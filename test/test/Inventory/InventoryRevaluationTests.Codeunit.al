namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
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
        LibraryInventory: Codeunit "Library - Inventory";
        Revaluation: Codeunit "Inventory Revaluation ori";

    /// <summary>Report5899 fills only the selected item and leaves ledgers and the excluded item untouched.</summary>
    [Test]
    procedure Calculate_SelectedItem_CreatesNativeJournalOnly()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ValueCount: Integer;
    begin
        // Accepted Calculate scope | Time: WorkDate | Risk: native report must create journal, not an estimate or ledger write.
        CreateStock(Item);
        CreateStock(OtherItem);
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        ValueCount := ValueEntry.Count();
        CalculationRequest(Request, Item."No.");
        InitArgument(TempArgument, Batch, Request);
        Revaluation.Calculate(TempArgument);
        FilterLines(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'One self-created receipt produces one native revaluation line.');
        Line.FindFirst();
        Assert.AreEqual(Item."No.", Line."Item No.", 'Native item filter excludes other stock.');
        Assert.AreEqual(Line."Value Entry Type"::Revaluation, Line."Value Entry Type", 'Native revaluation line type.');
        Assert.IsTrue(Line."Applies-to Entry" > 0, 'Native source ledger entry is recorded.');
        Assert.AreEqual(2, Line.Quantity, 'Native remaining quantity.');
        Assert.AreEqual(24, Line."Inventory Value (Calculated)", 'Actual posted value.');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'Calculate creates no ledger values.');
        Response := TempArgument.GetResponseJson();
        Response.Get('linesCreated', Token);
        Assert.AreEqual(Line.Count(), Token.AsValue().AsInteger(), 'Truthful created count.');
    end;

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
        Assert.IsTrue(Line.IsEmpty(), 'Posted batch cleared by native posting.');
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

    /// <summary>Calculate refuses a populated batch rather than creating duplicate proposals or showing confirmation.</summary>
    [Test]
    procedure Calculate_NonemptyBatch_RefusesDuplicates()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateProposal(Item, Batch, Line);
        CalculationRequest(Request, Item."No.");
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Revaluation.Calculate(TempArgument);
        Assert.ExpectedError('empty revaluation batch');
        FilterLines(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'Existing proposal unchanged.');
    end;

    /// <summary>Calculate refuses a non-Revaluation journal before native work.</summary>
    [Test]
    procedure Calculate_WrongTemplate_Refuses()
    var
        Batch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateBatch(Batch, Batch."Template Type"::Item);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Revaluation.Calculate(TempArgument);
        Assert.ExpectedError('Revaluation');
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

    /// <summary>SystemId batch identification supports native calculation without subject-key parsing.</summary>
    [Test]
    procedure Calculate_SystemIdAndEmptySelection_ReturnsZeroLines()
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        CalculationRequest(Request, 'NO-OWNED-STOCK');
        InitArgument(TempArgument, Batch, Request);
        TempArgument.Subject := Format(Batch.SystemId, 0, 4);
        Revaluation.Calculate(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('linesCreated', Token);
        Assert.AreEqual(0, Token.AsValue().AsInteger(), 'No matching stock is not a fake nonzero calculation.');
        FilterLines(Batch, Line);
        Assert.IsTrue(Line.IsEmpty(), 'Empty native selection has no writes.');
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
        Revaluation.Calculate(TempArgument);
        FilterLines(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native calculation creates the owned proposal.');
        Line.Validate("Inventory Value (Revalued)", 40);
        Line.Modify(true);
    end;

    local procedure CreateStock(var Item: Record Item)
    var
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
        InventorySetup.Modify();
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 2);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
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
}
