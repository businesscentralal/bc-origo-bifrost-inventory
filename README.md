# Bifrost Inventory

**App name:** Bifrost Inventory (display form *Bifröst birgðir*)  
**Publisher:** Origo — **Version:** 28.1.0.0 — **Target:** Cloud (BC 28.3 or later, runtime 17.0)  
**App ID:** `02701c94-c962-4825-92c7-ef9f70311a2b` — **Test app ID:** `a886b2cb-7da0-4784-8163-42956dbdd5ec`  
**Object ID range:** 10076835–10077034 (tests 96900–96999) — **Namespace:** `Origo.Bifrost.Inventory`  
**Environments:** Business Central online (SaaS) and the COSMO Alpaca development containers `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International Ltd.)

---

## Overview

Bifrost Inventory is the inventory module of the Bifröst platform. It publishes 76 Bifröst message
types for inventory work that Bifrost Foundation does not cover: item attributes, transfer orders,
assembly orders, item tracking, reservations, physical inventory, reclassification journals, item
application, inventory periods, cost adjustment and posting to G/L, revaluation, item cost reads and
unit price updates. An agent or an integration calls them through the same Queue → Task → Data API
as the rest of Bifröst.

Every message type calls Microsoft's own codeunits and reports (Item Tracking Management, Reservation
Management, Item Jnl.-Post Line, the undo codeunits, reports 795 and 1002 and so on). The app
reimplements none of that logic. Plain reads and writes stay with Foundation's `Data.Records.Get`
and `Data.Records.Set`.

### Message types

The active roster is implemented by the `Message Type ori` enum extensions under `app/src/`; disabled compatibility identifiers are excluded below. `Help.Bifrost.Get`
and `Help.Implementation.Get` return the same list and each type's contract at runtime.

| Type | Direction | Purpose |
|------|-----------|---------|
| `Purchase.Requisition.Calculate` | Inbound | Calculate a bounded native requisition worksheet plan (report 699) |
| `Purchase.Requisition.CarryOut` | Inbound | Consume selected new suggestions to create purchase or transfer orders |
| `Inventory.Attribute.Get` | Outbound | Read attributes and values for items |
| `Inventory.ItemSubstitution.Get` | Outbound | Read direct item substitutes and exact-variant on-hand inventory |
| `Inventory.ItemReference.Resolve` | Outbound | Resolve a barcode, customer or vendor item reference, item number, or GTIN |
| `Inventory.AvailabilityByPeriod.Get` | Outbound | Read projected availability per day, week, month, quarter or year |
| `Inventory.ItemCategory.Get` | Outbound | Read the item category tree, optionally with category attributes |
| `Inventory.ItemCategory.Set` | Inbound | Create or update item categories and their default attribute values |
| `Inventory.Item.Create` | Inbound | Create an item from an item template (description, base unit of measure, unit price, GTIN); answers the item number and its units of measure. Gated by the Attributes domain |
| `Inventory.SKU.Get` | Outbound | Read stockkeeping units with their planning and cost fields |
| `Inventory.SKU.Create` | Inbound | Create stockkeeping units per location and variant (report 5706), optionally replacing existing ones |
| `Purchase.ReturnOrder.CreateFromPosted` | Inbound | Create an open purchase return order or credit memo from posted receipt or invoice item lines. Nothing is posted |
| `Inventory.Attribute.Create` | Inbound | Assign an attribute value to an item |
| `Inventory.Attribute.Update` | Inbound | Change an existing item attribute mapping |
| `Inventory.AttributeDefinition.Create` | Inbound | Create an attribute definition and options |
| `Inventory.TransferOrder.Create` | Inbound | Create a transfer order |
| `Inventory.TransferOrder.Release` | Inbound | Release a transfer order |
| `Inventory.TransferOrder.Reopen` | Inbound | Reopen a transfer order |
| `Inventory.TransferOrder.Ship` | Inbound | Ship specified `qtyToShip` values on selected transfer lines; returns `postedShipmentNo` |
| `Inventory.TransferOrder.Receive` | Inbound | Receive specified `qtyToReceive` values on selected transfer lines; returns `postedReceiptNo` |
| `Inventory.TransferOrder.Post` | Inbound | Post a transfer order (Ship or Receive). A Receive that completes the order returns Success with `postedReceiptNo` and `orderDeleted: true` |
| `Inventory.TransferOrder.PreviewPost` | Inbound | Preview posting a transfer order |
| `Inventory.TransferOrder.Statistics` | Inbound | Read transfer order statistics |
| `Inventory.AssemblyOrder.Create` | Inbound | Create an assembly order |
| `Inventory.AssemblyOrder.RefreshLines` | Inbound | Refresh assembly order lines |
| `Inventory.AssemblyOrder.Release` | Inbound | Release an assembly order |
| `Inventory.AssemblyOrder.Reopen` | Inbound | Reopen an assembly order |
| `Inventory.AssemblyOrder.Post` | Inbound | Post an assembly order |
| `Inventory.AssemblyOrder.PreviewPost` | Inbound | Preview posting an assembly order |
| `Inventory.AssemblyOrder.Statistics` | Inbound | Read assembly order statistics |
| `Inventory.AssemblyToOrder.Get` | Outbound | Read the assemble-to-order assembly order linked to a sales line, with its lines |
| `Inventory.AssemblyBOM.Get` | Outbound | Read the assembly BOM components of an item, optionally exploded through all levels |
| `Inventory.AdjustCost.Run` | Inbound | Run report 795 with an item or category filter and an explicit optional postToGL setting |
| `Inventory.Cost.Get` | Outbound | Read unit cost, last direct cost, standard cost, and inventory |
| `Inventory.Cost.Update` | Inbound | Change unit cost, last direct cost or standard cost on one item card through native validation. Standard-costed items are refused and pointed to `Inventory.Revaluation.Post` |
| `Inventory.CostToGL.Post` | Inbound | Run report 1002 without applying request filters or initializing Post; success confirms completion, not G/L posting |
| `Inventory.CostToGL.Test` | Inbound | Test the inventory cost to G/L item filter without posting |
| `Inventory.Tracking.Assign` | Inbound | Assign lot, serial or package tracking to an explicit document line through native Item Tracking Lines |
| `Inventory.Tracking.Delete` | Inbound | Remove one unreserved tracking entry from an explicit source line |
| `Inventory.Tracking.Get` | Outbound | Read the lot, serial and package tracking of a document line or the open item ledger entries of an item |
| `Inventory.TrackingAvailability.Get` | Outbound | Read remaining quantity by lot, serial, and package |
| `Inventory.TrackingInfo.Get` | Outbound | Read one lot, serial or package information card: description, test quality, certificate, blocked, comments, inventory and expired inventory |
| `Inventory.Transfer.UndoShipment` | Inbound | Undo a posted transfer shipment |
| `Inventory.Assembly.UndoPost` | Inbound | Undo a posted assembly |
| `Inventory.ItemApplication.Get` | Outbound | Read item application entries and the joined item ledger entries |
| `Inventory.ItemApplication.Unapply` | Inbound | Unapply applications linked to itemLedgerEntryNo through Item Jnl.-Post Line; legacy entryNo selects one application |
| `Inventory.ItemApplication.Reapply` | Inbound | Reapply outboundEntryNo to inboundEntryNo for an exact positive base quantity; legacy selectors remain supported |
| `Inventory.Reclassification.Check` | Outbound | Check a reclassification journal batch |
| `Inventory.Reclassification.PreviewPost` | Inbound | Preview a reclassification journal batch without posting |
| `Inventory.Reclassification.Post` | Inbound | Post a reclassification journal batch |
| `Inventory.Period.Get` | Outbound | Read inventory periods |
| `Inventory.Period.Close` | Inbound | Close inventory periods through an ending date |
| `Inventory.Period.Reopen` | Inbound | Reopen a closed inventory period |
| `Inventory.Price.Update` | Inbound | Update an item unit price |
| `Price.List.Set` | Inbound | Create or update a Draft sales/purchase price list and numbered lines |
| `Price.List.Activate` | Inbound | Verify native price lines, refuse duplicate prices and activate the list |
| `Inventory.ItemCharge.Assign` | Inbound | Assign an item charge over purchase or sales item lines |
| `Inventory.ItemCharge.Get` | Outbound | Read item charge assignment rows and the unassigned quantity |
| `Sales.ReturnOrder.CreateFromPosted` | Inbound | Create a sales return order or credit memo, or fill an open one, from posted invoice or shipment lines with quantities, as Get Posted Document Lines to Reverse does; item lines get Appl.-from Item Entry; refuses too large a quantity and lines of another customer with `InvalidLine` |
| `Inventory.Revaluation.Calculate` | Inbound | Calculate remaining quantity and inventory value |
| `Inventory.Revaluation.PreviewPost` | Inbound | Preview posting a revaluation journal batch; nothing is kept |
| `Inventory.Revaluation.Post` | Inbound | Post a revaluation journal batch through Item Jnl.-Post Batch |
| `Inventory.Reservation.Get` | Outbound | Read reservation entries |
| `Inventory.Reservation.Create` | Inbound | Reserve supply for a sales, purchase, transfer, assembly, service, production or item journal source (`sourceType`, `sourceSubtype`, `sourceNo`, `sourceLineNo`, `quantity`) through Reservation Management; optional lot/serial/package filters or `itemLedgerEntryNo` select supply; returns `entryNo` |
| `Inventory.Reservation.Cancel` | Inbound | Cancel the reservation pair with `entryNo` through Reservation Engine Mgt. |
| `Inventory.Reservation.AutoReserve` | Inbound | Reserve a sales line from available supply |
| `Inventory.OrderTracking.Get` | Outbound | Read the order tracking chain for a line |
| `Inventory.PhysInventory.Calculate` | Inbound | Calculate on-hand quantity into an empty physical inventory journal batch with report 790. `postingDate` and `documentNo` are required; `itemNo`, `locationCode` and `variantCode` filter the items |
| `Inventory.PhysInventory.RecordCount` | Inbound | Record counted quantities for several journal lines; an omitted `qtyCounted` leaves the line uncounted, an explicit 0 records zero |
| `Inventory.PhysInventory.Record` | Inbound | Record a counted quantity on one physical inventory line (single-line form of RecordCount) |
| `Inventory.PhysInventory.Check` | Outbound | Check a physical inventory batch and list errors and warnings without posting |
| `Inventory.PhysInventory.PreviewPost` | Inbound | Preview posting a physical inventory batch; nothing is kept |
| `Inventory.PhysInventory.Post` | Inbound | Post a physical inventory journal batch and return the item register and ledger entry ranges. An empty batch is `PreconditionFailed` |
| `Inventory.PhysInventoryOrder.Create` | Inbound | Create a native physical inventory order with calculated expected quantities and one recording; requires an explicit `itemNoFilter` |
| `Inventory.PhysInventoryOrder.Finish` | Inbound | Write recording counts, finish all open recordings and finish the order to calculate differences; nothing is posted |
| `Inventory.PhysInventoryOrder.Post` | Inbound | Post one finished native physical inventory order and return its posted number; `expectedCount` counts one order, not lines or units |

Update this table in the same change as any new or renamed message type. Foundation itself
registers `Inventory.ItemJournal.Check`, `.Create`, `.Post` and `.PreviewPost`; this app does not
own them.

---

## Functional Flow

1. An external caller (an agent through the Bifröst MCP server, an integration, or Business Central
   itself) posts a message to Foundation's Queue → Task → Data route with an `Inventory.*` type.
2. Foundation resolves the type to its implementation codeunit in this app through the
   `Message Type ori` enum and the `Msg Interface ori` interface.
3. The implementation asks `Inventory Domain Gate ori` whether its domain is on in **Inventory
   Setup** and whether the caller holds the needed permission. Posting types also need the
   `BIFROST InvPost ori` permission set.
4. The implementation reads the request, calls the matching Microsoft codeunit or report and writes
   a JSON response, or a structured error (`MissingParameter`, `InvalidParameterFormat`,
   `PreconditionFailed`, `PermissionDenied`, …) through the Foundation argument.
5. Discovery (`Help.Bifrost.Get`) lists only the types that are enabled for the caller, and each
   type answers its contract chapters through `Help.Implementation.Get`.

---

## Benefits

- **One governed API for inventory work.** Transfer, assembly, tracking, reservations, counting,
  costing and period close can be run without opening the Business Central client.
- **Microsoft logic, not a copy.** Every write goes through the standard codeunits and reports, so
  validation, posting and ledger entries are exactly what a user would get.
- **Per-company control.** Each domain can be switched off for a company without uninstalling the
  app; a switched-off domain disappears from discovery.
- **Posting is separate from writing.** Posting, cost adjustment, cost to G/L and posting previews
  need their own permission set, so an integration can create and release documents without being
  able to post them.
- **Safe generic writes.** Item attribute tables, Inventory Setup, Tracking Specification,
  Reservation Entry, Item Category and the two Item Charge Assignment tables are closed to
  `Data.Records.Set`, so callers use the typed message types that keep Microsoft's validation.
- **Self-describing.** Every type publishes its parameters, response, errors, effect and related
  types at runtime, in English and Icelandic.

---

## Logic Flow

| Step | Object | What happens |
| --- | --- | --- |
| Registration | `Inventory Registration ori` (10076845) | Answers Foundation's `App Registry ori` `OnRegisterApps` and registers `Inventory Setup ori` as the app setup page. |
| Install / upgrade | `Inventory Install ori` (10076835), `Inventory Upgrade ori` (10076836) | Sets the initial-release upgrade tag; install inserts the Inventory Setup record per company. |
| Domain gate | `Inventory Domain Gate ori` (10076922) | `IsEnabled` / `AssertEnabled`: the domain flag must be on (a missing setup row counts as on) and the caller needs read, write or posting permission for the domain. |
| Posting gate | `Inv. Posting Gate ori` (10076921), `Inv. Posting ori` (10076835) | Write permission on the token table `Inv. Posting ori` is the posting permission; only `BIFROST InvPost ori` grants it. |
| Contracts | `Inventory Contract Parts ori` (10076919) | Shared contract chapters used by the implementation codeunits. |
| Write restrictions | `Item Attr. Data Restrict ori` (10076846), `Inventory Setup Restrict ori` (10076923), `Tracking Data Restrict ori` (10076920), `Reservation WriteGuard ori` (10076843) | Subscribe to Foundation's `OnAfterIsTableWriteRestrictedForDataRecords` and close their tables to `Data.Records.Set`. |
| Field restrictions | `Inventory Cost Data Guard ori` (10076838) | Subscribes to `OnAfterIsFieldWriteRestrictedForDataRecords` and closes Item Unit Cost, Standard Cost, Last Direct Cost and Unit Price to `Data.Records.Set`; the refusal names `Inventory.Cost.Update` or `Inventory.Price.Update`. |
| Write process | `Inventory Write Process ori` (10076842) | One `Codeunit.Run` boundary for the journal, card-cost, price and reservation writes, so a native error rolls the whole write back. |

Types that need the posting permission: `Inventory.TransferOrder.Ship`, `Inventory.TransferOrder.Receive`, `Inventory.TransferOrder.Post`, `Inventory.AssemblyOrder.Post`,
`Inventory.AdjustCost.Run`, `Inventory.CostToGL.Post`, `Inventory.CostToGL.Test`,
`Inventory.PhysInventory.Post`, `Inventory.Reclassification.Post`,
`Inventory.Reclassification.PreviewPost`, `Inventory.Revaluation.Post` and `Inventory.Revaluation.PreviewPost`.
`Inventory.Transfer.UndoReceipt` is not one of them: it is disabled, it does not post, and it is absent from the active roster.

---

## Set up with the wizard

Open **Assisted Setup → Set up Bifrost Inventory**, or **Inventory Setup → Setup Wizard**. Review the operations, HTTP status, access and company domains, then choose **Finish** to record completion. The HTTP action opens Foundation's setup; Inventory never writes the HTTP setting. Only `BIFROST InvPost ori` is separately assignable. The attribute read/write sets are included through Foundation Read/Full roles. The guide does not assign access or change domains. Closing early preserves the existing completion state. [Inventory documentation](https://docs.bifrost.origo.is/en-us/inventory/).

### Setja upp með uppsetningarhjálp

Opnaðu **Leiðsagða uppsetningu → Setja upp Bifröst birgðir**, eða **Uppsetningu birgða → Uppsetningarhjálp**. Farðu yfir aðgerðir, HTTP-stöðu, aðgang og svið fyrirtækisins. Veldu **Ljúka** til að skrá að yfirferð sé lokið. HTTP-aðgerðin opnar uppsetningu Foundation; birgðaviðbótin breytir ekki HTTP-stillingunni. Aðeins `BIFROST InvPost ori` er sérstaklega úthlutanleg; les- og skrifheimildir vörueiginleika fylgja Read/Full-heimildum Foundation. Leiðarvísirinn úthlutar ekki aðgangi og breytir ekki sviðum. Ef lokað er fyrr helst fyrri lokastaða óbreytt.

## Setup & Configuration

1. Install Bifrost Foundation 28.0.3.530 or later and complete its setup (Bifröst Setup).
2. Install Bifrost Inventory. The install code creates the **Inventory Setup** record in every
   company, and Bifröst Setup lists the app with **Inventory Setup** as its setup page.
3. Open **Inventory Setup** (search for *Inventory Setup*, or open it from Bifröst Setup) and switch
   the domains on or off: Attributes, Transfer Orders, Assembly, Reservations, Item Tracking,
   Physical Inventory, Costing, Reclassification, Item Application, Inventory Period, Item Price,
   Item Reference, Availability, Item Charge, Item Category, Item Substitution and Purchase Returns.
   Domain defaults now follow the company's inventory usage. New rows start off and enable the
   domains for which usage exists. A one-time, per-company upgrade raises the same flags on
   existing rows, including Reclassification. It never turns an enabled domain off and makes no
   write when nothing changes. Later manual choices remain in place; the upgrade does not run
   again. If no setup row exists, the existing all-domains-enabled rule still applies.
   Calls that reach a disabled domain's implementation return a coded refusal with a next step
   pointing to Inventory Setup. Foundation can omit disabled types from discovery and reject a
   call before it reaches the implementation; this app cannot change that Foundation behavior.

   | Domain | Usage that enables it (any listed signal is sufficient) |
   | --- | --- |
   | Attributes | Item Attribute records |
   | Transfer Orders | An in-transit Location, Transfer Header or Transfer Route |
   | Assembly | BOM Component, Assembly Header or Production BOM Header |
   | Reservations | Reservation Entry with status Reservation |
   | Item Tracking | Item Tracking Code, an Item with a tracking code, or lot/serial/package tracking on Reservation Entry, Tracking Specification or Item Ledger Entry |
   | Physical Inventory | Phys. Invt. Record Header, Phys. Inventory Ledger Entry, or an Item with a counting period |
   | Costing | Value Entry or Inventory Adjmt. Entry (Order) |
   | Reclassification | Location, Bin Content, Warehouse Entry, or one Item with ledger entries in more than one location |
   | Item Application | Item Application Entry |
   | Inventory Period | Inventory Period |
   | Item Price | Price List Line with Asset Type Item |
   | Item Substitution | Item Substitution |
   | Item Reference | Item Reference |
   | Availability | Item or Item Ledger Entry; valid demand/supply lines already reference an Item |
   | Item Charge | Item Charge |
   | Item Category | Item Category or an Item with a category code |
   | Purchase Returns | Purchase Header whose document type is Return Order or Credit Memo |

   Usage checks only read company data. A source the caller cannot read supplies no signal; no
   extra business-data permission is granted. Administrators can still enable any domain manually.
4. Grant permissions:
   - Foundation's `BIFROST Read ori` and `BIFROST Full ori` roles are extended by
     `BIFROST InvRead ori` and `BIFROST InvWrite ori`; no separate assignment is needed for reads
     and writes.
   - Apart from the item attribute tables, the app grants no standard table data. The item
     reference, availability, item charge, item category, auto-reserve and order tracking types
     need the caller's own Business Central permissions on the tables they touch (Item, Item
     Variant, Item Reference, Location, Item Category, Item Charge Assignment, Reservation Entry and
     the documents involved); they answer `PermissionDenied` when one is missing.
     `Purchase.ReturnOrder.CreateFromPosted` needs the caller's own permission to create purchase
     documents and to read posted purchase receipts, invoices and item entries.
   - Assign **`BIFROST InvPost ori`** (*Inv. Posting Gate*) to users or service principals that may
     post, run cost adjustment or post to G/L. It also grants the Inventory Setup page and table.
5. The underlying Business Central setup still applies: locations and transfer routes, assembly
   setup, item tracking codes, inventory periods, journal templates and batches, and posting setup.

---

## Example Scenario

A warehouse system moves stock from `MAIN` to `EAST`:

1. `Inventory.TransferOrder.Create` with the two locations and the item lines creates a transfer
   order.
2. `Inventory.Tracking.Assign` assigns a lot number to the transfer line.
3. `Inventory.TransferOrder.Release` releases the order, and `Inventory.TransferOrder.PreviewPost`
   shows the entries that posting would create.
4. A service principal with `BIFROST InvPost ori` calls `Inventory.TransferOrder.Post`. Without that
   permission set the call returns `PermissionDenied` and nothing is posted.
5. If the shipment was wrong, `Inventory.Transfer.UndoShipment` reverses the posted shipment.
6. At month end, `Inventory.AdjustCost.Run` and `Inventory.CostToGL.Post` run reports 795 and 1002,
   and `Inventory.Period.Close` closes the inventory period.

---

## Objects

### Tables

| ID | Name | Purpose |
| --- | --- | --- |
| 10076835 | `Inv. Posting ori` | Permission token for the posting gate; stores no records |
| 10076836 | `Inventory Setup ori` | Per-company domain switches |

### Pages

| ID | Name | Purpose |
| --- | --- | --- |
| 10076835 | `Inventory Setup ori` | Domain switches; context-sensitive help slug `inventory-setup` |

### Enums and enum extensions

| ID | Name | Purpose |
| --- | --- | --- |
| 10076835 | `Inventory Domain ori` | The seventeen domains |
| 10076835 | `MsgType.AvailPer.EnumExt ori` | `Inventory.AvailabilityByPeriod.Get` |
| 10076836 | `MsgType.CostGet.EnumExt ori` | `Inventory.Cost.Get`, `Inventory.Cost.Update`, `Inventory.Revaluation.Post`, `Inventory.Revaluation.PreviewPost` |
| 10076837 | `MsgType.EnumExt ori` | 36 message types on Foundation's `Message Type ori` |
| 10076838 | `MsgType.ItemCat.EnumExt ori` | `Inventory.ItemCategory.Get`, `Inventory.ItemCategory.Set` |
| 10076995 | `MsgType.SKU.EnumExt ori` | `Inventory.SKU.Create`, `Inventory.SKU.Get` |
| 10076839 | `MsgType.ItemChg.EnumExt ori` | `Inventory.ItemCharge.Assign`, `Inventory.ItemCharge.Get` |
| 10076840 | `MsgType.ItemRef.EnumExt ori` | `Inventory.ItemReference.Resolve`, `Inventory.ItemSubstitution.Get` |
| 10076841 | `MsgType.PhysInvt.EnumExt ori` | Physical inventory types |
| 10076842 | `MsgType.PhysRecord.EnumExt ori` | `Inventory.PhysInventory.Record` |
| 10076843 | `MsgType.ReservAuto.Ext ori` | `Inventory.Reservation.AutoReserve`, `Inventory.OrderTracking.Get` |
| 10076844 | `MsgType.Reserv.Create.Ext ori` | Reservation types |
| 10076845 | `MsgType.Reserv.EnumExt ori` | Reservation types |
| 10076846 | `MsgType.TrackAvail.EnumExt ori` | `Inventory.TrackingAvailability.Get`, `Inventory.Tracking.Get` |
| 10076848 | `MsgType.ItemCreate.EnumExt ori` | `Inventory.Item.Create` |
| 10076847 | `MsgType.PurchRet.EnumExt ori` | `Purchase.ReturnOrder.CreateFromPosted` |
| 10076860 | `MsgType.PhysOrder.Ext ori` | Physical inventory order lifecycle |
| 10076906 | `MsgType.SalesRetOrd.Ext ori` | `Sales.ReturnOrder.CreateFromPosted` |
| 10076960 | `MsgType.AsmRead.Ext ori` | `Inventory.AssemblyToOrder.Get`, `Inventory.AssemblyBOM.Get` |
| 10076915 | `MsgType.TrackInfo.EnumExt ori` | `Inventory.TrackingInfo.Get` (value 10077010) |

Each message type value is the ID of its implementation codeunit. The exception is
`Inventory.PhysInventory.RecordCount` (10076924), which shares `Phys. Invt. Record Impl ori` with
`Inventory.PhysInventory.Record` (10076882).

### Codeunits

Physical inventory orders (#113) add codeunits **10076960–10076964**: `Phys Order Create Impl ori`, `Phys Order Finish Impl ori`, `Phys Order Post Impl ori`, `Phys Order Process ori` and `Phys Order Contract ori`; test codeunit **96986** `Phys Order Tests ori`.

| IDs | Area | Codeunits |
| --- | --- | --- |
| 10076835, 10076836, 10076845 | Lifecycle | `Inventory Install ori`, `Inventory Upgrade ori`, `Inventory Registration ori` |
| 10076837–10076843 | Shared reads and writes | `Inventory Card Write ori`, `Inventory Cost Data Guard ori`, `Inventory Cost Read ori`, `Inventory Native Journal ori` (physical inventory and revaluation), `Inventory Tracking Read ori`, `Inventory Write Process ori`, `Reservation WriteGuard ori` |
| 10076846–10076848 | Write restrictions | `Item Attr. Data Restrict ori`, `Item Category Restrict ori`, `Item Charge Restrict ori` |
| 10076995–10076999 | Stockkeeping units | `SKU Create Impl ori`, `SKU Get Impl ori`, `SKU Create Proc ori`, `SKU Request ori`, `SKU Restrict ori` (blocks Data.Records.Set on table 5700) |
| 10076919–10076923 | Shared | Contract parts, tracking write restriction, posting gate, domain gate, setup write restriction |
| 10076844, 10076912–10076918 | Item attributes | `Item Attribute Resolve ori`, `Item Attribute Get/Create/Update Impl ori`, `Item AttrDef Create Impl ori`, their process codeunits |
| 10076849–10076856 | Assembly orders | Preview Post, Refresh Lines, Release, Reopen (+ process), Statistics, Create, Post |
| 10076965–10076966 | Assembly reads | `Asm. To Order Get Impl ori`, `Assembly BOM Get Impl ori` |
| 10076857 | Availability | `Avail. By Period Impl ori` |
| 10076858–10076866 | Costing | Adjust Cost Run (+ process), Cost Get, Cost To GL Post/Test, Cost Update, Reval Preview, Revaluation Calc, Revaluation Post |
| 10076867–10076869 | Item application | Get, Reapply, Unapply |
| 10076870–10076872 | Item categories | Get, Set (+ process) |
| 10076873–10076875 | Item charges | Assign (+ process), Get |
| 10076876 | Item references | `Item Ref. Resolve Impl ori` |
| 10076877–10076879, 10076886 | Periods and price | Period Close/Get/Reopen, Price Update |
| 10076880–10076885 | Physical inventory | Calculate (journal and count), Post, Record/RecordCount, Check, Preview Post |
| 10076887–10076889 | Reclassification | Check, Post, Preview |
| 10076890–10076896 | Reservations | Order Tracking Get, `Order Tracking Transfer ori`, Reservation Cancel/Create/Get, Auto Reserve (+ process) |
| 10077030 | Selected reservation supply | `Reserv. Supply Filter ori` restricts the native inventory search while explicitly bound |
| 10076897–10076900, 10077010 | Item tracking | Assign, Availability Get, Delete, Get; `Tracking Info Get Impl ori` (10077010) |
| 10076901–10076908 | Transfer orders | Preview Post, Create, Post, Reopen, Statistics, `Transfer Post Subscriber ori`, Release, Reopen process |
| 10076909–10076911 | Undo | Assembly, transfer shipment, transfer receipt |
| 10076931–10076932 | Items | `Item Create Impl ori`, `Item Create Proc ori` (`Inventory.Item.Create`) |
| 10076930 | Purchase returns | `Purch. Return Create Impl ori` |
| 10077026 | `Transfer Ship Impl ori` | Partial transfer shipment |
| 10077021 | `Transfer Receive Impl ori` | Partial transfer receipt |
| 10077022 | `Partial Transfer Mgt ori` | Validates selected transfer quantities |
| 10077023 | `Partial Transfer Process ori` | Atomic native posting |
| 10077024 | `Partial Transfer Contract ori` | English and Icelandic partial-transfer contracts |
| 10077025 | `Transfer Posting Setup ori` | BC 28/29 direct-transfer setup compatibility |
| 10077032–10077033 | Sales returns | `Sales Ret. Ord. Post. Impl ori` (`Sales.ReturnOrder.CreateFromPosted`), `Sales Ret. Ord. Post. Proc ori` (isolated write) |

### Permission sets

| ID | Name | Assignable | Purpose |
| --- | --- | --- | --- |
| 10076837 | `BIFROST InvPost ori` | Yes | Posting gate, Inventory Setup page and table |
| 10076835 | `BIFROST InvAttrRead ori` | No | Read grants on the standard item attribute tables |
| 10076836 | `BIFROST InvAttrWrite ori` | No | Write grants on the standard item attribute tables |
| 10076835 | `BIFROST InvRead ori` (extension) | — | Extends Foundation's `BIFROST Read ori` |
| 10076836 | `BIFROST InvWrite ori` (extension) | — | Extends Foundation's `BIFROST Full ori` |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.3.530 |
| Base Application (via `application`) | — | Microsoft | 28.3.0.0 |

The Foundation floor is the oldest Foundation release the app compiles against with CodeCop, UICop
and AppSourceCop at zero warnings (release `28.0.3`, package 28.0.3.530). The `application` floor
28.3.0.0 matches the sibling Bifröst apps; the app is compiled locally against BC 28.3 symbols and in
CI against the BC 28.5 sandbox artifact. The test app additionally depends on Bifrost Inventory
itself and on Microsoft's Tests-TestLibraries, Library Assert, Test Runner, Any and Library Variable
Storage.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Inventory`) |
| `app/src/Message Type/` | Message type enum extensions, contract parts and the implementation codeunits by area |
| `app/src/Setup/` | Inventory Setup table and page, domain enum, domain gate, setup write restriction |
| `app/src/Posting/` | Posting gate and its permission token table |
| `app/src/Permissions/` | Permission sets and Foundation role extensions |
| `app/src/Install/`, `app/src/Lifecycle/` | Install, upgrade, registration and attribute write restriction |
| `app/docs/appsource/` | AppSource listing text, market list and release checklist |
| `test/` | Test app (`Bifrost Inventory - Tests`) |
| `tools/` | Source guards and the AppSource build gate ([tools/AppSourceBuildGate.md](tools/AppSourceBuildGate.md)) |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` and `bc28-w1`, both defined in
  `app/.vscode/launch.json` (git-ignored). Publish and run the unit tests on both.
- Compile locally with `alc.exe` plus CodeCop, UICop and AppSourceCop. The build is expected to be
  warning-free; CI runs the same analyzers on the app and the test app with `failOn: warning`.
  `app.json` suppresses only **AS0081**, for the `internalsVisibleTo` entry the test app needs; the
  Default build removes both before compiling.
- Command-line `alc` does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the
  ` ori` suffix yourself.
- Source guards (`.github/workflows/SourceGuards.yaml`): no call stack in responses, validated
  `tableView`, nothing obsolete, permission coverage, Icelandic keyword counts, contract-guard
  regressions, unique object and enum value IDs, build inputs (allocations and the Foundation
  floor) and the compiler symbol-alias gate. Open guard items:
  - #32 Icelandic translation: after a compile, run `tools/Update-IcelandicXlf.ps1` and commit
    `app/Translations/Bifrost Inventory.is-IS.xlf`.
  - #33 Mixed language labels: user-facing labels need an `is-IS=` comment. Locked wire names stay
    Locked and are not translated.
  - #31 Help links: the Inventory pages on the documentation site are added in
    businesscentralal/bifrost.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`; agent context is in [AGENTS.md](AGENTS.md).

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://docs.bifrost.origo.is>.

