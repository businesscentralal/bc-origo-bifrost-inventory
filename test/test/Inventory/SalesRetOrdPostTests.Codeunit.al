namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Sales.ReturnOrder.CreateFromPosted (inventory#136).
/// </summary>
codeunit 96991 "Sales Ret. Ord. Post. Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    procedure NewReturnOrder_FromInvoiceLine_SetsApplFromItemEntry()
    var
        Customer: Record Customer;
        ReturnOrder: Record "Sales Header";
        ReturnLine: Record "Sales Line";
        InvoiceNo: Code[20];
        ResponseJson: JsonObject;
        AddedLines: JsonArray;
        AddedLine: JsonObject;
    begin
        // [GIVEN] A customer with a posted invoice for 5 pieces of an item
        LibrarySales.CreateCustomer(Customer);
        InvoiceNo := ShipAndInvoice(Customer."No.", 5);

        // [WHEN] A new return order is requested for 2 pieces of that invoice line
        ResponseJson := Execute(NewRequest('ReturnOrder', Customer."No.", 'Invoice', InvoiceNo, ItemLineNoOfInvoice(InvoiceNo), 2));

        // [THEN] The return order exists with one item line of 2 pieces that is applied from the original item entry
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual('ReturnOrder', ReadText(ResponseJson, 'documentType'), 'documentType');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'created'), 'created');
        ReturnOrder.Get(ReturnOrder."Document Type"::"Return Order", ReadText(ResponseJson, 'documentNo'));
        Assert.AreEqual(Customer."No.", ReturnOrder."Sell-to Customer No.", 'customer');
        ReturnLine.SetRange("Document Type", ReturnOrder."Document Type");
        ReturnLine.SetRange("Document No.", ReturnOrder."No.");
        ReturnLine.SetRange(Type, ReturnLine.Type::Item);
        ReturnLine.FindFirst();
        Assert.AreEqual(2, ReturnLine.Quantity, 'quantity');
        Assert.AreNotEqual(0, ReturnLine."Appl.-from Item Entry", 'Appl.-from Item Entry is set');
        AddedLines := ReadArray(ResponseJson, 'lines');
        Assert.AreEqual(ReadInteger(ResponseJson, 'addedCount'), AddedLines.Count(), 'addedCount matches lines');
        AddedLine := ItemLineOf(AddedLines);
        Assert.AreEqual(ReturnLine."Appl.-from Item Entry", ReadInteger(AddedLine, 'applFromItemEntryNo'), 'answer carries the applied entry');
    end;

    [Test]
    procedure ExistingCreditMemo_FromShipmentLine_AddsLines()
    var
        Customer: Record Customer;
        CreditMemo: Record "Sales Header";
        CreditLine: Record "Sales Line";
        ShipmentNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A shipped, not invoiced order and an empty open credit memo of the customer
        LibrarySales.CreateCustomer(Customer);
        ShipmentNo := ShipOnly(Customer."No.", 4);
        LibrarySales.CreateSalesHeader(CreditMemo, CreditMemo."Document Type"::"Credit Memo", Customer."No.");

        // [WHEN] One piece of the shipment line is reversed into that credit memo
        ResponseJson := Execute(ExistingRequest('CreditMemo', CreditMemo."No.", 'Shipment', ShipmentNo, ItemLineNoOfShipment(ShipmentNo), 1));

        // [THEN] The credit memo got the line, was not created by the call, and the item entry link is set
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.IsFalse(ReadBoolean(ResponseJson, 'created'), 'created');
        Assert.AreEqual(CreditMemo."No.", ReadText(ResponseJson, 'documentNo'), 'documentNo');
        CreditLine.SetRange("Document Type", CreditMemo."Document Type");
        CreditLine.SetRange("Document No.", CreditMemo."No.");
        CreditLine.SetRange(Type, CreditLine.Type::Item);
        CreditLine.FindFirst();
        Assert.AreEqual(1, CreditLine.Quantity, 'quantity');
        Assert.AreNotEqual(0, CreditLine."Appl.-from Item Entry", 'Appl.-from Item Entry is set');
    end;

    [Test]
    procedure QuantityAboveRemaining_ReturnsInvalidLineAndCreatesNothing()
    var
        Customer: Record Customer;
        InvoiceNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A posted invoice line of 3 pieces
        LibrarySales.CreateCustomer(Customer);
        InvoiceNo := ShipAndInvoice(Customer."No.", 3);

        // [WHEN] 4 pieces are requested
        ResponseJson := Execute(NewRequest('ReturnOrder', Customer."No.", 'Invoice', InvoiceNo, ItemLineNoOfInvoice(InvoiceNo), 4));

        // [THEN] The call is refused with InvalidLine and a next step, and no document was created
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(0, CountDocuments(Customer."No."), 'nothing created');
    end;

    [Test]
    procedure SameLineTwice_AddsUpAndIsRefusedAboveRemaining()
    var
        Customer: Record Customer;
        InvoiceNo: Code[20];
        LineNo: Integer;
        Request: JsonObject;
        Lines: JsonArray;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A posted invoice line of 3 pieces, requested as 2 + 2 in one request
        LibrarySales.CreateCustomer(Customer);
        InvoiceNo := ShipAndInvoice(Customer."No.", 3);
        LineNo := ItemLineNoOfInvoice(InvoiceNo);
        Lines.Add(LineJson('Invoice', InvoiceNo, LineNo, 2));
        Lines.Add(LineJson('Invoice', InvoiceNo, LineNo, 2));
        Request.Add('documentType', 'ReturnOrder');
        Request.Add('customerNo', Customer."No.");
        Request.Add('lines', Lines);

        // [WHEN] / [THEN] The sum 4 is above the 3 left to reverse
        ResponseJson := Execute(Request);
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual(0, CountDocuments(Customer."No."), 'nothing created');

        // [WHEN] Exactly the remaining 3 pieces are requested as 1 + 2
        Clear(Lines);
        Lines.Add(LineJson('Invoice', InvoiceNo, LineNo, 1));
        Lines.Add(LineJson('Invoice', InvoiceNo, LineNo, 2));
        Clear(Request);
        Request.Add('documentType', 'ReturnOrder');
        Request.Add('customerNo', Customer."No.");
        Request.Add('lines', Lines);
        ResponseJson := Execute(Request);

        // [THEN] The return order is created
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(1, CountDocuments(Customer."No."), 'one document');
    end;

    [Test]
    procedure LineOfOtherCustomer_ReturnsInvalidLine()
    var
        Customer: Record Customer;
        OtherCustomer: Record Customer;
        InvoiceNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A posted invoice of another customer
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateCustomer(OtherCustomer);
        InvoiceNo := ShipAndInvoice(OtherCustomer."No.", 2);

        // [WHEN] Its line is requested for a return order of the first customer
        ResponseJson := Execute(NewRequest('ReturnOrder', Customer."No.", 'Invoice', InvoiceNo, ItemLineNoOfInvoice(InvoiceNo), 1));

        // [THEN] The call is refused with InvalidLine and nothing is created
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(0, CountDocuments(Customer."No."), 'nothing created');
    end;

    [Test]
    procedure ReleasedReturnOrder_ReturnsPreconditionFailed()
    var
        Customer: Record Customer;
        ReturnOrder: Record "Sales Header";
        InvoiceNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A released return order and a posted invoice line
        LibrarySales.CreateCustomer(Customer);
        InvoiceNo := ShipAndInvoice(Customer."No.", 2);
        LibrarySales.CreateSalesHeader(ReturnOrder, ReturnOrder."Document Type"::"Return Order", Customer."No.");
        ReturnOrder.Status := ReturnOrder.Status::Released;
        ReturnOrder.Modify();

        // [WHEN] The line is requested for that document
        ResponseJson := Execute(ExistingRequest('ReturnOrder', ReturnOrder."No.", 'Invoice', InvoiceNo, ItemLineNoOfInvoice(InvoiceNo), 1));

        // [THEN] PreconditionFailed points to Sales.Document.Reopen
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Sales.Document.Reopen'), 'nextStep');
    end;

    [Test]
    procedure InvalidRequests_ReturnCodedRefusals()
    var
        Customer: Record Customer;
        ReturnOrder: Record "Sales Header";
        InvoiceNo: Code[20];
        LineNo: Integer;
        Request: JsonObject;
        Lines: JsonArray;
        BadLine: JsonObject;
    begin
        LibrarySales.CreateCustomer(Customer);
        InvoiceNo := ShipAndInvoice(Customer."No.", 2);
        LineNo := ItemLineNoOfInvoice(InvoiceNo);
        LibrarySales.CreateSalesHeader(ReturnOrder, ReturnOrder."Document Type"::"Return Order", Customer."No.");

        // [THEN] No documentType
        Request.Add('customerNo', Customer."No.");
        Request.Add('lines', OneLine('Invoice', InvoiceNo, LineNo, 1));
        AssertRefusal(Request, 'MissingParameter');
        // [THEN] Unknown documentType
        Clear(Request);
        Request.Add('documentType', 'Order');
        Request.Add('customerNo', Customer."No.");
        Request.Add('lines', OneLine('Invoice', InvoiceNo, LineNo, 1));
        AssertRefusal(Request, 'InvalidParameter');
        // [THEN] No lines
        Clear(Request);
        Request.Add('documentType', 'ReturnOrder');
        Request.Add('customerNo', Customer."No.");
        AssertRefusal(Request, 'MissingParameter');
        // [THEN] Empty lines
        Request.Add('lines', Lines);
        AssertRefusal(Request, 'InvalidParameterFormat');
        // [THEN] New document without customerNo
        Clear(Request);
        Request.Add('documentType', 'ReturnOrder');
        Request.Add('lines', OneLine('Invoice', InvoiceNo, LineNo, 1));
        AssertRefusal(Request, 'MissingParameter');
        // [THEN] Both identifiers
        Clear(Request);
        Request.Add('documentType', 'ReturnOrder');
        Request.Add('documentNo', ReturnOrder."No.");
        Request.Add('systemId', Format(ReturnOrder.SystemId, 0, 4));
        Request.Add('lines', OneLine('Invoice', InvoiceNo, LineNo, 1));
        AssertRefusal(Request, 'ConflictingIdentifiers');
        // [THEN] Unknown top-level key
        Clear(Request);
        Request.Add('documentType', 'ReturnOrder');
        Request.Add('customerNo', Customer."No.");
        Request.Add('invoiceNo', InvoiceNo);
        Request.Add('lines', OneLine('Invoice', InvoiceNo, LineNo, 1));
        AssertRefusal(Request, 'UnknownParameter');
        // [THEN] Unknown line key, missing line key, wrong line value types, unknown source
        AssertRefusal(NewRequestWithLine(Customer."No.", LineWith('Invoice', InvoiceNo, LineNo, 1, 'extra')), 'UnknownParameter');
        Clear(BadLine);
        BadLine.Add('source', 'Invoice');
        BadLine.Add('documentNo', InvoiceNo);
        BadLine.Add('quantity', 1);
        AssertRefusal(NewRequestWithLine(Customer."No.", BadLine), 'MissingParameter');
        Clear(BadLine);
        BadLine.Add('source', 'Invoice');
        BadLine.Add('documentNo', InvoiceNo);
        BadLine.Add('lineNo', LineNo);
        BadLine.Add('quantity', 'two');
        AssertRefusal(NewRequestWithLine(Customer."No.", BadLine), 'InvalidParameterFormat');
        Clear(BadLine);
        BadLine.Add('source', 'Invoice');
        BadLine.Add('documentNo', InvoiceNo);
        BadLine.Add('lineNo', LineNo);
        BadLine.Add('quantity', 0);
        AssertRefusal(NewRequestWithLine(Customer."No.", BadLine), 'InvalidParameterFormat');
        AssertRefusal(NewRequestWithLine(Customer."No.", LineJson('CreditMemo', InvoiceNo, LineNo, 1)), 'InvalidParameter');
        // [THEN] Unknown posted line, unknown existing document, unknown customer
        AssertRefusal(NewRequestWithLine(Customer."No.", LineJson('Invoice', InvoiceNo, 99999, 1)), 'RecordNotFound');
        AssertRefusal(ExistingRequest('ReturnOrder', 'MISSING-RO', 'Invoice', InvoiceNo, LineNo, 1), 'RecordNotFound');
        AssertRefusal(NewRequest('ReturnOrder', 'MISSING-CUST', 'Invoice', InvoiceNo, LineNo, 1), 'InvalidParameter');
        Assert.AreEqual(1, CountDocuments(Customer."No."), 'only the prepared return order exists');
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
        EnglishError: Text;
        IcelandicError: Text;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] The registered type, named with three dot-separated parts
        MessageType := "Message Type ori"::"Sales.ReturnOrder.CreateFromPosted";
        Assert.AreEqual(3, Format(MessageType).Split('.').Count(), 'three-part name');
        Discovery := MessageType;
        Contract := MessageType;
        PreviousLanguage := GlobalLanguage();

        // [WHEN] Help and one refusal are read in en-US and is-IS
        GlobalLanguage(1033);
        Contract.GetOverview(EnglishOverview);
        EnglishSelection := Discovery.GetSelectionDescription();
        EnglishError := ErrorHelpText();
        GlobalLanguage(1039);
        Contract.GetOverview(IcelandicOverview);
        IcelandicSelection := Discovery.GetSelectionDescription();
        IcelandicError := ErrorHelpText();
        GlobalLanguage(PreviousLanguage);

        // [THEN] The texts differ by language and the effect is a non-posting write
        Assert.AreNotEqual(EnglishOverview, IcelandicOverview, 'overview is translated');
        Assert.AreNotEqual(EnglishSelection, IcelandicSelection, 'selection is translated');
        Assert.AreNotEqual('', EnglishError, 'English error help');
        Assert.AreNotEqual(EnglishError, IcelandicError, 'error help is translated');
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

    /// <summary>The text of the first documented error (MissingParameter) in the current language.</summary>
    local procedure ErrorHelpText(): Text
    var
        Contract: Interface "Msg Contract ori";
        Errors: JsonArray;
        Token: JsonToken;
    begin
        Contract := "Message Type ori"::"Sales.ReturnOrder.CreateFromPosted";
        Contract.GetErrors(Errors);
        Errors.Get(0, Token);
        exit(ReadText(Token.AsObject(), 'fix'));
    end;

    local procedure ShipAndInvoice(CustomerNo: Code[20]; Qty: Decimal): Code[20]
    var
        SalesHeader: Record "Sales Header";
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        CreateOrder(SalesHeader, CustomerNo, Qty);
        LibrarySales.PostSalesDocument(SalesHeader, true, true);
        SalesInvHeader.SetRange("Order No.", SalesHeader."No.");
        SalesInvHeader.FindFirst();
        exit(SalesInvHeader."No.");
    end;

    local procedure ShipOnly(CustomerNo: Code[20]; Qty: Decimal): Code[20]
    var
        SalesHeader: Record "Sales Header";
    begin
        CreateOrder(SalesHeader, CustomerNo, Qty);
        exit(LibrarySales.PostSalesDocument(SalesHeader, true, false));
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

    local procedure ItemLineNoOfInvoice(InvoiceNo: Code[20]): Integer
    var
        SalesInvLine: Record "Sales Invoice Line";
    begin
        SalesInvLine.SetRange("Document No.", InvoiceNo);
        SalesInvLine.SetRange(Type, SalesInvLine.Type::Item);
        SalesInvLine.FindFirst();
        exit(SalesInvLine."Line No.");
    end;

    local procedure ItemLineNoOfShipment(ShipmentNo: Code[20]): Integer
    var
        SalesShptLine: Record "Sales Shipment Line";
    begin
        SalesShptLine.SetRange("Document No.", ShipmentNo);
        SalesShptLine.SetRange(Type, SalesShptLine.Type::Item);
        SalesShptLine.FindFirst();
        exit(SalesShptLine."Line No.");
    end;

    local procedure CountDocuments(CustomerNo: Code[20]): Integer
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.SetFilter("Document Type", '%1|%2', SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo");
        SalesHeader.SetRange("Sell-to Customer No.", CustomerNo);
        exit(SalesHeader.Count());
    end;

    local procedure LineJson(Source: Text; DocumentNo: Text; LineNo: Integer; Quantity: Decimal) Line: JsonObject
    begin
        Line.Add('source', Source);
        Line.Add('documentNo', DocumentNo);
        Line.Add('lineNo', LineNo);
        Line.Add('quantity', Quantity);
    end;

    local procedure LineWith(Source: Text; DocumentNo: Text; LineNo: Integer; Quantity: Decimal; ExtraKey: Text) Line: JsonObject
    begin
        Line := LineJson(Source, DocumentNo, LineNo, Quantity);
        Line.Add(ExtraKey, true);
    end;

    local procedure OneLine(Source: Text; DocumentNo: Text; LineNo: Integer; Quantity: Decimal) Lines: JsonArray
    begin
        Lines.Add(LineJson(Source, DocumentNo, LineNo, Quantity));
    end;

    local procedure NewRequest(DocumentType: Text; CustomerNo: Text; Source: Text; DocumentNo: Text; LineNo: Integer; Quantity: Decimal) RequestJson: JsonObject
    begin
        RequestJson.Add('documentType', DocumentType);
        RequestJson.Add('customerNo', CustomerNo);
        RequestJson.Add('lines', OneLine(Source, DocumentNo, LineNo, Quantity));
    end;

    local procedure NewRequestWithLine(CustomerNo: Text; Line: JsonObject) RequestJson: JsonObject
    var
        Lines: JsonArray;
    begin
        Lines.Add(Line);
        RequestJson.Add('documentType', 'ReturnOrder');
        RequestJson.Add('customerNo', CustomerNo);
        RequestJson.Add('lines', Lines);
    end;

    local procedure ExistingRequest(DocumentType: Text; TargetNo: Text; Source: Text; DocumentNo: Text; LineNo: Integer; Quantity: Decimal) RequestJson: JsonObject
    begin
        RequestJson.Add('documentType', DocumentType);
        RequestJson.Add('documentNo', TargetNo);
        RequestJson.Add('lines', OneLine(Source, DocumentNo, LineNo, Quantity));
    end;

    local procedure Execute(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        // Exercise the write within the caller transaction; the process must honor Omit Commit.
        ResponseJson := Library.ExecuteType("Message Type ori"::"Sales.ReturnOrder.CreateFromPosted", '', RequestJson, true);
    end;

    local procedure ItemLineOf(Lines: JsonArray): JsonObject
    var
        Token: JsonToken;
        Line: JsonObject;
        Index: Integer;
    begin
        for Index := 0 to Lines.Count() - 1 do begin
            Lines.Get(Index, Token);
            Line := Token.AsObject();
            if ReadText(Line, 'type') = 'Item' then
                exit(Line);
        end;
        Error('The answer has no item line.');
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadBoolean(ResponseJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
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
}
