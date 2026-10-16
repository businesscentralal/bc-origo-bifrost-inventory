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
    args = [pw, '-NoProfile', '-File', str(script), '-AppFolder', str(app_path), '-AllowListPath', str(root/'empty-allow-list.txt')]
    dependency = app_path.parent/'dependency'
    if dependency.exists(): args += ['-DependencyAppFolders', str(dependency)]
    return subprocess.run(args, capture_output=True, text=True)
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
lineage_body = """    local procedure ReadEntry(var Argument: Record "Message Argument ori"; EntryObject: JsonObject)
    var
        Reader: Codeunit "Request Value Reader ori";
        Quantity: Decimal;
    begin
        Reader.TryReadDecimal(Argument, EntryObject, 'quantity', true, Quantity);
    end;
"""
lineage_call = """        RequestJson.Get('entries', Token);
        Entries := Token.AsArray();
        foreach Entry in Entries do
            ReadEntry(Argument, Entry.AsObject());"""
lineage_cases = {
 'lineage-array-entry': (lineage_call, [], literal('entries')),
 'lineage-object': ("        RequestJson.Get('entries', Token); ReadEntry(Argument, Token.AsObject());", [], literal('entries')),
 'lineage-undeclared-parent': (lineage_call, ['read-not-declared|entries'], "        Parameters.ReadFrom('[]');"),
 'lineage-cleared-token': (lineage_call.replace('Entries := Token.AsArray();', 'Clear(Token); Entries := Token.AsArray();'), None, literal('entries')),
 'lineage-replaced-token': (lineage_call.replace('Entries := Token.AsArray();', "Token.ReadFrom('{}'); Entries := Token.AsArray();"), None, literal('entries')),
 'lineage-overwritten-array': (lineage_call.replace('foreach Entry', 'Entries := GetOtherArray(); foreach Entry'), None, literal('entries')),
 'lineage-unknown-array': (lineage_call.replace("RequestJson.Get('entries', Token);", "Unknown.Get('entries', Token);"), None, literal('entries')),
 'lineage-unrelated-helper': ("        ReadEntry(Argument, Unrelated.AsObject());", None, literal('entries')),
 'lineage-comment-decoy': (lineage_call.replace("RequestJson.Get('entries', Token);", "// RequestJson.Get('entries', Token);\n        Unknown.Get('entries', Token);"), None, literal('entries')),
}
for name, (execute, expected, contract) in lineage_cases.items():
 cases.append((name, contract, execute, expected, ''))
