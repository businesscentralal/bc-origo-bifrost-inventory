namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using Microsoft.Inventory.Item;
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
    begin
        // [GIVEN] All eleven shipping document lookup types.
        Names := LookupNames();
        foreach Name in Names do begin
            // [WHEN] Reading their public contract.
            Errors := ReadErrors(Name);
            Found := 0;
            foreach Entry in Errors do begin
                Entry.AsObject().Get('code', Value);
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
    procedure NonLookupTypes_ErrorsChapter_NoMultipleErrors()
    begin
        // [GIVEN] Non-document lookups; [WHEN] read errors; [THEN] no accidental aggregation declaration.
        AssertCodeCount('Inventory.TransferOrder.Create', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.AssemblyOrder.Create', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.Attribute.Get', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.Attribute.Create', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.Attribute.Update', 'MultipleErrors', 0);
        AssertCodeCount('Inventory.AttributeDefinition.Create', 'MultipleErrors', 0);
    end;

    /// <summary>A translated native refusal and its next step retain stable machine keys.</summary>
    [Test]
    procedure DomainRefusal_BothLanguages_ExactNextStep()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Gate: Codeunit "Inventory Domain Gate ori";
        Response: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
        English: Text;
        Icelandic: Text;
    begin
        // [GIVEN] This test company explicitly disables tracking; no licence or product execution is bypassed.
        Setup.InsertIfNotExists();
        Setup."Item Tracking" := false;
        Setup.Modify(true);
        PreviousLanguage := GlobalLanguage();
        // [WHEN] The same refusal is produced in both supported languages.
        GlobalLanguage(1033);
        Gate.AssertEnabled(TempArgument, "Inventory Domain ori"::ItemTracking, Database::Item, false, false);
        Response := TempArgument.GetResponseJson();
        Assert.IsTrue(Response.Get('nextStep', Token), 'English nextStep machine key');
        English := Token.AsValue().AsText();
        GlobalLanguage(1039);
        Gate.AssertEnabled(TempArgument, "Inventory Domain ori"::ItemTracking, Database::Item, false, false);
        Response := TempArgument.GetResponseJson();
        Assert.IsTrue(Response.Get('nextStep', Token), 'Icelandic nextStep machine key');
        Icelandic := Token.AsValue().AsText();
        GlobalLanguage(PreviousLanguage);
        // [THEN] Neither language falls back and the protocol status remains stable.
        Assert.AreEqual('Turn the domain on from the Inventory Setup page.', English, 'Exact English next step');
        Assert.AreEqual('Kveiktu á sviðinu á síðunni Uppsetning birgða.', Icelandic, 'Exact Icelandic next step');
        Response.Get('status', Token);
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Machine status is not translated');
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
