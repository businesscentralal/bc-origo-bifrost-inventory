namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 176: the deployed Foundation confirmation contract and dispatcher boundary for every irreversible Inventory type.</summary>
codeunit 96978 "Inv. Confirmation Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_ConfirmationBoundary_In1033()
    begin
        // Issue #176 AC01 | Time: no date dependency | Risk: only the owned test company setup is changed.
        AssertConfirmationBoundary(1033);
    end;

    [Test]
    procedure Scenario_AC01_ConfirmationBoundary_In1039()
    begin
        // Issue #176 AC01 | Time: no date dependency | Risk: only the owned test company setup is changed.
        AssertConfirmationBoundary(1039);
    end;

    [Test]
    [HandlerFunctions('NativeMessageHandler')]
    procedure Scenario_AC01_NativeSuccess_In1033()
    begin
        // Issue #176 AC01 | Time: WorkDate for native posting | Risk: owned test-company native journals only.
        VerifyNativeSuccess(1033);
    end;

    [Test]
    [HandlerFunctions('NativeMessageHandler')]
    procedure Scenario_AC01_NativeSuccess_In1039()
    begin
        // Issue #176 AC01 | Time: WorkDate for native posting | Risk: owned test-company native journals only.
        VerifyNativeSuccess(1039);
    end;

    /// <summary>Verifies English confirmed native posting preserves a pending queue key above the value-entry ledger.</summary>
    [Test]
    [HandlerFunctions('NativeMessageHandler')]
    procedure Scenario_AC01_PendingValueEntry_NativeSuccessIn1033()
    begin
        // Issue #176 AC01, PR #202 P1 | Time: WorkDate for native posting | Risk: owned queue fixture under test isolation.
        VerifyNativeSuccessWithPendingValueEntry(1033);
    end;

    /// <summary>Verifies Icelandic confirmed native posting preserves a pending queue key above the value-entry ledger.</summary>
    [Test]
    [HandlerFunctions('NativeMessageHandler')]
    procedure Scenario_AC01_PendingValueEntry_NativeSuccessIn1039()
    begin
        // Issue #176 AC01, PR #202 P1 | Time: WorkDate for native posting | Risk: owned queue fixture under test isolation.
        VerifyNativeSuccessWithPendingValueEntry(1039);
    end;

    /// <summary>Both non-posting carry-outs ignore compatibility counts while confirmation policy is enabled.</summary>
    [Test]
    procedure Scenario_279_AC02_CarryOutWrites_In1033()
    begin
        // Story #279 AC02 | Time: WorkDate | Risk: native planning commits; owned fixtures are explicitly removed.
        VerifyCarryOutWrites(1033);
    end;

    /// <summary>The same native write boundary holds in Icelandic.</summary>
    [Test]
    procedure Scenario_279_AC02_CarryOutWrites_In1039()
    begin
        // Story #279 AC02 | Time: WorkDate | Risk: native planning commits; owned fixtures are explicitly removed.
        VerifyCarryOutWrites(1039);
    end;

    local procedure VerifyCarryOutWrites(LanguageId: Integer)
    var
        PlanningTests: Codeunit "Plan Wksh Tests ori";
        RequisitionTests: Codeunit "Requisition Tests ori";
        FoundationSetup: RecordRef;
        PreviousConfirmation: Boolean;
        ChangedConfirmation: Boolean;
    begin
        ChangedConfirmation := EnableRequiredConfirmation(FoundationSetup, PreviousConfirmation);
        Assert.IsTrue(Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired'), 'This regression requires a confirmation-capable Foundation.');
        PlanningTests.VerifyIgnoredCount(LanguageId);
        RequisitionTests.VerifyIgnoredCount(LanguageId);
        RestoreConfirmation(FoundationSetup, ChangedConfirmation, PreviousConfirmation);
    end;

    [MessageHandler]
    procedure NativeMessageHandler(Message: Text[1024])
    begin
        // Native posting may emit informational completion messages in an interactive session.
    end;

    local procedure VerifyNativeSuccessWithPendingValueEntry(LanguageId: Integer)
    var
        ValueEntry: Record "Value Entry";
        PendingValueEntry: Record "Post Value Entry to G/L";
        SavedPendingValueEntry: Record "Post Value Entry to G/L";
        SequenceNoMgt: Codeunit "Sequence No. Mgt.";
        LastEntryNo: Integer;
    begin
        // [GIVEN] A queue row whose ledger key is absent, immediately above both allocation sources.
        LastEntryNo := ValueEntry.GetLastEntryNo();
        if PendingValueEntry.FindLast() then
            if PendingValueEntry."Value Entry No." > LastEntryNo then
                LastEntryNo := PendingValueEntry."Value Entry No.";
        if SequenceNoMgt.GetCurrentSeqNo(Database::"Value Entry") > LastEntryNo then
            LastEntryNo := SequenceNoMgt.GetCurrentSeqNo(Database::"Value Entry");
        ValueEntry.Init();
        ValueEntry."Entry No." := LastEntryNo + 100;
        ValueEntry.Insert();
        PendingValueEntry.Init();
        PendingValueEntry."Value Entry No." := ValueEntry."Entry No." + 1;
        PendingValueEntry."Item No." := 'XCONFIRM-PENDING';
        PendingValueEntry."Posting Date" := WorkDate();
        PendingValueEntry.Insert();
        SavedPendingValueEntry := PendingValueEntry;
        SequenceNoMgt.ClearState();

        // [WHEN] All confirmed native posting paths run, including revaluation with its exact amount assertion.
        VerifyNativeSuccess(LanguageId);

        // [THEN] The pre-existing queue row is neither consumed nor replaced by a new posting.
        PendingValueEntry.Get(SavedPendingValueEntry."Value Entry No.");
        Assert.AreEqual(SavedPendingValueEntry.SystemId, PendingValueEntry.SystemId, 'Existing queue row identity is preserved.');
        Assert.AreEqual(SavedPendingValueEntry."Item No.", PendingValueEntry."Item No.", 'Existing queue item is preserved.');
        Assert.AreEqual(SavedPendingValueEntry."Posting Date", PendingValueEntry."Posting Date", 'Existing queue date is preserved.');
        Assert.IsFalse(ValueEntry.Get(SavedPendingValueEntry."Value Entry No."), 'Posting must not reuse the existing queue key.');
    end;

    local procedure VerifyNativeSuccess(LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        ValueEntryBoundary: Record "Value Entry";
        InventoryLibrary: Codeunit "Inventory Test Library ori";
        FoundationSetup: RecordRef;
        PreviousConfirmation: Boolean;
        ChangedConfirmation: Boolean;
        PreviousLanguage: Integer;
        BoundaryEntryNo: Integer;
    begin
        InventoryLibrary.PrepareLibraryGLAccountNumbers();
        BoundaryEntryNo := PrepareNativeValueEntryNumbers();
        // [GIVEN] Normal posting setup, all required domains and newly created native source records.
        ChangedConfirmation := EnableRequiredConfirmation(FoundationSetup, PreviousConfirmation);
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := true;
        Setup.Assembly := true;
        Setup.Costing := true;
        Setup."Phys. Inventory" := true;
        Setup.Reclassification := true;
        Setup.Modify();
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        VerifyTransfer();
        VerifyAssembly();
        VerifyCosting();
        VerifyJournals();
        GlobalLanguage(PreviousLanguage);
        RestoreConfirmation(FoundationSetup, ChangedConfirmation, PreviousConfirmation);
        if BoundaryEntryNo <> 0 then begin
            ValueEntryBoundary.Get(BoundaryEntryNo);
            ValueEntryBoundary.Delete();
        end;
    end;

    local procedure PrepareNativeValueEntryNumbers(): Integer
    var
        ValueEntry: Record "Value Entry";
        PendingValueEntry: Record "Post Value Entry to G/L";
        SequenceNoMgt: Codeunit "Sequence No. Mgt.";
        BoundaryEntryNo: Integer;
    begin
        // A reused test company can retain queue keys above its last value entry.
        // Reserve a test-owned, zero-value boundary above those keys so both legacy
        // and sequence-based native posting allocate safely. Never delete tenant rows.
        if PendingValueEntry.FindLast() then
            if PendingValueEntry."Value Entry No." > ValueEntry.GetLastEntryNo() then begin
                BoundaryEntryNo := PendingValueEntry."Value Entry No." + 1;
                ValueEntry.Init();
                ValueEntry."Entry No." := BoundaryEntryNo;
                ValueEntry.Insert();
            end;
        // Discard single-instance buffers left by earlier tests; native validation
        // will advance the sequence against the ledger boundary without rewinding it.
        SequenceNoMgt.ClearState();
        exit(BoundaryEntryNo);
    end;

    local procedure VerifyTransfer()
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransit: Record Location;
        Item: Record Item;
        Header: Record "Transfer Header";
        Helper: Codeunit "Transfer Order Test Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        LibraryInventory.CreateItem(Item);
        CreateOwnedLocation(FromLocation, Item."Inventory Posting Group");
        CreateOwnedLocation(ToLocation, Item."Inventory Posting Group");
        CreateOwnedLocation(InTransit, Item."Inventory Posting Group");
        InTransit.Validate("Use As In-Transit", true);
        InTransit.Modify(true);
        Helper.CreatePositiveAdjustment(Item."No.", FromLocation.Code, 10);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransit.Code);
        Helper.CreateTransferLine(Header, Item."No.", 2);
        Codeunit.Run(Codeunit::"Release Transfer Document", Header);
        Request.Add('postingType', 'Ship');
        ConfirmAndRun("Message Type ori"::"Inventory.TransferOrder.Post", Header."No.", Request, Response);
        Assert.IsTrue(Response.Get('postedShipmentNo', Token), 'Native shipment number is returned.');
        Clear(Request);
        Request.Add('documentNo', Token.AsValue().AsText());
        ConfirmAndRun("Message Type ori"::"Inventory.Transfer.UndoShipment", '', Request, Response);
        Item.SetRange("Location Filter", FromLocation.Code);
        Item.CalcFields(Inventory);
        Assert.AreEqual(10, Item.Inventory, 'Native undo restores the owned source stock.');
    end;

    local procedure VerifyAssembly()
    var
        Parent: Record Item;
        Component: Record Item;
        Header: Record "Assembly Header";
        Helper: Codeunit "Assembly Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Helper.CreateAssemblyItemWithBOM(Parent, Component);
        Helper.CreateAssemblyOrder(Header, Parent."No.", 1);
        Helper.CreatePositiveAdjustment(Component."No.", 10);
        Request.Add('documentNo', Header."No.");
        ConfirmAndRun("Message Type ori"::"Inventory.AssemblyOrder.Post", '', Request, Response);
        Parent.CalcFields(Inventory);
        Assert.AreEqual(1, Parent.Inventory, 'Native assembly creates output.');
        Assert.IsTrue(Response.Get('postedDocumentNo', Token), 'Native posted assembly number is returned.');
        Clear(Request);
        Request.Add('documentNo', Token.AsValue().AsText());
        ConfirmAndRun("Message Type ori"::"Inventory.Assembly.UndoPost", '', Request, Response);
        Parent.CalcFields(Inventory);
        Assert.AreEqual(0, Parent.Inventory, 'Native undo reverses the assembly output.');
    end;

    local procedure VerifyCosting()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateStock(Item, 2);
        Request.Add('itemNoFilter', Item."No.");
        Request.Add('postToGL', false);
        ConfirmAndRun("Message Type ori"::"Inventory.AdjustCost.Run", Item."No.", Request, Response);
        Clear(Request);
        Request.Add('itemNoFilter', Item."No.");
        ConfirmAndRun("Message Type ori"::"Inventory.CostToGL.Post", Item."No.", Request, Response);
        Assert.IsTrue(Response.Get('postedValueEntryCount', Token), 'Native G/L posting reports actual entries.');
        Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'The owned pending value entry was posted.');
    end;

    local procedure VerifyJournals()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Location: Record Location;
        TempArgument: Record "Message Argument ori" temporary;
        CalculateValue: Report "Calculate Inventory Value";
        LibraryInventory: Codeunit "Library - Inventory";
        Journal: Codeunit "Inventory Native Journal ori";
        Request: JsonObject;
        Response: JsonObject;
        CountEntry: JsonObject;
        Counts: JsonArray;
        Token: JsonToken;
    begin
        CreateStock(Item, 10);
        CreateBatch(Batch, "Item Journal Template Type"::"Phys. Inventory");
        Request.Add('itemNo', Item."No.");
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Request.Add('documentNo', 'CONFIRM-PHYS');
        InitArgument(TempArgument, Batch, Request);
        Journal.Calculate(TempArgument);
        FilterBatch(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native calculation creates the owned count line.');
        CountEntry.Add('systemId', Line.SystemId);
        CountEntry.Add('qtyCounted', 8);
        Counts.Add(CountEntry);
        Clear(Request);
        Request.Add('counts', Counts);
        TempArgument.SetRequestJson(Request);
        Journal.RecordCount(TempArgument);
        Clear(Request);
        ConfirmAndRun("Message Type ori"::"Inventory.PhysInventory.Post", Batch."Journal Template Name" + '|' + Batch.Name, Request, Response);
        Item.CalcFields(Inventory);
        Assert.AreEqual(8, Item.Inventory, 'Confirmed native count is posted.');

        CreateStock(Item, 2);
        CreateBatch(Batch, "Item Journal Template Type"::Revaluation);
        Clear(Line);
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        Item.SetRange("No.", Item."No.");
        CalculateValue.SetItemJnlLine(Line);
        CalculateValue.SetParameters(WorkDate(), 'CONFIRM-REVAL', false, "Inventory Value Calc. Per"::"Item Ledger Entry", false, false, false, "Inventory Value Calc. Base"::" ", false);
        CalculateValue.SetTableView(Item);
        CalculateValue.UseRequestPage(false);
        CalculateValue.Run();
        FilterBatch(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native report creates the owned revaluation proposal.');
        Line.Validate("Inventory Value (Revalued)", 40);
        Line.Modify(true);
        Clear(Request);
        ConfirmAndRun("Message Type ori"::"Inventory.Revaluation.Post", Batch."Journal Template Name" + '|' + Batch.Name, Request, Response);
        Assert.IsTrue(Response.Get('totalAmount', Token), 'Actual revaluation amount is returned.');
        Assert.AreEqual(16, Token.AsValue().AsDecimal(), 'Native revaluation delta is posted.');

        Clear(Item);
        CreateStock(Item, 10);
        CreateBatch(Batch, "Item Journal Template Type"::Transfer);
        CreateOwnedLocation(Location, Item."Inventory Posting Group");
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 2);
        Line.Validate("New Location Code", Location.Code);
        Line.Modify(true);
        Clear(Request);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        ConfirmAndRun("Message Type ori"::"Inventory.Reclassification.Post", Batch."Journal Template Name" + '|' + Batch.Name, Request, Response);
        Item.SetRange("Location Filter", Location.Code);
        Item.CalcFields(Inventory);
        Assert.AreEqual(2, Item.Inventory, 'Confirmed native reclassification moves the owned stock.');
    end;

    local procedure CreateOwnedLocation(var Location: Record Location; InventoryPostingGroup: Code[20])
    var
        PostingSetup: Record "Inventory Posting Setup";
    begin
        // Library - ERM pads a sequence into the account number without checking the final key.
        // Use owned GUID keys instead; existing accounts and their posting setup remain untouched.
        repeat
            Clear(Location);
            Location.Init();
            Location.Code := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Location.Code));
        until not Location.Get(Location.Code);
        Location.Name := Location.Code;
        Location.Insert(true);
        PostingSetup.Init();
        PostingSetup.Validate("Location Code", Location.Code);
        PostingSetup.Validate("Invt. Posting Group Code", InventoryPostingGroup);
        PostingSetup.Validate("Inventory Account", CreateOwnedGLAccount());
        PostingSetup.Validate("Inventory Account (Interim)", CreateOwnedGLAccount());
        PostingSetup.Validate("WIP Account", CreateOwnedGLAccount());
        PostingSetup.Validate("Material Variance Account", CreateOwnedGLAccount());
        PostingSetup.Validate("Capacity Variance Account", CreateOwnedGLAccount());
        PostingSetup.Insert(true);
    end;

    local procedure CreateOwnedGLAccount(): Code[20]
    var
        Account: Record "G/L Account";
    begin
        repeat
            Clear(Account);
            Account.Init();
            Account."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Account."No."));
        until not Account.Get(Account."No.");
        Account.Validate(Name, Account."No.");
        Account.Insert(true);
        exit(Account."No.");
    end;

    local procedure ConfirmAndRun(MessageType: Enum "Message Type ori"; Subject: Text[250]; Request: JsonObject; var Response: JsonObject)
    var
        Entries: Record "Item Ledger Entry";
        Values: Record "Value Entry";
        BeforeEntries: Integer;
        BeforeValues: Integer;
        StatusToken: JsonToken;
        ResponseText: Text;
    begin
        BeforeEntries := Entries.Count();
        BeforeValues := Values.Count();
        if Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired') then begin
            Response := DispatchWithSubject(MessageType, Subject, Request);
            AssertText(Response, 'code', 'ConfirmationRequired');
            AssertText(Response, 'expected', '1');
            Assert.AreEqual(BeforeEntries, Entries.Count(), 'Missing confirmation changes no item ledger entries.');
            Assert.AreEqual(BeforeValues, Values.Count(), 'Missing confirmation changes no value entries.');
            Request.Add('expectedCount', 2);
            Response := DispatchWithSubject(MessageType, Subject, Request);
            AssertText(Response, 'code', 'ConfirmationMismatch');
            Assert.AreEqual(BeforeEntries, Entries.Count(), 'Wrong confirmation changes no item ledger entries.');
            Assert.AreEqual(BeforeValues, Values.Count(), 'Wrong confirmation changes no value entries.');
            Request.Replace('expectedCount', 1);
        end;
        Response := DispatchWithSubject(MessageType, Subject, Request);
        Response.WriteTo(ResponseText);
        Assert.IsTrue(Response.Get('status', StatusToken), 'Native result carries status.');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Confirmed native execution: ' + ResponseText);
    end;

    local procedure CreateStock(var Item: Record Item; Quantity: Decimal)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        Clear(Item);
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", Quantity);
        Line.Validate("Posting Date", WorkDate());
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch"; JournalType: Enum "Item Journal Template Type")
    var
        JournalTemplate: Record "Item Journal Template";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        Clear(Batch);
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalType);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;

    local procedure FilterBatch(Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    begin
        Line.Reset();
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
    end;

    local procedure InitArgument(var Argument: Record "Message Argument ori" temporary; Batch: Record "Item Journal Batch"; Request: JsonObject)
    begin
        Clear(Argument);
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Subject := Batch."Journal Template Name" + '|' + Batch.Name;
        Argument.Insert(true);
        Argument.SetRequestJson(Request);
    end;

    local procedure AssertConfirmationBoundary(LanguageId: Integer)
    var
        Item: Record Item;
        PendingValueEntry: Record "Post Value Entry to G/L";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Setup: Record "Inventory Setup ori";
        PreviousSetup: Record "Inventory Setup ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DomainCheck: Codeunit "Inv. MCP Fixture ori";
        FoundationSetup: RecordRef;
        Implementation: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        TypeName: Text;
        ItemLedgerCount: Integer;
        ValueEntryCount: Integer;
        Payload: Text;
        PreviousLanguage: Integer;
        Checked: Integer;
        Effect: JsonObject;
        Contract: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Parameter: JsonToken;
        Name: JsonToken;
        AdvertisesConfirmation: Boolean;
        SupportsConfirmation: Boolean;
        DeclaresConfirmation: Boolean;
        DeclaredParameters: JsonArray;
        PreviousConfirmation: Boolean;
        ChangedConfirmation: Boolean;
        HadSetup: Boolean;
    begin
        // [GIVEN] Domains are off. Since the Issue36 ruling (Gunnar 18.11.2026) that only hides the types; the handler is not refused for the domain
        // and stops at its own subject, validation or licence check instead, which the assertions below observe without a domain refusal.
        // Batch costing ignores Subject. Keep even confirmed calls away from existing company data.
        Item.SetRange("No.", 'XCONFIRM-BOUNDARY');
        Assert.IsTrue(Item.IsEmpty(), 'The boundary costing filter must match no item.');
        PendingValueEntry.SetRange("Item No.", 'XCONFIRM-BOUNDARY');
        Assert.IsTrue(PendingValueEntry.IsEmpty(), 'The boundary costing filter must match no pending value entry.');
        ChangedConfirmation := EnableRequiredConfirmation(FoundationSetup, PreviousConfirmation);
        ItemLedgerCount := ItemLedgerEntry.Count();
        ValueEntryCount := ValueEntry.Count();
        // No business document or ledger entry is created, posted or undone by this boundary test.
        HadSetup := PreviousSetup.Get();
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := false;
        Setup.Assembly := false;
        Setup.Costing := false;
        Setup."Phys. Inventory" := false;
        Setup.Reclassification := false;
        Setup.Planning := false;
        Setup.Modify();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        SupportsConfirmation := Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired');
        foreach TypeName in MessageType.Names() do
            if TypeName.StartsWith('Inventory.') and not TypeName.StartsWith('Inventory.ItemJournal.') then begin
                MessageType := Enum::"Message Type ori".FromInteger(MessageType.Ordinals().Get(MessageType.Names().IndexOf(TypeName)));
                Implementation := MessageType;
                Clear(Effect);
                if Implementation.GetEffect(Effect) then
                    if Effect.Get('effect', Token) then
                        if Token.AsValue().AsText() = 'irreversible' then begin
                            Checked += 1;
                            // An implementation can accept an optional count even before Foundation adds its gate.
                            DeclaresConfirmation := false;
                            Clear(DeclaredParameters);
                            if Implementation.GetParameters(DeclaredParameters) then
                                foreach Parameter in DeclaredParameters do
                                    if Parameter.AsObject().Get('name', Name) then
                                        if Name.AsValue().AsText() = 'expectedCount' then begin
                                            DeclaresConfirmation := true;
                                            AssertText(Parameter.AsObject(), 'type', 'integer');
                                            Assert.IsTrue(Parameter.AsObject().Get('required', Token), 'Explicit count declares whether it is required.');
                                            Assert.IsFalse(Token.AsValue().AsBoolean(), 'Handler count is optional; Foundation owns mandatory confirmation.');
                                        end;
                            Clear(Contract);
                            ContractMgt.GetContract(MessageType, Contract);
                            AdvertisesConfirmation := false;
                            if Contract.Get('parameters', Token) then
                                foreach Parameter in Token.AsArray() do
                                    if Parameter.AsObject().Get('name', Name) then
                                        if Name.AsValue().AsText() = 'expectedCount' then begin
                                            AdvertisesConfirmation := true;
                                            AssertText(Parameter.AsObject(), 'type', 'integer');
                                            Assert.IsTrue(Parameter.AsObject().Contains('description'), TypeName + ' documents confirmation.');
                                        end;
                            if TypeName in ['Inventory.TransferOrder.Ship', 'Inventory.TransferOrder.Receive'] then
                                Assert.IsTrue(AdvertisesConfirmation, TypeName + ' always documents its own optional count validation.');
                            Assert.AreEqual(SupportsConfirmation or DeclaresConfirmation, AdvertisesConfirmation,
                                TypeName + ' exposes the deployed Foundation protocol.');
                            Clear(Request);
                            if TypeName in ['Inventory.AdjustCost.Run', 'Inventory.CostToGL.Post'] then
                                Request.Add('itemNoFilter', 'XCONFIRM-BOUNDARY');
                            // An unnamed request is deliberately left to handler validation by Foundation #1278.
                            Response := DispatchWithSubject(MessageType, '', Request);
                            AssertHandlerRanWithoutDomainRefusal(DomainCheck, Response, TypeName);
                            // [WHEN] A named subject is previewed before the handler or any record lookup.
                            Response := Dispatch(MessageType, Request);
                            if SupportsConfirmation then begin
                                AssertText(Response, 'code', 'ConfirmationRequired');
                                AssertText(Response, 'parameter', 'expectedCount');
                                AssertText(Response, 'expected', '1');
                                Assert.IsFalse(Response.Contains('postedDocumentNo'), 'Preview must not post.');
                                // [THEN] A wrong count is refused; a matching count reaches the handler.
                                Request.Add('expectedCount', 2);
                                Response := Dispatch(MessageType, Request);
                                AssertText(Response, 'code', 'ConfirmationMismatch');
                                AssertText(Response, 'received', '2');
                                AssertText(Response, 'expected', '1');
                                Request.Replace('expectedCount', 1);
                                Response := Dispatch(MessageType, Request);
                            end;
                            // Legacy Foundation has no confirmation gate; it reaches this same handler directly.
                            AssertHandlerRanWithoutDomainRefusal(DomainCheck, Response, TypeName);
                            Response.WriteTo(Payload);
                            Assert.IsFalse(Payload.Contains('ConfirmationRequired') or Payload.Contains('ConfirmationMismatch'), TypeName + ': the handler ran after confirmation.');
                        end;
            end;
        GlobalLanguage(PreviousLanguage);
        if HadSetup then begin
            Setup.Get();
            Setup."Transfer Orders" := PreviousSetup."Transfer Orders";
            Setup.Assembly := PreviousSetup.Assembly;
            Setup.Costing := PreviousSetup.Costing;
            Setup."Phys. Inventory" := PreviousSetup."Phys. Inventory";
            Setup.Reclassification := PreviousSetup.Reclassification;
            Setup.Planning := PreviousSetup.Planning;
            Setup.Modify();
        end else
            Setup.Delete();
        Assert.AreEqual(12, Checked, 'All twelve app-owned irreversible Inventory types must be exercised.');
        Assert.AreEqual(ItemLedgerCount, ItemLedgerEntry.Count(), 'The boundary requests posted no item ledger entry.');
        Assert.AreEqual(ValueEntryCount, ValueEntry.Count(), 'The boundary requests posted no value entry.');
        RestoreConfirmation(FoundationSetup, ChangedConfirmation, PreviousConfirmation);
    end;

    local procedure EnableRequiredConfirmation(var FoundationSetup: RecordRef; var PreviousConfirmation: Boolean): Boolean
    var
        ConfirmationField: FieldRef;
        FieldIndex: Integer;
    begin
        if not Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired') then
            exit(false);
        FoundationSetup.Open(Database::"Setup ori");
        Assert.IsTrue(FoundationSetup.FindFirst(), 'Confirmation tests require existing Foundation setup.');
        for FieldIndex := 1 to FoundationSetup.FieldCount() do begin
            ConfirmationField := FoundationSetup.FieldIndex(FieldIndex);
            if ConfirmationField.Name() = 'Require Irreversible Confirm' then begin
                PreviousConfirmation := ConfirmationField.Value();
                ConfirmationField.Value := true;
                FoundationSetup.Modify();
                exit(true);
            end;
        end;
        // Earlier confirmation-capable Foundation versions always require confirmation.
        FoundationSetup.Close();
        exit(false);
    end;

    local procedure RestoreConfirmation(var FoundationSetup: RecordRef; ChangedConfirmation: Boolean; PreviousConfirmation: Boolean)
    var
        ConfirmationField: FieldRef;
        FieldIndex: Integer;
    begin
        if not ChangedConfirmation then
            exit;
        FoundationSetup.FindFirst();
        for FieldIndex := 1 to FoundationSetup.FieldCount() do begin
            ConfirmationField := FoundationSetup.FieldIndex(FieldIndex);
            if ConfirmationField.Name() = 'Require Irreversible Confirm' then begin
                ConfirmationField.Value := PreviousConfirmation;
                FoundationSetup.Modify();
                FoundationSetup.Close();
                exit;
            end;
        end;
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    begin
        // A named target is required: Foundation #1278 sends an unnamed request to normal validation.
        // The callers assert the exact confirmation codes; after confirmation the handler meets the unknown subject.
        Response := DispatchWithSubject(MessageType, 'XCONFIRM-BOUNDARY', Request);
    end;

    local procedure AssertHandlerRanWithoutDomainRefusal(var DomainCheck: Codeunit "Inv. MCP Fixture ori"; Response: JsonObject; TypeName: Text)
    var
        Payload: Text;
    begin
        Response.WriteTo(Payload);
        Assert.IsTrue(Payload.Contains('"status":"Error"') or Payload.Contains('"status":"Success"'), TypeName + ' answers a handler status: ' + Payload);
        Assert.IsFalse(DomainCheck.IsDomainRefusal(Payload), TypeName + ' must not refuse because its domain is off: ' + Payload);
    end;

    local procedure DispatchWithSubject(MessageType: Enum "Message Type ori"; Subject: Text[250]; Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ContentType: Text[100];
        Payload: Text;
        MessageId: Guid;
        EmptyTaskId: Guid;
        ResponseTime: Duration;
    begin
        // Deliberately bypass ConfirmRequest: missing and incorrect counts must reach the real dispatcher unchanged.
        Request.WriteTo(Payload);
        RequestContent.AddText(Payload);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", Subject, '', 'application/json', RequestContent,
            EmptyTaskId, GlobalLanguage(), MessageId, ResponseContent, ContentType, ResponseTime);
        ResponseContent.GetSubText(Payload, 1);
        Assert.IsTrue(Response.ReadFrom(Payload), 'Dispatcher returns a JSON response.');
    end;

    local procedure AssertText(Value: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
        Payload: Text;
    begin
        Value.WriteTo(Payload);
        Assert.IsTrue(Value.Get(KeyName, Token), 'Missing ' + KeyName + ': ' + Payload);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), 'Exact ' + KeyName);
    end;
}