| What | Where |
| --- | --- |
| Product documentation | <https://docs.bifrost.origo.is/en-us/inventory/> |
| In-product help (en-US and is-IS) | <https://docs.bifrost.origo.is/en-us/help/inventory/inventory-setup> |
| Privacy statement and EULA | <https://docs.bifrost.origo.is/en-us/licensing/privacy/>, <https://docs.bifrost.origo.is/en-us/licensing/eula/> |
| AppSource listing and release checklist | [app/docs/appsource/](app/docs/appsource/README.md) |
| Contract error notes | [docs/contracts.md](docs/contracts.md) |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

Message-type contracts are also served by the app at runtime through `Help.Bifrost.Get` and
`Help.Implementation.Get`.

### Context-Sensitive Help

`app.json` declares `contextSensitiveHelpUrl` = `https://docs.bifrost.origo.is/{0}/help/inventory/`
and `supportedLocales` `["en-US", "is-IS"]`, so every help page must exist in both locales.

| Slug | Pages that use it |
| --- | --- |
| `inventory-setup` | `Inventory Setup ori` |

---

© 2026 Origo ehf.

### Source-bound item tracking

`Inventory.Tracking.Assign` now requires `source: {"type":"PurchaseLine", "systemId":"<line GUID>"}` (also `SalesLine` and `TransferLine`). Send a positive base `quantity` plus `lotNo`, `serialNo` or `packageNo`; serial quantity must be one. Optional `itemNo` must match the source. For multiple allocations use `entries` with those tracking values. Read `Inventory.Tracking.Get` with the same source, then remove one unreserved `ReservationEntry` using `Inventory.Tracking.Delete` with that source and its `entryNo`. The calls use native tracking and do not insert unlinked tracking specifications.

