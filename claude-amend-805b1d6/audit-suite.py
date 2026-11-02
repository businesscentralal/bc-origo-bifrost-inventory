import re,json,hashlib,xml.etree.ElementTree as ET
from pathlib import Path
p=Path('/workspace/evidence/inventory175-claude-amend-final-20261102');r=Path('/workspace/inventory152-worker9');sha=json.loads((p/'deployment-provenance.json').read_text())['candidateSha'];root=ET.parse(p/'native-full-suite.xml').getroot();cases=root.findall('.//testcase');expected=[];rows=[]
for f in (r/'test').rglob('*.al'):
 s=f.read_text();s=re.sub(r'//[^\n]*','',s);s=re.sub(r'/\*.*?\*/','',s,flags=re.S);cu=re.search(r'codeunit\s+(\d+)\s+"([^"]+)"',s,re.I)
 if cu:
  methods=re.findall(r'\[Test\]\s*(?:\[[^\]]+\]\s*)*procedure\s+(\w+)\s*\(',s,re.I);expected.extend((cu[1],m) for m in methods)
  if methods:rows.append(dict(codeunit=int(cu[1]),name=cu[2],tests=len(methods),source=str(f.relative_to(r))))
actual=[]
for suite in root.findall('.//testsuite'):
 cid=suite.attrib['name'].split()[0];actual.extend((cid,c.attrib['name']) for c in suite.findall('testcase'))
errors=sum(c.find('error') is not None for c in cases);failed=sum(c.find('failure') is not None for c in cases);skipped=sum(c.find('skipped') is not None for c in cases)
a=dict(sha=sha,expected=len(expected),executed=len(actual),unique=len(set(actual)),failed=failed,errors=errors,skipped=skipped,missing=sorted(set(expected)-set(actual)),extra=sorted(set(actual)-set(expected)),junitSha256=hashlib.sha256((p/'native-full-suite.xml').read_bytes()).hexdigest());assert len(expected)==len(actual)==len(set(actual))==467 and not any([failed,errors,skipped,a['missing'],a['extra']]);(p/'suite-inventory-audit.json').write_text(json.dumps(a,indent=2));print(a)
(p/'test-inventory.json').write_text(json.dumps(dict(sha=sha,codeunits=len(rows),expectedMethods=len(expected),rows=rows),indent=2))
summary=dict(sha=sha,containerId='f0133160e482',foundationVersion='28.0.10.632',fullSuite=True,executed=467,passed=467,failed=0,skipped=0,errors=0);(p/'full-suite-summary.json').write_text(json.dumps(summary,indent=2))
