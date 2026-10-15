"""Independent bounded concrete source oracle. No AL/runtime acceptance claim."""
from pathlib import Path
from copy import deepcopy
import random,json,re,subprocess,tempfile,os,shutil
HERE=Path(__file__).resolve().parent
SCANNER=Path(os.environ.get('CONTRACT_PARAMETER_SCANNER',HERE.parent/'Test-ContractParameterKeys.ps1'))
PWSH=os.environ.get('PWSH','pwsh')
GETTER=json.loads((HERE/'fixtures/request-payload-proof.json').read_text())[0]['dependency']
keys=['selectedKey','extraKey','lineNo'];names=['RequestJson','Other','Third']
shapes=[set(k for i,k in enumerate(keys) if mask&(1<<i)) for mask in range(8)]
def mutate(world,op,var,key=None,other=None):
 p,v,h,n=deepcopy(world)
 if op=='acquire':n+=1;v[var]=n;h[n]=set(p)
 if op=='alias':v[var]=v[other]
 if op=='add':h[v[var]].add(key)
 if op=='remove':h[v[var]].discard(key)
 if op=='validate' and not h[v[var]]<=set([key]):return None
 if op=='setter':p=set(h[v[var]])
 return p,v,h,n
out=[]
for seed in range(150):
 rng=random.Random(seed);worlds=[(set(p),{'RequestJson':1,'Other':2,'Third':3},{1:set(p),2:set(),3:set()},3) for p in shapes]
 body='procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori"; '+ '; '.join(f'Flag{i}: Boolean' for i in range(8))+''')
var
 RequestJson: JsonObject;
 Other: JsonObject;
 Third: JsonObject;
begin
 RequestJson := Argument.GetRequestJson();
''';reads=[]
 for i in range(8):
  op=rng.choice(['acquire','alias','add','remove','validate','setter']);var=rng.choice(names);key=rng.choice(keys);other=rng.choice(names)
  stmt={'acquire':f'{var} := Argument.GetRequestJson();','alias':f'{var} := {other};','add':f"{var}.Add('{key}', true);",'remove':f"{var}.Remove('{key}');",'validate':f'Validate{keys.index(key)}({var});','setter':f'Argument.SetRequestJson({var});'}[op]
  conditional=rng.choice([True,False]);changed=[mutate(w,op,var,key,other) for w in worlds];changed=[w for w in changed if w is not None]
  if conditional:body+=f' if Flag{i} then '+stmt+'\n';worlds=worlds+changed
  else:body+=' '+stmt+'\n';worlds=changed
  for name in names:
   for k in keys:
    offset=len(body)+1;body+=f" {name}.Contains('{k}');\n"
    reads.append(dict(offset=offset,variable=name.lower(),key=k,concretePossible=any(k in h[v[name]] for p,v,h,n in worlds)))
 body+='end;\n'
 for i,key in enumerate(keys):body+=f"local procedure Validate{i}(Request: JsonObject)\nvar ParameterName: Text;\nbegin\nforeach ParameterName in Request.Keys() do if not (ParameterName in ['{key}']) then Error('Unsupported key');\nend;\n"
 source='codeunit 2 "Provenance Impl"\n{\n'+body+'}\n'
 out.append(dict(seed=seed,source=source,dependency=GETTER,reads=reads))
with tempfile.TemporaryDirectory(prefix='andvari-payload-oracle-') as tmp:
 root=Path(tmp);cases=root/'programs.json';result=root/'results.json';cases.write_text(json.dumps(out))
 r=subprocess.run([PWSH,'-NoProfile','-File',str(HERE/'Test-RequestPayloadSourceOracle.ps1'),'-Scanner',str(SCANNER),'-CasesPath',str(cases),'-Output',str(result)],capture_output=True,text=True)
 if r.returncode:
  raise AssertionError(r.stderr or (result.read_text(encoding='utf-8-sig') if result.exists() else r.stdout))
 report=json.loads(result.read_text(encoding='utf-8-sig'));assert report['passed'],report
 assert report['programs']==len(out) and report['matched']==report['readChecks'] and report['excluded']>0 and report['concretePositive']>0,report
 assert not report['violations'],report
 report.pop('violations',None)
assert not root.exists()
print(json.dumps(report))
