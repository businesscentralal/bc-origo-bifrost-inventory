---
title: Prepare the Inventory submission package
audience: release-owner
keywords: AppSource, Inventory, release, validation
locale: en-US
---

# Prepare the Inventory submission package

**Working material. No release candidate is certified by this package.** It collects what Partner
Center asks for and the evidence a release owner must gather before Bifrost Inventory is submitted.
Offer creation, submission and publication need separate authority; Gunnar approves every AppSource
publish. Keep `deliverToAppSource` unconfigured until an offer exists and its genuine product ID is
mapped to this app. Never reuse Foundation's or another Bifröst app's ID.

| Artifact | Purpose |
|---|---|
| [listing/README.md](listing/README.md) | Partner Center fields page by page, screenshots and captions |
| [listing/description.md](listing/description.md), [listing/description.html](listing/description.html) | Listing description, plain text and Partner Center HTML |
| [listing/logo-216.png](listing/logo-216.png) | Large logo |
| [release-checklist.md](release-checklist.md) | Release inputs, evidence and named owners |
| [partner-center-markets.csv](partner-center-markets.csv) | The fourteen countries declared in `app/AppSourceCop.json`; no validation claim |

This folder is submission material, not product help. Product and in-product help live in
businesscentralal/bifrost (<https://docs.bifrost.origo.is/en-us/inventory/>).

No credentials belong in these files.
