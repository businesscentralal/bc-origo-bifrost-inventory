namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Counting.Recording;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
        // [THEN] The domain is not enabled without evidence.
        AssertDomain(InventorySetup, 24, false);
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
        InventorySetup.InsertIfNotExists();
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
    procedure Scenario_AC02_MissingSetup_StaysAbsentAndEnabled()
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
        Assert.IsTrue(InventorySetup.IsDomainEnabled(Enum::"Inventory Domain ori"::ItemReference), 'Absent means enabled.');
    end;

    [Test]
    procedure Scenario_AC02_SetupPage_CreatesUsageDefaults()
    var
        InventorySetup: Record "Inventory Setup ori";
        UsageRecord: RecordRef;
        SetupPage: TestPage "Inventory Setup ori";
    begin
        // [SCENARIO] Issue147 AC02 | Time: none | Risk: prove actual page trigger wiring.
        ClearUsage();
        PrepareUsage(UsageRecord, Database::"Item Charge");
        UsageRecord.Insert(false);
        SetupPage.OpenEdit();
        SetupPage.ItemCharge.AssertEquals(true);
        SetupPage.Close();
        InventorySetup.Get();
        Assert.IsTrue(InventorySetup."Item Charge", 'The UI persists usage defaults.');
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
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
        InventorySetup.InsertIfNotExists();
        Assert.IsTrue(InventorySetup.Assembly, 'Production BOM is an accepted usage signal.');
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
        ClearTable(Database::"Item Charge");
        ClearTable(Database::"Item Category");
    end;

    local procedure ClearTable(TableNo: Integer)
    var
        UsageRecord: RecordRef;
    begin
        UsageRecord.Open(TableNo);
        UsageRecord.DeleteAll(false);
    end;
}
