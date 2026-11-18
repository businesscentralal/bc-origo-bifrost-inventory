namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Inventory.AgedInventory.Get: quantity and value per age bucket, paging, refusals and read-only behaviour.</summary>
codeunit 96981 "Aged Inventory Get Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        Library: Codeunit "Inventory Test Library ori";

    /// <summary>AC01, AC03: stock lands in the right bucket with quantity and value, and nothing is written.</summary>
    [Test]
    procedure AgedInventory_PostedStock_FillsBucketsAndWritesNothing()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        EndingDate: Date;
        EntriesBefore: Integer;
        Response: JsonObject;
        Row: JsonObject;
    begin
        EndingDate := WorkDate();
        CreateItem(Item, '');
        PostStock(Item."No.", EndingDate - 5, 10);
        PostStock(Item."No.", EndingDate - 45, 4);
        PostStock(Item."No.", EndingDate - 200, 2);
        Ledger.SetRange("Item No.", Item."No.");
        EntriesBefore := Ledger.Count();

        Response := Execute(Item."No.", EndingDate, 30, '', -1, -1);

        Library.AssertStatus(Response, 'Success');
        Library.AssertResponseContract("Message Type ori"::"Inventory.AgedInventory.Get", Response);
        Row := FirstItem(Response);
        AssertNumber(Row, 'totalQuantity', 16);
        AssertNumber(Row, 'totalValue', 192);
        AssertAge(Row, 1, 10, 120);
        AssertAge(Row, 2, 4, 48);
        AssertAge(Row, 3, 0, 0);
        AssertAge(Row, 4, 0, 0);
        AssertAge(Row, 5, 2, 24);
        Assert.AreEqual(EntriesBefore, Ledger.Count(), 'The read does not change item ledger entries.');
    end;

    /// <summary>AC02: skip and take page the items and totalNoOfLines counts every item with stock.</summary>
    [Test]
    procedure AgedInventory_TwoItems_PagesWithSkipAndTake()
    var
        Item: Record Item;
        OtherItem: Record Item;
        EmptyItem: Record Item;
        ItemCategory: Record "Item Category";
        Response: JsonObject;
        Token: JsonToken;
    begin
        LibraryInventory.CreateItemCategory(ItemCategory);
        CreateItem(Item, ItemCategory.Code);
        CreateItem(OtherItem, ItemCategory.Code);
        CreateItem(EmptyItem, ItemCategory.Code);
        PostStock(Item."No.", WorkDate() - 1, 1);
        PostStock(OtherItem."No.", WorkDate() - 1, 2);

        Response := Execute('', WorkDate(), 30, ItemCategory.Code, 0, 1);
        AssertNumber(Response, 'noOfLines', 1);
        AssertNumber(Response, 'totalNoOfLines', 2);
        Response.Get('items', Token);
        Token.AsArray().Get(0, Token);
        AssertText(Token.AsObject(), 'itemNo', Item."No.");

        Response := Execute('', WorkDate(), 30, ItemCategory.Code, 1, 1);
        AssertNumber(Response, 'noOfLines', 1);
        Response.Get('items', Token);
        Token.AsArray().Get(0, Token);
        AssertText(Token.AsObject(), 'itemNo', OtherItem."No.");
    end;

    /// <summary>Edge: entries posted after the ending date are not counted, and an item with only such entries is not listed.</summary>
    [Test]
    procedure AgedInventory_EntryAfterEndingDate_IsNotCounted()
    var
        Item: Record Item;
        Response: JsonObject;
        Row: JsonObject;
        Rows: JsonToken;
    begin
        CreateItem(Item, '');
        PostStock(Item."No.", WorkDate() - 10, 3);
        PostStock(Item."No.", WorkDate() + 10, 7);

        Response := Execute(Item."No.", WorkDate(), 30, '', -1, -1);
        Row := FirstItem(Response);
        AssertNumber(Row, 'totalQuantity', 3);

        Response := Execute(Item."No.", WorkDate() - 20, 30, '', -1, -1);
        Response.Get('items', Rows);
        Assert.AreEqual(0, Rows.AsArray().Count(), 'No stock was posted by the earlier ending date.');
    end;

    /// <summary>AC04: invalid input is refused with a Bifröst code and a next step.</summary>
    [Test]
    procedure AgedInventory_InvalidInput_IsRefusedWithNextStep()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateItem(Item, '');
        Response := Execute(Item."No.", WorkDate(), 0, '', -1, -1);
        AssertRefusal(Response, 'InvalidParameterFormat');

        Response := Execute(Item."No.", WorkDate(), 30, '', -1, 5000);
        AssertRefusal(Response, 'InvalidParameterFormat');

        Request.Add('itemNo', Item."No.");
        Request.Add('endingDate', 'not-a-date');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.AgedInventory.Get", '', Request, true);
        AssertRefusal(Response, 'InvalidParameterFormat');

        Response := Execute('NO-SUCH-ITEM-110', WorkDate(), 30, '', -1, -1);
        AssertRefusal(Response, 'RecordNotFound');
    end;

    /// <summary>AC05: the message type name has exactly three dot-separated parts.</summary>
    [Test]
    procedure AgedInventory_Name_HasThreeParts()
    var
        MessageType: Enum "Message Type ori";
    begin
        MessageType := "Message Type ori"::"Inventory.AgedInventory.Get";
        Assert.AreEqual(3, StrLen(Format(MessageType)) - StrLen(DelChr(Format(MessageType), '=', '.')) + 1, 'Three dot-separated parts.');
    end;

    local procedure Execute(ItemNo: Code[20]; EndingDate: Date; PeriodLength: Integer; CategoryFilter: Text; Skip: Integer; Take: Integer) Response: JsonObject
    var
        Request: JsonObject;
    begin
        if ItemNo <> '' then
            Request.Add('itemNo', ItemNo);
        Request.Add('endingDate', Format(EndingDate, 0, 9));
        Request.Add('periodLengthDays', PeriodLength);
        if CategoryFilter <> '' then
            Request.Add('itemCategoryFilter', CategoryFilter);
        if Skip >= 0 then
            Request.Add('skip', Skip);
        if Take >= 0 then
            Request.Add('take', Take);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.AgedInventory.Get", '', Request, true);
    end;

    local procedure CreateItem(var Item: Record Item; CategoryCode: Code[20])
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate("Costing Method", Item."Costing Method"::FIFO);
        if CategoryCode <> '' then
            Item.Validate("Item Category Code", CategoryCode);
        Item.Modify(true);
    end;

    local procedure PostStock(ItemNo: Code[20]; PostingDate: Date; Quantity: Decimal)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        GLSetup.Get();
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", ItemNo, Quantity);
        Line.Validate("Posting Date", PostingDate);
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
    end;

    local procedure FirstItem(Response: JsonObject) Row: JsonObject
    var
        Token: JsonToken;
    begin
        Library.AssertStatus(Response, 'Success');
        Response.Get('items', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'The response lists the item.');
        Token.AsArray().Get(0, Token);
        Row := Token.AsObject();
    end;

    local procedure AssertAge(Row: JsonObject; Bucket: Integer; Quantity: Decimal; Value: Decimal)
    var
        Token: JsonToken;
        Age: JsonObject;
    begin
        Row.Get('ages', Token);
        Token.AsArray().Get(Bucket - 1, Token);
        Age := Token.AsObject();
        AssertNumber(Age, 'bucket', Bucket);
        AssertNumber(Age, 'quantity', Quantity);
        AssertNumber(Age, 'value', Value);
    end;

    local procedure AssertRefusal(Response: JsonObject; Code: Text)
    begin
        AssertText(Response, 'code', Code);
        Assert.IsTrue(TextOf(Response, 'nextStep') <> '', 'The refusal carries a next step.');
    end;

    local procedure TextOf(Row: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Row.Get(Name, Token) then
            exit(Token.AsValue().AsText());
    end;

    local procedure AssertText(Row: JsonObject; Name: Text; Expected: Text)
    var
        Serialized: Text;
    begin
        Row.WriteTo(Serialized);
        Assert.AreEqual(Expected, TextOf(Row, Name), Name + ': ' + Serialized);
    end;

    local procedure AssertNumber(Row: JsonObject; Name: Text; Expected: Decimal)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Row.WriteTo(Serialized);
        Assert.IsTrue(Row.Get(Name, Token), Name + ': ' + Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), Name + ': ' + Serialized);
    end;
}
