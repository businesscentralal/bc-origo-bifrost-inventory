namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Self-created native stock verifies dedicated journal selection, checks, preview and posting isolation.</summary>
codeunit 96960 "Inventory Native Journal Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ContractLibrary: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Journal: Codeunit "Inventory Native Journal ori";

    /// <summary>Native validation detects a blocked item rather than reporting only the line count.</summary>
    [Test]
    procedure Check_BlockedItem_ReturnsNotReadyWithoutWrites()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
    begin
        CreateTransfer(Item, Batch, Line);
        Item.Get(Item."No.");
        Item.Validate(Blocked, true);
        Item.Modify(true);
        BeforeCount := Entries.Count();
        InitArgument(TempArgument, Batch, Request);
        Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        Response.Get('validationResult', Token);
        Assert.AreEqual('NotReady', Token.AsValue().AsText(), 'Native blocked-item check is executed.');
        Response.Get('errorCount', Token);
        Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'Native error is returned.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Check writes no ledger rows.');
        Assert.IsTrue(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Check preserves the line.');
    end;

    /// <summary>A correct transfer is ready and a future date produces a distinct warning verdict.</summary>
    [Test]
    procedure Check_ValidAndFutureDate_ReturnsReadiness()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateTransfer(Item, Batch, Line);
        InitArgument(TempArgument, Batch, Request);
        Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Reclassification.Check", Response);
        Response.Get('validationResult', Token);
        Assert.AreEqual('Ready', Token.AsValue().AsText(), 'Valid native Transfer journal.');
        Line.Validate("Posting Date", WorkDate() + 1);
        Line.Modify(true);
        InitArgument(TempArgument, Batch, Request);
        Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        Response.Get('validationResult', Token);
        Assert.AreEqual('ReadyWithWarnings', Token.AsValue().AsText(), 'Future date remains visible.');
    end;

    /// <summary>An empty batch is not ready, not a zero-line success.</summary>
    [Test]
    procedure Check_EmptyBatch_ReturnsNotReady()
    var
        Batch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateBatch(Batch, "Item Journal Template Type"::Transfer);
        InitArgument(TempArgument, Batch, Request);
        Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        Response.Get('validationResult', Token);
        Assert.AreEqual('NotReady', Token.AsValue().AsText(), 'No entries to check.');
        Response.Get('errorCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Explicit empty-batch error.');
    end;

    /// <summary>Posting a selected line produces native transfer entries and preserves the unselected line exactly.</summary>
    [Test]
    procedure Post_Subset_PreservesOtherLineAndReturnsNativeRegister()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Register: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inv Native Journal Process ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        SelectedId: Guid;
        OtherId: Guid;
        Destination: Code[10];
    begin
        CreateTransfer(Item, Batch, Line);
        AddTransfer(Batch, Item, Line."New Location Code", OtherLine);
        OtherId := OtherLine.SystemId;
        SelectedId := Line.SystemId;
        Destination := Line."New Location Code";
        SelectOne(Request, SelectedId);
        InitArgument(TempArgument, Batch, Request);
        Process.SetJournalType("Item Journal Template Type"::Transfer);
        Commit();
        Assert.IsTrue(Process.Run(TempArgument), GetLastErrorText());
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Reclassification.Post", Response);
        Response.Get('postedLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Exactly the selected line was posted.');
        Response.Get('itemRegisterNo', Token);
        Assert.IsTrue(Register.Get(Token.AsValue().AsInteger()), 'Response identifies an actual register.');
        Entries.SetRange("Entry No.", Register."From Entry No.", Register."To Entry No.");
        Entries.SetRange("Item No.", Item."No.");
        Assert.AreEqual(2, Entries.Count(), 'Native transfer has source and destination entries.');
        Entries.SetRange("Location Code", Destination);
        Entries.FindFirst();
        Assert.AreEqual(2, Entries.Quantity, 'Only selected quantity arrives.');
        Assert.IsFalse(Line.GetBySystemId(SelectedId), 'Posted line removed by native posting.');
        Assert.IsTrue(OtherLine.GetBySystemId(OtherId), 'Unselected SystemId preserved.');
        Assert.AreEqual(2, OtherLine.Quantity, 'Unselected quantity unchanged.');
        Response.Get('result', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Per-line result matches selected set.');
    end;

    /// <summary>Preview runs actual posting and leaves both selected and unselected journal rows and ledgers intact.</summary>
    [Test]
    procedure Preview_Subset_ReturnsLedgerImpactAndRollsBack()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Values: Record "Value Entry";
        Registers: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryCount: Integer;
        ValueCount: Integer;
        RegisterCount: Integer;
        SelectedId: Guid;
        OtherId: Guid;
    begin
        CreateTransfer(Item, Batch, Line);
        AddTransfer(Batch, Item, Line."New Location Code", OtherLine);
        SelectedId := Line.SystemId;
        OtherId := OtherLine.SystemId;
        EntryCount := Entries.Count();
        ValueCount := Values.Count();
        RegisterCount := Registers.Count();
        SelectOne(Request, SelectedId);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Journal.Preview(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Reclassification.PreviewPost", Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Native preview succeeds.');
        Response.Get('preview', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Captured native ledger entries, not echoed lines.');
        Response.Get('linesToPost', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Preview respects subset.');
        Assert.AreEqual(EntryCount, Entries.Count(), 'Item entries rolled back.');
        Assert.AreEqual(ValueCount, Values.Count(), 'Value entries rolled back.');
        Assert.AreEqual(RegisterCount, Registers.Count(), 'Register rolled back.');
        Assert.IsTrue(Line.GetBySystemId(SelectedId), 'Selected line preserved.');
        Assert.IsTrue(OtherLine.GetBySystemId(OtherId), 'Unselected line preserved.');
    end;

    /// <summary>Wrong template families are refused by check, preview and post before any native write.</summary>
    [Test]
    procedure WrongTemplate_AllOperationsRefuse()
    var
        Batch: Record "Item Journal Batch";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateBatch(Batch, "Item Journal Template Type"::Item);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('Type');
        Commit();
        asserterror Journal.Preview(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('Type');
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('Type');
    end;

    /// <summary>A non-Transfer line in a Transfer template is never silently filtered away.</summary>
    [Test]
    procedure WrongEntryType_PostRefusesWholeSelection()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateTransfer(Item, Batch, Line);
        Line."Entry Type" := Line."Entry Type"::"Positive Adjmt.";
        Line.Modify();
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('Entry Type');
        Assert.IsTrue(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Invalid line retained for correction.');
    end;

    /// <summary>Foreign and duplicate line IDs cannot broaden the selected batch.</summary>
    [Test]
    procedure Subset_ForeignAndDuplicateIds_AreRefused()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Batch: Record "Item Journal Batch";
        OtherBatch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Ids: JsonArray;
    begin
        CreateTransfer(Item, Batch, Line);
        CreateTransfer(OtherItem, OtherBatch, OtherLine);
        SelectOne(Request, OtherLine.SystemId);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('lineSystemIds');
        Clear(Request);
        Ids.Add(Line.SystemId);
        Ids.Add(Line.SystemId);
        Request.Add('lineSystemIds', Ids);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Preview(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('lineSystemIds');
        Assert.IsTrue(OtherLine.Get(OtherLine."Journal Template Name", OtherLine."Journal Batch Name", OtherLine."Line No."), 'Foreign line never touched.');
    end;

    /// <summary>Malformed or empty subset input never defaults to all lines.</summary>
    [Test]
    procedure Subset_InvalidAndEmpty_RefuseBeforePosting()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateTransfer(Item, Batch, Line);
        Request.ReadFrom('{"lineSystemIds":[]}');
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('lineSystemIds');
        Request.ReadFrom('{"lineSystemIds":[null]}');
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('lineSystemIds');
        Request.ReadFrom('{"lineSystemIds":"not-an-array"}');
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Post(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('lineSystemIds');
    end;

    /// <summary>Conflicting batch identifiers cannot redirect the request to another batch.</summary>
    [Test]
    procedure Identifiers_ConflictAndOversize_Refuse()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateTransfer(Item, Batch, Line);
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', 'WRONG');
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('Identify');
        Request.ReadFrom('{"templateName":"ELEVENCHARS","batchName":"X"}');
        InitArgument(TempArgument, Batch, Request);
        Commit();
        asserterror Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Assert.ExpectedError('at most 10');
    end;

    /// <summary>A subscriber fails after the real native Item Ledger Entry insertion; the isolated process rolls back all writes.</summary>
    [Test]
    procedure Post_AfterLedgerInsertError_RollsBackAllWrites()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Values: Record "Value Entry";
        Registers: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inv Native Journal Process ori";
        Observer: Codeunit "Inv Journal Write Observer";
        Request: JsonObject;
        EntryCount: Integer;
        ValueCount: Integer;
        RegisterCount: Integer;
        LineId: Guid;
    begin
        CreateTransfer(Item, Batch, Line);
        LineId := Line.SystemId;
        EntryCount := Entries.Count();
        ValueCount := Values.Count();
        RegisterCount := Registers.Count();
        InitArgument(TempArgument, Batch, Request);
        Observer.SetItem(Item."No.");
        BindSubscription(Observer);
        Process.SetJournalType("Item Journal Template Type"::Transfer);
        Commit();
        Assert.IsFalse(Process.Run(TempArgument), 'Real post-insert failure aborts the process.');
        Assert.ExpectedError('Owned native journal insert failure');
        UnbindSubscription(Observer);
        Assert.AreEqual(EntryCount, Entries.Count(), 'Native item insertion rolled back.');
        Assert.AreEqual(ValueCount, Values.Count(), 'Native value insertion rolled back.');
        Assert.AreEqual(RegisterCount, Registers.Count(), 'Native register rolled back.');
        Assert.IsTrue(Line.GetBySystemId(LineId), 'Journal line restored.');
    end;

    /// <summary>Lot reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_LotReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(true, false, false);
    end;

    /// <summary>Serial reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_SerialReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(false, true, false);
    end;

    /// <summary>Package reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_PackageReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(false, false, true);
    end;

    /// <summary>LotSerial reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_LotSerialReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(true, true, false);
    end;

    /// <summary>LotPackage reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_LotPackageReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(true, false, true);
    end;

    /// <summary>SerialPackage reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_SerialPackageReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(false, true, true);
    end;

    /// <summary>LotSerialPackage reclassification previews without writes, then posts native tracking and dimension changes for the selected line.</summary>
    [Test]
    procedure Scenario_AC34_LotSerialPackageReclassPreservesSelection()
    begin
        VerifyTrackedReclassification(true, true, true);
    end;

    /// <summary>Two lot assignments remain distinct in preview/post results and native ledger entries.</summary>
    [Test]
    procedure Scenario_AC34_SplitLotsReturnEveryAssignment()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        ReceiptBatch: Record "Item Journal Batch";
        Receipt: Record "Item Journal Line";
        Entry: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inv Native Journal Process ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
        ItemNo: Code[20];
        Destination: Code[10];
    begin
        CreateTrackedReclassification(Item, Batch, Line, true, false, false);
        ItemNo := Item."No.";
        Destination := Line."New Location Code";
        CreateBatch(ReceiptBatch, "Item Journal Template Type"::Item);
        LibraryInventory.CreateItemJournalLine(Receipt, ReceiptBatch."Journal Template Name", ReceiptBatch.Name, Receipt."Entry Type"::"Positive Adjmt.", ItemNo, 1);
        Receipt.Validate("Posting Date", WorkDate());
        Receipt.Validate("Location Code", Line."Location Code");
        Receipt.Validate("Variant Code", Line."Variant Code");
        Receipt.Validate("Unit of Measure Code", Line."Unit of Measure Code");
        Receipt.Validate("Unit Amount", 12);
        Receipt.Modify(true);
        SetAdditionalLotTracking(Receipt, 'X-SECOND-LOT', '', 3);
        LibraryInventory.PostItemJournalLine(ReceiptBatch."Journal Template Name", ReceiptBatch.Name);
        Line.Validate(Quantity, 2);
        Line.Modify(true);
        SetAdditionalLotTracking(Line, 'X-SECOND-LOT', 'X-SECOND-NEW', 3);
        BeforeCount := Entry.Count();
        SelectOne(Request, Line.SystemId);
        InitArgument(TempArgument, Batch, Request);
        Commit();
        Journal.Preview(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Split tracking preview succeeds.');
        AssertSplitTracking(Response);
        Assert.AreEqual(BeforeCount, Entry.Count(), 'Split preview writes no ledger rows.');
        InitArgument(TempArgument, Batch, Request);
        Process.SetJournalType("Item Journal Template Type"::Transfer);
        Commit();
        Assert.IsTrue(Process.Run(TempArgument), GetLastErrorText());
        Response := TempArgument.GetResponseJson();
        AssertSplitTracking(Response);
        Entry.SetRange("Item No.", ItemNo);
        Entry.SetRange("Location Code", Destination);
        Assert.AreEqual(2, Entry.Count(), 'Both native destination lots are posted.');
        Entry.SetRange("Lot No.", 'X-NEW-LOT');
        Entry.FindFirst();
        Assert.AreEqual(3, Entry.Quantity, 'First lot base quantity.');
        Entry.SetRange("Lot No.", 'X-SECOND-NEW');
        Entry.FindFirst();
        Assert.AreEqual(3, Entry.Quantity, 'Second lot base quantity.');
        Entry.SetRange("Lot No.");
        Entry.SetRange("Location Code");
        Entry.CalcSums(Quantity);
        Assert.AreEqual(6, Entry.Quantity, 'Split reclassification conserves total stock.');
    end;

    local procedure SetAdditionalLotTracking(Line: Record "Item Journal Line"; LotNo: Code[50]; NewLotNo: Code[50]; QuantityBase: Decimal)
    var
        Source: Record "Tracking Specification";
        TempTracking: Record "Tracking Specification" temporary;
        Reserve: Codeunit "Item Jnl. Line-Reserve";
        TrackingLines: Page "Item Tracking Lines";
    begin
        Reserve.InitFromItemJnlLine(Source, Line);
        TempTracking := Source;
        TempTracking."Entry No." := 1;
        TempTracking."Quantity (Base)" := QuantityBase;
        TempTracking."Lot No." := LotNo;
        TempTracking."New Lot No." := NewLotNo;
        TempTracking.Insert();
        TrackingLines.SetBlockCommit(true);
        if Line."Entry Type" = Line."Entry Type"::Transfer then
            TrackingLines.SetRunMode("Item Tracking Run Mode"::Reclass);
        TrackingLines.RegisterItemTrackingLines(Source, WorkDate(), TempTracking);
    end;

    local procedure AssertSplitTracking(Response: JsonObject)
    var
        Token: JsonToken;
        Assignment: JsonToken;
        ResultLine: JsonObject;
        TrackingEntry: JsonObject;
        Assignments: JsonArray;
        SeenLots: List of [Text];
        TotalBase: Decimal;
        LotNo: Text;
    begin
        Response.Get('result', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Split tracking remains one selected journal line.');
        Token.AsArray().Get(0, Token);
        ResultLine := Token.AsObject();
        ResultLine.Get('tracking', Token);
        Assignments := Token.AsArray();
        Assert.AreEqual(2, Assignments.Count(), 'Every native assignment is returned.');
        foreach Assignment in Assignments do begin
            TrackingEntry := Assignment.AsObject();
            TrackingEntry.Get('lotNo', Token);
            LotNo := Token.AsValue().AsText();
            Assert.IsFalse(SeenLots.Contains(LotNo), 'No assignment is duplicated.');
            SeenLots.Add(LotNo);
            TrackingEntry.Get('newLotNo', Token);
            case LotNo of
                'X-OLD-LOT':
                    Assert.AreEqual('X-NEW-LOT', Token.AsValue().AsText(), 'First destination lot.');
                'X-SECOND-LOT':
                    Assert.AreEqual('X-SECOND-NEW', Token.AsValue().AsText(), 'Second destination lot.');
                else
                    Assert.Fail('Unexpected source assignment.');
            end;
            TrackingEntry.Get('quantityBase', Token);
            Assert.AreEqual(3, Token.AsValue().AsDecimal(), 'Each assignment has its exact base quantity.');
            TotalBase += Token.AsValue().AsDecimal();
        end;
        Assert.AreEqual(6, TotalBase, 'No assignment is lost.');
        ResultLine.Get('lotNo', Token);
        Assert.AreEqual('', Token.AsValue().AsText(), 'A split line must not pretend it has one source lot.');
    end;

    local procedure VerifyTrackedReclassification(UseLot: Boolean; UseSerial: Boolean; UsePackage: Boolean)
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        Entry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Reservation: Record "Reservation Entry";
        Register: Record "Item Register";
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inv Native Journal Process ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        OriginalId: Guid;
        OtherId: Guid;
        EntryCount: Integer;
        ValueCount: Integer;
        ReservationCount: Integer;
        RegisterCount: Integer;
        OriginalDimensions: Integer;
        NewDimensions: Integer;
        SourceLocation: Code[10];
        Destination: Code[10];
        VariantCode: Code[10];
        BaseQuantity: Decimal;
    begin
        // Native integration below the licensed dispatcher; no licensed MCP or concurrency claim.
        CreateTrackedReclassification(Item, Batch, Line, UseLot, UseSerial, UsePackage);
        OriginalId := Line.SystemId;
        OriginalDimensions := Line."Dimension Set ID";
        NewDimensions := Line."New Dimension Set ID";
        SourceLocation := Line."Location Code";
        Destination := Line."New Location Code";
        VariantCode := Line."Variant Code";
        BaseQuantity := Line."Quantity (Base)";
        // Deliberately incomplete unselected tracking must neither be posted nor invalidate the selected line.
        AddTransfer(Batch, Item, Destination, OtherLine);
        OtherId := OtherLine.SystemId;
        EntryCount := Entry.Count();
        ValueCount := ValueEntry.Count();
        ReservationCount := Reservation.Count();
        RegisterCount := Register.Count();
        SelectOne(Request, OriginalId);
        InitArgument(TempArgument, Batch, Request);
        Journal.Check(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        Response.Get('validationResult', Token);
        Assert.AreEqual('Ready', Token.AsValue().AsText(), 'Selected tracked source passes native line validation.');
        Commit();
        Journal.Preview(TempArgument, "Item Journal Template Type"::Transfer);
        Response := TempArgument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Tracked subset previews successfully.');
        AssertResponseTracking(Response, UseLot, UseSerial, UsePackage, BaseQuantity);
        Response.Get('preview', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Preview captures actual native ledger impact.');
        Assert.AreEqual(EntryCount, Entry.Count(), 'Preview preserves all item entries.');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'Preview preserves all value entries.');
        Assert.AreEqual(ReservationCount, Reservation.Count(), 'Preview preserves pending tracking rows.');
        Assert.AreEqual(RegisterCount, Register.Count(), 'Preview preserves registers.');
        Assert.IsTrue(Line.GetBySystemId(OriginalId), 'Preview preserves the selected source.');
        Assert.IsTrue(OtherLine.GetBySystemId(OtherId), 'Preview preserves the unselected source.');
        Assert.AreEqual(OriginalDimensions, Line."Dimension Set ID", 'Preview preserves source dimensions.');
        Assert.AreEqual(NewDimensions, Line."New Dimension Set ID", 'Preview preserves destination dimensions.');
        InitArgument(TempArgument, Batch, Request);
        Process.SetJournalType("Item Journal Template Type"::Transfer);
        Commit();
        Assert.IsTrue(Process.Run(TempArgument), GetLastErrorText());
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Reclassification.Post", Response);
        Response.Get('postedLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only selected tracked line posts.');
        AssertResponseTracking(Response, UseLot, UseSerial, UsePackage, BaseQuantity);
        Response.Get('itemRegisterNo', Token);
        Register.Get(Token.AsValue().AsInteger());
        Entry.SetRange("Entry No.", Register."From Entry No.", Register."To Entry No.");
        Entry.SetRange("Item No.", Item."No.");
        Assert.AreEqual(2, Entry.Count(), 'Native transfer creates exactly two item entries.');
        Entry.SetRange(Positive, false);
        Entry.FindFirst();
        Assert.AreEqual(SourceLocation, Entry."Location Code", 'Outbound source location.');
        Assert.AreEqual(-BaseQuantity, Entry.Quantity, 'Outbound base quantity.');
        Assert.AreEqual(OriginalDimensions, Entry."Dimension Set ID", 'Outbound source dimensions.');
        AssertTrackingIdentity(Entry, UseLot, UseSerial, UsePackage, false);
        Entry.SetRange(Positive, true);
        Entry.FindFirst();
        Assert.AreEqual(Destination, Entry."Location Code", 'Inbound destination location.');
        Assert.AreEqual(BaseQuantity, Entry.Quantity, 'Inbound exact UOM base quantity.');
        Assert.AreEqual(NewDimensions, Entry."Dimension Set ID", 'Inbound changed dimensions.');
        Assert.AreEqual(VariantCode, Entry."Variant Code", 'Variant survives reclassification.');
        AssertTrackingIdentity(Entry, UseLot, UseSerial, UsePackage, true);
        Entry.SetRange("Entry No.");
        Entry.SetRange(Positive);
        Entry.CalcSums(Quantity);
        Assert.AreEqual(BaseQuantity, Entry.Quantity, 'Reclassification conserves total inventory.');
        Assert.IsFalse(Line.GetBySystemId(OriginalId), 'Native posting removes selected line.');
        Assert.IsTrue(OtherLine.GetBySystemId(OtherId), 'Unselected line identity survives posting.');
        Assert.AreEqual(2, OtherLine.Quantity, 'Unselected line quantity is unchanged.');
        Reservation.SetRange("Source Type", Database::"Item Journal Line");
        Reservation.SetRange("Source ID", Batch."Journal Template Name");
        Reservation.SetRange("Source Batch Name", Batch.Name);
        Assert.IsTrue(Reservation.IsEmpty(), 'Native posting consumes selected pending tracking.');
    end;

    local procedure AssertResponseTracking(Response: JsonObject; UseLot: Boolean; UseSerial: Boolean; UsePackage: Boolean; BaseQuantity: Decimal)
    var
        Entry: Record "Item Ledger Entry";
        Token: JsonToken;
        ResultLine: JsonObject;
        TrackingEntry: JsonObject;
    begin
        Response.Get('result', Token);
        Token.AsArray().Get(0, Token);
        ResultLine := Token.AsObject();
        ResultLine.Get('lotNo', Token);
        Entry."Lot No." := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Entry."Lot No."));
        ResultLine.Get('serialNo', Token);
        Entry."Serial No." := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Entry."Serial No."));
        ResultLine.Get('packageNo', Token);
        Entry."Package No." := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Entry."Package No."));
        AssertTrackingIdentity(Entry, UseLot, UseSerial, UsePackage, false);
        ResultLine.Get('newLotNo', Token);
        Entry."Lot No." := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Entry."Lot No."));
        ResultLine.Get('newSerialNo', Token);
        Entry."Serial No." := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Entry."Serial No."));
        ResultLine.Get('newPackageNo', Token);
        Entry."Package No." := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Entry."Package No."));
        AssertTrackingIdentity(Entry, UseLot, UseSerial, UsePackage, true);
        ResultLine.Get('tracking', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Response includes the selected native assignment.');
        Token.AsArray().Get(0, Token);
        TrackingEntry := Token.AsObject();
        TrackingEntry.Get('quantityBase', Token);
        Assert.AreEqual(BaseQuantity, Token.AsValue().AsDecimal(), 'Response tracking quantity uses base units.');
    end;

    local procedure CreateTrackedReclassification(var Item: Record Item; var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line"; UseLot: Boolean; UseSerial: Boolean; UsePackage: Boolean)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        TrackingCode: Record "Item Tracking Code";
        Variant: Record "Item Variant";
        ItemUOM: Record "Item Unit of Measure";
        SourceLocation: Record Location;
        Destination: Record Location;
        DimensionValue: Record "Dimension Value";
        NewDimensionValue: Record "Dimension Value";
        ReceiptBatch: Record "Item Journal Batch";
        Receipt: Record "Item Journal Line";
        LibraryDimension: Codeunit "Library - Dimension";
        DimensionSetId: Integer;
        NewDimensionSetId: Integer;
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
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode.Validate("Lot Specific Tracking", UseLot);
        TrackingCode.Validate("SN Specific Tracking", UseSerial);
        TrackingCode.Validate("Package Specific Tracking", UsePackage);
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        LibraryInventory.CreateItemVariant(Variant, Item."No.");
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(SourceLocation);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Destination);
        LibraryDimension.CreateDimWithDimValue(DimensionValue);
        LibraryDimension.CreateDimensionValue(NewDimensionValue, DimensionValue."Dimension Code");
        DimensionSetId := LibraryDimension.CreateDimSet(0, DimensionValue."Dimension Code", DimensionValue.Code);
        NewDimensionSetId := LibraryDimension.CreateDimSet(0, NewDimensionValue."Dimension Code", NewDimensionValue.Code);
        if not UseSerial then
            LibraryInventory.CreateItemUnitOfMeasureCode(ItemUOM, Item."No.", 3);
        CreateBatch(ReceiptBatch, "Item Journal Template Type"::Item);
        LibraryInventory.CreateItemJournalLine(Receipt, ReceiptBatch."Journal Template Name", ReceiptBatch.Name, Receipt."Entry Type"::"Positive Adjmt.", Item."No.", 1);
        Receipt.Validate("Posting Date", WorkDate());
        Receipt.Validate("Location Code", SourceLocation.Code);
        Receipt.Validate("Variant Code", Variant.Code);
        if not UseSerial then
            Receipt.Validate("Unit of Measure Code", ItemUOM.Code);
        Receipt.Validate("Dimension Set ID", DimensionSetId);
        Receipt.Validate("Unit Amount", 12);
        Receipt.Modify(true);
        SetNativeJournalTracking(Receipt, UseLot, UseSerial, UsePackage, false);
        LibraryInventory.PostItemJournalLine(ReceiptBatch."Journal Template Name", ReceiptBatch.Name);
        CreateBatch(Batch, "Item Journal Template Type"::Transfer);
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 1);
        Line.Validate("Posting Date", WorkDate());
        Line.Validate("Location Code", SourceLocation.Code);
        Line.Validate("New Location Code", Destination.Code);
        Line.Validate("Variant Code", Variant.Code);
        if not UseSerial then
            Line.Validate("Unit of Measure Code", ItemUOM.Code);
        Line.Validate("Dimension Set ID", DimensionSetId);
        Line.Validate("New Dimension Set ID", NewDimensionSetId);
        Line.Modify(true);
        SetNativeJournalTracking(Line, UseLot, UseSerial, UsePackage, true);
    end;

    local procedure SetNativeJournalTracking(Line: Record "Item Journal Line"; UseLot: Boolean; UseSerial: Boolean; UsePackage: Boolean; Reclassify: Boolean)
    var
        Source: Record "Tracking Specification";
        TempTracking: Record "Tracking Specification" temporary;
        Reserve: Codeunit "Item Jnl. Line-Reserve";
        TrackingLines: Page "Item Tracking Lines";
    begin
        Reserve.InitFromItemJnlLine(Source, Line);
        TempTracking := Source;
        TempTracking."Entry No." := 1;
        TempTracking."Quantity (Base)" := Line."Quantity (Base)";
        if UseLot then begin
            TempTracking."Lot No." := 'X-OLD-LOT';
            TempTracking."New Lot No." := 'X-NEW-LOT';
        end;
        if UseSerial then begin
            TempTracking."Serial No." := 'X-OLD-SERIAL';
            TempTracking."New Serial No." := 'X-NEW-SERIAL';
        end;
        if UsePackage then begin
            TempTracking."Package No." := 'X-OLD-PACKAGE';
            TempTracking."New Package No." := 'X-NEW-PACKAGE';
        end;
        TempTracking.Insert();
        TrackingLines.SetBlockCommit(true);
        if Reclassify then
            TrackingLines.SetRunMode("Item Tracking Run Mode"::Reclass);
        TrackingLines.RegisterItemTrackingLines(Source, WorkDate(), TempTracking);
    end;

    local procedure AssertTrackingIdentity(Entry: Record "Item Ledger Entry"; UseLot: Boolean; UseSerial: Boolean; UsePackage: Boolean; NewTracking: Boolean)
    var
        Prefix: Text;
    begin
        Prefix := 'X-OLD-';
        if NewTracking then
            Prefix := 'X-NEW-';
        if UseLot then
            Assert.AreEqual(Prefix + 'LOT', Entry."Lot No.", 'Native lot identity.')
        else
            Assert.AreEqual('', Entry."Lot No.", 'No lot was introduced.');
        if UseSerial then
            Assert.AreEqual(Prefix + 'SERIAL', Entry."Serial No.", 'Native serial identity.')
        else
            Assert.AreEqual('', Entry."Serial No.", 'No serial was introduced.');
        if UsePackage then
            Assert.AreEqual(Prefix + 'PACKAGE', Entry."Package No.", 'Native package identity.')
        else
            Assert.AreEqual('', Entry."Package No.", 'No package was introduced.');
    end;

    local procedure CreateTransfer(var Item: Record Item; var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    var
        Location: Record Location;
    begin
        CreateStock(Item);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        CreateBatch(Batch, "Item Journal Template Type"::Transfer);
        AddTransfer(Batch, Item, Location.Code, Line);
    end;

    local procedure AddTransfer(Batch: Record "Item Journal Batch"; Item: Record Item; Destination: Code[10]; var Line: Record "Item Journal Line")
    begin
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 2);
        Line.Validate("Posting Date", WorkDate());
        Line.Validate("New Location Code", Destination);
        Line.Modify(true);
    end;

    local procedure SelectOne(var Request: JsonObject; Id: Guid)
    var
        Ids: JsonArray;
    begin
        Ids.Add(Id);
        Request.Add('lineSystemIds', Ids);
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
