# Bifrost Inventory

Bifrost feature app for inventory message types that are not covered by Bifrost Foundation. Each company can turn domains on or off in Inventory Setup. `IsEnabled` checks the domain flag and the matching permission. Message types use the `Inventory.*.*` pattern. Inventory Setup is not exposed as a main-app message type and is protected from `Data.Records.Set`. Tracking Specification and Reservation Entry are also blocked from `Data.Records.Set`, and so are Item Category, Item Attribute Value Mapping and the two Item Charge Assignment tables (use `Inventory.ItemCategory.Set` and `Inventory.ItemCharge.Assign`).

The Item Reference, Availability, Item Charge and Item Category domains are new switches on Inventory Setup. A new company gets them on. A company that already has an Inventory Setup row gets them off after the upgrade; turn them on from the Inventory Setup page.

## Message types

| Type | Direction | Purpose |
|------|-----------|---------|
| `Inventory.Attribute.Get` | Outbound | Read attributes and values for items |
| `Inventory.ItemReference.Resolve` | Outbound | Resolve a barcode, customer or vendor item reference, item number, or GTIN |
| `Inventory.AvailabilityByPeriod.Get` | Outbound | Read projected availability per day, week, month, quarter or year |
| `Inventory.ItemCategory.Get` | Outbound | Read the item category tree, optionally with category attributes |
| `Inventory.ItemCategory.Set` | Inbound | Create or update item categories and their default attribute values |
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
| `Inventory.AdjustCost.Run` | Inbound | Run report 795 with an item or category filter and an explicit optional postToGL setting |
| `Inventory.Cost.Get` | Outbound | Read unit cost, last direct cost, standard cost, and inventory |
| `Inventory.CostToGL.Post` | Inbound | Run report 1002 without applying request filters or initializing Post; success confirms completion, not G/L posting |
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
| `Inventory.ItemCharge.Assign` | Inbound | Assign an item charge over purchase or sales item lines |
| `Inventory.ItemCharge.Get` | Outbound | Read item charge assignment rows and the unassigned quantity |
| `Inventory.Revaluation.Calculate` | Inbound | Calculate remaining quantity and inventory value |
| `Inventory.Reservation.Get` | Outbound | Read reservation entries |
| `Inventory.Reservation.Create` | Inbound | Create a reservation through Reservation Management |
| `Inventory.Reservation.Cancel` | Inbound | Cancel a reservation through Reservation Management |
| `Inventory.Reservation.AutoReserve` | Inbound | Reserve a sales line from available supply |
| `Inventory.OrderTracking.Get` | Outbound | Read the order tracking chain for a line |
| `Inventory.PhysInventory.Calculate` | Inbound | Calculate on-hand quantity into a physical inventory journal |
| `Inventory.PhysInventory.Record` | Inbound | Record a counted quantity on a physical inventory line |
| `Inventory.PhysInventory.Preview` | Outbound | Preview a physical inventory batch without posting |
| `Inventory.PhysInventory.Post` | Inbound | Post a physical inventory journal batch |

Update this table in the same change as any new or renamed message type.

## Source guards

- #32 Icelandic translation: `app/Translations/Bifrost Inventory.is-IS.xlf` is the committed file. After a compile, run `tools/Update-IcelandicXlf.ps1` and commit the generated file. The guard stays unwired until that generated file matches the build.
- #33 Mixed language labels: user-facing labels need an `is-IS=` comment. Locked wire names stay Locked and are not translated.
- #31 Help links: the external documentation site still needs a `help/inventory` topic. This app cannot create that page.

## Ranges

- App: 10036885–10036934 and 70013400–70013499
- Tests: 96900–96999

## Dependencies

- Bifrost Foundation 28.0.0.0 (`7505e808-6e52-4b96-a328-82573391297a`)

## Permissions

Ships only as PermissionSetExtension onto `BIFROST Read ori` / `BIFROST Full ori`:

- `BIFROST InvRead ori` (extends `BIFROST Read ori`): execute rights for the read-only types and helpers. Includes the nonassignable `BIFROST InvAttrRead ori` (read on the item attribute tables only).
- `BIFROST InvWrite ori` (extends `BIFROST Full ori`): execute rights for every type and helper. Includes the nonassignable `BIFROST InvAttrWrite ori` (write on the item attribute tables only).
- `BIFROST InvPost ori` (assignable): posting gate, assign explicitly.

The attribute sets hold only the attribute-table grants. Item reference, availability, item charge, item category, auto-reserve and order tracking types grant no standard table data: the caller needs a Business Central permission set that can read (or change) Item, Item Variant, Item Reference, Location, Item Category, Item Charge Assignment (Purch)/(Sales), Reservation Entry and the documents involved. IsEnabled and Execute check those permissions and answer `PermissionDenied` with a nextStep that names both sets. Adding standard-table grants through a Foundation role extension raises AppSourceCop AS0110/AS0112.
