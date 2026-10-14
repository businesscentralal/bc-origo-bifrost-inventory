namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
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
        ContractLibrary: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Revaluation: Codeunit "Inventory Revaluation ori";

    /// <summary>Published Calculate Help data executes against owned stock and leaves excluded stock and ledgers unchanged.</summary>
    [Test]
    procedure Calculate_HelpExample_CreatesOnlyOwnedJournalLines()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        TempArgument: Record "Message Argument ori" temporary;
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Example: JsonObject;
        Envelope: JsonObject;
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
        ContractMgt.GetContract("Message Type ori"::"Inventory.Revaluation.Calculate", Contract);
        Contract.Get('examples', Token);
        Token.AsArray().Get(0, Token);
        Example := Token.AsObject();
        Example.Get('request', Token);
        Envelope := Token.AsObject();
        Envelope.Get('data', Token);
        Request := Token.AsObject();
        Request.Replace('itemNo', Item."No.");
        Request.Replace('postingDate', Format(WorkDate(), 0, 9));
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
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Revaluation.Calculate", Response);
        Response.Get('linesCreated', Token);
        Assert.AreEqual(Line.Count(), Token.AsValue().AsInteger(), 'Truthful created count.');
    end;

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
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Revaluation.Calculate", Response);
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

    /// <summary>Explicit template/batch data parameters resolve a native batch with no subject.</summary>
    [Test]
    procedure Calculate_DataBatchKey_UsesNativePerItemMode()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateStock(Item);
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        CalculationRequest(Request, Item."No.");
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        Request.Add('calculatePer', 'Item');
        Request.Add('byLocation', true);
        Request.Add('byVariant', true);
        InitArgument(TempArgument, Batch, Request);
        TempArgument.Subject := '';
        Revaluation.Calculate(TempArgument);
        FilterLines(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native per-item calculation creates a journal proposal.');
        Assert.AreEqual(0, Line."Applies-to Entry", 'Native per-item mode aggregates rather than binding an entry.');
        Assert.AreEqual(24, Line."Inventory Value (Calculated)", 'Native aggregated value.');
    end;

    /// <summary>Malformed calculate options fail before the report writes any journal proposal.</summary>
    [Test]
    procedure Calculate_InvalidGrouping_LeavesEmptyBatch()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateStock(Item);
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        CalculationRequest(Request, Item."No.");
        Request.Add('byLocation', true);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Revaluation.Calculate(TempArgument);
        Assert.ExpectedError('require calculatePer=Item');
        FilterLines(Batch, Line);
        Assert.IsTrue(Line.IsEmpty(), 'Rejected option combination cannot create proposals.');
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

    /// <summary>Native location and variant filters exclude other stock of the same item in entry mode.</summary>
    [Test]
    procedure Calculate_LocationVariant_EntryModePreservesOtherStock()
    begin
        VerifyLocationVariantFilter(false);
    end;

    /// <summary>Native per-item grouping retains the selected location and variant without including other stock.</summary>
    [Test]
    procedure Calculate_LocationVariant_ItemModePreservesOtherStock()
    begin
        VerifyLocationVariantFilter(true);
    end;

    local procedure VerifyLocationVariantFilter(PerItem: Boolean)
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ReceiptTemplate: Record "Item Journal Template";
        ReceiptBatch: Record "Item Journal Batch";
        ReceiptLine: Record "Item Journal Line";
        Ledger: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        LedgersBefore: Integer;
        ValuesBefore: Integer;
    begin
        CreateStock(Item);
        LibraryInventory.CreateItemVariant(Variant, Item."No.");
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        LibraryInventory.CreateItemJournalTemplate(ReceiptTemplate);
        LibraryInventory.CreateItemJournalBatch(ReceiptBatch, ReceiptTemplate.Name);
        LibraryInventory.CreateItemJournalLine(ReceiptLine, ReceiptTemplate.Name, ReceiptBatch.Name, ReceiptLine."Entry Type"::"Positive Adjmt.", Item."No.", 3);
        ReceiptLine.Validate("Location Code", Location.Code);
        ReceiptLine.Validate("Variant Code", Variant.Code);
        ReceiptLine.Validate("Posting Date", WorkDate());
        ReceiptLine.Validate("Unit Amount", 15);
        ReceiptLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ReceiptTemplate.Name, ReceiptBatch.Name);
        LedgersBefore := Ledger.Count();
        ValuesBefore := ValueEntry.Count();
        CreateBatch(Batch, Batch."Template Type"::Revaluation);
        CalculationRequest(Request, Item."No.");
        Request.Add('locationCode', Location.Code);
        Request.Add('variantCode', Variant.Code);
        if PerItem then begin
            Request.Add('calculatePer', 'Item');
            Request.Add('byLocation', true);
            Request.Add('byVariant', true);
        end;
        InitArgument(TempArgument, Batch, Request);
        Revaluation.Calculate(TempArgument);
        FilterLines(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'Only the selected stock is proposed.');
        Line.FindFirst();
        Assert.AreEqual(Location.Code, Line."Location Code", 'Native selected location is retained.');
        Assert.AreEqual(Variant.Code, Line."Variant Code", 'Native selected variant is retained.');
        Assert.AreEqual(3, Line.Quantity, 'The two blank-location/variant units remain excluded.');
        Assert.AreEqual(45, Line."Inventory Value (Calculated)", 'Only selected posted value is calculated.');
        if PerItem then
            Assert.AreEqual(0, Line."Applies-to Entry", 'Per-item mode uses native grouped valuation.')
        else begin
            Ledger.Get(Line."Applies-to Entry");
            Assert.AreEqual(Location.Code, Ledger."Location Code", 'Entry mode binds selected native entry.');
            Assert.AreEqual(Variant.Code, Ledger."Variant Code", 'Entry mode binds selected variant.');
        end;
        Assert.AreEqual(LedgersBefore, Ledger.Count(), 'Calculation does not change item entries.');
        Assert.AreEqual(ValuesBefore, ValueEntry.Count(), 'Calculation does not change value entries.');
        Ledger.Reset();
        Ledger.SetRange("Item No.", Item."No.");
        Ledger.SetRange("Location Code", '');
        Ledger.SetRange("Variant Code", '');
        Ledger.CalcSums("Remaining Quantity");
        Assert.AreEqual(2, Ledger."Remaining Quantity", 'Excluded native stock is unchanged.');
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
        Revaluation.Calculate(TempArgument);
        FilterLines(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'One native proposal for the self-posted item.');
        Line.FindFirst();
        Assert.AreEqual(24, Line."Inventory Value (Calculated)", 'Native cost before revaluation.');
        Assert.AreEqual(2, Line.Quantity, 'Native remaining quantity.');
        Assert.IsFalse(Line."Update Standard Cost", 'Calculation does not opt into changing the standard cost.');
        Line.Validate("Inventory Value (Revalued)", 40);
        Line.Modify(true);
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
        Revaluation.Calculate(TempArgument);
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
