# Changelog

## [Unreleased]

### Fixed (2026-10-16) - four main message types that always failed

- Transfer Order Post Impl ori (70013415): a full `Inventory.TransferOrder.Post` Receive deleted the transfer order. Codeunit 5706 can then return false with "The Transfer Header does not exist", or the client reports Unhandled UI "successfully posted and is now deleted", after the posting had committed. Both are treated as Success. `postedReceiptNo` is read from Transfer Receipt Header by Transfer Order No., then Item Ledger Entry when that field is empty. Partial receive still keeps the order. Transfer Order Post Tests (96914) covers full and partial receive.
- Phys. Inv. Calc Impl ori (70013496): `Inventory.PhysInventory.Calculate` ran report Calculate Inventory without a posting date, so it always failed with "Enter the posting date." The contract now requires `postingDate` (YYYY-MM-DD) and accepts optional `itemNoFilter`. The report is initialized with that date, the batch document no, an item filter when sent, HideValidationDialog, and IncludeItemWithNoTransaction. The answer includes `lineCount`.
- Phys. Invt. Post Impl ori (70013465): `Inventory.PhysInventory.Post` passed an unpositioned `Item Journal Line` to Item Jnl.-Post, which failed with an empty template name. It now finds the first line, posts through Item Jnl.-Post Batch, and returns `itemRegisterNo` / `fromEntryNo` / `toEntryNo`. An empty batch is `PreconditionFailed` on `journalBatchName` with received = batch name and expected = at least one journal line.
- Reservation Create Impl ori (70013476): `Inventory.Reservation.Create` called AutoReserve on a reservation entry with no source type, so every call failed. It now loads a real source line (`sourceType` / `sourceNo` / `sourceLineNo`, optional `sourceSubtype`) for sales, purchase, transfer, and assembly lines, binds `Reservation Management.SetReservSource` on that record, then Reserv. Write Runner ori (70013479) runs AutoReserve via Codeunit.Run after Commit so the dispatcher TryFunction can insert. It returns `entryNo`. Reservation Cancel Impl ori (70013478) finds that entry by number and uses the same runner to delete.
- Phys Inventory Tests (96922) and Reservation Create Tests (96923) cover happy path, missing input, and the empty-batch / unknown-source edges. Help chapters are updated in en-US and is-IS.

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