`Inventory.Transfer.UndoReceipt` is disabled and removed from the active shipped roster because the supported platform has no native transfer receipt undo. Its released enum identifier remains solely for binary compatibility; it does not undo receipts. Return received goods with a new transfer order. `Inventory.Transfer.UndoShipment` refuses already-received lines with `PreconditionFailed` and that next step.

Tracking write helper: codeunit `10076925 Inventory Tracking Write ori`; native regressions: `96974 Inv. Source Tracking Tests ori`. The explicit test-only MCP fixture `96973` adds owned tracking sources.

### Confirm irreversible requests (Foundation core#1151)

On Foundation versions that expose `expectedCount` in the composed help contract, all nine
Inventory types declaring `irreversible` use the Foundation confirmation protocol:
`Inventory.AdjustCost.Run`, `Inventory.CostToGL.Post`, `Inventory.Revaluation.Post`,
`Inventory.PhysInventory.Post`, `Inventory.Reclassification.Post`, `Inventory.TransferOrder.Post`,
`Inventory.AssemblyOrder.Post`, `Inventory.Transfer.UndoShipment` and `Inventory.Assembly.UndoPost`.
Call without `data.expectedCount` first: `ConfirmationRequired` reports the count in `expected`
and changes no business data. Inspect the preview and repeat the same request with that count.
A stale or wrong count returns `ConfirmationMismatch` and changes nothing. These types use
Foundation's default single-subject count of **1** (one document, batch or invocation), not
the number of journal lines or ledger entries; confirmation does not prove the target exists.
The handler still validates the target, domain and native posting permissions afterwards.
Foundation's company confirmation setting controls whether an omitted count is required; a
supplied count is always checked. Never disable confirmation to make a request succeed.
The minimum supported Foundation remains 28.0.3.530, which predates this protocol; inspect
the deployed help contract before sending confirmation controls to that version.

