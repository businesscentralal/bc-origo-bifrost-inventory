namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Purchase.ReturnOrder.CreateFromPosted (#137): a return order from a receipt, a refusal above the
/// quantity left to reverse, a line that belongs to another vendor, and a partial credit memo from an invoice.
/// </summary>
codeunit 96980 "Purch. Return Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";

    [Test]
    procedure ReturnOrder_FromReceipt_AppliesFullQuantity()
    var
        Vendor: Record Vendor;
        PurchRcptLine: Record "Purch. Rcpt. Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Response: JsonObject;
        LineJson: JsonObject;
        Lines: JsonArray;
        DocumentNo: Code[20];
    begin
        // [SCENARIO] Issue137 AC01 | Time: none | Risk: owned purchase documents, removed before the test ends.
        // [GIVEN] A posted purchase receipt for quantity 4.
        PostReceipt(Vendor, PurchRcptLine, 4);
        Lines.Add(SourceLine('Receipt', PurchRcptLine."Document No.", PurchRcptLine."Line No.", 4));
        // [WHEN] The receipt line is copied onto a new return order.
        Response := CallCreate('ReturnOrder', '', Vendor."No.", Lines);
        // [THEN] The answer names the open return order and the line applies to the receipt entry.
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'status');
        Assert.AreEqual('ReturnOrder', ReadText(Response, 'documentType'), 'document type');
        DocumentNo := CopyStr(ReadText(Response, 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.AreNotEqual('', DocumentNo, 'document no.');
        Assert.AreEqual(Vendor."No.", ReadText(Response, 'vendorNo'), 'vendor');
        LineJson := LineAt(Response, 0);
        Assert.AreEqual(4, ReadDecimal(LineJson, 'quantity'), 'quantity');
        Assert.AreNotEqual(0, ReadInteger(LineJson, 'applToItemEntry'), 'appl.-to item entry');
        Assert.AreEqual('Receipt', ReadText(LineJson, 'sourceType'), 'source type');
        Assert.AreEqual(PurchRcptLine."Document No.", ReadText(LineJson, 'sourceDocumentNo'), 'source document');
        Assert.AreEqual(PurchRcptLine."Line No.", ReadInteger(LineJson, 'sourceLineNo'), 'source line');
        PurchaseHeader.Get(PurchaseHeader."Document Type"::"Return Order", DocumentNo);
        Assert.AreEqual(PurchaseHeader.Status::Open, PurchaseHeader.Status, 'the return order stays open');
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.FindFirst();
        Assert.AreEqual(4, PurchaseLine.Quantity, 'stored quantity');
        Assert.AreEqual(ReadInteger(LineJson, 'applToItemEntry'), PurchaseLine."Appl.-to Item Entry", 'stored application');
        ItemLedgerEntry.Get(PurchaseLine."Appl.-to Item Entry");
        Assert.AreEqual(PurchRcptLine."Document No.", ItemLedgerEntry."Document No.", 'application points at the receipt');
        PurchaseHeader.Delete(true);
    end;

    [Test]
    procedure QuantityAboveRemaining_ReturnsInvalidLine()
    var
        Vendor: Record Vendor;
        PurchRcptLine: Record "Purch. Rcpt. Line";
        Response: JsonObject;
        Lines: JsonArray;
        BeforeCount: Integer;
    begin
        // [SCENARIO] Issue137 AC02 | Time: none | Risk: the refusal writes nothing.
        // [GIVEN] A posted receipt for quantity 4.
        PostReceipt(Vendor, PurchRcptLine, 4);
        BeforeCount := CountReturnDocuments(Vendor."No.");
        Lines.Add(SourceLine('Receipt', PurchRcptLine."Document No.", PurchRcptLine."Line No.", 5));
        // [WHEN] The call asks for more than the quantity left to reverse.
        Response := CallCreate('ReturnOrder', '', Vendor."No.", Lines);
        // [THEN] InvalidLine is answered and no return document is created.
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'status');
        Assert.AreEqual('InvalidLine', ReadText(Response, 'code'), 'code');
        Assert.AreEqual('Send a quantity greater than zero and at most the quantity that is still left to reverse on that posted line.', ReadText(Response, 'nextStep'), 'nextStep');
        Assert.AreEqual(BeforeCount, CountReturnDocuments(Vendor."No."), 'no return document');
    end;

    [Test]
    procedure LineOfAnotherVendor_ReturnsInvalidLine()
    var
        VendorA: Record Vendor;
        VendorB: Record Vendor;
        PurchRcptLine: Record "Purch. Rcpt. Line";
        Response: JsonObject;
        Lines: JsonArray;
        BeforeCount: Integer;
    begin
        // [SCENARIO] Issue137 AC03 | Time: none | Risk: the refusal writes nothing.
        // [GIVEN] Vendor B has a posted receipt, and the call names vendor A.
        LibraryPurchase.CreateVendor(VendorA);
        PostReceipt(VendorB, PurchRcptLine, 4);
        BeforeCount := CountReturnDocuments(VendorA."No.") + CountReturnDocuments(VendorB."No.");
        Lines.Add(SourceLine('Receipt', PurchRcptLine."Document No.", PurchRcptLine."Line No.", 1));
        // [WHEN] The receipt line is sent as a return for the other vendor.
        Response := CallCreate('ReturnOrder', '', VendorA."No.", Lines);
        // [THEN] InvalidLine is answered and neither vendor gets a return document.
        Assert.AreEqual('Error', ReadText(Response, 'status'), 'status');
        Assert.AreEqual('InvalidLine', ReadText(Response, 'code'), 'code');
        Assert.AreEqual('Send a posted line that belongs to the same vendor as the return document.', ReadText(Response, 'nextStep'), 'nextStep');
        Assert.AreEqual(BeforeCount, CountReturnDocuments(VendorA."No.") + CountReturnDocuments(VendorB."No."), 'no return document');
    end;

    [Test]
    procedure CreditMemo_FromInvoice_KeepsPartialQuantityApplied()
    var
        Vendor: Record Vendor;
        PurchInvLine: Record "Purch. Inv. Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Response: JsonObject;
        LineJson: JsonObject;
        Lines: JsonArray;
        DocumentNo: Code[20];
    begin
        // [SCENARIO] Issue137 AC01 | Time: none | Risk: owned purchase documents, removed before the test ends.
        // [GIVEN] A posted purchase invoice for quantity 4 that applies to one item entry.
        PostInvoice(Vendor, PurchInvLine, 4);
        Lines.Add(SourceLine('Invoice', PurchInvLine."Document No.", PurchInvLine."Line No.", 1));
        // [WHEN] One of the four is copied onto a new credit memo.
        Response := CallCreate('CreditMemo', '', Vendor."No.", Lines);
        // [THEN] The credit memo line stores quantity 1 and still applies to the item entry.
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'status');
        Assert.AreEqual('CreditMemo', ReadText(Response, 'documentType'), 'document type');
        DocumentNo := CopyStr(ReadText(Response, 'documentNo'), 1, MaxStrLen(DocumentNo));
        LineJson := LineAt(Response, 0);
        Assert.AreEqual(1, ReadDecimal(LineJson, 'quantity'), 'quantity');
        Assert.AreNotEqual(0, ReadInteger(LineJson, 'applToItemEntry'), 'appl.-to item entry');
        Assert.AreEqual(PurchInvLine."Document No.", ReadText(LineJson, 'sourceDocumentNo'), 'source document');
        PurchaseHeader.Get(PurchaseHeader."Document Type"::"Credit Memo", DocumentNo);
        Assert.AreEqual(PurchaseHeader.Status::Open, PurchaseHeader.Status, 'the credit memo stays open');
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.FindFirst();
        Assert.AreEqual(1, PurchaseLine.Quantity, 'stored quantity');
        Assert.AreEqual(ReadInteger(LineJson, 'applToItemEntry'), PurchaseLine."Appl.-to Item Entry", 'stored application');
        PurchaseHeader.Delete(true);
    end;

    [Test]
    procedure TypeName_HasThreeParts()
    var
        TypeName: Text;
        Part: Text;
    begin
        // [SCENARIO] Issue137 AC05 | Time: none | Risk: metadata only.
        TypeName := Format("Message Type ori"::"Purchase.ReturnOrder.CreateFromPosted");
        Assert.AreEqual('Purchase.ReturnOrder.CreateFromPosted', TypeName, 'type name');
        Assert.AreEqual(3, TypeName.Split('.').Count(), 'three dot-separated parts');
        foreach Part in TypeName.Split('.') do
            Assert.AreNotEqual('', Part, 'no empty part');
    end;

    local procedure PostReceipt(var Vendor: Record Vendor; var PurchRcptLine: Record "Purch. Rcpt. Line"; Quantity: Decimal)
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ReceiptNo: Code[20];
    begin
        LibraryPurchase.CreateVendor(Vendor);
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", Quantity);
        PurchaseLine.Validate("Direct Unit Cost", 10);
        PurchaseLine.Modify(true);
        ReceiptNo := LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        PurchRcptLine.SetRange("Document No.", ReceiptNo);
        PurchRcptLine.SetRange(Type, PurchRcptLine.Type::Item);
        PurchRcptLine.FindFirst();
    end;

    local procedure PostInvoice(var Vendor: Record Vendor; var PurchInvLine: Record "Purch. Inv. Line"; Quantity: Decimal)
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        OrderNo: Code[20];
    begin
        LibraryPurchase.CreateVendor(Vendor);
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", Quantity);
        PurchaseLine.Validate("Direct Unit Cost", 10);
        PurchaseLine.Modify(true);
        OrderNo := PurchaseHeader."No.";
        PurchaseHeader.Validate("Vendor Invoice No.", OrderNo);
        PurchaseHeader.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, true);
        PurchInvLine.SetRange("Order No.", OrderNo);
        PurchInvLine.SetRange(Type, PurchInvLine.Type::Item);
        PurchInvLine.FindFirst();
    end;

    local procedure CallCreate(DocumentType: Text; DocumentNo: Code[20]; VendorNo: Code[20]; Lines: JsonArray) Response: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
        Request: JsonObject;
    begin
        EnablePurchaseReturns();
        Request.Add('documentType', DocumentType);
        if DocumentNo <> '' then
            Request.Add('documentNo', DocumentNo);
        if VendorNo <> '' then
            Request.Add('vendorNo', VendorNo);
        Request.Add('lines', Lines);
        Response := Library.ExecuteType("Message Type ori"::"Purchase.ReturnOrder.CreateFromPosted", '', Request, false);
    end;

    local procedure SourceLine(SourceType: Text; DocumentNo: Code[20]; LineNo: Integer; Quantity: Decimal) LineJson: JsonObject
    begin
        LineJson.Add('sourceType', SourceType);
        LineJson.Add('documentNo', DocumentNo);
        LineJson.Add('lineNo', LineNo);
        LineJson.Add('quantity', Quantity);
    end;

    local procedure EnablePurchaseReturns()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup."Purchase Returns" then
            exit;
        InventorySetup.Validate("Purchase Returns", true);
        InventorySetup.Modify(true);
    end;

    local procedure CountReturnDocuments(VendorNo: Code[20]): Integer
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchaseHeader.SetFilter("Document Type", '%1|%2', PurchaseHeader."Document Type"::"Return Order", PurchaseHeader."Document Type"::"Credit Memo");
        exit(PurchaseHeader.Count());
    end;

    local procedure LineAt(Response: JsonObject; Index: Integer) LineJson: JsonObject
    var
        LinesToken: JsonToken;
        LineToken: JsonToken;
    begin
        Assert.IsTrue(Response.Get('lines', LinesToken), 'lines');
        Assert.IsTrue(LinesToken.AsArray().Get(Index, LineToken), 'line');
        LineJson := LineToken.AsObject();
    end;

    local procedure ReadText(Source: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Source.Get(KeyName, Token), KeyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadInteger(Source: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Source.Get(KeyName, Token), KeyName);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadDecimal(Source: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Source.Get(KeyName, Token), KeyName);
        exit(Token.AsValue().AsDecimal());
    end;
}
