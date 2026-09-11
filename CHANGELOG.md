# Changelog

## Bifrost Inventory 28.0.0.0

### Added
- App scaffold for Bifrost Inventory (Foundation 28.0.0.0 dependency, idRanges 10036885–10036934).
- Message types: `Item.Attribute.Get`, `Item.Attribute.Create`, `Item.Attribute.Update`, `Item.AttributeDefinition.Create`.
- PermissionSetExtensions `BIFROST InvRead ori` / `BIFROST InvWrite ori` onto Foundation Read/Full (no own assignable set).
- AC-9: `Data.Records.Set` refused on Item Attribute tables 7500/7501/7504/7505; Get remains allowed.