Write-type error chapters may include Foundation's shared `Retryable` entry. Preserve the
app-owned errors and follow the shared retry guidance; an irreversible call is not a safe retry.

### Requisition worksheet planning (#131)

`Purchase.Requisition.Calculate` accepts `templateName`, `batchName`, ISO `startingDate` and
`endingDate`, plus optional native `itemFilter`, `locationFilter` and `variantFilter`. It returns
`lines` (lineNo, itemNo, quantity, vendorNo, locationCode, variantCode, dueDate, actionMessage,
replenishmentSystem) and `noOfLines`. Matching lines are replaced only in that worksheet;
other worksheets are preserved. Templates must be non-recurring Requisition templates without
automatic batch renaming. Unknown worksheets return `RecordNotFound`.

`Purchase.Requisition.CarryOut` accepts the same worksheet selector and optional `lineNos`
(a nonempty array of up to 500 distinct positive existing line numbers). Omission selects every
line, including unaccepted suggestions; a successful call accepts and consumes the selection.
It returns `linesCarriedOut`, `purchaseOrders` and `transferOrders`, each order as `{ "orderNo": "…" }`.
Every selected line is validated before writes. Only positive item suggestions with New or blank
action and Purchase or Transfer replenishment are accepted. Existing-document references,
drop shipments, special orders, Cancel, Change Qty. and rescheduling are refused. Unselected
lines remain. Native failures return `BusinessCentralError` and roll back the whole call.

