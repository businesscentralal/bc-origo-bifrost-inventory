# Bifrost Inventory

- Namespace: `Origo.Bifrost.Inventory`
- Test namespace: `Origo.Bifrost.Inventory.Test`
- Object range: 10036885–10036934 and 70013400–70013499 (app; block 2 registered 11.09.2026, workbook Solution Allocations row 19), 96900–96999 (tests)
- Foundation dependency: Bifrost Foundation 28.0.1.0; verified against 28.0.1.496
- Permissions: PermissionSetExtension only onto `BIFROST Read ori` / `BIFROST Full ori`
- No own assignable permission set; no `Setup ori` tabledata grants

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
