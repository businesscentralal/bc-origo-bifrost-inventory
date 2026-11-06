# Inventory help

Local help target for the Bifrost Inventory message types. The external documentation site is still owned by the documentation team. This page is the in-repo target for HelpLinks until that site publishes `help/inventory`.

## Set up with the wizard

Open **Assisted Setup → Set up Bifrost Inventory**, or **Inventory Setup → Setup Wizard**. The wizard explains what the app adds, shows whether outbound HTTP is enabled for the app (the **Enable HTTP in Bifrost Setup** action opens Foundation's setup wizard; Inventory never writes the HTTP setting), lists the assignable permission set `BIFROST InvPost ori` and opens Users and Permission Sets, and shows the company's Inventory domains read-only. Choose **Finish** to mark the setup complete; closing early leaves it unchanged.

## Message types

- Inventory.Attribute.Get, Create, Update, and AttributeDefinition.Create
- Inventory.ItemReference.Resolve
- Inventory.AvailabilityByPeriod.Get
- Inventory.ItemCharge.Assign and Inventory.ItemCharge.Get
- Inventory.TransferOrder.Create, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.AssemblyOrder.Create, RefreshLines, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.Transfer.UndoShipment
- Inventory.Transfer.UndoReceipt is not an active type. The released identifier stays for compatibility and is excluded from discovery, because this platform has no native undo of a posted transfer receipt. Return the goods with a new transfer order.
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
