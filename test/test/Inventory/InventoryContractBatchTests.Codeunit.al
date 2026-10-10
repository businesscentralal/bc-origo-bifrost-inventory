namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;

/// <summary>Verifies the Msg Contract and Msg Discovery rollout for all Inventory message types.</summary>
codeunit 96921 "Inventory Contract Batch Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure AllInventoryTypes_HaveRequiredContractChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
        Chapter: Text;
    begin
        foreach TypeName in InventoryTypes() do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
            foreach Chapter in RequiredChapters(TypeName) do
                LibraryAssert.IsTrue(Contract.Contains(Chapter), TypeName + ' must declare chapter ' + Chapter + '.');
        end;
    end;

    [Test]
    procedure AllInventoryTypes_HaveBilingualDiscovery()
    var
        MessageType: Enum "Message Type ori";
        Discovery: Interface "Msg Discovery ori";
        TypeName: Text;
    begin
        foreach TypeName in InventoryTypes() do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Discovery := MessageType;
            LibraryAssert.IsFalse(Discovery.GetKeywords() = '', TypeName + ' must have discovery keywords.');
            LibraryAssert.IsFalse(Discovery.GetSelectionDescription() = '', TypeName + ' must have a selection description.');
        end;
    end;

    [Test]
    procedure InventoryEffects_MatchOperation()
    begin
        AssertEffect('Item.Attribute.Get', 'read');
        AssertEffect('Item.Attribute.Create', 'write');
        AssertEffect('Item.Attribute.Update', 'write');
        AssertEffect('Item.AttributeDefinition.Create', 'write');
        AssertEffect('Inventory.TransferOrder.Create', 'write');
        AssertEffect('Inventory.TransferOrder.Release', 'write');
        AssertEffect('Inventory.TransferOrder.Reopen', 'write');
        AssertEffect('Inventory.TransferOrder.Post', 'irreversible');
        AssertEffect('Inventory.TransferOrder.PreviewPost', 'read');
        AssertEffect('Inventory.TransferOrder.Statistics', 'read');
        AssertEffect('Inventory.AssemblyOrder.Create', 'write');
        AssertEffect('Inventory.AssemblyOrder.RefreshLines', 'write');
        AssertEffect('Inventory.AssemblyOrder.Release', 'write');
        AssertEffect('Inventory.AssemblyOrder.Reopen', 'write');
        AssertEffect('Inventory.AssemblyOrder.Post', 'irreversible');
        AssertEffect('Inventory.AssemblyOrder.PreviewPost', 'read');
        AssertEffect('Inventory.AssemblyOrder.Statistics', 'read');
    end;

    local procedure AssertEffect(TypeName: Text; Expected: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonObject;
        EffectToken: JsonToken;
    begin
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        ContractMgt.GetContract(MessageType, Contract);
        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Effect.Get('effect', EffectToken);
        LibraryAssert.AreEqual(Expected, EffectToken.AsValue().AsText(), TypeName + ' effect mismatch.');
    end;

    local procedure InventoryTypes() Types: List of [Text]
    begin
        Types.Add('Item.Attribute.Get');
        Types.Add('Item.Attribute.Create');
        Types.Add('Item.Attribute.Update');
        Types.Add('Item.AttributeDefinition.Create');
        Types.Add('Inventory.TransferOrder.Create');
        Types.Add('Inventory.TransferOrder.Release');
        Types.Add('Inventory.TransferOrder.Reopen');
        Types.Add('Inventory.TransferOrder.Post');
        Types.Add('Inventory.TransferOrder.PreviewPost');
        Types.Add('Inventory.TransferOrder.Statistics');
        Types.Add('Inventory.AssemblyOrder.Create');
        Types.Add('Inventory.AssemblyOrder.RefreshLines');
        Types.Add('Inventory.AssemblyOrder.Release');
        Types.Add('Inventory.AssemblyOrder.Reopen');
        Types.Add('Inventory.AssemblyOrder.Post');
        Types.Add('Inventory.AssemblyOrder.PreviewPost');
        Types.Add('Inventory.AssemblyOrder.Statistics');
    end;

    local procedure RequiredChapters(TypeName: Text) Chapters: List of [Text]
    begin
        Chapters.Add('envelope');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('metering');
        Chapters.Add('related');
        if TypeName <> 'Item.AttributeDefinition.Create' then
            Chapters.Add('target');
        if TypeName in ['Item.Attribute.Get', 'Item.Attribute.Create', 'Item.Attribute.Update', 'Item.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.TransferOrder.Post', 'Inventory.TransferOrder.PreviewPost', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.Post'] then
            Chapters.Add('parameters');
        if TypeName in ['Inventory.TransferOrder.Create', 'Inventory.TransferOrder.PreviewPost', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.PreviewPost'] then
            Chapters.Add('workflow');
        if TypeName in ['Item.Attribute.Get', 'Item.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.AssemblyOrder.Create'] then
            Chapters.Add('examples');
        Chapters.Add('overview');
    end;

    local procedure OrdinalOf(TypeName: Text): Integer
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        exit(Ordinals.Get(Names.IndexOf(TypeName)));
    end;

    /// <summary>Checks published costing parameter defaults through the contract reader.</summary>
    [Test]
    procedure CostingContracts_DeclareTypedDefaults()
    var
        Contract: JsonObject;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        // Metadata only: this test makes no permission or report execution claim.
        LoadCostingContract('Inventory.AdjustCost.Run', Contract);
        AssertStringDefault(Contract, 'itemNoFilter');
        AssertStringDefault(Contract, 'itemCategoryFilter');
        AssertBooleanDefault(Contract, 'postToGL', false);
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        AssertStringDefault(Contract, 'itemNoFilter');
        AssertStringDefault(Contract, 'documentNoFilter');
    end;

    /// <summary>Checks the report 795 filter constraint and array-shaped preconditions.</summary>
    [Test]
    procedure CostingContracts_DeclareFilterPrecondition()
    var
        Contract: JsonObject;
        ChapterToken: JsonToken;
        Effect: JsonObject;
        Preconditions: JsonArray;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        LoadCostingContract('Inventory.AdjustCost.Run', Contract);
        Contract.Get('effect', ChapterToken);
        Effect := ChapterToken.AsObject();
        Effect.Get('preconditions', ChapterToken);
        LibraryAssert.IsTrue(ChapterToken.IsArray(), 'Preconditions must be an array, not prose.');
        Preconditions := ChapterToken.AsArray();
        LibraryAssert.AreEqual(3, Preconditions.Count(), 'Keep the domain, report and conflicting-filter preconditions.');
        Preconditions.Get(2, ChapterToken);
        LibraryAssert.AreEqual('Only one of itemNoFilter and itemCategoryFilter may remain nonempty after truncation to 250 characters; report 795 rejects both nonempty.', ChapterToken.AsValue().AsText(), 'Report 795 rejects simultaneous effective filters.');
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        Contract.Get('effect', ChapterToken);
        Effect := ChapterToken.AsObject();
        Effect.Get('preconditions', ChapterToken);
        LibraryAssert.IsTrue(ChapterToken.IsArray(), 'CostToGL preconditions must also be an array.');
    end;

    /// <summary>Checks normal-dispatch error mapping without claiming runtime execution.</summary>
    [Test]
    procedure CostingContracts_DeclareDispatcherFailure()
    var
        Contract: JsonObject;
        Error: JsonObject;
        ValueToken: JsonToken;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        LoadCostingContract('Inventory.AdjustCost.Run', Contract);
        GetNamedMember(Contract, 'errors', 'code', 'BusinessCentralError', Error);
        Error.Get('when', ValueToken);
        LibraryAssert.IsTrue(StrPos(ValueToken.AsValue().AsText(), 'Direct invocation may raise instead') > 0, 'Direct errors must remain distinct from dispatcher responses.');
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        GetNamedMember(Contract, 'errors', 'code', 'InvalidOperation', Error);
        Error.Get('when', ValueToken);
        LibraryAssert.AreEqual('The standard report Run returns false; response carries GetLastErrorText. This branch precedes response-echo conversion.', ValueToken.AsValue().AsText(), 'Do not describe post-report echo conversion as preflight validation.');
        GetNamedMember(Contract, 'errors', 'code', 'BusinessCentralError', Error);
    end;

    /// <summary>Checks that CostToGL completion does not promise G/L posting.</summary>
    [Test]
    procedure CostingContracts_DiscloseReportOptions()
    var
        Contract: JsonObject;
        ChapterToken: JsonToken;
        Effect: JsonObject;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        Contract.Get('effect', ChapterToken);
        Effect := ChapterToken.AsObject();
        Effect.Get('changes', ChapterToken);
        LibraryAssert.AreEqual('Report 1002 may write or post under its standard/runtime options. The caller neither initializes Post nor applies request filter fields. Report completion does not prove G/L posting.', ChapterToken.AsValue().AsText(), 'Report invocation does not prove posting or filtered selection.');
        Effect.Get('idempotent', ChapterToken);
        LibraryAssert.IsFalse(ChapterToken.AsValue().AsBoolean(), 'No safe retry or idempotence guarantee is established.');
    end;

    /// <summary>Checks omitted chapters clear reused interface outputs.</summary>
    [Test]
    procedure CostingContracts_ClearReusedChapters()
    var
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Contract ori";
        TypeName: Text;
        Types: List of [Text];
        ChapterKeys: List of [Text];
        ObjectChapter: JsonObject;
        ArrayChapter: JsonArray;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        Types.Add('Inventory.AdjustCost.Run');
        Types.Add('Inventory.CostToGL.Post');
        foreach TypeName in Types do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Implementation := MessageType;
            ObjectChapter.Add('stale', true);
            LibraryAssert.IsFalse(Implementation.GetWorkflow(ObjectChapter), 'No workflow is declared.');
            ChapterKeys := ObjectChapter.Keys();
            LibraryAssert.AreEqual(0, ChapterKeys.Count(), 'Absent workflow must clear old output.');
            ObjectChapter.Add('stale', true);
            LibraryAssert.IsFalse(Implementation.GetMetering(ObjectChapter), 'Foundation owns metering composition.');
            ChapterKeys := ObjectChapter.Keys();
            LibraryAssert.AreEqual(0, ChapterKeys.Count(), 'Absent app metering must clear old output.');
            ArrayChapter.Add('stale');
            LibraryAssert.IsTrue(Implementation.GetTarget(ArrayChapter), 'Unused subject has an explicit empty target.');
            LibraryAssert.AreEqual(0, ArrayChapter.Count(), 'Target must not retain previous records.');
        end;
    end;

    /// <summary>Exercises every costing chapter through the published enum interfaces.</summary>
    [Test]
    procedure CostingInterfaces_AllChapters_ReplaceReusedOutputs()
    var
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        Contract: Interface "Msg Contract ori";
        Types: List of [Text];
        TypeName: Text;
        TextChapter: Text;
        ObjectChapter: JsonObject;
        ArrayChapter: JsonArray;
        Keys: List of [Text];
        RepeatRead: Integer;
    begin
        // PR #90 metadata-all-members | Time: no date dependency | Risk: metadata only.
        // [GIVEN] Both real mappings and outputs reused across repetitions and mappings.
        Types.Add('Inventory.AdjustCost.Run');
        Types.Add('Inventory.CostToGL.Post');
        foreach TypeName in Types do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Implementation := MessageType;
            Discovery := MessageType;
            Contract := MessageType;
            LibraryAssert.AreEqual("Msg Direction ori"::Inbound, Implementation.GetMessageDirection(), 'Both operations are inbound.');
            LibraryAssert.AreEqual(27, Implementation.GetFilterTableNo(), 'Both filter tables are Item.');
            AssertCostingCatalogue(TypeName, Implementation.GetDescription(), Discovery.GetSelectionDescription(), Discovery.GetKeywords());
            for RepeatRead := 1 to 2 do begin
                // [WHEN] Every chapter is read with deliberately stale output.
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsTrue(Contract.GetEnvelope(ObjectChapter), 'Envelope is declared.');
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), 'Envelope must replace output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetTarget(ArrayChapter), 'Target is explicitly empty.');
                LibraryAssert.AreEqual(0, ArrayChapter.Count(), 'No subject target.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetParameters(ArrayChapter), 'Parameters are declared.');
                if TypeName = 'Inventory.AdjustCost.Run' then
                    LibraryAssert.AreEqual(3, ArrayChapter.Count(), 'Three supported request keys.')
                else
                    LibraryAssert.AreEqual(2, ArrayChapter.Count(), 'Two echo keys.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetErrors(ArrayChapter), 'Errors are declared.');
                LibraryAssert.AreEqual(4, ArrayChapter.Count(), 'Four independently specified error branches.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsTrue(Contract.GetResponse(ObjectChapter), 'Response is declared.');
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), 'Response must replace output.');
                AssertCostingResponseFields(TypeName, ObjectChapter);
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsTrue(Contract.GetEffect(ObjectChapter), 'Effect is declared.');
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), 'Effect must replace output.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsFalse(Contract.GetMetering(ObjectChapter), 'Application adds no metering.');
                Keys := ObjectChapter.Keys();
                LibraryAssert.AreEqual(0, Keys.Count(), 'App metering clears output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetRelated(ArrayChapter), 'Related is declared.');
                LibraryAssert.AreEqual(1, ArrayChapter.Count(), 'One sibling operation.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsFalse(Contract.GetWorkflow(ObjectChapter), 'Workflow omitted.');
                Keys := ObjectChapter.Keys();
                LibraryAssert.AreEqual(0, Keys.Count(), 'Workflow clears output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetExamples(ArrayChapter), 'Examples declared.');
                LibraryAssert.AreEqual(1, ArrayChapter.Count(), 'One example.');
                TextChapter := 'stale';
                LibraryAssert.IsTrue(Contract.GetOverview(TextChapter), 'Overview declared.');
                LibraryAssert.IsFalse((TextChapter = '') or (TextChapter = 'stale'), 'Overview replaces output.');
                TextChapter := 'stale';
                LibraryAssert.IsTrue(Contract.GetNotes(TextChapter), 'Notes declared.');
                LibraryAssert.IsFalse((TextChapter = '') or (TextChapter = 'stale'), 'Notes replace output.');
                // [THEN] Typed defaults are independently asserted by retained five tests.
            end;
        end;
    end;

    local procedure LoadCostingContract(TypeName: Text; var Contract: JsonObject)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
    begin
        Contract.Add('stale', true);
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Costing implementation must declare its contract.');
        LibraryAssert.IsFalse(Contract.Contains('stale'), 'Contract reader must clear reused output.');
    end;

    local procedure AssertStringDefault(Contract: JsonObject; Name: Text)
    var
        Parameter: JsonObject;
        ValueToken: JsonToken;
        DefaultJson: Text;
    begin
        GetNamedMember(Contract, 'parameters', 'name', Name, Parameter);
        Parameter.Get('type', ValueToken);
        LibraryAssert.AreEqual('string', ValueToken.AsValue().AsText(), Name + ' type must be string.');
        Parameter.Get('default', ValueToken);
        ValueToken.WriteTo(DefaultJson);
        LibraryAssert.AreEqual('""', DefaultJson, Name + ' default must be a JSON string.');
        LibraryAssert.AreEqual('', ValueToken.AsValue().AsText(), Name + ' must declare its empty default.');
        Parameter.Get('required', ValueToken);
        LibraryAssert.IsFalse(ValueToken.AsValue().AsBoolean(), Name + ' is optional.');
    end;

    local procedure AssertBooleanDefault(Contract: JsonObject; Name: Text; Expected: Boolean)
    var
        Parameter: JsonObject;
        ValueToken: JsonToken;
        DefaultJson: Text;
    begin
        GetNamedMember(Contract, 'parameters', 'name', Name, Parameter);
        Parameter.Get('type', ValueToken);
        LibraryAssert.AreEqual('boolean', ValueToken.AsValue().AsText(), Name + ' type must be boolean.');
        Parameter.Get('default', ValueToken);
        ValueToken.WriteTo(DefaultJson);
        if Expected then
            LibraryAssert.AreEqual('true', DefaultJson, Name + ' default must be a JSON Boolean.')
        else
            LibraryAssert.AreEqual('false', DefaultJson, Name + ' default must be a JSON Boolean.');
        LibraryAssert.AreEqual(Expected, ValueToken.AsValue().AsBoolean(), Name + ' must declare a typed Boolean default.');
        Parameter.Get('required', ValueToken);
        LibraryAssert.IsFalse(ValueToken.AsValue().AsBoolean(), Name + ' is optional.');
    end;

    local procedure GetNamedMember(Contract: JsonObject; Chapter: Text; KeyName: Text; Expected: Text; var Member: JsonObject)
    var
        ChapterToken: JsonToken;
        EntryToken: JsonToken;
        ValueToken: JsonToken;
    begin
        Clear(Member);
        LibraryAssert.IsTrue(Contract.Get(Chapter, ChapterToken), 'Missing contract chapter ' + Chapter + '.');
        foreach EntryToken in ChapterToken.AsArray() do begin
            Member := EntryToken.AsObject();
            if Member.Get(KeyName, ValueToken) then
                if ValueToken.AsValue().AsText() = Expected then
                    exit;
        end;
        LibraryAssert.Fail('Missing ' + Chapter + ' entry ' + Expected + '.');
    end;

    local procedure AssertCostingCatalogue(TypeName: Text; Description: Text; Selection: Text; Keywords: Text)
    begin
        if TypeName = 'Inventory.AdjustCost.Run' then begin
            LibraryAssert.AreEqual('Runs report 795 with optional item or category filter and explicit postToGL option.', Description, 'Exact AdjustCost description.');
            LibraryAssert.AreEqual('Run Adjust Cost - Item Entries for a filtered set of items, and optionally post the corrections to the general ledger.', Selection, 'Exact AdjustCost selection.');
            LibraryAssert.AreEqual('adjust cost,item entry correction,post to g/l,report 795', Keywords, 'Exact AdjustCost keywords.');
        end else begin
            LibraryAssert.AreEqual('Runs report 1002 without request selection or explicit Post initialization; success means report completion, not proof of G/L posting.', Description, 'Exact CostToGL description.');
            LibraryAssert.AreEqual('Post inventory value entries that are not yet posted to the general ledger.', Selection, 'Exact CostToGL selection.');
            LibraryAssert.AreEqual('post inventory cost,general ledger,report 1002', Keywords, 'Exact CostToGL keywords.');
        end;
    end;

    local procedure AssertCostingResponseFields(TypeName: Text; Response: JsonObject)
    var
        Field: JsonObject;
        Token: JsonToken;
    begin
        AssertJsonText(Response, 'contentType', 'text/json');
        Response.Get('fields', Token);
        if TypeName = 'Inventory.AdjustCost.Run' then
            LibraryAssert.AreEqual(4, Token.AsArray().Count(), 'Exact AdjustCost response field count.')
        else
            LibraryAssert.AreEqual(3, Token.AsArray().Count(), 'Exact CostToGL response field count.');
        GetNamedMember(Response, 'fields', 'name', 'status', Field);
        AssertJsonText(Field, 'type', 'string');
        GetNamedMember(Response, 'fields', 'name', 'itemNoFilter', Field);
        AssertJsonText(Field, 'type', 'string');
        if TypeName = 'Inventory.AdjustCost.Run' then begin
            GetNamedMember(Response, 'fields', 'name', 'itemCategoryFilter', Field);
            AssertJsonText(Field, 'type', 'string');
            GetNamedMember(Response, 'fields', 'name', 'postToGL', Field);
            AssertJsonText(Field, 'type', 'boolean');
        end else begin
            GetNamedMember(Response, 'fields', 'name', 'documentNoFilter', Field);
            AssertJsonText(Field, 'type', 'string');
        end;
    end;

    local procedure AssertJsonText(Value: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Value.Get(Name, Token), 'Missing response field ' + Name + '.');
        LibraryAssert.IsTrue(Token.IsValue(), Name + ' must be scalar.');
        LibraryAssert.AreEqual(Expected, Token.AsValue().AsText(), Name + ' mismatch.');
    end;
}