Calculate is `write`; CarryOut is `irreversible`, without posting or printing. `expectedCount`
confirms **one worksheet selection**, always 1, rather than lines or created orders. The types
require Full Access plus native worksheet/order permissions. No additional setup domain switch
or posting permission is introduced because order creation does not post. Native report 699 is
the purchase/transfer requisition mode; #117 owns the separate regenerative/net-change planning
reports. Both facades can reuse the internal worksheet and native event helpers added here.

New objects: codeunits 10076941 Calculate, 10076942 CarryOut, 10076943 atomic process,
10076944 worksheet validation/serialization, 10076945 scoped native subscribers;
enum extension 10076849; tests 96947.
### Price-list objects (#135)

| IDs | Kind | Objects |
|---|---|---|
| 10076980–10076984 | Codeunits | Price List Set Impl ori, Price List Activate Impl ori, Price List Process ori, Price List Contract ori, Price List Restrict ori |
| 10076980 | Enum extension | MsgType.PriceList.Ext ori, values 10076980 and 10076981 |
| 96987 | Test codeunit | Price List Tests ori |

See [price-list maintenance](docs/price-lists.md) for native sales/purchase field mapping and activation refusals.

### Create, finish and post physical inventory orders / Stofna, ljúka og bóka birgðatalningarpantanir

