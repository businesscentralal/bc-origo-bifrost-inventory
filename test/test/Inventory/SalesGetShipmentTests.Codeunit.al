namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Sales.SalesInvoice.GetShipmentLines (inventory#132).
/// </summary>
codeunit 96981 "Sales Get Shipment Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    procedure ShipmentNos_AddsLinesOfBothShipments()
    var
        Customer: Record Customer;
        Invoice: Record "Sales Header";
        InvoiceLine: Record "Sales Line";
        ShipmentNos: JsonArray;
        ResponseJson: JsonObject;
        AddedLines: JsonArray;
        FirstShipment: Code[20];
        SecondShipment: Code[20];
    begin
        // [GIVEN] Two posted, not invoiced shipments of one customer and an empty sales invoice
        LibrarySales.CreateCustomer(Customer);
        FirstShipment := ShipOrder(Customer."No.", 2);
        SecondShipment := ShipOrder(Customer."No.", 3);
        CreateInvoice(Invoice, Customer."No.");
        ShipmentNos.Add(FirstShipment);
        ShipmentNos.Add(SecondShipment);

        // [WHEN] The shipment lines of both shipments are pulled into the invoice
        ResponseJson := Execute(ShipmentRequest(Invoice."No.", ShipmentNos));

        // [THEN] Both item lines are on the invoice with their shipment link, and nothing is skipped
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(Invoice."No.", ReadText(ResponseJson, 'documentNo'), 'documentNo');
        AddedLines := ReadArray(ResponseJson, 'addedLines');
        Assert.AreEqual(ReadInteger(ResponseJson, 'addedCount'), AddedLines.Count(), 'addedCount matches addedLines');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'skippedCount'), 'skippedCount');
        InvoiceLine.SetRange("Document Type", Invoice."Document Type");
        InvoiceLine.SetRange("Document No.", Invoice."No.");
        InvoiceLine.SetRange(Type, InvoiceLine.Type::Item);
        Assert.AreEqual(2, InvoiceLine.Count(), 'two item lines on the invoice');
        InvoiceLine.SetRange("Shipment No.", FirstShipment);
        InvoiceLine.FindFirst();
        Assert.AreEqual(2, InvoiceLine.Quantity, 'first shipment quantity');
        InvoiceLine.SetRange("Shipment No.", SecondShipment);
        InvoiceLine.FindFirst();
        Assert.AreEqual(3, InvoiceLine.Quantity, 'second shipment quantity');
        Assert.AreEqual(AddedLines.Count(), CountInvoiceLines(Invoice), 'every invoice line is reported as added');
    end;

    [Test]
    procedure AllShipments_TakesOnlyBillToCustomer()
    var
        Customer: Record Customer;
        OtherCustomer: Record Customer;
        Invoice: Record "Sales Header";
        InvoiceLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        OwnShipment: Code[20];
    begin
        // [GIVEN] A shipment of the invoice customer and a shipment of another customer
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateCustomer(OtherCustomer);
        OwnShipment := ShipOrder(Customer."No.", 4);
        ShipOrder(OtherCustomer."No.", 5);
        CreateInvoice(Invoice, Customer."No.");

        // [WHEN] allShipments is sent
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allShipments', true);
        ResponseJson := Execute(RequestJson);

        // [THEN] Only the shipment of the bill-to customer is pulled in
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        InvoiceLine.SetRange("Document Type", Invoice."Document Type");
        InvoiceLine.SetRange("Document No.", Invoice."No.");
        InvoiceLine.SetRange(Type, InvoiceLine.Type::Item);
        Assert.AreEqual(1, InvoiceLine.Count(), 'one item line');
        InvoiceLine.FindFirst();
        Assert.AreEqual(OwnShipment, InvoiceLine."Shipment No.", 'shipment of the own customer');
    end;

    [Test]
    procedure OtherBillToCustomer_ReturnsInvalidLineAndAddsNothing()
    var
        Customer: Record Customer;
        OtherCustomer: Record Customer;
        Invoice: Record "Sales Header";
        ShipmentNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A shipment of another customer
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateCustomer(OtherCustomer);
        ShipmentNos.Add(ShipOrder(Customer."No.", 1));
        ShipmentNos.Add(ShipOrder(OtherCustomer."No.", 1));
        CreateInvoice(Invoice, Customer."No.");

        // [WHEN] Both shipments are named
        ResponseJson := Execute(ShipmentRequest(Invoice."No.", ShipmentNos));

        // [THEN] The call is refused with InvalidLine and a next step, and the invoice stays empty
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    [Test]
    procedure InvoicedLine_IsSkippedAndListed()
    var
        Customer: Record Customer;
        Invoice: Record "Sales Header";
        ShipmentNos: JsonArray;
        ResponseJson: JsonObject;
        SkippedLine: JsonObject;
        ShipmentNo: Code[20];
    begin
        // [GIVEN] A shipment whose order is already invoiced
        LibrarySales.CreateCustomer(Customer);
        ShipmentNo := ShipAndInvoiceOrder(Customer."No.", 2);
        CreateInvoice(Invoice, Customer."No.");
        ShipmentNos.Add(ShipmentNo);

        // [WHEN] That shipment is named
        ResponseJson := Execute(ShipmentRequest(Invoice."No.", ShipmentNos));

        // [THEN] Nothing is added and the invoiced line is listed with reason invoiced
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'addedCount'), 'addedCount');
        Assert.AreEqual(1, ReadInteger(ResponseJson, 'skippedCount'), 'skippedCount');
        SkippedLine := RowAt(ReadArray(ResponseJson, 'skippedLines'), 0);
        Assert.AreEqual(ShipmentNo, ReadText(SkippedLine, 'shipmentNo'), 'skipped shipmentNo');
        Assert.AreEqual('invoiced', ReadText(SkippedLine, 'reason'), 'reason');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'invoice stays empty');
    end;

    [Test]
    procedure SecondCall_SkipsLinesAlreadyOnOpenInvoice()
    var
        Customer: Record Customer;
        Invoice: Record "Sales Header";
        ShipmentNos: JsonArray;
        ResponseJson: JsonObject;
        SkippedLine: JsonObject;
        LineCount: Integer;
    begin
        // [GIVEN] A shipment that is already pulled into the invoice
        LibrarySales.CreateCustomer(Customer);
        ShipmentNos.Add(ShipOrder(Customer."No.", 2));
        CreateInvoice(Invoice, Customer."No.");
        Execute(ShipmentRequest(Invoice."No.", ShipmentNos));
        LineCount := CountInvoiceLines(Invoice);

        // [WHEN] The same request is sent again
        ResponseJson := Execute(ShipmentRequest(Invoice."No.", ShipmentNos));

        // [THEN] Nothing more is added; the line is listed as onOpenInvoice with the invoice that holds it
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'addedCount'), 'addedCount');
        Assert.AreEqual(LineCount, CountInvoiceLines(Invoice), 'line count unchanged');
        SkippedLine := RowAt(ReadArray(ResponseJson, 'skippedLines'), 0);
        Assert.AreEqual('onOpenInvoice', ReadText(SkippedLine, 'reason'), 'reason');
        Assert.AreEqual(Invoice."No.", ReadText(SkippedLine, 'invoiceNo'), 'invoiceNo');
    end;

    [Test]
    procedure ReleasedInvoice_ReturnsPreconditionFailed()
    var
        Customer: Record Customer;
        Invoice: Record "Sales Header";
        ShipmentNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A released invoice
        LibrarySales.CreateCustomer(Customer);
        ShipmentNos.Add(ShipOrder(Customer."No.", 1));
        CreateInvoice(Invoice, Customer."No.");
        Invoice.Status := Invoice.Status::Released;
        Invoice.Modify(false);

        // [WHEN] Shipment lines are requested
        ResponseJson := Execute(ShipmentRequest(Invoice."No.", ShipmentNos));

        // [THEN] PreconditionFailed points to Sales.Document.Reopen
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Sales.Document.Reopen'), 'nextStep');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    [Test]
    procedure InvalidRequests_ReturnCodedRefusals()
    var
        Customer: Record Customer;
        Invoice: Record "Sales Header";
        RequestJson: JsonObject;
        ShipmentNos: JsonArray;
        EmptyNos: JsonArray;
        NumberNos: JsonArray;
    begin
        LibrarySales.CreateCustomer(Customer);
        CreateInvoice(Invoice, Customer."No.");
        ShipmentNos.Add('MISSING-SHPT');
        NumberNos.Add(42);

        // [THEN] No invoice identifier
        RequestJson.Add('allShipments', true);
        AssertRefusal(RequestJson, 'MissingParameter');
        // [THEN] No shipment source
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        AssertRefusal(RequestJson, 'MissingParameter');
        // [THEN] Both identifiers
        RequestJson.Add('systemId', Format(Invoice.SystemId, 0, 4));
        RequestJson.Add('allShipments', true);
        AssertRefusal(RequestJson, 'ConflictingIdentifiers');
        // [THEN] Both sources
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allShipments', true);
        RequestJson.Add('shipmentNos', ShipmentNos);
        AssertRefusal(RequestJson, 'ConflictingIdentifiers');
        // [THEN] Unknown key
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allShipments', true);
        RequestJson.Add('lineNo', 10000);
        AssertRefusal(RequestJson, 'UnknownParameter');
        // [THEN] allShipments false
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allShipments', false);
        AssertRefusal(RequestJson, 'InvalidParameter');
        // [THEN] Empty and non-text shipmentNos, and a systemId that is not a GUID
        AssertRefusal(ShipmentRequest(Invoice."No.", EmptyNos), 'InvalidParameterFormat');
        AssertRefusal(ShipmentRequest(Invoice."No.", NumberNos), 'InvalidParameterFormat');
        Clear(RequestJson);
        RequestJson.Add('systemId', 'not-a-guid');
        RequestJson.Add('allShipments', true);
        AssertRefusal(RequestJson, 'InvalidParameterFormat');
        // [THEN] Unknown invoice and unknown shipment
        AssertRefusal(ShipmentRequest('MISSING-INV', ShipmentNos), 'RecordNotFound');
        AssertRefusal(ShipmentRequest(Invoice."No.", ShipmentNos), 'RecordNotFound');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    [Test]
    procedure Help_IsBilingual()
    var
        MessageType: Enum "Message Type ori";
        Discovery: Interface "Msg Discovery ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Token: JsonToken;
        EnglishOverview: Text;
        IcelandicOverview: Text;
        EnglishSelection: Text;
        IcelandicSelection: Text;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] The registered type, named with three dot-separated parts
        MessageType := "Message Type ori"::"Sales.SalesInvoice.GetShipmentLines";
        Assert.AreEqual(3, Format(MessageType).Split('.').Count(), 'three-part name');
        Discovery := MessageType;
        Contract := MessageType;
        PreviousLanguage := GlobalLanguage();

        // [WHEN] Help is read in en-US and is-IS
        GlobalLanguage(1033);
        Contract.GetOverview(EnglishOverview);
        EnglishSelection := Discovery.GetSelectionDescription();
        GlobalLanguage(1039);
        Contract.GetOverview(IcelandicOverview);
        IcelandicSelection := Discovery.GetSelectionDescription();
        GlobalLanguage(PreviousLanguage);

        // [THEN] The texts differ by language and the effect is a non-posting write
        Assert.AreNotEqual(EnglishOverview, IcelandicOverview, 'overview is translated');
        Assert.AreNotEqual(EnglishSelection, IcelandicSelection, 'selection is translated');
        Assert.AreNotEqual(0, StrPos(IcelandicOverview, 'afhendingarlínur'), 'Icelandic overview');
        Contract.GetEffect(Effect);
        Effect.Get('effect', Token);
        Assert.AreEqual('write', Token.AsValue().AsText(), 'effect');
        Effect.Get('posts', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'posts');
    end;

    local procedure AssertRefusal(RequestJson: JsonObject; ExpectedCode: Text)
    var
        ResponseJson: JsonObject;
        RequestText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        ResponseJson := Execute(RequestJson);
        Assert.AreEqual(ExpectedCode, ReadText(ResponseJson, 'code'), 'code for ' + RequestText);
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep for ' + RequestText);
    end;

    local procedure ShipOrder(CustomerNo: Code[20]; Qty: Decimal): Code[20]
    var
        SalesHeader: Record "Sales Header";
    begin
        CreateOrder(SalesHeader, CustomerNo, Qty);
        exit(LibrarySales.PostSalesDocument(SalesHeader, true, false));
    end;

    local procedure ShipAndInvoiceOrder(CustomerNo: Code[20]; Qty: Decimal): Code[20]
    var
        SalesHeader: Record "Sales Header";
        SalesShptHeader: Record "Sales Shipment Header";
    begin
        CreateOrder(SalesHeader, CustomerNo, Qty);
        LibrarySales.PostSalesDocument(SalesHeader, true, true);
        SalesShptHeader.SetRange("Order No.", SalesHeader."No.");
        SalesShptHeader.FindFirst();
        exit(SalesShptHeader."No.");
    end;

    local procedure CreateOrder(var SalesHeader: Record "Sales Header"; CustomerNo: Code[20]; Qty: Decimal)
    var
        Item: Record Item;
        SalesLine: Record "Sales Line";
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate("Prevent Negative Inventory", Item."Prevent Negative Inventory"::No);
        Item.Modify(true);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, CustomerNo);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", Qty);
        SalesLine.Validate("Unit Price", 10);
        SalesLine.Modify(true);
    end;

    local procedure CreateInvoice(var SalesHeader: Record "Sales Header"; CustomerNo: Code[20])
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Invoice, CustomerNo);
    end;

    local procedure CountInvoiceLines(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        exit(SalesLine.Count());
    end;

    local procedure ShipmentRequest(InvoiceNo: Text; ShipmentNos: JsonArray) RequestJson: JsonObject
    begin
        RequestJson.Add('documentNo', InvoiceNo);
        RequestJson.Add('shipmentNos', ShipmentNos);
    end;

    local procedure Execute(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        // Exercise the write within the caller transaction; the process must honor Omit Commit.
        ResponseJson := Library.ExecuteType("Message Type ori"::"Sales.SalesInvoice.GetShipmentLines", '', RequestJson, true);
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadInteger(ResponseJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsInteger());
        exit(-1);
    end;

    local procedure ReadArray(ResponseJson: JsonObject; KeyName: Text): JsonArray
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsArray() then
            exit(Token.AsArray());
    end;

    local procedure RowAt(Rows: JsonArray; Index: Integer): JsonObject
    var
        Token: JsonToken;
    begin
        Rows.Get(Index, Token);
        exit(Token.AsObject());
    end;
}
