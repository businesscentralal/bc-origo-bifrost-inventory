namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Native tests for Inventory.Reservation.Create and Inventory.Reservation.Cancel against a real source line (#122, #125).</summary>
codeunit 96946 "Reservation Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";

    [Test]
    procedure Create_TransferLine_ReservesAndCancelRemovesPair()
    var
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
    begin
        // [GIVEN] A released transfer order line for 6 of an item with 10 on hand at the from location.
        CreateTransferLine(Item, TransferHeader, TransferLine, 10, 6);

        // [WHEN] Reservation.Create reserves 3 against the outbound transfer line.
        RequestJson.Add('sourceType', Database::"Transfer Line");
        RequestJson.Add('sourceNo', TransferHeader."No.");
        RequestJson.Add('sourceLineNo', TransferLine."Line No.");
        RequestJson.Add('quantity', 3);
        RequestJson.Add('itemNo', Item."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);

        // [THEN] Success with the entry number and the reserved quantity, and both sides of the pair exist.
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('entryNo', Token), 'entryNo missing');
        EntryNo := Token.AsValue().AsInteger();
        Assert.AreNotEqual(0, EntryNo, 'entryNo must be populated');
        Assert.IsTrue(ResponseJson.Get('quantity', Token), 'quantity missing');
        Assert.AreEqual(3, Token.AsValue().AsDecimal(), 'Reserved quantity');
        Assert.IsTrue(ResponseJson.Get('fullAutoReservation', Token), 'fullAutoReservation missing');
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'The full quantity is available');
        ReservationEntry.SetRange("Entry No.", EntryNo);
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        Assert.AreEqual(2, ReservationEntry.Count(), 'A reservation is a pair of entries sharing the entry number');
        ReservationEntry.SetRange(Positive, false);
        ReservationEntry.FindFirst();
        Assert.AreEqual(Database::"Transfer Line", ReservationEntry."Source Type", 'The demand side is the transfer line');
        Assert.AreEqual(TransferHeader."No.", ReservationEntry."Source ID", 'Demand source no.');

        // [WHEN] Reservation.Cancel is called with that entry number.
        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('entryNo', EntryNo);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", RequestJson, ResponseJson);

        // [THEN] Success and no reservation with that number is left.
        AssertStatus(ResponseJson, 'Success');
        ReservationEntry.Reset();
        ReservationEntry.SetRange("Entry No.", EntryNo);
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'The reservation pair is cancelled');
    end;

    [Test]
    procedure Create_NoSupply_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] A transfer line for an item with nothing on hand.
        CreateTransferLine(Item, TransferHeader, TransferLine, 0, 2);

        // [WHEN] Reservation.Create is called.
        RequestJson.Add('sourceType', Database::"Transfer Line");
        RequestJson.Add('sourceNo', TransferHeader."No.");
        RequestJson.Add('sourceLineNo', TransferLine."Line No.");
        RequestJson.Add('quantity', 2);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);

        // [THEN] PreconditionFailed and no reservation entry exists for the line.
        AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Nothing to reserve');
        ReservationEntry.SetRange("Source Type", Database::"Transfer Line");
        ReservationEntry.SetRange("Source ID", TransferHeader."No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'No reservation was written');
    end;

    [Test]
    procedure Create_MissingSourceType_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] A request without sourceType.
        RequestJson.Add('sourceNo', 'TO-NONE');
        RequestJson.Add('sourceLineNo', 10000);
        RequestJson.Add('quantity', 1);
        // [WHEN] Reservation.Create runs.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        // [THEN] MissingParameter names sourceType.
        AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('sourceType', Token.AsValue().AsText(), 'parameter');
    end;

    [Test]
    procedure Create_UnknownSourceLine_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] A transfer line reference that does not exist.
        RequestJson.Add('sourceType', Database::"Transfer Line");
        RequestJson.Add('sourceNo', 'NO-SUCH-TO');
        RequestJson.Add('sourceLineNo', 10000);
        RequestJson.Add('quantity', 1);
        // [WHEN] Reservation.Create runs.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        // [THEN] RecordNotFound.
        AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'code');
    end;

    [Test]
    procedure Create_UnsupportedSourceTypeOrZeroQuantity_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] An unsupported source table (Item Ledger Entry, 32).
        RequestJson.Add('sourceType', 32);
        RequestJson.Add('sourceNo', 'X');
        RequestJson.Add('sourceLineNo', 1);
        RequestJson.Add('quantity', 1);
        // [WHEN] Reservation.Create runs.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        // [THEN] InvalidParameter on sourceType.
        AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('sourceType', Token.AsValue().AsText(), 'parameter');

        // [GIVEN] A zero quantity.
        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('sourceType', Database::"Transfer Line");
        RequestJson.Add('sourceNo', 'X');
        RequestJson.Add('sourceLineNo', 1);
        RequestJson.Add('quantity', 0);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        // [THEN] InvalidParameter on quantity.
        AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('quantity', Token.AsValue().AsText(), 'parameter');
    end;

    [Test]
    procedure Cancel_UnknownEntry_ReturnsRecordNotFound()
    var
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
    begin
        // [GIVEN] An entry number above every existing reservation entry.
        ReservationEntry.SetLoadFields("Entry No.");
        if ReservationEntry.FindLast() then
            EntryNo := ReservationEntry."Entry No.";
        RequestJson.Add('entryNo', EntryNo + 1000);
        // [WHEN] Reservation.Cancel runs.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", RequestJson, ResponseJson);
        // [THEN] RecordNotFound on entryNo.
        AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('entryNo', Token.AsValue().AsText(), 'parameter');
    end;

    [Test]
    procedure Scenario_AC03_CreateSales_ItemReserveNever_RefusesWithoutWrites()
    begin
        VerifySalesEligibility('itemNever');
    end;

    [Test]
    procedure Scenario_AC03_CreateSales_LineReserveNever_RefusesWithoutWrites()
    begin
        VerifySalesEligibility('lineNever');
    end;

    [Test]
    procedure Scenario_AC03_CreateSales_DropShipment_RefusesWithoutWrites()
    begin
        VerifySalesEligibility('drop');
    end;

    [Test]
    procedure Scenario_AC03_CreateSales_SpecialOrder_RefusesWithoutWrites()
    begin
        VerifySalesEligibility('special');
    end;

    [Test]
    procedure Scenario_AC03_CreateSales_NoShipmentDate_RefusesWithoutWrites()
    begin
        VerifySalesEligibility('date');
    end;

    [Test]
    procedure Scenario_AC03_CreateSales_Eligible_ReservesAndCancelsPair()
    begin
        VerifySalesEligibility('valid');
    end;

    [Test]
    procedure Scenario_AC03_Cancel_MixedStatus_PreservesPair()
    begin
        VerifyCancelConsistency('status');
    end;

    [Test]
    procedure Scenario_AC03_Cancel_MissingSupply_PreservesPair()
    begin
        VerifyCancelConsistency('missing');
    end;

    [Test]
    procedure Scenario_AC03_Cancel_UnequalBaseQuantity_PreservesPair()
    begin
        VerifyCancelConsistency('quantity');
    end;

    [Test]
    procedure Scenario_AC03_Cancel_DifferentItem_PreservesPair()
    begin
        VerifyCancelConsistency('item');
    end;

    local procedure VerifySalesEligibility(CaseName: Text)
    var
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        LibrarySales: Codeunit "Library - Sales";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
    begin
        // Story #159 AC03 | Time: WorkDate for owned demand | Risk: Create bypasses AutoReserve eligibility.
        CreateTransferLine(Item, TransferHeader, TransferLine, 10, 1);
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 3);
        SalesLine.Validate("Location Code", TransferLine."Transfer-from Code");
        SalesLine.Validate(Reserve, SalesLine.Reserve::Optional);
        SalesLine.Validate("Shipment Date", WorkDate());
        case CaseName of
            'itemNever':
                begin
                    Item.Validate(Reserve, Item.Reserve::Never);
                    Item.Modify(true);
                end;
            'lineNever':
                SalesLine.Validate(Reserve, SalesLine.Reserve::Never);
            'drop':
                SalesLine."Drop Shipment" := true;
            'special':
                SalesLine."Special Order" := true;
            'date':
                SalesLine."Shipment Date" := 0D;
        end;
        SalesLine.Modify(true);
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Request.Add('quantity', 2);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        ReservationEntry.SetRange("Item No.", Item."No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if CaseName = 'valid' then begin
            AssertStatus(Response, 'Success');
            Assert.AreEqual(2, ReservationEntry.Count(), 'Eligible sales source produces a real pair.');
            Response.Get('entryNo', Token);
            EntryNo := Token.AsValue().AsInteger();
            Clear(Request);
            Clear(Response);
            Request.Add('entryNo', EntryNo);
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
            AssertStatus(Response, 'Success');
            Assert.IsTrue(ReservationEntry.IsEmpty(), 'Valid sales pair is cancelled normally.');
        end else begin
            AssertStatus(Response, 'Error');
            Assert.IsTrue(Response.Get('code', Token), 'Eligibility refusal is coded.');
            Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Shared eligibility policy.');
            Assert.IsTrue(ReservationEntry.IsEmpty(), 'Refusal writes no reservation pair.');
        end;
    end;

    local procedure VerifyCancelConsistency(CaseName: Text)
    var
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        Demand: Record "Reservation Entry";
        Supply: Record "Reservation Entry";
        Pair: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
        BeforeCount: Integer;
        DemandModifiedAt: DateTime;
        SupplyModifiedAt: DateTime;
    begin
        // Story #159 AC03 | Time: WorkDate | Risk: cancelling one side destroys an inconsistent reservation pair.
        CreateTransferLine(Item, TransferHeader, TransferLine, 10, 6);
        Request.Add('sourceType', Database::"Transfer Line");
        Request.Add('sourceNo', TransferHeader."No.");
        Request.Add('sourceLineNo', TransferLine."Line No.");
        Request.Add('quantity', 3);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entryNo', Token);
        EntryNo := Token.AsValue().AsInteger();
        Demand.Get(EntryNo, false);
        Supply.Get(EntryNo, true);
        case CaseName of
            'status':
                Supply."Reservation Status" := Supply."Reservation Status"::Tracking;
            'quantity':
                Supply."Quantity (Base)" += 1;
            'item':
                Supply."Item No." := 'W8-MISMATCH';
        end;
        // Deliberately corrupt only this test's own native pair to exercise defensive cancellation.
        if CaseName = 'missing' then
            Supply.Delete(false)
        else begin
            Supply.Modify(false);
            SupplyModifiedAt := Supply.SystemModifiedAt;
        end;
        DemandModifiedAt := Demand.SystemModifiedAt;
        Pair.SetRange("Entry No.", EntryNo);
        BeforeCount := Pair.Count();
        Clear(Request);
        Clear(Response);
        Request.Add('entryNo', EntryNo);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
        AssertStatus(Response, 'Error');
        Assert.IsTrue(Response.Get('code', Token), 'Inconsistent pair refusal is coded.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Pair consistency is checked.');
        Assert.AreEqual(BeforeCount, Pair.Count(), 'No side was removed.');
        Demand.Get(EntryNo, false);
        Assert.AreEqual(DemandModifiedAt, Demand.SystemModifiedAt, 'Demand side unchanged.');
        if CaseName <> 'missing' then begin
            Supply.Get(EntryNo, true);
            Assert.AreEqual(SupplyModifiedAt, Supply.SystemModifiedAt, 'Supply side unchanged.');
        end;
    end;

    local procedure CreateTransferLine(var Item: Record Item; var TransferHeader: Record "Transfer Header"; var TransferLine: Record "Transfer Line"; OnHand: Decimal; LineQuantity: Decimal)
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, OnHand);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", LineQuantity);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
    end;

    local procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        ResponseJson.WriteTo(Serialized);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing: ' + Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Serialized);
    end;
}
