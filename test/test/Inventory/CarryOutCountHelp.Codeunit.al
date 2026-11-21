namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Checks reversible carry-out contracts and the app-wide posting effect boundary (#279).</summary>
codeunit 96948 "CarryOut Count Help ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>AC03 The composed contracts declare reversible writes at both session languages.</summary>
    [Test]
    procedure Scenario_AC01_English_NamesWorksheetSelections()
    begin
        // Story #279 AC03 | Time: independent | Risk: stale composed confirmation guidance.
        // GetContract keeps the effect chapter in English at every session language (#777, #1239).
        // Codeunit 98729 reads that chapter at 1033 and at 1039, so both passes need the English marker.
        AssertComposed(1033);
        AssertComposed(1039);
    end;

    /// <summary>AC03 The declared labels translate Writes and the ignored compatibility parameter.</summary>
    [Test]
    procedure Scenario_AC03_Icelandic_NamesWorksheetSelections()
    begin
        // Story #279 AC03 | Time: independent | Risk: stale Icelandic effect or compatibility guidance.
        // The composed chapter stays English. These asserts read the type's own labels at 1039.
        AssertDeclared("Message Type ori"::"Purchase.Requisition.CarryOut", 'Skrifar.');
        AssertDeclared("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'Skrifar.');
    end;

    /// <summary>AC03 No count requirement remains in effect.changes.</summary>
    [Test]
    procedure Scenario_AC02_UnrecognizedAlwaysOne_IsAbsent()
    begin
        // Story #279 AC03 | Time: independent | Risk: obsolete count requirement remains in help.
        AssertOldWordingAbsent(1033);
        AssertOldWordingAbsent(1039);
    end;

    local procedure AssertComposed(LanguageId: Integer)
    var
        SavedLanguageId: Integer;
    begin
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        AssertComposedType("Message Type ori"::"Purchase.Requisition.CarryOut", 'Writes.');
        AssertComposedType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'Writes.');
        GlobalLanguage(SavedLanguageId);
    end;

    local procedure AssertComposedType(MessageType: Enum "Message Type ori"; NotLines: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Token: JsonToken;
        Changes: Text;
        ParameterDescription: Text;
        Marker: Text;
    begin
        Marker := 'ignored';
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'The composed contract is published.');
        Assert.IsTrue(Contract.Get('effect', Token), 'effect chapter exists.');
        Effect := Token.AsObject();
        Assert.IsTrue(Effect.Get('effect', Token), 'effect name exists.');
        Assert.AreEqual('write', Token.AsValue().AsText(), 'Carry-out creates editable orders without posting.');
        Assert.IsTrue(Effect.Get('changes', Token), 'effect.changes exists.');
        Changes := Token.AsValue().AsText();
        Assert.IsFalse(Changes.Contains('expectedCount'), 'effect.changes has no count requirement.');
        Assert.IsFalse(Changes.ToLower().Contains('irreversible'), 'Non-posting help has no irreversible classification.');
        Assert.IsTrue(Changes.Contains(NotLines), 'effect.changes says Writes.');
        Assert.IsFalse(Changes.StartsWith('Counts '), 'effect.changes does not use the parameter shorthand.');
        Assert.IsFalse(Changes.StartsWith('Telur '), 'effect.changes does not use the Icelandic parameter shorthand.');
        ParameterDescription := ExpectedCountDescription(Contract);
        Assert.AreNotEqual('', ParameterDescription, 'expectedCount is declared.');
        Assert.IsTrue(ParameterDescription.Contains(Marker), 'expectedCount is explicitly ignored.');
        AssertOptionalExpectedCount(Contract);
    end;

    local procedure AssertDeclared(MessageType: Enum "Message Type ori"; NotLines: Text)
    var
        Contract: Interface "Msg Contract ori";
        Implementation: Interface "Msg Interface ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Token: JsonToken;
        ParameterContract: JsonObject;
        SavedLanguageId: Integer;
        Changes: Text;
        ParameterDescription: Text;
        Marker: Text;
    begin
        Marker := 'hunsuð';
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1039);
        Contract := MessageType;
        Implementation := MessageType;
        Assert.IsTrue(Implementation.GetDescription().Contains('Skrifar.'), 'Localized catalogue help says Skrifar even when Foundation composes contract chapters in English.');
        Assert.IsTrue(Contract.GetEffect(Effect), 'The type declares an effect.');
        Assert.IsTrue(Effect.Get('changes', Token), 'effect.changes exists.');
        Changes := Token.AsValue().AsText();
        Assert.IsFalse(Changes.Contains('expectedCount'), 'Icelandic effect has no count requirement.');
        Assert.IsFalse(Changes.ToLower().Contains('óafturkræft'), 'Non-posting Icelandic help has no irreversible classification.');
        Assert.IsTrue(Changes.Contains(NotLines), 'Icelandic effect says Skrifar.');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'The type declares parameters.');
        ParameterContract.Add('parameters', Parameters);
        ParameterDescription := ExpectedCountDescription(ParameterContract);
        Assert.AreNotEqual('', ParameterDescription, 'expectedCount is declared on the type.');
        Assert.IsTrue(ParameterDescription.Contains(Marker), 'Icelandic parameter explicitly says ignored.');
        AssertOptionalExpectedCount(ParameterContract);
        GlobalLanguage(SavedLanguageId);
    end;

    local procedure AssertOldWordingAbsent(LanguageId: Integer)
    var
        SavedLanguageId: Integer;
    begin
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        AssertOldWordingAbsentFor("Message Type ori"::"Purchase.Requisition.CarryOut");
        AssertOldWordingAbsentFor("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut");
        GlobalLanguage(SavedLanguageId);
    end;

    local procedure AssertOldWordingAbsentFor(MessageType: Enum "Message Type ori")
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Token: JsonToken;
        Changes: Text;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'The composed contract is published.');
        Assert.IsTrue(Contract.Get('effect', Token), 'effect chapter exists.');
        Effect := Token.AsObject();
        Assert.IsTrue(Effect.Get('changes', Token), 'effect.changes exists.');
        Changes := Token.AsValue().AsText();
        Assert.IsFalse(Changes.Contains('expectedCount'), 'No count sentence remains.');
        Assert.IsFalse(Changes.Contains('expectedCount er alltaf 1'), 'The unrecognized Icelandic sentence is gone.');
    end;

    /// <summary>Only the fourteen explicitly approved posting operations are irreversible across every app-owned type.</summary>
    [Test]
    procedure Scenario_279_AC01_OnlyPostingIsIrreversible()
    var
        MessageType: Enum "Message Type ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Token: JsonToken;
        Expected: List of [Text];
        TypeName: Text;
        Ordinal: Integer;
        Checked: Integer;
        PostingCount: Integer;
    begin
        // Story #279 AC01 | Time: independent | Risk: an unrelated type accidentally becomes irreversible.
        Expected := ('Inventory.AdjustCost.Run,Inventory.CostToGL.Post,Inventory.Revaluation.Post,' +
            'Inventory.PhysInventory.Post,Inventory.PhysInventoryOrder.Post,Inventory.Reclassification.Post,' +
            'Inventory.TransferOrder.Ship,Inventory.TransferOrder.Receive,Inventory.TransferOrder.Post,' +
            'Inventory.AssemblyOrder.Post,Inventory.Assembly.UndoPost,Inventory.Transfer.UndoShipment,' +
            'Sales.Shipment.Undo,Purchase.Receipt.Undo').Split(',');
        foreach TypeName in MessageType.Names() do begin
            Ordinal := MessageType.Ordinals().Get(MessageType.Names().IndexOf(TypeName));
            if (Ordinal >= 10076835) and (Ordinal <= 10077034) then begin
                Checked += 1;
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                Contract := MessageType;
                Clear(Effect);
                Assert.IsTrue(Contract.GetEffect(Effect), TypeName + ' declares an effect.');
                Assert.IsTrue(Effect.Get('effect', Token), TypeName + ' has an effect name.');
                Assert.AreEqual(Expected.Contains(TypeName), Token.AsValue().AsText() = 'irreversible', TypeName + ' follows the posting-only boundary.');
                if Token.AsValue().AsText() = 'irreversible' then
                    PostingCount += 1;
            end;
        end;
        Assert.IsTrue(Checked >= 97, 'Every app-owned type is audited, including non-Inventory names.');
        Assert.AreEqual(14, PostingCount, 'Every KEEP operation remains irreversible.');
    end;

    local procedure AssertOptionalExpectedCount(Contract: JsonObject)
    var
        Parameters: JsonToken;
        Entry: JsonToken;
        Token: JsonToken;
    begin
        Assert.IsTrue(Contract.Get('parameters', Parameters), 'Parameters exist.');
        foreach Entry in Parameters.AsArray() do
            if Entry.AsObject().Get('name', Token) then
                if Token.AsValue().AsText() = 'expectedCount' then begin
                    Assert.IsTrue(Entry.AsObject().Get('required', Token), 'Compatibility parameter declares optionality.');
                    Assert.IsFalse(Token.AsValue().AsBoolean(), 'expectedCount remains optional.');
                    exit;
                end;
        Assert.Fail('expectedCount must remain accepted for strict-key compatibility.');
    end;

    local procedure ExpectedCountDescription(Contract: JsonObject): Text
    var
        Token: JsonToken;
        Entry: JsonToken;
        Name: JsonToken;
        Description: JsonToken;
    begin
        if not Contract.Get('parameters', Token) then
            exit('');
        foreach Entry in Token.AsArray() do
            if Entry.AsObject().Get('name', Name) then
                if Name.AsValue().AsText() = 'expectedCount' then
                    if Entry.AsObject().Get('description', Description) then
                        exit(Description.AsValue().AsText());
        exit('');
    end;
}
