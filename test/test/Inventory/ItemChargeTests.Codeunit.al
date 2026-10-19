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
codeunit 96954 "Item Charge Tests"
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
        Amount: Decimal;
    begin
        // [GIVEN] A purchase order with two item lines and a charge line of quantity 4
        ChargeLine := CreatePurchaseCharge(PurchHeader, 4);

        // [WHEN] The charge is assigned equally
        ResponseJson := AssignMethod('purchase', PurchHeader."No.", ChargeLine."Line No.", 'equally');

        // [THEN] Both item lines get half the quantity and the amounts add up to the charge line amount
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'replacedCount'), 'first assign replaces nothing');
        Rows := ReadArray(ResponseJson, 'assignments');
        Assert.AreEqual(2, Rows.Count(), 'two item lines');
        Qty := ReadDecimal(RowAt(Rows, 0), 'qtyToAssign') + ReadDecimal(RowAt(Rows, 1), 'qtyToAssign');
        Amount := ReadDecimal(RowAt(Rows, 0), 'amountToAssign') + ReadDecimal(RowAt(Rows, 1), 'amountToAssign');
        Assert.AreEqual(4, Qty, 'assigned quantity');
        Assert.AreNearlyEqual(ChargeLine."Line Amount", Amount, 0.05, 'assigned amount');
        Assert.AreEqual('order', ReadText(RowAt(Rows, 0), 'appliesToDocType'), 'appliesToDocType');
    end;

    [Test]
    procedure AssignByAmount_FollowsLineAmounts()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ResponseJson: JsonObject;
        Rows: JsonArray;
    begin
        // [GIVEN] Item lines worth 20 and 40 and a charge of quantity 3
        ChargeLine := CreatePurchaseCharge(PurchHeader, 3);

        // [WHEN] The charge is assigned by amount
        ResponseJson := AssignMethod('purchase', PurchHeader."No.", ChargeLine."Line No.", 'byAmount');

        // [THEN] The bigger line gets twice the quantity of the smaller one
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Rows := ReadArray(ResponseJson, 'assignments');
        Assert.AreEqual(2, Rows.Count(), 'rows');
        Assert.AreEqual(1, ReadDecimal(RowAt(Rows, 0), 'qtyToAssign'), 'first line');
        Assert.AreEqual(2, ReadDecimal(RowAt(Rows, 1), 'qtyToAssign'), 'second line');
    end;

    [Test]
    procedure AssignTargets_WritesOnlyNamedLines()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ItemLine: Record "Purchase Line";
        ResponseJson: JsonObject;
        Targets: JsonArray;
        Rows: JsonArray;
    begin
        // [GIVEN] A charge line and one of the two item lines as explicit target
        ChargeLine := CreatePurchaseCharge(PurchHeader, 2);
        FindFirstPurchaseItemLine(PurchHeader, ItemLine);
        Targets.Add(TargetJson('order', PurchHeader."No.", ItemLine."Line No.", 2));

        // [WHEN] The charge is assigned to that target
        ResponseJson := AssignTargets(PurchHeader."No.", ChargeLine."Line No.", Targets);

        // [THEN] One row carries the whole quantity
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Rows := ReadArray(ResponseJson, 'assignments');
        Assert.AreEqual(1, Rows.Count(), 'one row');
        Assert.AreEqual(ItemLine."Line No.", ReadInteger(RowAt(Rows, 0), 'appliesToDocLineNo'), 'target line');
        Assert.AreEqual(2, ReadDecimal(RowAt(Rows, 0), 'qtyToAssign'), 'qtyToAssign');
        Assert.AreNotEqual(0, ReadDecimal(RowAt(Rows, 0), 'amountToAssign'), 'amountToAssign');
    end;

    [Test]
    procedure AssignAgain_ReportsReplacedRows()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ItemLine: Record "Purchase Line";
        Assignment: Record "Item Charge Assignment (Purch)";
        ResponseJson: JsonObject;
        Targets: JsonArray;
    begin
        // [GIVEN] A charge already assigned equally over two item lines
        ChargeLine := CreatePurchaseCharge(PurchHeader, 2);
        AssignMethod('purchase', PurchHeader."No.", ChargeLine."Line No.", 'equally');

        // [WHEN] The charge is assigned again to one explicit target
        FindFirstPurchaseItemLine(PurchHeader, ItemLine);
        Targets.Add(TargetJson('order', PurchHeader."No.", ItemLine."Line No.", 2));
        ResponseJson := AssignTargets(PurchHeader."No.", ChargeLine."Line No.", Targets);

        // [THEN] The two earlier rows are replaced by one
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'replacedCount'), 'replaced rows');
        Assert.AreEqual(1, ReadArray(ResponseJson, 'assignments').Count(), 'rows after replace');
        Assignment.SetRange("Document Type", PurchHeader."Document Type");
        Assignment.SetRange("Document No.", PurchHeader."No.");
        Assignment.SetRange("Document Line No.", ChargeLine."Line No.");
        Assert.AreEqual(1, Assignment.Count(), 'stored rows');
    end;

    [Test]
    procedure SalesAssignEqually_SplitsAcrossItemLines()
    var
        SalesHeader: Record "Sales Header";
        ChargeLine: Record "Sales Line";
        ResponseJson: JsonObject;
        Rows: JsonArray;
    begin
        // [GIVEN] A sales order with two item lines and a charge line of quantity 2
        ChargeLine := CreateSalesCharge(SalesHeader, 2);

        // [WHEN] The charge is assigned equally
        ResponseJson := AssignMethod('sales', SalesHeader."No.", ChargeLine."Line No.", 'equally');

        // [THEN] Each item line gets one
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Rows := ReadArray(ResponseJson, 'assignments');
        Assert.AreEqual(2, Rows.Count(), 'two sales lines');
        Assert.AreEqual(1, ReadDecimal(RowAt(Rows, 0), 'qtyToAssign'), 'first line');
    end;

    [Test]
    procedure Get_ReturnsRowsAndUnassignedQuantity()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A charge assigned equally
        ChargeLine := CreatePurchaseCharge(PurchHeader, 4);
        AssignMethod('purchase', PurchHeader."No.", ChargeLine."Line No.", 'equally');

        // [WHEN] The assignment is read by systemId
        ResponseJson := CallGetBySystemId('purchase', PurchHeader.SystemId, ChargeLine."Line No.");

        // [THEN] Both rows are returned and nothing is left unassigned
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(0, ReadDecimal(ResponseJson, 'unassignedQuantity'), 'unassigned');
        Assert.AreEqual(4, ReadDecimal(ResponseJson, 'qtyToAssign'), 'qtyToAssign');
        Assert.AreEqual(2, ReadArray(ResponseJson, 'assignments').Count(), 'rows');
    end;

    [Test]
    procedure Get_BeforeAssign_ReturnsWholeQuantityUnassigned()
    var
        SalesHeader: Record "Sales Header";
        ChargeLine: Record "Sales Line";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A sales charge line that was never assigned
        ChargeLine := CreateSalesCharge(SalesHeader, 3);

        // [WHEN] The assignment is read
        ResponseJson := CallGet('sales', SalesHeader."No.", ChargeLine."Line No.");

        // [THEN] No rows and the whole quantity is unassigned
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(3, ReadDecimal(ResponseJson, 'unassignedQuantity'), 'unassigned');
        Assert.AreEqual(0, ReadArray(ResponseJson, 'assignments').Count(), 'rows');
    end;

    [Test]
    procedure Get_NonChargeLine_ReturnsPreconditionFailed()
    var
        PurchHeader: Record "Purchase Header";
        ItemLine: Record "Purchase Line";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] An item line instead of a charge line
        CreatePurchaseCharge(PurchHeader, 1);
        FindFirstPurchaseItemLine(PurchHeader, ItemLine);

        // [WHEN] The item line is read
        ResponseJson := CallGet('purchase', PurchHeader."No.", ItemLine."Line No.");

        // [THEN] PreconditionFailed
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Pass the line no. of a Charge (Item) line.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Get_UnknownDocument_ReturnsRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A document number that does not exist
        EnableItemCharge();

        // [WHEN] The assignment is read
        ResponseJson := CallGet('purchase', 'NOSUCHDOC-108', 10000);

        // [THEN] RecordNotFound with a next step
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure NonChargeLine_ReturnsPreconditionFailed()
    var
        PurchHeader: Record "Purchase Header";
        ItemLine: Record "Purchase Line";
        Assignment: Record "Item Charge Assignment (Purch)";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] An item line instead of a charge line
        CreatePurchaseCharge(PurchHeader, 1);
        FindFirstPurchaseItemLine(PurchHeader, ItemLine);

        // [WHEN] The item line is assigned
        ResponseJson := AssignMethod('purchase', PurchHeader."No.", ItemLine."Line No.", 'equally');

        // [THEN] PreconditionFailed and nothing is written
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Pass the line no. of a Charge (Item) line.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assignment.SetRange("Document Type", PurchHeader."Document Type");
        Assignment.SetRange("Document No.", PurchHeader."No.");
        Assert.IsTrue(Assignment.IsEmpty(), 'nothing was written');
    end;

    [Test]
    procedure OtherVendorTarget_ReturnsInvalidLine()
    var
        PurchHeader: Record "Purchase Header";
        OtherHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        OtherItem: Record "Purchase Line";
        Assignment: Record "Item Charge Assignment (Purch)";
        ResponseJson: JsonObject;
        Targets: JsonArray;
    begin
        // [GIVEN] A target line on an order of another vendor
        ChargeLine := CreatePurchaseCharge(PurchHeader, 1);
        CreatePurchaseCharge(OtherHeader, 1);
        FindFirstPurchaseItemLine(OtherHeader, OtherItem);
        Targets.Add(TargetJson('order', OtherHeader."No.", OtherItem."Line No.", 1));

        // [WHEN] The charge is assigned to it
        ResponseJson := AssignTargets(PurchHeader."No.", ChargeLine."Line No.", Targets);

        // [THEN] InvalidLine and nothing is written
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Use lines from the same vendor/customer.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assignment.SetRange("Document Type", PurchHeader."Document Type");
        Assignment.SetRange("Document No.", PurchHeader."No.");
        Assert.IsTrue(Assignment.IsEmpty(), 'nothing was written');
    end;

    [Test]
    procedure ChargeLineAsTarget_ReturnsInvalidLine()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        ResponseJson: JsonObject;
        Targets: JsonArray;
    begin
        // [GIVEN] The charge line itself as target, which is not an item line
        ChargeLine := CreatePurchaseCharge(PurchHeader, 1);
        Targets.Add(TargetJson('order', PurchHeader."No.", ChargeLine."Line No.", 1));

        // [WHEN] The charge is assigned to it
        ResponseJson := AssignTargets(PurchHeader."No.", ChargeLine."Line No.", Targets);

        // [THEN] InvalidLine
        Assert.AreEqual('InvalidLine', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure ByWeightWithoutWeight_ReturnsInvalidParameter()
    var
        PurchHeader: Record "Purchase Header";
        ChargeLine: Record "Purchase Line";
        Assignment: Record "Item Charge Assignment (Purch)";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] Item lines without gross weight
        ChargeLine := CreatePurchaseCharge(PurchHeader, 2);

        // [WHEN] The charge is assigned by weight
        ResponseJson := AssignMethod('purchase', PurchHeader."No.", ChargeLine."Line No.", 'byWeight');

        // [THEN] InvalidParameter and nothing is written
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Use equally or byAmount, or fill the item''s weight/volume.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assignment.SetRange("Document Type", PurchHeader."Document Type");
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
        Assert.AreEqual('Send documentType.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure LineNoAsText_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCharge();
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', 'MISSING');
        RequestJson.Add('lineNo', '10000');
        RequestJson.Add('method', 'equally');
        ResponseJson := ExecuteAssign(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
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
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure UnknownDocument_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCharge();
        RequestJson.Add('documentType', 'sales');
        RequestJson.Add('documentNo', 'NOSUCHDOC-108');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('method', 'equally');
        ResponseJson := ExecuteAssign(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
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
        Assert.AreEqual('Send method or targets, not both.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure DocumentNoAndSystemId_ReturnConflict()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCharge();
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', 'MISSING');
        RequestJson.Add('systemId', Format(CreateGuid(), 0, 4));
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('method', 'equally');
        ResponseJson := ExecuteAssign(RequestJson);
        Assert.AreEqual('ConflictingIdentifiers', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send documentNo or systemId, not both.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_AssignmentTables()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [THEN] Generic writes are refused on both assignment tables and point to the dedicated types
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Charge Assignment (Purch)", false), 'purch assignment');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Charge Assignment (Sales)", false), 'sales assignment');
        Assert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::Item, false), 'item stays writable');
        Assert.AreNotEqual(0, StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Item Charge Assignment (Purch)"), 'Inventory.ItemCharge.Assign'), 'purch hint');
        Assert.AreNotEqual(0, StrPos(TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Item Charge Assignment (Sales)"), 'Inventory.ItemCharge.Assign'), 'sales hint');
        // [THEN] Reads stay allowed
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Item Charge Assignment (Purch)"), 'purch read');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Item Charge Assignment (Sales)"), 'sales read');
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

    local procedure FindFirstPurchaseItemLine(PurchHeader: Record "Purchase Header"; var ItemLine: Record "Purchase Line")
    begin
        ItemLine.SetRange("Document Type", PurchHeader."Document Type");
        ItemLine.SetRange("Document No.", PurchHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        ItemLine.FindFirst();
    end;

    local procedure TargetJson(AppliesTo: Text; DocumentNo: Code[20]; LineNo: Integer; Qty: Decimal) Target: JsonObject
    begin
        Target.Add('appliesToDocType', AppliesTo);
        Target.Add('documentNo', DocumentNo);
        Target.Add('lineNo', LineNo);
        Target.Add('qtyToAssign', Qty);
    end;

    local procedure AssignMethod(DocumentType: Text; DocumentNo: Code[20]; LineNo: Integer; Method: Text) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', DocumentType);
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

    local procedure CallGet(DocumentType: Text; DocumentNo: Code[20]; LineNo: Integer) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', DocumentType);
        RequestJson.Add('documentNo', DocumentNo);
        RequestJson.Add('lineNo', LineNo);
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCharge.Get", DocumentNo, RequestJson, true);
    end;

    local procedure CallGetBySystemId(DocumentType: Text; SystemId: Guid; LineNo: Integer) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', DocumentType);
        RequestJson.Add('systemId', Format(SystemId, 0, 4));
        RequestJson.Add('lineNo', LineNo);
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCharge.Get", '', RequestJson, true);
    end;

    local procedure ExecuteAssign(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        // The write runs in an isolated Codeunit.Run, which needs a committed transaction, so the dispatcher commits.
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCharge.Assign", '', RequestJson, false);
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
