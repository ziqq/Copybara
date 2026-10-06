#!/usr/bin/env python3
# Copyright (c) 2026 Anton Ustinoff. All rights reserved.
# Use and redistribution are subject to LICENSE.

"""Verify release identity and mutual identity recognition across versions."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def verify(app, identity):
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
    with tempfile.TemporaryDirectory(prefix='copybara-public-certificate-') as folder:
        prefix = str(Path(folder) / 'certificate')
        run('codesign', '--display', '--extract-certificates=' + prefix, str(app))
        leaf = Path(prefix + '0').read_bytes()
        if hashlib.sha1(leaf).hexdigest().upper() != identity.upper():
            raise ValueError('Release was signed by a different identity')
    return requirement


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--identity', required=True, help='Expected public certificate SHA1')
    parser.add_argument('--reference', type=Path, help='Another signed version to check in both directions')
    args = parser.parse_args()
    requirement = verify(args.app, args.identity)
    if args.reference:
        reference = verify(args.reference, args.identity)
        run('codesign', '--verify', '--strict', '-R', '=' + requirement, str(args.reference))
        run('codesign', '--verify', '--strict', '-R', '=' + reference, str(args.app))
        print('Both versions satisfy each other\'s signing requirement')
    print('Copybara certificate identity and sealed bundle verified')


if __name__ == '__main__':
    main()
