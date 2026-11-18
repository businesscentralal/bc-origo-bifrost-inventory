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
  enum 10076835 `Inventory Domain ori`; enum extensions on `Message Type ori` 10076835-10076847 and 10076906;
  permission sets 10076835-10076837 (InvAttrRead, InvAttrWrite, InvPost), extensions 10076835-10076836 (InvRead, InvWrite).
- Codeunits 10076835-10076923, grouped by domain (alphabetical by folder): lifecycle 10076835-10076836 and 10076845,
  shared reads/writes 10076837-10076843, write restrictions 10076846-10076848, assembly 10076849-10076856,
  availability 10076857, costing 10076858-10076866, item application 10076867-10076869, item category 10076870-10076872,
  item charge 10076873-10076875, item reference 10076876, period 10076877-10076879, physical inventory 10076880-10076885,
  price 10076886, reclassification 10076887-10076889, reservations 10076890-10076896, tracking 10076897-10076900,
  transfer orders 10076901-10076908, undo 10076909-10076911, item attributes 10076844 and 10076912-10076918,
  shared gates and contract parts 10076919-10076923, item create 10076931-10076932 (`Inventory.Item.Create`, #130; 10076925-10076929 are already used by shared codeunits),
  sales return from posted documents 10077032-10077033 (`Sales.ReturnOrder.CreateFromPosted`, #136).
  shared gates and contract parts 10076919-10076923, assembly reads 10076965-10076966 (`Inventory.AssemblyToOrder.Get`,
  `Inventory.AssemblyBOM.Get`, #116; enum values 10076965-10076966 in enum extension 10076960).
  shared gates and contract parts 10076919-10076923, item variants 10076990-10076993 (#99; enum extension 10076890).
- Message type enum values = the impl codeunit id (e.g. `Inventory.Cost.Get` 10076860 = `Cost Get Impl ori`).
  Exception: `Inventory.PhysInventory.RecordCount` = 10076924, because it shares `Phys. Invt. Record Impl ori`
  (10076882) with `Inventory.PhysInventory.Record`. Codeunit 10076924 is `Inventory Wizard Reg. ori`; the shared number is a different object type.
- Preserve released Purchase Returns codeunit/message value 10076930 and enum extension 10076847.
  Unreleased Planning uses `Plan Wksh Calc Impl ori` codeunit/message value 10076949,
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
  (10076882) with `Inventory.PhysInventory.Record`.
- Next free codeunit: 10076932 (10076924 stays unused as a codeunit so the RecordCount value does not clash with
  the convention). Taken above that: 10077020 `Item Subst. Get Impl ori` (#118) and 10077032-10077033
  `Sales Ret. Ord. Post. Impl/Proc ori` (#136). Free: 10076932-10077019, 10077021-10077029 and 10077034 for codeunits,
  10076836-10077034 for pages/enums, 10076837-10077034 for tables, 10076848-10076905 and 10076907-10077034 for enum extensions,
  10076838-10077034 for permission sets.
- 10077032-10077033 are `Sales Ret. Ord. Post. Impl/Proc ori` (`Sales.ReturnOrder.CreateFromPosted`, enum value 10077032, enum extension 10076906, test codeunit 96991). 10077030-10077031 and test codeunit 96990 are used by earlier open PRs. Check main and every open PR before picking an ID. 10077034 is free at the top of the range.
- `Inventory Domain ori` values 11 ItemReference, 12 Availability, 13 ItemCharge, 14 ItemCategory; `Inventory Setup ori`
  fields 21-24. New setup rows and the tagged issue147 upgrade enable domains from company usage; existing enabled switches are never turned off.
  (10076882) with `Inventory.PhysInventory.Record`. Codeunit 10076924 is `Inventory Wizard Reg. ori`; the shared
  number is a different object type.
- Codeunits are used through 10076930 (`Purch. Return Create Impl ori`), 10077019 and 10076947 (catalog items) and 10077032-10077033. Next free codeunit: 10076931
  (10076925-10076929 and 10076931-10077018, 10077022-10077031 are free except as taken by open PRs; 10077034 is free at the top of the range).
  Next free enum extension: 10076848 (`MsgType.PurchRet.EnumExt ori` is 10076847; 10076906 is `MsgType.SalesRetOrd.Ext ori`; 10077019 is `MsgType.Nonstock.EnumExt ori`).
  Next free page, table and permission set are unchanged from the ranges above where those objects were not taken.
- 10077032-10077033 are `Sales Ret. Ord. Post. Impl/Proc ori` (`Sales.ReturnOrder.CreateFromPosted`, enum value 10077032, enum extension 10076906, test codeunit 96991). 10077030-10077031 and test codeunit 96990 are used by earlier open PRs. Check main and every open PR before picking an ID. 10077034 is free at the top of the range.
- `Inventory Domain ori` values 11 ItemReference, 12 Availability, 13 ItemCharge, 14 ItemCategory, 15 ItemSubstitution, 16 PurchaseReturns, 17 Planning and 18 CatalogItems; `Inventory Setup ori`
  fields 21-28 (`Item Substitution` is field 25, `Purchase Returns` is field 26, `Planning` is field 27, `Catalog Items` is field 28). New setup rows and the tagged issue147 upgrade enable domains from company usage; existing enabled switches are never turned off.
  Catalog Items (#119) has its own upgrade tag `CatalogItemsUsage-20261116` that raises only that switch.
- Catalog items (#119): codeunits 10077019 `Nonstock Item Create Impl ori` (= `Inventory.NonstockItem.Create`) and
  10076947 (process), enum extension 10077019; taken from the top of the free range. Purchase returns on main kept domain value 16 and setup field 26, Planning keeps value 17, field 27 and setup-guide slot 18, so Catalog Items uses value 18, field 28 and setup-guide slot 19.
- Codeunits are used through 10076930 (`Purch. Return Create Impl ori`), 10077028-10077029 (`Sales Get Shipment Impl/Proc ori`,
  `Sales.SalesInvoice.GetShipmentLines`, enum extension 10076900, test codeunit 96995) and 10077032-10077033. Next free codeunit: 10076931
  (10076925-10076929 and 10076931-10077027 are free except as taken by open PRs; 10077034 is free at the top of the range).
  Next free enum extension: 10076848 (`MsgType.PurchRet.EnumExt ori` is 10076847; 10076900 is `MsgType.SalesGetShpt.Ext ori`;
  10076906 is `MsgType.SalesRetOrd.Ext ori`).
  Next free page, table and permission set are unchanged from the ranges above where those objects were not taken.
  Several workers build Inventory types in parallel, so check main and every open PR before picking an ID.
- 10077032-10077033 are `Sales Ret. Ord. Post. Impl/Proc ori` (`Sales.ReturnOrder.CreateFromPosted`, enum value 10077032, enum extension 10076906, test codeunit 96991). 10077030-10077031 and test codeunit 96990 are used by earlier open PRs. Check main and every open PR before picking an ID.
- `Inventory Domain ori` values 11 ItemReference, 12 Availability, 13 ItemCharge, 14 ItemCategory,
  15 ItemSubstitution and 16 PurchaseReturns; `Inventory Setup ori` fields 21-26 (`Item Substitution` is field 25; `Purchase Returns` is field 26). New setup rows and the
  tagged issue147 upgrade enable domains from company usage; existing enabled switches are never turned off.

## Test object IDs (unchanged by the renumbering)

- 96950-96959 (Item Ref. Resolve Tests/Perm, Avail. By Period Tests/Perm, Item Charge Tests/Perm,
  Item Category Tests/Perm, Reserv. AutoReserve Tests/Perm) and 96962 `Order Tracking Get Tests`.
- Costing, tracking and physical inventory: codeunits 96927, 96933, 96936-96946; permission sets 96934-96936.
- 96995 `Sales Get Shipment Tests`. (Open PRs claim 96980 (#193), 96981 (#195), 96988 (#197).)
- Free (16.11.2026, any test object type): 96924-96926, 96928-96929, 96947-96949, 96960-96961, 96964-96969, 96982-96987, 96989-96994, 96996-96999. Check main and open PRs first.
- Free: 96960-96961, 96963-96979.

## Issue 134 allocation (Alvíss, 16.11.2026)

- Codeunits / message values 10077028 Sales Undo Impl ori, 10077029 Purchase Undo Impl ori.
- Shared codeunit 10077027 Posted Line Undo ori; enum extension 10077025 MsgType.PostedUndo.Ext ori.
- Tests 96998 Posted Line Undo Tests ori (moved from 96996 on merging #133; main keeps 96996 Purch Get Receipt Tests); test fixture codeunit and page 96997 Posted Undo MCP Fixture ori.
- These IDs are within the declared ranges and avoid the allocations visible in open Inventory PRs at implementation time.

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
- 96980 `Purch. Return Create Tests` (#137).
- 96934 `Nonstock Item Create Tests` (#119); 96998 stays with main's `Posted Line Undo Tests ori`.
- Next free test codeunit: 96981, except 96998 and other IDs already used on main or by open PRs. 96960-96961 stay free. 96963-96980 are in use.
- 96960 `Item Create Tests`, 96961 `Item Create Perm` (#130). 96991 `Sales Ret. Ord. Post. Tests` (#136). Free: 96964-96969 (96963 and 96970-96979 are used; 96990 is used by an earlier open PR).
- 96980 `Purch. Return Create Tests`. Next free test codeunit: 96981. 96960-96961 stay free; 96963-96979 are in use.

## PR #198 main-merge ID reconciliation

- Item Create uses implementation codeunit and enum value 10076932, process codeunit 10076931, and enum extension 10076848. Purchase Return keeps codeunit/enum value 10076930 and enum extension 10076847 from main. These taken IDs supersede the free-ID notes preserved above.

## PR #224 main-merge ID reconciliation

- Standard cost collides with Item Create on codeunit 10076932, enum value 10076932 and enum extension 10076848. The PR side moves: `Std. Cost Suggest Impl ori` and `Inventory.StandardCost.Suggest` are 10076938; `MsgType.StdCost.EnumExt ori` is 10076850. `Inventory.StandardCost.Implement` stays 10076933. Item Create keeps 10076932 and enum extension 10076848. Codeunits 10076934–10076937 are unchanged.
- 96966 `Assembly Read Tests`, 96967 `Assembly Read Perm` (#116). Free: 96960-96961, 96963-96965, 96968-96979 (open PRs claim some of these; check before use).

## PR #201 main-merge ID reconciliation

- Catalog tests use codeunit 96934 (formerly 96998); main keeps codeunit 96998 `Posted Line Undo Tests ori`. Codeunit 96934 was unused on main and all 12 open Inventory PR heads on 2026-11-18. Permission set 96934 is a different object type and remains unchanged. Test bodies and assertions are unchanged.

- Catalog Items process codeunit is 10076947 (formerly 10077021); main keeps 10077021 `Transfer Receive Impl ori`. Checked against current main and all 20 other open PR heads. These taken IDs supersede the historical free-ID notes above. The catalog message enum value remains 10077019.
## Issue 133 object claims (2026-11-17 main-merge)

- Main-merge ID collision: codeunit 10077030 stays `Reserv. Supply Filter ori`. `Purch Get Receipt Impl ori` and message value `Purchase.PurchaseInvoice.GetReceiptLines` are 10077018 (formerly 10077030). 10077027 is claimed by open pull requests #206 and #215; 10077028–10077029 are claimed by #203. Process codeunit 10077031 and enum extension 10077030 `MsgType.PurchGetRcpt.Ext ori` stay. These taken IDs supersede the free-ID notes preserved above.
- Test codeunit 96996 `Purch Get Receipt Tests`.
- Checked against main `ee7110286259dc00a9a539832a93a4be27a61273` and the open Inventory branches on 2026-11-17. Do not reuse 10077018, 10077030 or 10077031.

## PR #221 test ID reconciliation

- Main keeps codeunit 96964 `Inv. 186 Blank Line Tests ori`. Reclassification uses codeunit 96925 `Reclass Journal Tests ori` (formerly 96964), within the existing 96900–96999 test range. Checked main and every open Inventory PR head on 2026-11-17; 96925 was unused. Test bodies and assertions are unchanged.
## PR #201 Planning merge reconciliation

- Main-merge 2026-11-17: Planning keeps domain value 17, setup field 27 and wizard slot 18. Catalog Items uses the next free domain value 18, setup field 28 and wizard slot 19; both tagged migrations remain independent.
