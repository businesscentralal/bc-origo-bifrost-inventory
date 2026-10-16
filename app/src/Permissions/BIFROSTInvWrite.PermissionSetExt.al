namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;
using Microsoft.Inventory.Item.Attribute;

/// <summary>
/// Extends Foundation <c>BIFROST Full ori</c> with write access for Item Attribute message types.
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
        codeunit "Inventory Native Journal ori" = X,
        codeunit "Inv Native Journal Process ori" = X,
        codeunit "Phys. Inv. Calc Impl ori" = X,
        codeunit "Phys. Invt. Record Impl ori" = X,
        codeunit "Phys. Invt. Post Impl ori" = X,
        codeunit "Inventory Revaluation ori" = X,
        codeunit "Inv Reval Post Process ori" = X,
        codeunit "Revaluation Post Impl ori" = X,
        codeunit "Reval Preview Impl ori" = X,
        codeunit "Inventory Cost Write ori" = X,
        codeunit "Inventory Cost Write Proc. ori" = X,
        codeunit "Cost Update Impl ori" = X,
        codeunit "Inventory Price Write ori" = X,
        codeunit "Inv. Price Write Process ori" = X,
        codeunit "Price Update Impl ori" = X,
        codeunit "Inventory Cost Data Guard ori" = X,
        codeunit "Inventory Domain Gate ori" = X,
        codeunit "Inv. Posting Gate ori" = X;
}
