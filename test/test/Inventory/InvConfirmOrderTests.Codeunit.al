namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 286: document validation runs before the irreversible confirmation gate.</summary>
codeunit 97903 "Inv. Confirm Order Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";

    [Test]
    procedure UndoShipment_UnknownDocument_BothCounts_1033()
    begin
        VerifyUnknownUndo(1033);
    end;

    [Test]
    procedure UndoShipment_UnknownDocument_BothCounts_1039()
    begin
        VerifyUnknownUndo(1039);
    end;

    [Test]
    procedure Ship_NoLines_NotConfirmation_1033()
    begin
        VerifyShipNoLines(1033, 'no lines');
    end;

    [Test]
    procedure Ship_NoLines_NotConfirmation_1039()
    begin
        VerifyShipNoLines(1039, 'engar línur');
    end;

    [Test]
    procedure Ship_ValidOrder_ConfirmsThenPosts_1033()
    begin
        VerifyValidShip(1033);
    end;

    [Test]
    procedure Ship_ValidOrder_ConfirmsThenPosts_1039()
    begin
        VerifyValidShip(1039);
    end;

    [Test]
    procedure OtherGatedTypes_InvalidDocument_NotConfirmation_1033()
    begin
        VerifyOtherTypes(1033);
    end;

    [Test]
    procedure OtherGatedTypes_InvalidDocument_NotConfirmation_1039()
    begin
        VerifyOtherTypes(1039);
    end;

    [Test]
    procedure CostRuns_ValidFilter_StillConfirms_1033()
    begin
        VerifyCostStillConfirms(1033);
    end;

    [Test]
    procedure CostRuns_ValidFilter_StillConfirms_1039()
    begin
        VerifyCostStillConfirms(1039);
    end;

    local procedure VerifyUnknownUndo(LanguageId: Integer)
    var
        FoundationSetup: RecordRef;
        Request: JsonObject;
        Response: JsonObject;
        Changed: Boolean;
        Previous: Boolean;
    begin
        Changed := EnableRequiredConfirmation(FoundationSetup, Previous);
        Clear(Request);
        Request.Add('documentNo', 'X-MISSING-286');
        Response := Dispatch("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, LanguageId);
        AssertCode(Response, 'RecordNotFound');
        Request.Add('expectedCount', 1);
        Response := Dispatch("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, LanguageId);
        AssertCode(Response, 'RecordNotFound');
        Request.Replace('expectedCount', 2);
        Response := Dispatch("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, LanguageId);
        AssertCode(Response, 'RecordNotFound');
        RestoreConfirmation(FoundationSetup, Changed, Previous);
    end;

    local procedure VerifyShipNoLines(LanguageId: Integer; ExpectedText: Text)
    var
        Header: Record "Transfer Header";
        FoundationSetup: RecordRef;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Payload: Text;
        Changed: Boolean;
        Previous: Boolean;
    begin
        Changed := EnableRequiredConfirmation(FoundationSetup, Previous);
        CreateHeaderOnly(Header);
        Request.Add('documentNo', Header."No.");
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId);
        AssertCode(Response, 'PreconditionFailed');
        Response.WriteTo(Payload);
        Assert.IsTrue(Response.Get('error', Token), Payload);
        Assert.IsTrue(StrPos(Token.AsValue().AsText(), ExpectedText) > 0, Payload);
        Request.Add('expectedCount', 2);
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId);
        AssertCode(Response, 'PreconditionFailed');
        Assert.IsFalse(Response.Get('code', Token) and (Token.AsValue().AsText() = 'ConfirmationMismatch'), 'A count is not compared for an order with no lines.');
        if Header.Get(Header."No.") then
            Header.Delete(true);
        RestoreConfirmation(FoundationSetup, Changed, Previous);
    end;

    local procedure VerifyValidShip(LanguageId: Integer)
    var
        Header: Record "Transfer Header";
        FoundationSetup: RecordRef;
        Request: JsonObject;
        Lines: JsonArray;
        Line: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Changed: Boolean;
        Previous: Boolean;
    begin
        Changed := EnableRequiredConfirmation(FoundationSetup, Previous);
        CreateOrder(Header);
        Line.Add('lineNo', 10000);
        Line.Add('qtyToShip', 1);
        Lines.Add(Line);
        Request.Add('documentNo', Header."No.");
        Request.Add('lines', Lines);
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId);
        AssertCode(Response, 'ConfirmationRequired');
        AssertText(Response, 'expected', '1');
        Request.Add('expectedCount', 2);
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId);
        AssertCode(Response, 'ConfirmationMismatch');
        Request.Replace('expectedCount', 1);
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId);
        Assert.IsTrue(Response.Get('status', Token), 'Ship response has a status.');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'A matching count ships the order.');
        RestoreConfirmation(FoundationSetup, Changed, Previous);
    end;

    local procedure VerifyOtherTypes(LanguageId: Integer)
    var
        FoundationSetup: RecordRef;
        Request: JsonObject;
        LineNos: JsonArray;
        Response: JsonObject;
        Changed: Boolean;
        Previous: Boolean;
    begin
        Changed := EnableRequiredConfirmation(FoundationSetup, Previous);
        Clear(Request);
        Request.Add('documentNo', 'X-MISSING-286');
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Receive", Request, LanguageId);
        AssertNotConfirmation(Response);
        Clear(Request);
        Request.Add('documentNo', 'X-MISSING-286');
        Request.Add('postingType', 'Ship');
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Post", Request, LanguageId);
        AssertNotConfirmation(Response);
        Clear(Request);
        Request.Add('documentNo', 'X-MISSING-286');
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Post", Request, LanguageId);
        AssertNotConfirmation(Response);
        Response := Dispatch("Message Type ori"::"Inventory.Assembly.UndoPost", Request, LanguageId);
        AssertNotConfirmation(Response);
        Clear(Request);
        Response := Dispatch("Message Type ori"::"Inventory.Reclassification.Post", Request, LanguageId);
        AssertNotConfirmation(Response);
        Response := DispatchWithSubject("Message Type ori"::"Inventory.PhysInventory.Post", 'XCONFIRM-BOUNDARY', Request, LanguageId);
        AssertNotConfirmation(Response);
        Response := DispatchWithSubject("Message Type ori"::"Inventory.Revaluation.Post", 'XCONFIRM-BOUNDARY', Request, LanguageId);
        AssertNotConfirmation(Response);
        Response := DispatchWithSubject("Message Type ori"::"Inventory.PhysInventoryOrder.Post", 'X-MISSING-286', Request, LanguageId);
        AssertNotConfirmation(Response);
        Clear(Request);
        Request.Add('documentNo', 'X-MISSING-286');
        LineNos.Add(10000);
        Request.Add('lineNos', LineNos);
        Response := Dispatch("Message Type ori"::"Sales.Shipment.Undo", Request, LanguageId);
        AssertNotConfirmation(Response);
        Response := Dispatch("Message Type ori"::"Purchase.Receipt.Undo", Request, LanguageId);
        AssertNotConfirmation(Response);
        Clear(Request);
        Request.Add('postingDate', '2026-01-01');
        Response := Dispatch("Message Type ori"::"Inventory.AdjustCost.Run", Request, LanguageId);
        AssertCode(Response, 'UnknownParameter');
        RestoreConfirmation(FoundationSetup, Changed, Previous);
    end;

    local procedure VerifyCostStillConfirms(LanguageId: Integer)
    var
        FoundationSetup: RecordRef;
        Request: JsonObject;
        Response: JsonObject;
        Changed: Boolean;
        Previous: Boolean;
    begin
        Changed := EnableRequiredConfirmation(FoundationSetup, Previous);
        Request.Add('itemNoFilter', 'XCONFIRM-BOUNDARY');
        Response := Dispatch("Message Type ori"::"Inventory.AdjustCost.Run", Request, LanguageId);
        AssertCode(Response, 'ConfirmationRequired');
        AssertText(Response, 'expected', '1');
        Clear(Request);
        Request.Add('itemNoFilter', 'XCONFIRM-BOUNDARY');
        Response := Dispatch("Message Type ori"::"Inventory.CostToGL.Post", Request, LanguageId);
        AssertCode(Response, 'ConfirmationRequired');
        AssertText(Response, 'expected', '1');
        RestoreConfirmation(FoundationSetup, Changed, Previous);
    end;

    local procedure CreateHeaderOnly(var Header: Record "Transfer Header")
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        TransitLocation: Record Location;
        Item: Record Item;
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := true;
        Setup.Modify(true);
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, TransitLocation, Item, 0);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, TransitLocation.Code);
    end;

    local procedure CreateOrder(var Header: Record "Transfer Header")
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        TransitLocation: Record Location;
        Item: Record Item;
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := true;
        Setup.Modify(true);
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, TransitLocation, Item, 0);
        FromLocation.Rename(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10));
        ToLocation.Rename(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10));
        TransitLocation.Rename(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10));
        Item.Rename(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
        Helper.CreatePositiveAdjustment(Item."No.", FromLocation.Code, 10);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, TransitLocation.Code);
        Helper.CreateTransferLine(Header, Item."No.", 4);
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer) Response: JsonObject
    begin
        Response := DispatchWithSubject(MessageType, '', Request, LanguageId);
    end;

    local procedure DispatchWithSubject(MessageType: Enum "Message Type ori"; Subject: Text[250]; Request: JsonObject; LanguageId: Integer) Response: JsonObject
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
        Request.WriteTo(Payload);
        RequestContent.AddText(Payload);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", Subject, '', 'application/json', RequestContent,
            EmptyTaskId, LanguageId, MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(Payload, 1);
        Assert.IsTrue(Response.ReadFrom(Payload), 'Dispatcher returns JSON.');
    end;

    local procedure AssertCode(Response: JsonObject; Expected: Text)
    var
        Token: JsonToken;
        Payload: Text;
    begin
        Response.WriteTo(Payload);
        Assert.IsTrue(Response.Get('code', Token), Payload);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Payload);
    end;

    local procedure AssertText(Response: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
        Payload: Text;
    begin
        Response.WriteTo(Payload);
        Assert.IsTrue(Response.Get(Name, Token), Payload);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Payload);
    end;

    local procedure AssertNotConfirmation(Response: JsonObject)
    var
        Token: JsonToken;
        Payload: Text;
    begin
        Response.WriteTo(Payload);
        Assert.IsTrue(Response.Get('code', Token), Payload);
        Assert.AreNotEqual('ConfirmationRequired', Token.AsValue().AsText(), Payload);
        Assert.AreNotEqual('ConfirmationMismatch', Token.AsValue().AsText(), Payload);
    end;

    local procedure EnableRequiredConfirmation(var FoundationSetup: RecordRef; var PreviousConfirmation: Boolean): Boolean
    var
        ConfirmationField: FieldRef;
        FieldIndex: Integer;
    begin
        FoundationSetup.Open(Database::"Setup ori");
        if not FoundationSetup.FindFirst() then
            exit(false);
        for FieldIndex := 1 to FoundationSetup.FieldCount() do begin
            ConfirmationField := FoundationSetup.FieldIndex(FieldIndex);
            if ConfirmationField.Name() = 'Require Irreversible Confirm' then begin
                PreviousConfirmation := ConfirmationField.Value();
                ConfirmationField.Value := true;
                FoundationSetup.Modify();
                exit(true);
            end;
        end;
        FoundationSetup.Close();
        exit(false);
    end;

    local procedure RestoreConfirmation(var FoundationSetup: RecordRef; ChangedConfirmation: Boolean; PreviousConfirmation: Boolean)
    var
        ConfirmationField: FieldRef;
        FieldIndex: Integer;
    begin
        if not ChangedConfirmation then
            exit;
        FoundationSetup.FindFirst();
        for FieldIndex := 1 to FoundationSetup.FieldCount() do begin
            ConfirmationField := FoundationSetup.FieldIndex(FieldIndex);
            if ConfirmationField.Name() = 'Require Irreversible Confirm' then begin
                ConfirmationField.Value := PreviousConfirmation;
                FoundationSetup.Modify();
                FoundationSetup.Close();
                exit;
            end;
        end;
    end;
}
