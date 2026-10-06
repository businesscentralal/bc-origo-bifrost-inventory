# Bifrost Inventory

Bifrost feature app for inventory message types that are not covered by Bifrost Foundation. Each company can turn domains on or off in Inventory Setup. `IsEnabled` checks the domain flag and the matching permission. Message types use the `Inventory.*.*` pattern. Inventory Setup is not exposed as a main-app message type and is protected from `Data.Records.Set`. Tracking Specification and Reservation Entry are also blocked from `Data.Records.Set`.

## Message types

| Type | Direction | Purpose |
|------|-----------|---------|
| `Inventory.Attribute.Get` | Outbound | Read attributes and values for items |
| `Inventory.Attribute.Create` | Inbound | Assign an attribute value to an item |
| `Inventory.Attribute.Update` | Inbound | Change an existing item attribute mapping |
| `Inventory.AttributeDefinition.Create` | Inbound | Create an attribute definition and options |
| `Inventory.TransferOrder.Create` | Inbound | Create a transfer order |
| `Inventory.TransferOrder.Release` | Inbound | Release a transfer order |
| `Inventory.TransferOrder.Reopen` | Inbound | Reopen a transfer order |
| `Inventory.TransferOrder.Post` | Inbound | Post a transfer order |
| `Inventory.TransferOrder.PreviewPost` | Inbound | Preview posting a transfer order |
| `Inventory.TransferOrder.Statistics` | Outbound | Read transfer order statistics |
| `Inventory.AssemblyOrder.Create` | Inbound | Create an assembly order |
| `Inventory.AssemblyOrder.RefreshLines` | Inbound | Refresh assembly order lines |
| `Inventory.AssemblyOrder.Release` | Inbound | Release an assembly order |
| `Inventory.AssemblyOrder.Reopen` | Inbound | Reopen an assembly order |
| `Inventory.AssemblyOrder.Post` | Inbound | Post an assembly order |
| `Inventory.AssemblyOrder.PreviewPost` | Inbound | Preview posting an assembly order |
| `Inventory.AssemblyOrder.Statistics` | Outbound | Read assembly order statistics |
| `Inventory.AdjustCost.Run` | Inbound | Run Adjust Cost - Item Entries, report 795, with item filters |
| `Inventory.Cost.Get` | Outbound | Read unit cost, last direct cost, standard cost, and inventory |
| `Inventory.CostToGL.Post` | Inbound | Post inventory cost to G/L, report 1002, with item filters |
| `Inventory.CostToGL.Test` | Inbound | Test the inventory cost to G/L item filter without posting |
| `Inventory.Tracking.Assign` | Inbound | Assign lot, serial, or package tracking through Item Tracking Management |
| `Inventory.Tracking.Delete` | Inbound | Delete an item tracking specification |
| `Inventory.TrackingAvailability.Get` | Outbound | Read remaining quantity by lot, serial, and package |
| `Inventory.Transfer.UndoShipment` | Inbound | Undo a posted transfer shipment |
| `Inventory.Transfer.UndoReceipt` | Inbound | Undo a posted transfer receipt |
| `Inventory.Assembly.UndoPost` | Inbound | Undo a posted assembly |
| `Inventory.ItemApplication.Get` | Outbound | Read item application entries and the joined item ledger entries |
| `Inventory.ItemApplication.Unapply` | Inbound | Unapply an item application through Item Jnl.-Post Line |
| `Inventory.ItemApplication.Reapply` | Inbound | Reapply an item ledger entry through Item Jnl.-Post Line |
| `Inventory.Reclassification.Check` | Outbound | Check a reclassification journal batch |
| `Inventory.Reclassification.PreviewPost` | Inbound | Preview a reclassification journal batch without posting |
| `Inventory.Reclassification.Post` | Inbound | Post a reclassification journal batch |
| `Inventory.Period.Get` | Outbound | Read inventory periods |
| `Inventory.Period.Close` | Inbound | Close inventory periods through an ending date |
| `Inventory.Period.Reopen` | Inbound | Reopen a closed inventory period |
| `Inventory.Price.Update` | Inbound | Update an item unit price |
| `Inventory.Revaluation.Calculate` | Inbound | Calculate remaining quantity and inventory value |
| `Inventory.Reservation.Get` | Outbound | Read reservation entries |
| `Inventory.Reservation.Create` | Inbound | Create a reservation through Reservation Management |
| `Inventory.Reservation.Cancel` | Inbound | Cancel a reservation through Reservation Management |
| `Inventory.PhysInventory.Calculate` | Inbound | Calculate on-hand quantity into a physical inventory journal |
| `Inventory.PhysInventory.Record` | Inbound | Record a counted quantity on a physical inventory line |
| `Inventory.PhysInventory.Check` | Outbound | Read quantity differences before posting |
| `Inventory.PhysInventory.Preview` | Outbound | Preview a physical inventory batch without posting |
| `Inventory.PhysInventory.Post` | Inbound | Post a physical inventory journal batch |

Update this table in the same change as any new or renamed message type.

## Source guards

- #32 Icelandic translation: `app/Translations/Bifrost Inventory.is-IS.xlf` is the committed file. After a compile, run `tools/Update-IcelandicXlf.ps1` and commit the generated file. The guard stays unwired until that generated file matches the build.
- #33 Mixed language labels: user-facing labels need an `is-IS=` comment. Locked wire names stay Locked and are not translated.
- #31 Help links: the external documentation site still needs a `help/inventory` topic. This app cannot create that page.

## Ranges

- App: 10036885–10036934
- Tests: 96900–96999

## Dependencies

- Bifrost Foundation 28.0.0.0 (`7505e808-6e52-4b96-a328-82573391297a`)

## Permissions

Ships only as PermissionSetExtension onto `BIFROST Read ori` / `BIFROST Full ori`.
