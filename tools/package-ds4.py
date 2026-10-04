#!/usr/bin/env python3
"""Package verified CI outputs; never claim hardware validation."""
from pathlib import Path
import hashlib
import os
import shutil
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parent.parent
out = root / 'build/ds4-delivery'
out.mkdir(parents=True, exist_ok=True)
reports = list((root / 'app/build/test-results/testDebugUnitTest').glob('TEST-*.xml'))
assert reports, 'No unit test results'
totals = {k: 0 for k in ('tests', 'failures', 'errors', 'skipped')}
for report in reports:
    suite = ET.parse(report).getroot()
    for key in totals:
        totals[key] += int(suite.get(key, '0'))
assert totals['failures'] == totals['errors'] == 0, totals
lint = ET.parse(root / 'app/build/reports/lint-results-debug.xml').getroot()
issues = list(lint.findall('issue'))
assert not any(x.get('severity') in ('Error', 'Fatal') for x in issues)
shutil.copy2(root / 'app/build/outputs/apk/debug/app-debug.apk', out / 'Blugaemand-DS4-Begonia-v0.2.apk')
module = root / 'packaging/magisk'
with ZipFile(out / 'Blugaemand-DS4-Begonia-Identity-v0.2.zip', 'w', ZIP_DEFLATED) as archive:
    for path in sorted(module.rglob('*')):
        if path.is_file(): archive.write(path, path.relative_to(module))
for name in ('DS4-BEGONIA.fa.md', 'DS4-PROTOCOL.md'):
    shutil.copy2(root / 'docs' / name, out / name)
shutil.copy2(root / 'tools/ds4-diagnose.sh', out / 'ds4-diagnose.sh')
(out / 'VALIDATION.txt').write_text(
    f"Commit: {os.environ.get('GITHUB_SHA', 'local')}\nUnit tests: {totals}\n"
    f"Lint: no errors; {len(issues)} reported issues\n"
    'Clean debug build; packaged application ID and APK signature verified by CI.\n'
    'Physical begonia/iPad pairing, sensor orientation and latency: NOT VERIFIED.\n')
files = sorted(p for p in out.iterdir() if p.is_file() and p.name not in ('SHA256SUMS', 'DS4-Begonia-v0.2-test-kit.zip'))
(out / 'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in files))
with ZipFile(out / 'DS4-Begonia-v0.2-test-kit.zip', 'w', ZIP_DEFLATED) as archive:
    for path in files + [out / 'SHA256SUMS']: archive.write(path, path.name)
with ZipFile(out / 'DS4-Begonia-v0.2-test-kit.zip') as archive:
    assert archive.testzip() is None
print((out / 'VALIDATION.txt').read_text())
