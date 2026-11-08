"""Package the TOC, loaded source, runtime textures and user documentation."""
from pathlib import Path
import hashlib
import re
import zipfile

root = Path(__file__).resolve().parent.parent
toc = (root / 'ForeverSuite.toc').read_text()
version = re.search(r'^## Version: (.+)$', toc, re.M).group(1).strip()
sources = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
files = ['ForeverSuite.toc', *sources]
files += [str(path.relative_to(root)) for path in sorted((root / 'Assets').rglob('*.tga'))]
files += [str(path.relative_to(root)) for path in sorted((root / 'Assets').rglob('*.ttf'))]
files += ['README.md', 'CHANGELOG.md', 'FEATURE_AUDIT.md', 'IN_GAME_TEST.md', 'VALIDATION.txt', 'ROADMAP.md', 'DELIVERY_STATUS.md', 'NEW_TOOLS.md', 'COPYRIGHT.txt', 'LICENSE']
destination = root / 'dist' / f'ForeverSuite-{version}-forever.zip'
destination.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for filename in files:
        archive.write(root / filename, 'ForeverSuite/' + filename.replace('\\', '/'))
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(set(archive.namelist())) == len(files)
    for filename in sources:
        assert archive.read('ForeverSuite/' + filename) == (root / filename).read_bytes()
    assert 'Modules/Bags/Sidebar.lua' in archive.read('ForeverSuite/ForeverSuite.toc').decode()
digest = hashlib.sha256(destination.read_bytes()).hexdigest()
destination.with_suffix('.sha256').write_text(f'{digest}  {destination.name}\n')
print(f'Created {destination.name}: {len(files)} files; CRC and loaded-source contents verified.')
