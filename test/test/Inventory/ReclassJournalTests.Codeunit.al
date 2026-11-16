namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 34: Reclassification Check validates lines natively; Post and Preview accept lineSystemIds and Post returns the item register.</summary>
codeunit 96964 "Reclass Journal Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    procedure Scenario_AC34_Check_ValidBatch_1033_IsReady()
    begin
        VerifyCheck(1033, false, false);
    end;

    [Test]
    procedure Scenario_AC34_Check_ValidBatch_1039_IsReady()
    begin
        VerifyCheck(1039, false, false);
    end;

    [Test]
    procedure Scenario_AC34_Check_BlockedItemLine_IsNotReady()
    begin
        VerifyCheck(1033, true, false);
    end;

    [Test]
    procedure Scenario_AC34_Check_SubsetSkipsInvalidLine()
    begin
        VerifyCheck(1033, true, true);
    end;

    [Test]
    procedure Scenario_AC34_Post_Subset_PostsOnlySelectedLine_1033()
    begin
        VerifyPost(1033);
    end;

    [Test]
    procedure Scenario_AC34_Post_Subset_PostsOnlySelectedLine_1039()
    begin
        VerifyPost(1039);
    end;

    [Test]
    procedure Scenario_AC34_Post_ForeignLineSystemId_IsRefused()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        OtherBatch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        Location: Record Location;
        Ids: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Entries: Record "Item Ledger Entry";
        BeforeEntries: Integer;
    begin
        // [GIVEN] A line that belongs to another batch.
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        CreateBatch(OtherBatch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        CreateLine(OtherLine, OtherBatch, Item, Location, 1);
        Ids.Add(Format(OtherLine.SystemId, 0, 4));
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('lineSystemIds', Ids);
        Request.Add('expectedCount', 1);
        BeforeEntries := Entries.Count();
        Commit();
        // [WHEN] Posting with the foreign SystemId.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        // [THEN] The request is refused and nothing is posted.
        Assert.IsTrue(Response.Get('code', Token), 'Refusal is coded.');
        Assert.AreEqual('InvalidParameter', Token.AsValue().AsText(), 'Foreign line id code.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Nothing is posted.');
    end;

    [Test]
    procedure Scenario_AC34_Post_ItemTemplate_IsRefusedAsPreconditionFailed()
    var
        Batch: Record "Item Journal Batch";
        JournalTemplate: Record "Item Journal Template";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        EnableDomain();
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, "Item Journal Template Type"::Item);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('expectedCount', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        Assert.IsTrue(Response.Get('code', Token), 'Refusal is coded.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Only Transfer templates post.');
    end;

    local procedure VerifyCheck(LanguageId: Integer; WithBlockedLine: Boolean; Subset: Boolean)
    var
        Item: Record Item;
        BlockedItem: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        BadLine: Record "Item Journal Line";
        Location: Record Location;
        Ids: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
        ResponseText: Text;
    begin
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        if WithBlockedLine then begin
            CreateStock(BlockedItem);
            CreateLine(BadLine, Batch, BlockedItem, Location, 1);
            BlockedItem.Find();
            BlockedItem.Blocked := true;
            BlockedItem.Modify();
        end;
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        if Subset then begin
            Ids.Add(Format(Line.SystemId, 0, 4));
            Request.Add('lineSystemIds', Ids);
        end;
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Check", Request, Response);
        GlobalLanguage(PreviousLanguage);
        Response.WriteTo(ResponseText);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Response.Get('validationResult', Token);
        if WithBlockedLine and not Subset then begin
            Assert.AreEqual('NotReady', Token.AsValue().AsText(), ResponseText);
            Response.Get('errorCount', Token);
            Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'The blocked item is reported.');
            Response.Get('lineCount', Token);
            Assert.AreEqual(2, Token.AsValue().AsInteger(), 'Both lines are checked.');
        end else begin
            Assert.AreEqual('Ready', Token.AsValue().AsText(), ResponseText);
            Response.Get('lineCount', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only the valid line is checked.');
            Response.Get('postedLineCount', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Compatibility count equals lineCount.');
        end;
    end;

    local procedure VerifyPost(LanguageId: Integer)
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        SecondLine: Record "Item Journal Line";
        Location: Record Location;
        Entries: Record "Item Ledger Entry";
        Register: Record "Item Register";
        Ids: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
        ResponseText: Text;
    begin
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 2);
        CreateLine(SecondLine, Batch, Item, Location, 1);
        Ids.Add(Format(Line.SystemId, 0, 4));
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('lineSystemIds', Ids);
        Request.Add('expectedCount', 1);
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        GlobalLanguage(PreviousLanguage);
        Response.WriteTo(ResponseText);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Response.Get('postedLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only the selected line is posted.');
        Response.Get('itemRegisterNo', Token);
        Assert.IsTrue(Register.Get(Token.AsValue().AsInteger()), 'The item register exists.');
        Response.Get('result', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One result per posted line.');
        Assert.IsTrue(Response.Contains('journalBatchName'), 'Earlier response key is kept.');
        Entries.SetRange("Item No.", Item."No.");
        Entries.SetRange("Entry Type", Entries."Entry Type"::Transfer);
        Assert.IsFalse(Entries.IsEmpty(), 'Item ledger entries of type Transfer are written.');
        Assert.IsFalse(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Posted line leaves the journal.');
        Assert.IsTrue(SecondLine.Get(SecondLine."Journal Template Name", SecondLine."Journal Batch Name", SecondLine."Line No."), 'Unselected line remains.');
    end;

    local procedure EnableDomain()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Reclassification := true;
        Setup.Modify(true);
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, "Item Journal Template Type"::Transfer);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;

    local procedure CreateLine(var Line: Record "Item Journal Line"; Batch: Record "Item Journal Batch"; Item: Record Item; Location: Record Location; Quantity: Decimal)
    begin
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", Quantity);
        Line.Validate("New Location Code", Location.Code);
        Line.Modify(true);
    end;

    local procedure CreateStock(var Item: Record Item)
    var
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
    begin
        Clear(Item);
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
    end;
}
