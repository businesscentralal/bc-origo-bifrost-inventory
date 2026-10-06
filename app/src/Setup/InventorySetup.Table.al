namespace Origo.Bifrost.Inventory;

/// <summary>
/// Per-company switches for Bifrost Inventory domains. A missing row counts as every domain on.
/// </summary>
table 70013451 "Inventory Setup ori"
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
            InitValue = true;
        }
        field(11; "Transfer Orders"; Boolean)
        {
            Caption = 'Transfer Orders', Comment = 'is-IS=Flutningspantanir';
            InitValue = true;
        }
        field(12; Assembly; Boolean)
        {
            Caption = 'Assembly', Comment = 'is-IS=Samsetning';
            InitValue = true;
        }
        field(13; Reservations; Boolean)
        {
            Caption = 'Reservations', Comment = 'is-IS=Frátektir';
            InitValue = true;
        }
        field(14; "Item Tracking"; Boolean)
        {
            Caption = 'Item Tracking', Comment = 'is-IS=Vörurakning';
            InitValue = true;
        }
        field(15; "Phys. Inventory"; Boolean)
        {
            Caption = 'Physical Inventory', Comment = 'is-IS=Birgðatalning';
            InitValue = true;
        }
        field(16; Costing; Boolean)
        {
            Caption = 'Costing', Comment = 'is-IS=Kostnaður';
            InitValue = true;
        }
        field(17; Reclassification; Boolean)
        {
            Caption = 'Reclassification', Comment = 'is-IS=Endurflokkun';
        }
        field(18; "Item Application"; Boolean)
        {
            Caption = 'Item Application', Comment = 'is-IS=Vörujöfnun';
            InitValue = true;
        }
        field(19; "Inventory Period"; Boolean)
        {
            Caption = 'Inventory Period', Comment = 'is-IS=Birgðatímabil';
            InitValue = true;
        }
        field(20; "Item Price"; Boolean)
        {
            Caption = 'Item Price', Comment = 'is-IS=Vöruverð';
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

    procedure InsertIfNotExists()
    begin
        if Get() then
            exit;
        Init();
        Insert(true);
    end;

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
        end;
        exit(true);
    end;
}
