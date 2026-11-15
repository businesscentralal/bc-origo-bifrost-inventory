namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Self-created native stock verifies dedicated journal selection, checks, preview and posting isolation.</summary>
codeunit 96944 "Inventory Physical Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ContractLibrary: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        Journal: Codeunit "Inventory Native Journal ori";

    [Test]
    [HandlerFunctions('CostPostMessageHandler')]
    procedure CostToGL_PostsSelectedItemOnly()
    begin
        VerifyCostToGLPosting(false);
    end;

    [Test]
    [HandlerFunctions('CostPostMessageHandler')]
    procedure CostToGL_AppliesDocumentAndItemFilters()
    begin
        VerifyCostToGLPosting(true);
    end;

    [MessageHandler]
    procedure CostPostMessageHandler(Message: Text[1024])
    begin
        // Native report statistics; posting and selection are asserted from actual ledgers below.
    end;

    local procedure VerifyCostToGLPosting(UseDocumentFilter: Boolean)
    var
        Item: Record Item;
        OtherItem: Record Item;
        ValueEntry: Record "Value Entry";
        OtherValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
        Helper: Codeunit "Assembly Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
        OtherEntryNo: Integer;
        BeforeCount: Integer;
        ResponseText: Text;
    begin
        CreateStock(Item);
        CreateStock(OtherItem);
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.FindFirst();
        EntryNo := ValueEntry."Entry No.";
        OtherValueEntry.SetRange("Item No.", OtherItem."No.");
        OtherValueEntry.FindFirst();
        OtherEntryNo := OtherValueEntry."Entry No.";
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'Owned selected cost is unposted.');
        Assert.AreEqual(0, OtherValueEntry."Cost Posted to G/L", 'Owned other cost is unposted.');
        if UseDocumentFilter then begin
            Assert.AreNotEqual(ValueEntry."Document No.", OtherValueEntry."Document No.", 'Own fixture documents differ.');
            Request.Add('itemNoFilter', Item."No." + '|' + OtherItem."No.");
            Request.Add('documentNoFilter', ValueEntry."Document No.");
        end else
            Request.Add('itemNoFilter', Item."No.");
        BeforeCount := GLEntry.Count();
        Helper.ProcessMessage("Message Type ori"::"Inventory.CostToGL.Post", Request, Response);
        Response.Get('status', Token);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Response.Get('posted', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'Actual selected entries posted.');
        Response.Get('postedValueEntryCount', Token);
        Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'Actual posted count.');
        ValueEntry.Get(EntryNo);
        OtherValueEntry.Get(OtherEntryNo);
        Assert.AreEqual(ValueEntry."Cost Amount (Actual)", ValueEntry."Cost Posted to G/L", 'Selected value entry cost is posted.');
        Assert.AreEqual(0, OtherValueEntry."Cost Posted to G/L", 'Unselected value entry remains unposted.');
        Assert.IsTrue(GLEntry.Count() > BeforeCount, 'Real G/L entries were created.');
    end;

    [Test]
    procedure ReclassPost_RejectsItemTemplate_1033()
    begin
        VerifyWrongReclassTemplate("Item Journal Template Type"::Item, 1033);
    end;

    [Test]
    procedure ReclassPost_RejectsItemTemplate_1039()
    begin
        VerifyWrongReclassTemplate("Item Journal Template Type"::Item, 1039);
    end;

    [Test]
    procedure ReclassPost_RejectsPhysicalTemplate_1033()
    begin
        VerifyWrongReclassTemplate("Item Journal Template Type"::"Phys. Inventory", 1033);
    end;

    [Test]
    procedure ReclassPost_RejectsPhysicalTemplate_1039()
    begin
        VerifyWrongReclassTemplate("Item Journal Template Type"::"Phys. Inventory", 1039);
    end;

    [Test]
    procedure ReclassPost_RejectsRevaluationTemplate_1033()
    begin
        VerifyWrongReclassTemplate("Item Journal Template Type"::Revaluation, 1033);
    end;

    [Test]
    procedure ReclassPost_RejectsRevaluationTemplate_1039()
    begin
        VerifyWrongReclassTemplate("Item Journal Template Type"::Revaluation, 1039);
    end;

    /// <summary>Calculate uses report 790 and its item filter, leaves ledgers untouched, and refuses duplicate proposals.</summary>
    [Test]
    procedure Scenario_AC01_Calculate_SelectedStockCreatesNativeLines()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
    begin
        CreateStock(Item);
        CreateStock(OtherItem);
        CreateBatch(Batch, "Item Journal Template Type"::"Phys. Inventory");
        CalculationRequest(Request, Item."No.");
        InitArgument(TempArgument, Batch, Request);
        BeforeCount := Entries.Count();
        Journal.Calculate(TempArgument);
        FilterBatch(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'Only selected owned item is calculated.');
        Line.FindFirst();
        Assert.AreEqual(Item."No.", Line."Item No.", 'Item filter is honored.');
        Assert.IsTrue(Line."Phys. Inventory", 'Native physical line flag.');
        Assert.AreEqual(10, Line."Qty. (Calculated)", 'Report calculates actual posted stock.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Calculation creates no ledger rows.');
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.PhysInventory.Calculate", Response);
        Response.Get('linesCreated', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Actual inserted count returned.');
        Commit();
        asserterror Journal.Calculate(TempArgument);
        Assert.ExpectedError('empty physical');
        Assert.AreEqual(1, Line.Count(), 'Repeat cannot append duplicate count lines.');
    end;

    /// <summary>Calculate without the required postingDate answers an error naming postingDate and writes no lines (#122 F2).</summary>
    [Test]
    procedure Scenario_AC01_Calculate_MissingPostingDate_Refuses()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] Stock and an empty physical inventory batch.
        CreateStock(Item);
        CreateBatch(Batch, "Item Journal Template Type"::"Phys. Inventory");
        // [WHEN] Calculate runs with a document number and item filter but no postingDate.
        Request.Add('documentNo', 'COUNT-NODATE');
        Request.Add('itemNo', Item."No.");
        InitArgument(TempArgument, Batch, Request);
        Journal.Calculate(TempArgument);
        // [THEN] The response is an error on postingDate and the batch stays empty.
        Response := TempArgument.GetResponseJson();
        Assert.IsTrue(Response.Get('status', Token), 'status missing');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'postingDate is required.');
        Assert.IsTrue(Response.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('postingDate', Token.AsValue().AsText(), 'The error names postingDate.');
        FilterBatch(Batch, Line);
        Assert.IsTrue(Line.IsEmpty(), 'No journal line is created without a posting date.');
    end;

    /// <summary>Omitted count leaves the native value untouched and explicit zero runs Validate to produce the full shortage.</summary>
    [Test]
    procedure Scenario_AC02_RecordCount_OmittedAndZeroDiffer()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Count: JsonObject;
        Counts: JsonArray;
        Token: JsonToken;
        BeforeQuantity: Decimal;
    begin
        CreatePhysical(Item, Batch, Line);
        BeforeQuantity := Line."Qty. (Phys. Inventory)";
        Count.Add('lineNo', Line."Line No.");
        Counts.Add(Count);
        Request.Add('counts', Counts);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(BeforeQuantity, Line."Qty. (Phys. Inventory)", 'Omitted quantity is not a zero write.');
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.PhysInventory.RecordCount", Response);
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Token.AsObject().Get('counted', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Omitted count explicitly identified.');
        Clear(Request);
        AddCount(Request, Line.SystemId, 0);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(0, Line."Qty. (Phys. Inventory)", 'Explicit zero means counted none.');
        Assert.AreEqual(10, Line.Quantity, 'Native Validate calculates shortage.');
        Assert.AreEqual(Line."Entry Type"::"Negative Adjmt.", Line."Entry Type", 'Native delta sign is retained.');
        Response := TempArgument.GetResponseJson();
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Token.AsObject().Get('before', Token);
        Assert.AreEqual(BeforeQuantity, Token.AsValue().AsDecimal(), 'Before value returned for the changed line.');
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Token.AsObject().Get('counted', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'Explicit zero is a submitted count.');

        // Story #6, AC2 | Time: native WorkDate fixture | Risk: zero value mistaken for a submitted count on a later omitted request.
        Clear(Request);
        Request.Add('counts', Counts);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(0, Line."Qty. (Phys. Inventory)", 'Omission after zero preserves the recorded count.');
        Assert.AreEqual(10, Line.Quantity, 'Omission preserves the native shortage.');
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.PhysInventory.RecordCount", Response);
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        Token.AsObject().Get('counted', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Omitted qtyCounted is not a submitted count, even when the stored value is zero.');
    end;

    /// <summary>The native check accepts physical-count zero deltas rather than applying generic nonzero quantity rules.</summary>
    [Test]
    procedure Scenario_AC04_EqualCount_IsReady()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreatePhysical(Item, Batch, Line);
        AddCount(Request, Line.SystemId, 10);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        Clear(Request);
        InitArgument(TempArgument, Batch, Request);
        Journal.Check(TempArgument, "Item Journal Template Type"::"Phys. Inventory");
        Response := TempArgument.GetResponseJson();
        Response.Get('validationResult', Token);
        Assert.AreEqual('Ready', Token.AsValue().AsText(), 'A real unchanged physical count remains postable.');
    end;

    /// <summary>Native preview captures physical adjustment entries and rolls back all ledgers and journal modifications.</summary>
    [Test]
    procedure Scenario_AC05_Preview_RollsBackPhysicalEntries()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        PhysicalEntries: Record "Phys. Inventory Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeEntries: Integer;
        BeforePhysical: Integer;
        LineId: Guid;
    begin
        CreatePhysical(Item, Batch, Line);
        AddCount(Request, Line.SystemId, 8);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        BeforeEntries := Entries.Count();
        BeforePhysical := PhysicalEntries.Count();
        LineId := Line.SystemId;
        Clear(Request);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Journal.Preview(TempArgument, "Item Journal Template Type"::"Phys. Inventory");
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.PhysInventory.PreviewPost", Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Native physical preview succeeds.');
        Response.Get('preview', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Actual ledger impact is captured.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Item entries unchanged.');
        Assert.AreEqual(BeforePhysical, PhysicalEntries.Count(), 'Physical count ledger unchanged.');
        Assert.IsTrue(Line.GetBySystemId(LineId), 'Original physical line remains.');
        Assert.AreEqual(8, Line."Qty. (Phys. Inventory)", 'Count preserved after preview.');
    end;

    /// <summary>Posting returns ranges of actual item and physical-count entries from the native register.</summary>
    [Test]
    procedure Scenario_AC06_Post_ReturnsBothNativeLedgerRanges()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        PhysicalEntries: Record "Phys. Inventory Ledger Entry";
        Register: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inventory Write Process ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreatePhysical(Item, Batch, Line);
        AddCount(Request, Line.SystemId, 8);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        Clear(Request);
        InitArgument(TempArgument, Batch, Request);
        Process.SetJournalType("Item Journal Template Type"::"Phys. Inventory");
        Commit();
        Assert.IsTrue(Process.Run(TempArgument), GetLastErrorText());
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.PhysInventory.Post", Response);
        Response.Get('itemRegisterNo', Token);
        Register.Get(Token.AsValue().AsInteger());
        Assert.IsTrue(Register."From Phys. Inventory Entry No." > 0, 'Native register contains physical count range.');
        Response.Get('fromPhysInventoryEntryNo', Token);
        Assert.AreEqual(Register."From Phys. Inventory Entry No.", Token.AsValue().AsInteger(), 'Actual physical range returned.');
        PhysicalEntries.SetRange("Entry No.", Register."From Phys. Inventory Entry No.", Register."To Phys. Inventory Entry No.");
        PhysicalEntries.FindFirst();
        Assert.AreEqual(Item."No.", PhysicalEntries."Item No.", 'Owned item count posted.');
        Assert.AreEqual(8, PhysicalEntries."Qty. (Phys. Inventory)", 'Actual count audit.');
        Entries.SetRange("Entry No.", Register."From Entry No.", Register."To Entry No.");
        Entries.FindFirst();
        Assert.AreEqual(-2, Entries.Quantity, 'Actual native shortage adjustment.');
    end;

    [Test]
    procedure PhysicalPost_IgnoresOnlyEmptyLine_EN()
    begin
        VerifyEmptyPhysicalLine(1033, false);
    end;

    [Test]
    procedure PhysicalPost_IgnoresOnlyEmptyLine_IS()
    begin
        VerifyEmptyPhysicalLine(1039, false);
    end;

    [Test]
    procedure PhysicalPost_RejectsNonemptyMissingItem_EN()
    begin
        VerifyEmptyPhysicalLine(1033, true);
    end;

    [Test]
    procedure PhysicalPost_RejectsNonemptyMissingItem_IS()
    begin
        VerifyEmptyPhysicalLine(1039, true);
    end;

    local procedure VerifyEmptyPhysicalLine(LanguageId: Integer; InvalidNonempty: Boolean)
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        BlankLine: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inventory Write Process ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
        OldLanguage: Integer;
    begin
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        CreatePhysical(Item, Batch, Line);
        AddCount(Request, Line.SystemId, 8);
        InitArgument(TempArgument, Batch, Request);
        Journal.RecordCount(TempArgument);
        BlankLine.Init();
        BlankLine."Journal Template Name" := Batch."Journal Template Name";
        BlankLine."Journal Batch Name" := Batch.Name;
        BlankLine."Line No." := Line."Line No." + 10000;
        if InvalidNonempty then
            BlankLine.Quantity := 1;
        BlankLine.Insert(false);
        Clear(Request);
        InitArgument(TempArgument, Batch, Request);
        Process.SetJournalType("Item Journal Template Type"::"Phys. Inventory");
        BeforeCount := Entries.Count();
        Commit();
        if InvalidNonempty then begin
            Assert.IsFalse(Process.Run(TempArgument), 'A malformed nonempty row must still fail native validation.');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'Failure does not leave partial posting.');
        end else begin
            Assert.IsTrue(Process.Run(TempArgument), GetLastErrorText());
            Response := TempArgument.GetResponseJson();
            Response.Get('postedLineCount', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only the meaningful physical inventory row posts.');
            Entries.SetRange("Item No.", Item."No.");
            Entries.SetRange(Quantity, -2);
            Assert.AreEqual(1, Entries.Count(), 'Actual shortage posted despite the empty row.');
        end;
        GlobalLanguage(OldLanguage);
    end;

    /// <summary>Every operation rejects an existing batch of another journal family.</summary>
    [Test]
    procedure Scenario_AC03_WrongTemplate_AllFiveRefuse()
    var
        Batch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateBatch(Batch, "Item Journal Template Type"::Item);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Calculate(TempArgument);
        Assert.ExpectedError('Type');
        Commit();
        asserterror Journal.RecordCount(TempArgument);
        Assert.ExpectedError('Type');
        Commit();
        asserterror Journal.Check(TempArgument, "Item Journal Template Type"::"Phys. Inventory");
        Assert.ExpectedError('Type');
        Commit();
        asserterror Journal.Preview(TempArgument, "Item Journal Template Type"::"Phys. Inventory");
        Assert.ExpectedError('Type');
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::"Phys. Inventory");
        Assert.ExpectedError('Type');
    end;

    /// <summary>An invalid second count rolls back rather than preserving the first requested change.</summary>
    [Test]
    procedure RecordCount_LaterInvalidCount_PreservesFirstLine()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inventory Write Process ori";
        Request: JsonObject;
        Count: JsonObject;
        Counts: JsonArray;
        BeforeQuantity: Decimal;
    begin
        CreatePhysical(Item, Batch, Line);
        BeforeQuantity := Line."Qty. (Phys. Inventory)";
        Count.Add('lineNo', Line."Line No.");
        Count.Add('qtyCounted', 3);
        Counts.Add(Count);
        Clear(Count);
        Count.Add('lineNo', 999999);
        Count.Add('qtyCounted', 5);
        Counts.Add(Count);
        Request.Add('counts', Counts);
        InitArgument(TempArgument, Batch, Request);
        Process.SetOperation('RecordCount');
        Commit();
        Assert.IsFalse(Process.Run(TempArgument), 'Missing second line refuses the whole batch.');
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(BeforeQuantity, Line."Qty. (Phys. Inventory)", 'First line untouched.');
    end;

    /// <summary>The published legacy Record wire format retains native single-line behavior.</summary>
    [Test]
    procedure LegacyRecord_Quantity_UsesNativeCountValidation()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreatePhysical(Item, Batch, Line);
        Request.Add('lineNo', Line."Line No.");
        Request.Add('quantity', 6);
        InitArgument(TempArgument, Batch, Request);
        TempArgument.Type := "Message Type ori"::"Inventory.PhysInventory.Record";
        Journal.RecordCount(TempArgument);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(6, Line."Qty. (Phys. Inventory)", 'Existing Record parameter is preserved.');
        Assert.AreEqual(4, Line.Quantity, 'Native adjustment from existing count wire format.');
    end;

    /// <summary>Null, negative and text counts are refused without changing the calculated line.</summary>
    [Test]
    procedure RecordCount_MalformedQuantity_Refuses()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Count: JsonObject;
        Counts: JsonArray;
    begin
        CreatePhysical(Item, Batch, Line);
        Count.Add('lineNo', Line."Line No.");
        Count.Add('qtyCounted', -1);
        Counts.Add(Count);
        Request.Add('counts', Counts);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.RecordCount(TempArgument);
        Assert.ExpectedError('qtyCounted');
        Clear(Request);
        Clear(Counts);
        Clear(Count);
        Count.Add('lineNo', Line."Line No.");
        Count.Add('qtyCounted', '3');
        Counts.Add(Count);
        Request.Add('counts', Counts);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.RecordCount(TempArgument);
        Assert.ExpectedError('qtyCounted');
    end;

    /// <summary>A real subscriber failure after count modification rolls back the native Validate result.</summary>
    [Test]
    procedure RecordCount_AfterModifyError_RollsBackNativeWrite()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inventory Write Process ori";
        Observer: Codeunit "Inv Journal Write Observer";
        Request: JsonObject;
        BeforeQuantity: Decimal;
    begin
        CreatePhysical(Item, Batch, Line);
        BeforeQuantity := Line."Qty. (Phys. Inventory)";
        AddCount(Request, Line.SystemId, 3);
        InitArgument(TempArgument, Batch, Request);
        Observer.SetCountItem(Item."No.");
        BindSubscription(Observer);
        Process.SetOperation('RecordCount');
        Commit();
        Assert.IsFalse(Process.Run(TempArgument), 'Error after actual count modification aborts the process.');
        Assert.ExpectedError('Owned native journal insert failure');
        UnbindSubscription(Observer);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(BeforeQuantity, Line."Qty. (Phys. Inventory)", 'Native count write rolled back.');
        Assert.AreEqual(0, Line.Quantity, 'Native delta write rolled back.');
    end;

    /// <summary>The public calculation example runs natively after substituting owned identifiers and accounting date.</summary>
    [Test]
    procedure Scenario_AC01_HelpCalculateExample_CreatesOnlyOwnedLines()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        BeforeEntries: Integer;
    begin
        // Issue #6 AC01 / #27 | Time: WorkDate replaces illustrative date | Risk: Help example omits input.
        CreateStock(Item);
        CreateBatch(Batch, "Item Journal Template Type"::"Phys. Inventory");
        Request := HelpExampleData("Message Type ori"::"Inventory.PhysInventory.Calculate", 0);
        Request.Replace('itemNo', Item."No.");
        Request.Replace('postingDate', Format(WorkDate(), 0, 9));
        InitArgument(TempArgument, Batch, Request);
        BeforeEntries := Entries.Count();
        Journal.Calculate(TempArgument);
        FilterBatch(Batch, Line);
        Assert.AreEqual(1, Line.Count(), 'Published calculation example creates one selected native line.');
        Line.FindFirst();
        Assert.AreEqual(Item."No.", Line."Item No.", 'Only the owned item is selected.');
        Assert.AreEqual(10, Line."Qty. (Calculated)", 'Native report reads actual owned stock.');
        Assert.AreEqual('COUNT-001', Line."Document No.", 'Example document option reaches native calculation.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Example does not post ledger entries.');
    end;

    /// <summary>The public batched count example writes explicit zero through native validation.</summary>
    [Test]
    procedure Scenario_AC02_HelpRecordCountExample_WritesZeroWithoutPosting()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Count: JsonObject;
        Counts: JsonArray;
        Token: JsonToken;
        BeforeEntries: Integer;
    begin
        // Issue #6 AC02 / #27 | Time: native owned stock uses WorkDate | Risk: example drops explicit zero.
        CreatePhysical(Item, Batch, Line);
        Request := HelpExampleData("Message Type ori"::"Inventory.PhysInventory.RecordCount", 0);
        Request.Get('counts', Token);
        Counts := Token.AsArray();
        Counts.Get(0, Token);
        Count := Token.AsObject();
        Count.Replace('lineNo', Line."Line No.");
        Counts.Set(0, Count);
        Request.Replace('counts', Counts);
        InitArgument(TempArgument, Batch, Request);
        TempArgument.Type := "Message Type ori"::"Inventory.PhysInventory.RecordCount";
        BeforeEntries := Entries.Count();
        Journal.RecordCount(TempArgument);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(0, Line."Qty. (Phys. Inventory)", 'Explicit example zero is written.');
        Assert.AreEqual(10, Line.Quantity, 'Native validation calculates shortage.');
        Assert.AreEqual(Line."Entry Type"::"Negative Adjmt.", Line."Entry Type", 'Native shortage has negative adjustment type.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Count example does not post ledger entries.');
    end;

    /// <summary>The legacy example remains distinct from the canonical type and retains zero semantics.</summary>
    [Test]
    procedure Scenario_AC02_HelpLegacyRecordExample_RefusesCanonicalType()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        BeforeEntries: Integer;
        BeforeCount: Decimal;
    begin
        // Issue #6 AC02 / #27 | Time: WorkDate | Risk: union Help silently broadens canonical input.
        CreatePhysical(Item, Batch, Line);
        Request := HelpExampleData("Message Type ori"::"Inventory.PhysInventory.Record", 1);
        Request.Replace('lineNo', Line."Line No.");
        InitArgument(TempArgument, Batch, Request);
        TempArgument.Type := "Message Type ori"::"Inventory.PhysInventory.RecordCount";
        BeforeCount := Line."Qty. (Phys. Inventory)";
        BeforeEntries := Entries.Count();
        Commit();
        asserterror Journal.RecordCount(TempArgument);
        Assert.ExpectedError('Unsupported journal parameter');
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(BeforeCount, Line."Qty. (Phys. Inventory)", 'Wrong message type does not modify the count.');
        TempArgument.Type := "Message Type ori"::"Inventory.PhysInventory.Record";
        Journal.RecordCount(TempArgument);
        Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.AreEqual(0, Line."Qty. (Phys. Inventory)", 'Legacy example zero is retained.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Neither refusal nor count posts ledger entries.');
    end;

    local procedure HelpExampleData(MessageType: Enum "Message Type ori"; Index: Integer) Data: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Registered public Help exists.');
        Contract.Get('examples', Token);
        Token.AsArray().Get(Index, Token);
        Token.AsObject().Get('request', Token);
        Token.AsObject().Get('data', Token);
        Data := Token.AsObject();
    end;

    local procedure CreatePhysical(var Item: Record Item; var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateStock(Item);
        CreateBatch(Batch, "Item Journal Template Type"::"Phys. Inventory");
        CalculationRequest(Request, Item."No.");
        InitArgument(TempArgument, Batch, Request);
        Journal.Calculate(TempArgument);
        FilterBatch(Batch, Line);
        Assert.IsTrue(Line.FindFirst(), 'Native report790 creates the count line.');
    end;

    local procedure FilterBatch(Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    begin
        Line.Reset();
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
    end;

    local procedure CalculationRequest(var Request: JsonObject; ItemNo: Code[20])
    begin
        Request.Add('itemNo', ItemNo);
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Request.Add('documentNo', 'OWNED-PHYS');
    end;

    local procedure AddCount(var Request: JsonObject; Id: Guid; Quantity: Decimal)
    var
        Count: JsonObject;
        Counts: JsonArray;
    begin
        Count.Add('systemId', Id);
        Count.Add('qtyCounted', Quantity);
        Counts.Add(Count);
        Request.Add('counts', Counts);
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
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
    end;

    local procedure VerifyWrongReclassTemplate(JournalType: Enum "Item Journal Template Type"; LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Helper: Codeunit "Assembly Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
        PreviousLanguage: Integer;
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Reclassification := true;
        Setup.Modify(true);
        CreateBatch(Batch, JournalType);
        Line.Init();
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        Line."Line No." := 10000;
        Line.Description := 'Owned template guard fixture';
        Line.Insert(false);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        BeforeCount := Entries.Count();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(Response.Get('code', Token), 'Refusal must be coded before native posting runs.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Wrong journal type.');
        Response.Get('parameter', Token);
        Assert.AreEqual('journalTemplateName', Token.AsValue().AsText(), 'Template parameter.');
        Response.Get('received', Token);
        Assert.AreEqual(Batch."Journal Template Name", Token.AsValue().AsText(), 'Actual template name.');
        Response.Get('error', Token);
        if LanguageId = 1039 then
            Assert.AreEqual('Bókarsniðmátið ' + Batch."Journal Template Name" + ' er ekki af gerðinni Transfer.', Token.AsValue().AsText(), 'Icelandic refusal.')
        else
            Assert.AreEqual('Journal template ' + Batch."Journal Template Name" + ' is not a Transfer template.', Token.AsValue().AsText(), 'English refusal.');
        Assert.IsTrue(Response.Get('nextStep', Token), 'Recovery instruction required.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Recovery instruction nonempty.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Wrong template creates no item ledger entries.');
        Assert.IsTrue(Line.Get(Batch."Journal Template Name", Batch.Name, 10000), 'Wrong template must not consume the line.');
        Assert.AreEqual('Owned template guard fixture', Line.Description, 'Line unchanged.');
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch"; JournalType: Enum "Item Journal Template Type")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalType);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
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
