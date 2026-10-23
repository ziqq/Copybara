#!/usr/bin/env python3
# Copyright (c) 2026 Anton Ustinoff. All rights reserved.
# Use and redistribution are subject to LICENSE.

"""Verify release identity and mutual identity recognition across versions."""
import argparse
import hashlib
import plistlib
import re
from pathlib import Path
import subprocess
import tempfile


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def verify_distribution_code(code, identity, team_id):
    requirement = (
        'anchor apple generic and '
        'certificate leaf[field.1.2.840.113635.100.6.1.13] exists and '
        f'certificate leaf[subject.OU] = "{team_id}"'
    )
    run('codesign', '--verify', '--strict', '-R', '=' + requirement, str(code))
    result = run('codesign', '--display', '--verbose=4', '--entitlements', '-', '--xml', str(code))
    metadata = result.stderr
    if not re.search(r'^CodeDirectory .*flags=.*\(.*runtime.*\)', metadata, re.MULTILINE):
        raise ValueError(f'Hardened runtime is missing: {code}')
    timestamps = [line.split('=', 1)[1].strip() for line in metadata.splitlines()
                  if line.startswith('Timestamp=')]
    if len(timestamps) != 1 or timestamps[0].casefold() in ('', 'none', '(none)'):
        raise ValueError(f'Secure timestamp is missing: {code}')
    if f'TeamIdentifier={team_id}' not in metadata.splitlines():
        raise ValueError(f'Unexpected signing team: {code}')
    entitlements = plistlib.loads(result.stdout.encode()) if result.stdout.strip() else {}
    if entitlements.get('com.apple.security.get-task-allow'):
        raise ValueError(f'Debugger entitlement is forbidden in distribution: {code}')
    verify_certificate(code, identity)


def verify_certificate(code, identity):
    with tempfile.TemporaryDirectory(prefix='copybara-public-certificate-') as folder:
        prefix = str(Path(folder) / 'certificate')
        run('codesign', '--display', '--extract-certificates=' + prefix, str(code))
        leaf = Path(prefix + '0').read_bytes()
        if hashlib.sha1(leaf).hexdigest().upper() != identity.upper():
            raise ValueError(f'Release was signed by a different identity: {code}')


def verify(app, identity, team_id=None):
    run('codesign', '--verify', '--deep', '--strict', str(app))
    result = run('codesign', '--display', '--requirements', '-', str(app))
    text = result.stdout + result.stderr
    lines = [line.split('designated =>', 1)[1].strip() for line in text.splitlines()
             if 'designated =>' in line]
    if len(lines) != 1:
        raise ValueError('Missing designated requirement')
    requirement = lines[0]
    if 'cdhash' in requirement or 'identifier "dev.ustinoff.copybara"' not in requirement:
        raise ValueError('Release must have a stable Copybara certificate requirement')
    verify_certificate(app, identity)
    if team_id:
        sparkle = app / 'Contents/Frameworks/Sparkle.framework'
        for code in (
            sparkle / 'Versions/B/XPCServices/Downloader.xpc',
            sparkle / 'Versions/B/XPCServices/Installer.xpc',
            sparkle / 'Versions/B/Autoupdate',
            sparkle / 'Versions/B/Updater.app',
            sparkle,
            app,
        ):
            verify_distribution_code(code, identity, team_id)
    return requirement


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--identity', required=True, help='Expected public certificate SHA1')
    parser.add_argument('--team-id', help='Require Developer ID, hardened runtime and timestamp for this team')
    parser.add_argument('--reference', type=Path, help='Another signed version to check in both directions')
    args = parser.parse_args()
    if args.team_id and not re.fullmatch(r'[A-Z0-9]{10}', args.team_id):
        parser.error('Invalid Developer ID team')
    requirement = verify(args.app, args.identity, args.team_id)
    if args.reference:
        reference = verify(args.reference, args.identity, args.team_id)
        run('codesign', '--verify', '--strict', '-R', '=' + requirement, str(args.reference))
        run('codesign', '--verify', '--strict', '-R', '=' + reference, str(args.app))
        print('Both versions satisfy each other\'s signing requirement')
    print('Copybara certificate identity and sealed bundle verified')


if __name__ == '__main__':
    main()
