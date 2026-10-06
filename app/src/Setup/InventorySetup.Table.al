namespace Origo.Bifrost.Inventory;

/// <summary>
/// Per-company switches for inventory domains. A missing row means every domain is on.
/// </summary>
table 70013451 "Inventory Setup ori"
{
    Caption = 'Inventory Setup', Locked = true;
    DataClassification = CustomerContent;
    Extensible = false;
    Access = Internal;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Locked = true;
            DataClassification = SystemMetadata;
        }
        field(10; "Attributes Enabled"; Boolean)
        {
            Caption = 'Attributes', Comment = 'is-IS=Eiginleikar';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(11; "Transfer Orders Enabled"; Boolean)
        {
            Caption = 'Transfer Orders', Comment = 'is-IS=Flutningspantanir';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(12; "Assembly Enabled"; Boolean)
        {
            Caption = 'Assembly', Comment = 'is-IS=Samsetning';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(13; "Reservations Enabled"; Boolean)
        {
            Caption = 'Reservations', Comment = 'is-IS=Frátektir';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(14; "Item Tracking Enabled"; Boolean)
        {
            Caption = 'Item Tracking', Comment = 'is-IS=Vörurakning';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(15; "Phys. Inventory Enabled"; Boolean)
        {
            Caption = 'Physical Inventory', Comment = 'is-IS=Birgðatalning';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(16; "Costing Enabled"; Boolean)
        {
            Caption = 'Costing', Comment = 'is-IS=Kostnaður';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(17; "Reclassification Enabled"; Boolean)
        {
            Caption = 'Reclassification', Comment = 'is-IS=Endurflokkun';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(18; "Item Application Enabled"; Boolean)
        {
            Caption = 'Item Application', Comment = 'is-IS=Vörujöfnun';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(19; "Inventory Period Enabled"; Boolean)
        {
            Caption = 'Inventory Period', Comment = 'is-IS=Birgðatímabil';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(20; "Item Price Enabled"; Boolean)
        {
            Caption = 'Item Price', Comment = 'is-IS=Vöruverð';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// True when the domain is on. A missing setup row counts as on.
    /// </summary>
    procedure IsDomainEnabled(Domain: Enum "Inventory Domain ori"): Boolean
    begin
        if not Get() then
            exit(true);
        case Domain of
            Domain::Attributes:
                exit("Attributes Enabled");
            Domain::TransferOrders:
                exit("Transfer Orders Enabled");
            Domain::Assembly:
                exit("Assembly Enabled");
            Domain::Reservations:
                exit("Reservations Enabled");
            Domain::ItemTracking:
                exit("Item Tracking Enabled");
            Domain::PhysInventory:
                exit("Phys. Inventory Enabled");
            Domain::Costing:
                exit("Costing Enabled");
            Domain::Reclassification:
                exit("Reclassification Enabled");
            Domain::ItemApplication:
                exit("Item Application Enabled");
            Domain::InventoryPeriod:
                exit("Inventory Period Enabled");
            Domain::ItemPrice:
                exit("Item Price Enabled");
        end;
        exit(true);
    end;
}
