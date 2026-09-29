namespace Origo.Bifrost.Inventory;

/// <summary>
/// Permission token for BIFROST InvPost ori.
/// No records are stored. WritePermission() on this table is the inventory posting gate
/// for Inventory.TransferOrder.Post and Inventory.AssemblyOrder.Post.
/// </summary>
table 70013442 "Inv. Posting ori"
{
    Extensible = false;
    Access = Internal;
    Caption = 'BIFROST InvPost ori', Comment = 'is-IS=Bifröst bókun birgða';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
