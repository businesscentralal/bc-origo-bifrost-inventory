namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 115: partial transfer posting, validation, rollback and bilingual contracts.</summary>
codeunit 96969 "Partial Transfer Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure PartialShipReceive_EN()
    begin
        VerifyPartialFlow(1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure PartialShipReceive_IS()
    begin
        VerifyPartialFlow(1039);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure ShipAboveOutstanding_EN()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":11}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure ShipAboveOutstanding_IS()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":11}]', true, 1039);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure ReceiveAboveShipped_EN()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToReceive":1}]', false, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure ReceiveAboveShipped_IS()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToReceive":1}]', false, 1039);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsDuplicateLines()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":2},{"lineNo":10000,"qtyToShip":2}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsUnknownLine()
    begin
        VerifyInvalid('[{"lineNo":90000,"qtyToShip":2}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsEmptyLines()
    begin
        VerifyInvalid('[]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsMissingQuantity()
    begin
        VerifyInvalid('[{"lineNo":10000}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsZeroQuantity()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":0}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsNegativeQuantity()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":-1}]', true, 1039);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsNumericString()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":"2"}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsNonObjectLine()
    begin
        VerifyInvalid('[null]', true, 1039);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsMalformedLineNumber()
    begin
        VerifyInvalid('[{"lineNo":1.5,"qtyToShip":2}]', true, 1033);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure RejectsEntireRequestBeforeWrites()
    begin
        VerifyInvalid('[{"lineNo":10000,"qtyToShip":2},{"lineNo":20000,"qtyToShip":11}]', true, 1039);
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure NativeFailureRollsBackQuantities()
    var
        Header: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        Item: Record Item;
        Shipment: Record "Transfer Shipment Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateOrder(Header);
        TransferLine.Get(Header."No.", 10000);
        Item.Get(TransferLine."Item No.");
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Request := MakeRequest(Header."No.", '[{"lineNo":10000,"qtyToShip":2}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Ship", Request, 1033, Response);
        VerifyError(Response, 'BusinessCentralError');
        TransferLine.Get(Header."No.", 10000);
        Assert.AreEqual(10, TransferLine."Qty. to Ship", 'Failed posting restores the selected quantity.');
        TransferLine.Get(Header."No.", 20000);
        Assert.AreEqual(10, TransferLine."Qty. to Ship", 'Failed posting restores omitted quantities.');
        Shipment.SetRange("Transfer Order No.", Header."No.");
        Assert.IsTrue(Shipment.IsEmpty(), 'Failed posting leaves no posted shipment.');
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure DirectTransferIsCoded()
    var
        Header: Record "Transfer Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateOrder(Header);
        Header.Validate("Direct Transfer", true);
        Header.Modify(true);
        Request := MakeRequest(Header."No.", '[{"lineNo":10000,"qtyToShip":2}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Ship", Request, 1039, Response);
        VerifyError(Response, 'PreconditionFailed');
    end;

    /// <summary>Verifies the named partial-transfer acceptance scenario.</summary>
    [Test]
    procedure BilingualContractsDeclareEffectAndCountingUnit()
    var
        Contract: Codeunit "Partial Transfer Contract ori";
        Effect: JsonObject;
        Token: JsonToken;
        English: Text;
        Icelandic: Text;
        SavedLanguage: Integer;
        Ship: Boolean;
        Direction: Integer;
    begin
        SavedLanguage := GlobalLanguage();
        for Direction := 1 to 2 do begin
            Ship := Direction = 1;
            GlobalLanguage(1033);
            English := Contract.GetNotes(Ship);
            Effect := Contract.GetEffect(Ship);
            Effect.Get('effect', Token);
            Assert.AreEqual('irreversible', Token.AsValue().AsText(), 'Posting must declare its actual effect.');
            Assert.IsTrue(English.Contains('expectedCount counts transfer orders'), 'English help names the counting unit.');
            GlobalLanguage(1039);
            Icelandic := Contract.GetNotes(Ship);
            Assert.IsTrue(Icelandic.Contains('expectedCount telur flutningspantanir'), 'Icelandic help names the counting unit.');
            Assert.AreNotEqual(English, Icelandic, 'Icelandic help is translated.');
        end;
        GlobalLanguage(SavedLanguage);
        Assert.AreEqual(3, 'Inventory.TransferOrder.Ship'.Split('.').Count(), 'Ship has three name parts.');
        Assert.AreEqual(3, 'Inventory.TransferOrder.Receive'.Split('.').Count(), 'Receive has three name parts.');
    end;

    local procedure VerifyPartialFlow(LanguageId: Integer)
    var
        Header: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ShipmentLine: Record "Transfer Shipment Line";
        ReceiptLine: Record "Transfer Receipt Line";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        OrderNo: Code[20];
    begin
        CreateOrder(Header);
        OrderNo := Header."No.";
        Request := MakeRequest(OrderNo, '[{"lineNo":10000,"qtyToShip":3}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId, Response);
        AssertSuccess(Response);
        Response.Get('postedShipmentNo', Token);
        ShipmentLine.SetRange("Document No.", Token.AsValue().AsText());
        ShipmentLine.SetFilter(Quantity, '<>0');
        Assert.AreEqual(1, ShipmentLine.Count(), 'Only the requested line is shipped.');
        ShipmentLine.FindFirst();
        Assert.AreEqual(3, ShipmentLine.Quantity, 'Exactly three units shipped.');
        TransferLine.Get(OrderNo, 20000);
        Assert.AreEqual(0, TransferLine."Quantity Shipped", 'Omitted line is not shipped.');
        Request := MakeRequest(OrderNo, '[{"lineNo":10000,"qtyToReceive":2}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Receive", Request, LanguageId, Response);
        AssertSuccess(Response);
        Response.Get('postedReceiptNo', Token);
        ReceiptLine.SetRange("Document No.", Token.AsValue().AsText());
        ReceiptLine.SetFilter(Quantity, '<>0');
        Assert.AreEqual(1, ReceiptLine.Count(), 'Only the requested line is received.');
        ReceiptLine.FindFirst();
        Assert.AreEqual(2, ReceiptLine.Quantity, 'Exactly two units received.');
        TransferLine.Get(OrderNo, 10000);
        Assert.AreEqual(3, TransferLine."Quantity Shipped", 'Shipment remains three units.');
        Assert.AreEqual(2, TransferLine."Quantity Received", 'Partial receipt leaves one unit in transit.');
        Request := MakeRequest(OrderNo, '[{"lineNo":10000,"qtyToReceive":2}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Receive", Request, LanguageId, Response);
        VerifyError(Response, 'InvalidLine');
        Request := MakeRequest(OrderNo, '[{"lineNo":10000,"qtyToShip":7},{"lineNo":20000,"qtyToShip":10}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId, Response);
        AssertSuccess(Response);
        Request := MakeRequest(OrderNo, '[{"lineNo":10000,"qtyToReceive":8},{"lineNo":20000,"qtyToReceive":10}]');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Receive", Request, LanguageId, Response);
        AssertSuccess(Response);
        Response.Get('postedReceiptNo', Token);
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Final receipt still returns its posted number.');
        Response.Get('orderDeleted', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'Final receipt reports the completed order deletion.');
        Assert.IsFalse(Header.Get(OrderNo), 'Fully received order is removed by native posting.');
    end;

    local procedure VerifyInvalid(Lines: Text; Ship: Boolean; LanguageId: Integer)
    var
        Header: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateOrder(Header);
        Request := MakeRequest(Header."No.", Lines);
        if Ship then
            Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Ship", Request, LanguageId, Response)
        else
            Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Receive", Request, LanguageId, Response);
        VerifyError(Response, 'InvalidLine');
        TransferLine.Get(Header."No.", 10000);
        Assert.AreEqual(0, TransferLine."Quantity Shipped", 'Invalid request does not ship.');
        Assert.AreEqual(0, TransferLine."Quantity Received", 'Invalid request does not receive.');
        Assert.AreEqual(10, TransferLine."Qty. to Ship", 'Invalid request does not change quantities.');
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
        Helper.CreatePositiveAdjustment(Item."No.", FromLocation.Code, 30);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, TransitLocation.Code);
        Helper.CreateTransferLine(Header, Item."No.", 10);
        Helper.CreateTransferLine(Header, Item."No.", 10);
    end;

    local procedure MakeRequest(OrderNo: Code[20]; LinesText: Text) Request: JsonObject
    var
        Lines: JsonArray;
    begin
        Lines.ReadFrom(LinesText);
        Request.Add('documentNo', OrderNo);
        Request.Add('lines', Lines);
    end;

    local procedure AssertSuccess(Response: JsonObject)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        Assert.IsTrue(Response.Get('status', Token), ResponseText);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
    end;

    local procedure VerifyError(Response: JsonObject; ExpectedCode: Text)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        Assert.IsTrue(Response.Get('code', Token), ResponseText);
        Assert.AreEqual(ExpectedCode, Token.AsValue().AsText(), ResponseText);
        Assert.IsTrue(Response.Get('nextStep', Token), 'Every refusal has nextStep.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'nextStep is actionable.');
    end;
}
