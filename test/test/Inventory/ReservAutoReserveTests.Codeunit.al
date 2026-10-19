namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.Reservation.AutoReserve: happy path, edge cases, refusals and help.
/// </summary>
codeunit 96958 "Reserv. AutoReserve Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    procedure AutoReserve_SalesLineWithStock_ReservesFully()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryToken: JsonToken;
    begin
        // [GIVEN] An item with 5 in stock and a sales order line for 2.
        EnableReservations();
        CreateStockedItem(Item, Item.Reserve::Optional, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 2);
        // [WHEN] The line is auto-reserved.
        ResponseJson := CallAuto(LineRequest(SalesLine));
        // [THEN] All 2 are reserved from the item ledger entry, and the entry made is listed.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual(2, ReadDecimal(ResponseJson, 'reserved'), 'reserved');
        Assert.AreEqual(2, ReadDecimal(ResponseJson, 'reservedQuantity'), 'reservedQuantity');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'fullyReserved'), 'fullyReserved');
        Assert.AreEqual(Format(SalesLine.SystemId, 0, 4), ReadText(ResponseJson, 'systemId'), 'systemId');
        Entries := ReadArray(ResponseJson, 'entries');
        Assert.AreEqual(1, Entries.Count(), 'entries made');
        Entries.Get(0, EntryToken);
        Assert.AreEqual(Database::"Item Ledger Entry", ReadDecimal(EntryToken.AsObject(), 'supplyType'), 'supply is inventory');
        Assert.AreEqual(Item."No.", ReadText(EntryToken.AsObject(), 'itemNo'), 'itemNo');
        SalesLine.Find();
        SalesLine.CalcFields("Reserved Quantity");
        Assert.AreEqual(2, SalesLine."Reserved Quantity", 'line reserved quantity');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_BySystemIdWithQuantity_ReservesPart()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] An item with 5 in stock and a sales order line for 3.
        EnableReservations();
        CreateStockedItem(Item, Item.Reserve::Optional, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 3);
        // [WHEN] Only 1 is requested, by SystemId.
        RequestJson.Add('systemId', Format(SalesLine.SystemId, 0, 4));
        RequestJson.Add('quantity', 1);
        ResponseJson := CallAuto(RequestJson);
        // [THEN] 1 is reserved and the line is not fully reserved.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual(1, ReadDecimal(ResponseJson, 'reserved'), 'reserved');
        Assert.IsFalse(ReadBoolean(ResponseJson, 'fullyReserved'), 'fullyReserved');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_AlreadyFullyReserved_ReturnsZero()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A sales order line that is already fully reserved.
        EnableReservations();
        CreateStockedItem(Item, Item.Reserve::Optional, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 2);
        ResponseJson := CallAuto(LineRequest(SalesLine));
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        // [WHEN] It is auto-reserved again.
        ResponseJson := CallAuto(LineRequest(SalesLine));
        // [THEN] Success with reserved 0, fullyReserved true and no new entries.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual(0, ReadDecimal(ResponseJson, 'reserved'), 'reserved');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'fullyReserved'), 'fullyReserved');
        Assert.AreEqual(0, ReadArray(ResponseJson, 'entries').Count(), 'no new entries');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_ReserveNever_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] An item with Reserve = Never.
        EnableReservations();
        CreateStockedItem(Item, Item.Reserve::Never, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 1);
        // [WHEN] Its sales line is auto-reserved.
        ResponseJson := CallAuto(LineRequest(SalesLine));
        // [THEN] PreconditionFailed with the nextStep, and nothing is written.
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Change the item''s Reserve setting or reserve manually.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(0, CountReservations(Item."No."), 'nothing written');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_SalesQuoteLine_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A sales quote line, identified by SystemId.
        EnableReservations();
        CreateStockedItem(Item, Item.Reserve::Optional, 5);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Quote, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        RequestJson.Add('systemId', Format(SalesLine.SystemId, 0, 4));
        // [WHEN] It is auto-reserved.
        ResponseJson := CallAuto(RequestJson);
        // [THEN] PreconditionFailed: only sales order lines are reserved. Nothing is written.
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual(0, CountReservations(Item."No."), 'nothing written');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_PartialSupply_ReturnsLinesSkippedAndRollsBack()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ResponseJson: JsonObject;
    begin
        // [GIVEN] 1 in stock and a sales order line for 5.
        EnableReservations();
        CreateStockedItem(Item, Item.Reserve::Optional, 1);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 5);
        // [WHEN] The line is auto-reserved.
        ResponseJson := CallAuto(LineRequest(SalesLine));
        // [THEN] LinesSkipped with the nextStep, and the partial reservation of 1 is rolled back.
        Assert.AreEqual('LinesSkipped', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Read Inventory.Reservation.Get for what was reserved.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(0, CountReservations(Item."No."), 'partial reservation was rolled back');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_MissingLine_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Check the document and line no.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure AutoReserve_UnknownSystemId_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('systemId', Format(CreateGuid(), 0, 4));
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('systemId', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure AutoReserve_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('extra', 'no');
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure AutoReserve_MissingKeys_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Send documentType, documentNo and lineNo, or systemId.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure AutoReserve_MissingLineNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('lineNo', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure AutoReserve_BadLineNo_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 'nope');
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Send lineNo as an integer.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure AutoReserve_ZeroQuantity_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('quantity', 0);
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('quantity', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure AutoReserve_QuoteDocumentType_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentType', 'Quote');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('documentType', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure AutoReserve_SystemIdAndDocument_ReturnsConflictingIdentifiers()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('systemId', '00000000-0000-0000-0000-000000000001');
        RequestJson.Add('documentNo', 'MISSING112');
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('ConflictingIdentifiers', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Send systemId or the document keys, not both.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure AutoReserve_Help_CoversRefusalsInBothLanguages()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        AutoImpl: Codeunit "Reserv. AutoReserve Impl ori";
        Contract: JsonObject;
        ContractText: Text;
        EnglishNotes: Text;
        IcelandicNotes: Text;
        PreviousLanguage: Integer;
    begin
        // [WHEN] The help contract is read.
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Inventory.Reservation.AutoReserve", Contract), 'contract');
        Contract.WriteTo(ContractText);
        // [THEN] Every refusal code and the parameters are documented, and no AL object is named.
        Assert.IsTrue(ContractText.Contains('PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(ContractText.Contains('LinesSkipped'), 'LinesSkipped');
        Assert.IsTrue(ContractText.Contains('RecordNotFound'), 'RecordNotFound');
        Assert.IsTrue(ContractText.Contains('ConflictingIdentifiers'), 'ConflictingIdentifiers');
        Assert.IsTrue(ContractText.Contains('PermissionDenied'), 'PermissionDenied');
        Assert.IsTrue(ContractText.Contains('Read Inventory.Reservation.Get for what was reserved.'), 'LinesSkipped nextStep');
        Assert.IsTrue(Contract.Contains('examples'), 'examples');
        Assert.IsFalse(ContractText.Contains('Reservation Management'), 'no codeunit names');
        Assert.IsFalse(ContractText.Contains(' ori"'), 'no object names');
        // [THEN] The notes follow the language of the call.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Assert.IsTrue(AutoImpl.GetNotes(EnglishNotes), 'English notes');
        GlobalLanguage(1039);
        Assert.IsTrue(AutoImpl.GetNotes(IcelandicNotes), 'Icelandic notes');
        GlobalLanguage(PreviousLanguage);
        Assert.AreNotEqual(EnglishNotes, IcelandicNotes, 'notes follow LCID 1039');
    end;

    [Test]
    procedure ReservationEntry_RemainsWriteRestricted()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Reservation Entry", false), 'Reservation Entry stays behind the reservation write guard');
    end;

    local procedure EnableReservations()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup.Reservations then
            exit;
        InventorySetup.Validate(Reservations, true);
        InventorySetup.Modify(true);
    end;

    local procedure CreateStockedItem(var Item: Record Item; ReserveMethod: Enum "Reserve Method"; Qty: Decimal)
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate(Reserve, ReserveMethod);
        Item.Modify(true);
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::Item, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, "Item Ledger Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    local procedure CreateSalesLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; ItemNo: Code[20]; Qty: Decimal)
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Qty);
    end;

    local procedure LineRequest(SalesLine: Record "Sales Line") RequestJson: JsonObject
    begin
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");
    end;

    local procedure CallAuto(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.Reservation.AutoReserve", '', RequestJson, false);
    end;

    local procedure CountReservations(ItemNo: Code[20]): Integer
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        exit(ReservationEntry.Count());
    end;

    local procedure Cleanup(var SalesHeader: Record "Sales Header"; ItemNo: Code[20])
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.DeleteAll(true);
        if SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.") then
            SalesHeader.Delete(true);
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not ResponseJson.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadDecimal(ResponseJson: JsonObject; KeyName: Text): Decimal
    var
        Result: Decimal;
    begin
        if Evaluate(Result, ReadText(ResponseJson, KeyName), 9) then
            exit(Result);
        exit(0);
    end;

    local procedure ReadBoolean(ResponseJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not ResponseJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure ReadArray(ResponseJson: JsonObject; KeyName: Text): JsonArray
    var
        Token: JsonToken;
        Empty: JsonArray;
    begin
        if not ResponseJson.Get(KeyName, Token) then
            exit(Empty);
        if not Token.IsArray() then
            exit(Empty);
        exit(Token.AsArray());
    end;
}
