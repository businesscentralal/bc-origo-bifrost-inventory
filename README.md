# Bifrost Inventory

Bifrost feature app for Item Attribute message types on top of Bifrost Foundation.

## Message types

| Type | Direction | Purpose |
|------|-----------|---------|
| `Item.Attribute.Get` | Outbound | Read attributes/values for items |
| `Item.Attribute.Create` | Inbound | Assign attribute value to an item |
| `Item.Attribute.Update` | Inbound | Change an existing mapping |
| `Item.AttributeDefinition.Create` | Inbound | Create attribute definition (+ options) |

## Ranges

- App: 10036885–10036934
- Tests: 96900–96999

## Dependencies

- Bifrost Foundation 28.0.0.0 (`7505e808-6e52-4b96-a328-82573391297a`)

## Permissions

Ships only as PermissionSetExtension onto `BIFROST Read ori` / `BIFROST Full ori`.
