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
codeunit 96962 "Inventory Physical Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ContractLibrary: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        Journal: Codeunit "Inventory Native Journal ori";

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
        Process: Codeunit "Inv Native Journal Process ori";
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
        Process: Codeunit "Inv Native Journal Process ori";
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
        Process: Codeunit "Inv Native Journal Process ori";
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
