#!/usr/bin/env python3
"""Niri refresh picker: only advertised modes, with a timed revert."""
import json
import subprocess

def run(args, **kwargs):
    return subprocess.run(args,capture_output=True,text=True,check=True,**kwargs).stdout

def main():
    outputs = json.loads(run(['/usr/bin/niri','msg','--json','outputs']))
    connected = [o for o in outputs.values() if o.get('current_mode') is not None]
    output = next((o for o in connected if o['name'].startswith('eDP-')),connected[0] if connected else None)
    if not output: raise RuntimeError('No active Niri output')
    current = output['modes'][output['current_mode']]
    modes = [m for m in output['modes'] if (m['width'],m['height']) == (current['width'],current['height'])]
    def label(m): return f"{m['width']}x{m['height']}@{m['refresh_rate']/1000:.3f}"
    choices = {label(m):m for m in sorted(modes,key=lambda m:m['refresh_rate'],reverse=True)}
    try:
        selection = run(['fuzzel','--dmenu','--prompt','Refresh rate: '],input='\n'.join(choices)).strip()
    except subprocess.CalledProcessError: return
    if selection not in choices: return
    command = ['/usr/bin/niri','msg','output',output['name'],'mode']
    run(command+[selection])
    keep = False
    try:
        keep = run(['fuzzel','--dmenu','--prompt','Keep this mode? (10s) '],input='Keep\nRevert',timeout=10).strip() == 'Keep'
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError): pass
    if not keep: run(command+[label(current)])

if __name__ == '__main__':
    try: main()
    except Exception as error:
        subprocess.run(['notify-send','iNiR refresh rate',str(error)])
        raise SystemExit(str(error))
