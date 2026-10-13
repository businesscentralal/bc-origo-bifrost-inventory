from pathlib import Path
import subprocess, json, re, tempfile, os, shutil, atexit
repo = Path(__file__).resolve().parents[2]
pw = os.environ.get('PWSH', 'pwsh')
script = repo / 'tools/Test-ContractParameterKeys.ps1'
root = Path(tempfile.mkdtemp(prefix='inventory-contract-guard-'))
p = root
atexit.register(shutil.rmtree, root, ignore_errors=True)
helper = 'codeunit 4 "Request Value Reader ori"\n{\n}\n' 
def run(script_name, app_path, name):
    return subprocess.run([pw, '-NoProfile', '-File', str(script), '-AppFolder', str(app_path), '-AllowListPath', str(root/'empty-allow-list.txt')], capture_output=True, text=True)
def app(name,contract,execute,parts='',variables=''):
 root=p/'fixtures'/name/'app';s=root/'src';s.mkdir(parents=True,exist_ok=True)
 (s/'Types.al').write_text('''enum 1 "Message Type ori"
{
    value(1; "Fixture.Selected")
    {
        Implementation = "Msg Interface ori" = "Fixture Impl", "Msg Contract ori" = "Fixture Impl";
    }
}
''')
 (s/'Impl.al').write_text('''codeunit 2 "Fixture Impl"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        Reader: Codeunit "Request Value Reader ori";
        ValueDate: Date;
        ValueDecimal: Decimal;
    begin
        RequestJson := Argument.GetRequestJson();
'''+execute+'''
    end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
        Unrelated: JsonArray;
        Parts: Codeunit "Fixture Parts";
'''+variables+'''
    begin
'''+contract+'''
        exit(true);
    end;
}
''')
 if parts: (s/'Parts.al').write_text(parts)
 (s/'Helper.al').write_text(helper)
 return root
parts='''codeunit 3 "Fixture Parts"
{
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Fixture.Selected', 'Fixture.Alias':
                begin
                    Parameters.Add(Mgt.Parameter('selectedKey', 'string', false, 'Selected'));
                end;
            'Fixture.Other':
                Parameters.Add(Mgt.Parameter('otherKey', 'string', false, 'Other'));
        end;
    end;
}
'''
read=lambda key:f"        RequestJson.Get('{key}', Token);"
literal=lambda key:'        Parameters.ReadFrom(\'[{{"name":"{}"}}]\');'.format(key)
hand="        ParameterJson.Add('name', 'selectedKey');\n        Parameters.Add(ParameterJson);"
normal="        Parameters.Add(Mgt.Parameter('selectedKey', 'string', false, 'Selected'));"
cases=[
 ('handbuilt',hand,read('selectedKey'),[],''),
 ('literal',literal('selectedKey'),read('selectedKey'),[],''),
 ('selected-case',"        Parameters := Parts.GetParameters('Fixture.Selected');",read('selectedKey'),[],parts),
 ('alias-case',"        Parameters := Parts.GetParameters('Fixture.Alias');",read('selectedKey'),[],parts),
 ('undeclared',literal('selectedKey'),read('selectedKey')+'\n'+read('unknownKey'),['read-not-declared|unknownKey'],''),
 ('unused',literal('unusedKey'),read('selectedKey'),['declared-not-read|unusedKey','read-not-declared|selectedKey'],''),
 ('wrong-selector',"        Parameters := Parts.GetParameters('Fixture.Other');",read('selectedKey'),['declared-not-read|otherKey','read-not-declared|selectedKey'],parts),
 ('missing-selector',"        Parameters := Parts.GetParameters('Fixture.Missing');",read('selectedKey'),['read-not-declared|selectedKey'],parts),
 ('malformed-json',"        Parameters.ReadFrom('[{broken]');",read('selectedKey'),['malformed-contract-json|Parameters','read-not-declared|selectedKey'],''),
 ('wrong-json-shape',"        Parameters.ReadFrom('{\"name\":\"selectedKey\"}');",read('selectedKey'),['malformed-contract-json|Parameters','read-not-declared|selectedKey'],''),
 ('unrelated-literal',"        Unrelated.ReadFrom('[{\"name\":\"selectedKey\"}]');",read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('empty-array',"        Parameters.ReadFrom('[]');",read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('cleared-handbuilt',"        ParameterJson.Add('name', 'selectedKey');\n        Clear(ParameterJson);\n        Parameters.Add(ParameterJson);",read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('unattached-handbuilt',"        ParameterJson.Add('name', 'selectedKey');",read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('comment-decoy','        // '+literal('selectedKey'),read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('dynamic-selector',"        Parameters := Parts.GetParameters(Selector);",read('selectedKey'),['dynamic-ambiguity|Fixture Parts::getparameters','declared-not-read|otherKey'],parts),
 ('literal-escaped-description',"        Parameters.ReadFrom('[{\"name\":\"selectedKey\",\"description\":\"caller''''s key\"}]');",read('selectedKey'),[],''),
 ('unrelated-handbuilt',"        ParameterJson.Add('name', 'selectedKey');\n        Unrelated.Add(ParameterJson);",read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('helper-date',literal('postingDate'),"        Reader.TryReadDate(Argument, RequestJson, 'postingDate', false, ValueDate);",[],''),
 ('helper-decimal',literal('quantityToAssemble'),"        Reader.TryReadDecimal(Argument, RequestJson, 'quantityToAssemble', false, ValueDecimal);",[],''),
 ('helper-required',literal('postingDate'),"        Reader.TryReadDate(Argument, RequestJson, 'postingDate', true, ValueDate);",[],''),
 ('helper-undeclared',"        Parameters.ReadFrom('[]');","        Reader.TryReadDecimal(Argument, RequestJson, 'quantityToAssemble', false, ValueDecimal);",['read-not-declared|quantityToAssemble'],''),
 ('cleared-literal',literal('selectedKey')+'\n        Clear(Parameters);',read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('cleared-array',hand+'\n        Clear(Parameters);',read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('overwritten-literal',literal('selectedKey')+'\n        Parameters.ReadFrom(\'[]\');',read('selectedKey'),['read-not-declared|selectedKey'],''),
 ('helper-dynamic',literal('postingDate'),"        Reader.TryReadDate(Argument, RequestJson, KeyName, false, ValueDate);",None,''),
]
results=[]
for name,contract,execute,expected,part in cases:
 root=app(name,contract,execute,part)
 r=run('Test-ContractParameterKeys.ps1',root,'fixture-'+name)
 found=re.findall(r'New offender .*?: Fixture.Selected\|([^\n]+)',r.stdout)
 if expected is None: ok=r.returncode==1 and any(x.startswith('dynamic-ambiguity|typed-reader:') for x in found)
 else: ok=sorted(found)==sorted(expected) and r.returncode==(1 if expected else 0)
 results.append(dict(name=name,passed=ok,exitCode=r.returncode,expected=expected,actual=found))
 print(name,ok,found if not ok else '')
print(json.dumps({'total':len(results),'passed':sum(x['passed'] for x in results),'failed':sum(not x['passed'] for x in results)}))
failed = [x for x in results if not x['passed']]
shutil.rmtree(root)
assert not failed, json.dumps(failed)
