namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 192: every irreversible Inventory type keeps its effect and names what expectedCount counts.</summary>
codeunit 96935 "Inv. Count Unit Tests ori"
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
    procedure Scenario_AC03_ReadTypesDoNotClaimCount()
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        Effect: JsonObject;
    begin
        // Issue #192 AC03 edge case: a read type is not made to claim a count; its effect text stays unchanged.
        Effect := Parts.GetEffect('Inventory.TransferOrder.PreviewPost');
        Assert.IsFalse(HasText(Effect, 'changes', 'expectedCount'), 'A read effect does not mention expectedCount.');
    end;

    local procedure VerifyCountUnits(LanguageId: Integer)
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Contract ori";
        TypeName: Text;
        Types: List of [Text];
        Units: List of [Text];
        Supported: Boolean;
        PreviousLanguage: Integer;
        Effect: JsonObject;
        Parameters: JsonArray;
        Token: JsonToken;
        Parameter: JsonToken;
        Name: JsonToken;
        Unit: Text;
        FoundParameter: Boolean;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Types.Add('Inventory.Revaluation.Post');
        Units.Add(Parts.CountUnitRevaluation());
        Types.Add('Inventory.AssemblyOrder.Post');
        Units.Add(Parts.CountUnitAssemblyOrder());
        Types.Add('Inventory.AdjustCost.Run');
        Units.Add(Parts.CountUnitAdjustCost());
        Types.Add('Inventory.CostToGL.Post');
        Units.Add(Parts.CountUnitCostToGL());
        Supported := Parts.SupportsConfirmation();
        foreach TypeName in Types do begin
            MessageType := Enum::"Message Type ori".FromInteger(MessageType.Ordinals().Get(MessageType.Names().IndexOf(TypeName)));
            Clear(Effect);
            Clear(Parameters);
            Implementation := MessageType;
            // [THEN] The effect stays irreversible and its changes text names the unit and the preview.
            Assert.IsTrue(Implementation.GetEffect(Effect), TypeName + ' has an effect chapter.');
            Assert.IsTrue(Effect.Get('effect', Token), TypeName + ' declares an effect.');
            Assert.AreEqual('irreversible', Token.AsValue().AsText(), TypeName + ' stays irreversible.');
            Unit := Units.Get(Types.IndexOf(TypeName));
            Assert.AreNotEqual('', Unit, TypeName + ' has a count unit.');
            // [THEN] AC02: the sentence is translated at 1039 and English at 1033.
            if LanguageId = 1039 then
                Assert.IsTrue(Unit.Contains('telur'), TypeName + ' count unit is Icelandic at 1039.')
            else
                Assert.IsTrue(Unit.Contains('counts'), TypeName + ' count unit is English at 1033.');
            // [THEN] Older Foundation has no confirmation protocol: the app adds no count sentence there.
            Assert.AreEqual(Supported, HasText(Effect, 'changes', Unit), TypeName + ' effect names the count unit exactly when Foundation has the protocol.');
            Assert.AreEqual(Supported, HasText(Effect, 'changes', Parts.CountReadText()), TypeName + ' effect names the side-effect-free preview exactly when Foundation has the protocol.');
            // [THEN] The expectedCount parameter carries the same unit and the preview way.
            FoundParameter := false;
            Assert.IsTrue(Implementation.GetParameters(Parameters), TypeName + ' declares parameters.');
            foreach Parameter in Parameters do
                if Parameter.AsObject().Get('name', Name) then
                    if Name.AsValue().AsText() = 'expectedCount' then begin
                        FoundParameter := true;
                        if Supported then begin
                            Assert.IsTrue(HasText(Parameter.AsObject(), 'description', Unit), TypeName + ' parameter names the count unit.');
                            Assert.IsTrue(HasText(Parameter.AsObject(), 'description', Parts.CountReadText()), TypeName + ' parameter names the preview.');
                        end;
                    end;
            Assert.AreEqual(Supported, FoundParameter, TypeName + ' declares expectedCount exactly when Foundation has the protocol.');
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
