namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Purchases.Document;
using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Counting.Recording;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Pricing.PriceList;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;

using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;
using System.TestLibraries.Upgrade;
using System.Upgrade;

/// <summary>Usage-based domain defaults for issue 147. Each native test runs with transaction rollback in an owned company.</summary>
codeunit 96963 "Inventory Domain Usage Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC05_AttributesUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Attributes signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Attribute");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 10, true);
    end;

    [Test]
    procedure Scenario_AC05_AttributesNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 10, false);
    end;

    [Test]
    procedure Scenario_AC05_TransferUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Transfer signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::Location);
        SetField(UsageRecord, 'Use As In-Transit', true);
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 11, true);
    end;

    [Test]
    procedure Scenario_AC05_TransferNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 11, false);
    end;

    [Test]
    procedure Scenario_AC05_AssemblyUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Assembly signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"BOM Component");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 12, true);
    end;

    [Test]
    procedure Scenario_AC05_AssemblyNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 12, false);
    end;

    [Test]
    procedure Scenario_AC05_ReservationsUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Reservations signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Reservation Entry");
        SetField(UsageRecord, 'Reservation Status', 0);
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 13, true);
    end;

    [Test]
    procedure Scenario_AC05_ReservationsNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 13, false);
    end;

    [Test]
    procedure Scenario_AC05_TrackingUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Tracking signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Tracking Code");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 14, true);
    end;

    [Test]
    procedure Scenario_AC05_TrackingNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 14, false);
    end;

    [Test]
    procedure Scenario_AC05_PhysicalUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Physical signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Phys. Invt. Record Header");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 15, true);
    end;

    [Test]
    procedure Scenario_AC05_PhysicalNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 15, false);
    end;

    [Test]
    procedure Scenario_AC05_CostingUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Costing signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Value Entry");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 16, true);
    end;

    [Test]
    procedure Scenario_AC05_CostingNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 16, false);
    end;

    [Test]
    procedure Scenario_AC05_ReclassUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Reclass signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::Location);
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 17, true);
    end;

    [Test]
    procedure Scenario_AC05_ReclassNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 17, false);
    end;

    [Test]
    procedure Scenario_AC05_ApplicationUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Application signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Application Entry");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 18, true);
    end;

    [Test]
    procedure Scenario_AC05_ApplicationNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 18, false);
    end;

    [Test]
    procedure Scenario_AC05_PeriodUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Period signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Inventory Period");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 19, true);
    end;

    [Test]
    procedure Scenario_AC05_PeriodNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 19, false);
    end;

    [Test]
    procedure Scenario_AC05_PriceUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Price signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Price List Line");
        SetField(UsageRecord, 'Asset Type', 10);
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 20, true);
    end;

    [Test]
    procedure Scenario_AC05_PriceNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 20, false);
    end;

    [Test]
    procedure Scenario_AC05_ReferenceUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Reference signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Reference");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 21, true);
    end;

    [Test]
    procedure Scenario_AC05_ReferenceNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 21, false);
    end;

    [Test]
    procedure Scenario_AC05_AvailabilityUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Availability signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::Item);
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 22, true);
    end;

    [Test]
    procedure Scenario_AC05_AvailabilityNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 22, false);
    end;

    [Test]
    procedure Scenario_AC05_ChargeUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Charge signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Charge");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 23, true);
    end;

    [Test]
    procedure Scenario_AC05_ChargeNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 23, false);
    end;

    [Test]
    procedure Scenario_AC05_CategoryUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created Category signal.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Category");
        
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Only evidence is needed to turn the tested domain on.
        AssertDomain(InventorySetup, 24, true);
    end;

    [Test]
    procedure Scenario_AC05_CategoryNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] All source tables are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 24, false);
    end;

    [Test]
    procedure Scenario_AC05_PurchaseReturnUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue137 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one purchase return order header.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Purchase Header");
        SetField(UsageRecord, 'Document Type', "Purchase Document Type"::"Return Order");
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row; the table trigger must run.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] A return order is enough to turn Purchase Returns on.
        AssertDomain(InventorySetup, 26, true);
    end;

    [Test]
    procedure Scenario_AC05_PurchaseReturnNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue137 | Time: no date selection | Risk: isolated company data, rolled back by runner.
        // [GIVEN] Purchase documents, including ordinary orders, are cleared in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without a return order or credit memo.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Purchase Returns stays off. A purchase order is not a signal.
        AssertDomain(InventorySetup, 26, false);
    end;

    [Test]
    procedure Scenario_AC05_PlanningUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        WkshTemplate: Record "Req. Wksh. Template";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue117 | Time: none | Risk: isolated company data, rolled back by the runner.
        // [GIVEN] No usage signals, then one planning worksheet template.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Req. Wksh. Template");
        WkshTemplate.Type := WkshTemplate.Type::Planning;
        SetField(UsageRecord, 'Type', WkshTemplate.Type);
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The planning template enables Planning and leaves the other new switch testable on its own.
        AssertDomain(InventorySetup, 27, true);
    end;

    [Test]
    procedure Scenario_AC05_PlanningNoUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue117 | Time: none | Risk: isolated company data, rolled back by the runner.
        // [GIVEN] All source tables, including planning worksheet templates, are empty in this transaction.
        ClearUsage();
        // [WHEN] A setup row is created without usage.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Planning stays off.
        AssertDomain(InventorySetup, 27, false);
    end;

    [Test]
    procedure Scenario_AC03_AlreadyOnWithoutUsage_StaysOn()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC03 | Time: none | Risk: no automatic disabling.
        ClearUsage();
        InventorySetup.Init();
        InventorySetup.Attributes := true;
        Assert.IsFalse(InventorySetup.EnableDomainsInUse(), 'No change without usage.');
        Assert.IsTrue(InventorySetup.Attributes, 'An enabled domain must stay enabled.');
    end;

    [Test]
    procedure Scenario_AC04_SecondEvaluation_DoesNotModifyRow()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
        BeforeVersion: BigInteger;
    begin
        // [SCENARIO] Issue147 AC04 | Time: SystemRowVersion proves no Modify | Risk: none.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Attribute");
        UsageRecord.Insert(false);
        InsertSetupFromUsage(InventorySetup);
        BeforeVersion := InventorySetup.SystemRowVersion;
        Assert.IsFalse(InventorySetup.EnableDomainsInUse(), 'Already enabled usage must report no change.');
        InventorySetup.Get();
        Assert.AreEqual(BeforeVersion, InventorySetup.SystemRowVersion, 'No redundant Modify.');
    end;

    [Test]
    procedure Scenario_AC01_UpgradeExistingOffRow_EnablesUsageOnce()
    var
        InventorySetup: Record "Inventory Setup ori";
        InventoryUpgrade: Codeunit "Inventory Upgrade ori";
        UpgradeTagLibrary: Codeunit "Upgrade Tag Library";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC01/03 | Time: none | Risk: preserve later manual opt-out.
        ClearUsage();
        InventorySetup.Init();
        InventorySetup.Insert(false);
        PrepareUsage(UsageRecord, Database::"Item Reference");
        UsageRecord.Insert(false);
        UpgradeTagLibrary.DeleteUpgradeTag(InventoryUpgrade.GetDomainUsageTag(), CopyStr(CompanyName(), 1, 30));
        // Upgrade lifecycle is platform driven; invoke its shared migration entry directly.
        InventoryUpgrade.EnableUsedDomains();
        InventorySetup.Get();
        Assert.IsTrue(InventorySetup."Item Reference", 'Existing false value must migrate from usage.');
        InventorySetup."Item Reference" := false;
        InventorySetup.Modify(true);
        InventoryUpgrade.EnableUsedDomains();
        InventorySetup.Get();
        Assert.IsFalse(InventorySetup."Item Reference", 'The tag preserves manual changes after migration.');
    end;

    [Test]
    procedure Scenario_Issue119_CatalogUsage_EnablesDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue119 | Time: none | Risk: isolated company data, rolled back by runner.
        // [GIVEN] No usage signals, then one self-created catalog item.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Nonstock Item");
        UsageRecord.Insert(false);
        // [WHEN] A user creates the setup row.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The Catalog Items domain is on.
        AssertDomain(InventorySetup, 28, true);
    end;

    [Test]
    procedure Scenario_Issue119_NoCatalogUsage_PreservesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue119 | Time: none | Risk: isolated company data, rolled back by runner.
        ClearUsage();
        InsertSetupFromUsage(InventorySetup);
        AssertDomain(InventorySetup, 28, false);
    end;

    [Test]
    procedure Scenario_Issue119_CatalogUpgrade_RaisesOnlyCatalogItemsOnce()
    var
        InventorySetup: Record "Inventory Setup ori";
        InventoryUpgrade: Codeunit "Inventory Upgrade ori";
        UpgradeTag: Codeunit "Upgrade Tag";
        UpgradeTagLibrary: Codeunit "Upgrade Tag Library";
        UsageRecord: RecordRef;
        PerCompanyUpgradeTags: List of [Code[250]];
    begin
        // [SCENARIO] Issue119 | Time: none | Risk: the catalog migration must not undo an earlier opt-out of another domain.
        // [GIVEN] An existing row with every switch off, catalog items and item references in use.
        ClearUsage();
        InventorySetup.Init();
        InventorySetup.Insert(false);
        PrepareUsage(UsageRecord, Database::"Nonstock Item");
        UsageRecord.Insert(false);
        UsageRecord.Close();
        PrepareUsage(UsageRecord, Database::"Item Reference");
        UsageRecord.Insert(false);
        if UpgradeTag.HasUpgradeTag(InventoryUpgrade.GetCatalogItemsUsageTag()) then
            UpgradeTagLibrary.DeleteUpgradeTag(InventoryUpgrade.GetCatalogItemsUsageTag(), CopyStr(CompanyName(), 1, 30));
        // [WHEN] The catalog items migration runs.
        InventoryUpgrade.EnableUsedCatalogItems();
        // [THEN] Only Catalog Items is raised; Item Reference stays off as the administrator left it.
        InventorySetup.Get();
        Assert.IsTrue(InventorySetup."Catalog Items", 'Catalog items in use raise the new domain.');
        Assert.IsFalse(InventorySetup."Item Reference", 'Other switches are not touched by the catalog migration.');
        // [THEN] The tag makes the migration run once and is registered for new companies.
        InventorySetup."Catalog Items" := false;
        InventorySetup.Modify(true);
        InventoryUpgrade.EnableUsedCatalogItems();
        InventorySetup.Get();
        Assert.IsFalse(InventorySetup."Catalog Items", 'The tag preserves a later opt-out.');
        UpgradeTag.GetPerCompanyUpgradeTags(PerCompanyUpgradeTags);
        Assert.IsTrue(PerCompanyUpgradeTags.Contains(InventoryUpgrade.GetCatalogItemsUsageTag()), 'New companies register the catalog migration tag.');
    end;

    [Test]
    procedure Scenario_AC02_MissingSetup_StaysAbsentAndOff()
    var
        InventorySetup: Record "Inventory Setup ori";
        InventoryUpgrade: Codeunit "Inventory Upgrade ori";
        UpgradeTagLibrary: Codeunit "Upgrade Tag Library";
    begin
        // [SCENARIO] Issue147 AC02 | Time: none | Risk: preserve missing-row contract.
        ClearUsage();
        UpgradeTagLibrary.DeleteUpgradeTag(InventoryUpgrade.GetDomainUsageTag(), CopyStr(CompanyName(), 1, 30));
        InventoryUpgrade.EnableUsedDomains();
        Assert.IsFalse(InventorySetup.Get(), 'Upgrade must not insert a missing setup.');
        Assert.IsFalse(InventorySetup.IsDomainEnabled(Enum::"Inventory Domain ori"::ItemReference), 'Absent means off.');
    end;

    [Test]
    procedure Scenario_AC02_SetupPage_OpensWithSwitchesOff()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
        SetupPage: TestPage "Inventory Setup ori";
    begin
        // [SCENARIO] Issue267 AC01 | Time: none | Risk: the page no longer derives switches from usage; Suggest Setup does.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Charge");
        UsageRecord.Insert(false);
        SetupPage.OpenEdit();
        SetupPage.ItemCharge.AssertEquals(false);
        SetupPage.Close();
        InventorySetup.Get();
        Assert.IsFalse(InventorySetup."Item Charge", 'Opening the page creates a row with every switch off.');
    end;

    [Test]
    procedure Scenario_AC05_NonTransitLocation_DoesNotEnableTransfer()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: none | Risk: do not infer transfers from any location.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::Location);
        UsageRecord.Insert(false);
        InsertSetupFromUsage(InventorySetup);
        Assert.IsFalse(InventorySetup."Transfer Orders", 'A normal location is not a transfer signal.');
        Assert.IsTrue(InventorySetup.Reclassification, 'A normal location is a reclassification signal.');
    end;

    [Test]
    procedure Scenario_AC05_SurplusTracking_DoesNotEnableReservation()
    var
        InventorySetup: Record "Inventory Setup ori";
        ReservationEntry: Record "Reservation Entry";
    begin
        // [SCENARIO] Issue147 AC05 | Time: none | Risk: distinguish tracking from reservations.
        ClearUsage();
        ReservationEntry."Entry No." := 1;
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Surplus;
        ReservationEntry."Lot No." := 'ZZTEST';
        ReservationEntry.Insert(false);
        InsertSetupFromUsage(InventorySetup);
        Assert.IsFalse(InventorySetup.Reservations, 'Surplus is not a reservation.');
        Assert.IsTrue(InventorySetup."Item Tracking", 'Lot tracking enables tracking.');
    end;

    [Test]
    procedure Scenario_AC05_ProductionBOM_EnablesAssembly()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
    begin
        // [SCENARIO] Issue147 AC05 | Time: none | Risk: manufacturing BOM also signals assembly use.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Production BOM Header");
        UsageRecord.Insert(false);
        InsertSetupFromUsage(InventorySetup);
        Assert.IsTrue(InventorySetup.Assembly, 'Production BOM is an accepted usage signal.');
    end;

    [Test]
    procedure Scenario_AC03_NewCompanyTags_PreserveLaterOptOut()
    var
        InventorySetup: Record "Inventory Setup ori";
        Location: Record Location;
        InventoryUpgrade: Codeunit "Inventory Upgrade ori";
        UpgradeTag: Codeunit "Upgrade Tag";
        UpgradeTagLibrary: Codeunit "Upgrade Tag Library";
        PerCompanyUpgradeTags: List of [Code[250]];
    begin
        // [SCENARIO] Issue147 AC03 / review F2 | Time: none | Risk: a later upgrade must preserve a new company's opt-out.
        // [GIVEN] The same tag-registration path used by company initialization.
        ClearUsage();
        UpgradeTagLibrary.DeleteUpgradeTag(InventoryUpgrade.GetDomainUsageTag(), CopyStr(CompanyName(), 1, 30));
        UpgradeTag.GetPerCompanyUpgradeTags(PerCompanyUpgradeTags);
        Assert.IsTrue(PerCompanyUpgradeTags.Contains(InventoryUpgrade.GetDomainUsageTag()), 'New companies must register the domain migration tag.');
        UpgradeTag.SetAllUpgradeTags();
        Assert.IsTrue(UpgradeTag.HasUpgradeTag(InventoryUpgrade.GetDomainUsageTag()), 'Company initialization must persist the tag.');
        Location.Code := 'XDOMAIN';
        Location.Insert(false);
        InsertSetupFromUsage(InventorySetup);
        Assert.IsTrue(InventorySetup.Reclassification, 'New rows still derive defaults from usage.');
        InventorySetup.Reclassification := false;
        InventorySetup.Modify(true);
        // [WHEN] The next app upgrade calls the tagged migration.
        InventoryUpgrade.EnableUsedDomains();
        // [THEN] A deliberate opt-out made after company initialization survives.
        InventorySetup.Get();
        Assert.IsFalse(InventorySetup.Reclassification, 'The next upgrade must not repeat the migration for a new company.');
    end;

    [Test]
    procedure Scenario_AC05_LocationUsage_AvoidsLedgerScan()
    var
        InventorySetup: Record "Inventory Setup ori";
        Location: Record Location;
        SetupRecord: RecordRef;
        DomainField: FieldRef;
        EntryNo: Integer;
        FieldNo: Integer;
        BeforeRowsRead: BigInteger;
        RowsRead: BigInteger;
        ExcessiveReadsErr: Label 'Expected bounded existence reads, but read %1 SQL rows.', Comment = '%1 = number of SQL rows read', Locked = true;
    begin
        // [SCENARIO] Issue147 AC05 / review F1 | Time: no timing threshold | Risk: eager OR scans a large ledger during upgrade.
        // [GIVEN] A Location already proves usage and 1000 ledger entries provide no additional location.
        ClearUsage();
        Location.Code := 'XDOMAIN';
        Location.Insert(false);
        for EntryNo := 1 to 1000 do
            InsertLedgerLocation(EntryNo, 'XITEM', 'XDOMAIN');
        SetupRecord.GetTable(InventorySetup);
        for FieldNo := 10 to 28 do begin
            DomainField := SetupRecord.Field(FieldNo);
            DomainField.Value := true;
        end;
        SetupRecord.SetTable(InventorySetup);
        InventorySetup.Reclassification := false;
        // [WHEN] Only Reclassification needs evaluation, as on an existing mostly enabled setup.
        BeforeRowsRead := SessionInformation.SqlRowsRead();
        Assert.IsTrue(InventorySetup.EnableDomainsInUse(), 'Location usage must enable the remaining domain.');
        RowsRead := SessionInformation.SqlRowsRead() - BeforeRowsRead;
        // [THEN] The result is correct without reading the 1000 ledger rows.
        Assert.IsTrue(InventorySetup.Reclassification, 'An existing Location enables reclassification.');
        Assert.IsTrue(RowsRead < 100, StrSubstNo(ExcessiveReadsErr, RowsRead));
    end;

    [Test]
    procedure Scenario_AC05_LedgerLocationsForSameItem_EnableReclass()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: none | Risk: the last-resort ledger signal must remain supported.
        // [GIVEN] No Location, Bin Content or Warehouse Entry; one item has ledger entries at two locations.
        ClearUsage();
        InsertLedgerLocation(1, 'XITEM', 'XLOC1');
        InsertLedgerLocation(2, 'XITEM', 'XLOC2');
        // [WHEN] A setup row is created.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] The fallback enables Reclassification.
        Assert.IsTrue(InventorySetup.Reclassification, 'Multiple ledger locations for the same item enable reclassification.');
    end;

    [Test]
    procedure Scenario_AC05_LedgerLocationsForDifferentItems_StayOff()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: none | Risk: do not combine locations from unrelated items.
        // [GIVEN] Two items each use only one location, with no other reclassification signal.
        ClearUsage();
        InsertLedgerLocation(1, 'XITEM1', 'XLOC1');
        InsertLedgerLocation(2, 'XITEM2', 'XLOC2');
        // [WHEN] A setup row is created.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Distinct locations across items do not enable Reclassification.
        Assert.IsFalse(InventorySetup.Reclassification, 'Multiple locations must belong to the same item.');
    end;

    [Test]
    procedure Scenario_AC05_BlankLedgerLocations_AvoidsLedgerScan()
    var
        InventorySetup: Record "Inventory Setup ori";
        SetupRecord: RecordRef;
        DomainField: FieldRef;
        EntryNo: Integer;
        FieldNo: Integer;
        BeforeRowsRead: BigInteger;
        RowsRead: BigInteger;
        ExcessiveReadsErr: Label 'Expected bounded existence reads, but read %1 SQL rows.', Comment = '%1 = number of SQL rows read', Locked = true;
    begin
        // [SCENARIO] Issue147 AC05 | Time: no timing threshold | Risk: blank-location ledgers must not be materialized in AL.
        // [GIVEN] No location signal and 1000 ledger entries at the blank location.
        ClearUsage();
        for EntryNo := 1 to 1000 do
            InsertLedgerLocation(EntryNo, 'XITEM', '');
        SetupRecord.GetTable(InventorySetup);
        for FieldNo := 10 to 28 do begin
            DomainField := SetupRecord.Field(FieldNo);
            DomainField.Value := true;
        end;
        SetupRecord.SetTable(InventorySetup);
        InventorySetup.Reclassification := false;
        // [WHEN] Evaluate the remaining domain directly; setup-page trigger wiring is covered separately.
        BeforeRowsRead := SessionInformation.SqlRowsRead();
        Assert.IsFalse(InventorySetup.EnableDomainsInUse(), 'A blank-only ledger must not change any domain.');
        RowsRead := SessionInformation.SqlRowsRead() - BeforeRowsRead;
        // [THEN] Reclassification stays off without fetching all ledger rows into AL.
        Assert.IsFalse(InventorySetup.Reclassification, 'One blank location is not multiple locations.');
        Assert.IsTrue(RowsRead < 100, StrSubstNo(ExcessiveReadsErr, RowsRead));
    end;

    [Test]
    procedure Scenario_AC05_BlankAndNamedLedgerLocations_EnableReclass()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC05 | Time: none | Risk: the existence filter must not remove blank locations from comparison.
        // [GIVEN] One item uses a blank and a named location, with no Location/Bin/Warehouse rows.
        ClearUsage();
        InsertLedgerLocation(1, 'XITEM', '');
        InsertLedgerLocation(2, 'XITEM', 'XLOC');
        // [WHEN] The legacy usage rules run on a new row.
        InsertSetupFromUsage(InventorySetup);
        // [THEN] Blank and named locations still count as two locations for the same item.
        InventorySetup.Get();
        Assert.IsTrue(InventorySetup.Reclassification, 'The blank location must participate in the comparison.');
    end;

    local procedure InsertLedgerLocation(EntryNo: Integer; ItemNo: Code[20]; LocationCode: Code[10])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry."Entry No." := EntryNo;
        ItemLedgerEntry."Item No." := ItemNo;
        ItemLedgerEntry."Location Code" := LocationCode;
        ItemLedgerEntry.Insert(false);
    end;

    local procedure AssertDomain(InventorySetup: Record "Inventory Setup ori"; FieldNo: Integer; Expected: Boolean)
    var
        SetupRecord: RecordRef;
        DomainField: FieldRef;
    begin
        SetupRecord.GetTable(InventorySetup);
        DomainField := SetupRecord.Field(FieldNo);
        Assert.AreEqual(Expected, DomainField.Value, 'Domain usage default.');
    end;

    local procedure PrepareUsage(var UsageRecord: RecordRef; TableNo: Integer)
    var
        KeyField: FieldRef;
        PrimaryKey: KeyRef;
        FieldIndex: Integer;
    begin
        UsageRecord.Open(TableNo);
        UsageRecord.Init();
        PrimaryKey := UsageRecord.KeyIndex(1);
        for FieldIndex := 1 to PrimaryKey.FieldCount() do begin
            KeyField := PrimaryKey.FieldIndex(FieldIndex);
            case KeyField.Type of
                FieldType::Code, FieldType::Text:
                    KeyField.Value := CopyStr('ZZTEST', 1, KeyField.Length);
                FieldType::Integer:
                    KeyField.Value := 1;
                FieldType::Date:
                    KeyField.Value := WorkDate();
            end;
        end;
    end;

    local procedure SetField(var UsageRecord: RecordRef; FieldName: Text; FieldValue: Variant)
    var
        UsageField: FieldRef;
        FieldIndex: Integer;
    begin
        for FieldIndex := 1 to UsageRecord.FieldCount() do begin
            UsageField := UsageRecord.FieldIndex(FieldIndex);
            if UsageField.Name = FieldName then begin
                UsageField.Value := FieldValue;
                exit;
            end;
        end;
        Error('Fixture field not found: %1', FieldName);
    end;

    /// <summary>Creates the setup row (all switches off) and then applies the legacy usage rules, which the upgrade tags still run on rows that exist.</summary>
    local procedure InsertSetupFromUsage(var InventorySetup: Record "Inventory Setup ori")
    begin
        InventorySetup.InsertIfNotExists();
        InventorySetup.Get();
        if InventorySetup.EnableDomainsInUse() then
            InventorySetup.Modify(true);
    end;

    local procedure ClearUsage()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // Only the individually owned verification company; Test Runner rolls the transaction back.
        // No consent, licensing, HTTP setting or backend data is read or written.
        InventorySetup.DeleteAll(false);
        ClearTable(Database::"Item Attribute");
        ClearTable(Database::"Location");
        ClearTable(Database::"Transfer Header");
        ClearTable(Database::"Transfer Route");
        ClearTable(Database::"BOM Component");
        ClearTable(Database::"Assembly Header");
        ClearTable(Database::"Production BOM Header");
        ClearTable(Database::"Reservation Entry");
        ClearTable(Database::"Item Tracking Code");
        ClearTable(Database::"Item");
        ClearTable(Database::"Item Ledger Entry");
        ClearTable(Database::"Tracking Specification");
        ClearTable(Database::"Phys. Invt. Record Header");
        ClearTable(Database::"Phys. Inventory Ledger Entry");
        ClearTable(Database::"Value Entry");
        ClearTable(Database::"Inventory Adjmt. Entry (Order)");
        ClearTable(Database::"Bin Content");
        ClearTable(Database::"Warehouse Entry");
        ClearTable(Database::"Item Application Entry");
        ClearTable(Database::"Inventory Period");
        ClearTable(Database::"Price List Line");
        ClearTable(Database::"Item Reference");
        ClearTable(Database::"Item Substitution");
        ClearTable(Database::"Item Charge");
        ClearTable(Database::"Item Category");
        ClearTable(Database::"Purchase Header");
        ClearTable(Database::"Nonstock Item");
        ClearTable(Database::"Requisition Line");
        ClearTable(Database::"Requisition Wksh. Name");
        ClearTable(Database::"Req. Wksh. Template");
    end;

    local procedure ClearTable(TableNo: Integer)
    var
        UsageRecord: RecordRef;
    begin
        UsageRecord.Open(TableNo);
        UsageRecord.DeleteAll(false);
    end;
}
