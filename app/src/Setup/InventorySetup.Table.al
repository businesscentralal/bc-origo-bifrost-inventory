namespace Origo.Bifrost.Inventory;

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

/// <summary>
/// Per-company switches for Bifrost Inventory domains. A missing row counts as every domain on.
/// </summary>
table 10076836 "Inventory Setup ori"
{
    Access = Internal;
    Caption = 'Inventory Setup', Comment = 'is-IS=Uppsetning birgða';
    DataClassification = CustomerContent;
    Extensible = false;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
        field(10; Attributes; Boolean)
        {
            Caption = 'Attributes', Comment = 'is-IS=Eiginleikar';
        }
        field(11; "Transfer Orders"; Boolean)
        {
            Caption = 'Transfer Orders', Comment = 'is-IS=Flutningspantanir';
        }
        field(12; Assembly; Boolean)
        {
            Caption = 'Assembly', Comment = 'is-IS=Samsetning';
        }
        field(13; Reservations; Boolean)
        {
            Caption = 'Reservations', Comment = 'is-IS=Frátektir';
        }
        field(14; "Item Tracking"; Boolean)
        {
            Caption = 'Item Tracking', Comment = 'is-IS=Vörurakning';
        }
        field(15; "Phys. Inventory"; Boolean)
        {
            Caption = 'Physical Inventory', Comment = 'is-IS=Birgðatalning';
        }
        field(16; Costing; Boolean)
        {
            Caption = 'Costing', Comment = 'is-IS=Kostnaður';
        }
        field(17; Reclassification; Boolean)
        {
            Caption = 'Reclassification', Comment = 'is-IS=Endurflokkun';
        }
        field(18; "Item Application"; Boolean)
        {
            Caption = 'Item Application', Comment = 'is-IS=Vörujöfnun';
        }
        field(19; "Inventory Period"; Boolean)
        {
            Caption = 'Inventory Period', Comment = 'is-IS=Birgðatímabil';
        }
        field(20; "Item Price"; Boolean)
        {
            Caption = 'Item Price', Comment = 'is-IS=Vöruverð';
        }
        field(21; "Item Reference"; Boolean)
        {
            Caption = 'Item Reference', Comment = 'is-IS=Vörutilvísun';
        }
        field(22; Availability; Boolean)
        {
            Caption = 'Availability', Comment = 'is-IS=Framboð';
        }
        field(23; "Item Charge"; Boolean)
        {
            Caption = 'Item Charge', Comment = 'is-IS=Kostnaðarauki';
        }
        field(24; "Item Category"; Boolean)
        {
            Caption = 'Item Category', Comment = 'is-IS=Vöruflokkur';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        EnableDomainsInUse();
    end;

    /// <summary>Creates the company setup with defaults derived from existing inventory usage.</summary>
    procedure InsertIfNotExists()
    begin
        if Get() then
            exit;
        Init();
        Insert(true);
    end;

    /// <summary>Reads a domain switch; an absent setup row preserves the all-enabled contract.</summary>
    procedure IsDomainEnabled(Domain: Enum "Inventory Domain ori"): Boolean
    begin
        if not Get() then
            exit(true);
        case Domain of
            Domain::Attributes:
                exit(Attributes);
            Domain::TransferOrders:
                exit("Transfer Orders");
            Domain::Assembly:
                exit(Assembly);
            Domain::Reservations:
                exit(Reservations);
            Domain::ItemTracking:
                exit("Item Tracking");
            Domain::PhysInventory:
                exit("Phys. Inventory");
            Domain::Costing:
                exit(Costing);
            Domain::Reclassification:
                exit(Reclassification);
            Domain::ItemApplication:
                exit("Item Application");
            Domain::InventoryPeriod:
                exit("Inventory Period");
            Domain::ItemPrice:
                exit("Item Price");
            Domain::ItemReference:
                exit("Item Reference");
            Domain::Availability:
                exit(Availability);
            Domain::ItemCharge:
                exit("Item Charge");
            Domain::ItemCategory:
                exit("Item Category");
        end;
        exit(true);
    end;
    /// <summary>
    /// Raises domain switches supported by company data, without changing enabled switches or writing the row.
    /// Returns whether a switch changed so lifecycle callers can avoid a needless Modify.
    /// </summary>
    internal procedure EnableDomainsInUse(): Boolean
    var
        Changed: Boolean;
    begin
        if not Attributes then
            if HasRecords(Database::"Item Attribute") then begin
                Attributes := true;
                Changed := true;
            end;
        if not "Transfer Orders" then
            if HasTransferUsage() then begin
                "Transfer Orders" := true;
                Changed := true;
            end;
        if not Assembly then
            if HasAssemblyUsage() then begin
                Assembly := true;
                Changed := true;
            end;
        if not Reservations then
            if HasReservationUsage() then begin
                Reservations := true;
                Changed := true;
            end;
        if not "Item Tracking" then
            if HasTrackingUsage() then begin
                "Item Tracking" := true;
                Changed := true;
            end;
        if not "Phys. Inventory" then
            if HasPhysicalInventoryUsage() then begin
                "Phys. Inventory" := true;
                Changed := true;
            end;
        if not Costing then
            if HasCostingUsage() then begin
                Costing := true;
                Changed := true;
            end;
        if not Reclassification then
            if HasReclassificationUsage() then begin
                Reclassification := true;
                Changed := true;
            end;
        if not "Item Application" then
            if HasRecords(Database::"Item Application Entry") then begin
                "Item Application" := true;
                Changed := true;
            end;
        if not "Inventory Period" then
            if HasRecords(Database::"Inventory Period") then begin
                "Inventory Period" := true;
                Changed := true;
            end;
        if not "Item Price" then
            if HasItemPriceUsage() then begin
                "Item Price" := true;
                Changed := true;
            end;
        if not "Item Reference" then
            if HasRecords(Database::"Item Reference") then begin
                "Item Reference" := true;
                Changed := true;
            end;
        if not Availability then
            if HasAvailabilityUsage() then begin
                Availability := true;
                Changed := true;
            end;
        if not "Item Charge" then
            if HasRecords(Database::"Item Charge") then begin
                "Item Charge" := true;
                Changed := true;
            end;
        if not "Item Category" then
            if HasItemCategoryUsage() then begin
                "Item Category" := true;
                Changed := true;
            end;
        exit(Changed);
    end;

    local procedure HasRecords(TableNo: Integer): Boolean
    var
        UsageRecord: RecordRef;
    begin
        UsageRecord.Open(TableNo);
        UsageRecord.ReadIsolation := IsolationLevel::ReadCommitted;
        if not UsageRecord.ReadPermission() then
            exit(false);
        exit(not UsageRecord.IsEmpty());
    end;

    local procedure HasTransferUsage(): Boolean
    var
        Location: Record Location;
    begin
        Location.SetRange("Use As In-Transit", true);
        if Location.ReadPermission() then
            if not Location.IsEmpty() then
                exit(true);
        if HasRecords(Database::"Transfer Header") then
            exit(true);
        exit(HasRecords(Database::"Transfer Route"));
    end;

    local procedure HasAssemblyUsage(): Boolean
    begin
        if HasRecords(Database::"BOM Component") then
            exit(true);
        if HasRecords(Database::"Assembly Header") then
            exit(true);
        exit(HasRecords(Database::"Production BOM Header"));
    end;

    local procedure HasCostingUsage(): Boolean
    begin
        if HasRecords(Database::"Value Entry") then
            exit(true);
        exit(HasRecords(Database::"Inventory Adjmt. Entry (Order)"));
    end;

    local procedure HasReclassificationUsage(): Boolean
    begin
        // AL evaluates both operands of OR. Keep the ledger scan behind the cheaper signals.
        if HasRecords(Database::Location) then
            exit(true);
        if HasRecords(Database::"Bin Content") then
            exit(true);
        if HasRecords(Database::"Warehouse Entry") then
            exit(true);
        exit(HasMultipleLedgerLocations());
    end;

    local procedure HasAvailabilityUsage(): Boolean
    begin
        if HasRecords(Database::Item) then
            exit(true);
        exit(HasRecords(Database::"Item Ledger Entry"));
    end;

    local procedure HasReservationUsage(): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if not ReservationEntry.ReadPermission() then
            exit(false);
        exit(not ReservationEntry.IsEmpty());
    end;

    local procedure HasTrackingUsage(): Boolean
    var
        Item: Record Item;
        ReservationEntry: Record "Reservation Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        TrackingSpecification: Record "Tracking Specification";
    begin
        if HasRecords(Database::"Item Tracking Code") then
            exit(true);
        Item.SetFilter("Item Tracking Code", '<>%1', '');
        if Item.ReadPermission() then
            if not Item.IsEmpty() then
                exit(true);
        ReservationEntry.FilterGroup(-1);
        ReservationEntry.SetFilter("Lot No.", '<>%1', '');
        ReservationEntry.SetFilter("Serial No.", '<>%1', '');
        ReservationEntry.SetFilter("Package No.", '<>%1', '');
        if ReservationEntry.ReadPermission() then
            if not ReservationEntry.IsEmpty() then
                exit(true);
        ItemLedgerEntry.FilterGroup(-1);
        ItemLedgerEntry.SetFilter("Lot No.", '<>%1', '');
        ItemLedgerEntry.SetFilter("Serial No.", '<>%1', '');
        ItemLedgerEntry.SetFilter("Package No.", '<>%1', '');
        if ItemLedgerEntry.ReadPermission() then
            if not ItemLedgerEntry.IsEmpty() then
                exit(true);
        TrackingSpecification.FilterGroup(-1);
        TrackingSpecification.SetFilter("Lot No.", '<>%1', '');
        TrackingSpecification.SetFilter("Serial No.", '<>%1', '');
        TrackingSpecification.SetFilter("Package No.", '<>%1', '');
        if not TrackingSpecification.ReadPermission() then
            exit(false);
        exit(not TrackingSpecification.IsEmpty());
    end;

    local procedure HasPhysicalInventoryUsage(): Boolean
    var
        Item: Record Item;
    begin
        if HasRecords(Database::"Phys. Invt. Record Header") then
            exit(true);
        if HasRecords(Database::"Phys. Inventory Ledger Entry") then
            exit(true);
        Item.SetFilter("Phys Invt Counting Period Code", '<>%1', '');
        if not Item.ReadPermission() then
            exit(false);
        exit(not Item.IsEmpty());
    end;

    local procedure HasMultipleLedgerLocations(): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        FirstLocations: Dictionary of [Code[20], Code[10]];
        FirstLocation: Code[10];
    begin
        if not ItemLedgerEntry.ReadPermission() then
            exit(false);
        ItemLedgerEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        ItemLedgerEntry.SetLoadFields("Item No.", "Location Code");
        if ItemLedgerEntry.FindSet() then
            repeat
                if FirstLocations.Get(ItemLedgerEntry."Item No.", FirstLocation) then begin
                    if FirstLocation <> ItemLedgerEntry."Location Code" then
                        exit(true);
                end else
                    FirstLocations.Add(ItemLedgerEntry."Item No.", ItemLedgerEntry."Location Code");
            until ItemLedgerEntry.Next() = 0;
        exit(false);
    end;

    local procedure HasItemPriceUsage(): Boolean
    var
        PriceListLine: Record "Price List Line";
    begin
        PriceListLine.SetRange("Asset Type", PriceListLine."Asset Type"::Item);
        if not PriceListLine.ReadPermission() then
            exit(false);
        exit(not PriceListLine.IsEmpty());
    end;

    local procedure HasItemCategoryUsage(): Boolean
    var
        Item: Record Item;
    begin
        if HasRecords(Database::"Item Category") then
            exit(true);
        Item.SetFilter("Item Category Code", '<>%1', '');
        if not Item.ReadPermission() then
            exit(false);
        exit(not Item.IsEmpty());
    end;

}
