# Bifrost Inventory

- Namespace: `Origo.Bifrost.Inventory`
- Test namespace: `Origo.Bifrost.Inventory.Test`
- Object range: 10076835–10077034 (app; renumbered 20.10.2026, replaces 10036885–10036934 and 70013400–70013499), 96900–96999 (tests)
- Foundation dependency: Bifrost Foundation 28.0.3.530 (release `28.0.3`); app and test app compile against it with CodeCop/UICop/AppSourceCop at 0 warnings (19.10.2026). `application` floor 28.3.0.0.
- Permissions: PermissionSetExtension onto `BIFROST Read ori` / `BIFROST Full ori` for reads and writes
- One assignable permission set, `BIFROST InvPost ori` (10076837): posting gate (`Inv. Posting ori` write permission) plus the Inventory Setup page/table. Keep it assignable - the posting gate and the setup page depend on it.
- No Foundation `Setup ori` tabledata grants
- Context-sensitive help: `https://docs.bifrost.origo.is/{0}/help/inventory/`, slug `inventory-setup` on `Inventory Setup ori`
- AppSource build gate: see `tools/AppSourceBuildGate.md` (ported from Bifrost Attachments)

## Object IDs (app)

README "Objects" lists every object with its ID. In short:

- Tables 10076835 `Inv. Posting ori`, 10076836 `Inventory Setup ori`; page 10076835 `Inventory Setup ori`;
  enum 10076835 `Inventory Domain ori`; enum extensions on `Message Type ori` 10076835-10076846;
  permission sets 10076835-10076837 (InvAttrRead, InvAttrWrite, InvPost), extensions 10076835-10076836 (InvRead, InvWrite).
- Codeunits 10076835-10076923, grouped by domain (alphabetical by folder): lifecycle 10076835-10076836 and 10076845,
  shared reads/writes 10076837-10076843, write restrictions 10076846-10076848, assembly 10076849-10076856,
  availability 10076857, costing 10076858-10076866, item application 10076867-10076869, item category 10076870-10076872,
  item charge 10076873-10076875, item reference 10076876, period 10076877-10076879, physical inventory 10076880-10076885,
  price 10076886, reclassification 10076887-10076889, reservations 10076890-10076896, tracking 10076897-10076900,
  transfer orders 10076901-10076908, undo 10076909-10076911, item attributes 10076844 and 10076912-10076918,
  shared gates and contract parts 10076919-10076923.
- Message type enum values = the impl codeunit id (e.g. `Inventory.Cost.Get` 10076860 = `Cost Get Impl ori`).
  Exception: `Inventory.PhysInventory.RecordCount` = 10076924, because it shares `Phys. Invt. Record Impl ori`
  (10076882) with `Inventory.PhysInventory.Record`.
- Codeunits 10076924-10076929 are taken on main; 10077028-10077029 are `Sales Get Shipment Impl/Proc ori`
  (`Sales.SalesInvoice.GetShipmentLines`, enum extension 10076900). Several workers build Inventory types in
  parallel (16.11.2026: open PRs claim 10076930 and enum extension 10076847 (#195), 10076990-10076993 and enum
  extension 10076890 (#197)), so check main and every open PR before picking an ID.
  Otherwise free: 10076930-10077034 for codeunits, 10076836-10077034 for pages/enums, 10076837-10077034 for
  tables, 10076847-10077034 for enum extensions, 10076838-10077034 for permission sets.
- 10077032-10077033 are `Sales Ret. Ord. Post. Impl/Proc ori` (`Sales.ReturnOrder.CreateFromPosted`, enum value 10077032, enum extension 10076906, test codeunit 96991). 10077030-10077031 and test codeunit 96990 are used by earlier open PRs. Check main and every open PR before picking an ID. 10077034 is free at the top of the range.
- `Inventory Domain ori` values 11 ItemReference, 12 Availability, 13 ItemCharge, 14 ItemCategory; `Inventory Setup ori`
  fields 21-24. New setup rows and the tagged issue147 upgrade enable domains from company usage; existing enabled switches are never turned off.

## Test object IDs (unchanged by the renumbering)

- 96950-96959 (Item Ref. Resolve Tests/Perm, Avail. By Period Tests/Perm, Item Charge Tests/Perm,
  Item Category Tests/Perm, Reserv. AutoReserve Tests/Perm) and 96962 `Order Tracking Get Tests`.
- Costing, tracking and physical inventory: codeunits 96927, 96933, 96936-96946; permission sets 96934-96936.
- 96995 `Sales Get Shipment Tests`. (Open PRs claim 96980 (#193), 96981 (#195), 96988 (#197).)
- Free (16.11.2026, any test object type): 96924-96926, 96928-96929, 96947-96949, 96960-96961, 96964-96969, 96982-96987, 96989-96994, 96996-96999. Check main and open PRs first.
