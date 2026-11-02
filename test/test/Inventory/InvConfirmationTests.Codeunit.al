namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 176: the deployed Foundation confirmation contract and dispatcher boundary for every irreversible Inventory type.</summary>
codeunit 96978 "Inv. Confirmation Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_ConfirmationBoundary_In1033()
    begin
        // Issue #176 AC01 | Time: no date dependency | Risk: only the owned test company setup is changed.
        AssertConfirmationBoundary(1033);
    end;

    [Test]
    procedure Scenario_AC01_ConfirmationBoundary_In1039()
    begin
        // Issue #176 AC01 | Time: no date dependency | Risk: only the owned test company setup is changed.
        AssertConfirmationBoundary(1039);
    end;

    local procedure AssertConfirmationBoundary(LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        PreviousSetup: Record "Inventory Setup ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Implementation: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        TypeName: Text;
        PreviousLanguage: Integer;
        Checked: Integer;
        Effect: JsonObject;
        Contract: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Parameter: JsonToken;
        Name: JsonToken;
        AdvertisesConfirmation: Boolean;
        HadSetup: Boolean;
    begin
        // [GIVEN] Disabled domains create a safe, observable handler refusal after the confirmation gate.
        // No business document or ledger entry is created, posted or undone by this boundary test.
        HadSetup := PreviousSetup.Get();
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := false;
        Setup.Assembly := false;
        Setup.Costing := false;
        Setup."Phys. Inventory" := false;
        Setup.Reclassification := false;
        Setup.Modify();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        foreach TypeName in MessageType.Names() do
            if TypeName.StartsWith('Inventory.') and not TypeName.StartsWith('Inventory.ItemJournal.') then begin
                MessageType := Enum::"Message Type ori".FromInteger(MessageType.Ordinals().Get(MessageType.Names().IndexOf(TypeName)));
                Implementation := MessageType;
                Clear(Effect);
                if Implementation.GetEffect(Effect) then
                    if Effect.Get('effect', Token) then
                        if Token.AsValue().AsText() = 'irreversible' then begin
                            Checked += 1;
                            Clear(Contract);
                            ContractMgt.GetContract(MessageType, Contract);
                            AdvertisesConfirmation := false;
                            if Contract.Get('parameters', Token) then
                                foreach Parameter in Token.AsArray() do
                                    if Parameter.AsObject().Get('name', Name) then
                                        if Name.AsValue().AsText() = 'expectedCount' then begin
                                            AdvertisesConfirmation := true;
                                            AssertText(Parameter.AsObject(), 'type', 'integer');
                                            Assert.IsTrue(Parameter.AsObject().Contains('description'), TypeName + ' documents confirmation.');
                                        end;
                            Assert.AreEqual(Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired'), AdvertisesConfirmation,
                                TypeName + ' exposes the deployed Foundation protocol.');
                            Clear(Request);
                            // [WHEN] Dispatch without confirmation; newer Foundation must refuse before the handler.
                            Response := Dispatch(MessageType, Request);
                            if AdvertisesConfirmation then begin
                                AssertText(Response, 'code', 'ConfirmationRequired');
                                AssertText(Response, 'parameter', 'expectedCount');
                                AssertText(Response, 'expected', '1');
                                Assert.IsFalse(Response.Contains('postedDocumentNo'), 'Preview must not post.');
                                // [THEN] A wrong count is refused; a matching count reaches the real domain gate.
                                Request.Add('expectedCount', 2);
                                Response := Dispatch(MessageType, Request);
                                AssertText(Response, 'code', 'ConfirmationMismatch');
                                AssertText(Response, 'received', '2');
                                AssertText(Response, 'expected', '1');
                                Request.Replace('expectedCount', 1);
                                Response := Dispatch(MessageType, Request);
                            end;
                            // Legacy Foundation has no confirmation gate; it reaches this same handler directly.
                            AssertText(Response, 'code', 'InvalidParameter');
                            Assert.IsTrue(Response.Get('nextStep', Token), 'Handler domain refusal supplies a next action.');
                            Assert.IsFalse(Token.AsValue().AsText() = '', 'The handler ran after confirmation.');
                        end;
            end;
        GlobalLanguage(PreviousLanguage);
        if HadSetup then begin
            Setup.Get();
            Setup."Transfer Orders" := PreviousSetup."Transfer Orders";
            Setup.Assembly := PreviousSetup.Assembly;
            Setup.Costing := PreviousSetup.Costing;
            Setup."Phys. Inventory" := PreviousSetup."Phys. Inventory";
            Setup.Reclassification := PreviousSetup.Reclassification;
            Setup.Modify();
        end else
            Setup.Delete();
        Assert.AreEqual(9, Checked, 'All nine app-owned irreversible types must be exercised.');
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Payload: Text;
        MessageId: Guid;
        EmptyTaskId: Guid;
        ResponseTime: Duration;
    begin
        // Deliberately bypass ConfirmRequest: missing and incorrect counts must reach the real dispatcher unchanged.
        Request.WriteTo(Payload);
        RequestContent.AddText(Payload);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'application/json', RequestContent,
            EmptyTaskId, GlobalLanguage(), MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(Payload, 1);
        Assert.IsTrue(Response.ReadFrom(Payload), 'Dispatcher returns a JSON response.');
        AssertText(Response, 'status', 'Error');
    end;

    local procedure AssertText(Value: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Value.Get(KeyName, Token), 'Missing ' + KeyName);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), 'Exact ' + KeyName);
    end;
}