```json
{"type":"Inventory.PhysInventoryOrder.Create","data":{"itemNoFilter":"1000"}}
{"type":"Inventory.PhysInventoryOrder.Finish","data":{"documentNo":"PI0001","counts":[{"recordingNo":1,"lineNo":10000,"quantity":8}]}}
{"type":"Inventory.PhysInventoryOrder.Post","data":{"documentNo":"PI0001","expectedCount":1}}
```

`Inventory.PhysInventoryOrder.Create` requires an explicit `itemNoFilter` (native Item No. filter, maximum 250 characters). Optional `locationCode` selects one exact location; otherwise native calculation includes all locations. `postingDate` defaults to WorkDate. `includeZero` includes zero expected quantities; `includeUntransacted` also includes items without transactions and requires `includeZero: true`. The response lists the native `documentNo`, `systemId`, `lineCount`, and `recordings` containing `recordingNo` and their `lines` with `lineNo`, item, variant, location, bin, quantity and recorded state. An empty calculation leaves no order behind.

`Inventory.PhysInventoryOrder.Finish` takes `documentNo` (or the same number in `subject`) and optional `counts`, for example `[{"recordingNo":1,"lineNo":10000,"quantity":8}]`. Quantities use the recording line unit of measure. Zero means counted zero. Serial, lot and package numbers can be supplied as `serialNo`, `lotNo`, `packageNo`; native tracking validation applies. Additional or split tracking lines must first be prepared in the native client. Every nonempty recording line must already be recorded or receive a count in this call. Finishing open recordings and the order computes differences without posting. A later refusal rolls back earlier quantities and finishing in the same call.

