namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;
using Microsoft.Inventory.Item.Attribute;

/// <summary>
/// Extends Foundation <c>BIFROST Full ori</c> with write access for Item Attribute message types.
/// </summary>
permissionsetextension 10036916 "BIFROST InvWrite ori" extends "BIFROST Full ori"
{
    Permissions =
        tabledata "Item Attribute" = RIMD,
        tabledata "Item Attribute Value" = RIMD,
        tabledata "Item Attribute Value Mapping" = RIMD,
        tabledata "Item Attr. Value Translation" = RIMD,
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
        codeunit "Asm. Order Statistics Impl ori" = X;
}
