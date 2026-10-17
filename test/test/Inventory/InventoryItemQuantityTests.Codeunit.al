namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.Cost.Get returns calculated inventory and Inventory.Revaluation.Calculate
/// returns remaining value from calculated ledger cost.
/// </summary>
codeunit 96924 "Inventory Item Quantity Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    procedure CostGet_ItemNo_ReturnsCalculatedInventory()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        Quantity: Decimal;
    begin
        Quantity := 4;
        LibraryInventory.CreateItem(Item);
        PostPositiveAdjustment(Item."No.", Quantity, 2.5);
        Item.CalcFields(Inventory);
        RequestJson.Add('itemNo', Item."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Cost.Get", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'status');
        Assert.IsTrue(ResponseJson.Get('inventory', Token), 'inventory missing');
        Assert.AreEqual(Item.Inventory, Token.AsValue().AsDecimal(), 'inventory');
        Assert.AreEqual(Quantity, Token.AsValue().AsDecimal(), 'posted quantity');
    end;

    [Test]
    procedure RevaluationCalculate_UsesLedgerCost()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        Quantity: Decimal;
        UnitAmount: Decimal;
    begin
        Quantity := 4;
        UnitAmount := 2.5;
        LibraryInventory.CreateItem(Item);
        PostPositiveAdjustment(Item."No.", Quantity, UnitAmount);
        RequestJson.Add('itemNo', Item."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Revaluation.Calculate", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'status');
        Assert.IsTrue(ResponseJson.Get('remainingQuantity', Token), 'remainingQuantity missing');
        Assert.AreEqual(Quantity, Token.AsValue().AsDecimal(), 'remainingQuantity');
        Assert.IsTrue(ResponseJson.Get('inventoryValue', Token), 'inventoryValue missing');
        Assert.AreNearlyEqual(Quantity * UnitAmount, Token.AsValue().AsDecimal(), 0.01, 'inventoryValue');
    end;

    local procedure PostPositiveAdjustment(ItemNo: Code[20]; Quantity: Decimal; UnitAmount: Decimal)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::Item, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        LibraryInventory.CreateItemJournalLine(
            ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name,
            "Item Ledger Entry Type"::"Positive Adjmt.", ItemNo, Quantity);
        ItemJournalLine.Validate("Unit Amount", UnitAmount);
        ItemJournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;
}