`Inventory.PhysInventoryOrder.Post` posts the finished order through native posting and returns `postedDocumentNo`, verified against the created posted header. It declares `irreversible`. **expectedCount counts physical inventory order headers: exactly one order, not lines, recordings or units.** Foundation's confirmation policy applies. Post needs native item posting permission as well as native physical inventory permissions. A completed Finish or Post cannot be repeated. Create and Finish declare `write`; all three respect the existing Physical Inventory domain switch and execute grants in `BIFROST Full ori`. No new product page or action is added.

`Create` stofnar birgðatalningarpöntun með stöðluðum útreikningi og skráningu. `itemNoFilter` er nauðsynleg sía á vörunúmer; `locationCode` velur eina birgðageymslu. `includeZero` tekur með núllmagn og `includeUntransacted` vörur án færslna og krefst `includeZero: true`. Svarið tilgreinir pöntunar-, skráningar- og línunúmer.

`Finish` tekur `documentNo` eða sama númer í `subject` og valfrjálsar `counts` með `recordingNo`, `lineNo` og `quantity`. Magn er í mælieiningu línunnar; núll er gild talning. Hægt er að senda `serialNo`, `lotNo` og `packageNo`; stöðluð rakningarprófun gildir. Undirbúið viðbótarlínur eða skiptingu rakningar í staðlaða biðlaranum. Allar línur verða að vera taldar áður en skráningum og pöntun er lokið. Mismunur er reiknaður án bókunar. Höfnun afturkallar allar breytingar kallsins.

