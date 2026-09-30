namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Extends Bifrost Foundation <c>Message Type ori</c> with Item Attribute message types.
/// Captions are Locked because message identifiers are part of the public wire contract.
/// </summary>
enumextension 10036892 "MsgType.EnumExt ori" extends "Message Type ori"
{
    /// <summary>Reads attribute definitions and assigned values for one or more items.</summary>
    value(10036893; "Item.Attribute.Get")
    {
        Caption = 'Item.Attribute.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Get Impl ori", "Msg Discovery ori" = "Item Attribute Get Impl ori", "Msg Contract ori" = "Item Attribute Get Impl ori";
    }
    /// <summary>Assigns an attribute value to an item; idempotent when the same value already exists.</summary>
    value(10036894; "Item.Attribute.Create")
    {
        Caption = 'Item.Attribute.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Create Impl ori", "Msg Discovery ori" = "Item Attribute Create Impl ori", "Msg Contract ori" = "Item Attribute Create Impl ori";
    }
    /// <summary>Updates an existing item attribute mapping and returns before/after values.</summary>
    value(10036895; "Item.Attribute.Update")
    {
        Caption = 'Item.Attribute.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Update Impl ori", "Msg Discovery ori" = "Item Attribute Update Impl ori", "Msg Contract ori" = "Item Attribute Update Impl ori";
    }
    /// <summary>Creates an attribute definition and optional option values, independent of any item.</summary>
    value(10036896; "Item.AttributeDefinition.Create")
    {
        Caption = 'Item.AttributeDefinition.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item AttrDef Create Impl ori", "Msg Discovery ori" = "Item AttrDef Create Impl ori", "Msg Contract ori" = "Item AttrDef Create Impl ori";
    }

    /// <summary>
    /// Creates a new transfer order header with from/to locations, posting date, shipment/receipt dates and optional direct transfer.
    /// </summary>
    value(70013400; "Inventory.TransferOrder.Create")
    {
        Caption = 'Inventory.TransferOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Create Impl ori", "Msg Discovery ori" = "Transfer Order Create Impl ori", "Msg Contract ori" = "Transfer Order Create Impl ori";
    }

    /// <summary>
    /// Releases an open transfer order so it can be processed and posted.
    /// </summary>
    value(70013401; "Inventory.TransferOrder.Release")
    {
        Caption = 'Inventory.TransferOrder.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Transf. Order Release Impl ori", "Msg Discovery ori" = "Transf. Order Release Impl ori", "Msg Contract ori" = "Transf. Order Release Impl ori";
    }

    /// <summary>
    /// Reopens a released transfer order so it can be edited again.
    /// </summary>
    value(70013402; "Inventory.TransferOrder.Reopen")
    {
        Caption = 'Inventory.TransferOrder.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Reopen Impl ori", "Msg Discovery ori" = "Transfer Order Reopen Impl ori", "Msg Contract ori" = "Transfer Order Reopen Impl ori";
    }

    /// <summary>
    /// Posts a transfer order (ship, receive, or ship+receive for direct transfers).
    /// </summary>
    value(70013403; "Inventory.TransferOrder.Post")
    {
        Caption = 'Inventory.TransferOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Post Impl ori", "Msg Discovery ori" = "Transfer Order Post Impl ori", "Msg Contract ori" = "Transfer Order Post Impl ori";
    }

    /// <summary>
    /// Performs a preview-post for a transfer order without committing any data, returning predicted documents and ledger entries.
    /// </summary>
    value(70013404; "Inventory.TransferOrder.PreviewPost")
    {
        Caption = 'Inventory.TransferOrder.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Transf Doc Prev. Post Impl ori", "Msg Discovery ori" = "Transf Doc Prev. Post Impl ori", "Msg Contract ori" = "Transf Doc Prev. Post Impl ori";
    }

    /// <summary>
    /// Returns transfer order line totals (Quantity, Parcels, Net/Gross Weight, Volume).
    /// </summary>
    value(70013405; "Inventory.TransferOrder.Statistics")
    {
        Caption = 'Inventory.TransferOrder.Statistics', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Stats Impl ori", "Msg Discovery ori" = "Transfer Order Stats Impl ori", "Msg Contract ori" = "Transfer Order Stats Impl ori";
    }

    /// <summary>
    /// Creates a new assembly order header (Assembly Header with Document Type = Order)
    /// for a parent item, optionally refreshing component lines from the item's BOM.
    /// </summary>
    value(70013406; "Inventory.AssemblyOrder.Create")
    {
        Caption = 'Inventory.AssemblyOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Create Impl ori", "Msg Discovery ori" = "Assembly Order Create Impl ori", "Msg Contract ori" = "Assembly Order Create Impl ori";
    }

    /// <summary>
    /// Refreshes the component lines of an assembly order from the parent item's BOM (RefreshBOM).
    /// </summary>
    value(70013407; "Inventory.AssemblyOrder.RefreshLines")
    {
        Caption = 'Inventory.AssemblyOrder.RefreshLines', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order RefreshLn Impl ori", "Msg Discovery ori" = "Asm. Order RefreshLn Impl ori", "Msg Contract ori" = "Asm. Order RefreshLn Impl ori";
    }

    /// <summary>
    /// Releases an open assembly order so it can be posted (status Open -> Released).
    /// </summary>
    value(70013408; "Inventory.AssemblyOrder.Release")
    {
        Caption = 'Inventory.AssemblyOrder.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order Release Impl ori", "Msg Discovery ori" = "Asm. Order Release Impl ori", "Msg Contract ori" = "Asm. Order Release Impl ori";
    }

    /// <summary>
    /// Reopens a released assembly order so it can be edited again (status Released -> Open).
    /// </summary>
    value(70013409; "Inventory.AssemblyOrder.Reopen")
    {
        Caption = 'Inventory.AssemblyOrder.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Reopen Impl ori", "Msg Discovery ori" = "Assembly Order Reopen Impl ori", "Msg Contract ori" = "Assembly Order Reopen Impl ori";
    }

    /// <summary>
    /// Posts an assembly order via codeunit 900 "Assembly-Post" and returns the posted document number.
    /// </summary>
    value(70013410; "Inventory.AssemblyOrder.Post")
    {
        Caption = 'Inventory.AssemblyOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Post Impl ori", "Msg Discovery ori" = "Assembly Order Post Impl ori", "Msg Contract ori" = "Assembly Order Post Impl ori";
    }

    /// <summary>
    /// Performs a preview-post for an assembly order without committing any data, returning predicted documents and ledger entries.
    /// </summary>
    value(70013411; "Inventory.AssemblyOrder.PreviewPost")
    {
        Caption = 'Inventory.AssemblyOrder.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Doc Prev. Post Impl ori", "Msg Discovery ori" = "Asm. Doc Prev. Post Impl ori", "Msg Contract ori" = "Asm. Doc Prev. Post Impl ori";
    }

    /// <summary>
    /// Returns assembly order statistics: header info, line counts and cost breakdown (material, resource, overhead).
    /// </summary>
    value(70013412; "Inventory.AssemblyOrder.Statistics")
    {
        Caption = 'Inventory.AssemblyOrder.Statistics', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order Statistics Impl ori", "Msg Discovery ori" = "Asm. Order Statistics Impl ori", "Msg Contract ori" = "Asm. Order Statistics Impl ori";
    }
}
