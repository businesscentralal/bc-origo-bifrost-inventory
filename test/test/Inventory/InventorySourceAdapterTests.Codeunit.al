namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Service.Document;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Native W1 adapter unit tests for source pointers, UOM and posting progress; these do not claim end-to-end reservation pairing.</summary>
codeunit 96928 "Inventory Source Adapter Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Resolver: Codeunit "Inventory Source Resolve ori";

    /// <summary>SalesLine retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_SalesLineNativePointerAndProgress()
    var
        TempSource: Record "Sales Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document Type" := TempSource."Document Type"::Order;
        TempSource."Document No." := 'W8-SALE';
        TempSource."Line No." := 10000;
        TempSource."Type" := TempSource.Type::Item;
        TempSource."No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Qty. Shipped (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Sales Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(1, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-SALE', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(10000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>PurchaseLine retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_PurchaseLineNativePointerAndProgress()
    var
        TempSource: Record "Purchase Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document Type" := TempSource."Document Type"::Order;
        TempSource."Document No." := 'W8-PURCHASE';
        TempSource."Line No." := 20000;
        TempSource."Type" := TempSource.Type::Item;
        TempSource."No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Qty. Received (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Purchase Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(1, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-PURCHASE', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(20000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>TransferOutbound retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_TransferOutboundNativePointerAndProgress()
    var
        TempSource: Record "Transfer Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document No." := 'W8-TRANSFER';
        TempSource."Line No." := 30000;
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Transfer-from Code" := 'W8-FROM';
        TempSource."Transfer-to Code" := 'W8-TO';
        TempSource."Derived From Line No." := 50000;
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Qty. Shipped (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Transfer Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(0, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-TRANSFER', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(30000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(50000, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-FROM', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>TransferInbound retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_TransferInboundNativePointerAndProgress()
    var
        TempSource: Record "Transfer Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document No." := 'W8-TRANSFER';
        TempSource."Line No." := 30000;
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Transfer-from Code" := 'W8-FROM';
        TempSource."Transfer-to Code" := 'W8-TO';
        TempSource."Derived From Line No." := 50000;
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Qty. Received (Base)" := 3;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Inbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Transfer Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(1, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-TRANSFER', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(30000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(50000, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-TO', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(3, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>AssemblyHeader retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_AssemblyHeaderNativePointerAndProgress()
    var
        TempSource: Record "Assembly Header" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document Type" := TempSource."Document Type"::Order;
        TempSource."No." := 'W8-ASSEMBLY';
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Assembled Quantity (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Assembly Header", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(1, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-ASSEMBLY', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(0, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>AssemblyLine retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_AssemblyLineNativePointerAndProgress()
    var
        TempSource: Record "Assembly Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document Type" := TempSource."Document Type"::Order;
        TempSource."Document No." := 'W8-ASSEMBLY';
        TempSource."Line No." := 40000;
        TempSource."Type" := TempSource.Type::Item;
        TempSource."No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Consumed Quantity (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Assembly Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(1, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-ASSEMBLY', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(40000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>ServiceLine retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_ServiceLineNativePointerAndProgress()
    var
        TempSource: Record "Service Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Document Type" := TempSource."Document Type"::Order;
        TempSource."Document No." := 'W8-SERVICE';
        TempSource."Line No." := 60000;
        TempSource."Type" := TempSource.Type::Item;
        TempSource."No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Qty. Shipped (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Service Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(1, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-SERVICE', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(60000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>ProdOrderLine retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_ProdOrderLineNativePointerAndProgress()
    var
        TempSource: Record "Prod. Order Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Status" := TempSource.Status::Released;
        TempSource."Prod. Order No." := 'W8-PRODUCTION';
        TempSource."Line No." := 70000;
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        TempSource."Finished Qty. (Base)" := 6;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Prod. Order Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(3, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-PRODUCTION', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(0, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(70000, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>ProdOrderComponent retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_ProdOrderComponentNativePointerAndProgress()
    var
        TempSource: Record "Prod. Order Component" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Status" := TempSource.Status::Released;
        TempSource."Prod. Order No." := 'W8-PRODUCTION';
        TempSource."Prod. Order Line No." := 70000;
        TempSource."Line No." := 80000;
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Expected Qty. (Base)" := 15;
        TempSource."Remaining Qty. (Base)" := 9;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Prod. Order Component", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(3, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-PRODUCTION', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(80000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(70000, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(9, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(6, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>ItemJournalLine retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_ItemJournalLineNativePointerAndProgress()
    var
        TempSource: Record "Item Journal Line" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Entry Type" := TempSource."Entry Type"::"Positive Adjmt.";
        TempSource."Journal Template Name" := 'W8-TEMPL';
        TempSource."Journal Batch Name" := 'W8-BATCH';
        TempSource."Line No." := 90000;
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Quantity (Base)" := 15;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Item Journal Line", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(2, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('W8-TEMPL', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(90000, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('W8-BATCH', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(15, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(0, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
    end;

    /// <summary>ItemLedgerEntry retains its native source pointer, base UOM and handled quantity.</summary>
    [Test]
    procedure Scenario_AC7_ItemLedgerEntryNativePointerAndProgress()
    var
        TempSource: Record "Item Ledger Entry" temporary;
        TempSpecification: Record "Tracking Specification" temporary;
        SourceRef: RecordRef;
    begin
        // [GIVEN] An isolated source buffer with distinguishable keys, UOM and posting progress.
        TempSource."Entry No." := 987654;
        TempSource."Item No." := 'W8-ITEM';
        TempSource."Location Code" := 'W8-LOC';
        TempSource."Qty. per Unit of Measure" := 3;
        TempSource."Remaining Quantity" := 9;
        TempSource."Lot No." := 'W8-LOT';
        TempSource."Serial No." := 'W8-SERIAL';
        TempSource."Package No." := 'W8-PACKAGE';
        TempSource."Expiration Date" := 20300101D;
        SourceRef.GetTable(TempSource);

        // [WHEN] The production resolver invokes the W1 native source adapter.
        Resolver.InitializeSpecification(SourceRef, "Transfer Direction"::Outbound, TempSpecification);

        // [THEN] No pointer component or posted quantity is lost.
        Assert.AreEqual(Database::"Item Ledger Entry", TempSpecification."Source Type", 'Native source table.');
        Assert.AreEqual(0, TempSpecification."Source Subtype", 'Native source subtype.');
        Assert.AreEqual('', TempSpecification."Source ID", 'Document/template identity.');
        Assert.AreEqual(987654, TempSpecification."Source Ref. No.", 'Line/entry identity.');
        Assert.AreEqual('', TempSpecification."Source Batch Name", 'Journal batch identity.');
        Assert.AreEqual(0, TempSpecification."Source Prod. Order Line", 'Production/derived line identity.');
        Assert.AreEqual('W8-LOC', TempSpecification."Location Code", 'Correct location and transfer direction.');
        Assert.AreEqual(3, TempSpecification."Qty. per Unit of Measure", 'Non-unit UOM is preserved.');
        Assert.AreEqual(9, TempSpecification."Quantity (Base)", 'Base source quantity.');
        Assert.AreEqual(0, TempSpecification."Quantity Handled (Base)", 'Posted progress is retained.');
        Assert.AreEqual(TempSource."Lot No.", TempSpecification."Lot No.", 'Posted tracking preserved.');
        Assert.AreEqual(TempSource."Serial No.", TempSpecification."Serial No.", 'Posted tracking preserved.');
        Assert.AreEqual(TempSource."Package No.", TempSpecification."Package No.", 'Posted tracking preserved.');
        Assert.AreEqual(TempSource."Expiration Date", TempSpecification."Expiration Date", 'Posted tracking preserved.');
    end;

}