runtime_source = '''codeunit 5 "Fixture Runtime"
{
    TableNo = "Message Argument ori";
    var
        OtherMode: Boolean;
    trigger OnRun()
    var
        RequestJson: JsonObject;
    begin
        RequestJson := Rec.GetRequestJson();
        if OtherMode then
            RequestJson.Contains('otherKey')
        else
            RequestJson.Contains('selectedKey');
    end;
    procedure SetOtherMode()
    begin
        OtherMode := true;
    end;
}
'''
context_cases = {
 'context-literal-bool-setter': (runtime_source.replace('SetOtherMode()', 'SetOtherMode(Value: Boolean)').replace('OtherMode := true;', 'OtherMode := Value;'), '        Worker.SetOtherMode(true); Worker.Run(Argument);', [], 'otherKey'),
 'context-dynamic-bool-setter': (runtime_source.replace('SetOtherMode()', 'SetOtherMode(Value: Boolean)').replace('OtherMode := true;', 'OtherMode := Value;'), '        Worker.SetOtherMode(DynamicMode); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-label-before-shadow': (runtime_source.replace('RequestJson: JsonObject;', "BeforeLbl: Label 'begin'; OtherMode: Boolean; RequestJson: JsonObject;"), '        Worker.SetOtherMode(); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-default-local': (runtime_source, '        Worker.Run(Argument);', [], 'selectedKey'),
 'context-setter-local': (runtime_source, '        Worker.SetOtherMode(); Worker.Run(Argument);', [], 'otherKey'),
 'context-conditional-setter': (runtime_source, '        if UnknownFlag then Worker.SetOtherMode(); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-setter-after-run': (runtime_source, '        Worker.Run(Argument); Worker.SetOtherMode(); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-single-instance': (runtime_source.replace('TableNo =', 'SingleInstance = true;\n    TableNo ='), '        Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-complex-setter': (runtime_source.replace('OtherMode := true;', 'OtherMode := true; Touch();'), '        Worker.SetOtherMode(); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-unknown-mutator': (runtime_source.replace('if OtherMode then', 'Mutate(OtherMode);\n        if OtherMode then'), '        Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-internal-setter': (runtime_source.replace('if OtherMode then', 'SetOtherMode();\n        if OtherMode then'), '        Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-cleared-instance': (runtime_source, '        Worker.SetOtherMode(); Clear(Worker); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-escaped-instance': (runtime_source, '        Mutate(Worker); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-two-instances': (runtime_source, '        Worker.SetOtherMode(); Worker.Run(Argument); OtherWorker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-global-instance': (runtime_source, '        Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
 'context-shadowed-flag': (runtime_source.replace('RequestJson: JsonObject;', 'RequestJson: JsonObject; OtherMode: Boolean;'), '        Worker.SetOtherMode(); Worker.Run(Argument);', ['read-not-declared|otherKey'], 'selectedKey'),
}
selector_runtime = '''    local procedure ReadSelected(Request: JsonObject; Operation: Text)
    begin
        case Operation of
            'Selected':
                Request.Contains('selectedKey');
            'Other':
                Request.Contains('otherKey');
            else
                Request.Contains('fallbackKey');
        end;
    end;
'''
context_selector_cases = {
 'context-code-parameter': (selector_runtime.replace('Operation: Text', 'Operation: Code[20]'), "        ReadSelected(RequestJson, 'Selected');", ['read-not-declared|otherKey','read-not-declared|fallbackKey'], 'selectedKey'),
 'context-bounded-text-parameter': (selector_runtime.replace('Operation: Text', 'Operation: Text[20]'), "        ReadSelected(RequestJson, 'Selected');", ['read-not-declared|otherKey','read-not-declared|fallbackKey'], 'selectedKey'),
 'context-literal-case': (selector_runtime, "        ReadSelected(RequestJson, 'Selected');", [], 'selectedKey'),
 'context-case-default': (selector_runtime, "        ReadSelected(RequestJson, 'Missing');", [], 'fallbackKey'),
 'context-case-dynamic': (selector_runtime, '        ReadSelected(RequestJson, DynamicOperation);', ['read-not-declared|otherKey','read-not-declared|fallbackKey'], 'selectedKey'),
 'context-case-mixed': (selector_runtime, "        ReadSelected(RequestJson, 'Selected'); ReadSelected(RequestJson, DynamicOperation);", ['read-not-declared|otherKey','read-not-declared|fallbackKey'], 'selectedKey'),
 'context-case-mutated': (selector_runtime.replace('case Operation of', "Operation := 'Other';\n        case Operation of"), "        ReadSelected(RequestJson, 'Selected');", ['read-not-declared|Selected','read-not-declared|otherKey','read-not-declared|fallbackKey'], 'selectedKey'),
 'context-case-nested': (selector_runtime.replace("Request.Contains('selectedKey');", "begin\n                    if UnknownFlag then begin Request.Contains('selectedKey'); end;\n                end;"), "        ReadSelected(RequestJson, 'Selected');", [], 'selectedKey'),
 'context-chained-selector': (selector_runtime, "        ReadSelected(RequestJson, 'Selected'); GetUnknown().ReadSelected(RequestJson, 'Other');", ['read-not-declared|otherKey','read-not-declared|fallbackKey','read-not-declared|Other'], 'selectedKey'),
 'context-case-label-text': (selector_runtime.replace("Request.Contains('selectedKey');", "begin Request.Contains('selectedKey'); Error('case end else begin'); end;"), "        ReadSelected(RequestJson, 'Selected');", [], 'selectedKey'),
}
for name, (_, execute, expected, key) in {**context_cases, **context_selector_cases}.items():
 cases.append((name, literal(key), execute, expected, ''))
envelope_runtime = '''codeunit 5 "Fixture Runtime"
{
    TableNo = "Message Argument ori";
    trigger OnRun()
    var
        RequestJson: JsonObject;
    begin
        case Rec.Type of
            "Message Type ori"::"Fixture.Selected":
                begin
                    RequestJson := Rec.GetRequestJson();
                    RequestJson.Contains('selectedKey');
                end;
            "Message Type ori"::"Fixture.Other":
                begin
                    RequestJson := Rec.GetRequestJson();
                    RequestJson.Contains('otherKey');
                end;
            else
                Rec.TestField(Type, "Message Type ori"::"Fixture.Selected");
        end;
    end;
}
'''
envelope_call = '        Codeunit.Run(Codeunit::"Fixture Runtime", Argument);'
envelope_cases = {
 'envelope-type-var-escape': (envelope_runtime, '        MutateType(Argument.Type);\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-type-value-copy': (envelope_runtime, '        ReadType(Argument.Type);\n' + envelope_call, []),
 'envelope-type-unknown-consumer': (envelope_runtime, '        UnknownType(Argument.Type);\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-chained-record-escape': (envelope_runtime, '        GetUnknown().Mutate(Argument);\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-chained-type-escape': (envelope_runtime, '        GetUnknown().MutateType(Argument.Type);\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-content-type-write': (envelope_runtime, envelope_call, []),
 'envelope-copy-source': (envelope_runtime, envelope_call, []),
 'envelope-enum-identifier-case': (envelope_runtime.replace('"Fixture.Selected":', '"fixture.selected":'), envelope_call, []),
 'envelope-implicit-init': (envelope_runtime, envelope_call, ['read-not-declared|otherKey']),
 'envelope-trigger-type-write': (envelope_runtime, envelope_call, ['read-not-declared|otherKey']),
 'envelope-direct': (envelope_runtime, envelope_call, []),
 'envelope-type-write': (envelope_runtime, '        Argument.Type := "Message Type ori"::"Fixture.Other";\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-clear-record': (envelope_runtime, '        Clear(Argument);\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-unknown-method': (envelope_runtime, '        Argument.UnknownMethod();\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-mutated-before-case': (envelope_runtime.replace('case Rec.Type of', 'Rec.Type := "Message Type ori"::"Fixture.Other";\n        case Rec.Type of'), envelope_call, ['read-not-declared|otherKey']),
 'envelope-source-helper-write': (envelope_runtime, '        MutateEnvelope(Argument);\n' + envelope_call, ['read-not-declared|otherKey']),
 'envelope-readonly-helper': (envelope_runtime, '        ReadEnvelope(Argument);\n' + envelope_call, []),
 'envelope-duplicate-variable-type': (envelope_runtime, '        Guard.Check(Argument);\n' + envelope_call, []),
}
for name, (_, execute, expected) in envelope_cases.items():
 cases.append((name, literal('selectedKey'), execute, expected, ''))
rejection_body = '''    local procedure RejectInput(Request: JsonObject; Name: Text)
    begin
        if ReadText(Request, Name) <> '' then
            Error('Unsupported input');
    end;
    local procedure ReadText(Request: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Request.Get(Name, Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;
'''
rejection_execute = "        RejectInput(RequestJson, 'badKey');\n" + read('selectedKey')
rejection_cases = {
 'rejection-readonly-condition': (rejection_body, rejection_execute, [], literal('selectedKey')),
 'rejection-other-read-retained': (rejection_body, rejection_execute + '\n' + read('badKey'), ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-unknown-consumer': (rejection_body.replace('if not Request.Get', 'Mutate(Request);\n        if not Request.Get'), rejection_execute, ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-reader-side-effect': (rejection_body.replace('if not Request.Get', 'WriteBusinessData();\n        if not Request.Get'), rejection_execute, ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-extra-success-work': (rejection_body.replace("Error('Unsupported input');", "Error('Unsupported input');\n        Consume(Request);"), rejection_execute, ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-not-empty-test': (rejection_body.replace("<> '' then", "= 'supported' then"), rejection_execute, ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-shadowed-error': (rejection_body + "    local procedure Error(Value: Text)\n    begin\n        Message(Value);\n    end;\n", rejection_execute, ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-chained-callee': (rejection_body, "        GetUnknown().RejectInput(RequestJson, 'badKey');\n" + read('selectedKey'), ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-unknown-callee': ('', rejection_execute, ['read-not-declared|badKey'], literal('selectedKey')),
 'rejection-declared-unsupported': (rejection_body, rejection_execute, ['declared-not-read|badKey'], literal('selectedKey') + "\n        Parameters.ReadFrom('[{\"name\":\"selectedKey\"},{\"name\":\"badKey\"}]');"),
}
for name, (_, execute, expected, contract) in rejection_cases.items():
 cases.append((name, contract, execute, expected, ''))
dependency_cases = {
 'dependency-source': [],
 'dependency-extra-key': ['read-not-declared|extraKey'],
 'dependency-missing-source': ['declared-not-read|selectedKey','no-reads-seen|*'],
 'dependency-name-collision': None,
}
for name, expected in dependency_cases.items():
 cases.append((name, literal('selectedKey'), '        Lookup.Read(RequestJson);', expected, ''))
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
 if name in lineage_cases:
  impl = root/'src'/'Impl.al'
  text = impl.read_text()
  impl.write_text(text.rsplit('}', 1)[0] + lineage_body + '}\n')
 if name in context_cases:
  runtime, _, _, _ = context_cases[name]
  (root/'src'/'Runtime.al').write_text(runtime)
  impl = root/'src'/'Impl.al'
  text = impl.read_text()
  declarations = '        Worker: Codeunit "Fixture Runtime"; OtherWorker: Codeunit "Fixture Runtime";\n'
  if name == 'context-global-instance':
   text = text.replace('codeunit 2 "Fixture Impl"\n{', 'codeunit 2 "Fixture Impl"\n{\n    var\n' + declarations)
  else:
   text = text.replace('        RequestJson: JsonObject;', declarations + '        RequestJson: JsonObject;', 1)
  impl.write_text(text)
 if name in context_selector_cases:
  impl = root/'src'/'Impl.al'
  text = impl.read_text()
  impl.write_text(text.rsplit('}', 1)[0] + context_selector_cases[name][0] + '}\n')
 if name in envelope_cases:
  (root/'src'/'Runtime.al').write_text(envelope_cases[name][0])
  dependency = root.parent/'dependency'/'src'
  dependency.mkdir(parents=True)
  (dependency/'Argument.al').write_text('table 8 "Message Argument ori"\n{\n    procedure GetRequestJson() RequestJson: JsonObject\n    begin\n    end;\n}\n')
  if name == 'envelope-implicit-init':
   arg = dependency/'Argument.al'
   arg.write_text(arg.read_text().replace('    begin\n', '    begin\n        Init();\n', 1))
  if name == 'envelope-trigger-type-write':
   arg = dependency/'Argument.al'
   text = arg.read_text().replace('    begin\n', '    begin\n        Modify(true);\n', 1)
   trigger = '    trigger OnModify()\n    begin\n        Type := "Message Type ori"::"Fixture.Other";\n    end;\n'
   arg.write_text(text.rsplit('}', 1)[0] + trigger + '}\n')
  if name == 'envelope-content-type-write':
   arg = dependency/'Argument.al'
   arg.write_text(arg.read_text().replace('    begin\n', '    begin\n        "Content Type" := \'text/json\';\n', 1))
  if name == 'envelope-copy-source':
   arg = dependency/'Argument.al'
   arg.write_text(arg.read_text().replace('    begin\n', '    var\n        Other: Record "Message Argument ori";\n    begin\n        Other.Copy(Rec, true);\n', 1))
  if name in ('envelope-type-var-escape','envelope-type-value-copy'):
   impl = root/'src'/'Impl.al'
   text = impl.read_text()
   method = 'MutateType' if name == 'envelope-type-var-escape' else 'ReadType'
   modifier = 'var ' if name == 'envelope-type-var-escape' else ''
   method_body = '    local procedure ' + method + '(' + modifier + 'Value: Enum "Message Type ori")\n    begin\n        Value := "Message Type ori"::"Fixture.Other";\n    end;\n'
   impl.write_text(text.rsplit('}', 1)[0] + method_body + '}\n')
  if name == 'envelope-duplicate-variable-type':
   (dependency/'Guard.al').write_text('codeunit 9 "Envelope Guard"\n{\n    procedure Check(var Argument: Record "Message Argument ori")\n    begin\n        Message(\'%1\', Argument.Type);\n    end;\n}\n')
   impl = root/'src'/'Impl.al'
   text = impl.read_text().replace('        RequestJson: JsonObject;', '        Guard: Codeunit "Envelope Guard";\n        RequestJson: JsonObject;', 1).replace('        ParameterJson: JsonObject;', '        Guard: Codeunit "Envelope Guard";\n        ParameterJson: JsonObject;', 1)
   impl.write_text(text)
  if name in ('envelope-source-helper-write','envelope-readonly-helper'):
   impl = root/'src'/'Impl.al'
   text = impl.read_text()
   body = 'Argument.Type := "Message Type ori"::"Fixture.Other";' if name == 'envelope-source-helper-write' else "Message('%1', Argument.Type);"
   method = 'MutateEnvelope' if name == 'envelope-source-helper-write' else 'ReadEnvelope'
   helper_body = '    local procedure ' + method + '(var Argument: Record "Message Argument ori")\n    begin\n        ' + body + '\n    end;\n'
   impl.write_text(text.rsplit('}', 1)[0] + helper_body + '}\n')
 if name in rejection_cases:
  impl = root/'src'/'Impl.al'
  text = impl.read_text()
  impl.write_text(text.rsplit('}', 1)[0] + rejection_cases[name][0] + '}\n')
 if name in dependency_cases:
  impl = root/'src'/'Impl.al'
  impl.write_text(impl.read_text().replace('        RequestJson: JsonObject;', '        Lookup: Codeunit "External Lookup";\n        RequestJson: JsonObject;', 1))
  if name != 'dependency-missing-source':
   dependency = root.parent/'dependency'/'src'
   dependency.mkdir(parents=True)
   extra = "        Request.Contains('extraKey');" if name == 'dependency-extra-key' else ''
   lookup = 'Fixture Impl' if name == 'dependency-name-collision' else 'External Lookup'
   (dependency/'Lookup.al').write_text('codeunit 6 "' + lookup + '"\n{\n    procedure Read(Request: JsonObject)\n    begin\n        Request.Contains(\'selectedKey\');\n' + extra + '\n    end;\n}\n')
   # Dependency registrations are not part of the selected app's scan.
   (dependency/'Types.al').write_text((root/'src'/'Types.al').read_text().replace('Fixture.Selected','Dependency.Broken').replace('enum 1 "Message Type ori"','enum 7 "Dependency Message Types"'))
 r=run('Test-ContractParameterKeys.ps1',root,'fixture-'+name)
 found=re.findall(r'New offender .*?: Fixture.Selected\|([^\n]+)',r.stdout)
 if name == 'dependency-name-collision': ok=r.returncode==1 and 'Duplicate AL object name' in r.stderr
 elif expected is None: ok=r.returncode==1 and any(x.startswith('dynamic-ambiguity|typed-reader:') for x in found)
 else: ok=sorted(found)==sorted(expected) and r.returncode==(1 if expected else 0)
 results.append(dict(name=name,passed=ok,exitCode=r.returncode,expected=expected,actual=found))
 print(name,ok,found if not ok else '')
print(json.dumps({'total':len(results),'passed':sum(x['passed'] for x in results),'failed':sum(not x['passed'] for x in results)}))
failed = [x for x in results if not x['passed']]
shutil.rmtree(root)
assert not failed, json.dumps(failed)

# Keep the payload/branch counterexamples in the existing SourceGuards command.
# Workflow ownership and production guard wiring are unchanged.
import sys
extension_results = []
tests_folder = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='inventory-contract-source-extensions-') as extension_tmp:
    extension_root = Path(extension_tmp)
    for filename in ['Test-RequestPayloadProof.ps1', 'Test-ContractBranchParser.ps1']:
        result_file = extension_root / (filename + '.json')
        result = subprocess.run([pw, '-NoProfile', '-File', str(tests_folder / filename),
                                 '-Scanner', str(script), '-OutputPath', str(result_file)],
                                capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
        report = json.loads(result_file.read_text(encoding='utf-8-sig'))
        assert report['executed'] > 0 and report['failed'] == report['skipped'] == 0, report
        extension_results.append({key: value for key, value in report.items() if key != 'results'})
    oracle_env = dict(os.environ, PWSH=pw, CONTRACT_PARAMETER_SCANNER=str(script))
    result = subprocess.run([sys.executable, '-I', str(tests_folder / 'test-request-payload-source-oracle.py')],
                            capture_output=True, text=True, env=oracle_env)
    assert result.returncode == 0, result.stdout + result.stderr
    oracle = json.loads(result.stdout)
    assert oracle['passed'] and oracle['missing'] == oracle['unsoundExclusionsFound'] == 0, oracle
    extension_results.append(oracle)
assert not extension_root.exists()
print(json.dumps({'kind': 'additional source regressions; not AL runtime tests',
                  'ownedFixtureCleanupVerified': True, 'families': extension_results}))
