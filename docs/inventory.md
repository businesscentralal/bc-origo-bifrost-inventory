# Inventory help

Local help target for the Bifrost Inventory message types. The external documentation site is still owned by the documentation team. This page is the in-repo target for HelpLinks until that site publishes `help/inventory`.

## Message types

- Inventory.Attribute.Get, Create, Update, and AttributeDefinition.Create
- Inventory.ItemReference.Resolve
- Inventory.AvailabilityByPeriod.Get
- Inventory.ItemCharge.Assign and Inventory.ItemCharge.Get
- Inventory.TransferOrder.Create, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.AssemblyOrder.Create, RefreshLines, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.Transfer.UndoShipment and Inventory.Transfer.UndoReceipt
- Inventory.Assembly.UndoPost
- Inventory.Tracking.Get, Assign, Delete, and TrackingAvailability.Get
- Inventory.Reservation.Get, Create, Cancel, and AutoReserve
- Inventory.OrderTracking.Get
- Inventory.ItemApplication.Get, Unapply, and Reapply
- Inventory.ItemCategory.Get and Inventory.ItemCategory.Set
- Inventory.Reclassification.Check, PreviewPost, and Post
- Inventory.Period.Get, Close, and Reopen
- Inventory.Price.Update
- Inventory.Cost.Get, Cost.Update, AdjustCost.Run, CostToGL.Post, and CostToGL.Test
- Inventory.Revaluation.Calculate, PreviewPost, and Post
- Inventory.PhysInventory.Calculate, RecordCount, Record, Check, PreviewPost, and Post

The published help is `https://docs.bifrost.origo.is/en-us/inventory/` (product page) and
`https://docs.bifrost.origo.is/{locale}/help/inventory/inventory-setup` (context-sensitive help for
the Inventory Setup page).

Icelandic translations are in `app/Translations/Bifrost Inventory.is-IS.xlf`. SourceGuards.yaml is not enabled for HelpLinks, IcelandicXlfInSync, or MixedLanguageLabels in this change. Those jobs stay unwired until the guards pass and infrastructure review approves them.

## Enabling a domain

An administrator uses **Inventory Setup** in the Business Central Web Client to enable a domain
for the current company. The **Inv. Posting Gate** permission set (Icelandic: **Bókunarhlið birgða**)
grants access to this page and its settings. `Data.Records.Set` deliberately cannot change this
protected setup, including with `force`; an integration caller must ask the administrator.
The usage-based defaults from issue #147 can enable domains when their native data exists,
including Reclassification. They do not remove an administrator's later opt-out.

## Statistics and counting compatibility

Assembly and transfer statistics are read-only **requests**: they retain their published Inbound
direction and declare a read effect. They do not post or update documents. In an assembly statistics
response, `status` is the call result and the existing `status_` field is the order status. Clients
must continue to use that field; it is retained for backward compatibility.

`Inventory.PhysInventory.RecordCount` takes a `counts` array. The legacy
`Inventory.PhysInventory.Record` also accepts a single `lineNo` and `quantity` when `counts` is
absent. Their help describes the shared operation and explicitly identifies these differences.
Neither call posts the journal.

Attribute creation accepts `overwrite` **inside an object in `attributes`**, not at the request
root. Use that flag intentionally to replace an existing value, or use
`Inventory.Attribute.Update`. Help examples use the registered `Inventory.Attribute.*` names.
