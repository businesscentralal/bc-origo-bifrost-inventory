namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemCharge.Assign and Inventory.ItemCharge.Get.
/// </summary>
codeunit 96926 "Item Charge Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryRandom: Codeunit "Library - Random";

    [Test]
    procedure AssignEqually_SplitsAcrossItemLines()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ResponseJson: JsonObject;
        Rows: JsonArray;
        Qty: Decimal;
    begin
        ChargeLine := CreatePurchaseCharge(PurchHeader, 4);
        ResponseJson := AssignMethod(PurchHeader."No.", ChargeLine."Line No.", 'equally');
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'replacedCount'), 'first assign replaces nothing');
        Rows := ReadArray(ResponseJson, 'assignments');
        Assert.AreEqual(2, Rows.Count(), 'two item lines');
        Qty := ReadDecimal(RowAt(Rows, 0), 'qtyToAssign') + ReadDecimal(RowAt(Rows, 1), 'qtyToAssign');
        Assert.AreEqual(4, Qty, 'assigned quantity');
    end;

    [Test]
    procedure AssignAgain_ReportsReplacedRows()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ResponseJson: JsonObject;
    begin
        ChargeLine := CreatePurchaseCharge(PurchHeader, 2);
        AssignMethod(PurchHeader."No.", ChargeLine."Line No.", 'equally');
        ResponseJson := AssignMethod(PurchHeader."No.", ChargeLine."Line No.", 'equally');
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'replacedCount'), 'replaced rows');
        Assert.AreEqual(2, ReadArray(ResponseJson, 'assignments').Count(), 'rows after replace');
    end;

    [Test]
    procedure Get_ReturnsRowsAndUnassignedQuantity()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ResponseJson: JsonObject;
    begin
        ChargeLine := CreatePurchaseCharge(PurchHeader, 4);
        AssignMethod(PurchHeader."No.", ChargeLine."Line No.", 'equally');
        ResponseJson := CallGet(PurchHeader."No.", ChargeLine."Line No.");
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadDecimal(ResponseJson, 'unassignedQuantity'), 'unassigned');
        Assert.AreEqual(2, ReadArray(ResponseJson, 'assignments').Count(), 'rows');
    end;

    [Test]
    procedure NonChargeLine_ReturnsPreconditionFailed()
    var
        PurchHeader: Record "Purchase Header";
        ItemLine: Record "Purchase Line";
        ResponseJson: JsonObject;
    begin
        CreatePurchaseCharge(PurchHeader, 1);
        ItemLine.SetRange("Document Type", PurchHeader."Document Type");
        ItemLine.SetRange("Document No.", PurchHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        ItemLine.FindFirst();
        ResponseJson := AssignMethod(PurchHeader."No.", ItemLine."Line No.", 'equally');
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Pass the line no. of a Charge (Item) line.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure OtherVendorTarget_ReturnsInvalidLine()
    var
        PurchHeader: Record "Purchase Header";
        OtherHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        OtherItem: Record "Purchase Line";
        ResponseJson: JsonObject;
        Targets: JsonArray;
        Target: JsonObject;
    begin
        ChargeLine := CreatePurchaseCharge(PurchHeader, 1);
        CreatePurchaseCharge(OtherHeader, 1);
        OtherItem.SetRange("Document Type", OtherHeader."Document Type");
        OtherItem.SetRange("Document No.", OtherHeader."No.");
        OtherItem.SetRange(Type, OtherItem.Type::Item);
        OtherItem.FindFirst();
        Target.Add('appliesToDocType', 'order');
        Target.Add('documentNo', OtherHeader."No.");
        Target.Add('lineNo', OtherItem."Line No.");
        Target.Add('qtyToAssign', 1);
        Targets.Add(Target);
        ResponseJson := AssignTargets(PurchHeader."No.", ChargeLine."Line No.", Targets);
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Use lines from the same vendor/customer.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure ByWeightWithoutWeight_ReturnsInvalidParameter()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        Assignment: Record "Item Charge Assignment (Purch)";
        ResponseJson: JsonObject;
    begin
        ChargeLine := CreatePurchaseCharge(PurchHeader, 2);
        ResponseJson := AssignMethod(PurchHeader."No.", ChargeLine."Line No.", 'byWeight');
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Use equally or byAmount, or fill the item''s weight/volume.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assignment.SetRange("Document No.", PurchHeader."No.");
        Assignment.SetRange("Document Line No.", ChargeLine."Line No.");
        Assert.AreEqual(0, Assignment.Count(), 'nothing was written');
    end;

    [Test]
    procedure MissingDocumentType_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCharge();
        RequestJson.Add('documentNo', 'MISSING');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('method', 'equally');
        ResponseJson := ExecuteAssign(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCharge();
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', 'MISSING');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('method', 'equally');
        RequestJson.Add('warehouse', 'BLUE');
        ResponseJson := ExecuteAssign(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure MethodAndTargets_ReturnConflict()
    var
        RequestJson: JsonObject;
        Targets: JsonArray;
        ResponseJson: JsonObject;
    begin
        EnableItemCharge();
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', 'MISSING');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('method', 'equally');
        RequestJson.Add('targets', Targets);
        ResponseJson := ExecuteAssign(RequestJson);
        Assert.AreEqual('ConflictingIdentifiers', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure SalesAssignEqually_SplitsAcrossItemLines()
    var
        SalesHeader: Record "Sales Header";
        ChargeLine: Record "Sales Line";
        ResponseJson: JsonObject;
    begin
        ChargeLine := CreateSalesCharge(SalesHeader, 2);
        ResponseJson := AssignSalesMethod(SalesHeader."No.", ChargeLine."Line No.", 'equally');
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(2, ReadArray(ResponseJson, 'assignments').Count(), 'two sales lines');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_AssignmentTables()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Charge Assignment (Purch)", false), 'purch assignment');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Charge Assignment (Sales)", false), 'sales assignment');
        Assert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::Item, false), 'item stays writable');
    end;

    local procedure CreatePurchaseCharge(var PurchHeader: Record "Purchase Header"; ChargeQty: Decimal) ChargeLine: Record "Purchase Line"
    var
        Vendor: Record Vendor;
        Item: Record Item;
        ItemCharge: Record "Item Charge";
        ItemLine: Record "Purchase Line";
    begin
        EnableItemCharge();
        LibraryPurchase.CreateVendor(Vendor);
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemCharge(ItemCharge);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(ItemLine, PurchHeader, ItemLine.Type::Item, Item."No.", 2);
        ItemLine.Validate("Direct Unit Cost", 10);
        ItemLine.Modify(true);
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchaseLine(ItemLine, PurchHeader, ItemLine.Type::Item, Item."No.", 2);
        ItemLine.Validate("Direct Unit Cost", 20);
        ItemLine.Modify(true);
        LibraryPurchase.CreateItemChargePurchaseLine(ChargeLine, ItemCharge, PurchHeader, ChargeQty, LibraryRandom.RandDec(10, 2));
    end;

    local procedure CreateSalesCharge(var SalesHeader: Record "Sales Header"; ChargeQty: Decimal) ChargeLine: Record "Sales Line"
    var
        Customer: Record Customer;
        Item: Record Item;
        ItemCharge: Record "Item Charge";
        ItemLine: Record "Sales Line";
    begin
        EnableItemCharge();
        LibrarySales.CreateCustomer(Customer);
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemCharge(ItemCharge);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(ItemLine, SalesHeader, ItemLine.Type::Item, Item."No.", 1);
        ItemLine.Validate("Unit Price", 10);
        ItemLine.Modify(true);
        LibraryInventory.CreateItem(Item);
        LibrarySales.CreateSalesLine(ItemLine, SalesHeader, ItemLine.Type::Item, Item."No.", 1);
        ItemLine.Validate("Unit Price", 15);
        ItemLine.Modify(true);
        LibrarySales.CreateItemChargeSalesLine(ChargeLine, ItemCharge, SalesHeader, ChargeQty, 5);
    end;

    local procedure AssignMethod(DocumentNo: Code[20]; LineNo: Integer; Method: Text) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', DocumentNo);
        RequestJson.Add('lineNo', LineNo);
        RequestJson.Add('method', Method);
        ResponseJson := ExecuteAssign(RequestJson);
    end;

    local procedure AssignSalesMethod(DocumentNo: Code[20]; LineNo: Integer; Method: Text) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', 'sales');
        RequestJson.Add('documentNo', DocumentNo);
        RequestJson.Add('lineNo', LineNo);
        RequestJson.Add('method', Method);
        ResponseJson := ExecuteAssign(RequestJson);
    end;

    local procedure AssignTargets(DocumentNo: Code[20]; LineNo: Integer; Targets: JsonArray) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', DocumentNo);
        RequestJson.Add('lineNo', LineNo);
        RequestJson.Add('targets', Targets);
        ResponseJson := ExecuteAssign(RequestJson);
    end;

    local procedure CallGet(DocumentNo: Code[20]; LineNo: Integer) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', DocumentNo);
        RequestJson.Add('lineNo', LineNo);
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCharge.Get", DocumentNo, RequestJson, true);
    end;

    local procedure ExecuteAssign(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCharge.Assign", '', RequestJson, true);
    end;

    local procedure EnableItemCharge()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup."Item Charge" then
            exit;
        InventorySetup.Validate("Item Charge", true);
        InventorySetup.Modify(true);
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

    local procedure ReadDecimal(ResponseJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsDecimal());
        exit(0);
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
