# Inventory help

Local help target for the Bifrost Inventory message types. The external documentation site is still owned by the documentation team. This page is the in-repo target for HelpLinks until that site publishes `help/inventory`.

## Message types

- Inventory.Attribute.Get, Create, Update, and AttributeDefinition.Create
- Inventory.TransferOrder.Create, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.AssemblyOrder.Create, RefreshLines, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.Transfer.UndoShipment and Inventory.Transfer.UndoReceipt
- Inventory.Assembly.UndoPost
- Inventory.Tracking.Assign, Delete, and TrackingAvailability.Get
- Inventory.Reservation.Get, Create, and Cancel
- Inventory.ItemApplication.Get, Unapply, and Reapply
- Inventory.Reclassification.Check, PreviewPost, and Post
- Inventory.Period.Get, Close, and Reopen
- Inventory.Price.Update
- Inventory.Cost.Get, AdjustCost.Run, CostToGL.Post, and CostToGL.Test
- Inventory.Revaluation.Calculate
- Inventory.PhysInventory.Calculate, Record, Check, Preview, and Post

Icelandic translations are in `app/Translations/Bifrost Inventory.is-IS.xlf`. SourceGuards.yaml is not enabled for HelpLinks, IcelandicXlfInSync, or MixedLanguageLabels in this change. Those jobs stay unwired until the guards pass and infrastructure review approves them.
