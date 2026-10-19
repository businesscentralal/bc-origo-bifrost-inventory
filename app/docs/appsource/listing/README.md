# AppSource offer: Bifrost Inventory

Everything to enter in Partner Center for this offer, page by page, as Microsoft's offer pages ask
for it (Business Central offer). Built from the app's main branch and the documentation. No message
type names, as on the public site. Review before publishing.

This replaces the attributes-only draft on branch `appsource/listing` (06.10.2026). That draft
described only the four item attribute message types; the app now covers eleven inventory domains.

## Files in this folder

| File | Use | Partner Center page | State |
|---|---|---|---|
| `logo-216.png` | Large logo, 216 × 216 PNG, in the style of Bifrost Foundation's | Offer listing › Logos | Carried over from the draft |
| `screenshots/*.png` | Screenshots, 1280 × 720 PNG (3 to 5 required) | Offer listing › Screenshots | 3 attribute screenshots carried over; more needed, see below |
| `description.html` | Description with the allowed HTML tags | Offer listing › Description | New, whole app |
| `description.md` | The same as plain text | (for review) | New, whole app |
| `product-sheet.pdf` | One-page marketing sheet (1 to 3 PDFs required) | Offer listing › Supporting documents | **Missing** - the draft's sheet covered attributes only and was not carried over |

## 1. Offer setup

| Field | Value |
|---|---|
| Offer alias | Bifrost Inventory |
| Customer leads / listing option | Same as Bifrost Foundation |

## 2. Properties

| Field | Value | Subcategories |
|---|---|---|
| Primary category | Operations & Supply Chain | Inventory Management; Information Management & Connectivity |
| Secondary category | Commerce | Product Information & Content Management |
| Industry | Distribution | — |
| Industry | Retail & Consumer Goods | Retailers |
| App version | The version of the `.app` you upload (the pipeline sets it) | |
| Terms and conditions (URL) | https://docs.bifrost.origo.is/en-us/licensing/eula/ | |

Check the subcategory names against the current Partner Center list before entering them.

## 3. Offer listing

| Field | Value | Length / limit |
|---|---|---|
| Name | Bifrost Inventory | 17 / 200 |
| Search results summary | Run transfers, assembly, counts, tracking and costing in Business Central from other systems. | 93 / 100 |
| Description | `description.html` | about 2,600 / 5,000 |
| Search keywords | Inventory, Warehouse integration, Item tracking | 3 / 3 |
| Products your app works with | Dynamics 365 Business Central | 1 / 3 |
| Help link | https://docs.bifrost.origo.is/en-us/inventory/ | must differ from Support URL |
| Privacy policy link | https://docs.bifrost.origo.is/en-us/licensing/privacy/ | |
| Support contact (name, e-mail, phone, URL) | Same as Bifrost Foundation; Support URL https://www.origo.is/ | not shown to customers |
| Engineering contact | Same as Bifrost Foundation | not shown to customers |
| Supporting documents | `product-sheet.pdf` (to be made) | 1 to 3 PDFs |
| Logo | `logo-216.png` | PNG |
| Screenshots | see below | 3 to 5, 1280 × 720 PNG |
| Videos | optional; none yet | up to 4 |

Links use the documentation's own domain, docs.bifrost.origo.is, the same addresses as the app's
`app.json`. The Inventory pages on the site are added on branch `docs/publish-inventory` in
businesscentralal/bifrost; check that they are live before submitting.

Microsoft's logo guidance says no text on the logo; Bifrost Foundation's logo has text, so this one
follows Foundation for a consistent family.

### Screenshots and captions

Carried over (taken in the Bifrost sandbox, CRONUS demo company, demo data, 06.10.2026; company name,
user names, e-mail addresses and IDs were replaced before capture):

| File | Caption |
|---|---|
| `screenshots/01-item-card.png` | Item attributes kept up to date on the item card. |
| `screenshots/02-attribute-values.png` | Values set by an assistant or another system, checked before they change. |
| `screenshots/03-attributes.png` | Define new attributes and their options before any item uses them. |

Still needed (not taken yet; capture them in a demo company with demo data, 1280 × 720, and replace
names, e-mail addresses and IDs before capture):

| Proposed file | What to show | Proposed caption |
|---|---|---|
| `screenshots/04-inventory-setup.png` | The Inventory Setup page with its domain switches | Turn each inventory area on or off per company. |
| `screenshots/05-transfer-order.png` | A transfer order created and released by a message, on the Transfer Order page | Transfer orders created and released from another system. |
| `screenshots/06-phys-inventory.png` | A physical inventory journal filled by Calculate and Record | Counts recorded from a scanner or an assistant, ready to post. |

Five screenshots is the maximum; drop one attribute screenshot if all three new ones are taken.

## 4. Availability

Markets: the same as Bifrost Foundation. The fourteen countries declared in `app/AppSourceCop.json`
are in [`../partner-center-markets.csv`](../partner-center-markets.csv).

## 5. Technical configuration

Upload the app's `.app` file from the release build. Dependency: Bifrost Foundation 28.0.3.530 or
later.

## 6. Supplemental content

| Field | Value |
|---|---|
| Supported editions | Essentials and Premium |
| Key usage scenario, test accounts, test app | No longer used in validation (Microsoft); leave empty unless Partner Center requires it |

---
Drafted with the help of Claude (Anthropic); review before publishing. Origo's AI policy (STE-0002):
the person who publishes is responsible for the content.
