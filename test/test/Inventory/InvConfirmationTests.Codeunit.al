namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Finance.GeneralLedger.Setup;
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

    [MessageHandler]
    procedure NativeMessageHandler(Message: Text[1024])
    begin
        // Native posting may emit informational completion messages in an interactive session.
    end;

    local procedure VerifyNativeSuccess(LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        PreviousLanguage: Integer;
    begin
        // [GIVEN] Normal posting setup, all required domains and newly created native source records.
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
    end;

    local procedure VerifyTransfer()
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransit: Record Location;
        Item: Record Item;
        Header: Record "Transfer Header";
        Helper: Codeunit "Transfer Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransit, Item, 10);
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
        ConfirmAndRun("Message Type ori"::"Inventory.AdjustCost.Run", '', Request, Response);
        Clear(Request);
        Request.Add('itemNoFilter', Item."No.");
        ConfirmAndRun("Message Type ori"::"Inventory.CostToGL.Post", '', Request, Response);
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
        LibraryWarehouse: Codeunit "Library - Warehouse";
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
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 2);
        Line.Validate("New Location Code", Location.Code);
        Line.Modify(true);
        Clear(Request);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        ConfirmAndRun("Message Type ori"::"Inventory.Reclassification.Post", '', Request, Response);
        Item.SetRange("Location Filter", Location.Code);
        Item.CalcFields(Inventory);
        Assert.AreEqual(2, Item.Inventory, 'Confirmed native reclassification moves the owned stock.');
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
        Setup: Record "Inventory Setup ori";
        PreviousSetup: Record "Inventory Setup ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Implementation: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        TypeName: Text;
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
        HadSetup: Boolean;
    begin
        // [GIVEN] Disabled domains create a safe, observable handler refusal after the confirmation gate.
        // No business document or ledger entry is created, posted or undone by this boundary test.
        HadSetup := PreviousSetup.Get();
        Setup.InsertIfNotExists();
        Setup."Transfer Orders" := false;
        Setup.Assembly := false;
        Setup.Costing := false;
        Setup."Phys. Inventory" := false;
        Setup.Reclassification := false;
        Setup.Modify();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        foreach TypeName in MessageType.Names() do
            if TypeName.StartsWith('Inventory.') and not TypeName.StartsWith('Inventory.ItemJournal.') then begin
                MessageType := Enum::"Message Type ori".FromInteger(MessageType.Ordinals().Get(MessageType.Names().IndexOf(TypeName)));
                Implementation := MessageType;
                Clear(Effect);
                if Implementation.GetEffect(Effect) then
                    if Effect.Get('effect', Token) then
                        if Token.AsValue().AsText() = 'irreversible' then begin
                            Checked += 1;
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
                            Assert.AreEqual(Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired'), AdvertisesConfirmation,
                                TypeName + ' exposes the deployed Foundation protocol.');
                            Clear(Request);
                            // [WHEN] Dispatch without confirmation; newer Foundation must refuse before the handler.
                            Response := Dispatch(MessageType, Request);
                            if AdvertisesConfirmation then begin
                                AssertText(Response, 'code', 'ConfirmationRequired');
                                AssertText(Response, 'parameter', 'expectedCount');
                                AssertText(Response, 'expected', '1');
                                Assert.IsFalse(Response.Contains('postedDocumentNo'), 'Preview must not post.');
                                // [THEN] A wrong count is refused; a matching count reaches the real domain gate.
                                Request.Add('expectedCount', 2);
                                Response := Dispatch(MessageType, Request);
                                AssertText(Response, 'code', 'ConfirmationMismatch');
                                AssertText(Response, 'received', '2');
                                AssertText(Response, 'expected', '1');
                                Request.Replace('expectedCount', 1);
                                Response := Dispatch(MessageType, Request);
                            end;
                            // Legacy Foundation has no confirmation gate; it reaches this same handler directly.
                            AssertText(Response, 'code', 'InvalidParameter');
                            Assert.IsTrue(Response.Get('nextStep', Token), 'Handler domain refusal supplies a next action.');
                            Assert.IsFalse(Token.AsValue().AsText() = '', 'The handler ran after confirmation.');
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
            Setup.Modify();
        end else
            Setup.Delete();
        Assert.AreEqual(9, Checked, 'All nine app-owned irreversible types must be exercised.');
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject) Response: JsonObject
    begin
        Response := DispatchWithSubject(MessageType, '', Request);
        AssertText(Response, 'status', 'Error');
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
    begin
        Assert.IsTrue(Value.Get(KeyName, Token), 'Missing ' + KeyName);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), 'Exact ' + KeyName);
    end;
}
