namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemTracing.Get: the trace of a lot number through the item ledger in both directions,
/// read-only behaviour, refusals, the node cap and help.
/// </summary>
codeunit 96960 "Item Tracing Get Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryItemTracking: Codeunit "Library - Item Tracking";

    [Test]
    procedure ItemTracing_OriginToUsage_ReturnsTreeAndWritesNothing()
    var
        Item: Record Item;
        LedgerEntry: Record "Item Ledger Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Root: JsonObject;
        Child: JsonObject;
        EntriesBefore: Integer;
    begin
        // [GIVEN] A lot received with 5 and used with 2.
        EnableTracking();
        CreateLotItem(Item);
        PostLot(Item."No.", 'ITR-LOT-A', 5, "Item Ledger Entry Type"::"Positive Adjmt.");
        PostLot(Item."No.", 'ITR-LOT-A', -2, "Item Ledger Entry Type"::"Negative Adjmt.");
        EntriesBefore := LedgerEntry.Count();
        // [WHEN] The lot is traced from origin to usage.
        RequestJson.Add('lotNo', 'ITR-LOT-A');
        RequestJson.Add('itemNo', Item."No.");
        ResponseJson := CallTrace(RequestJson);
        // [THEN] The tree has the receipt at level 0 and the use below it, with quantity and entry type.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('originToUsage', ReadText(ResponseJson, 'direction'), 'direction');
        Assert.IsTrue(FindNode(ResponseJson, 'Positive Adjmt.', Root), 'receipt node');
        Assert.IsTrue(FindNode(ResponseJson, 'Negative Adjmt.', Child), 'use node');
        Assert.AreEqual(0, ReadInteger(Root, 'level'), 'root level');
        Assert.AreEqual(1, ReadInteger(Child, 'level'), 'child level');
        Assert.AreEqual(ReadInteger(Root, 'entryNo'), ReadInteger(Child, 'parentEntryNo'), 'parent link');
        Assert.AreEqual(5, ReadDecimal(Root, 'quantity'), 'receipt quantity');
        Assert.AreEqual(-2, ReadDecimal(Child, 'quantity'), 'use quantity');
        Assert.AreEqual('ITR-LOT-A', ReadText(Root, 'lotNo'), 'lotNo');
        Assert.AreEqual(Item."No.", ReadText(Root, 'itemNo'), 'itemNo');
        Assert.AreEqual(ReadInteger(ResponseJson, 'nodeCount'), ReadArray(ResponseJson, 'nodes').Count(), 'nodeCount');
        // [THEN] Nothing was written.
        Assert.AreEqual(EntriesBefore, LedgerEntry.Count(), 'read only');
    end;

    [Test]
    procedure ItemTracing_UsageToOrigin_ReturnsUseAndItsOrigin()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Node: JsonObject;
    begin
        // [GIVEN] A lot received with 4 and used with 1.
        EnableTracking();
        CreateLotItem(Item);
        PostLot(Item."No.", 'ITR-LOT-B', 4, "Item Ledger Entry Type"::"Positive Adjmt.");
        PostLot(Item."No.", 'ITR-LOT-B', -1, "Item Ledger Entry Type"::"Negative Adjmt.");
        // [WHEN] The lot is traced from usage to origin (any case).
        RequestJson.Add('lotNo', 'ITR-LOT-B');
        RequestJson.Add('direction', 'UsageToOrigin');
        ResponseJson := CallTrace(RequestJson);
        // [THEN] The use is a root and the origin is reached from it.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('usageToOrigin', ReadText(ResponseJson, 'direction'), 'direction');
        Assert.IsTrue(FindNode(ResponseJson, 'Negative Adjmt.', Node), 'use node');
        Assert.IsTrue(FindNode(ResponseJson, 'Positive Adjmt.', Node), 'origin node');
    end;

    [Test]
    procedure ItemTracing_NeitherLotNorSerial_RefusedAsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('direction', 'originToUsage');
        ResponseJson := CallTrace(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure ItemTracing_InvalidInput_RefusedWithNextStep()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [WHEN] The direction is unknown.
        RequestJson.Add('lotNo', 'X');
        RequestJson.Add('direction', 'sideways');
        ResponseJson := CallTrace(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'direction nextStep');
        // [WHEN] The lot carries filter characters.
        Clear(RequestJson);
        RequestJson.Add('lotNo', '*');
        ResponseJson := CallTrace(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'filter nextStep');
        // [WHEN] A key is not part of the type.
        Clear(RequestJson);
        RequestJson.Add('lotNo', 'X');
        RequestJson.Add('bogus', 1);
        ResponseJson := CallTrace(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        // [WHEN] A key is an object.
        Clear(RequestJson);
        RequestJson.Add('lotNo', ResponseJson);
        ResponseJson := CallTrace(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
    end;

    [Test]
    procedure ItemTracing_UnknownLot_RefusedAsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('lotNo', 'ITR-NO-SUCH-LOT');
        ResponseJson := CallTrace(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure ItemTracing_AboveNodeCap_RefusedAsLimitExceeded()
    var
        LedgerEntry: Record "Item Ledger Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        FirstEntryNo: Integer;
        Index: Integer;
    begin
        // [GIVEN] 1001 ledger entries that carry one lot (written directly; the test run rolls them back).
        EnableTracking();
        if LedgerEntry.FindLast() then
            FirstEntryNo := LedgerEntry."Entry No.";
        for Index := 1 to 1001 do begin
            Clear(LedgerEntry);
            LedgerEntry."Entry No." := FirstEntryNo + Index;
            LedgerEntry."Item No." := 'ITR-CAP';
            LedgerEntry."Lot No." := 'ITR-CAP-LOT';
            LedgerEntry."Entry Type" := LedgerEntry."Entry Type"::"Positive Adjmt.";
            LedgerEntry.Quantity := 1;
            LedgerEntry.Positive := true;
            LedgerEntry."Posting Date" := WorkDate();
            LedgerEntry.Insert();
        end;
        // [WHEN] The lot is traced.
        RequestJson.Add('lotNo', 'ITR-CAP-LOT');
        ResponseJson := CallTrace(RequestJson);
        // [THEN] The call is refused above the node cap.
        Assert.AreEqual('LimitExceeded', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure ItemTracing_Help_CoversRefusalsInBothLanguages()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TracingImpl: Codeunit "Item Tracing Get Impl ori";
        Contract: JsonObject;
        ContractText: Text;
        EnglishNotes: Text;
        IcelandicNotes: Text;
        PreviousLanguage: Integer;
    begin
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Inventory.ItemTracing.Get", Contract), 'contract');
        Contract.WriteTo(ContractText);
        Assert.IsTrue(ContractText.Contains('MissingParameter'), 'MissingParameter');
        Assert.IsTrue(ContractText.Contains('LimitExceeded'), 'LimitExceeded');
        Assert.IsTrue(ContractText.Contains('RecordNotFound'), 'RecordNotFound');
        Assert.IsTrue(ContractText.Contains('PermissionDenied'), 'PermissionDenied');
        Assert.IsTrue(Contract.Contains('examples'), 'examples');
        Assert.IsFalse(ContractText.Contains('Item Tracing Mgt'), 'no codeunit names');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Assert.IsTrue(TracingImpl.GetNotes(EnglishNotes), 'English notes');
        GlobalLanguage(1039);
        Assert.IsTrue(TracingImpl.GetNotes(IcelandicNotes), 'Icelandic notes');
        GlobalLanguage(PreviousLanguage);
        Assert.AreNotEqual(EnglishNotes, IcelandicNotes, 'notes follow LCID 1039');
    end;

    local procedure EnableTracking()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup."Item Tracking" then
            exit;
        InventorySetup.Validate("Item Tracking", true);
        InventorySetup.Modify(true);
    end;

    local procedure CreateLotItem(var Item: Record Item)
    begin
        LibraryItemTracking.CreateLotItem(Item);
    end;

    local procedure PostLot(ItemNo: Code[20]; LotNo: Code[50]; Qty: Decimal; EntryType: Enum "Item Ledger Entry Type")
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        ReservationEntry: Record "Reservation Entry";
    begin
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::Item, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, EntryType, ItemNo, Abs(Qty));
        LibraryItemTracking.CreateItemJournalLineItemTracking(ReservationEntry, ItemJournalLine, '', LotNo, Abs(Qty));
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    local procedure CallTrace(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemTracing.Get", '', RequestJson, false);
    end;

    local procedure FindNode(ResponseJson: JsonObject; EntryType: Text; var Found: JsonObject): Boolean
    var
        NodeToken: JsonToken;
    begin
        foreach NodeToken in ReadArray(ResponseJson, 'nodes') do
            if ReadText(NodeToken.AsObject(), 'entryType') = EntryType then begin
                Found := NodeToken.AsObject();
                exit(true);
            end;
        exit(false);
    end;

    local procedure ReadText(Json: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Json.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadDecimal(Json: JsonObject; KeyName: Text): Decimal
    var
        Result: Decimal;
    begin
        if Evaluate(Result, ReadText(Json, KeyName), 9) then
            exit(Result);
        exit(0);
    end;

    local procedure ReadInteger(Json: JsonObject; KeyName: Text): Integer
    begin
        exit(Round(ReadDecimal(Json, KeyName), 1));
    end;

    local procedure ReadArray(Json: JsonObject; KeyName: Text): JsonArray
    var
        Token: JsonToken;
        Empty: JsonArray;
    begin
        if not Json.Get(KeyName, Token) then
            exit(Empty);
        if not Token.IsArray() then
            exit(Empty);
        exit(Token.AsArray());
    end;
}
