namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Service.Document;
using Microsoft.Service.Test;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Native tests for Inventory.Reservation.Create, .Get and .Cancel against a real source line (#7, #122, #125).</summary>
codeunit 96946 "Reservation Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        DomainSetup: Codeunit "Inventory Test Library ori";
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
        DomainSetup.EnableReservations();
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
        DomainSetup.EnableReservations();
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
        DomainSetup.EnableReservations();
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
        DomainSetup.EnableReservations();
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
        DomainSetup.EnableReservations();
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
        DomainSetup.EnableReservations();
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
        // [THEN] The refusal carries received, expected and an actionable nextStep (#151 refusal contract, #169).
        Assert.IsTrue(ResponseJson.Get('received', Token), 'received missing');
        Assert.AreEqual(Format(EntryNo + 1000, 0, 9), Token.AsValue().AsText(), 'received');
        Assert.IsTrue(ResponseJson.Get('expected', Token), 'expected missing');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'expected must not be empty');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.IsTrue(Token.AsValue().AsText().Contains('Inventory.Reservation.Get'), 'nextStep names Inventory.Reservation.Get');
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

    [Test]
    procedure Scenario_Issue7_AC2_GetBySourceLine_ReturnsOnlyThatLine()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        OtherLine: Record "Sales Line";
        Request: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
        EntryToken: JsonToken;
        Token: JsonToken;
        EntryObject: JsonObject;
    begin
        // [GIVEN] Two reserved lines of one sales order.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 10, 3);
        AddSalesLine(SalesHeader, SalesLine, OtherLine, 2);
        ReserveSalesLine(SalesHeader, SalesLine, 2);
        ReserveSalesLine(SalesHeader, OtherLine, 1);

        // [WHEN] Reservation.Get reads the first line.
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceSubtype', 1);
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", Request, Response);

        // [THEN] Only the demand entries of that line come back, with source, tracking and sign fields.
        AssertStatus(Response, 'Success');
        Response.Get('entries', Token);
        Entries := Token.AsArray();
        Assert.AreNotEqual(0, Entries.Count(), 'The line has reservation entries.');
        foreach EntryToken in Entries do begin
            EntryObject := EntryToken.AsObject();
            EntryObject.Get('sourceRefNo', Token);
            Assert.AreEqual(SalesLine."Line No.", Token.AsValue().AsInteger(), 'Only the requested line.');
            EntryObject.Get('sourceType', Token);
            Assert.AreEqual(Database::"Sales Line", Token.AsValue().AsInteger(), 'sourceType of the demand side.');
            EntryObject.Get('positive', Token);
            Assert.IsFalse(Token.AsValue().AsBoolean(), 'A sales line is the demand side.');
            EntryObject.Get('quantityBase', Token);
            Assert.IsTrue(Token.AsValue().AsDecimal() < 0, 'The stored sign is kept.');
            Assert.IsTrue(EntryObject.Contains('lotNo') and EntryObject.Contains('serialNo') and EntryObject.Contains('packageNo'), 'Tracking keys are answered.');
            EntryObject.Get('reservationStatus', Token);
            Assert.AreEqual('Reservation', Token.AsValue().AsText(), 'Status by name.');
        end;
    end;

    [Test]
    procedure Scenario_Issue7_AC3_GetByEntryNo_ReturnsPairAndUnknownIsRecordNotFound()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
    begin
        // [GIVEN] One reservation on a sales line.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 10, 3);
        EntryNo := ReserveSalesLine(SalesHeader, SalesLine, 2);

        // [WHEN] Reservation.Get reads that entry number.
        Request.Add('entryNo', EntryNo);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", Request, Response);

        // [THEN] Both sides of the pair are answered.
        AssertStatus(Response, 'Success');
        Response.Get('entries', Token);
        Assert.AreEqual(2, Token.AsArray().Count(), 'Supply and demand side share the entry number.');

        // [WHEN] An entry number that does not exist is read.
        ReservationEntry.FindLast();
        Clear(Request);
        Clear(Response);
        Request.Add('entryNo', ReservationEntry."Entry No." + 1000);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", Request, Response);

        // [THEN] A coded RecordNotFound, not an exception.
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'Unknown entry.');
    end;

    [Test]
    procedure Scenario_Issue7_GetSourceTypeWithoutSourceNo_ReturnsMissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] The Reservations domain is on.
        DomainSetup.EnableReservations();
        // [WHEN] Reservation.Get names a source type without the document.
        Request.Add('sourceType', Database::"Sales Line");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", Request, Response);
        // [THEN] MissingParameter: a source line needs sourceType and sourceNo together.
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'sourceNo is required with sourceType.');
    end;

    [Test]
    procedure Scenario_Issue7_AC8_CancelBySourceLine_CancelsEveryPairOfTheLine()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        OtherLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        FirstEntryNo: Integer;
        SecondEntryNo: Integer;
        Expected: Integer;
    begin
        // [GIVEN] Two reservations on one sales line and one on another line.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 10, 3);
        AddSalesLine(SalesHeader, SalesLine, OtherLine, 2);
        FirstEntryNo := ReserveSalesLine(SalesHeader, SalesLine, 1);
        SecondEntryNo := ReserveSalesLine(SalesHeader, SalesLine, 1);
        ReserveSalesLine(SalesHeader, OtherLine, 1);
        Expected := 2;
        if FirstEntryNo = SecondEntryNo then
            Expected := 1;

        // [WHEN] Reservation.Cancel names the first source line.
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);

        // [THEN] Every pair of that line is cancelled, the other line keeps its reservation.
        AssertStatus(Response, 'Success');
        Response.Get('entriesCancelled', Token);
        Assert.AreEqual(Expected, Token.AsValue().AsInteger(), 'entriesCancelled counts the pairs of the line.');
        Response.Get('quantity', Token);
        Assert.AreEqual(2, Token.AsValue().AsDecimal(), 'Cancelled quantity of the line.');
        ReservationEntry.SetRange("Source Type", Database::"Sales Line");
        ReservationEntry.SetRange("Source ID", SalesHeader."No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'No reservation is left on the line.');
        ReservationEntry.SetRange("Source Ref. No.", OtherLine."Line No.");
        Assert.IsFalse(ReservationEntry.IsEmpty(), 'The other line is untouched.');
    end;

    [Test]
    procedure Scenario_Issue7_AC8_CancelBySourceLine_NoReservations_SucceedsWithZero()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] An open sales line without reservations.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 10, 3);
        // [WHEN] Reservation.Cancel names the line.
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
        // [THEN] Idempotent Success with entriesCancelled 0.
        AssertStatus(Response, 'Success');
        Response.Get('entriesCancelled', Token);
        Assert.AreEqual(0, Token.AsValue().AsInteger(), 'Nothing to cancel.');
    end;

    [Test]
    procedure Scenario_Issue7_AC8_CancelBySourceLine_MissingLineNo_ReturnsMissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] The Reservations domain is on.
        DomainSetup.EnableReservations();
        // [WHEN] Reservation.Cancel names a document without a line.
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', 'NOSUCHDOC');
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
        // [THEN] MissingParameter for sourceLineNo.
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'sourceLineNo is required.');
    end;

    [Test]
    procedure Scenario_Issue7_AC7_ClosedSalesLine_CreateAndCancelArePreconditionFailed()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] A sales line whose outstanding quantity is 0.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 10, 3);
        SalesLine.Validate(Quantity, 0);
        SalesLine.Modify(true);
        Assert.AreEqual(0, SalesLine."Outstanding Quantity", 'Fixture: the line is closed.');

        // [WHEN] Reservation.Create is called for the closed line.
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Request.Add('quantity', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        // [THEN] PreconditionFailed and nothing is written.
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Create refuses a closed line.');
        ReservationEntry.SetRange("Item No.", Item."No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'No reservation was written.');

        // [WHEN] Reservation.Cancel names the closed line.
        Clear(Request);
        Clear(Response);
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
        // [THEN] PreconditionFailed as well.
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Cancel refuses a closed line.');
    end;

    [Test]
    procedure Scenario_AC04_LotFilter_ReservesMatchingInventory()
    begin
        // Story #7, AC04/AC05 | Time: WorkDate for supply and demand | Risk: None
        VerifySupplySelection('lot');
    end;

    [Test]
    procedure Scenario_AC04_SerialFilter_ReservesMatchingInventory()
    begin
        // Story #7, AC04/AC05 | Time: WorkDate for supply and demand | Risk: None
        VerifySupplySelection('serial');
    end;

    [Test]
    procedure Scenario_AC04_PackageFilter_ReservesMatchingInventory()
    begin
        // Story #7, AC04/AC05 | Time: WorkDate for supply and demand | Risk: None
        VerifySupplySelection('package');
    end;

    [Test]
    procedure Scenario_AC05_SelectedEntry_ReservesOnlyNamedSupply()
    begin
        // Story #7, AC04/AC05 | Time: WorkDate for supply and demand | Risk: None
        VerifySupplySelection('selected');
    end;

    [Test]
    procedure Scenario_AC05_InsufficientSelectedSupply_LeavesNoReservation()
    begin
        // Story #7, AC04/AC05 | Time: WorkDate for supply and demand | Risk: None
        VerifySupplySelection('insufficient');
    end;

    [Test]
    procedure Scenario_AC05_ConflictingTracking_LeavesNoReservation()
    begin
        // Story #7, AC04/AC05 | Time: WorkDate for supply and demand | Risk: None
        VerifySupplySelection('conflict');
    end;

    [Test]
    procedure Scenario_AC04_InvalidTrackingValue_RefusesBeforeWrites()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #7, AC04 | Time: None | Risk: None
        DomainSetup.EnableReservations();
        // [GIVEN] A lot number sent as a JSON number instead of a string.
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', 'NO-SUCH-LINE');
        Request.Add('sourceLineNo', 10000);
        Request.Add('quantity', 1);
        Request.Add('lotNo', 123);
        // [WHEN] Create validates the request before source resolution.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        // [THEN] InvalidParameterFormat identifies the malformed tracking key.
        AssertStatus(Response, 'Error');
        Response.Get('parameter', Token);
        Assert.AreEqual('lotNo', Token.AsValue().AsText(), 'Invalid tracking parameter.');
    end;

    [Test]
    procedure Scenario_AC04_ServiceLine_ReservesAndCancels()
    begin
        // Story #7, Oct06 source scope | Time: WorkDate for availability | Risk: None
        VerifyAdditionalSource('service');
    end;

    [Test]
    procedure Scenario_AC04_ProductionLine_ReservesAndCancels()
    begin
        // Story #7, Oct06 source scope | Time: WorkDate for availability | Risk: None
        VerifyAdditionalSource('production');
    end;

    [Test]
    procedure Scenario_AC04_ProductionComponent_ReservesAndCancels()
    begin
        // Story #7, Oct06 source scope | Time: WorkDate for availability | Risk: None
        VerifyAdditionalSource('component');
    end;

    [Test]
    procedure Scenario_AC08_ProductionStatus_CancelPreservesOtherStatus()
    begin
        // Story #7: equal production pointers in different statuses must not share cancellation.
        VerifyAdditionalSource('productionStatus');
    end;

    [Test]
    procedure Scenario_AC08_ComponentStatus_CancelPreservesOtherStatus()
    begin
        // Story #7: component cancellation also requires the complete production status key.
        VerifyAdditionalSource('componentStatus');
    end;

    [Test]
    procedure Scenario_AC04_ItemJournalLine_ReservesAndCancels()
    begin
        // Story #7, Oct06 source scope | Time: WorkDate for availability | Risk: None
        VerifyAdditionalSource('journal');
    end;

    [Test]
    procedure Scenario_AC04_AssemblyHeader_ReservesAndCancels()
    begin
        // Story #7, Oct06 source scope | Time: WorkDate for availability | Risk: None
        VerifyAdditionalSource('assemblyHeader');
    end;

    [Test]
    procedure Scenario_AC04_SerialMultipleUnits_RefusesWithoutWrites()
    begin
        // Story #7, AC04 | Time: WorkDate for supply | Risk: None
        VerifySupplySelection('serialOver');
    end;

    [Test]
    procedure Scenario_AC04_NonReservableJournal_RefusesWithoutWrites()
    begin
        // Story #7, AC04 | Time: WorkDate for supply | Risk: Native journal eligibility is retained
        VerifyAdditionalSource('journalInvalid');
    end;

    [Test]
    procedure Scenario_AC04_JournalWithoutBatch_ReturnsMissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #7, AC04 | Time: None | Risk: None
        DomainSetup.EnableReservations();
        // [GIVEN] An incomplete journal source pointer.
        Request.Add('sourceType', Database::"Item Journal Line");
        Request.Add('sourceSubtype', 3);
        Request.Add('sourceNo', 'MISSING');
        Request.Add('sourceLineNo', 10000);
        Request.Add('quantity', 1);
        // [WHEN] Create validates the native journal key.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        // [THEN] The batch is mandatory before any source is read or reserved.
        AssertStatus(Response, 'Error');
        Response.Get('parameter', Token);
        Assert.AreEqual('sourceBatchName', Token.AsValue().AsText(), 'Batch part of the source key.');
    end;

    [Test]
    procedure Scenario_AC04_ComponentWithoutParentLine_ReturnsMissingParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #7, AC04 | Time: None | Risk: None
        DomainSetup.EnableReservations();
        // [GIVEN] A component pointer without its parent production line.
        Request.Add('sourceType', Database::"Prod. Order Component");
        Request.Add('sourceSubtype', 3);
        Request.Add('sourceNo', 'MISSING');
        Request.Add('sourceLineNo', 10000);
        Request.Add('quantity', 1);
        // [WHEN] Create validates the native production key.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        // [THEN] The parent line is mandatory before any source is read or reserved.
        AssertStatus(Response, 'Error');
        Response.Get('parameter', Token);
        Assert.AreEqual('sourceProdOrderLine', Token.AsValue().AsText(), 'Parent part of the source key.');
    end;

    [Test]
    procedure Scenario_AC08_GenericWrite_NamesDedicatedTypesInBothLanguages()
    var
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Keys: JsonObject;
        Fields: JsonObject;
        Rows: JsonArray;
        ResponseText: Text;
        LanguageId: Integer;
        Languages: List of [Integer];
    begin
        // Story #7, write guard DoD | Time: None | Risk: None
        DomainSetup.EnableReservations();
        // [GIVEN] A valid generic write envelope targeting the guarded reservation table.
        Keys.Add('EntryNo_', 2147483000);
        Keys.Add('Positive', false);
        Fields.Add('Quantity', 1);
        Row.Add('primaryKey', Keys);
        Row.Add('fields', Fields);
        Rows.Add(Row);
        Request.Add('data', Rows);
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            // [WHEN] The request reaches Foundation's normal table write restriction.
            Clear(Response);
            Helper.ProcessMessage("Message Type ori"::"Data.Records.Set", 'Reservation Entry', Request, LanguageId, Response);
            // [THEN] Both dedicated native write types are named in the refusal in either language.
            AssertStatus(Response, 'Error');
            Response.WriteTo(ResponseText);
            Assert.IsTrue(ResponseText.Contains('Inventory.Reservation.Create'), 'Create is named in the restriction hint.');
            Assert.IsTrue(ResponseText.Contains('Inventory.Reservation.Cancel'), 'Cancel is named in the restriction hint.');
        end;
    end;

    local procedure VerifyAdditionalSource(CaseName: Text)
    var
        Item: Record Item;
        ParentItem: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        AssemblyHeader: Record "Assembly Header";
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        JournalLine: Record "Item Journal Line";
        OtherBatch: Record "Item Journal Batch";
        OtherJournal: Record "Item Journal Line";
        OtherProdLine: Record "Prod. Order Line";
        OtherProductionOrder: Record "Production Order";
        OtherComponent: Record "Prod. Order Component";
        Entry: Record "Reservation Entry";
        LibraryAssembly: Codeunit "Library - Assembly";
        LibraryService: Codeunit "Library - Service";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryInventory: Codeunit "Library - Inventory";
        Request: JsonObject;
        Response: JsonObject;
        CancelRequest: JsonObject;
        IncompleteRequest: JsonObject;
        OtherRequest: JsonObject;
        ReadResponse: JsonObject;
        Token: JsonToken;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceLineNo: Integer;
        ParentLineNo: Integer;
        SourceNo: Code[20];
        BatchName: Code[10];
        DifferentStatus: Boolean;
    begin
        DifferentStatus := CaseName in ['productionStatus', 'componentStatus'];
        if CaseName = 'productionStatus' then
            CaseName := 'production';
        if CaseName = 'componentStatus' then
            CaseName := 'component';
        // [GIVEN] Real stock and native source records, independently seeded by the test.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 10, 5);
        case CaseName of
            'assemblyHeader':
                begin
                    LibraryAssembly.CreateAssemblyHeader(AssemblyHeader, WorkDate(), Item."No.", SalesLine."Location Code", 3, '');
                    SourceType := Database::"Assembly Header";
                    SourceSubtype := AssemblyHeader."Document Type".AsInteger();
                    SourceNo := AssemblyHeader."No.";
                end;
            'service':
                begin
                    LibraryService.CreateServiceHeader(ServiceHeader, ServiceHeader."Document Type"::Order, '');
                    LibraryService.CreateServiceLine(ServiceLine, ServiceHeader, ServiceLine.Type::Item, Item."No.");
                    ServiceLine.Validate("Location Code", SalesLine."Location Code");
                    ServiceLine.Validate(Quantity, 3);
                    ServiceLine.Validate("Needed by Date", WorkDate());
                    ServiceLine.Modify(true);
                    SourceType := Database::"Service Line";
                    SourceSubtype := ServiceLine."Document Type".AsInteger();
                    SourceNo := ServiceLine."Document No.";
                    SourceLineNo := ServiceLine."Line No.";
                end;
            'production', 'component':
                begin
                    if CaseName = 'component' then
                        LibraryInventory.CreateItem(ParentItem)
                    else
                        ParentItem := Item;
                    LibraryManufacturing.CreateProductionOrder(ProductionOrder, ProductionOrder.Status::Released,
                        ProductionOrder."Source Type"::Item, ParentItem."No.", 3);
                    LibraryManufacturing.CreateProdOrderLine(ProdOrderLine, ProductionOrder.Status, ProductionOrder."No.",
                        ParentItem."No.", '', SalesLine."Location Code", 3);
                    ProdOrderLine.Validate("Due Date", WorkDate());
                    ProdOrderLine.Modify(true);
                    SourceSubtype := ProdOrderLine.Status.AsInteger();
                    SourceNo := ProductionOrder."No.";
                    ParentLineNo := ProdOrderLine."Line No.";
                    if CaseName = 'production' then
                        SourceType := Database::"Prod. Order Line"
                    else begin
                        Component.Init();
                        Component.Status := ProductionOrder.Status;
                        Component."Prod. Order No." := ProductionOrder."No.";
                        Component."Prod. Order Line No." := ParentLineNo;
                        Component."Line No." := 10000;
                        Component.Insert(true);
                        Component.Validate("Item No.", Item."No.");
                        Component.Validate("Location Code", SalesLine."Location Code");
                        Component.Validate("Quantity per", 1);
                        Component.Validate("Expected Quantity", 3);
                        Component.Validate("Due Date", WorkDate());
                        Component.Modify(true);
                        SourceType := Database::"Prod. Order Component";
                        SourceLineNo := Component."Line No.";
                    end;
                end;
            'journal', 'journalInvalid':
                begin
                    LibraryInventory.CreateItemJnlLine(JournalLine, JournalLine."Entry Type"::Transfer, WorkDate(),
                        Item."No.", 3, SalesLine."Location Code");
                    if CaseName = 'journalInvalid' then begin
                        JournalLine.Validate("Entry Type", JournalLine."Entry Type"::"Negative Adjmt.");
                        JournalLine.Modify(true);
                    end;
                    SourceType := Database::"Item Journal Line";
                    SourceSubtype := JournalLine."Entry Type".AsInteger();
                    SourceNo := JournalLine."Journal Template Name";
                    BatchName := JournalLine."Journal Batch Name";
                    SourceLineNo := JournalLine."Line No.";
                end;
        end;
        Request.Add('sourceType', SourceType);
        Request.Add('sourceSubtype', SourceSubtype);
        Request.Add('sourceNo', SourceNo);
        Request.Add('sourceLineNo', SourceLineNo);
        if BatchName <> '' then
            Request.Add('sourceBatchName', BatchName);
        if ParentLineNo <> 0 then
            Request.Add('sourceProdOrderLine', ParentLineNo);
        CancelRequest := Request.Clone().AsObject();
        Request.Add('quantity', 2);

        // [WHEN] Create reserves through the native source-specific reservation subscriber.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);

        // [THEN] Native eligibility is retained; valid sources have an actual reservation pair.
        if CaseName = 'journalInvalid' then begin
            AssertStatus(Response, 'Error');
            Response.Get('code', Token);
            Assert.AreEqual('BusinessCentralError', Token.AsValue().AsText(), 'Native journal eligibility refusal.');
            Entry.SetRange("Source Type", SourceType);
            Entry.SetRange("Source ID", SourceNo);
            Entry.SetRange("Source Batch Name", BatchName);
            Assert.IsTrue(Entry.IsEmpty(), 'BC refuses journal entries that are not true demand or supply without writes.');
            exit;
        end;
        AssertStatus(Response, 'Success');
        Response.Get('quantity', Token);
        Assert.AreEqual(2, Token.AsValue().AsDecimal(), 'Reserved for the native source.');
        // [GIVEN] A second native source with the same template/order and line number but a different batch/parent.
        if CaseName in ['journal', 'production', 'component'] then begin
            OtherRequest := CancelRequest.Clone().AsObject();
            if CaseName = 'journal' then begin
                LibraryInventory.CreateItemJournalBatch(OtherBatch, JournalLine."Journal Template Name");
                LibraryInventory.CreateItemJournalLine(OtherJournal, JournalLine."Journal Template Name", OtherBatch.Name,
                    JournalLine."Entry Type", Item."No.", 3);
                if OtherJournal."Line No." <> SourceLineNo then
                    OtherJournal.Rename(OtherJournal."Journal Template Name", OtherJournal."Journal Batch Name", SourceLineNo);
                OtherJournal.Validate("Location Code", JournalLine."Location Code");
                OtherJournal.Modify(true);
                OtherRequest.Replace('sourceBatchName', OtherBatch.Name);
                OtherRequest.Replace('sourceLineNo', OtherJournal."Line No.");
                Assert.AreEqual(SourceLineNo, OtherJournal."Line No.", 'Equal line numbers exercise batch isolation.');
            end else begin
                OtherProductionOrder := ProductionOrder;
                if DifferentStatus then begin
                    OtherProductionOrder.Status := OtherProductionOrder.Status::"Firm Planned";
                    OtherProductionOrder.Insert(true);
                end;
                LibraryManufacturing.CreateProdOrderLine(OtherProdLine, OtherProductionOrder.Status, OtherProductionOrder."No.",
                    ParentItem."No.", '', SalesLine."Location Code", 3);
                OtherProdLine.Validate("Due Date", WorkDate());
                OtherProdLine.Modify(true);
                if DifferentStatus then
                    Assert.AreEqual(ParentLineNo, OtherProdLine."Line No.", 'Equal line numbers exercise status isolation.');
                if CaseName = 'component' then begin
                    OtherComponent := Component;
                    OtherComponent.Status := OtherProductionOrder.Status;
                    OtherComponent."Prod. Order Line No." := OtherProdLine."Line No.";
                    OtherComponent.Insert(true);
                end;
                OtherRequest.Replace('sourceSubtype', OtherProductionOrder.Status.AsInteger());
                OtherRequest.Replace('sourceProdOrderLine', OtherProdLine."Line No.");
            end;
            OtherRequest.Add('quantity', 1);
            Clear(ReadResponse);
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", OtherRequest, ReadResponse);
            AssertStatus(ReadResponse, 'Success');
            OtherRequest.Remove('quantity');
        end;
        // [WHEN] Get uses the complete source pointer.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", CancelRequest, ReadResponse);
        AssertStatus(ReadResponse, 'Success');
        ReadResponse.Get('entries', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Get selects only the requested batch or production parent.');
        Entry.SetRange("Source Type", SourceType);
        Entry.SetRange("Source Subtype", SourceSubtype);
        Entry.SetRange("Source ID", SourceNo);
        Entry.SetRange("Source Ref. No.", SourceLineNo);
        Entry.SetRange("Source Prod. Order Line", ParentLineNo);
        Entry.SetRange("Source Batch Name", BatchName);
        Entry.SetRange("Reservation Status", Entry."Reservation Status"::Reservation);
        Assert.IsFalse(Entry.IsEmpty(), 'A native source reservation exists.');
        if CaseName in ['production', 'component'] then begin
            // [WHEN] A destructive call omits a production key part.
            IncompleteRequest := CancelRequest.Clone().AsObject();
            IncompleteRequest.Remove('sourceProdOrderLine');
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", IncompleteRequest, Response);
            AssertStatus(Response, 'Error');
            Response.Get('code', Token);
            Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'A production parent key is mandatory.');
            Response.Get('parameter', Token);
            Assert.AreEqual('sourceProdOrderLine', Token.AsValue().AsText(), 'Missing production parent is identified.');
            Assert.AreEqual(1, Entry.Count(), 'Missing parent leaves the requested reservation intact.');
            IncompleteRequest := CancelRequest.Clone().AsObject();
            IncompleteRequest.Remove('sourceSubtype');
            Clear(Response);
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", IncompleteRequest, Response);
            AssertStatus(Response, 'Error');
            Response.Get('code', Token);
            Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'A production status is mandatory.');
            Response.Get('parameter', Token);
            Assert.AreEqual('sourceSubtype', Token.AsValue().AsText(), 'Missing production status is identified.');
            Assert.AreEqual(1, Entry.Count(), 'Missing status leaves the requested reservation intact.');
        end;
        Clear(Response);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", CancelRequest, Response);
        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Cancel is scoped to this exact native source pointer.');
        if OtherRequest.Contains('sourceType') then begin
            Clear(ReadResponse);
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", OtherRequest, ReadResponse);
            AssertStatus(ReadResponse, 'Success');
            ReadResponse.Get('entries', Token);
            Assert.AreEqual(1, Token.AsArray().Count(), 'The other batch or parent keeps its reservation.');
            Clear(ReadResponse);
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", OtherRequest, ReadResponse);
            AssertStatus(ReadResponse, 'Success');
        end;
    end;

    local procedure VerifySupplySelection(CaseName: Text)
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LedgerEntry: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        LotNo: Code[50];
        SerialNo: Code[50];
        PackageNo: Code[50];
        SupplyEntryNo: Integer;
        RequestedQuantity: Decimal;
    begin
        // [GIVEN] Independently posted stock, including an earlier nonmatching supply entry.
        DomainSetup.EnableReservations();
        CreateOpenSalesLine(Item, SalesHeader, SalesLine, 0, 5);
        RequestedQuantity := 2;
        LibraryInventory.CreateItemTrackingCode(ItemTrackingCode);
        case CaseName of
            'lot', 'conflict':
                begin
                    ItemTrackingCode."Lot Specific Tracking" := true;
                    LotNo := 'CHOSEN-LOT';
                end;
            'serial', 'serialOver':
                begin
                    ItemTrackingCode."SN Specific Tracking" := true;
                    SerialNo := 'CHOSEN-SERIAL';
                    RequestedQuantity := 1;
                end;
            'package':
                begin
                    ItemTrackingCode."Package Specific Tracking" := true;
                    PackageNo := 'CHOSEN-PACKAGE';
                end;
        end;
        ItemTrackingCode.Modify(true);
        Item.Validate("Item Tracking Code", ItemTrackingCode.Code);
        Item.Modify(true);
        if CaseName in ['lot', 'conflict'] then
            PostTrackedSupply(Item, SalesLine."Location Code", 'OTHER-LOT', '', '', 3)
        else
            if CaseName in ['serial', 'serialOver'] then
                PostTrackedSupply(Item, SalesLine."Location Code", '', 'OTHER-SERIAL', '', 1)
            else
                if CaseName = 'package' then
                    PostTrackedSupply(Item, SalesLine."Location Code", '', '', 'OTHER-PACKAGE', 3)
                else
                    PostTrackedSupply(Item, SalesLine."Location Code", '', '', '', 3);
        PostTrackedSupply(Item, SalesLine."Location Code", LotNo, SerialNo, PackageNo, RequestedQuantity);
        LedgerEntry.SetRange("Item No.", Item."No.");
        LedgerEntry.FindLast();
        SupplyEntryNo := LedgerEntry."Entry No.";
        if CaseName in ['insufficient', 'serialOver'] then
            RequestedQuantity += 1;
        if CaseName = 'conflict' then
            LotNo := 'OTHER-LOT';
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Request.Add('quantity', RequestedQuantity);
        if LotNo <> '' then
            Request.Add('lotNo', LotNo);
        if SerialNo <> '' then
            Request.Add('serialNo', SerialNo);
        if PackageNo <> '' then
            Request.Add('packageNo', PackageNo);
        if CaseName in ['selected', 'insufficient', 'conflict'] then
            Request.Add('itemLedgerEntryNo', SupplyEntryNo);

        // [WHEN] Create selects the tracking dimensions or the explicitly named supply entry.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);

        // [THEN] A refusal leaves no reservation, or both native sides name exactly the requested supply.
        Entry.SetRange("Source Type", Database::"Sales Line");
        Entry.SetRange("Source ID", SalesHeader."No.");
        Entry.SetRange("Reservation Status", Entry."Reservation Status"::Reservation);
        if CaseName in ['insufficient', 'conflict', 'serialOver'] then begin
            AssertStatus(Response, 'Error');
            Assert.IsTrue(Entry.IsEmpty(), 'Refused supply selection is atomic.');
            LedgerEntry.Get(SupplyEntryNo);
            LedgerEntry.CalcFields("Reserved Quantity");
            Assert.AreEqual(0, LedgerEntry."Reserved Quantity", 'Supply remains unreserved.');
            exit;
        end;
        AssertStatus(Response, 'Success');
        Response.Get('quantity', Token);
        Assert.AreEqual(RequestedQuantity, Token.AsValue().AsDecimal(), 'Requested quantity reserved.');
        Entry.FindFirst();
        Assert.AreEqual(LotNo, Entry."Lot No.", 'Demand lot.');
        Assert.AreEqual(SerialNo, Entry."Serial No.", 'Demand serial.');
        Assert.AreEqual(PackageNo, Entry."Package No.", 'Demand package.');
        Entry.Get(Entry."Entry No.", true);
        Assert.AreEqual(Database::"Item Ledger Entry", Entry."Source Type", 'Inventory supply.');
        Assert.AreEqual(SupplyEntryNo, Entry."Source Ref. No.", 'Only the chosen supply entry.');
    end;

    local procedure PostTrackedSupply(Item: Record Item; LocationCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50]; Quantity: Decimal)
    var
        JournalLine: Record "Item Journal Line";
        Entry: Record "Reservation Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryTracking: Codeunit "Library - Item Tracking";
    begin
        LibraryInventory.CreateItemJnlLine(JournalLine, JournalLine."Entry Type"::"Positive Adjmt.", WorkDate(), Item."No.", Quantity, LocationCode);
        if (LotNo <> '') or (SerialNo <> '') or (PackageNo <> '') then
            LibraryTracking.CreateItemJournalLineItemTracking(Entry, JournalLine, SerialNo, LotNo, PackageNo, Quantity);
        LibraryInventory.PostItemJournalLine(JournalLine."Journal Template Name", JournalLine."Journal Batch Name");
    end;

    local procedure CreateOpenSalesLine(var Item: Record Item; var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; OnHand: Decimal; LineQuantity: Decimal)
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        LibrarySales: Codeunit "Library - Sales";
    begin
        CreateTransferLine(Item, TransferHeader, TransferLine, OnHand, 1);
        Item.Get(Item."No.");
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", LineQuantity);
        SalesLine.Validate("Location Code", TransferLine."Transfer-from Code");
        SalesLine.Validate(Reserve, SalesLine.Reserve::Optional);
        SalesLine.Validate("Shipment Date", WorkDate());
        SalesLine.Modify(true);
    end;

    local procedure AddSalesLine(SalesHeader: Record "Sales Header"; TemplateLine: Record "Sales Line"; var SalesLine: Record "Sales Line"; LineQuantity: Decimal)
    var
        LibrarySales: Codeunit "Library - Sales";
    begin
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, TemplateLine."No.", LineQuantity);
        SalesLine.Validate("Location Code", TemplateLine."Location Code");
        SalesLine.Validate(Reserve, SalesLine.Reserve::Optional);
        SalesLine.Validate("Shipment Date", WorkDate());
        SalesLine.Modify(true);
    end;

    local procedure ReserveSalesLine(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"; Quantity: Decimal): Integer
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Request.Add('sourceType', Database::"Sales Line");
        Request.Add('sourceNo', SalesHeader."No.");
        Request.Add('sourceLineNo', SalesLine."Line No.");
        Request.Add('quantity', Quantity);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entryNo', Token);
        exit(Token.AsValue().AsInteger());
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
        Item.Get(Item."No.");
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
                    Item.Get(Item."No.");
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
