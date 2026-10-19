# Bifrost Inventory

- Namespace: `Origo.Bifrost.Inventory`
- Test namespace: `Origo.Bifrost.Inventory.Test`
- Object range: 10036885–10036934 and 70013400–70013499 (app; block 2 registered 11.09.2026, workbook Solution Allocations row 19), 96900–96999 (tests)
- Foundation dependency: Bifrost Foundation 28.0.3.530 (release `28.0.3`); app and test app compile against it with CodeCop/UICop/AppSourceCop at 0 warnings (19.10.2026). `application` floor 28.3.0.0.
- Permissions: PermissionSetExtension onto `BIFROST Read ori` / `BIFROST Full ori` for reads and writes
- One assignable permission set, `BIFROST InvPost ori` (70013444): posting gate (`Inv. Posting ori` write permission) plus the Inventory Setup page/table. Keep it assignable - the posting gate and the setup page depend on it.
- No Foundation `Setup ori` tabledata grants
- Context-sensitive help: `https://docs.bifrost.origo.is/{0}/help/inventory/`, slug `inventory-setup` on `Inventory Setup ori`
- AppSource build gate: see `tools/AppSourceBuildGate.md` (ported from Bifrost Attachments)

## Object IDs used by #101, #103, #108, #111, #112 (PR claude/inv-new-types)

- App codeunits: 10036917 `Item Ref. Resolve Impl ori`, 10036918 `Avail. By Period Impl ori`,
  10036919 `Item Charge Assign Impl ori`, 10036920 `Item Charge Get Impl ori`, 10036921 `Item Charge Restrict ori`,
  10036922 `Item Category Get Impl ori`, 10036923 `Item Category Set Impl ori`, 10036924 `Item Category Restrict ori`,
  10036925 `Reserv. AutoReserve Impl ori`, 10036926 `Order Tracking Get Impl ori`,
  10036927 `Item Charge Assign Proc ori`, 10036929 `Order Tracking Transfer ori`,
  70013439 `Reserv. AutoReserve Proc ori`, 70013499 `Item Category Set Proc ori`.
- Enum extensions on `Message Type ori`: 10036917 (ItemRef), 10036918 (AvailPer), 10036919 (ItemChg), 10036920 (ItemCat), 10036921 (ReservAuto).
- Message type enum values = the impl codeunit id: 10036917 ItemReference.Resolve, 10036918 AvailabilityByPeriod.Get,
  10036919 ItemCharge.Assign, 10036920 ItemCharge.Get, 10036922 ItemCategory.Get, 10036923 ItemCategory.Set,
  10036925 Reservation.AutoReserve, 10036926 OrderTracking.Get.
- `Inventory Domain ori` values 11 ItemReference, 12 Availability, 13 ItemCharge, 14 ItemCategory; `Inventory Setup ori`
  fields 21-24. New domains are opt-in for companies that already have a setup row (no upgrade code switches them on).
- Tests: 96950-96959 (Item Ref. Resolve Tests/Perm, Avail. By Period Tests/Perm, Item Charge Tests/Perm,
  Item Category Tests/Perm, Reserv. AutoReserve Tests/Perm) and 96962 `Order Tracking Get Tests`.
- Free in this block: 10036928, 10036930-10036934, 96960-96961, 96963-96979.
- Reserved for other PRs, do not use here: app codeunits 70013432, 70013479; enum values 70013437, 70013438;
  test codeunits 96922-96924, 96927, 96930-96949.

## Object IDs used by #4, #5, #6 and #122 (PR #139, claude/inv-costing)

- App codeunits: 70013406 `Revaluation Post Impl ori`, 70013407 `Reval Preview Impl ori`, 70013408 `Cost Update Impl ori`,
  70013409 `Inventory Native Journal ori` (physical inventory and revaluation journals), 70013410 `Inventory Tracking Read ori`,
  70013411 `Tracking Get Impl ori`, 70013412 `Inventory Write Process ori` (one Codeunit.Run write boundary selected by
  SetOperation), 70013432 `Inventory Cost Read ori`, 70013437 `Inventory Cost Data Guard ori`, 70013438 `Inventory Card Write ori`,
  70013479 `Phys. Inv. Check Impl ori`.
- Message type enum values: 70013437 Cost.Update, 70013438 Revaluation.Post (both in enum extension 70013469 with Cost.Get),
  70013413 Revaluation.PreviewPost, 70013414-70013416 PhysInventory.Check/PreviewPost/RecordCount, 70013417 Tracking.Get.
- Tests: codeunits 96927, 96933, 96936-96946; permission sets 96934-96936.
- Free in block 2 after this PR: codeunits 70013400-70013405, 70013429-70013431, 70013433-70013436; enum values 70013418-70013419.
