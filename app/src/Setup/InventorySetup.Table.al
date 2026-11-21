namespace Origo.Bifrost.Inventory;

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

/// <summary>
/// Per-company switches for Bifrost Inventory domains. Every switch is off by default and a missing row counts as every domain off. Suggest Setup turns on the domains the company can use.
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
        field(25; "Item Substitution"; Boolean)
        {
            Caption = 'Item Substitution', Comment = 'is-IS=Vöruskipti';
            ToolTip = 'Enable reading item substitutions and their on-hand inventory.', Comment = 'is-IS=Virkja lestur vöruskipta og núverandi birgða þeirra.';
        }
        field(26; "Purchase Returns"; Boolean)
        {
            Caption = 'Purchase Returns', Comment = 'is-IS=Innkaupaskil';
        }
        field(28; "Catalog Items"; Boolean)
        {
            Caption = 'Catalog Items', Comment = 'is-IS=Vörulistavörur';
        }
        field(27; Planning; Boolean)
        {
            Caption = 'Planning', Comment = 'is-IS=Áætlun';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>Creates the company setup with every domain switch off. Suggest Setup turns on the domains the company can use.</summary>
    procedure InsertIfNotExists()
    begin
        if Get() then
            exit;
        Init();
        Insert(true);
    end;

    /// <summary>Reads a domain switch; an absent setup row counts as every domain off.</summary>
    procedure IsDomainEnabled(Domain: Enum "Inventory Domain ori"): Boolean
    begin
        if not Get() then
            exit(false);
        exit(IsSwitchOn(Domain));
    end;

    /// <summary>Reads a domain switch on the record in memory, without reading the row.</summary>
    internal procedure IsSwitchOn(Domain: Enum "Inventory Domain ori"): Boolean
    begin
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
            Domain::ItemSubstitution:
                exit("Item Substitution");
            Domain::PurchaseReturns:
                exit("Purchase Returns");
            Domain::CatalogItems:
                exit("Catalog Items");
            Domain::Planning:
                exit(Planning);
        end;
        exit(false);
    end;

    /// <summary>Sets one domain switch without writing the row.</summary>
    internal procedure SetDomainEnabled(Domain: Enum "Inventory Domain ori"; Value: Boolean)
    begin
        case Domain of
            Domain::Attributes:
                Attributes := Value;
            Domain::TransferOrders:
                "Transfer Orders" := Value;
            Domain::Assembly:
                Assembly := Value;
            Domain::Reservations:
                Reservations := Value;
            Domain::ItemTracking:
                "Item Tracking" := Value;
            Domain::PhysInventory:
                "Phys. Inventory" := Value;
            Domain::Costing:
                Costing := Value;
            Domain::Reclassification:
                Reclassification := Value;
            Domain::ItemApplication:
                "Item Application" := Value;
            Domain::InventoryPeriod:
                "Inventory Period" := Value;
            Domain::ItemPrice:
                "Item Price" := Value;
            Domain::ItemReference:
                "Item Reference" := Value;
            Domain::Availability:
                Availability := Value;
            Domain::ItemCharge:
                "Item Charge" := Value;
            Domain::ItemCategory:
                "Item Category" := Value;
            Domain::ItemSubstitution:
                "Item Substitution" := Value;
            Domain::PurchaseReturns:
                "Purchase Returns" := Value;
            Domain::CatalogItems:
                "Catalog Items" := Value;
            Domain::Planning:
                Planning := Value;
        end;
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
        if not "Item Substitution" then
            if HasRecords(Database::"Item Substitution") then begin
                "Item Substitution" := true;
                Changed := true;
            end;
        if not "Purchase Returns" then
            if HasPurchaseReturnUsage() then begin
                "Purchase Returns" := true;
                Changed := true;
            end;
        if EnableCatalogItemsInUse() then
            Changed := true;
        if not Planning then
            if HasPlanningUsage() then begin
                Planning := true;
                Changed := true;
            end;
        exit(Changed);
    end;

    /// <summary>
    /// Raises only the Catalog Items switch when the company has catalog items, without writing the row.
    /// Used by the catalog items upgrade so other switches an administrator turned off stay off.
    /// </summary>
    internal procedure EnableCatalogItemsInUse(): Boolean
    begin
        if "Catalog Items" then
            exit(false);
        if not HasRecords(Database::"Nonstock Item") then
            exit(false);
        "Catalog Items" := true;
        exit(true);
    end;

    /// <summary>Turns on Planning only, when a planning worksheet template exists. Other switches stay as they are.</summary>
    internal procedure EnablePlanningFromUsage(): Boolean
    begin
        if Planning then
            exit(false);
        if not HasPlanningUsage() then
            exit(false);
        Planning := true;
        exit(true);
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
        ItemLedgerEntry.SetFilter("Location Code", '<>%1', '');
        if ItemLedgerEntry.IsEmpty() then
            exit(false);
        ItemLedgerEntry.SetRange("Location Code");
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

    local procedure HasPurchaseReturnUsage(): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.SetFilter("Document Type", '%1|%2', PurchaseHeader."Document Type"::"Return Order", PurchaseHeader."Document Type"::"Credit Memo");
        if not PurchaseHeader.ReadPermission() then
            exit(false);
        exit(not PurchaseHeader.IsEmpty());
    end;

    local procedure HasPlanningUsage(): Boolean
    var
        ReqWkshTemplate: Record "Req. Wksh. Template";
    begin
        ReqWkshTemplate.SetRange(Type, ReqWkshTemplate.Type::Planning);
        if not ReqWkshTemplate.ReadPermission() then
            exit(false);
        exit(not ReqWkshTemplate.IsEmpty());
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
