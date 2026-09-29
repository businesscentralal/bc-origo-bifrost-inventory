namespace Origo.Bifrost.Inventory;

/// <summary>
/// Grants Bifrost Inventory posting.
/// Assign explicitly. Not included in BIFROST InvRead ori or BIFROST InvWrite ori.
/// BIFROST ItemPost ori does not cover Inventory.TransferOrder.Post or Inventory.AssemblyOrder.Post.
/// </summary>
permissionset 70013444 "BIFROST InvPost ori"
{
    Assignable = true;
    Caption = 'Inv. Posting Gate', MaxLength = 30, Comment = 'is-IS=Bókunarhlið birgða';

    Permissions =
        tabledata "Inv. Posting ori" = RIMD;
}
