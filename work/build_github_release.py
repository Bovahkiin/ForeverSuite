"""Validate the source version and build a release without publishing anything."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile


def metadata(root):
    toc = (root / 'ForeverSuite.toc').read_text(encoding='utf-8-sig')
    matches = re.findall(r'^## Version:\s*(\S+)\s*$', toc, re.M)
    if len(matches) != 1 or not re.fullmatch(r'\d+\.\d+\.\d+', matches[0]):
        raise ValueError('ForeverSuite.toc needs one numeric version, for example 0.8.10.')
    version = matches[0]
    init = (root / 'Core/Init.lua').read_text(encoding='utf-8-sig')
    if not re.search(r'FS\.version\s*=\s*"' + re.escape(version) + r'"', init):
        raise ValueError('The TOC and Core/Init.lua versions must match.')
    changelog = (root / 'CHANGELOG.md').read_text(encoding='utf-8-sig')
    first = re.search(r'^# (\S+) - (\d{4}-\d{2}-\d{2})\s*$', changelog, re.M)
    if not first or first.group(1) != version:
        raise ValueError('The first CHANGELOG.md heading must describe this version.')
    body = changelog[first.end():].split('\n# ', 1)[0].strip()
    if not body:
        raise ValueError('Add patch notes below the current CHANGELOG.md heading.')
    sources = [s.strip() for s in toc.splitlines() if s.strip() and not s.startswith('#')]
    for name in sources:
        path = PurePosixPath(name.replace('\\', '/'))
        if path.is_absolute() or '..' in path.parts or ':' in name:
            raise ValueError('Invalid TOC path: ' + name)
        if not (root / path).is_file():
            raise ValueError('Missing source file: ' + name)
    return version, body


def build(root):
    version, body = metadata(root)
    subprocess.run([sys.executable, str(root / 'work/package_release.py')], cwd=root, check=True)
    archive = root / 'dist' / f'ForeverSuite-{version}-forever.zip'
    checksum = archive.with_suffix('.sha256')
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise ValueError('The built ZIP failed its CRC check.')
        if 'ForeverSuite/ForeverSuite.toc' not in z.namelist():
            raise ValueError('The ZIP must contain a single ForeverSuite addon folder.')
        for name in z.namelist():
            parts = PurePosixPath(name).parts
            if parts[0] != 'ForeverSuite' or '..' in parts or any(p in {'work', '.git', '.github', 'dist'} for p in parts):
                raise ValueError('Unexpected release file: ' + name)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if checksum.read_text(encoding='utf-8').split()[0] != digest:
        raise ValueError('Release checksum mismatch.')
    notes = archive.parent / f'ForeverSuite-{version}-release-notes.md'
    notes.write_text(f'## ForeverSuite {version}\n\n{body}\n\nDownload: `{archive.name}`.\n', encoding='utf-8')
    info = dict(version=version, tag='v'+version, zip=archive.relative_to(root).as_posix(),
                checksum=checksum.relative_to(root).as_posix(), notes=notes.relative_to(root).as_posix())
    (archive.parent / 'release-info.json').write_text(json.dumps(info, indent=2)+'\n', encoding='utf-8')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
            for key, value in info.items():
                output.write(f'{key}={value}\n')
    print('Validated release:', version, '(not published)')
    return info


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Only validate source metadata.')
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    if args.check:
        print('Validated source version:', metadata(source)[0])
    else:
        build(source)
