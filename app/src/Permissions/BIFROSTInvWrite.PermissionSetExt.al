namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Extends Foundation <c>BIFROST Full ori</c> with write access for the Inventory message types.
/// Standard-table data for the item reference, availability, item charge, item category, auto-reserve
/// and order tracking types comes from the caller's own Business Central permissions; IsEnabled and Execute check it.
/// </summary>
permissionsetextension 10036916 "BIFROST InvWrite ori" extends "BIFROST Full ori"
{
    IncludedPermissionSets = "BIFROST InvAttrWrite ori";

    Permissions =
        tabledata "Inventory Setup ori" = R,
        codeunit "Item Attribute Get Impl ori" = X,
        codeunit "Item Attribute Create Impl ori" = X,
        codeunit "Item Attr. Create Process ori" = X,
        codeunit "Item Attribute Update Impl ori" = X,
        codeunit "Item Attr. Update Process ori" = X,
        codeunit "Item AttrDef Create Impl ori" = X,
        codeunit "Item AttrDef Create Proc ori" = X,
        codeunit "Item Attribute Resolve ori" = X,
        codeunit "Item Attr. Data Restrict ori" = X,
        codeunit "Inventory Registration ori" = X,
        codeunit "Inventory Install ori" = X,
        codeunit "Inventory Upgrade ori" = X,
        codeunit "Transfer Order Create Impl ori" = X,
        codeunit "Transfer Order Post Impl ori" = X,
        codeunit "Transf. Order Release Impl ori" = X,
        codeunit "Transfer Order Reopen Impl ori" = X,
        codeunit "Transf. Order Reopen Proc. ori" = X,
        codeunit "Transfer Post Subscriber ori" = X,
        codeunit "Transf Doc Prev. Post Impl ori" = X,
        codeunit "Transfer Order Stats Impl ori" = X,
        codeunit "Assembly Order Create Impl ori" = X,
        codeunit "Assembly Order Post Impl ori" = X,
        codeunit "Asm. Order Release Impl ori" = X,
        codeunit "Assembly Order Reopen Impl ori" = X,
        codeunit "Asm. Order Reopen Process ori" = X,
        codeunit "Asm. Doc Prev. Post Impl ori" = X,
        codeunit "Asm. Order RefreshLn Impl ori" = X,
        codeunit "Asm. Order Statistics Impl ori" = X,
        codeunit "Inventory Contract Parts ori" = X,
        codeunit "Item Ref. Resolve Impl ori" = X,
        codeunit "Avail. By Period Impl ori" = X,
        codeunit "Item Charge Assign Impl ori" = X,
        codeunit "Item Charge Assign Proc ori" = X,
        codeunit "Item Charge Get Impl ori" = X,
        codeunit "Item Charge Restrict ori" = X,
        codeunit "Item Category Get Impl ori" = X,
        codeunit "Item Category Set Impl ori" = X,
        codeunit "Item Category Set Proc ori" = X,
        codeunit "Item Category Restrict ori" = X,
        codeunit "Reserv. AutoReserve Impl ori" = X,
        codeunit "Reserv. AutoReserve Proc ori" = X,
        codeunit "Order Tracking Get Impl ori" = X,
        codeunit "Order Tracking Transfer ori" = X;
}
