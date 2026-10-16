namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Native tests for Inventory.PhysInventory.Calculate and Inventory.PhysInventory.Post.</summary>
codeunit 96922 "Phys Inventory Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        IsInitialized := true;
    end;

    [Test]
    procedure Calculate_MissingPostingDate_ReturnsError()
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ParameterToken: JsonToken;
    begin
        // [SCENARIO] Calculate without postingDate does not run Calculate Inventory.
        Initialize();
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::"Phys. Inventory");
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::"Phys. Inventory", ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        RequestJson.Add('journalTemplateName', ItemJournalTemplate.Name);
        RequestJson.Add('journalBatchName', ItemJournalBatch.Name);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventory.Calculate", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Missing postingDate is an error');
        Assert.IsTrue(ResponseJson.Get('parameter', ParameterToken), 'parameter missing');
        Assert.AreEqual('postingDate', ParameterToken.AsValue().AsText(), 'parameter is postingDate');
    end;

    [Test]
    procedure Calculate_WithPostingDateAndItemFilter_ReturnsLineCount()
    var
        Item: Record Item;
        Location: Record Location;
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        LineCountToken: JsonToken;
    begin
        // [SCENARIO] Calculate with postingDate and itemNoFilter fills the batch and returns lineCount.
        Initialize();
        CreateItemWithStock(Item, Location, 8);
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::"Phys. Inventory");
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::"Phys. Inventory", ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        RequestJson.Add('journalTemplateName', ItemJournalTemplate.Name);
        RequestJson.Add('journalBatchName', ItemJournalBatch.Name);
        RequestJson.Add('postingDate', Format(WorkDate(), 0, 9));
        RequestJson.Add('itemNoFilter', Item."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventory.Calculate", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Calculate should succeed. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('lineCount', LineCountToken), 'lineCount missing');
        Assert.AreNotEqual(0, LineCountToken.AsValue().AsInteger(), 'lineCount should be at least one');
        ItemJournalLine.SetRange("Journal Template Name", ItemJournalTemplate.Name);
        ItemJournalLine.SetRange("Journal Batch Name", ItemJournalBatch.Name);
        ItemJournalLine.SetRange("Item No.", Item."No.");
        Assert.IsTrue(ItemJournalLine.FindFirst(), 'A physical inventory line should exist for the filtered item');
        Assert.AreEqual(WorkDate(), ItemJournalLine."Posting Date", 'Posting date is applied to the journal line');
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
    end;

    [Test]
    procedure Post_AfterCalculate_ReturnsRegisterAndEntryNumbers()
    var
        Item: Record Item;
        Location: Record Location;
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemRegister: Record "Item Register";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        RegisterToken: JsonToken;
        FromToken: JsonToken;
        RegisterNo: Integer;
    begin
        // [SCENARIO] Post after Calculate returns item register and ledger entry numbers.
        Initialize();
        CreateItemWithStock(Item, Location, 5);
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::"Phys. Inventory");
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::"Phys. Inventory", ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        RequestJson.Add('journalTemplateName', ItemJournalTemplate.Name);
        RequestJson.Add('journalBatchName', ItemJournalBatch.Name);
        RequestJson.Add('postingDate', Format(WorkDate(), 0, 9));
        RequestJson.Add('itemNoFilter', Item."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventory.Calculate", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'calculate status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Calculate should succeed before post. ' + JsonText(ResponseJson));

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('journalTemplateName', ItemJournalTemplate.Name);
        RequestJson.Add('journalBatchName', ItemJournalBatch.Name);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventory.Post", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'post status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Post should succeed');
        Assert.IsTrue(ResponseJson.Get('itemRegisterNo', RegisterToken), 'itemRegisterNo missing');
        RegisterNo := RegisterToken.AsValue().AsInteger();
        Assert.AreNotEqual(0, RegisterNo, 'itemRegisterNo should be populated');
        Assert.IsTrue(ItemRegister.Get(RegisterNo), 'Posted item register should exist');
        Assert.IsTrue(ResponseJson.Get('fromEntryNo', FromToken), 'fromEntryNo missing');
        Assert.AreEqual(ItemRegister."From Entry No.", FromToken.AsValue().AsInteger(), 'fromEntryNo matches the register');
    end;

    local procedure CreateItemWithStock(var Item: Record Item; var Location: Record Location; Quantity: Decimal)
    var
        LibraryWarehouse: Codeunit "Library - Warehouse";
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        LibraryInventory.CreateItem(Item);
        Helper.CreatePositiveAdjustment(Item."No.", Location.Code, Quantity);
    end;

    local procedure JsonText(ResponseJson: JsonObject): Text
    var
        TextValue: Text;
    begin
        ResponseJson.WriteTo(TextValue);
        exit(TextValue);
    end;
}
