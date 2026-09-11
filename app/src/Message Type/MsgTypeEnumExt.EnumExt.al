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
        Implementation = "Msg Interface ori" = "Item Attribute Get Impl ori";
    }
    /// <summary>Assigns an attribute value to an item; idempotent when the same value already exists.</summary>
    value(10036894; "Item.Attribute.Create")
    {
        Caption = 'Item.Attribute.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Create Impl ori";
    }
    /// <summary>Updates an existing item attribute mapping and returns before/after values.</summary>
    value(10036895; "Item.Attribute.Update")
    {
        Caption = 'Item.Attribute.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Update Impl ori";
    }
    /// <summary>Creates an attribute definition and optional option values, independent of any item.</summary>
    value(10036896; "Item.AttributeDefinition.Create")
    {
        Caption = 'Item.AttributeDefinition.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item AttrDef Create Impl ori";
    }
}
