# Maintain and activate a price list

```json
{"type":"Price.List.Set","data":{"code":"AGENT-SALES","priceType":"Sales","description":"Agent sales prices","lines":[{"lineNo":10000,"assetType":"Item","productNo":"1000","unitOfMeasureCode":"PCS","minimumQuantity":2,"unitPrice":25.5,"lineDiscountPercent":5,"startingDate":"2026-01-01","endingDate":"2026-12-31"}]}}
```

Set creates or updates a Draft list using native table validation. It upserts lines by `lineNo`; omitted lines are preserved. It never deletes a line or activates a list.

| Key | Meaning |
|---|---|
| `code` | Required non-empty price-list code, at most 20 characters. No subject or tableView selector. |
| `priceType` | Required `Sales` or `Purchase`. Cannot change an existing list's price type. |
| `sourceType`, `sourceNo` | Sales defaults to `All Customers`, Purchase to `All Vendors`. Use `Customer` or `Vendor` and the corresponding number for a specific partner. Native validation checks it. |
| `description`, `currencyCode` | Optional native header fields (250 and 10 characters). Empty currency means local currency. |
| `startingDate`, `endingDate` | Optional header defaults in `yyyy-mm-dd` format. Native default-update rules apply. |
| `lines` | Required array of 1..200 objects. Every object requires a unique positive integer `lineNo` and `productNo` (at most 20 characters). |
| `lines[].assetType` | New lines default to `Item`. Also accepts `Resource`, `Resource Group`, `Item Discount Group`, `G/L Account`. Native asset validation applies. |
| `lines[].unitOfMeasureCode` | Optional native unit, at most 10 characters. |
| `lines[].minimumQuantity` | Optional nonnegative JSON number. |
| `lines[].unitPrice` | Optional nonnegative JSON number. Maps to **Unit Price** on sales lists and **Direct Unit Cost** on purchase lists. |
| `lines[].lineDiscountPercent` | Optional JSON number from 0 through 100. |
| `lines[].startingDate`, `lines[].endingDate` | Optional native line validity dates. |

Unknown keys and wrong JSON scalar types are refused. Omitted fields on an unchanged product are preserved. Changing the asset or header defaults follows native Business Central rules. A native error in a normal call rolls back the entire upsert, including earlier lines. An `Omit Commit` caller owns the transaction and must roll it back on error.

```json
{"type":"Price.List.Activate","data":{"code":"AGENT-SALES"}}
```

Activate requires a non-empty Draft list. It uses **Price List Management** to verify all lines and detect duplicates inside the list and against other price lists. It then uses native header status validation to activate the header and its lines. It does not post or change existing documents.

A duplicate refusal returns `PreconditionFailed`, localized `nextStep`, and `conflicts[]` entries with `code` and `lineNo`. Both the selected list and conflicting foreign list are identified. No duplicate is deleted or automatically resolved. Review the lines on the Price Lists page and correct them before retrying.

Success returns `priceListCode`, `priceListStatus` and `linesWritten` (Set) or `linesActivated` (Activate). Set also returns `created` and `priceType`. Missing activation lists answer `RecordNotFound`. Non-Draft or empty activation lists answer `PreconditionFailed`. Invalid requests answer `InvalidParameter`; native failures answer `BusinessCentralError`. Every operation refusal supplies a `nextStep`.

Both types declare effect `write`, need the **Item Price** domain and write permission on **Price List Header** and **Price List Line**, and use Foundation licensing/version checks. `BIFROST Full ori` grants execution; native table permissions come from the caller. Generic writes to 7000/7001 are restricted even with `force`; generic reads remain available.

`Inventory.Price.Update` still changes only the Item card's Unit Price. Use `Price.List.Set` and `Price.List.Activate` for sales/purchase price lists.

## Viðhald verðlista

```json
{"type":"Price.List.Set","data":{"code":"AGENT-INNKAUP","priceType":"Purchase","lines":[{"lineNo":10000,"productNo":"1000","unitPrice":19.25}]}}
```

`Price.List.Set` stofnar eða uppfærir sölu- eða innkaupaverðlista í **Drögum** með hefðbundinni sannprófun. Hver lína þarf einkvætt jákvætt heiltölugildi `lineNo` og `productNo`. Listi þarf 1..200 línur. Línum sem er sleppt er ekki eytt. `unitPrice` merkir einingarverð á sölulista og **beinan einingarkostnað** á innkaupalista. Tölur eru JSON-tölur og dagsetningar nota `yyyy-mm-dd`.

`Price.List.Activate` yfirfer allar línur, leitar að tvíteknum verðum innan listans og gagnvart öðrum listum og virkjar haus og línur með hefðbundinni stöðusannprófun. Árekstur svarar `PreconditionFailed`, `nextStep` á íslensku og `conflicts[]` með verðlistakóða (`code`) og línunúmeri (`lineNo`). Ekkert er leyst eða fjarlægt sjálfkrafa. Yfirfarðu listann á síðunni **Verðlistar**, leiðréttu árekstra og reyndu aftur.

Kveikt verður að vera á sviðinu **Vöruverð** og kallandi þarf skrifheimild á verðlistahausa og verðlistalínur. Almenn skrif í töflur 7000/7001 eru lokuð; lestur er áfram leyfður. Báðar tegundir lýsa áhrifunum `write`; þær bóka ekki og breyta ekki skjölum sem eru til. Venjuleg mistök bakfæra allt kallið. Kallandi með `Omit Commit` ber sjálfur ábyrgð á bakfærslu við villu.
