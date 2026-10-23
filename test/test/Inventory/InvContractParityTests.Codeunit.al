namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Completeness guard for the contract and discovery of every Inventory message type, as Foundation does for its own
/// types: every chapter is declared, every error carries a machine code, the direction matches the effect and the
/// discovery texts exist in English and Icelandic. A type added later fails here until it is complete.
/// </summary>
codeunit 96970 "Inv. Contract Parity Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Every Inventory type declares the envelope, target, response, errors, effect, related, overview, notes and examples chapters.</summary>
    [Test]
    procedure EveryType_DeclaresEveryRequiredChapter()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
        TypeCount: Integer;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' has a contract.');
            Assert.IsTrue(Contract.Contains('envelope'), TypeName + ' declares the envelope.');
            if PinnedNoTargetTypes().Contains(TypeName) then
                Assert.IsFalse(Contract.Contains('target'), TypeName + ' addresses no record and an existing test pins its target as absent.')
            else
                Assert.IsTrue(Contract.Contains('target'), TypeName + ' declares the target.');
            Assert.IsTrue(Contract.Contains('response'), TypeName + ' declares the response.');
            Assert.IsTrue(Contract.Contains('errors'), TypeName + ' declares the errors.');
            Assert.IsTrue(Contract.Contains('effect'), TypeName + ' declares the effect.');
            Assert.IsTrue(Contract.Contains('metering'), TypeName + ' has the metering chapter.');
            Assert.IsTrue(Contract.Contains('related'), TypeName + ' declares the related types.');
            Assert.AreNotEqual('', TextOf(Contract, 'overview'), TypeName + ' declares the overview.');
            if PinnedNoNotesTypes().Contains(TypeName) then
                Assert.IsFalse(Contract.Contains('notes'), TypeName + ' has no notes and an existing test pins that.')
            else
                Assert.AreNotEqual('', TextOf(Contract, 'notes'), TypeName + ' declares the notes.');
            Assert.IsTrue(ArrayOf(Contract, 'related').Count() > 0, TypeName + ' names at least one related type.');
            if PinnedNoExamplesTypes().Contains(TypeName) then
                Assert.IsFalse(Contract.Contains('examples'), TypeName + ' has no examples and an existing test pins that.')
            else
                Assert.IsTrue(ArrayOf(Contract, 'examples').Count() > 0, TypeName + ' declares at least one example.');
            if NoParameterTypes().Contains(TypeName) then
                Assert.IsFalse(Contract.Contains('parameters'), TypeName + ' reads no data key, so it declares no parameters.')
            else
                Assert.IsTrue(ArrayOf(Contract, 'parameters').Count() > 0, TypeName + ' declares its parameters.');
            TypeCount += 1;
        end;
        Assert.IsTrue(TypeCount >= 59, 'Every Inventory type is checked.');
    end;

    /// <summary>The envelope states how subject is used, the version and the content type of the answer.</summary>
    [Test]
    procedure EveryEnvelope_StatesSubjectVersionAndContentType()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Envelope: JsonObject;
        Subject: JsonObject;
        Token: JsonToken;
        TypeName: Text;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            Contract.Get('envelope', Token);
            Envelope := Token.AsObject();
            Assert.IsTrue(Envelope.Get('subject', Token), TypeName + ' envelope describes the subject.');
            Subject := Token.AsObject();
            Assert.IsTrue(TextOf(Subject, 'use') in ['required', 'optional', 'notUsed'], TypeName + ' envelope subject use is required, optional or notUsed.');
            Assert.IsTrue(Envelope.Contains('dataRequired'), TypeName + ' envelope states whether data is required.');
            Assert.AreNotEqual('', TextOf(Envelope, 'version'), TypeName + ' envelope states the version.');
            Assert.AreNotEqual('', TextOf(Envelope, 'contentType'), TypeName + ' envelope states the content type.');
        end;
    end;

    /// <summary>Every type that changes data, or previews a change, declares a workflow; only the plain reads may leave it out.</summary>
    [Test]
    procedure EveryChangingType_DeclaresAWorkflow()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Implementation: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Workflow: JsonObject;
        Steps: JsonArray;
        Step: JsonToken;
        Token: JsonToken;
        TypeName: Text;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Implementation := MessageType;
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            Contract.Get('effect', Token);
            Effect := Token.AsObject();
            if Contract.Get('workflow', Token) then begin
                Workflow := Token.AsObject();
                Steps := ArrayOf(Workflow, 'steps');
                Assert.IsTrue(Steps.Count() > 0, TypeName + ' workflow has steps.');
                foreach Step in Steps do begin
                    Assert.AreNotEqual('', TextOf(Step.AsObject(), 'messageType'), TypeName + ' workflow step names a message type.');
                    Assert.AreNotEqual('', TextOf(Step.AsObject(), 'purpose'), TypeName + ' workflow step has a purpose.');
                end;
            end else
                Assert.IsTrue(((TextOf(Effect, 'effect') = 'read') and (Implementation.GetMessageDirection() = Enum::"Msg Direction ori"::Outbound)) or PinnedNoWorkflowTypes().Contains(TypeName), TypeName + ' changes or previews data, so it declares a workflow.');
        end;
    end;

    /// <summary>Every error entry carries a machine code that exists, the condition and what to do; an entry without a code carries the error text.</summary>
    [Test]
    procedure EveryErrorEntry_CarriesCodeConditionAndFix()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Entry: JsonToken;
        ErrorCodes: List of [Text];
        TypeName: Text;
        EntryCode: Text;
        EntryCount: Integer;
    begin
        ErrorCodes := Enum::"Bifrost Error Code ori".Names();
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            Assert.IsTrue(ArrayOf(Contract, 'errors').Count() > 0, TypeName + ' lists its errors.');
            foreach Entry in ArrayOf(Contract, 'errors') do begin
                EntryCode := TextOf(Entry.AsObject(), 'code');
                if EntryCode = '' then
                    Assert.AreNotEqual('', TextOf(Entry.AsObject(), 'error'), TypeName + ' error entry without a code carries the error text.')
                else
                    Assert.IsTrue(ErrorCodes.Contains(EntryCode), TypeName + ' error code ' + EntryCode + ' exists.');
                Assert.AreNotEqual('', TextOf(Entry.AsObject(), 'when'), TypeName + ' error ' + EntryCode + ' states when it is answered.');
                Assert.AreNotEqual('', TextOf(Entry.AsObject(), 'fix'), TypeName + ' error ' + EntryCode + ' states what to do.');
                EntryCount += 1;
            end;
        end;
        Assert.IsTrue(EntryCount >= 59, 'Error entries were checked.');
    end;

    /// <summary>
    /// The direction matches the effect: plain reads are Outbound, changes are Inbound (or Both when a type is used
    /// both ways), and the types that run a request but only read (previews, checks, tests, statistics) stay Inbound.
    /// A direction is never narrowed: Both is always accepted for a changing type.
    /// </summary>
    [Test]
    procedure EveryType_DirectionMatchesEffect()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Implementation: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        EffectObject: JsonObject;
        Token: JsonToken;
        TypeName: Text;
        EffectKind: Text;
        Direction: Enum "Msg Direction ori";
        DirectionMatches: Boolean;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Implementation := MessageType;
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            Contract.Get('effect', Token);
            EffectObject := Token.AsObject();
            EffectKind := TextOf(EffectObject, 'effect');
            Assert.IsTrue(EffectKind in ['read', 'write', 'irreversible'], TypeName + ' effect is read, write or irreversible.');
            Assert.AreNotEqual('', TextOf(EffectObject, 'changes'), TypeName + ' effect states what changes.');
            Assert.AreNotEqual('', TextOf(EffectObject, 'permissionSet'), TypeName + ' effect names the permission set.');
            Assert.IsTrue(EffectObject.Contains('idempotent'), TypeName + ' effect states whether it is idempotent.');
            Direction := Implementation.GetMessageDirection();
            if EffectKind = 'read' then
                DirectionMatches := (Direction = Enum::"Msg Direction ori"::Outbound) or ((Direction = Enum::"Msg Direction ori"::Inbound) and ReadRequestTypes().Contains(TypeName))
            else
                DirectionMatches := (Direction = Enum::"Msg Direction ori"::Inbound) or (Direction = Enum::"Msg Direction ori"::Both);
            Assert.IsTrue(DirectionMatches, TypeName + ' direction matches the ' + EffectKind + ' effect.');
        end;
    end;

    /// <summary>Every parameter is declared with a name, a JSON type and a description, and every array of objects lists its children.</summary>
    [Test]
    procedure EveryParameter_IsDescribed()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Parameter: JsonToken;
        TypeName: Text;
        ParameterName: Text;
        ParameterCount: Integer;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            foreach Parameter in ArrayOf(Contract, 'parameters') do begin
                ParameterName := TextOf(Parameter.AsObject(), 'name');
                Assert.AreNotEqual('', ParameterName, TypeName + ' parameter has a name.');
                AssertParameterDescribed(Parameter.AsObject(), TypeName, ParameterName);
                ParameterCount += 1;
            end;
        end;
        Assert.IsTrue(ParameterCount >= 59, 'Parameters were checked.');
    end;

    /// <summary>Every response chapter lists fields with a name, a type and a description; every example is a real request and response object.</summary>
    [Test]
    procedure ResponseAndExamples_AreComplete()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        ResponseObject: JsonObject;
        Token: JsonToken;
        Field: JsonToken;
        Example: JsonToken;
        TypeName: Text;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            Contract.Get('response', Token);
            ResponseObject := Token.AsObject();
            Assert.IsTrue(ArrayOf(ResponseObject, 'fields').Count() > 0, TypeName + ' response lists fields.');
            foreach Field in ArrayOf(ResponseObject, 'fields') do begin
                Assert.AreNotEqual('', TextOf(Field.AsObject(), 'name'), TypeName + ' response field has a name.');
                Assert.AreNotEqual('', TextOf(Field.AsObject(), 'type'), TypeName + ' response field ' + TextOf(Field.AsObject(), 'name') + ' has a type.');
                Assert.AreNotEqual('', TextOf(Field.AsObject(), 'description'), TypeName + ' response field ' + TextOf(Field.AsObject(), 'name') + ' has a description.');
            end;
            foreach Example in ArrayOf(Contract, 'examples') do begin
                Assert.AreNotEqual('', TextOf(Example.AsObject(), 'title'), TypeName + ' example has a title.');
                Assert.IsTrue(Example.AsObject().Get('request', Token), TypeName + ' example has a request.');
                Assert.IsTrue(Token.IsObject(), TypeName + ' example request is a JSON object.');
                AssertExampleRequest(Token.AsObject(), TypeName);
                Assert.IsTrue(Example.AsObject().Get('response', Token), TypeName + ' example has a response.');
                Assert.IsTrue(Token.IsObject(), TypeName + ' example response is a JSON object.');
            end;
        end;
    end;

    /// <summary>Every related type, and every workflow step, names a message type that exists.</summary>
    [Test]
    procedure RelatedAndWorkflow_NameExistingTypes()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        TypeNames: List of [Text];
        TypeName: Text;
    begin
        TypeNames := Enum::"Message Type ori".Names();
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            foreach Entry in ArrayOf(Contract, 'related') do begin
                Assert.IsTrue(TypeNames.Contains(TextOf(Entry.AsObject(), 'name')), TypeName + ' related type exists: ' + TextOf(Entry.AsObject(), 'name'));
                Assert.AreNotEqual('', TextOf(Entry.AsObject(), 'useInsteadWhen'), TypeName + ' related type says when to use it.');
            end;
            if Contract.Get('workflow', Token) then
                foreach Entry in ArrayOf(Token.AsObject(), 'steps') do
                    Assert.IsTrue(TypeNames.Contains(TextOf(Entry.AsObject(), 'messageType')), TypeName + ' workflow step type exists: ' + TextOf(Entry.AsObject(), 'messageType'));
        end;
    end;

    /// <summary>Every type has a description, a selection description and keywords in English and in Icelandic, and the Icelandic texts are translated.</summary>
    [Test]
    procedure EveryType_DiscoveryTextsExistInBothLanguages()
    var
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        OriginalLanguage: Integer;
        TypeName: Text;
        EnglishDescription: Text;
        EnglishSelection: Text;
        EnglishKeywords: Text;
        TypeCount: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Implementation := MessageType;
            Discovery := MessageType;
            GlobalLanguage(1033);
            EnglishDescription := Implementation.GetDescription();
            EnglishSelection := Discovery.GetSelectionDescription();
            EnglishKeywords := Discovery.GetKeywords();
            GlobalLanguage(1039);
            Assert.AreNotEqual('', EnglishDescription, TypeName + ' has a description.');
            Assert.AreNotEqual('', EnglishSelection, TypeName + ' has a selection description.');
            Assert.AreNotEqual('', EnglishKeywords, TypeName + ' has keywords.');
            Assert.AreNotEqual('', Implementation.GetDescription(), TypeName + ' has an Icelandic description.');
            Assert.AreNotEqual(EnglishDescription, Implementation.GetDescription(), TypeName + ' description is translated.');
            Assert.AreNotEqual(EnglishSelection, Discovery.GetSelectionDescription(), TypeName + ' selection description is translated.');
            Assert.AreNotEqual(EnglishKeywords, Discovery.GetKeywords(), TypeName + ' keywords are translated.');
            GlobalLanguage(OriginalLanguage);
            TypeCount += 1;
        end;
        GlobalLanguage(OriginalLanguage);
        Assert.IsTrue(TypeCount >= 59, 'Every Inventory type is checked.');
    end;

    /// <summary>The notes and overview of every type name no AL object and no internal procedure.</summary>
    [Test]
    procedure NotesAndOverview_NameNoAlObjects()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
    begin
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            AssertNamesNoAlObject(TextOf(Contract, 'notes'), TypeName + ' notes');
            AssertNamesNoAlObject(TextOf(Contract, 'overview'), TypeName + ' overview');
        end;
    end;

    local procedure AssertParameterDescribed(Parameter: JsonObject; TypeName: Text; ParameterName: Text)
    var
        Child: JsonToken;
        JsonType: Text;
    begin
        JsonType := TextOf(Parameter, 'type');
        Assert.AreNotEqual('', JsonType, TypeName + ' parameter ' + ParameterName + ' has a type.');
        Assert.IsTrue(JsonType in ['string', 'number', 'integer', 'decimal', 'boolean', 'object', 'array'], TypeName + ' parameter ' + ParameterName + ' has a JSON type: ' + JsonType);
        Assert.AreNotEqual('', TextOf(Parameter, 'description'), TypeName + ' parameter ' + ParameterName + ' has a description.');
        if JsonType = 'array' then
            if not ScalarArrayParameters().Contains(TypeName + '|' + ParameterName) then
                Assert.IsTrue(ArrayOf(Parameter, 'children').Count() > 0, TypeName + ' array parameter ' + ParameterName + ' lists its children.');
        foreach Child in ArrayOf(Parameter, 'children') do
            AssertParameterDescribed(Child.AsObject(), TypeName, ParameterName + '.' + TextOf(Child.AsObject(), 'name'));
    end;

    local procedure AssertExampleRequest(Request: JsonObject; TypeName: Text)
    var
        RequestKey: Text;
        RequestType: Text;
    begin
        foreach RequestKey in Request.Keys() do
            Assert.IsTrue(RequestKey in ['type', 'subject', 'data'], TypeName + ' example request key ' + RequestKey + ' is part of the request envelope.');
        RequestType := TextOf(Request, 'type');
        if TypeName in ['Inventory.PhysInventory.Record', 'Inventory.PhysInventory.RecordCount'] then
            Assert.IsTrue(RequestType in ['Inventory.PhysInventory.Record', 'Inventory.PhysInventory.RecordCount'], TypeName + ' example request names Record or RecordCount.')
        else
            Assert.AreEqual(TypeName, RequestType, TypeName + ' example request names its own type.');
    end;

    local procedure AssertNamesNoAlObject(HelpText: Text; Context: Text)
    var
        Forbidden: Text;
    begin
        Forbidden := FindAlReference(HelpText);
        Assert.AreEqual('', Forbidden, Context + ' names an AL object or internal procedure: "' + Forbidden + '"');
    end;

    local procedure FindAlReference(HelpText: Text): Text
    var
        Lowered: Text;
        Fragment: Text;
        ObjectWord: Text;
    begin
        Lowered := LowerCase(HelpText);
        foreach Fragment in ForbiddenFragments() do
            if Lowered.Contains(LowerCase(Fragment)) then
                exit(Fragment);
        foreach ObjectWord in ObjectWords() do begin
            Fragment := NumberedObject(Lowered, ObjectWord);
            if Fragment <> '' then
                exit(Fragment);
        end;
        exit('');
    end;

    local procedure ForbiddenFragments() Fragments: List of [Text]
    begin
        Fragments.Add('codeunit');
        Fragments.Add('Impl ori');
        Fragments.Add('Helper ori');
        Fragments.Add('Context ori');
        Fragments.Add('Lookup ori');
        Fragments.Add('Parts ori');
        Fragments.Add('Gate ori');
        Fragments.Add('Process ori');
        Fragments.Add('Dispatcher.');
        Fragments.Add('OmitCommit');
        Fragments.Add('BC report');
        Fragments.Add('BC table');
        Fragments.Add('BC page');
    end;

    local procedure ObjectWords() Words: List of [Text]
    begin
        Words.Add('report ');
        Words.Add('table ');
        Words.Add('page ');
        Words.Add('xmlport ');
        Words.Add('query ');
    end;

    local procedure NumberedObject(Lowered: Text; ObjectWord: Text): Text
    var
        Position: Integer;
        Offset: Integer;
        NextChar: Text;
    begin
        Offset := 0;
        Position := StrPos(Lowered, ObjectWord);
        while Position > 0 do begin
            NextChar := CopyStr(Lowered, Offset + Position + StrLen(ObjectWord), 1);
            if (NextChar <> '') and (StrPos('0123456789', NextChar) > 0) then
                exit(CopyStr(Lowered, Offset + Position, StrLen(ObjectWord) + 5));
            Offset += Position + StrLen(ObjectWord) - 1;
            Position := StrPos(CopyStr(Lowered, Offset + 1), ObjectWord);
        end;
        exit('');
    end;

    local procedure InventoryTypes() Types: List of [Enum "Message Type ori"]
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        Names := Enum::"Message Type ori".Names();
        Ordinals := Enum::"Message Type ori".Ordinals();
        for Index := 1 to Names.Count() do
            if (Ordinals.Get(Index) >= AppRangeFrom()) and (Ordinals.Get(Index) <= AppRangeTo()) then
                Types.Add(Enum::"Message Type ori".FromInteger(Ordinals.Get(Index)));
    end;

    /// <summary>The first value of the object range of this app: every message type of this app has its implementation id as value.</summary>
    local procedure AppRangeFrom(): Integer
    begin
        exit(10076835);
    end;

    /// <summary>The last value of the object range of this app.</summary>
    local procedure AppRangeTo(): Integer
    begin
        exit(10077034);
    end;

    local procedure TypeNameOf(MessageType: Enum "Message Type ori"): Text
    begin
        exit(Enum::"Message Type ori".Names().Get(Enum::"Message Type ori".Ordinals().IndexOf(MessageType.AsInteger())));
    end;

    /// <summary>Types that run as an Inbound request but only read: previews, checks, tests and statistics.</summary>
    local procedure ReadRequestTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.AssemblyOrder.PreviewPost');
        Names.Add('Inventory.AssemblyOrder.Statistics');
        Names.Add('Inventory.CostToGL.Test');
        Names.Add('Inventory.PhysInventory.Check');
        Names.Add('Inventory.PhysInventory.PreviewPost');
        Names.Add('Inventory.Reclassification.Check');
        Names.Add('Inventory.Reclassification.PreviewPost');
        Names.Add('Inventory.Revaluation.PreviewPost');
        Names.Add('Inventory.TransferOrder.PreviewPost');
        Names.Add('Inventory.TransferOrder.Statistics');
        Names.Add('Inventory.Transfer.UndoReceipt');
    end;

    /// <summary>Types that read no data key beyond the identifiers of their target, so they declare no parameters.</summary>
    local procedure NoParameterTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.Period.Get');
        Names.Add('Inventory.TransferOrder.Release');
        Names.Add('Inventory.TransferOrder.Reopen');
        Names.Add('Inventory.TransferOrder.Statistics');
        Names.Add('Inventory.AssemblyOrder.RefreshLines');
        Names.Add('Inventory.AssemblyOrder.Release');
        Names.Add('Inventory.AssemblyOrder.Reopen');
        Names.Add('Inventory.AssemblyOrder.PreviewPost');
        Names.Add('Inventory.AssemblyOrder.Statistics');
    end;

    /// <summary>Array parameters whose items are plain values, so they have no children.</summary>
    local procedure ScalarArrayParameters() Names: List of [Text]
    begin
        Names.Add('Inventory.Attribute.Get|attributeNames');
        Names.Add('Inventory.Attribute.Get|attributeIds');
        Names.Add('Inventory.AttributeDefinition.Create|optionValues');
        Names.Add('Inventory.AvailabilityByPeriod.Get|items');
        Names.Add('Inventory.PhysInventory.Check|lineSystemIds');
        Names.Add('Inventory.PhysInventory.PreviewPost|lineSystemIds');
        Names.Add('Inventory.PhysInventory.Post|lineSystemIds');
    end;

    /// <summary>
    /// Chapters that an existing test in Inventory Contract Batch Tests pins as absent. They are listed here, not
    /// fixed, because that test may not be loosened in this change: it asserts the absence of the chapter.
    /// </summary>
    local procedure PinnedNoTargetTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.AttributeDefinition.Create');
    end;

    local procedure PinnedNoNotesTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.Attribute.Get');
        Names.Add('Inventory.AttributeDefinition.Create');
        Names.Add('Inventory.CostToGL.Test');
    end;

    local procedure PinnedNoExamplesTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.Attribute.Create');
        Names.Add('Inventory.Attribute.Update');
    end;

    local procedure PinnedNoWorkflowTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.AdjustCost.Run');
        Names.Add('Inventory.CostToGL.Post');
        Names.Add('Inventory.Attribute.Create');
        Names.Add('Inventory.Attribute.Update');
        Names.Add('Inventory.AttributeDefinition.Create');
    end;

    local procedure TextOf(Source: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Source.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ArrayOf(Source: JsonObject; KeyName: Text) Result: JsonArray
    var
        Token: JsonToken;
    begin
        if not Source.Get(KeyName, Token) then
            exit;
        if Token.IsArray() then
            Result := Token.AsArray();
    end;
}
