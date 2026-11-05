namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Checks the shipped contract reader for the eleven strict document lookups.</summary>
codeunit 96922 "Inv. Lookup Contract Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Every document lookup names data and every accepted key in its format error.</summary>
    [Test]
    procedure AllLookupTypes_ErrorsChapter_ListsDataAndKeys()
    var
        Names: List of [Text];
        Name: Text;
        Errors: JsonArray;
        Entry: JsonToken;
        Value: JsonToken;
        TextValue: Text;
        Found: Integer;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] All eleven shipping document lookup types.
        PreviousLanguage := GlobalLanguage();
        Names := LookupNames();
        foreach Name in Names do begin
            // [WHEN] Reading their public contract.
            GlobalLanguage(1033);
            Errors := ReadErrors(Name);
            GlobalLanguage(PreviousLanguage);
            Found := 0;
            foreach Entry in Errors do
                if Entry.AsObject().Get('code', Value) then
                    if Value.AsValue().AsText() = 'InvalidParameterFormat' then begin
                        Found += 1;
                        Entry.WriteTo(TextValue);
                        // [THEN] The contract describes data and the exact document key family.
                        Assert.IsTrue(TextValue.Contains('data is not a JSON object'), Name + ': data shape');
                        Assert.IsTrue(TextValue.Contains('documentNo'), Name + ': documentNo');
                        Assert.IsTrue(TextValue.Contains('no, systemId, recordSystemId, id'), Name + ': aliases');
                        if Name.StartsWith('Inventory.TransferOrder.') then
                            Assert.IsTrue(TextValue.Contains('transferOrderNo'), Name + ': transfer alias')
                        else
                            Assert.IsTrue(TextValue.Contains('assemblyOrderNo'), Name + ': assembly alias');
                        Assert.IsFalse(TextValue.Contains('A SystemId or document identifier cannot be read.'), Name + ': obsolete text');
                    end;
            Assert.AreEqual(1, Found, Name + ': one format error');
        end;
    end;

    /// <summary>Aggregation is declared once on every document lookup.</summary>
    [Test]
    procedure AllLookupTypes_ErrorsChapter_ExactlyOneMultipleErrors()
    var
        Names: List of [Text];
        Name: Text;
    begin
        // [GIVEN] Document lookups; [WHEN] read errors; [THEN] exactly one aggregation entry.
        Names := LookupNames();
        foreach Name in Names do
            AssertCodeCount(Name, 'MultipleErrors', 1);
    end;

    /// <summary>Create and Item range lookups retain their distinct non-strict contracts.</summary>
    [Test]
    procedure CreateTypes_DeclareCollectionAndAttributeReadsDoNot()
    begin
        // [GIVEN] Create preflight collects independent errors; attribute reads retain their existing contract.
        AssertCodeCount('Inventory.TransferOrder.Create', 'MultipleErrors', 1);
        AssertCodeCount('Inventory.AssemblyOrder.Create', 'MultipleErrors', 1);
        AssertCodeCount('Inventory.Attribute.Get', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.Attribute.Create', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.Attribute.Update', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.AttributeDefinition.Create', 'MultipleErrors', 1);
    end;

    /// <summary>Blocked attribute refusal translates its sentence while retaining the item and protocol key.</summary>
    [Test]
    procedure AttributeBlocked_BothLanguages_PlaceholderAndKeyPreserved()
    var
        TempItem: Record Item temporary;
        Resolve: Codeunit "Item Attribute Resolve ori";
        PreviousLanguage: Integer;
        English: Text;
        Icelandic: Text;
    begin
        // [GIVEN] A self-contained temporary blocked item; no shared fixture or persistent write.
        TempItem."No." := 'W8-LOCALE';
        TempItem.Blocked := true;
        PreviousLanguage := GlobalLanguage();
        // [WHEN] Native validation refuses the same item in both languages.
        GlobalLanguage(1033);
        asserterror Resolve.AssertItemWritable(TempItem, false);
        English := GetLastErrorText();
        GlobalLanguage(1039);
        asserterror Resolve.AssertItemWritable(TempItem, false);
        Icelandic := GetLastErrorText();
        GlobalLanguage(PreviousLanguage);
        // [THEN] Exact sentences prove translation, interpolation and an unchanged allowBlocked key.
        Assert.AreEqual('Item "W8-LOCALE" is blocked. Pass allowBlocked: true to override.', English, 'English refusal');
        Assert.AreEqual('Varan "W8-LOCALE" er lokuð. Sendu allowBlocked: true til að leyfa breytinguna.', Icelandic, 'Icelandic refusal');
    end;

    /// <summary>Every strict lookup keeps Foundation contract chapters English and restores the caller language.</summary>
    [Test]
    procedure AllLookupTypes_BothLanguages_KeepEnglishContract()
    var
        Names: List of [Text];
        Codes: List of [Text];
        Name: Text;
        Code: Text;
        EnglishErrors: JsonArray;
        IcelandicErrors: JsonArray;
        EnglishEntry: JsonObject;
        IcelandicEntry: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] All eleven document lookup contracts with their five shared error entries.
        Names := LookupNames();
        Codes.Add('MissingParameter');
        Codes.Add('RecordNotFound');
        Codes.Add('ConflictingIdentifiers');
        Codes.Add('InvalidParameterFormat');
        Codes.Add('MultipleErrors');
        PreviousLanguage := GlobalLanguage();
        foreach Name in Names do begin
            // [WHEN] The public contract reader runs under each supported UI language.
            GlobalLanguage(1033);
            EnglishErrors := ReadErrors(Name);
            Assert.AreEqual(1033, GlobalLanguage(), Name + ': preserves English caller language');
            GlobalLanguage(1039);
            IcelandicErrors := ReadErrors(Name);
            Assert.AreEqual(1039, GlobalLanguage(), Name + ': restores Icelandic caller language');
            GlobalLanguage(PreviousLanguage);
            // [THEN] Foundation GetContract intentionally forces English (#777); it restores the caller language.
            foreach Code in Codes do begin
                EnglishEntry := ErrorByCode(EnglishErrors, Code);
                IcelandicEntry := ErrorByCode(IcelandicErrors, Code);
                Assert.AreEqual(EntryText(EnglishEntry, 'when'), EntryText(IcelandicEntry, 'when'), Name + ': stable English explanation ' + Code);
                Assert.AreEqual(EntryText(EnglishEntry, 'fix'), EntryText(IcelandicEntry, 'fix'), Name + ': stable English next step ' + Code);
            end;
            IcelandicEntry := ErrorByCode(IcelandicErrors, 'InvalidParameterFormat');
            Assert.IsTrue(EntryText(IcelandicEntry, 'when').Contains('data is not a JSON object'), Name + ': English contract explanation');
            Assert.IsTrue(EntryText(IcelandicEntry, 'when').Contains('no, systemId, recordSystemId, id'), Name + ': invariant identifier keys');
            if Name.StartsWith('Inventory.TransferOrder.') then
                Assert.IsTrue(EntryText(IcelandicEntry, 'when').Contains('documentNo, transferOrderNo'), Name + ': transfer alias')
            else
                Assert.IsTrue(EntryText(IcelandicEntry, 'when').Contains('documentNo, assemblyOrderNo'), Name + ': assembly alias');
            IcelandicEntry := ErrorByCode(IcelandicErrors, 'MultipleErrors');
            Assert.IsTrue(EntryText(IcelandicEntry, 'when').Contains('errors[]'), Name + ': invariant aggregate key');
        end;
    end;

    local procedure ErrorByCode(Errors: JsonArray; Code: Text) Result: JsonObject
    var
        Entry: JsonToken;
        Value: JsonToken;
        Count: Integer;
    begin
        foreach Entry in Errors do
            if Entry.AsObject().Get('code', Value) then
                if Value.AsValue().AsText() = Code then
                    if (Code <> 'MissingParameter') or not EntryText(Entry.AsObject(), 'when').Contains('postingType') then begin
                        Result := Entry.AsObject();
                        Count += 1;
                    end;
        Assert.AreEqual(1, Count, 'Exactly one stable ' + Code + ' entry in each language.');
    end;

    local procedure EntryText(Entry: JsonObject; FieldName: Text): Text
    var
        Value: JsonToken;
    begin
        Assert.IsTrue(Entry.Get(FieldName, Value), 'Required help entry field ' + FieldName);
        Assert.IsTrue(Value.AsValue().AsText() <> '', 'Nonempty help text ' + FieldName);
        exit(Value.AsValue().AsText());
    end;

    local procedure ReadErrors(Name: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Contract: JsonObject;
        Token: JsonToken;
    begin
        Names := MessageType.Names();
        Assert.IsTrue(Names.Contains(Name), 'Registered type ' + Name);
        MessageType := "Message Type ori".FromInteger(MessageType.Ordinals().Get(Names.IndexOf(Name)));
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Contract for ' + Name);
        Assert.IsTrue(Contract.Get('errors', Token), 'Errors chapter for ' + Name);
        Errors := Token.AsArray();
    end;

    local procedure AssertCodeCount(Name: Text; Code: Text; Expected: Integer)
    var
        Errors: JsonArray;
        Entry: JsonToken;
        Value: JsonToken;
        Count: Integer;
    begin
        Errors := ReadErrors(Name);
        foreach Entry in Errors do
            if Entry.AsObject().Get('code', Value) then
                if Value.AsValue().AsText() = Code then
                    Count += 1;
        Assert.AreEqual(Expected, Count, Name + ': ' + Code);
    end;

    local procedure LookupNames() Names: List of [Text]
    begin
        Names.Add('Inventory.TransferOrder.Release');
        Names.Add('Inventory.TransferOrder.Reopen');
        Names.Add('Inventory.TransferOrder.Post');
        Names.Add('Inventory.TransferOrder.PreviewPost');
        Names.Add('Inventory.TransferOrder.Statistics');
        Names.Add('Inventory.AssemblyOrder.RefreshLines');
        Names.Add('Inventory.AssemblyOrder.Release');
        Names.Add('Inventory.AssemblyOrder.Reopen');
        Names.Add('Inventory.AssemblyOrder.Post');
        Names.Add('Inventory.AssemblyOrder.PreviewPost');
        Names.Add('Inventory.AssemblyOrder.Statistics');
    end;
}
