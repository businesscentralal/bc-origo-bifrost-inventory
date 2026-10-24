namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.Post message type.
/// </summary>
codeunit 96914 "Transfer Order Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then exit;
        IsInitialized := true;
    end;

    [Test]
    procedure UndoShipment_SelectedDocumentOnly()
    begin
        VerifyShipmentUndo(false);
    end;

    [Test]
    procedure UndoShipment_SecondLineFailureRollsBackAll()
    begin
        VerifyShipmentUndo(true);
    end;

    [Test]
    procedure UndoShipment_ReceivedIsCodedAndPreserved_EN()
    begin
        VerifyReceivedRefusal(1033);
    end;

    [Test]
    procedure UndoShipment_ReceivedIsCodedAndPreserved_IS()
    begin
        VerifyReceivedRefusal(1039);
    end;

    local procedure VerifyReceivedRefusal(LanguageId: Integer)
    var
        Shipment: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ShipmentNo: Code[20];
        BeforeCount: Integer;
        SavedLanguage: Integer;
    begin
        ShipmentNo := CreateUndoShipment();
        Shipment.Get(ShipmentNo);
        Request.Add('postingType', 'Receive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", Shipment."Transfer Order No.", Request, Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Own shipment is actually received before refusal verification.');
        BeforeCount := Entries.Count();
        Clear(Request);
        Request.Add('documentNo', ShipmentNo);
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        GlobalLanguage(SavedLanguage);
        Assert.IsTrue(Response.Get('code', Token), 'A received shipment has a coded refusal.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Received shipment is a precondition failure.');
        Assert.IsTrue(Response.Get('nextStep', Token), 'Refusal provides the return-transfer next step.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Next step is not empty.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Refusal writes no reversing entries.');
        Line.SetRange("Document No.", ShipmentNo);
        Line.SetRange("Correction Line", true);
        Assert.IsTrue(Line.IsEmpty(), 'The already-received shipment is preserved.');
    end;

    local procedure VerifyShipmentUndo(FailSecondLine: Boolean)
    var
        Line: Record "Transfer Shipment Line";
        OtherLine: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ShipmentNo: Code[20];
        OtherShipmentNo: Code[20];
        BeforeCount: Integer;
    begin
        ShipmentNo := CreateUndoShipment();
        OtherShipmentNo := CreateUndoShipment();
        BeforeCount := Entries.Count();
        if FailSecondLine then begin
            Observer.SetUndoFailure(ShipmentNo, '');
            BindSubscription(Observer);
        end;
        Request.Add('documentNo', ShipmentNo);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        if FailSecondLine then
            UnbindSubscription(Observer);
        Response.Get('status', Token);
        Line.SetRange("Document No.", ShipmentNo);
        Line.SetRange("Correction Line", true);
        if FailSecondLine then begin
            Assert.AreEqual('Error', Token.AsValue().AsText(), 'Injected native failure is returned.');
            Response.Get('error', Token);
            Assert.AreNotEqual(0, StrPos(Token.AsValue().AsText(), 'Owned second undo line failure'), 'The second native line was reached.');
            Assert.AreEqual(2, Observer.UndoCallbacks(), 'Failure after native writes for two selected lines.');
            Assert.AreEqual(0, Line.Count(), 'All selected correction flags roll back.');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'All reversing ledger entries roll back.');
        end else begin
            Assert.AreEqual('Success', Token.AsValue().AsText(), 'Selected shipment undone.');
            Assert.IsTrue(Line.Count() >= 2, 'Both selected lines are reversed.');
            Assert.IsTrue(Entries.Count() > BeforeCount, 'Native reversing entries were posted.');
        end;
        OtherLine.SetRange("Document No.", OtherShipmentNo);
        OtherLine.SetRange("Correction Line", true);
        Assert.AreEqual(0, OtherLine.Count(), 'Another owned shipment is untouched.');
        OtherLine.SetRange("Correction Line", false);
        Assert.AreEqual(2, OtherLine.Count(), 'Both other shipment lines remain unchanged.');
    end;

    local procedure CreateUndoShipment() ShipmentNo: Code[20]
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        Header: Record "Transfer Header";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(Header, Item."No.", 10);
        Helper.CreateTransferLine(Header, Item."No.", 5);
        Codeunit.Run(Codeunit::"Release Transfer Document", Header);
        Request.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", Header."No.", Request, Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Owned shipment fixture posts.');
        Response.Get('postedShipmentNo', Token);
        ShipmentNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
    end;

    [Test]
    procedure Post_Ship_ReturnsPostedShipmentNo()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ShipmentToken : JsonToken;
    begin
        // [SCENARIO] Posting Ship on a released transfer returns postedShipmentNo
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.AreNotEqual('', ShipmentToken.AsValue().AsText(), 'postedShipmentNo should be populated');
    end;

    [Test]
    procedure Post_InvalidPostingType_ReturnsError()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Invalid postingType value returns Error
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Bogus');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [Test]
    procedure Post_DirectTransfer_ReceiptAndShipment_ReturnsBothDocuments()
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        OriginalSetup: Record "Inventory Setup";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ShipmentToken: JsonToken;
        ReceiptToken: JsonToken;
        ShipmentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Receipt and Shipment on a direct transfer posts the shipment and the receipt together.
        Initialize();
        Helper.SetDirectTransferPosting(false, OriginalSetup);
        Helper.CreateReleasedDirectTransfer(TransferHeader, 10);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Ship", 4);
        TransferLine.Modify(true);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);
        Helper.RestoreDirectTransferPosting(OriginalSetup);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ShipmentNo := CopyStr(ShipmentToken.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ShipmentNo, 'postedShipmentNo should be populated');
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferShipmentHeader.Get(ShipmentNo), 'Posted transfer shipment should exist');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(TransferHeader."No."), 'A partial direct transfer should keep the order');
    end;

    [Test]
    procedure Post_Receive_Full_ReturnsPostedReceiptNoAfterHeaderDeleted()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ReceiptToken : JsonToken;
        DocumentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Full Receive after Ship deletes the transfer order and still returns Success with postedReceiptNo.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        DocumentNo := TransferHeader."No.";

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'ship status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Ship should succeed');

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('postingType', 'Receive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'receive status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Full receive must not return an error after the posting committed. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated. ' + JsonText(ResponseJson));
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist. postedReceiptNo=' + ReceiptNo + ' ' + JsonText(ResponseJson));
        Assert.IsFalse(TransferHeader.Get(DocumentNo), 'A full receive deletes the transfer order');
        Assert.IsTrue(ResponseJson.Get('orderDeleted', StatusToken), 'orderDeleted missing');
        Assert.IsTrue(StatusToken.AsValue().AsBoolean(), 'orderDeleted must be true after a full receive');
    end;

    [Test]
    procedure Post_Receive_Partial_KeepsOrderAndReturnsPostedReceiptNo()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ReceiptToken : JsonToken;
        DocumentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Partial Receive after Ship keeps the transfer order and returns postedReceiptNo.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        DocumentNo := TransferHeader."No.";

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'ship status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Ship should succeed');

        TransferLine.SetRange("Document No.", DocumentNo);
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Receive", 4);
        TransferLine.Modify(true);

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('postingType', 'Receive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'receive status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Partial receive should succeed');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(DocumentNo), 'A partial receive keeps the transfer order');
        Assert.IsTrue(ResponseJson.Get('orderDeleted', StatusToken), 'orderDeleted missing');
        Assert.IsFalse(StatusToken.AsValue().AsBoolean(), 'orderDeleted must be false after a partial receive');
    end;

    local procedure JsonText(ResponseJson: JsonObject): Text
    var
        TextValue: Text;
    begin
        ResponseJson.WriteTo(TextValue);
        exit(TextValue);
    end;
}
