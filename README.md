# Bifrost Inventory

**App name:** Bifrost Inventory (display form *Bifröst birgðir*)  
**Publisher:** Origo — **Version:** 28.1.0.0 — **Target:** Cloud (BC 28.3 or later, runtime 17.0)  
**App ID:** `02701c94-c962-4825-92c7-ef9f70311a2b` — **Test app ID:** `a886b2cb-7da0-4784-8163-42956dbdd5ec`  
**Object ID ranges:** 10036885–10036934 and 70013400–70013499 (tests 96900–96999) — **Namespace:** `Origo.Bifrost.Inventory`  
**Environments:** Business Central online (SaaS) and the COSMO Alpaca development containers `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International Ltd.)

---

## Overview

Bifrost Inventory is the inventory module of the Bifröst platform. It publishes 44 Bifröst message
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

The list is the `Message Type ori` enum extensions under `app/src/Message Type/`. `Help.Bifrost.Get`
and `Help.Implementation.Get` return the same list and each type's contract at runtime.

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
| Registration | `Inventory Registration ori` (10036912) | Answers Foundation's `App Registry ori` `OnRegisterApps` and registers `Inventory Setup ori` as the app setup page. |
| Install / upgrade | `Inventory Install ori` (10036909), `Inventory Upgrade ori` (10036910) | Sets the initial-release upgrade tag; install inserts the Inventory Setup record per company. |
| Domain gate | `Inventory Domain Gate ori` (70013453) | `IsEnabled` / `AssertEnabled`: the domain flag must be on (a missing setup row counts as on) and the caller needs read, write or posting permission for the domain. |
| Posting gate | `Inv. Posting Gate ori` (70013443), `Inv. Posting ori` (70013442) | Write permission on the token table `Inv. Posting ori` is the posting permission; only `BIFROST InvPost ori` grants it. |
| Contracts | `Inventory Contract Parts ori` (70013445) | Shared contract chapters used by the implementation codeunits. |
| Write restrictions | `Item Attr. Data Restrict ori` (10036911), `Inventory Setup Restrict ori` (70013454), `Tracking Data Restrict ori` (70013457), `Reservation WriteGuard ori` (70013498) | Subscribe to Foundation's `OnAfterIsTableWriteRestrictedForDataRecords` and close their tables to `Data.Records.Set`. |

Types that need the posting permission: `Inventory.TransferOrder.Post`, `Inventory.AssemblyOrder.Post`,
`Inventory.AdjustCost.Run`, `Inventory.CostToGL.Post`, `Inventory.CostToGL.Test`,
`Inventory.PhysInventory.Post`, `Inventory.Reclassification.Post`,
`Inventory.Reclassification.PreviewPost` and `Inventory.Transfer.UndoReceipt`.

---

## Setup & Configuration

1. Install Bifrost Foundation 28.0.3.530 or later and complete its setup (Bifröst Setup).
2. Install Bifrost Inventory. The install code creates the **Inventory Setup** record in every
   company, and Bifröst Setup lists the app with **Inventory Setup** as its setup page.
3. Open **Inventory Setup** (search for *Inventory Setup*, or open it from Bifröst Setup) and switch
   the domains on or off: Attributes, Transfer Orders, Assembly, Reservations, Item Tracking,
   Physical Inventory, Costing, Reclassification, Item Application, Inventory Period, Item Price,
   Item Reference, Availability, Item Charge and Item Category.
   All domains start on except **Reclassification**, which starts off once the setup record exists.
   Item Reference, Availability, Item Charge and Item Category start on in a new company; a company
   that already had an Inventory Setup record before they were added gets them off after the
   upgrade, so turn them on here.
4. Grant permissions:
   - Foundation's `BIFROST Read ori` and `BIFROST Full ori` roles are extended by
     `BIFROST InvRead ori` and `BIFROST InvWrite ori`; no separate assignment is needed for reads
     and writes.
   - Apart from the item attribute tables, the app grants no standard table data. The item
     reference, availability, item charge, item category, auto-reserve and order tracking types
     need the caller's own Business Central permissions on the tables they touch (Item, Item
     Variant, Item Reference, Location, Item Category, Item Charge Assignment, Reservation Entry and
     the documents involved); they answer `PermissionDenied` when one is missing.
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
| 70013442 | `Inv. Posting ori` | Permission token for the posting gate; stores no records |
| 70013451 | `Inventory Setup ori` | Per-company domain switches |

### Pages

| ID | Name | Purpose |
| --- | --- | --- |
| 70013452 | `Inventory Setup ori` | Domain switches; context-sensitive help slug `inventory-setup` |

### Enums and enum extensions

| ID | Name | Purpose |
| --- | --- | --- |
| 70013450 | `Inventory Domain ori` | The fifteen domains |
| 10036892 | `MsgType.EnumExt ori` | 34 message types on Foundation's `Message Type ori` |
| 70013455 | `MsgType.TrackAvail.EnumExt ori` | `Inventory.TrackingAvailability.Get` |
| 70013456 | `MsgType.PhysRecord.EnumExt ori` | `Inventory.PhysInventory.Record` |
| 70013458 | `MsgType.Reserv.Create.Ext ori` | Reservation types |
| 70013459 | `MsgType.PhysInvt.EnumExt ori` | Physical inventory types |
| 70013469 | `MsgType.CostGet.EnumExt ori` | `Inventory.Cost.Get` |
| 70013492 | `MsgType.Reserv.EnumExt ori` | Reservation types |
| 10036917 | `MsgType.ItemRef.EnumExt ori` | `Inventory.ItemReference.Resolve` |
| 10036918 | `MsgType.AvailPer.EnumExt ori` | `Inventory.AvailabilityByPeriod.Get` |
| 10036919 | `MsgType.ItemChg.EnumExt ori` | `Inventory.ItemCharge.Assign`, `Inventory.ItemCharge.Get` |
| 10036920 | `MsgType.ItemCat.EnumExt ori` | `Inventory.ItemCategory.Get`, `Inventory.ItemCategory.Set` |
| 10036921 | `MsgType.ReservAuto.Ext ori` | `Inventory.Reservation.AutoReserve`, `Inventory.OrderTracking.Get` |

### Codeunits

| IDs | Area | Codeunits |
| --- | --- | --- |
| 10036897–10036900, 10036905–10036908 | Item attributes | `Item Attribute Get/Create/Update Impl ori`, `Item AttrDef Create Impl ori`, their process codeunits, `Item Attribute Resolve ori` |
| 10036909–10036912 | Lifecycle | `Inventory Install ori`, `Inventory Upgrade ori`, `Item Attr. Data Restrict ori`, `Inventory Registration ori` |
| 70013413–70013420 | Transfer orders | Create, Release, Reopen (+ process), Post, Preview Post, Statistics, `Transfer Post Subscriber ori` |
| 70013421–70013428 | Assembly orders | Create, Refresh Lines, Release, Reopen (+ process), Post, Preview Post, Statistics |
| 70013443, 70013445, 70013453, 70013454, 70013457, 70013498 | Shared | Posting gate, contract parts, domain gate, setup/tracking/reservation write restrictions |
| 70013460–70013462, 70013467, 70013468, 70013488 | Costing | Adjust Cost Run (+ process), Cost To GL Post/Test, Cost Get, Revaluation Calc |
| 70013464–70013466, 70013472, 70013496 | Physical inventory | Calculate, Record, Preview, Post |
| 70013470, 70013471, 70013473 | Item tracking | Assign, Delete, Availability Get |
| 70013474, 70013475, 70013493 | Reclassification | Check, Preview, Post |
| 70013476–70013478 | Reservations | Create, Get, Cancel |
| 70013480–70013482 | Undo | Transfer shipment, transfer receipt, assembly |
| 70013483–70013486 | Periods and price | Period Get/Reopen/Close, Price Update |
| 70013490–70013492 | Item application | Get, Unapply, Reapply |
| 10036917 | Item references | `Item Ref. Resolve Impl ori` |
| 10036918 | Availability | `Avail. By Period Impl ori` |
| 10036919–10036921, 10036927 | Item charges | Assign (+ process), Get, `Item Charge Restrict ori` |
| 10036922–10036924, 70013499 | Item categories | Get, Set (+ process), `Item Category Restrict ori` |
| 10036925, 10036926, 10036929, 70013439 | Reservations | Auto Reserve (+ process), Order Tracking Get, `Order Tracking Transfer ori` |

### Permission sets

| ID | Name | Assignable | Purpose |
| --- | --- | --- | --- |
| 70013444 | `BIFROST InvPost ori` | Yes | Posting gate, Inventory Setup page and table |
| 10036915 | `BIFROST InvAttrRead ori` | No | Read grants on the standard item attribute tables |
| 10036916 | `BIFROST InvAttrWrite ori` | No | Write grants on the standard item attribute tables |
| 10036915 | `BIFROST InvRead ori` (extension) | — | Extends Foundation's `BIFROST Read ori` |
| 10036916 | `BIFROST InvWrite ori` (extension) | — | Extends Foundation's `BIFROST Full ori` |

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
