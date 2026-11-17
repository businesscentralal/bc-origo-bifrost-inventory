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
  shared gates and contract parts 10076919-10076923, assembly reads 10076965-10076966 (`Inventory.AssemblyToOrder.Get`,
  `Inventory.AssemblyBOM.Get`, #116; enum values 10076965-10076966 in enum extension 10076960).
- Message type enum values = the impl codeunit id (e.g. `Inventory.Cost.Get` 10076860 = `Cost Get Impl ori`).
  Exception: `Inventory.PhysInventory.RecordCount` = 10076924, because it shares `Phys. Invt. Record Impl ori`
  (10076882) with `Inventory.PhysInventory.Record`. Codeunit 10076924 is `Inventory Wizard Reg. ori`; the shared number is a different object type.
- Preserve released Purchase Returns codeunit/message value 10076930 and enum extension 10076847.
  Unreleased Planning uses `Plan Wksh Calc Impl ori` codeunit/message value 10076938,
  `Plan Wksh Carry Impl ori` 10076939, `Req. Worksheet Engine ori` 10076946 and enum extension 10076947.
  Codeunits 10076925-10076929 remain allocated (tracking through assembly preview). Planning allocations were checked against main and open PR bodies (including #224 and #203);
  check main and open PRs. Do not reuse open-PR allocations; 10076860 and 10076906 remain allocated.
  Page, table and permission-set ranges are unchanged where objects have not been allocated.
- 10077032-10077033 are `Sales Ret. Ord. Post. Impl/Proc ori` (`Sales.ReturnOrder.CreateFromPosted`, enum value 10077032,
  enum extension 10076906, test codeunit 96991). 10077030-10077031 and test codeunit 96990 belong to earlier open PRs;
  10077034 is the Item Application quantity helper. Check source and open PRs before choosing an ID.
- `Inventory Domain ori`: 11 ItemReference, 12 Availability, 13 ItemCharge, 14 ItemCategory, 15 ItemSubstitution,
  16 PurchaseReturns and 17 Planning. Setup fields 21-27 correspond to these domains; preserve released fields
  25 Item Substitution and 26 Purchase Returns. Planning is unreleased field 27, wizard slot 18.
  New setup rows and the tagged issue147 upgrade enable domains from company usage; existing switches are never turned off.
  Upgrade tag `Origo.Bifrost.Inventory-PlanningDomain-20261117` turns on Planning only.

## Test object IDs (unchanged by the renumbering)

- 96950-96959 (Item Ref. Resolve Tests/Perm, Avail. By Period Tests/Perm, Item Charge Tests/Perm,
  Item Category Tests/Perm, Reserv. AutoReserve Tests/Perm) and 96962 `Order Tracking Get Tests`.
- Costing, tracking and physical inventory: codeunits 96927, 96933, 96936-96946; permission sets 96934-96936.
- Free: 96960-96961, 96963-96979.
- #106 (`Inventory.TrackingInfo.Get`): codeunit and enum value 10077010, enum extension 10076915, test codeunit 96992.
  On main 96963 and 96970-96979 are already used, so check `test/` before taking an ID from the free list above.

## Requisition worksheet operations (#131)

- Codeunits 10076941–10076945, enum extension 10076849, message values 10076941–10076942, test codeunit 96947.
- Bounded option A (Gunnar 16.11.2026): report 699 may replace only the selected worksheet's working lines; native carry-out may consume selected lines to create new purchase/transfer orders, never change existing documents. Shared helpers are intended for coordinated #117.
- Names are Purchase.Requisition.Calculate (write) and Purchase.Requisition.CarryOut (irreversible; expectedCount counts one worksheet selection). Native table permissions apply; no additional setup domain or posting gate.
## Issue 135 object claims (2026-11-16)

- Codeunits 10076980–10076984: Price List Set Impl ori, Price List Activate Impl ori, Price List Process ori, Price List Contract ori, Price List Restrict ori.
- Enum extension 10076980 MsgType.PriceList.Ext ori; values 10076980 Price.List.Set and 10076981 Price.List.Activate.
- Test codeunit 96987 Price List Tests ori. Checked against main and open Inventory PR claims.

## Issue 40 additions

- Codeunit 10077034 `Item Appl. Quantity ori`: manually bound native quantity subscriber.
- Test codeunit 96994 `Item Application 40 Tests ori`.
- 96980 `Purch. Return Create Tests`. Next free test codeunit: 96981. 96960-96961 stay free; 96963-96979 are in use.
- 96966 `Assembly Read Tests`, 96967 `Assembly Read Perm` (#116). Free: 96960-96961, 96963-96965, 96968-96979 (open PRs claim some of these; check before use).
