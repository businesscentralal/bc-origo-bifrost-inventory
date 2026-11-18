# Inventory help

Local help target for the Bifrost Inventory message types. The external documentation site is still owned by the documentation team. This page is the in-repo target for HelpLinks until that site publishes `help/inventory`.

## Set up with the wizard

Open **Assisted Setup → Set up Bifrost Inventory**, or **Inventory Setup → Setup Wizard**. The wizard explains what the app adds, shows whether outbound HTTP is enabled for the app (the **Enable HTTP in Bifrost Setup** action opens Foundation's setup wizard; Inventory never writes the HTTP setting), lists the assignable permission set `BIFROST InvPost ori` and opens Users and Permission Sets, and shows the company's Inventory domains read-only. Choose **Finish** to mark the setup complete; closing early leaves it unchanged.

## Message types

- Inventory.Attribute.Get, Create, Update, and AttributeDefinition.Create
- Inventory.ItemSubstitution.Get
- Inventory.ItemReference.Resolve and Inventory.ItemReference.Set
- Inventory.AvailabilityByPeriod.Get
- Inventory.ItemCharge.Assign and Inventory.ItemCharge.Get
- Inventory.TransferOrder.Create, Release, Reopen, Post, Ship, Receive, PreviewPost, Statistics
- Inventory.AssemblyOrder.Create, RefreshLines, Release, Reopen, Post, PreviewPost, Statistics
- Inventory.Transfer.UndoShipment
- Inventory.Transfer.UndoReceipt is not an active type. The released identifier stays for compatibility and is excluded from discovery, because this platform has no native undo of a posted transfer receipt. Return the goods with a new transfer order.
- Inventory.Assembly.UndoPost
- Inventory.Tracking.Get, Assign, Delete, TrackingAvailability.Get, and TrackingInfo.Get
- Inventory.Reservation.Get, Create, Cancel, and AutoReserve
- Inventory.OrderTracking.Get
- Inventory.ItemApplication.Get, Unapply, and Reapply
- Inventory.ItemCategory.Get and Inventory.ItemCategory.Set
- Inventory.Reclassification.Check, PreviewPost, and Post
- Inventory.Period.Get, Close, and Reopen
- Inventory.SKU.Get and Inventory.SKU.Create
- Inventory.Price.Update
- Inventory.Cost.Get, Cost.Update, AdjustCost.Run, CostToGL.Post, and CostToGL.Test
- Inventory.Revaluation.Calculate, PreviewPost, and Post
- Inventory.CycleCount.Calculate (cycle counting journal by counting period; posting stays with Inventory.PhysInventory.Post)
- Inventory.PhysInventory.Calculate, RecordCount, Record, Check, PreviewPost, and Post
- Inventory.PlanningWorksheet.Calculate and Inventory.PlanningWorksheet.CarryOut

The published help is `https://docs.bifrost.origo.is/en-us/inventory/` (product page) and
`https://docs.bifrost.origo.is/{locale}/help/inventory/inventory-setup` (context-sensitive help for
the Inventory Setup page).

Icelandic translations are in `app/Translations/Bifrost Inventory.is-IS.xlf`. SourceGuards.yaml is not enabled for HelpLinks, IcelandicXlfInSync, or MixedLanguageLabels in this change. Those jobs stay unwired until the guards pass and infrastructure review approves them.

## Save an item reference

```json
{"type":"Inventory.ItemReference.Set","data":{"itemNo":"1000","referenceType":"barCode","referenceNo":"5901234123457","description":"Case barcode"}}
```

Enable the Item Reference domain and use `BIFROST Full ori`. The item must exist. Supply `variantCode` and `unitOfMeasure` when needed; an omitted unit uses the item's base unit. `referenceType` accepts `barCode`, `customer`, `vendor` or `blank`. Customer and vendor references require the matching `referenceTypeNo`.

Omitted descriptions and validity dates retain their saved values. Send `startingDate` and `endingDate` as `yyyy-mm-dd`, or an empty string to clear them. A reference already assigned to another item returns `ConflictingIdentifiers` and a `nextStep`. Generic writes to Item Reference (table 5777) are refused and name this dedicated type. Use `Inventory.ItemReference.Resolve` to read back the saved reference. Runtime catalogue descriptions and errors are available in English and Icelandic.

## Reservations

- `Inventory.Reservation.Get` reads by item (`subject` or `itemNo`), by source line (`sourceType` + `sourceNo`, optionally `sourceSubtype` and `sourceLineNo`) or by `entryNo`. Filters sent together all apply. Quantities keep the sign Business Central stores. An unknown `entryNo` is `RecordNotFound`.
- `Inventory.Reservation.Create` reserves for one source line through Reservation Management. A closed sales line (outstanding quantity 0) is `PreconditionFailed`. Optional `lotNo`, `serialNo` and `packageNo` select matching supply. To pin one positive, open inventory entry, send `itemLedgerEntryNo`; conflicting tracking or insufficient unreserved quantity refuses the whole selected-entry request.

```json
{"type":"Inventory.Reservation.Create","data":{"sourceType":37,"sourceNo":"SO-1001","sourceLineNo":10000,"quantity":2,"itemLedgerEntryNo":8842,"lotNo":"LOT-A"}}
```

Create supports Sales Line (37), Purchase Line (39), Transfer Line (5741), Assembly Header (900), Assembly Line (901), Service Line (5902), Prod. Order Line (5406), Prod. Order Component (5407), and Item Journal Line (83). For journals, send `sourceNo` as the template and `sourceBatchName` as the batch, with the entry type in `sourceSubtype`. For production, send the status ordinal in `sourceSubtype` and the parent line in `sourceProdOrderLine`; `sourceLineNo` is 0 for an output line and the component line number for a component. Assembly headers also use `sourceLineNo:0`. Use the same source pointer for Get or Cancel, omitting blank optional parts. BC permits reservation pairs for transfer journal entries; other journal entry types still receive BC's native refusal.

A `serialNo` request must represent exactly one base unit, including conversion from the source unit of measure.

Without `itemLedgerEntryNo`, the existing general-supply path may return a partial quantity as `Success` with `fullAutoReservation:false`. Read `quantity` and `requestedQuantity` before treating a reservation as complete.
- `Inventory.Reservation.Cancel` cancels one reservation pair by `entryNo`, or every reservation of a source line in one transaction. A line without reservations answers Success with `entriesCancelled` 0.

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

## Post part of a transfer order

Send `Inventory.TransferOrder.Ship` with this data:

```json
{"documentNo":"XTRANSFER","expectedCount":1,"lines":[{"lineNo":10000,"qtyToShip":3}]}
```

The result includes `postedShipmentNo`. For receipt, use `Inventory.TransferOrder.Receive` with `qtyToReceive`; the result includes `postedReceiptNo`. Both also return `status`, `documentNo`, `postingDate`, `postedShipmentNo`, `postedReceiptNo` and `orderDeleted`; the unused posted number is empty. A final receipt can remove the completed order and still returns its posted number.

`expectedCount` counts transfer orders, so send 1 regardless of line count or quantity. Send 1–200 distinct existing top-level lines with positive JSON numbers. Ship cannot exceed quantity minus quantity shipped; Receive cannot exceed quantity shipped minus quantity received. Omitted lines are not posted. Duplicate lines, invalid or excessive quantities return `InvalidLine` with `nextStep`. Direct transfers return `PreconditionFailed`: use `Inventory.TransferOrder.Post` for those. Native posting errors roll back the quantity changes and posting entries. Success commits and ignores Omit Commit; inspect posted state before retrying.

Both operations require the Transfer Orders domain and the existing write and posting permissions. Runtime help and refusals are available in English and Icelandic.

## Bóka hluta flutningspöntunar

Sendu `Inventory.TransferOrder.Ship` með `documentNo`, `expectedCount: 1` og `lines` sem inniheldur `lineNo` og `qtyToShip`. Svarið skilar `postedShipmentNo`. Notaðu `Inventory.TransferOrder.Receive` með `qtyToReceive` fyrir móttöku; svarið skilar `postedReceiptNo`.

`expectedCount` telur flutningspantanir, ekki línur eða magn. Sendu 1–200 aðskildar aðallínur með jákvæðu tölulegu magni innan eftirstöðva. Móttaka má ekki fara yfir afhent en ómóttekið magn. Línur sem er sleppt eru ekki bókaðar. Ógildar línur skila `InvalidLine` með `nextStep`. Beinir flutningar nota `Inventory.TransferOrder.Post`. Villur í innbyggðri bókun afturkalla breytingar; heppnuð bókun er vistuð og hunsar Omit Commit. Lokamóttaka getur eytt fullgerðri pöntun en skilar samt númeri bókaðrar móttöku.

Foundation publishes JSON contract chapters in English in every locale. The discovery selection description also defines the counting unit in the caller’s language (1033/1039); the app ships Icelandic XLF for all labels.
