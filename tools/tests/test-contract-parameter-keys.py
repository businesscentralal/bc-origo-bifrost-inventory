from pathlib import Path
import subprocess, json, re, tempfile, os, shutil, atexit
repo = Path(__file__).resolve().parents[2]
pw = os.environ.get('PWSH', 'pwsh')
script = Path(os.environ.get('CONTRACT_PARAMETER_SCANNER', repo / 'tools/Test-ContractParameterKeys.ps1'))
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
# A source-resolved operation selector is not a request key. Keep true key uses,
# unknown calls and ambiguous overloads visible instead of exempting method names.
selector_body = """    local procedure CheckParameters(Request: JsonObject; Operation: Text)
    begin
        case Operation of
            'Calculate':
                Request.Contains('selectedKey');
        end;
    end;
"""
selector_cases = {
 'operation-selector': (selector_body, "CheckParameters(RequestJson, 'Calculate');", []),
 'selector-comment-decoy': (selector_body.replace('case Operation of', "// Operation is a selector; not a key.\n        case Operation of"), "CheckParameters(RequestJson, 'Calculate');", []),
 'selector-string-decoy': (selector_body.replace("Request.Contains('selectedKey');", "begin\n                    Request.Contains('selectedKey');\n                    Error('Operation must be Calculate.');\n                end;"), "CheckParameters(RequestJson, 'Calculate');", []),
 'selector-also-read': (selector_body.replace("Request.Contains('selectedKey');", "begin\n                    Request.Contains('selectedKey');\n                    Request.Contains(Operation);\n                end;"), "CheckParameters(RequestJson, 'Calculate');", ['read-not-declared|Calculate']),
 'unknown-selector-callee': ('', "CheckParameters(RequestJson, 'Calculate');", ['read-not-declared|Calculate']),
 'selector-no-case': (selector_body.replace('case Operation of', 'case Request.Keys().Count() of'), "CheckParameters(RequestJson, 'Calculate');", ['read-not-declared|Calculate']),
 'selector-qualified': ('qualified', "Parts.CheckParameters(RequestJson, 'Calculate');", []),
 'selector-ambiguous-overload': (selector_body + selector_body.replace('Operation: Text', 'Operation: Code[20]').replace('case Operation of', 'case Request.Keys().Count() of'), "CheckParameters(RequestJson, 'Calculate');", ['read-not-declared|Calculate']),
}
for name, (body, call, expected) in selector_cases.items():
 cases.append((name, literal('selectedKey'), read('selectedKey') + '\n        ' + call, expected, ''))
binding_body = """    local procedure ReadNumber(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text)
    var
        Reader: Codeunit "Request Value Reader ori";
        Number: Decimal;
    begin
        Reader.TryReadDecimal(Argument, Request, KeyName, true, Number);
    end;
"""
binding_cases = {
 'binding-literal': (binding_body, "ReadNumber(Argument, RequestJson, 'selectedKey');", [], literal('selectedKey')),
 'binding-unknown-key': (binding_body, "ReadNumber(Argument, RequestJson, 'unknownKey');", ['declared-not-read|selectedKey', 'read-not-declared|unknownKey'], literal('selectedKey')),
 'binding-dynamic': (binding_body, "ReadNumber(Argument, RequestJson, DynamicKey);", None, literal('selectedKey')),
 'binding-mixed-callers': (binding_body, "ReadNumber(Argument, RequestJson, 'selectedKey'); ReadNumber(Argument, RequestJson, DynamicKey);", None, literal('selectedKey')),
 'binding-nested-caller': (binding_body, "ReadNumber(Argument, RequestJson, 'selectedKey'); ReadNumber(Argument, RequestJson, GetDynamicKey());", None, literal('selectedKey')),
 'binding-unknown-receiver': (binding_body, "ReadNumber(Argument, RequestJson, 'selectedKey'); Unknown.ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
 'binding-multiple-literals': (binding_body, "ReadNumber(Argument, RequestJson, 'selectedKey'); ReadNumber(Argument, RequestJson, 'extraKey');", ['read-not-declared|extraKey'], literal('selectedKey')),
 'binding-qualified': ('qualified', "Parts.ReadNumber(Argument, RequestJson, 'selectedKey');", [], literal('selectedKey')),
 'binding-ambiguous-overload': (binding_body + binding_body.replace('KeyName: Text', 'KeyName: Code[20]'), "ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
 'binding-mutated-key': (binding_body.replace('Reader.TryReadDecimal', "KeyName := 'otherKey';\n        Reader.TryReadDecimal"), "ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
 'binding-cleared-key': (binding_body.replace('Reader.TryReadDecimal', "Clear(KeyName);\n        Reader.TryReadDecimal"), "ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
 'binding-unknown-mutator': (binding_body.replace('Reader.TryReadDecimal', "Mutate(KeyName);\n        Reader.TryReadDecimal"), "ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
 'binding-nested-mutator': (binding_body.replace('Reader.TryReadDecimal', "Argument.RespondWithError(Code, Msg, Mutate(KeyName), '', '', '');\n        Reader.TryReadDecimal"), "ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
 'binding-error-context': (binding_body.replace('Reader.TryReadDecimal', "Argument.RespondWithError(Code, Msg, KeyName, Format(Number, 0, 9), '', '');\n        Reader.TryReadDecimal"), "ReadNumber(Argument, RequestJson, 'selectedKey');", [], literal('selectedKey')),
 'binding-not-parameter': (binding_body.replace('KeyName: Text)', 'Unused: Text)').replace('Number: Decimal;', 'Number: Decimal; KeyName: Text;'), "ReadNumber(Argument, RequestJson, 'selectedKey');", None, literal('selectedKey')),
}
for name, (body, call, expected, contract) in binding_cases.items():
 cases.append((name, contract, '        ' + call, expected, ''))
results=[]
for name,contract,execute,expected,part in cases:
 root=app(name,contract,execute,part)
 if name in selector_cases:
  body = selector_cases[name][0]
  if body == 'qualified':
   body = 'codeunit 3 "Fixture Parts"\n{\n' + selector_body.replace('local procedure', 'procedure') + '}\n'
   (root/'src'/'Parts.al').write_text(body)
  else:
   impl = root/'src'/'Impl.al'
   text = impl.read_text()
   impl.write_text(text.rsplit('}', 1)[0] + body + '}\n')
 if name in binding_cases:
  body = binding_cases[name][0]
  if body == 'qualified':
   (root/'src'/'Parts.al').write_text('codeunit 3 "Fixture Parts"\n{\n' + binding_body.replace('local procedure', 'procedure') + '}\n')
  else:
   impl = root/'src'/'Impl.al'
   text = impl.read_text()
   impl.write_text(text.rsplit('}', 1)[0] + body + '}\n')
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
