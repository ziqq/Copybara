#!/usr/bin/env python3
# Copyright (c) 2026 Anton Ustinoff. All rights reserved.
# Use and redistribution are subject to LICENSE.
"""Capture the isolated native screenshot fixture; never launch the installed app.

The fixture in build/appstore-screenshots/source uses the production SwiftUI
views with demo data and a screenshot-only presentation canvas. Build it first.
"""
import argparse
import shutil
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'build/appstore-screenshots'
OUT = ROOT / 'docs/appstore/screenshots'
APP = WORK / 'DerivedData/Build/Products/Debug/Copybara.app'
HELPER = WORK / 'window-id'


def run(*args):
    """Run a local export command and require success."""
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def main():
    """Export six real-window captures and their dimensions manifest."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true', help='Rebuild the isolated screenshot fixture')
    args = parser.parse_args()
    if args.build or not APP.is_dir():
        source = WORK / 'source'
        source.mkdir(parents=True, exist_ok=True)
        for name in ('Copybara', 'CopybaraTests', 'Config'):
            shutil.copytree(ROOT / name, source / name, dirs_exist_ok=True)
        for name in ('project.yml', 'LICENSE', 'THIRD_PARTY_NOTICES', 'README.md'):
            shutil.copy2(ROOT / name, source / name)
        (source / 'docs').mkdir(exist_ok=True)
        shutil.copy2(OUT / 'fixtures/ScreenshotRenderer.swift', source / 'Copybara/Support/ScreenshotRenderer.swift')
        run('xcodegen', 'generate', '--spec', str(source / 'project.yml'))
        with (WORK / 'build.log').open('w') as log:
            subprocess.run(['xcodebuild', '-project', str(source / 'Copybara.xcodeproj'), '-scheme', 'Copybara', '-configuration', 'Debug', '-destination', 'platform=macOS', '-derivedDataPath', str(WORK / 'DerivedData'), '-clonedSourcePackagesDirPath', str(ROOT / 'build/DerivedData/SourcePackages'), 'PRODUCT_BUNDLE_IDENTIFIER=dev.ustinoff.copybara.screenshots.$(PRODUCT_NAME:rfc1034identifier)', 'CODE_SIGN_IDENTITY=-', 'CODE_SIGN_STYLE=Manual', 'DEVELOPMENT_TEAM=', 'build'], check=True, stdout=log, stderr=log)
    OUT.mkdir(parents=True, exist_ok=True)
    helper_source = WORK / 'window-id.swift'
    helper_source.write_text('''import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where window[kCGWindowOwnerPID as String] as? Int == pid {
 if let id = window[kCGWindowNumber as String] as? Int,
    let bounds = window[kCGWindowBounds as String] as? [String: Any],
    let width = bounds["Width"] as? Int, width > 1000 { print(id); break }
}
''')
    run('xcrun', 'swiftc', '-module-cache-path', str(WORK / 'ModuleCache'), str(helper_source), '-o', str(HELPER))
    manifest = []
    for locale in ('en', 'ru'):
        for index, shot in enumerate(('history', 'pins', 'settings'), 1):
            directory = OUT / locale
            directory.mkdir(exist_ok=True)
            target = directory / f'{index:02d}-{shot}.png'
            env = dict(os.environ, COPYBARA_SCREENSHOT='1', COPYBARA_SHOT=shot,
                       CFFIXED_USER_HOME=str(WORK / 'Home'))
            (WORK / 'Home').mkdir(exist_ok=True)
            with (WORK / f'{locale}-{shot}.log').open('w') as log:
                process = subprocess.Popen([str(APP / 'Contents/MacOS/Copybara'), '-AppleLanguages', f'({locale})', '-AppleLocale', f'{locale}_{"RU" if locale == "ru" else "US"}'], env=env, stdout=log, stderr=log)
                try:
                    window = ''
                    for _ in range(40):
                        time.sleep(0.25)
                        window = run(str(HELPER), str(process.pid)).strip()
                        if window:
                            break
                    if not window:
                        raise RuntimeError('Fixture window did not appear')
                    time.sleep(2)
                    run('screencapture', '-x', '-o', '-l', window, str(target))
                    details = run('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', str(target))
                    if 'pixelWidth: 2880' not in details or 'pixelHeight: 1800' not in details:
                        raise RuntimeError('Unexpected native capture dimensions: ' + details)
                    manifest.append({'file': str(target.relative_to(OUT)), 'width': 2880, 'height': 1800, 'locale': locale, 'scene': shot})
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    run('xcrun', 'swift', '-module-cache-path', str(WORK / 'ModuleCache'), str(OUT / 'fixtures/Derivatives.swift'), str(OUT))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
