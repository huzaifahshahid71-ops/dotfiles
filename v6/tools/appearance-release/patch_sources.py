"""Guarded changes to the existing retained v6 installer implementation."""
from pathlib import Path
import ast
import hashlib
import os


def once(text,before,after):
    if after in text:return text
    if text.count(before)!=1:raise RuntimeError('Installer source declaration differs: '+before[:100])
    return text.replace(before,after,1)


def in_function(text,name,before,after):
    """Keep intervening helpers and other functions intact."""
    functions=[node for node in ast.parse(text).body if isinstance(node,ast.FunctionDef) and node.name==name]
    if len(functions)!=1:raise RuntimeError('Installer function differs: '+name)
    node=functions[0];lines=text.splitlines(keepends=True)
    start=node.lineno-1;end=node.end_lineno
    body=''.join(lines[start:end]);patched=once(body,before,after)
    return ''.join(lines[:start])+patched+''.join(lines[end:])


def backend(text):
    text=in_function(text,'validate_plan','    return plan\n',
        '    if plan.get("icon_bundle"):\n        from icon_bundle import source\n        source(payload,plan["icon_bundle"])\n    return plan\n')
    text=in_function(text,'install','    receipt_path = snapshot(home, paths)',
        '    if plan.get("icon_bundle"):\n        from icon_bundle import PATHS\n        paths.extend(PATHS)\n    receipt_path = snapshot(home, paths)')
    anchor='        if verify_runtime:\n            command(["/usr/bin/systemctl", "--user", "daemon-reload"])'
    text=in_function(text,'install',anchor,
        '        if plan.get("icon_bundle"):\n            from icon_bundle import install as install_icons\n            install_icons(payload,plan["icon_bundle"],home,replacements,changed,callback)\n'+anchor)
    compile(text,'payload_backend.py','exec')
    return text


def transaction(text):
    text=once(text,'            receipt["packages_added"] = sorted(set(after_packages) - set(before_packages))',
        '            receipt["packages_added"] = sorted(set(after_packages) - set(before_packages))\n            if plan.get("login_defaults") == "sddm-next-boot-v1":\n                import grub_records\n                receipt["grub_records"] = grub_records.prepare(self.root,state,receipt["files"])')
    text=once(text,'            receipt["status"] = "installed"',
        '            if plan.get("login_defaults") == "sddm-next-boot-v1":\n                import login_defaults, grub_records\n                grub_records.change(self.root,state,receipt.get("grub_records"),"installed",lambda:write_json(state / "receipt.json",receipt))\n                receipt["login_defaults"] = login_defaults.prepare(self.root)\n                write_json(state / "receipt.json", receipt)\n                login_defaults.change(self.root,receipt["login_defaults"],"installed",lambda:write_json(state / "receipt.json",receipt))\n                callback("SDDM selected for next boot; desktop services retained")\n            receipt["status"] = "installed"')
    text=once(text,'    def rollback_committed(self, state, receipt):',
        '    def rollback_committed(self, state, receipt):\n        if receipt.get("login_defaults"):\n            import login_defaults\n            login_defaults.change(self.root,receipt["login_defaults"],"before",partial=True)\n        if receipt.get("grub_records"):\n            import grub_records\n            grub_records.change(self.root,state,receipt["grub_records"],"before",partial=True)')
    text=once(text,'        conflicts = []',
        '        conflicts = []\n        if receipt.get("login_defaults"):\n            import login_defaults\n            conflicts.extend(login_defaults.conflicts(self.root,receipt["login_defaults"]))\n        if receipt.get("grub_records"):\n            import grub_records\n            conflicts.extend(grub_records.conflicts(self.root,state,receipt["grub_records"]))')
    text=once(text,'        completed = []\n        try:',
        '        completed = []\n        login_changed = False\n        grub_changed = False\n        try:\n            if receipt.get("grub_records"):\n                import grub_records\n                grub_changed = True\n                grub_records.change(self.root,state,receipt["grub_records"],"before")\n            if receipt.get("login_defaults"):\n                import login_defaults\n                login_changed = True\n                login_defaults.change(self.root,receipt["login_defaults"],"before")')
    text=once(text,'        except Exception:\n            for index in reversed(completed):',
        '        except Exception:\n            if login_changed:\n                login_defaults.change(self.root,receipt["login_defaults"],"installed")\n            if grub_changed:\n                grub_records.change(self.root,state,receipt["grub_records"],"installed")\n            for index in reversed(completed):')
    text=once(text,'("core.py", "maintenance.py", "package_policy.py", "system_transaction.py"):',
        '("core.py", "maintenance.py", "package_policy.py", "system_transaction.py", "login_defaults.py", "grub_records.py"):')
    return text


def grub_manager(text):
    marker='# SUMI_QUIET_SELECTION_V1'
    if marker in text:return text
    anchor='        printf \'%s\\n\' \'fi\' "$END"'
    replacement='        printf \'%s\\n\' \'fi\'\n        # SUMI_QUIET_SELECTION_V1\n        printf \'%s\\n\' \'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT-} quiet systemd.show_status=false rd.systemd.show_status=false"\' "$END"'
    return once(text,anchor,replacement)


def apply(path,transform):
    for item in (path,*path.parents):
        if item.is_symlink():raise RuntimeError('Source symlink preserved: '+str(item))
    before=path.read_bytes();after=transform(before.decode()).encode()
    if before==after:return
    if path.suffix=='.py':compile(after,str(path),'exec')
    backup=path.with_name(path.name+'.before-appearance-r2-'+hashlib.sha256(before).hexdigest()[:16])
    if backup.exists() and backup.read_bytes()!=before:raise RuntimeError('Source backup differs')
    if not backup.exists():backup.write_bytes(before)
    temp=path.with_name(path.name+'.appearance-new')
    if temp.exists() or temp.is_symlink():raise RuntimeError('Source temporary preserved')
    temp.write_bytes(after);temp.chmod(path.stat().st_mode&0o777);os.replace(temp,path)
