namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Sales.Document;
using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Origo.Bifrost;
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
    /// <summary>Seeds only the explicit worker-6 issue39 undo scenarios and returns their exact document numbers.</summary>
    procedure SeedUndo39(): Text
    var
        Item: Record Item;
        Setup: Record "Inventory Setup ori";
        InventorySetup: Record "Inventory Setup";
        GLSetup: Record "General Ledger Setup";
        Scenarios: JsonArray;
        Result: JsonObject;
        Output: Text;
    begin
        AssertUndo39Company();
        Item.SetFilter("No.", 'W6U39-*');
        if not Item.IsEmpty() then
            Error('Issue39 fixtures exist. Inspect before retrying.');
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := true;
        Setup.Assembly := true;
        Setup.Modify();
        GLSetup.Get();
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        SeedUndo39Scenario('EN', 1033, Scenarios);
        SeedUndo39Scenario('IS', 1039, Scenarios);
        Result.Add('scenarios', Scenarios);
        Result.WriteTo(Output);
        exit(Output);
    end;

    local procedure SeedUndo39Scenario(Suffix: Code[2]; LanguageId: Integer; var Scenarios: JsonArray)
    var
        Item: Record Item;
        Parent: Record Item;
        Component: Record Item;
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransit: Record Location;
        Transfer: Record "Transfer Header";
        Assembly: Record "Assembly Header";
        Shipment: Record "Transfer Shipment Header";
        PostedAssembly: Record "Posted Assembly Header";
        TransferHelper: Codeunit "Transfer Order Test Helper";
        AssemblyHelper: Codeunit "Assembly Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
        Scenario: JsonObject;
        Token: JsonToken;
    begin
        TransferHelper.SetupLocationsAndItem(FromLocation, ToLocation, InTransit, Item, 0);
        Item.Rename('W6U39-S' + Suffix);
        FromLocation.Rename('W6U39F' + Suffix);
        ToLocation.Rename('W6U39T' + Suffix);
        InTransit.Rename('W6U39I' + Suffix);
        TransferHelper.CreatePositiveAdjustment(Item."No.", FromLocation.Code, 10);
        TransferHelper.CreateTransferHeader(Transfer, FromLocation.Code, ToLocation.Code, InTransit.Code);
        TransferHelper.CreateTransferLine(Transfer, Item."No.", 2);
        TransferHelper.CreateTransferLine(Transfer, Item."No.", 3);
        Commit();
        Codeunit.Run(Codeunit::"Release Transfer Document", Transfer);
        Request.Add('documentNo', Transfer."No.");
        Request.Add('postingType', 'Ship');
        TransferHelper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", Request, Response);
        Response.Get('status', Token);
        if Token.AsValue().AsText() <> 'Success' then
            Error('Owned shipment fixture could not post: %1', Response);
        Response.Get('postedShipmentNo', Token);
        Shipment.Get(Token.AsValue().AsText());
        Scenario.Add('lcid', LanguageId);
        Scenario.Add('shipmentNo', Shipment."No.");
        Scenario.Add('transferOrderNo', Transfer."No.");
        Scenario.Add('shipmentItemNo', Item."No.");
        AssemblyHelper.CreateAssemblyItemWithBOM(Parent, Component);
        // Rename the parent first, so its BOM remains linked. Replace the component through the BOM validation.
        Parent.Rename('W6U39-A' + Suffix);
        RenameUndo39Component(Parent."No.", Component, 'W6U39-C' + Suffix);
        AssemblyHelper.CreatePositiveAdjustment(Component."No.", 10);
        AssemblyHelper.CreateAssemblyOrder(Assembly, Parent."No.", 1);
        Clear(Request);
        Clear(Response);
        Request.Add('documentNo', Assembly."No.");
        AssemblyHelper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Post", Request, Response);
        Response.Get('status', Token);
        if Token.AsValue().AsText() <> 'Success' then
            Error('Owned assembly fixture could not post: %1', Response);
        PostedAssembly.SetRange("Order No.", Assembly."No.");
        PostedAssembly.FindFirst();
        Scenario.Add('assemblyNo', PostedAssembly."No.");
        Scenario.Add('assemblyOrderNo', Assembly."No.");
        Scenario.Add('assemblyItemNo', Parent."No.");
        Scenarios.Add(Scenario);
    end;

    local procedure RenameUndo39Component(ParentNo: Code[20]; var Component: Record Item; NewNo: Code[20])
    var
        BOM: Record "BOM Component";
    begin
        Component.Rename(NewNo);
        BOM.SetRange("Parent Item No.", ParentNo);
        BOM.SetRange(Type, BOM.Type::Item);
        BOM.FindFirst();
        BOM.Validate("No.", Component."No.");
        BOM.Modify(true);
    end;

    /// <summary>Deletes only test records linked to W6U39 items and their explicitly named test locations.</summary>
    procedure CleanupUndo39()
    var
        Item: Record Item;
        Entry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PostValueEntry: Record "Post Value Entry to G/L";
        AverageCostEntry: Record "Avg. Cost Adjmt. Entry Point";
        AdjustmentOrder: Record "Inventory Adjmt. Entry (Order)";
        Register: Record "Item Register";
        RangeEntry: Record "Item Ledger Entry";
        OwnedEntry: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        Relation: Record "Item Entry Relation";
        Transfer: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        Shipment: Record "Transfer Shipment Header";
        ShipmentLine: Record "Transfer Shipment Line";
        Assembly: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        PostedAssembly: Record "Posted Assembly Header";
        PostedAssemblyLine: Record "Posted Assembly Line";
        BOM: Record "BOM Component";
        Location: Record Location;
    begin
        AssertUndo39Company();
        if Register.FindSet() then
            repeat
                RangeEntry.SetRange("Entry No.", Register."From Entry No.", Register."To Entry No.");
                OwnedEntry.CopyFilters(RangeEntry);
                OwnedEntry.SetFilter("Item No.", 'W6U39-*');
                if (not RangeEntry.IsEmpty()) and (RangeEntry.Count() = OwnedEntry.Count()) then
                    Register.Delete();
            until Register.Next() = 0;
        Item.SetFilter("No.", 'W6U39-*');
        if Item.FindSet() then
            repeat
                Entry.SetRange("Item No.", Item."No.");
                if Entry.FindSet() then
                    repeat
                        Application.SetRange("Inbound Item Entry No.", Entry."Entry No.");
                        Application.DeleteAll();
                        Application.SetRange("Inbound Item Entry No.");
                        Application.SetRange("Outbound Item Entry No.", Entry."Entry No.");
                        Application.DeleteAll();
                        Application.SetRange("Outbound Item Entry No.");
                        Application.SetRange("Item Ledger Entry No.", Entry."Entry No.");
                        Application.DeleteAll();
                        Application.Reset();
                        Relation.SetRange("Item Entry No.", Entry."Entry No.");
                        Relation.DeleteAll();
                    until Entry.Next() = 0;
                PostValueEntry.SetRange("Item No.", Item."No.");
                PostValueEntry.DeleteAll();
                AverageCostEntry.SetRange("Item No.", Item."No.");
                AverageCostEntry.DeleteAll();
                AdjustmentOrder.SetRange("Item No.", Item."No.");
                AdjustmentOrder.DeleteAll();
                ValueEntry.SetRange("Item No.", Item."No.");
                ValueEntry.DeleteAll();
                Entry.DeleteAll();
                Item.UpdateCostIsAdjusted();
            until Item.Next() = 0;
        Transfer.SetFilter("Transfer-from Code", 'W6U39F*');
        if Transfer.FindSet() then
            repeat
                TransferLine.SetRange("Document No.", Transfer."No.");
                TransferLine.DeleteAll();
            until Transfer.Next() = 0;
        Transfer.DeleteAll();
        Shipment.SetFilter("Transfer-from Code", 'W6U39F*');
        if Shipment.FindSet() then
            repeat
                ShipmentLine.SetRange("Document No.", Shipment."No.");
                ShipmentLine.DeleteAll();
            until Shipment.Next() = 0;
        Shipment.DeleteAll();
        Assembly.SetFilter("Item No.", 'W6U39-*');
        if Assembly.FindSet() then
            repeat
                AssemblyLine.SetRange("Document Type", Assembly."Document Type");
                AssemblyLine.SetRange("Document No.", Assembly."No.");
                AssemblyLine.DeleteAll();
            until Assembly.Next() = 0;
        Assembly.DeleteAll();
        PostedAssembly.SetFilter("Item No.", 'W6U39-*');
        if PostedAssembly.FindSet() then
            repeat
                PostedAssemblyLine.SetRange("Document No.", PostedAssembly."No.");
                PostedAssemblyLine.DeleteAll();
            until PostedAssembly.Next() = 0;
        PostedAssembly.DeleteAll();
        BOM.SetFilter("Parent Item No.", 'W6U39-*');
        BOM.DeleteAll();
        Item.DeleteAll(true);
        Location.SetFilter(Code, 'W6U39*');
        Location.DeleteAll(true);
    end;

    local procedure AssertUndo39Company()
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('Only the owned issue39 verification company is supported.');
    end;

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
}
