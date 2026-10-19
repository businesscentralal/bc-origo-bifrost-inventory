# Changelog

## [Unreleased]

### Added (2026-10-19) - costing, item tracking reads and physical inventory (#4, #5, #6)

- Costing (#4): `Inventory.Cost.Update` changes Unit Cost, Last Direct Cost or Standard Cost on one item card through native validation and refuses Standard-costed items with a pointer to `Inventory.Revaluation.Post`. `Inventory.Revaluation.PreviewPost` and `Inventory.Revaluation.Post` preview and post a Revaluation journal batch with Item Jnl.-Post Batch. `Inventory.Cost.Get` returns a native cost snapshot and `Inventory.Price.Update` writes Unit Price through native validation. Data.Records.Set refuses the Item cost and price fields and names the dedicated type.
- Item tracking (#5): `Inventory.Tracking.Get` reads the lot, serial and package tracking of a document line or the open item ledger entries of an item; `Inventory.TrackingAvailability.Get` groups availability with native expiration dates (blank unless the item tracking code uses expiration dates) and paging.
- Physical inventory (#6): `Inventory.PhysInventory.Calculate` runs report 790 into an empty batch and requires `postingDate` and `documentNo` (`itemNo`, `locationCode`, `variantCode` filter the items). `RecordCount` records several counts (an omitted `qtyCounted` leaves the line uncounted, 0 records zero), `Check` reports readiness, `PreviewPost` previews, and `Post` returns the item register and both ledger entry ranges. Item Journal Line stays writable through Data.Records.Set.
- New objects: codeunits 70013406 `Revaluation Post Impl ori`, 70013407 `Reval Preview Impl ori`, 70013408 `Cost Update Impl ori`, 70013409 `Inventory Native Journal ori`, 70013410 `Inventory Tracking Read ori`, 70013411 `Tracking Get Impl ori`, 70013412 `Inventory Write Process ori`, 70013432 `Inventory Cost Read ori`, 70013437 `Inventory Cost Data Guard ori`, 70013438 `Inventory Card Write ori`, 70013479 `Phys. Inv. Check Impl ori`; message type values 70013437 `Inventory.Cost.Update`, 70013438 `Inventory.Revaluation.Post`, 70013413 `Inventory.Revaluation.PreviewPost`, 70013414-70013416 `Inventory.PhysInventory.Check/PreviewPost/RecordCount`, 70013417 `Inventory.Tracking.Get`. Execute grants go to the `BIFROST InvRead ori` / `BIFROST InvWrite ori` permission set extensions; the attribute permission sets are unchanged.
- Tests: codeunits 96927, 96933, 96936-96946 and permission sets 96934-96936.

### Fixed (2026-10-19) - message types that always failed (#122, #123, #124, #125)

- `Inventory.TransferOrder.Post` with `postingType` Receive no longer answers "The Transfer Header does not exist" after a receive that completes the order: the posting runs in batch mode (no "posted and deleted" message) and the posted shipment, receipt or direct transfer number is captured from the posting events. The response adds `orderDeleted`.
- `Inventory.PhysInventory.Calculate` takes the required `postingDate`, and `Inventory.PhysInventory.Post` posts the positioned batch; an empty batch is `PreconditionFailed` with the batch name as `received` and "at least one journal line" as `expected`.
- `Inventory.Reservation.Create` reserves against a real source line (`sourceType` 37/39/5741/901, `sourceSubtype`, `sourceNo`, `sourceLineNo`, `quantity`) and returns `entryNo`/`entryNos`; nothing available is `PreconditionFailed`. `Inventory.Reservation.Cancel` cancels the pair through Reservation Engine Mgt. Both write through `Inventory Write Process ori` so a native error rolls the write back.
- `Inventory Contract Batch Tests` no longer requires exactly four Foundation `Inventory.ItemJournal.*` types (Foundation 28.0.7 registers five).


### Fixed (2026-10-16) - integrate contract tooling after product acceptance

- Reconcile the existing contract and mixed-language guard repairs with merged PR96 on main. Preserve its product, test and translation files unchanged; retain request-lineage, payload-generation, branch-parser and label-property regression coverage (#30–33). Production guard wiring and whole-issue acceptance remain pending. No AL object IDs, app versions, permissions or workflows change relative to main.

### Fixed (2026-10-16) - runtime catalogue localization

- Replace literal catalogue descriptions with translatable labels for the 35 scoped message types, including TransferOrder.Release. Convert the remaining 17 literal keyword lists and 17 selection descriptions; preserve all existing English text and existing translated labels. Regenerate `app/Translations/Bifrost Inventory.is-IS.xlf` from the compiler output.
- Remove compiler/developer instructions from public Reservation.Create and CostToGL.Test notes and clear reused notes outputs. Message execution and wire identifiers are unchanged.
- `InventoryContractBatchTests.Codeunit.al` (96921) adds a language-switch regression over all 35 scoped catalogue entries in LCIDs 1033/1039 and checks both removed notes outputs. The existing nonempty discovery check alone did not detect English literals at LCID 1039.
- Amended implementation files and codeunit IDs: `ReclassCheckImpl.Codeunit.al` (70013475); `AsmDocPrevPostImpl.Codeunit.al` (70013423); `AsmOrderRefreshLnImpl.Codeunit.al` (70013421); `AsmOrderReleaseImpl.Codeunit.al` (70013426); `AsmOrderStatisticsImpl.Codeunit.al` (70013422); `AssemblyOrderCreateImpl.Codeunit.al` (70013424); `AssemblyOrderPostImpl.Codeunit.al` (70013425); `AssemblyOrderReopenImpl.Codeunit.al` (70013427); `CostGetImpl.Codeunit.al` (70013468); `CostToGLTestImpl.Codeunit.al` (70013467); `RevaluationCalcImpl.Codeunit.al` (70013488); `ItemApplGetImpl.Codeunit.al` (70013490); `ItemApplReapplyImpl.Codeunit.al` (70013492); `ItemApplUnapplyImpl.Codeunit.al` (70013491); `PeriodGetImpl.Codeunit.al` (70013483); `PhysInvtPostImpl.Codeunit.al` (70013465); `PhysInvtRecordImpl.Codeunit.al` (70013466); `PhysInvCalcImpl.Codeunit.al` (70013496); `PriceUpdateImpl.Codeunit.al` (70013486); `ReclassPreviewImpl.Codeunit.al` (70013474); `ReservationCancelImpl.Codeunit.al` (70013478); `ReservationCreateImpl.Codeunit.al` (70013476); `ReservationGetImpl.Codeunit.al` (70013477); `TrackingAvailGetImpl.Codeunit.al` (70013473); `TransfDocPrevPostImpl.Codeunit.al` (70013413); `TransferOrderCreateImpl.Codeunit.al` (70013414); `TransferOrderPostImpl.Codeunit.al` (70013415); `TransferOrderReopenImpl.Codeunit.al` (70013417); `TransferOrderStatsImpl.Codeunit.al` (70013419); `TransfOrderReleaseImpl.Codeunit.al` (70013416); `TransfUndoRcptImpl.Codeunit.al` (70013481); `ItemAttrDefCreateImpl.Codeunit.al` (10036900); `ItemAttributeCreateImpl.Codeunit.al` (10036898); `ItemAttributeGetImpl.Codeunit.al` (10036897); `ItemAttributeUpdateImpl.Codeunit.al` (10036899).

### Fixed (2026-10-16) - Icelandic translation resources

- Regenerate `app/Translations/Bifrost Inventory.is-IS.xlf` from the current build: include all 85 generated units using the existing Icelandic source comments and replace the three obsolete numeric-ID entries. Inventory Setup captions, domain captions, posting refusals, assembly/transfer descriptions and attribute help now have matching runtime translation IDs. English source text and AL behavior are unchanged.
- Explicitly mark the five already-temporary Message Argument test variables as `temporary` in `ItemAttributeTestsori.Codeunit.al` (96900), `InvPostingGateTests.Codeunit.al` (96918) and `InvPostingGateGrantTests.Codeunit.al` (96919). This preserves the Foundation table's `TableType = Temporary` behavior and lets the BC 28 analyzer recognize the existing temporary-variable names without AA0237 warnings.

### Fixed (2026-10-15) - contract reads retain payload generation and source position

- `tools/Test-ContractParameterKeys.ps1` versions JSON snapshots and the underlying request payload, applies exhaustive validators at individual read/call sites, and unions conditional paths. Source-checked normalization retains removed keys in the original payload constraint; replacements, streams, unknown effects, implicit calls and try-function/codeunit return boundaries discard stale proof. Unsupported regions retain their reads. JSON key comparisons remain case sensitive (#30).
- The AL statement parser preserves CASE/IF/ELSE ownership across terminators and loop statements. Portable source-proof fixtures, branch parser controls and an independent bounded concrete source oracle retain the counterexamples behind this repair.
- Remaining `tableView` source discrepancies stay visible. Issues #30–33 remain acceptance-open, and production guard wiring stays off. No AL object IDs, contracts, allow-lists, workflow files or app versions change in this tooling repair.

### Fixed (2026-10-15) - preserve request context in contract source checks

- `tools/Test-ContractParameterKeys.ps1` follows nested JSON records through array iteration and helper arguments, while cleared or replaced tokens retain ambiguity diagnostics. It narrows runtime branches only from source-proven literal selectors, fresh local codeunit modes, or an unchanged message envelope at an entry dispatch. Unknown consumers, shared instances, mutation and ambiguous calls retain both paths (#30).
- Dependency source can be supplied with `-DependencyAppFolders`; only the selected app's registrations are scanned. Duplicate object names fail, and invocation evidence must identify the dependency commit and official artifact. Rejection-only checks are reported separately only when a void helper's sole action is a read-only nonempty-value check followed by `Error`; real reads and incorrect declarations remain findings.
- `tools/tests/test-contract-parameter-keys.py` covers positive and negative request lineage, dispatch, dependency and rejection scenarios. The functional candidate's remaining journal-validation findings and newly exposed `tableView` discrepancies remain visible; this does not close #30–33 or enable production workflow wiring. No AL object IDs, contracts, allow-lists or workflow files changed in this tooling repair.

### Fixed (2026-10-15) - typed-reader keys retain literal caller bindings

- `tools/Test-ContractParameterKeys.ps1` resolves a forwarded typed-reader key only when every reached source call supplies a literal for that parameter. Unknown receivers, nested or dynamic arguments, mutable keys, unknown key consumers and overloaded procedures retain the ambiguity diagnostic (#30). This recognizes the existing `skip` and `take` wrapper without a key-name exception.
- `tools/tests/test-contract-parameter-keys.py` adds fifteen caller-binding cases, including undocumented literal keys, multiple callers and unresolved bindings. The remaining production guard findings stay visible; no workflow is enabled.

### Fixed (2026-10-15) - operation selectors are not request parameters

- `tools/Test-ContractParameterKeys.ps1` excludes a literal operation selector only when the resolved callee's source proves that its parameter is used solely in `case` selectors (#30). Unknown calls, additional parameter uses and ambiguous overloads retain the conservative request-key check. No method-name exception or allow-list was added.
- `tools/tests/test-contract-parameter-keys.py` adds eight operation-selector regressions. The full production scan still reports the existing four contract discrepancies at this product base; this repair does not close #30 or enable the production guard.

### Fixed (2026-10-15) - label property scanner respects quoted comments

- `tools/Test-MixedLanguageLabels.ps1` now reads the `Locked` property outside quoted strings and comments. Protocol text such as `allowBlocked=true` in an Icelandic translation comment no longer reports a translated refusal as locked (#33). Actual `Locked = true` labels remain findings.
- `tools/tests/test-mixed-language-labels.py` checks both local and global labels, escaped quotes, property order, case and whitespace, explicit false, and real locked properties. No AL objects, allow-lists or workflow jobs changed.

### Fixed (2026-10-15) - zero-warning Inventory verification

- Preserve the attribute-table grants from `BIFROSTInvRead.PermissionSetExt.al` (10036915) and `BIFROSTInvWrite.PermissionSetExt.al` (10036916) in the included, nonassignable `BIFROSTInvAttrRead.PermissionSet.al` (10036915) and `BIFROSTInvAttrWrite.PermissionSet.al` (10036916). Read and Full roles retain their original access; no posting or Foundation Setup grants are added.
- Align AL filenames with object names and order record declarations before codeunits without changing message execution. `PhysInvCalcImpl.Codeunit.al` (70013496), `PhysInvPreviewImpl.Codeunit.al` (70013472) and `TrackingAvailGetImpl.Codeunit.al` (70013473) clear the notes output when they report no notes.
- Fix test helper content-type buffer lengths, load the item Description field, initialize JSON-array indexes explicitly and name temporary arguments consistently. `InvPostingGateTests.Codeunit.al` (96918) verifies preserved read-only/write attribute access, and `InventoryContractBatchTests.Codeunit.al` (96921) verifies stale notes are cleared. Existing tests and assertions remain enabled.

### Fixed (2026-10-13) - contract source guard recognizes Inventory chapters

- `Test-ContractParameterKeys.ps1` follows a literal shared-chapter selector, literal JSON parameter arrays, attached parameter objects and the typed request readers in Foundation Request Value Reader ori. Unresolved selectors and malformed arrays fail with explicit diagnostics; undeclared and unread keys still fail. Regression fixtures cover valid chapters, mismatches, unrelated objects, cleared objects and dynamic calls. No AL object or message implementation changes.

- `.github/workflows/SourceGuards.yaml` adds the `ContractParameterKeysRegression` job for the guard self-test and Python regression fixtures. Its comments identify the remaining production contract, localization, translation and help-link checks.
- `tools/tests/test-contract-parameter-keys.py` adds 26 regression fixtures for contract selectors, declarations and typed readers, including mismatches and malformed inputs.

### Fixed (2026-10-12) - related help entries name existing message types

- Cost Get Impl ori (70013468) added `Inventory.AdjustCost.Run` and `Inventory.Revaluation.Calculate` as plain strings. Foundation reads a string related entry as message type "", so `Help.Implementation.Get` failed and the UAT roster refresh dropped 50 help documents.
- These codeunits now add related entries as objects with `name` and `useInsteadWhen`: Cost Get Impl ori (70013468), Cost To GL Test Impl ori (70013467), Revaluation Calc Impl ori (70013488), Item Appl. Get Impl ori (70013490), Item Appl. Reapply Impl ori (70013492), Item Appl. Unapply Impl ori (70013491), Period Close Impl ori (70013485), Period Get Impl ori (70013483), Period Reopen Impl ori (70013484), Phys. Inv. Calc Impl ori (70013496), Phys. Inv. Preview Impl ori (70013472), Phys. Invt. Calc Impl ori (70013464), Phys. Invt. Post Impl ori (70013465), Phys. Invt. Record Impl ori (70013466), Price Update Impl ori (70013486), Reclass Check Impl ori (70013475), Reclass Post Impl ori (70013493), Reclass Preview Impl ori (70013474), Reservation Cancel Impl ori (70013478), Reservation Create Impl ori (70013476), Reservation Get Impl ori (70013477), Tracking Assign Impl ori (70013470), Tracking Avail. Get Impl ori (70013473), Tracking Delete Impl ori (70013471), Assembly Undo Post Impl ori (70013482), and Transf Undo Rcpt Impl ori (70013481). Those names are registered message types.
- `Inventory.PhysInventory.Check` was never registered and never published, so dropping it is not a breaking change. Phys. Inv. Preview Impl ori (70013472) no longer names it. The preview still names `Inventory.PhysInventory.Post`. Phys. Inv. Check Impl ori (70013499) had no callers and is removed. The README no longer lists the type.
- Phys. Inv. Post Impl ori (70013497) was not bound to a message type and had no callers. It was never published, so removing it is not a breaking change. `Inventory.PhysInventory.Post` stays on Phys. Invt. Post Impl ori (70013465).
- Inventory Contract Batch Tests (96921) walks every Inventory message type and fails when a related entry is not an object with a non-empty name that exists in the catalogue. This app registers 44 Inventory types. Foundation also registers `Inventory.ItemJournal.Check`, `Inventory.ItemJournal.Create`, `Inventory.ItemJournal.Post`, and `Inventory.ItemJournal.PreviewPost`. Those four have help contracts, so the walk expects 48. They are not unpublished leftovers, and this app does not own them.
- Item Appl. Get Impl ori (70013490) returned false for every contract chapter, so the help reader had no contract for `Inventory.ItemApplication.Get`. It now follows Item Appl. Unapply Impl ori (70013491): envelope, Item Application Entry target, required `itemLedgerEntryNo`, the success response, `MissingParameter`, a read-only effect, and related Unapply and Reapply.
- These registered types whose contract chapters also returned false now declare the chapters their implementations already answer: Reservation Get Impl ori (70013477) `Inventory.Reservation.Get`, Period Get Impl ori (70013483) `Inventory.Period.Get`, Period Close Impl ori (70013485) `Inventory.Period.Close`, Period Reopen Impl ori (70013484) `Inventory.Period.Reopen`, Transf Undo Rcpt Impl ori (70013481) `Inventory.Transfer.UndoReceipt`, Assembly Undo Post Impl ori (70013482) `Inventory.Assembly.UndoPost`, Reclass Post Impl ori (70013493) `Inventory.Reclassification.Post`, Price Update Impl ori (70013486) `Inventory.Price.Update`, and Revaluation Calc Impl ori (70013488) `Inventory.Revaluation.Calculate`.

### Changed (2026-10-12) - empty physical inventory batch returns PreconditionFailed

- Phys. Invt. Post Impl ori (70013465) named error code `NothingToPost`, which `Bifrost Error Code ori` does not have, and the runtime raised that empty batch with no error code. An empty batch is a state precondition, the same case as the core item journal and general journal post. The contract and the runtime now return `PreconditionFailed` on parameter `journalBatchName`. Callers that matched `NothingToPost` or the bare error text now receive `PreconditionFailed`. Inventory Contract Batch Tests (96921) asserts that code on the contract and on an empty batch.

### Fixed (2026-10-11) - direct transfer posting on BC 28.5

- UAT Base Application 28.5.54151.55799 has no `Inventory Setup."Direct Transfer Posting Type"` (AL0132). That enum is new in BC 29. On BC 28.0 through 28.6 the setup field is still the option `Direct Transfer Posting`, with `Receipt and Shipment` and `Direct Transfer`, which is what codeunit 5706 reads.
- Transfer Order Post Impl ori and Transf Doc Prev. Post Impl ori use that option. `Receipt and Shipment` posts the shipment and the receipt together. `Direct Transfer` posts one direct transfer.
- CI now compiles against sandbox artifact 28.5.54151.55751 (w1), the closest published 28.5 artifact at or before UAT 28.5.54151.55799. That UAT build is not in the public w1 index. The Current workflow uses the same pin. Next Minor and Next Major keep `////nextminor` and `////nextmajor`.
- `.AL-Go/settings.json` is a `fullBuildPatterns` entry, so a later artifact pin is a full pull-request build instead of an incremental skip.

### Fixed (2026-10-11) - semantic compile errors on the compile repair

- Cost To GL Post Impl ori and Adjust Cost Run Process ori run reports 1002 and 795 inside a TryFunction, because `Report.Run` returns no value. A failed run is returned with `GetLastErrorText`. Success uses `SetResponseJson`. The costing contract chapters, including the `InvalidOperation` error text, are unchanged.
- Reclass Post Impl ori returns the empty-batch text through `RespondWithError`, because `Bifrost Error Code ori` has no `NothingToPost` value.
- Price Update Impl ori looks up the item with `Document Lookup ori.FindItemRange`.
- Reservation Create Impl ori calls `Reservation Management.AutoReserve`.
- Phys. Inv. Calc Impl ori runs report `Calculate Inventory` from `Microsoft.Inventory.Counting.Journal` through `SetItemJnlLine`.
- Transfer Undo Shpt Impl ori runs `Undo Transfer Shipment` on each shipment line whose `Correction Line` is false. A failure is returned as an error.
- Transfer Order Post Impl ori and Transf Doc Prev. Post Impl ori briefly read BC 29 `Direct Transfer Posting Type`. That reference is replaced by the BC 28 option in the 28.5 fix above.
- Item attribute tests call the registered message types `Inventory.Attribute.Get`, `Inventory.Attribute.Create`, `Inventory.Attribute.Update`, and `Inventory.AttributeDefinition.Create`. Write-restriction checks pass `Force = false`, which Foundation now requires.
- Attribute related chapters name those registered message types. Costing contracts use error code `PreconditionFailed` for a failed report run. `BusinessCentralError` stays the dispatcher failure.
- BIFROST InvRead ori, BIFROST InvWrite ori, and the posting-gate test set can read Inventory Setup ori, so a caller without BIFROST InvPost ori can still evaluate the domain gate. BIFROST InvPost ori keeps the page and tabledata grant used by permission coverage.
- The no-component-stock assembly preview test rereads the component item after the BOM is created, then sets Prevent Negative Inventory.
- Transfer and assembly posting preview stay enabled without BIFROST InvPost ori. Posting still requires that set.

### Fixed (2026-10-11) - remaining main compile blockers

- Object IDs that sat outside `[10036885..10036934]` and `[70013400..70013499]`, and the duplicate codeunit IDs 70013490 and 70013491, now use free IDs inside those ranges. Item Appl. Get Impl ori (70013490) and Item Appl. Unapply Impl ori (70013491) keep their IDs. Reservation Get Impl ori is 70013477 and Reservation Cancel Impl ori is 70013478. App and test versions are unchanged.
- `Inventory.PhysInventory.Calculate` stays on Phys. Inv. Calc Impl ori (70013496), value 70013446. The second registration of that same name is removed. `Inventory.TrackingAvailability.Get` moves to value 70013449.
- Assembly Undo Post Impl ori calls `Assembly-Post.Undo` because codeunit `Pstd. Assembly - Undo` is not in this Business Central version. A failed undo is returned as an error and is not reported as success.
- Transf Undo Rcpt Impl ori no longer calls the missing codeunit `Undo Transfer Receipt`. A posted transfer receipt that exists is answered with an error that this version cannot undo it. Success is not invented.
- Asm. Order Release Impl ori and Assembly Undo Post Impl ori use the `Assembly` domain. Phys. Invt. Post Impl ori (70013465) uses the `PhysInventory` domain.
- BIFROST InvPost ori grants page Inventory Setup ori (70013452) and tabledata Inventory Setup ori, which is the app's only assignable permission set. Foundation table Setup ori is not granted.

### Fixed (2026-10-10) - UAT dependency installation

- UAT feature-app deployment uses the Foundation app already deployed by its own pipeline in Dev scope, avoiding an unauthorized AppSource Foundation installation. `.github/AL-Go-Settings.json`: `DeployToBifrost.DependencyInstallMode = "ignore"`. AppSource delivery is unchanged; no AL objects or IDs change.

### Fixed (2026-10-10) - Attribute chapter selector compatibility

- Inventory Contract Parts ori (70013445) accepts the four registered Inventory Attribute selectors alongside the existing Item helper selectors. Existing chapter payloads, Item-related references and executable implementations Item Attribute Get Impl ori (10036897), Item Attribute Create Impl ori (10036898), Item Attribute Update Impl ori (10036899), and Item AttrDef Create Impl ori (10036900) are preserved; related-name catalogue validation remains a separately tracked blocker.
- Inventory Contract Batch Tests (96921) use the registered names and check exact ordinals, parameter types/required flags/default absence, Item targets, Definition subject/target absence, response fields/effects and existing error/example/overview/notes content through the real contract interface and reader.
- The contract-key guard binds declaration and target calls in lexical scope with separate literal contexts, grouped/nested selectors, forwarders and early exits. Unsupported contexts fail explicitly; budgets are 32 call edges and 256 contexts per chapter root. Existing readers and allowlist remain unchanged, with positive, mismatch, unsupported and boundary controls.

### Fixed (2026-10-10) - literal contract parameter validation

- The contract parameter guard recognizes the literal JSON chapters of Adjust Cost Run Impl ori (70013460) and Cost To GL Post Impl ori (70013462), while still reporting unread declarations and undocumented reads. Guard fixtures cover unrelated JSON receivers, comments, AL apostrophe escaping, malformed chapters and empty arrays; costing execution and metadata are preserved.

### Fixed (2026-10-10) - costing metadata interface completeness

- Adjust Cost Run Impl ori (70013460) and Cost To GL Post Impl ori (70013462) implement the missing message direction, description and contract chapters with typed defaults, array preconditions and cleared reused outputs. CostToGL metadata discloses report completion without promising G/L posting; existing execution, filters and report options are preserved.
- Inventory Contract Batch Tests (96921) adds six metadata regressions covering defaults, conflicting-filter preconditions, dispatcher error declarations, report options and reused interface outputs.

### Fixed (2026-10-09) - main lexical compile blockers

- Period Close Impl ori (70013485), Period Get Impl ori (70013483), Period Reopen Impl ori (70013484), Phys. Invt. Post Impl ori (70013534), Reclass Post Impl ori (70013493), and Tracking Avail. Get Impl ori (70013542) import their standard Inventory Period, posting, and ledger namespaces verified in BC28 and BC29 shipped packages.
- Reservation WriteGuard ori (70013498) and Tracking Data Restrict ori (70013544) subscribe to the Message Argument ori table (10077896) publisher; restriction bodies and subscriber skip flags are preserved.
- Asm. Order Release Impl ori (70013426) removes a duplicate local declaration while retaining both domain gate calls.
- MsgType.Reserv.EnumExt ori (70013492) shortens the enumextension object name to fit the 30-character limit; value IDs, captions and implementations are preserved.

### Changed (2026-10-07) - preserve the Bifrost pipeline across AL-Go and Alpaca updates

- `Bifrost Pipeline Guards` runs `tools/Test-BifrostPipeline.ps1` and `tools/Test-SharedAlpacaContainer.ps1` when workflows, AL-Go settings, Alpaca scripts, or `AGENTS.md` change. `fullBuildPatterns` includes `.github/workflows/**` and `tools/Test-BifrostPipeline.ps1`, so a pipeline change runs the full Default and Test build.

### Changed (2026-10-05) - align with Bifrost Foundation 28.0.1

- The Foundation dependency floor is **28.0.1.0** in `app/app.json` and `test/app.json`, the same floor as Bifrost Language Models and Bifrost Attachments.
- The Inventory table already declares `Extensible = false`; no table or page change was needed.
- `tools/` carries Foundation's source guards. The Source Guards workflow runs the checks that already pass on Attachments: no call stack in answers, validated table views, no obsolete, permission coverage, and Icelandic keyword counts. Contract-parameter and mixed-language guards are copied but not wired in.
- Parsing and field-write checks use Request Value Reader ori; posting previews use Posting Preview Helper ori; transfer/assembly/item lookup uses Document Lookup ori, preserving existing request and response behavior. Migrated objects: Item Attribute Resolve ori (10036908), Asm. Doc Prev. Post Impl ori (70013423), Asm. Order RefreshLn Impl ori (70013421), Asm. Order Release Impl ori (70013426), Asm. Order Statistics Impl ori (70013422), Assembly Order Create Impl ori (70013424), Assembly Order Post Impl ori (70013425), Assembly Order Reopen Impl ori (70013427), Transf Doc Prev. Post Impl ori (70013413), Transfer Order Create Impl ori (70013414), TransferOrder-Post (Yes/No) (5706), Transfer Order Reopen Impl ori (70013417), Transfer Order Stats Impl ori (70013419), Transf. Order Release Impl ori (70013416), Item Attribute Get Impl ori (10036897).
- Real Icelandic discovery keywords replace filler in Assembly Order Create Impl ori (70013424), Assembly Order Post Impl ori (70013425), and Transfer Order Create Impl ori (70013414); generated Icelandic translations follow the AL comments.
- Regression coverage extends Asm. Doc Prev. Post Tests (96905), Transfer Order Create Tests (96913), and Transfer Order Stats. Tests (96917) for preview response fields, posting failure, typed input rejection, and lookup errors.
- Help Links is not wired in until `businesscentralal/bifrost` main has `help/inventory/`.

### Changed (2026-10-04) - CI/CD builds only main; every pull request gets a Pull Request Build

- Build policy only, no app change. `CI/CD` runs on pushes to `main` only, and `Pull Request Build` runs for pull requests into any branch. `.github/AL-Go-Settings.json` sets `CICDPushBranches` to `main` and `CICDPullRequestBranches` to `**`, so Update AL-Go System Files keeps the triggers.

### Changed (2026-10-01) - code style of the message contracts

- The contract procedures of all 17 message type codeunits are written one statement per line (84 CodeCop AA0018 warnings), empty `GetNotes` stubs clear their `var` parameter (AA0150), and three file names match their object names (AA0215). No behaviour change.

### Removed (2026-10-01) - markdown help procedure (#23)

- Every Inventory message type codeunit drops `GetMessageHelpAsMarkdownDocument`, the empty compatibility shim. Foundation removed it from `Msg Interface ori` (core#198); help is the contract chapters that `Help.Implementation.Get` returns. No chapter changed.
- Bifrost Foundation dependency raised to 28.0.0.186, the first Foundation build without the procedure, in `app/app.json` and `test/app.json`.

### Added (2026-09-30) - Inventory message contracts (#24)

- All 17 Inventory message types now implement `Msg Contract ori` and expose envelope, target, parameters, response, errors, effect, related, workflow, examples, overview, and notes chapters where applicable.
- All 17 message types expose distinct English and Icelandic discovery keywords and selection descriptions.
- Per-type markdown help codeunits were removed after their content moved into contract chapters; the legacy markdown interface method remains as an empty compatibility shim for issue #23.
- The app and test projects now pin Bifrost Foundation `28.0.0.166`; contract conformance, effect, and discovery tests cover the full batch.

### Added (2026-09-29) - Transfer and assembly order message types (#20)

- Inventory.TransferOrder.* and Inventory.AssemblyOrder.* message types now live in Bifrost Inventory (moved from Foundation). Field-write checks, transfer-line handling, preview shaping, and typed date, decimal, and boolean reads go through public Dispatcher ori. PreviewPost no longer checks posting permission. Anyone who posts transfer or assembly orders through Bifrost now needs BIFROST InvPost ori, because BIFROST ItemPost ori no longer covers Inventory.TransferOrder.Post or Inventory.AssemblyOrder.Post. Foundation TakeOver does not assign BIFROST InvPost ori, so admins must grant it manually. Transfer and Assembly PreviewPost help matches the Success answer: every Success answer carries entryCount and glEntryCount, balanced is omitted when glEntryCount is 0, and Business Central posting errors come back verbatim with no code.

### Changed (2026-09-25) - Latest Foundation CI build (floor 28.0.0.0)

- The app builds against the latest Foundation CI build with a Foundation floor of `28.0.0.0`.
- App and test Bifrost Foundation dependency version set to `28.0.0.0`.
- AL-Go `appDependencyProbingPaths` for bc-origo-bifrost-core: `release_status: latestBuild`, `version: latest`. GetArtifacts matches a specific version exactly; only `latest` uses the last successful CICD run.
### Security

- Default (release) builds no longer ship the test app's internalsVisibleTo grant; the strip moved to PipelineInitialize.ps1 because Alpaca never ran PreCompileApp.ps1 (core#129).

### Fixed (2026-09-25) - Deploy to Bifrost sandbox rejected as a version downgrade

- CI/CD run [36029236028](https://github.com/businesscentralal/bc-origo-bifrost-inventory/actions/runs/36029236028) failed at Deploy to Bifrost: `Cannot install the extension Bifrost Inventory by Origo 28.0.0.12 because a newer version 28.0.10.0 was already installed.`
- Cause: #16 switched AL-Go to `versioningStrategy: 3` (major.minor.build from app.json, run number as revision). Earlier builds used strategy 0 (run number as build) and deployed `28.0.10.0`, so every strategy-3 build (`28.0.0.<run>`) was lower than the installed version.
- Fix: app and test `version` raised to `28.1.0.0`; `versioningStrategy: 3` kept. Test dependency on Bifrost Inventory moved to `28.1.0.0` so tests always resolve the rebuilt app.

### Changed (2026-09-17) - Bifrost Foundation Exact pin 28.0.0.100 (no float)

- App/test Bifrost Foundation dependency set to Exact `28.0.0.100`.
- AL-Go `appDependencyProbingPaths` for bc-origo-bifrost-core: `release_status: latestBuild`, `version: 1.0.0.100`.
- `nuGetFeedSelectMode: Exact` so NuGet does not resolve `[28.0.0.100,)` upward to colliding `.107`.

### Changed

- App manifest: privacy statement and EULA URLs now point at the published Bifröst Foundation pages; Application Insights connection string updated to the shared bc-cosmos-shared telemetry resource. Help and publisher URL unchanged.
- App logo: new Bifröst wordmark with "Powered by origo." tagline; app-name line unchanged.


## Bifrost Inventory 28.0.0.0

### Added
- App scaffold for Bifrost Inventory (Foundation 28.0.0.0 dependency, idRanges 10036885–10036934).
- Message types: `Item.Attribute.Get`, `Item.Attribute.Create`, `Item.Attribute.Update`, `Item.AttributeDefinition.Create`.
- PermissionSetExtensions `BIFROST InvRead ori` / `BIFROST InvWrite ori` onto Foundation Read/Full (no own assignable set).
- AC-9: `Data.Records.Set` refused on Item Attribute tables 7500/7501/7504/7505; Get remains allowed.
