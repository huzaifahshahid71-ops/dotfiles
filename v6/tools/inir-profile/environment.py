#!/usr/bin/env python3
"""Separate iNiR state from application state, preserving unset and empty values."""
import argparse
import json
import os
from pathlib import Path
import shlex
import sys

KEYS = ('HOME XDG_CONFIG_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_HOME '
        'XDG_DATA_DIRS GSETTINGS_BACKEND QT_SCALE_FACTOR QT_SCALE_FACTOR_ROUNDING_POLICY '
        'QT_LOGGING_RULES QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE '
        'QS_DISABLE_CRASH_HANDLER').split()

def private_env(root, incoming):
    env = dict(incoming)
    if env.get('INIR_PRIVATE_CONTEXT') == str(root):
        return env
    env['INIR_APP_ENV_JSON'] = json.dumps({k: env.get(k) for k in KEYS})
    real_home = env['HOME']
    private = root/'home'
    env.update(HOME=str(private), XDG_CONFIG_HOME=str(private/'.config'),
               XDG_CACHE_HOME=str(private/'.cache'), XDG_STATE_HOME=str(private/'.local/state'),
               XDG_DATA_HOME=str(private/'.local/share'), GSETTINGS_BACKEND='keyfile',
               INIR_PRIVATE_CONTEXT=str(root), INIR_PROFILE_ROOT=str(root),
               INIR_RUNTIME_DIR=str(root/'runtime'), INIR_DISABLE_HOT_RELOAD='1',
               INIR_VENV=str(root/'venv'), ILLOGICAL_IMPULSE_VIRTUAL_ENV=str(root/'venv'),
               QT_SCALE_FACTOR='1', QT_SCALE_FACTOR_ROUNDING_POLICY='RoundPreferFloor',
               QS_DISABLE_CRASH_HANDLER='1')
    env['XDG_DATA_DIRS'] = (incoming.get('XDG_DATA_HOME') or real_home+'/.local/share')+':'+incoming.get('XDG_DATA_DIRS','/usr/local/share:/usr/share')
    return env

def application_env(incoming):
    env = dict(incoming)
    if not env.get('INIR_APP_ENV_JSON'):
        return env
    snapshot = json.loads(env['INIR_APP_ENV_JSON'])
    for key in KEYS:
        value = snapshot[key]
        if value is None: env.pop(key, None)
        else: env[key] = value
    for key in list(env):
        if key.startswith('INIR_') or key == 'ILLOGICAL_IMPULSE_VIRTUAL_ENV':
            env.pop(key)
    return env

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--shell', action='store_true')
    p.add_argument('--raw', action='store_true')
    p.add_argument('args', nargs=argparse.REMAINDER)
    a = p.parse_args()
    root = Path(__file__).resolve().parent
    if a.shell:
        env = private_env(root, os.environ)
        for k in KEYS+['INIR_APP_ENV_JSON','INIR_PRIVATE_CONTEXT','INIR_PROFILE_ROOT',
                       'INIR_RUNTIME_DIR','INIR_DISABLE_HOT_RELOAD','INIR_VENV',
                       'ILLOGICAL_IMPULSE_VIRTUAL_ENV']:
            if k in env: print('export '+k+'='+shlex.quote(env[k]))
        return
    args = a.args
    if args and args[0] == '--': args = args[1:]
    if not args: p.error('An application command is required')
    env = application_env(os.environ)
    if os.environ.get('INIR_PRIVATE_CONTEXT') and os.getcwd() == os.environ.get('HOME'):
        os.chdir(env['HOME'])
    runtime = Path(env.get('XDG_RUNTIME_DIR', '/nonexistent'))
    if not a.raw and (runtime/'systemd/private').is_socket():
        args = ['/usr/bin/systemd-run','--user','--quiet','--collect','--same-dir','--scope','--',*args]
    os.execvpe(args[0],args,env)

if __name__ == '__main__': main()
