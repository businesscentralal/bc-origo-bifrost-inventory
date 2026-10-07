# AppSource offer: Bifrost Inventory

Everything to enter in Partner Center for this offer, page by page, as Microsoft's offer pages ask
for it (Business Central offer, checked 06.10.2026). Built from the app's main branch and the
documentation. No message type names, as on the public site. Review before publishing.

## Files in this folder

| File | Use | Partner Center page |
|---|---|---|
| `logo-216.png` | Large logo, PNG, in the style of Bifrost Foundation's | Offer listing › Logos |
| `screenshots/*.png` | 3 screenshots, 1280 × 720 PNG (3 to 5 required) | Offer listing › Screenshots |
| `description.html` | Description with the allowed HTML tags | Offer listing › Description |
| `description.txt` | The same as plain text | (for review) |
| `product-sheet.pdf` | One-page marketing sheet (1 to 3 PDFs required) | Offer listing › Supporting documents |

## 1. Offer setup

| Field | Value |
|---|---|
| Offer alias | Bifrost Inventory |
| Customer leads / listing option | Same as Bifrost Foundation |

## 2. Properties

| Field | Value | Subcategories |
|---|---|---|
| Primary category | Operations & Supply Chain | Information Management & Connectivity |
| Secondary category | Commerce | Product Information & Content Management |
| Industry | Distribution | — |
| Industry | Retail & Consumer Goods | Retailers |
| App version | The version of the `.app` you upload (the pipeline sets it) | |
| Terms and conditions (URL) | https://docs.bifrost.origo.is/en-us/licensing/eula/ | |

## 3. Offer listing

| Field | Value | Length / limit |
|---|---|---|
| Name | Bifrost Inventory | 17 / 200 |
| Search results summary | Keep item attributes up to date from other systems and AI assistants. | 69 / 100 |
| Description | `description.html` | 1569 / 5,000 |
| Search keywords | Item attributes, Product information, Inventory | 3 / 3 |
| Products your app works with | Dynamics 365 Business Central | 1 / 3 |
| Help link | https://docs.bifrost.origo.is/en-us/apps/ | must differ from Support URL |
| Privacy policy link | https://docs.bifrost.origo.is/en-us/licensing/privacy/ | |
| Support contact (name, e-mail, phone, URL) | Same as Bifrost Foundation; Support URL https://www.origo.is/ | not shown to customers |
| Engineering contact | Same as Bifrost Foundation | not shown to customers |
| Supporting documents | `product-sheet.pdf` | 1 to 3 PDFs |
| Logo | `logo-216.png` | PNG |
| Screenshots | see below | 3 to 5, 1280 × 720 PNG |
| Videos | optional; none yet | up to 4 |

Links use the documentation's own domain, docs.bifrost.origo.is. The app has no page of its own on the
site yet, so the help link goes to the app list; change it to the app's page once that is published.
The app's `app.json` still points to the old github.io address, which GitHub forwards to the new domain.

Microsoft's logo guidance says no text on the logo; Bifrost Foundation's logo has text, so this one
follows Foundation for a consistent family.

### Screenshots and captions

| File | Caption |
|---|---|
| `screenshots/01-item-card.png` | Item attributes kept up to date on the item card. |
| `screenshots/02-attribute-values.png` | Values set by an assistant or another system, checked before they change. |
| `screenshots/03-attributes.png` | Define new attributes and their options before any item uses them. |

Taken in the Bifrost sandbox (CRONUS demo company, demo data), 06.10.2026. The company name, user
names, e-mail addresses and IDs were replaced before capture.

## 4. Availability

Markets: the same as Bifrost Foundation.

## 5. Technical configuration

Upload the app's `.app` file from the release build. Dependency: Bifrost Foundation.

## 6. Supplemental content

| Field | Value |
|---|---|
| Supported editions | Essentials and Premium |
| Key usage scenario, test accounts, test app | No longer used in validation (Microsoft); leave empty unless Partner Center requires it |

## Description (as in `description.txt`)

```
Keep item attributes up to date from other systems and assistants.

Bifrost Inventory lets another system or an AI assistant read and maintain item attributes in Business Central. The results show on the item, under the standard item attributes; the app has no pages of its own. It is an add-on to Bifrost Foundation.

Who it is for
Companies that keep product information in more than one place, and teams that want an assistant to help enrich and clean item data.

What it does
- Shows an item's attributes in one go, including the ones that have no value yet.
- Gives an item an attribute value safely: setting the same value again changes nothing, and replacing a value happens only when asked.
- Changes a value and shows it before and after.
- Defines a new attribute, with its option values, before any item uses it.
- Feeds catalogue sync, product information enrichment and master-data work by an assistant.

Requirements and pricing
- Microsoft Dynamics 365 Business Central 28.0 or later, Essentials or Premium.
- Bifrost Foundation, available separately on AppSource.
- For prices, contact Origo (https://www.origo.is/) or your Business Central partner.
- If you are a partner, contact The App Channel (https://www.theappchannel.com/).

Bifrost Inventory does not replace Business Central or its extensions. It makes their data and business logic available to the people, routines and AI platforms your organisation already uses.
```

---
Drafted with the help of Claude (Anthropic); review before publishing. Origo's AI policy (STE-0002):
the person who publishes is responsible for the content.
