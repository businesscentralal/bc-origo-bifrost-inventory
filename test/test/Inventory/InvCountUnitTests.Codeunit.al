namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 192: every irreversible Inventory type keeps its effect and names what expectedCount counts.</summary>
codeunit 96980 "Inv. Count Unit Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_AC02_CountUnitIsNamed_In1033()
    begin
        // Issue #192 AC01, AC02, AC03 | Time: no date dependency | Risk: read-only contract inspection.
        VerifyCountUnits(1033);
    end;

    [Test]
    procedure Scenario_AC01_AC02_CountUnitIsNamed_In1039()
    begin
        // Issue #192 AC01, AC02, AC03 | Time: no date dependency | Risk: read-only contract inspection.
        VerifyCountUnits(1039);
    end;

    [Test]
    procedure Scenario_AC03_ReadAndWriteTypesDoNotClaimCount()
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        Effect: JsonObject;
    begin
        // Issue #192 AC03 edge case: a type that is not irreversible has no count unit and its effect text stays unchanged.
        Assert.AreEqual('', Parts.CountUnit('Inventory.TransferOrder.PreviewPost'), 'A preview names no count unit.');
        Assert.AreEqual('', Parts.CountUnit('Inventory.Nonexistent.Post'), 'An unknown type names no count unit.');
        Effect := Parts.GetEffect('Inventory.TransferOrder.PreviewPost');
        Assert.IsFalse(HasText(Effect, 'changes', 'expectedCount'), 'A read effect does not mention expectedCount.');
    end;

    local procedure VerifyCountUnits(LanguageId: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        MessageType: Enum "Message Type ori";
        TypeName: Text;
        Types: List of [Text];
        PreviousLanguage: Integer;
        Contract: JsonObject;
        Effect: JsonObject;
        Token: JsonToken;
        Parameter: JsonToken;
        Name: JsonToken;
        Unit: Text;
        FoundParameter: Boolean;
    begin
        Types.Add('Inventory.Revaluation.Post');
        Types.Add('Inventory.TransferOrder.Post');
        Types.Add('Inventory.AssemblyOrder.Post');
        Types.Add('Inventory.AdjustCost.Run');
        Types.Add('Inventory.CostToGL.Post');
        Types.Add('Inventory.Transfer.UndoShipment');
        Types.Add('Inventory.Assembly.UndoPost');
        Types.Add('Inventory.Reclassification.Post');
        Types.Add('Inventory.PhysInventory.Post');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        foreach TypeName in Types do begin
            MessageType := Enum::"Message Type ori".FromInteger(MessageType.Ordinals().Get(MessageType.Names().IndexOf(TypeName)));
            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            // [THEN] The effect stays irreversible and its changes text names the unit and the preview.
            Assert.IsTrue(Contract.Get('effect', Token), TypeName + ' has an effect chapter.');
            Effect := Token.AsObject();
            Assert.IsTrue(Effect.Get('effect', Token), TypeName + ' declares an effect.');
            Assert.AreEqual('irreversible', Token.AsValue().AsText(), TypeName + ' stays irreversible.');
            Unit := Parts.CountUnit(TypeName);
            Assert.AreNotEqual('', Unit, TypeName + ' has a count unit.');
            Assert.IsTrue(HasText(Effect, 'changes', 'expectedCount counts ' + Unit), TypeName + ' effect names the count unit.');
            Assert.IsTrue(HasText(Effect, 'changes', 'send the request without expectedCount and read expected'), TypeName + ' effect names the side-effect-free preview.');
            // [THEN] The expectedCount parameter carries the same unit and the preview way.
            FoundParameter := false;
            Contract.Get('parameters', Token);
            foreach Parameter in Token.AsArray() do
                if Parameter.AsObject().Get('name', Name) then
                    if Name.AsValue().AsText() = 'expectedCount' then begin
                        FoundParameter := true;
                        Assert.IsTrue(HasText(Parameter.AsObject(), 'description', 'It counts ' + Unit), TypeName + ' parameter names the count unit.');
                        Assert.IsTrue(HasText(Parameter.AsObject(), 'description', 'without expectedCount'), TypeName + ' parameter names the preview.');
                    end;
            Assert.IsTrue(FoundParameter, TypeName + ' declares expectedCount.');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure HasText(Value: JsonObject; KeyName: Text; Part: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Value.Get(KeyName, Token) then
            exit(false);
        exit(Token.AsValue().AsText().Contains(Part));
    end;
}
