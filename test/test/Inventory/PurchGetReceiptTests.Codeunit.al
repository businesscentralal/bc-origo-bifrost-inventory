namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Purchase.PurchaseInvoice.GetReceiptLines (inventory#133).
/// </summary>
codeunit 96996 "Purch Get Receipt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";

    [Test]
    /// <summary>Implements ReceiptNos_AddsLinesOfBothReceipts for purchase receipt invoice lines.</summary>
    procedure Scenario_AC01_ReceiptNos_AddsLinesOfBothReceipts()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        InvoiceLine: Record "Purchase Line";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
        AddedLines: JsonArray;
        FirstReceipt: Code[20];
        SecondReceipt: Code[20];
    begin
        // Story #133, AC01 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] Two posted, not invoiced receipts of one vendor and an empty purchase invoice
        CreateVendor(Vendor);
        FirstReceipt := ReceiveOrder(Vendor."No.", 2);
        SecondReceipt := ReceiveOrder(Vendor."No.", 3);
        CreateInvoice(Invoice, Vendor."No.");
        ReceiptNos.Add(FirstReceipt);
        ReceiptNos.Add(SecondReceipt);

        // [WHEN] The receipt lines of both receipts are pulled into the invoice
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));

        // [THEN] Both item lines are on the invoice with their receipt link, and nothing is skipped
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(Invoice."No.", ReadText(ResponseJson, 'documentNo'), 'documentNo');
        AddedLines := ReadArray(ResponseJson, 'addedLines');
        Assert.AreEqual(ReadInteger(ResponseJson, 'addedCount'), AddedLines.Count(), 'addedCount matches addedLines');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'skippedCount'), 'skippedCount');
        InvoiceLine.SetRange("Document Type", Invoice."Document Type");
        InvoiceLine.SetRange("Document No.", Invoice."No.");
        InvoiceLine.SetRange(Type, InvoiceLine.Type::Item);
        Assert.AreEqual(2, InvoiceLine.Count(), 'two item lines on the invoice');
        InvoiceLine.SetRange("Receipt No.", FirstReceipt);
        InvoiceLine.FindFirst();
        Assert.AreEqual(2, InvoiceLine.Quantity, 'first receipt quantity');
        InvoiceLine.SetRange("Receipt No.", SecondReceipt);
        InvoiceLine.FindFirst();
        Assert.AreEqual(3, InvoiceLine.Quantity, 'second receipt quantity');
        Assert.AreEqual(AddedLines.Count(), CountInvoiceLines(Invoice), 'every invoice line is reported as added');
    end;

    [Test]
    /// <summary>Implements AllReceipts_TakesOnlyPayToVendor for purchase receipt invoice lines.</summary>
    procedure Scenario_AC01_AllReceipts_TakesOnlyPayToVendor()
    var
        Vendor: Record Vendor;
        OtherVendor: Record Vendor;
        Invoice: Record "Purchase Header";
        InvoiceLine: Record "Purchase Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        OwnReceipt: Code[20];
    begin
        // Story #133, AC01 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] A receipt of the invoice vendor and a receipt of another vendor
        CreateVendor(Vendor);
        CreateVendor(OtherVendor);
        OwnReceipt := ReceiveOrder(Vendor."No.", 4);
        ReceiveOrder(OtherVendor."No.", 5);
        CreateInvoice(Invoice, Vendor."No.");

        // [WHEN] allReceipts is sent
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allReceipts', true);
        ResponseJson := Execute(RequestJson);

        // [THEN] Only the receipt of the pay-to vendor is pulled in
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        InvoiceLine.SetRange("Document Type", Invoice."Document Type");
        InvoiceLine.SetRange("Document No.", Invoice."No.");
        InvoiceLine.SetRange(Type, InvoiceLine.Type::Item);
        Assert.AreEqual(1, InvoiceLine.Count(), 'one item line');
        InvoiceLine.FindFirst();
        Assert.AreEqual(OwnReceipt, InvoiceLine."Receipt No.", 'receipt of the own vendor');
    end;

    [Test]
    /// <summary>Implements OtherPayToVendor_ReturnsInvalidLineAndAddsNothing for purchase receipt invoice lines.</summary>
    procedure Scenario_AC02_OtherPayToVendor_ReturnsInvalidLineAndAddsNothing()
    var
        Vendor: Record Vendor;
        OtherVendor: Record Vendor;
        Invoice: Record "Purchase Header";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // Story #133, AC02 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] A receipt of another vendor
        CreateVendor(Vendor);
        CreateVendor(OtherVendor);
        ReceiptNos.Add(ReceiveOrder(Vendor."No.", 1));
        ReceiptNos.Add(ReceiveOrder(OtherVendor."No.", 1));
        CreateInvoice(Invoice, Vendor."No.");

        // [WHEN] Both receipts are named
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));

        // [THEN] The call is refused with InvalidLine and a next step, and the invoice stays empty
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    [Test]
    /// <summary>Implements InvoicedLine_IsSkippedAndListed for purchase receipt invoice lines.</summary>
    procedure Scenario_AC03_InvoicedLine_IsSkippedAndListed()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
        SkippedLine: JsonObject;
        ReceiptNo: Code[20];
    begin
        // Story #133, AC03 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] A receipt whose order is already invoiced
        CreateVendor(Vendor);
        ReceiptNo := ReceiveAndInvoiceOrder(Vendor."No.", 2);
        CreateInvoice(Invoice, Vendor."No.");
        ReceiptNos.Add(ReceiptNo);

        // [WHEN] That receipt is named
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));

        // [THEN] Nothing is added and the invoiced line is listed with reason invoiced
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'addedCount'), 'addedCount');
        Assert.AreEqual(1, ReadInteger(ResponseJson, 'skippedCount'), 'skippedCount');
        SkippedLine := RowAt(ReadArray(ResponseJson, 'skippedLines'), 0);
        Assert.AreEqual(ReceiptNo, ReadText(SkippedLine, 'receiptNo'), 'skipped receiptNo');
        Assert.AreEqual('invoiced', ReadText(SkippedLine, 'reason'), 'reason');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'invoice stays empty');
    end;

    [Test]
    /// <summary>Implements SecondCall_SkipsLinesAlreadyOnOpenInvoice for purchase receipt invoice lines.</summary>
    procedure Scenario_AC03_SecondCall_SkipsLinesAlreadyOnOpenInvoice()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
        SkippedLine: JsonObject;
        LineCount: Integer;
    begin
        // Story #133, AC03 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] A receipt that is already pulled into the invoice
        CreateVendor(Vendor);
        ReceiptNos.Add(ReceiveOrder(Vendor."No.", 2));
        CreateInvoice(Invoice, Vendor."No.");
        Execute(ReceiptRequest(Invoice."No.", ReceiptNos));
        LineCount := CountInvoiceLines(Invoice);

        // [WHEN] The same request is sent again
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));

        // [THEN] Nothing more is added; the line is listed as onOpenInvoice with the invoice that holds it
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'addedCount'), 'addedCount');
        Assert.AreEqual(LineCount, CountInvoiceLines(Invoice), 'line count unchanged');
        SkippedLine := RowAt(ReadArray(ResponseJson, 'skippedLines'), 0);
        Assert.AreEqual('onOpenInvoice', ReadText(SkippedLine, 'reason'), 'reason');
        Assert.AreEqual(Invoice."No.", ReadText(SkippedLine, 'invoiceNo'), 'invoiceNo');
    end;

    [Test]
    /// <summary>Implements ReleasedInvoice_ReturnsPreconditionFailed for purchase receipt invoice lines.</summary>
    procedure Scenario_AC04_ReleasedInvoice_ReturnsPreconditionFailed()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // Story #133, AC04 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] A released invoice
        CreateVendor(Vendor);
        ReceiptNos.Add(ReceiveOrder(Vendor."No.", 1));
        CreateInvoice(Invoice, Vendor."No.");
        Invoice.Status := Invoice.Status::Released;
        Invoice.Modify(false);

        // [WHEN] Receipt lines are requested
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));

        // [THEN] PreconditionFailed points to Purchase.Document.Reopen
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Purchase.Document.Reopen'), 'nextStep');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    [Test]
    /// <summary>Implements InvalidRequests_ReturnCodedRefusals for purchase receipt invoice lines.</summary>
    procedure Scenario_AC04_InvalidRequests_ReturnCodedRefusals()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        RequestJson: JsonObject;
        ReceiptNos: JsonArray;
        EmptyNos: JsonArray;
        NumberNos: JsonArray;
    begin
        // Story #133, AC04 | Time: WorkDate for posting fixtures | Risk: None
        CreateVendor(Vendor);
        CreateInvoice(Invoice, Vendor."No.");
        ReceiptNos.Add('MISSING-SHPT');
        NumberNos.Add(42);

        // [THEN] No invoice identifier
        RequestJson.Add('allReceipts', true);
        AssertRefusal(RequestJson, 'MissingParameter');
        // [THEN] No receipt source
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        AssertRefusal(RequestJson, 'MissingParameter');
        // [THEN] Both identifiers
        RequestJson.Add('systemId', Format(Invoice.SystemId, 0, 4));
        RequestJson.Add('allReceipts', true);
        AssertRefusal(RequestJson, 'ConflictingIdentifiers');
        // [THEN] Both sources
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allReceipts', true);
        RequestJson.Add('receiptNos', ReceiptNos);
        AssertRefusal(RequestJson, 'ConflictingIdentifiers');
        // [THEN] Unknown key
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allReceipts', true);
        RequestJson.Add('lineNo', 10000);
        AssertRefusal(RequestJson, 'UnknownParameter');
        // [THEN] allReceipts false
        Clear(RequestJson);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allReceipts', false);
        AssertRefusal(RequestJson, 'InvalidParameter');
        // [THEN] Empty and non-text receiptNos, and a systemId that is not a GUID
        AssertRefusal(ReceiptRequest(Invoice."No.", EmptyNos), 'InvalidParameterFormat');
        AssertRefusal(ReceiptRequest(Invoice."No.", NumberNos), 'InvalidParameterFormat');
        Clear(RequestJson);
        RequestJson.Add('systemId', 'not-a-guid');
        RequestJson.Add('allReceipts', true);
        AssertRefusal(RequestJson, 'InvalidParameterFormat');
        // [THEN] Unknown invoice and unknown receipt
        AssertRefusal(ReceiptRequest('MISSING-INV', ReceiptNos), 'RecordNotFound');
        AssertRefusal(ReceiptRequest(Invoice."No.", ReceiptNos), 'RecordNotFound');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    [Test]
    /// <summary>Implements Help_IsBilingual for purchase receipt invoice lines.</summary>
    procedure Scenario_AC05_Help_IsBilingual()
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
        // Story #133, AC05 | Time: WorkDate for posting fixtures | Risk: None
        // [GIVEN] The registered type, named with three dot-separated parts
        MessageType := "Message Type ori"::"Purchase.PurchaseInvoice.GetReceiptLines";
        Assert.AreEqual(3, MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger())).Split('.').Count(), 'three-part name');
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
        Assert.AreNotEqual(0, StrPos(IcelandicOverview, 'móttökulínur'), 'Icelandic overview');
        Contract.GetEffect(Effect);
        Effect.Get('effect', Token);
        Assert.AreEqual('write', Token.AsValue().AsText(), 'effect');
        Effect.Get('posts', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'posts');
    end;

    /// <summary>SystemId resolves the same invoice and repeated receipt identifiers are deduplicated.</summary>
    [Test]
    procedure Scenario_AC01_SystemIdAndDuplicateReceipt_AddsOnce()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        ReceiptNos: JsonArray;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ReceiptNo: Code[20];
    begin
        // Story #133, AC01 | Time: WorkDate posting | Risk: None
        CreateVendor(Vendor);
        ReceiptNo := ReceiveOrder(Vendor."No.", 2);
        CreateInvoice(Invoice, Vendor."No.");
        ReceiptNos.Add(ReceiptNo);
        ReceiptNos.Add(ReceiptNo);
        RequestJson.Add('systemId', Format(Invoice.SystemId, 0, 4));
        RequestJson.Add('receiptNos', ReceiptNos);
        ResponseJson := Execute(RequestJson);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'systemId resolves invoice');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'skippedCount'), 'duplicates do not create skipped rows');
        Assert.AreEqual(ReadInteger(ResponseJson, 'addedCount'), CountInvoiceLines(Invoice), 'each new line listed once');
        Assert.AreEqual(Invoice."No.", ReadText(ResponseJson, 'documentNo'), 'resolved invoice');
    end;

    /// <summary>Long identifiers must never be truncated into a different existing invoice.</summary>
    [Test]
    procedure Scenario_AC04_DocumentNumberBoundaries_RefusesTruncation()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        RequestJson: JsonObject;
        ReceiptNos: JsonArray;
    begin
        // Story #133, AC04 | Time: None | Risk: None
        CreateVendor(Vendor);
        Invoice.Init();
        Invoice."Document Type" := Invoice."Document Type"::Invoice;
        // Message execution can commit: each invocation needs its own full-length key.
        Invoice."No." := NewCode();
        Assert.AreEqual(20, StrLen(Invoice."No."), 'fixture exercises the exact document-number boundary');
        Invoice.Insert(true);
        Invoice.Validate("Buy-from Vendor No.", Vendor."No.");
        Invoice.Modify(true);
        RequestJson.Add('documentNo', Invoice."No.");
        RequestJson.Add('allReceipts', true);
        Assert.AreEqual('Success', ReadText(Execute(RequestJson), 'status'), '20 characters accepted');
        RequestJson.Replace('documentNo', Invoice."No." + 'X');
        AssertRefusal(RequestJson, 'InvalidParameterFormat');
        RequestJson.Replace('documentNo', '');
        AssertRefusal(RequestJson, 'InvalidParameterFormat');
        RequestJson.Replace('documentNo', Invoice."No.");
        RequestJson.Remove('allReceipts');
        ReceiptNos.Add('X12345678901234567890X');
        RequestJson.Add('receiptNos', ReceiptNos);
        AssertRefusal(RequestJson, 'InvalidParameterFormat');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'no writes on invalid identifiers');
        Invoice.Delete(true);
    end;

    /// <summary>The boundary scenario can repeat on the same company in English.</summary>
    [Test]
    procedure Scenario_AC04_BoundaryRerun_EN()
    begin
        // Story #263, AC04 | Time: None | Risk: None
        AssertBoundaryRerun(1033);
    end;

    /// <summary>The boundary scenario can repeat on the same company in Icelandic.</summary>
    [Test]
    procedure Scenario_AC04_BoundaryRerun_IS()
    begin
        // Story #263, AC04 | Time: None | Risk: None
        AssertBoundaryRerun(1039);
    end;

    local procedure AssertBoundaryRerun(LanguageId: Integer)
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Scenario_AC04_DocumentNumberBoundaries_RefusesTruncation();
        Scenario_AC04_DocumentNumberBoundaries_RefusesTruncation();
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Only the receipt quantity still uninvoiced is copied by the native engine.</summary>
    [Test]
    procedure Scenario_AC03_PartlyInvoicedReceipt_AddsRemainingQuantity()
    var
        Vendor: Record Vendor;
        OrderHeader: Record "Purchase Header";
        OrderLine: Record "Purchase Line";
        ReceiptHeader: Record "Purch. Rcpt. Header";
        Invoice: Record "Purchase Header";
        InvoiceLine: Record "Purchase Line";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // Story #133, AC03 | Time: WorkDate posting | Risk: None
        CreateVendor(Vendor);
        CreateOrder(OrderHeader, Vendor."No.", 5);
        OrderLine.SetRange("Document Type", OrderHeader."Document Type");
        OrderLine.SetRange("Document No.", OrderHeader."No.");
        OrderLine.FindFirst();
        OrderLine.Validate("Qty. to Invoice", 2);
        OrderLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(OrderHeader, true, true);
        ReceiptHeader.SetRange("Order No.", OrderHeader."No.");
        ReceiptHeader.FindFirst();
        ReceiptNos.Add(ReceiptHeader."No.");
        CreateInvoice(Invoice, Vendor."No.");
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'partial receipt accepted');
        InvoiceLine.SetRange("Document Type", Invoice."Document Type");
        InvoiceLine.SetRange("Document No.", Invoice."No.");
        InvoiceLine.SetRange(Type, InvoiceLine.Type::Item);
        InvoiceLine.FindFirst();
        Assert.AreEqual(3, InvoiceLine.Quantity, 'native remaining quantity, not original quantity');
        Assert.AreEqual(ReceiptHeader."No.", InvoiceLine."Receipt No.", 'receipt link retained');
    end;

    /// <summary>A currency mismatch is refused before any invoice line can be written.</summary>
    [Test]
    procedure Scenario_AC02_OtherCurrency_ReturnsInvalidLine()
    var
        Vendor: Record Vendor;
        Invoice: Record "Purchase Header";
        ReceiptNos: JsonArray;
        ResponseJson: JsonObject;
    begin
        // Story #133, AC02 | Time: WorkDate posting | Risk: None
        CreateVendor(Vendor);
        ReceiptNos.Add(ReceiveOrder(Vendor."No.", 1));
        CreateInvoice(Invoice, Vendor."No.");
        Invoice."Currency Code" := 'XCCY';
        Invoice.Modify(false);
        ResponseJson := Execute(ReceiptRequest(Invoice."No.", ReceiptNos));
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'different currency refused');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'actionable refusal');
        Assert.AreEqual(0, CountInvoiceLines(Invoice), 'nothing added');
    end;

    local procedure CreateVendor(var Vendor: Record Vendor)
    begin
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Rename(NewCode());
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
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

    local procedure ReceiveOrder(VendorNo: Code[20]; Qty: Decimal): Code[20]
    var
        PurchHeader: Record "Purchase Header";
    begin
        CreateOrder(PurchHeader, VendorNo, Qty);
        exit(LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false));
    end;

    local procedure ReceiveAndInvoiceOrder(VendorNo: Code[20]; Qty: Decimal): Code[20]
    var
        PurchHeader: Record "Purchase Header";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
    begin
        CreateOrder(PurchHeader, VendorNo, Qty);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);
        PurchRcptHeader.SetRange("Order No.", PurchHeader."No.");
        PurchRcptHeader.FindFirst();
        exit(PurchRcptHeader."No.");
    end;

    local procedure CreateOrder(var PurchHeader: Record "Purchase Header"; VendorNo: Code[20]; Qty: Decimal)
    var
        Item: Record Item;
        PurchLine: Record "Purchase Line";
    begin
        LibraryInventory.CreateItem(Item);
        Item.Rename(NewCode());
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, VendorNo);
        PurchHeader."Vendor Invoice No." := NewCode();
        PurchHeader.Modify(true);
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", Qty);
        PurchLine.Validate("Direct Unit Cost", 10);
        PurchLine.Modify(true);
    end;

    local procedure CreateInvoice(var PurchHeader: Record "Purchase Header"; VendorNo: Code[20])
    begin
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Invoice, VendorNo);
    end;

    local procedure CountInvoiceLines(PurchHeader: Record "Purchase Header"): Integer
    var
        PurchLine: Record "Purchase Line";
    begin
        PurchLine.SetRange("Document Type", PurchHeader."Document Type");
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        exit(PurchLine.Count());
    end;

    local procedure ReceiptRequest(InvoiceNo: Text; ReceiptNos: JsonArray) RequestJson: JsonObject
    begin
        RequestJson.Add('documentNo', InvoiceNo);
        RequestJson.Add('receiptNos', ReceiptNos);
    end;

    local procedure Execute(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        // Exercise the write within the caller transaction; the process must honor Omit Commit.
        ResponseJson := Library.ExecuteType("Message Type ori"::"Purchase.PurchaseInvoice.GetReceiptLines", '', RequestJson, true);
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
