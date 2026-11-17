namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Checks that both carry-out types name the worksheet selection counted by expectedCount (#234).</summary>
codeunit 96948 "CarryOut Count Help ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>AC01 The composed contract names one worksheet selection at both session languages.</summary>
    [Test]
    procedure Scenario_AC01_English_NamesWorksheetSelections()
    begin
        // Story #234 AC01 | Time: independent | Risk: help that says "always 1" without naming the counted unit.
        // GetContract keeps the effect chapter in English at every session language (#777, #1239).
        // Codeunit 98729 reads that chapter at 1033 and at 1039, so both passes need the English marker.
        AssertComposed(1033);
        AssertComposed(1039);
    end;

    /// <summary>AC03 The declared labels translate the count unit.</summary>
    [Test]
    procedure Scenario_AC03_Icelandic_NamesWorksheetSelections()
    begin
        // Story #234 AC03 | Time: independent | Risk: a translated label that drops the Icelandic count marker.
        // The composed chapter stays English. These asserts read the type's own labels at 1039.
        AssertDeclared("Message Type ori"::"Purchase.Requisition.CarryOut", 'ekki fjölda lína eða pantana');
        AssertDeclared("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'ekki fjölda pantana eða lína');
    end;

    /// <summary>AC02 The unrecognized "always 1" sentence is gone from effect.changes.</summary>
    [Test]
    procedure Scenario_AC02_UnrecognizedAlwaysOne_IsAbsent()
    begin
        // Story #234 AC02 | Time: independent | Risk: effect.changes still uses the sentence Foundation cannot derive a count from.
        AssertOldWordingAbsent(1033);
        AssertOldWordingAbsent(1039);
    end;

    local procedure AssertComposed(LanguageId: Integer)
    var
        SavedLanguageId: Integer;
    begin
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(LanguageId);
        AssertComposedType("Message Type ori"::"Purchase.Requisition.CarryOut", 'not the number of lines or orders');
        AssertComposedType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'not the number of orders or lines');
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
        Marker := 'expectedCount counts worksheet selections: always 1';
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'The composed contract is published.');
        Assert.IsTrue(Contract.Get('effect', Token), 'effect chapter exists.');
        Effect := Token.AsObject();
        Assert.IsTrue(Effect.Get('effect', Token), 'effect name exists.');
        Assert.AreEqual('irreversible', Token.AsValue().AsText(), 'Carry-out stays irreversible.');
        Assert.IsTrue(Effect.Get('changes', Token), 'effect.changes exists.');
        Changes := Token.AsValue().AsText();
        Assert.IsTrue(Changes.Contains(Marker), 'effect.changes names the worksheet selection.');
        Assert.IsTrue(Changes.Contains(NotLines), 'effect.changes excludes lines from the count.');
        Assert.IsFalse(Changes.StartsWith('Counts '), 'effect.changes does not use the parameter shorthand.');
        Assert.IsFalse(Changes.StartsWith('Telur '), 'effect.changes does not use the Icelandic parameter shorthand.');
        ParameterDescription := ExpectedCountDescription(Contract);
        Assert.AreNotEqual('', ParameterDescription, 'expectedCount is declared.');
        Assert.IsTrue(ParameterDescription.Contains(Marker), 'expectedCount names the worksheet selection.');
        Assert.IsTrue(ParameterDescription.Contains(NotLines), 'expectedCount excludes lines from the count.');
    end;

    local procedure AssertDeclared(MessageType: Enum "Message Type ori"; NotLines: Text)
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Token: JsonToken;
        ParameterContract: JsonObject;
        SavedLanguageId: Integer;
        Changes: Text;
        ParameterDescription: Text;
        Marker: Text;
    begin
        Marker := 'expectedCount telur val á vinnublaði: alltaf 1';
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1039);
        Contract := MessageType;
        Assert.IsTrue(Contract.GetEffect(Effect), 'The type declares an effect.');
        Assert.IsTrue(Effect.Get('changes', Token), 'effect.changes exists.');
        Changes := Token.AsValue().AsText();
        Assert.IsTrue(Changes.Contains(Marker), 'The Icelandic label names the worksheet selection.');
        Assert.IsTrue(Changes.Contains(NotLines), 'The Icelandic label excludes lines from the count.');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'The type declares parameters.');
        ParameterContract.Add('parameters', Parameters);
        ParameterDescription := ExpectedCountDescription(ParameterContract);
        Assert.AreNotEqual('', ParameterDescription, 'expectedCount is declared on the type.');
        Assert.IsTrue(ParameterDescription.Contains(Marker), 'The Icelandic parameter names the worksheet selection.');
        Assert.IsTrue(ParameterDescription.Contains(NotLines), 'The Icelandic parameter excludes lines from the count.');
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
        Assert.IsFalse(Changes.Contains('expectedCount is always 1'), 'The unrecognized English sentence is gone.');
        Assert.IsFalse(Changes.Contains('expectedCount er alltaf 1'), 'The unrecognized Icelandic sentence is gone.');
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
