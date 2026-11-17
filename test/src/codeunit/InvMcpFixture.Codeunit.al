namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.CRM.Contact;
using Microsoft.CRM.BusinessRelation;
using Microsoft.Sales.Document;
using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
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

    /// <summary>Explicitly seeds independent physical-count batches and periods for issue151 in the owned evaluation company.</summary>
    procedure CreateRefusalFixtures()
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Item: Record Item;
        Period: Record "Inventory Period";
        Setup: Record "Inventory Setup ori";
        CalculateInventory: Report "Calculate Inventory";
        LibraryInventory: Codeunit "Library - Inventory";
        Suffix: Code[2];
        Index: Integer;
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('Only the owned CRONUS verification company is supported.');
        if JournalTemplate.Get('W8COUNT') or Period.Get(20991231D) or Period.Get(20991130D) then
            Error('Owned151 fixtures exist; inspect actual state and do not replay.');
        Item.Get('W8PRV-EN');
        Item.Get('W8PRV-IS');
        Setup.Get();
        Setup."Phys. Inventory" := true;
        Setup."Inventory Period" := true;
        Setup.Modify();
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalTemplate.Type::"Phys. Inventory");
        JournalTemplate.Rename('W8COUNT');
        for Index := 1 to 2 do begin
            if Index = 1 then
                Suffix := 'EN'
            else
                Suffix := 'IS';
            LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
            Batch.Rename(JournalTemplate.Name, Suffix);
            Clear(Line);
            Line."Journal Template Name" := Batch."Journal Template Name";
            Line."Journal Batch Name" := Batch.Name;
            Item.Reset();
            Item.SetRange("No.", 'W8PRV-' + Suffix);
            Clear(CalculateInventory);
            CalculateInventory.SetItemJnlLine(Line);
            CalculateInventory.InitializeRequest(WorkDate(), 'W8COUNT-' + Suffix, false, false);
            CalculateInventory.SetTableView(Item);
            CalculateInventory.UseRequestPage(false);
            CalculateInventory.RunModal();
            Line.Reset();
            Line.SetRange("Journal Template Name", Batch."Journal Template Name");
            Line.SetRange("Journal Batch Name", Batch.Name);
            Line.FindLast();
            Line."Line No." += 10000;
            Line.Init();
            Line.Insert(false);
            LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
            Batch.Rename(JournalTemplate.Name, Suffix + 'CALC');
        end;
        Period.Init();
        Period."Ending Date" := 20991231D;
        Period.Name := 'W8I151 EN';
        Period.Insert(true);
        Period.Init();
        Period."Ending Date" := 20991130D;
        Period.Name := 'W8I151 IS';
        Period.Insert(true);
    end;

    /// <summary>Creates independent source lines for issue 150 in the owned evaluation company, only on explicit UI invocation.</summary>
    procedure CreateTrackingFixtures()
    var
        Item: Record Item;
        FeatureSetup: Record "Inventory Setup ori";
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('Owned evaluation company required.');
        if Item.Get('W8I150-L-EN') or Item.Get('W8I150-S-EN') or Item.Get('W8I150-L-IS') or Item.Get('W8I150-S-IS') then
            Error('Owned tracking fixtures already exist. Inspect actual state before recovery.');
        FeatureSetup.InsertIfNotExists();
        FeatureSetup.Get();
        FeatureSetup."Item Tracking" := true;
        FeatureSetup.Modify();
        CreateTrackingLine('W8I150-L-EN', false);
        CreateTrackingLine('W8I150-S-EN', true);
        CreateTrackingLine('W8I150-L-IS', false);
        CreateTrackingLine('W8I150-S-IS', true);
    end;

    /// <summary>Creates four explicitly owned issue 37 tracking fixtures through the existing native library adapters.</summary>
    procedure CreateTracking37Fixtures()
    var
        Item: Record Item;
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('Owned evaluation company required.');
        Item.SetFilter("No.", 'XW4I37-*');
        if not Item.IsEmpty() then
            Error('Owned issue 37 fixtures already exist; inspect them before retrying.');
        CreateTrackingLine('XW4I37-L-EN', false);
        CreateTrackingLine('XW4I37-S-EN', true);
        CreateTrackingLine('XW4I37-L-IS', false);
        CreateTrackingLine('XW4I37-S-IS', true);
    end;

    /// <summary>Deletes only owned issue 37 fixtures after the message API has removed their unposted tracking.</summary>
    procedure CleanupTracking37Fixtures()
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Vendor: Record Vendor;
        Contact: Record Contact;
        ContactRelation: Record "Contact Business Relation";
        ContactNumbers: List of [Code[20]];
        ContactNo: Code[20];
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('Owned evaluation company required.');
        Item.SetFilter("No.", 'XW4I37-*');
        if Item.FindSet() then
            repeat
                Entry.SetRange("Item No.", Item."No.");
                if not Entry.IsEmpty() then
                    Error('Remove owned item tracking through Inventory.Tracking.Delete before cleanup.');
                Line.SetRange(Type, Line.Type::Item);
                Line.SetRange("No.", Item."No.");
                while Line.FindFirst() do begin
                    Header.Get(Line."Document Type", Line."Document No.");
                    Vendor.Get(Header."Buy-from Vendor No.");
                    ContactRelation.SetRange("Link to Table", ContactRelation."Link to Table"::Vendor);
                    ContactRelation.SetRange("No.", Vendor."No.");
                    Clear(ContactNumbers);
                    if ContactRelation.FindSet() then
                        repeat
                            ContactNumbers.Add(ContactRelation."Contact No.");
                        until ContactRelation.Next() = 0;
                    Header.Delete(true);
                    Vendor.Delete(true);
                    foreach ContactNo in ContactNumbers do
                        if Contact.Get(ContactNo) then
                            Contact.Delete(true);
                end;
                if Item."Item Tracking Code" <> '' then
                    TrackingCode.Get(Item."Item Tracking Code");
                Item.Delete(true);
                if TrackingCode.Code <> '' then begin
                    TrackingCode.Delete(true);
                    Clear(TrackingCode);
                end;
            until Item.Next() = 0;
    end;

    local procedure CreateTrackingLine(ItemNo: Code[20]; Serial: Boolean)
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
    begin
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode."SN Specific Tracking" := Serial;
        TrackingCode."Lot Specific Tracking" := not Serial;
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Rename(ItemNo);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        LibraryPurchase.CreatePurchHeader(Header, Header."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(Line, Header, Line.Type::Item, Item."No.", 10);
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
    /// <summary>Creates owned, tracked inventory and a customer for issue 7 MCP probes through an explicit test page action.</summary>
    procedure CreateInv7Fixtures(Suffix: Code[2])
    var
        Item: Record Item;
        Customer: Record Customer;
        TrackingCode: Record "Item Tracking Code";
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransit: Record Location;
        FeatureSetup: Record "Inventory Setup ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Helper: Codeunit "Transfer Order Test Helper";
    begin
        AssertInv7Suffix(Suffix);
        if Item.Get('W6I7T' + Suffix) or Item.Get('W6I7U' + Suffix) or Customer.Get('W6I7C' + Suffix) then
            Error('Issue 7 fixtures already exist; inspect them before retrying.');
        FeatureSetup.InsertIfNotExists();
        FeatureSetup.Reservations := true;
        FeatureSetup."Transfer Orders" := true;
        FeatureSetup.Modify(true);
        LibrarySales.CreateCustomer(Customer);
        Customer.Rename('W6I7C' + Suffix);
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode."Lot Specific Tracking" := true;
        TrackingCode."SN Specific Tracking" := true;
        TrackingCode."Package Specific Tracking" := true;
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Rename('W6I7T' + Suffix);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        PostInv7Stock(Item, '', 'LOT-A', 'SER-A', 'PKG-A');
        PostInv7Stock(Item, '', 'LOT-B', 'SER-B', 'PKG-B');
        LibraryWarehouse.CreateLocationWMS(FromLocation, false, false, false, false, false);
        FromLocation.Rename('W6I7F' + Suffix);
        LibraryWarehouse.CreateLocationWMS(ToLocation, false, false, false, false, false);
        ToLocation.Rename('W6I7D' + Suffix);
        LibraryWarehouse.CreateInTransitLocation(InTransit);
        InTransit.Rename('W6I7I' + Suffix);
        LibraryInventory.CreateItem(Item);
        Item.Rename('W6I7U' + Suffix);
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        Helper.CreatePositiveAdjustment(Item."No.", FromLocation.Code, 10);
    end;

    local procedure PostInv7Stock(Item: Record Item; LocationCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50])
    var
        Line: Record "Item Journal Line";
        Entry: Record "Reservation Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryTracking: Codeunit "Library - Item Tracking";
    begin
        LibraryInventory.CreateItemJnlLine(Line, Line."Entry Type"::"Positive Adjmt.", WorkDate(), Item."No.", 1, LocationCode);
        LibraryTracking.CreateItemJournalLineItemTracking(Entry, Line, SerialNo, LotNo, PackageNo, 1);
        LibraryInventory.PostItemJournalLine(Line."Journal Template Name", Line."Journal Batch Name");
    end;

    /// <summary>Removes only this test page's issue 7 documents and owned inventory fixtures after explicit MCP cancellation.</summary>
    procedure CleanupInv7Fixtures(Suffix: Code[2])
    var
        SalesHeader: Record "Sales Header";
        Customer: Record Customer;
        Item: Record Item;
        Location: Record Location;
        TransferLine: Record "Transfer Line";
        TransferHeader: Record "Transfer Header";
        ShipmentLine: Record "Transfer Shipment Line";
        ShipmentHeader: Record "Transfer Shipment Header";
        ReceiptLine: Record "Transfer Receipt Line";
        ReceiptHeader: Record "Transfer Receipt Header";
        EntryRelation: Record "Item Entry Relation";
        ItemApplication: Record "Item Application Entry";
        Ledger: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Pending: Record "Post Value Entry to G/L";
        Reservation: Record "Reservation Entry";
        TrackingCode: Record "Item Tracking Code";
        ReservationManagement: Codeunit "Reservation Management";
        DocumentNo: Code[20];
        ItemNo: Code[20];
        TrackingCodeName: Code[10];
        Kind: Text;
    begin
        AssertInv7Suffix(Suffix);
        SalesHeader.SetRange("Sell-to Customer No.", 'W6I7C' + Suffix);
        SalesHeader.DeleteAll(true);
        foreach Kind in 'T|U'.Split('|') do begin
            ItemNo := 'W6I7' + Kind + Suffix;
            if Item.Get(ItemNo) then begin
                TrackingCodeName := Item."Item Tracking Code";
                TransferLine.SetRange("Item No.", ItemNo);
                while TransferLine.FindFirst() do begin
                    TransferHeader.Get(TransferLine."Document No.");
                    TransferHeader.Delete(true);
                end;
                ShipmentLine.SetRange("Item No.", ItemNo);
                while ShipmentLine.FindFirst() do begin
                    DocumentNo := ShipmentLine."Document No.";
                    ShipmentLine.SetRange("Document No.", DocumentNo);
                    ShipmentLine.DeleteAll();
                    if ShipmentHeader.Get(DocumentNo) then
                        ShipmentHeader.Delete();
                    ShipmentLine.SetRange("Document No.");
                end;
                ReceiptLine.SetRange("Item No.", ItemNo);
                while ReceiptLine.FindFirst() do begin
                    DocumentNo := ReceiptLine."Document No.";
                    ReceiptLine.SetRange("Document No.", DocumentNo);
                    ReceiptLine.DeleteAll();
                    if ReceiptHeader.Get(DocumentNo) then
                        ReceiptHeader.Delete();
                    ReceiptLine.SetRange("Document No.");
                end;
                Ledger.SetRange("Item No.", ItemNo);
                if Ledger.FindSet() then
                    repeat
                        ReservationManagement.SetReservSource(Ledger);
                        ReservationManagement.DeleteReservEntries(true, 0);
                        EntryRelation.SetRange("Item Entry No.", Ledger."Entry No.");
                        EntryRelation.DeleteAll();
                        ItemApplication.SetRange("Inbound Item Entry No.", Ledger."Entry No.");
                        ItemApplication.DeleteAll();
                        ItemApplication.SetRange("Inbound Item Entry No.");
                        ItemApplication.SetRange("Outbound Item Entry No.", Ledger."Entry No.");
                        ItemApplication.DeleteAll();
                        ItemApplication.SetRange("Outbound Item Entry No.");
                    until Ledger.Next() = 0;
                Reservation.SetRange("Item No.", ItemNo);
                if not Reservation.IsEmpty() then
                    Error('Cancel every owned reservation through Inventory.Reservation.Cancel before cleanup.');
                Pending.SetRange("Item No.", ItemNo);
                Pending.DeleteAll();
                ValueEntry.SetRange("Item No.", ItemNo);
                ValueEntry.DeleteAll();
                Ledger.DeleteAll();
                // Native source/tracking cleanup can update the item; delete the current record version.
                Clear(Item);
                Item.Get(ItemNo);
                // All owned ledger data is gone; native deletion must not adjust the removed test entries.
                Item."Cost is Adjusted" := true;
                Item.Modify();
                Item.Delete(true);
                if (TrackingCodeName <> '') and TrackingCode.Get(TrackingCodeName) then
                    TrackingCode.Delete(true);
            end;
        end;
        // Also finish an interrupted older cleanup that removed lines before their headers.
        ShipmentHeader.SetRange("Transfer-from Code", 'W6I7F' + Suffix);
        ShipmentHeader.SetRange("Transfer-to Code", 'W6I7D' + Suffix);
        if ShipmentHeader.FindSet() then
            repeat
                ShipmentLine.Reset();
                ShipmentLine.SetRange("Document No.", ShipmentHeader."No.");
                if ShipmentLine.IsEmpty() then
                    ShipmentHeader.Delete();
            until ShipmentHeader.Next() = 0;
        ReceiptHeader.SetRange("Transfer-from Code", 'W6I7F' + Suffix);
        ReceiptHeader.SetRange("Transfer-to Code", 'W6I7D' + Suffix);
        if ReceiptHeader.FindSet() then
            repeat
                ReceiptLine.Reset();
                ReceiptLine.SetRange("Document No.", ReceiptHeader."No.");
                if ReceiptLine.IsEmpty() then
                    ReceiptHeader.Delete();
            until ReceiptHeader.Next() = 0;
        if Customer.Get('W6I7C' + Suffix) then
            Customer.Delete(true);
        if Location.Get('W6I7F' + Suffix) then
            Location.Delete(true);
        if Location.Get('W6I7D' + Suffix) then
            Location.Delete(true);
        if Location.Get('W6I7I' + Suffix) then
            Location.Delete(true);
    end;

    local procedure AssertInv7Suffix(Suffix: Code[2])
    begin
        if not IsOwnedCompany() or not (Suffix in ['EN', 'IS']) then
            Error('Owned issue 7 fixtures require the evaluation company and suffix EN or IS.');
    end;

}
