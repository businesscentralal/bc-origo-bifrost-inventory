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

/// <summary>Self-created native stock verifies dedicated journal selection, checks, preview and posting isolation.</summary>
codeunit 96960 "Inventory Native Journal Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
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
