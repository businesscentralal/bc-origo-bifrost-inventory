namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Sales.Document;
using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
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
        if not IsOwnedCompany() then
            Error('This explicit test seed is limited to the owned CRONUS verification company.');
        if Item.Get(FixtureCode('PRV-EN')) or Item.Get(FixtureCode('PRV-IS')) or JournalTemplate.Get(FixtureShortCode('PRV')) then
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
        Location.Rename(FixtureShortCode('PRV'));
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalTemplate.Type::Transfer);
        JournalTemplate.Rename(FixtureShortCode('PRV'));
        LibraryInventory.CreateItemJournalTemplateByType(StockTemplate, StockTemplate.Type::Item);
        StockTemplate.Rename(FixtureShortCode('PRVSTK'));
        LibraryInventory.CreateItemJournalBatch(StockBatch, StockTemplate.Name);
        StockBatch.Rename(StockTemplate.Name, 'OWNED');
        CreateScenario(FixtureCode('PRV-EN'), 'EN', StockBatch, Location.Code);
        CreateScenario(FixtureCode('PRV-IS'), 'IS', StockBatch, Location.Code);
        CreateScenario(FixtureCode('PRV-FAIL'), 'FAIL', StockBatch, Location.Code);
        CreateScenario(FixtureCode('PRV-OTHER'), 'OTHER', StockBatch, Location.Code);
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
        LibraryInventory.CreateItemJournalBatch(Batch, FixtureShortCode('PRV'));
        Batch.Rename(FixtureShortCode('PRV'), BatchName);
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 2);
        Line.Validate("New Location Code", NewLocation);
        if BatchName = 'FAIL' then
            Line."Item No." := FixtureCode('PRV-NOT-FOUND');
        Line.Modify(false);
    end;

    local procedure CreateEmptyBatch()
    var
        Batch: Record "Item Journal Batch";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemJournalBatch(Batch, FixtureShortCode('PRV'));
        Batch.Rename(FixtureShortCode('PRV'), 'EMPTY');
    end;
    /// <summary>Completes only the inspected partial seed; it never repeats an existing stock posting.</summary>
    procedure CompletePreviewFixture()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        StockBatch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entry: Record "Item Ledger Entry";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        if not IsOwnedCompany() then
            Error('Owned company required.');
        Item.Get(FixtureCode('PRV-FAIL'));
        Entry.SetRange("Item No.", Item."No.");
        if Entry.Count() <> 1 then
            Error('Inspect owned stock before recovery.');
        Entry.FindFirst();
        Entry.TestField(Quantity, 10);
        if Batch.Get(FixtureShortCode('PRV'), 'FAIL') or Item.Get(FixtureCode('PRV-OTHER')) or Batch.Get(FixtureShortCode('PRV'), 'EMPTY') then
            Error('Recovery target already exists; inspect before another action.');
        LibraryInventory.CreateItemJournalBatch(Batch, FixtureShortCode('PRV'));
        Batch.Rename(FixtureShortCode('PRV'), 'FAIL');
        LibraryInventory.CreateItemJournalLine(Line, FixtureShortCode('PRV'), 'FAIL', Line."Entry Type"::Transfer, FixtureCode('PRV-FAIL'), 2);
        Line.Validate("New Location Code", FixtureShortCode('PRV'));
        // Explicit corrupt test fixture: native preview must reject it without changing journal or ledger records.
        Line."Item No." := FixtureCode('PRV-NOT-FOUND');
        Line.Modify(false);
        StockBatch.Get(FixtureShortCode('PRVSTK'), 'OWNED');
        CreateScenario(FixtureCode('PRV-OTHER'), 'OTHER', StockBatch, FixtureShortCode('PRV'));
        CreateEmptyBatch();
    end;

    /// <summary>Creates separate owned source documents for live posting, undo and item-charge MCP acceptance.</summary>
    procedure CreatePostingFixtures(Suffix: Code[2])
    var
        Item: Record Item;
        FeatureSetup: Record "Inventory Setup ori";
        Customer: Record Customer;
        LibrarySales: Codeunit "Library - Sales";
    begin
        if not IsOwnedCompany() or not (Suffix in ['EN', 'IS']) then
            Error('Owned company and scenario required.');
        if Item.Get(FixtureCode('ASM-' + Suffix)) or Item.Get(FixtureCode('TRF-' + Suffix)) or Item.Get(FixtureCode('CHI1-' + Suffix)) then
            Error('Posting fixture exists; inspect state, do not replay.');
        FeatureSetup.Get();
        FeatureSetup.Assembly := true;
        FeatureSetup."Transfer Orders" := true;
        FeatureSetup."Item Charge" := true;
        FeatureSetup.Modify(true);
        if Suffix = 'EN' then begin
            if Customer.Get(FixtureCode('PRV-CUST')) then
                Error('Owned customer already exists.');
            LibrarySales.CreateCustomer(Customer);
            Customer.Rename(FixtureCode('PRV-CUST'));
            ConfigureReservationVAT();
        end;
        CreateAssemblyFixture(Suffix);
        CreateTransferFixture(Suffix);
        CreateChargeFixture(Suffix);
    end;

    local procedure CreateAssemblyFixture(Suffix: Code[2])
    var
        ParentItem: Record Item;
        Component: Record Item;
        BOM: Record "BOM Component";
        Header: Record "Assembly Header";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssembly: Codeunit "Library - Assembly";
    begin
        LibraryInventory.CreateItem(Component);
        Component.Rename(FixtureCode('CMP-' + Suffix));
        LibraryInventory.CreateItem(ParentItem);
        ParentItem.Rename(FixtureCode('ASM-' + Suffix));
        ParentItem.Validate("Replenishment System", ParentItem."Replenishment System"::Assembly);
        ParentItem.Validate("Assembly Policy", ParentItem."Assembly Policy"::"Assemble-to-Stock");
        ParentItem.Modify(true);
        LibraryAssembly.CreateAssemblyListComponent(BOM.Type::Item, Component."No.", ParentItem."No.", '', BOM."Resource Usage Type", 1, true);
        PostOwnedStock(Component."No.", '', 'ASM' + Suffix, 10);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), ParentItem."No.", '', 2, '');
    end;

    local procedure CreateTransferFixture(Suffix: Code[2])
    var
        Item: Record Item;
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransit: Record Location;
        Header: Record "Transfer Header";
        Line: Record "Transfer Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
    begin
        LibraryWarehouse.CreateLocationWMS(FromLocation, false, false, false, false, false);
        LibraryWarehouse.CreateLocationWMS(ToLocation, false, false, false, false, false);
        LibraryWarehouse.CreateInTransitLocation(InTransit);
        LibraryInventory.CreateItem(Item);
        Item.Rename(FixtureCode('TRF-' + Suffix));
        PostOwnedStock(Item."No.", FromLocation.Code, 'TRF' + Suffix, 30);
        LibraryWarehouse.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransit.Code);
        LibraryWarehouse.CreateTransferLine(Header, Line, Item."No.", 4);
        LibraryWarehouse.CreateTransferLine(Header, Line, Item."No.", 2);
        Codeunit.Run(Codeunit::"Release Transfer Document", Header);
    end;

    local procedure PostOwnedStock(ItemNo: Code[20]; LocationCode: Code[10]; BatchName: Code[10]; Quantity: Decimal)
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        if Batch.Get(FixtureShortCode('PRVSTK'), BatchName) then
            Error('Owned stock batch exists.');
        LibraryInventory.CreateItemJournalBatch(Batch, FixtureShortCode('PRVSTK'));
        Batch.Rename(FixtureShortCode('PRVSTK'), BatchName);
        LibraryInventory.CreateItemJournalLine(Line, FixtureShortCode('PRVSTK'), BatchName, Line."Entry Type"::"Positive Adjmt.", ItemNo, Quantity);
        Line.Validate("Location Code", LocationCode);
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(FixtureShortCode('PRVSTK'), BatchName);
    end;

    local procedure CreateChargeFixture(Suffix: Code[2])
    var
        Vendor: Record Vendor;
        Item: Record Item;
        Charge: Record "Item Charge";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
    begin
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Rename(FixtureCode('CHGV-' + Suffix));
        LibraryInventory.CreateItemCharge(Charge);
        Charge.Rename(FixtureCode('CHG-' + Suffix));
        LibraryPurchase.CreatePurchHeader(Header, Header."Document Type"::Order, Vendor."No.");
        LibraryInventory.CreateItem(Item);
        Item.Rename(FixtureCode('CHI1-' + Suffix));
        LibraryPurchase.CreatePurchaseLine(Line, Header, Line.Type::Item, Item."No.", 2);
        Line.Validate("Direct Unit Cost", 10);
        Line.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Rename(FixtureCode('CHI2-' + Suffix));
        LibraryPurchase.CreatePurchaseLine(Line, Header, Line.Type::Item, Item."No.", 2);
        Line.Validate("Direct Unit Cost", 20);
        Line.Modify(true);
        LibraryPurchase.CreateItemChargePurchaseLine(Line, Charge, Header, 4, 5);
    end;

    /// <summary>Builds an owned VAT combination through native validation without changing Bifrost write guards.</summary>
    procedure ConfigureReservationVAT()
    var
        Customer: Record Customer;
        Header: Record "Sales Header";
        Item: Record Item;
        VATSetup: Record "VAT Posting Setup";
        GenBusGroup: Record "Gen. Business Posting Group";
        GenSetup: Record "General Posting Setup";
        SalesLine: Record "Sales Line";
        LibraryERM: Codeunit "Library - ERM";
        LibrarySales: Codeunit "Library - Sales";
    begin
        if not IsOwnedCompany() then
            Error('Owned company required.');
        Customer.Get(FixtureCode('PRV-CUST'));
        Header.SetRange("Sell-to Customer No.", Customer."No.");
        if not Header.IsEmpty() then
            Error('Sales source already exists; inspect it before changing its fixture setup.');
        LibraryERM.CreateVATPostingSetupWithAccounts(VATSetup, VATSetup."VAT Calculation Type"::"Normal VAT", 0);
        LibraryERM.CreateGenBusPostingGroup(GenBusGroup);
        Customer.Validate("Gen. Bus. Posting Group", GenBusGroup.Code);
        Customer.Validate("VAT Bus. Posting Group", VATSetup."VAT Bus. Posting Group");
        Customer.Modify(true);
        Item.Get(FixtureCode('PRV-EN'));
        Item.Validate("VAT Prod. Posting Group", VATSetup."VAT Prod. Posting Group");
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        LibraryERM.CreateGeneralPostingSetup(GenSetup, GenBusGroup.Code, Item."Gen. Prod. Posting Group");
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, Header, SalesLine.Type::Item, Item."No.", 3);
        SalesLine.Validate("Shipment Date", WorkDate());
        SalesLine.Validate(Reserve, SalesLine.Reserve::Optional);
        SalesLine.Modify(true);
        Item.Get(FixtureCode('PRV-IS'));
        Item.Validate("VAT Prod. Posting Group", VATSetup."VAT Prod. Posting Group");
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        LibraryERM.CreateGeneralPostingSetup(GenSetup, GenBusGroup.Code, Item."Gen. Prod. Posting Group");
        Clear(Header);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, Header, SalesLine.Type::Item, Item."No.", 3);
        SalesLine.Validate("Shipment Date", WorkDate());
        SalesLine.Validate(Reserve, SalesLine.Reserve::Optional);
        SalesLine.Modify(true);
    end;

    /// <summary>Reports whether this company's isolated preview fixture already exists.</summary>
    procedure FixtureExists(): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.Get(FixtureCode('PRV-EN')));
    end;

    local procedure IsOwnedCompany(): Boolean
    begin
        exit(CompanyName() in ['CRONUS International Ltd.', 'CRONUS W8 Inv164']);
    end;

    local procedure FixtureShortCode(Suffix: Text): Code[10]
    begin
        exit(CopyStr(FixtureCode(Suffix), 1, 10));
    end;

    local procedure FixtureCode(Suffix: Text): Code[20]
    begin
        if CompanyName() = 'CRONUS W8 Inv164' then
            exit(CopyStr('R8' + Suffix, 1, 20));
        exit(CopyStr('W8' + Suffix, 1, 20));
    end;
}