`Post` bókar eina lokna pöntun og skilar `postedDocumentNo`. **expectedCount telur hausa birgðatalningarpantana: eina pöntun, ekki línur, skráningar eða einingar.** Staðfestingarreglur Foundation gilda. Bókun er varanleg og krefst staðlaðrar vörubókunarheimildar. Ekki er hægt að endurtaka lokna eða bókaða aðgerð. Svið Birgðatalningar og staðlaðar heimildir gilda fyrir allar þrjár aðgerðir.

### Item application selectors and quantity objects (#40)

| ID | Kind | Object |
|---|---|---|
| 10077034 | Codeunit | `Item Appl. Quantity ori` (scoped native quantity event) |
| 96994 | Test codeunit | `Item Application 40 Tests ori` |

`Inventory.ItemApplication.Get` accepts `itemNo` or `itemLedgerEntryNo`, plus exact `locationCode` and `variantCode`, and returns each application once with `inboundEntry` and `outboundEntry` projections.

See [the item application selectors and quantities](docs/contracts.md#item-application-selectors-and-quantities-40).

### Item substitution objects (#118)

| ID | Kind | Object |
|---|---|---|
| 10077020 | Codeunit | `Item Subst. Get Impl ori` |
| 96993 | Test codeunit | `Item Substitution Tests ori` |

See [the substitution request and response](docs/contracts.md#inventoryitemsubstitutionget).
