namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Self-posted stock proves native revaluation calculation, preview, posting and refusal boundaries.</summary>
codeunit 96941 "Inventory Revaluation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ContractLibrary: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryCosting: Codeunit "Library - Costing";
        Revaluation: Codeunit "Inventory Revaluation ori";

    /// <summary>Native preview captures revaluation value entries and preserves journal/ledger rows exactly.</summary>
    [Test]
    procedure Scenario_AC05_Preview_RollsBackNativeLedgerChanges()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
        Register: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ValuesBefore: Integer;
        GLBefore: Integer;
        RegistersBefore: Integer;
    begin
        CreateProposal(Item, Batch, Line);
        ValuesBefore := ValueEntry.Count();
        GLBefore := GLEntry.Count();
        RegistersBefore := Register.Count();
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Revaluation.Preview(TempArgument);
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Revaluation.PreviewPost", Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Native posting preview succeeds.');
        Response.Get('rollback', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'Native rollback reported.');
        Response.Get('preview', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Actual predicted ledger entries, not echoed journal lines.');
        Assert.AreEqual(ValuesBefore, ValueEntry.Count(), 'No value entries committed.');
        Assert.AreEqual(GLBefore, GLEntry.Count(), 'No G/L entries committed.');
        Assert.AreEqual(RegistersBefore, Register.Count(), 'No item register committed.');
        FilterLines(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'Journal proposal preserved.');
        Line.FindFirst();
        Assert.AreEqual(40, Line."Inventory Value (Revalued)", 'Proposed value preserved.');
    end;

    /// <summary>Native posting emits the actual item register/value entry range and clears only the selected batch.</summary>
    [Test]
    procedure Scenario_AC06_Post_ReturnsActualRegisterAndValue()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Batch: Record "Item Journal Batch";
        OtherBatch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        Register: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateProposal(Item, Batch, Line);
        CreateProposal(OtherItem, OtherBatch, OtherLine);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Assert.IsTrue(Codeunit.Run(Codeunit::"Inv Reval Post Process ori", TempArgument), GetLastErrorText());
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Revaluation.Post", Response);
        Response.Get('itemRegisterNo', Token);
        Register.Get(Token.AsValue().AsInteger());
        Response.Get('fromValueEntryNo', Token);
        Assert.AreEqual(Register."From Value Entry No.", Token.AsValue().AsInteger(), 'Actual register start.');
        Response.Get('toValueEntryNo', Token);
        Assert.AreEqual(Register."To Value Entry No.", Token.AsValue().AsInteger(), 'Actual register end.');
        ValueEntry.SetRange("Entry No.", Register."From Value Entry No.", Register."To Value Entry No.");
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.SetRange("Entry Type", ValueEntry."Entry Type"::Revaluation);
        ValueEntry.CalcSums("Cost Amount (Actual)");
        Assert.AreEqual(16, ValueEntry."Cost Amount (Actual)", 'Native revaluation delta 40 minus 24.');
        FilterLines(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native posting creates its next blank journal line.');
        Assert.IsTrue(Line.EmptyLine(), 'Native replacement row is empty.');
        Line.SetFilter("Item No.", '<>%1', '');
        Assert.IsTrue(Line.IsEmpty(), 'No posted item proposal remains in the batch.');
        FilterLines(OtherBatch, OtherLine);
        Assert.AreEqual(1, OtherLine.Count(), 'Unselected batch preserved.');
        Response.Get('linesPosted', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Actual nonempty native line count.');
    end;

    /// <summary>A valid first line followed by an invalid second line cannot leave partial native postings.</summary>
    [Test]
    procedure Scenario_AC06_PostFailure_PreservesJournalAndLedgers()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        InvalidLine: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        Register: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        ValuesBefore: Integer;
        RegistersBefore: Integer;
    begin
        CreateProposal(Item, Batch, Line);
        InvalidLine := Line;
        InvalidLine."Line No." += 10000;
        InvalidLine."Posting Date" := 0D;
        InvalidLine.Insert(false);
        ValuesBefore := ValueEntry.Count();
        RegistersBefore := Register.Count();
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Reval Post Process ori", TempArgument), 'Native invalid date fails the whole process.');
        Assert.IsTrue(GetLastErrorText() <> '', 'Actual native failure retained.');
        Assert.AreEqual(ValuesBefore, ValueEntry.Count(), 'No partial ledger write.');
        Assert.AreEqual(RegistersBefore, Register.Count(), 'No partial register.');
        FilterLines(Batch, Line);
        Assert.AreEqual(2, Line.Count(), 'Both journal lines survive refusal.');
    end;

    /// <summary>Post refuses a non-Revaluation journal before native work.</summary>
    [Test]
    procedure Post_WrongTemplate_Refuses()
    var
        Batch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateBatch(Batch, Batch."Template Type"::Item);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Revaluation.Post(TempArgument);
        Assert.ExpectedError('Revaluation');
    end;

    /// <summary>Preview refuses a non-Revaluation journal before native work.</summary>
    [Test]
    procedure Preview_WrongTemplate_Refuses()
    var
        Batch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateBatch(Batch, Batch."Template Type"::Item);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Revaluation.Preview(TempArgument);
        Assert.ExpectedError('Revaluation');
    end;

    /// <summary>The process rolls back an error after actual native value-entry insertion, not merely prevalidation.</summary>
    [Test]
    procedure Post_AfterNativeInsertFailure_RollsBackActualWrite()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inv Revaluation Observer";
        Request: JsonObject;
        ValuesBefore: Integer;
    begin
        CreateProposal(Item, Batch, Line);
        ValuesBefore := ValueEntry.Count();
        InitArgument(TempArgument, Batch, Request);
        Observer.SetItem(Item."No.");
        BindSubscription(Observer);
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Reval Post Process ori", TempArgument), 'Post-insert failure rolls back the process.');
        Assert.ExpectedError('Owned revaluation failure after native value entry insertion');
        UnbindSubscription(Observer);
        Assert.AreEqual(ValuesBefore, ValueEntry.Count(), 'The real inserted value entry was rolled back.');
        FilterLines(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'Proposal survives failed native posting.');
    end;

    /// <summary>LIFO revaluation preserves native preview rollback and posts the exact owned value delta.</summary>
    [Test]
    procedure Revaluation_LIFO_NativePreviewAndPost()
    begin
        VerifyCostingMethod("Costing Method"::LIFO);
    end;

    /// <summary>Average revaluation preserves native preview rollback and posts the exact owned value delta.</summary>
    [Test]
    procedure Revaluation_Average_NativePreviewAndPost()
    begin
        VerifyCostingMethod("Costing Method"::Average);
    end;

    /// <summary>Standard revaluation preserves native preview rollback and posts the exact owned value delta.</summary>
    [Test]
    procedure Revaluation_Standard_NativePreviewAndPost()
    begin
        VerifyCostingMethod("Costing Method"::Standard);
    end;

    /// <summary>Specific costing revalues the exact two serial-number entries through native preview and posting.</summary>
    [Test]
    procedure Revaluation_Specific_NativeSerialPreviewAndPost()
    begin
        VerifyCostingMethod("Costing Method"::Specific);
    end;

    local procedure VerifyCostingMethod(Method: Enum "Costing Method")
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        Ledger: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ValuesBefore: Integer;
        LedgersBefore: Integer;
    begin
        CreateStockWithMethod(Item, Method);
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        CalculationRequest(Request, Item."No.");
        if Method = Method::Average then
            Request.Add('calculatePer', 'Item');
        InitArgument(TempArgument, Batch, Request);
        CreateNativeProposal(TempArgument);
        FilterLines(Batch, Line);
        if Method = Method::Specific then
            Assert.AreEqual(2, Line.Count(), 'Each native serial entry has its own proposal.')
        else
            Assert.AreEqual(1, Line.Count(), 'One native proposal for the self-posted item.');
        Line.CalcSums(Quantity, "Inventory Value (Calculated)");
        Assert.AreEqual(24, Line."Inventory Value (Calculated)", 'Native cost before revaluation.');
        Assert.AreEqual(2, Line.Quantity, 'Native remaining quantity.');
        Line.FindSet();
        repeat
            Assert.IsFalse(Line."Update Standard Cost", 'Calculation does not opt into changing the standard cost.');
            if Method = Method::Specific then begin
                Ledger.Get(Line."Applies-to Entry");
                Assert.IsTrue(Ledger."Serial No." in ['RV-SERIAL-1', 'RV-SERIAL-2'], 'Proposal binds one self-posted native serial.');
                Assert.AreEqual(1, Line.Quantity, 'One unit per serial entry.');
                Line.Validate("Inventory Value (Revalued)", 20);
            end else
                Line.Validate("Inventory Value (Revalued)", 40);
            Line.Modify(true);
        until Line.Next() = 0;
        ValuesBefore := ValueEntry.Count();
        LedgersBefore := Ledger.Count();
        Clear(Request);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Revaluation.Preview(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Native preview succeeds for the costing method.');
        Response.Get('preview', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Preview contains predicted entries.');
        Assert.AreEqual(ValuesBefore, ValueEntry.Count(), 'Preview commits no value entry.');
        Assert.AreEqual(LedgersBefore, Ledger.Count(), 'Preview commits no item entry.');
        FilterLines(Batch, Line);
        if Method = Method::Specific then
            Assert.AreEqual(2, Line.Count(), 'Preview preserves both serial proposals.')
        else
            Assert.AreEqual(1, Line.Count(), 'Preview preserves the proposed journal line.');
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Assert.IsTrue(Codeunit.Run(Codeunit::"Inv Reval Post Process ori", TempArgument), GetLastErrorText());
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.SetRange("Entry Type", ValueEntry."Entry Type"::Revaluation);
        ValueEntry.CalcSums("Cost Amount (Actual)");
        Assert.AreEqual(16, ValueEntry."Cost Amount (Actual)", 'Native posting adds exactly the proposed delta.');
        Assert.AreEqual(LedgersBefore, Ledger.Count(), 'Revaluation creates no quantity movements.');
        Item.Get(Item."No.");
        if Method = Method::Standard then
            Assert.AreEqual(12, Item."Standard Cost", 'Revaluation without update option preserves the standard cost.');
        FilterLines(Batch, Line);
        Line.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Line.IsEmpty(), 'The posted proposal is removed.');
    end;

    local procedure CreateProposal(var Item: Record Item; var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateStock(Item);
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        CalculationRequest(Request, Item."No.");
        InitArgument(TempArgument, Batch, Request);
        CreateNativeProposal(TempArgument);
        FilterLines(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native calculation creates the owned proposal.');
        Line.Validate("Inventory Value (Revalued)", 40);
        Line.Modify(true);
    end;

    local procedure CreateStock(var Item: Record Item)
    begin
        CreateStockWithMethod(Item, "Costing Method"::FIFO);
    end;

    local procedure CreateStockWithMethod(var Item: Record Item; Method: Enum "Costing Method")
    var
        TrackingCode: Record "Item Tracking Code";
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
    begin
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup."Average Cost Period" := InventorySetup."Average Cost Period"::Day;
        InventorySetup."Average Cost Calc. Type" := InventorySetup."Average Cost Calc. Type"::Item;
        InventorySetup.Modify();
        LibraryInventory.CreateItem(Item);
        if Method = Method::Specific then begin
            LibraryInventory.CreateItemTrackingCode(TrackingCode);
            TrackingCode.Validate("SN Specific Tracking", true);
            TrackingCode.Modify(true);
            Item.Validate("Item Tracking Code", TrackingCode.Code);
        end;
        Item.Validate("Costing Method", Method);
        if Method = Method::Standard then
            Item.Validate("Standard Cost", 12);
        Item.Modify(true);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 2);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        if Method = Method::Specific then
            AssignNativeSerials(JournalLine);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
        if Method = Method::Average then
            LibraryCosting.AdjustCostItemEntries(Item."No.", '');
    end;

    local procedure AssignNativeSerials(Line: Record "Item Journal Line")
    var
        Source: Record "Tracking Specification";
        TempTracking: Record "Tracking Specification" temporary;
        Reserve: Codeunit "Item Jnl. Line-Reserve";
        TrackingLines: Page "Item Tracking Lines";
        SerialIndex: Integer;
    begin
        Reserve.InitFromItemJnlLine(Source, Line);
        for SerialIndex := 1 to 2 do begin
            TempTracking := Source;
            TempTracking."Entry No." := SerialIndex;
            TempTracking."Quantity (Base)" := 1;
            TempTracking."Serial No." := CopyStr('RV-SERIAL-' + Format(SerialIndex), 1, 50);
            TempTracking.Insert();
        end;
        TrackingLines.SetBlockCommit(true);
        TrackingLines.RegisterItemTrackingLines(Source, WorkDate(), TempTracking);
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch"; JournalType: Enum "Item Journal Template Type")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalType);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;

    local procedure FilterLines(Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    begin
        Line.Reset();
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
    end;

    local procedure CalculationRequest(var Request: JsonObject; ItemNo: Code[20])
    begin
        Request.Add('itemNo', ItemNo);
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Request.Add('documentNo', 'OWNED-REVAL');
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary; Batch: Record "Item Journal Batch"; Request: JsonObject)
    begin
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Subject := Batch."Journal Template Name" + '|' + Batch.Name;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
    end;
    local procedure CreateNativeProposal(var Argument: Record "Message Argument ori")
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Item: Record Item;
        CalculateValue: Report "Calculate Inventory Value";
        Request: JsonObject;
        Token: JsonToken;
        Parts: List of [Text];
        CalculatePer: Enum "Inventory Value Calc. Per";
    begin
        Parts := Argument.Subject.Split('|');
        Batch.Get(Parts.Get(1), Parts.Get(2));
        Request := Argument.GetRequestJson();
        Request.Get('itemNo', Token);
        Item.SetRange("No.", Token.AsValue().AsText());
        CalculatePer := "Inventory Value Calc. Per"::"Item Ledger Entry";
        if Request.Get('calculatePer', Token) then
            if Token.AsValue().AsText() = 'Item' then
                CalculatePer := "Inventory Value Calc. Per"::Item;
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        CalculateValue.SetItemJnlLine(Line);
        CalculateValue.SetParameters(WorkDate(), 'REVAL-TEST', false, CalculatePer, false, false, false, "Inventory Value Calc. Base"::" ", false);
        CalculateValue.SetTableView(Item);
        CalculateValue.UseRequestPage(false);
        CalculateValue.Run();
    end;
}
