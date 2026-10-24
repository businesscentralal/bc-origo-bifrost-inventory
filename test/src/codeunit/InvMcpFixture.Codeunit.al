namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Origo.Bifrost.Inventory;

/// <summary>Explicit test-only seed for self-owned issue 159 MCP scenarios. It never runs on install or from product dispatch.</summary>
codeunit 96973 "Inv. MCP Fixture ori"
{
    trigger OnRun()
    var
        Item: Record Item;
        Location: Record Location;
        JournalTemplate: Record "Item Journal Template";
        StockTemplate: Record "Item Journal Template";
        StockBatch: Record "Item Journal Batch";
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        FeatureSetup: Record "Inventory Setup ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('This explicit test seed is limited to the owned CRONUS verification company.');
        if Item.Get('W8PRV-EN') or Item.Get('W8PRV-IS') or JournalTemplate.Get('W8PRV') then
            Error('Owned fixture already exists. Inspect actual state; never replay the seed.');
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        FeatureSetup.InsertIfNotExists();
        FeatureSetup.Get();
        FeatureSetup.Reclassification := true;
        FeatureSetup.Costing := true;
        FeatureSetup.Reservations := true;
        FeatureSetup.Modify();
        LibraryWarehouse.CreateLocation(Location);
        Location.Rename('W8PRV');
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalTemplate.Type::Transfer);
        JournalTemplate.Rename('W8PRV');
        LibraryInventory.CreateItemJournalTemplateByType(StockTemplate, StockTemplate.Type::Item);
        StockTemplate.Rename('W8PRVSTK');
        LibraryInventory.CreateItemJournalBatch(StockBatch, StockTemplate.Name);
        StockBatch.Rename(StockTemplate.Name, 'OWNED');
        CreateScenario('W8PRV-EN', 'EN', StockBatch, Location.Code);
        CreateScenario('W8PRV-IS', 'IS', StockBatch, Location.Code);
        CreateScenario('W8PRV-FAIL', 'FAIL', StockBatch, Location.Code);
        CreateScenario('W8PRV-OTHER', 'OTHER', StockBatch, Location.Code);
        CreateEmptyBatch();
    end;

    local procedure CreateScenario(ItemNo: Code[20]; BatchName: Code[10]; StockBatch: Record "Item Journal Batch"; NewLocation: Code[10])
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        GenProdGroup: Record "Gen. Product Posting Group";
        InvGroup: Record "Inventory Posting Group";
        GenPostingSetup: Record "General Posting Setup";
        InvPostingSetup: Record "Inventory Posting Setup";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryERM: Codeunit "Library - ERM";
        InventoryAccount: Code[20];
        AdjustmentAccount: Code[20];
    begin
        // Each scenario owns its item, posting groups/accounts, stock and selected journal batch.
        LibraryInventory.CreateItem(Item);
        Item.Rename(ItemNo);
        LibraryERM.CreateGenProdPostingGroup(GenProdGroup);
        LibraryInventory.CreateInventoryPostingGroup(InvGroup);
        Item.Validate("Gen. Prod. Posting Group", GenProdGroup.Code);
        Item.Validate("Inventory Posting Group", InvGroup.Code);
        Item.Modify(true);
        InventoryAccount := LibraryERM.CreateGLAccountNo();
        AdjustmentAccount := LibraryERM.CreateGLAccountNo();
        LibraryERM.CreateGeneralPostingSetup(GenPostingSetup, '', GenProdGroup.Code);
        GenPostingSetup."Inventory Adjmt. Account" := AdjustmentAccount;
        GenPostingSetup.Modify(true);
        LibraryInventory.CreateInventoryPostingSetup(InvPostingSetup, '', InvGroup.Code);
        InvPostingSetup."Inventory Account" := InventoryAccount;
        InvPostingSetup.Modify(true);
        LibraryInventory.CreateInventoryPostingSetup(InvPostingSetup, NewLocation, InvGroup.Code);
        InvPostingSetup."Inventory Account" := InventoryAccount;
        InvPostingSetup.Modify(true);
        LibraryInventory.CreateItemJournalLine(Line, StockBatch."Journal Template Name", StockBatch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(StockBatch."Journal Template Name", StockBatch.Name);
        LibraryInventory.CreateItemJournalBatch(Batch, 'W8PRV');
        Batch.Rename('W8PRV', BatchName);
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 2);
        Line.Validate("New Location Code", NewLocation);
        if BatchName = 'FAIL' then
            Line."Item No." := 'W8PRV-NOT-FOUND';
        Line.Modify(true);
    end;

    local procedure CreateEmptyBatch()
    var
        Batch: Record "Item Journal Batch";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemJournalBatch(Batch, 'W8PRV');
        Batch.Rename('W8PRV', 'EMPTY');
    end;
}
