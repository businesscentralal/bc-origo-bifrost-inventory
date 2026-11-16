namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 186: Check, Preview and Post share the native empty physical-line boundary in both languages.</summary>
codeunit 96964 "Inv. 186 Blank Line Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        ContractLibrary: Codeunit "Inventory Test Library ori";
        Helper: Codeunit "Assembly Order Test Helper";

    /// <summary>AC1/AC2/AC4: a mixed batch checks, previews and posts in English.</summary>
    [Test]
    procedure MixedBatch_1033()
    begin
        VerifyPostable(1033, false);
    end;

    /// <summary>AC1/AC2/AC4: a mixed batch checks, previews and posts in Icelandic.</summary>
    [Test]
    procedure MixedBatch_1039()
    begin
        VerifyPostable(1039, false);
    end;

    /// <summary>AC1/AC2/AC4: excluding blanks preserves explicit selection in English.</summary>
    [Test]
    procedure SelectedLines_1033()
    begin
        VerifyPostable(1033, true);
    end;

    /// <summary>AC1/AC2/AC4: excluding blanks preserves explicit selection in Icelandic.</summary>
    [Test]
    procedure SelectedLines_1039()
    begin
        VerifyPostable(1039, true);
    end;

    /// <summary>AC1/AC2/AC4: a blank-only selection retains the empty-batch contract in English.</summary>
    [Test]
    procedure BlankOnly_1033()
    begin
        VerifyBlankOnly(1033);
    end;

    /// <summary>AC1/AC2/AC4: a blank-only selection retains the empty-batch contract in Icelandic.</summary>
    [Test]
    procedure BlankOnly_1039()
    begin
        VerifyBlankOnly(1039);
    end;

    /// <summary>AC3/AC4: each nonzero quantity field keeps missing-item rows invalid in English.</summary>
    [Test]
    procedure MissingItem_1033()
    begin
        VerifyMissingItem(1033);
    end;

    /// <summary>AC3/AC4: each nonzero quantity field keeps missing-item rows invalid in Icelandic.</summary>
    [Test]
    procedure MissingItem_1039()
    begin
        VerifyMissingItem(1039);
    end;

    local procedure VerifyPostable(LanguageId: Integer; SelectSubset: Boolean)
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        BlankLine: Record "Item Journal Line";
        InvalidLine: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        PhysicalEntries: Record "Phys. Inventory Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Selected: JsonArray;
        Token: JsonToken;
        PreviousLanguage: Integer;
        BeforeEntries: Integer;
        BeforePhysical: Integer;
        LineId: Guid;
        BlankId: Guid;
    begin
        // [GIVEN] An owned count with a shortage and the empty row left by the native page.
        CreatePhysical(Batch, Line);
        CreateBlank(Batch, Line."Line No." + 10000, BlankLine);
        LineId := Line.SystemId;
        BlankId := BlankLine.SystemId;
        if SelectSubset then begin
            CreateBlank(Batch, Line."Line No." + 20000, InvalidLine);
            InvalidLine.Quantity := 1;
            InvalidLine.Modify(false);
            Selected.Add(Line.SystemId);
            Selected.Add(BlankLine.SystemId);
            Request.Add('lineSystemIds', Selected);
        end;
        BeforeEntries := Entries.Count();
        BeforePhysical := PhysicalEntries.Count();
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);

        // [WHEN] The same selection passes through the public Check and Preview dispatchers.
        Dispatch("Message Type ori"::"Inventory.PhysInventory.Check", Batch, Request, Response);
        AssertText(Response, 'status', 'Success');
        AssertText(Response, 'validationResult', 'Ready');
        AssertNumber(Response, 'lineCount', 1);
        AssertNumber(Response, 'errorCount', 0);
        Dispatch("Message Type ori"::"Inventory.PhysInventory.PreviewPost", Batch, Request, Response);
        AssertText(Response, 'status', 'Success');
        AssertNumber(Response, 'linesToPost', 1);
        Assert.IsTrue(Response.Get('preview', Token), 'Preview entries are returned.');
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Native shortage entries are captured.');

        // [THEN] Both operations preserve the lines and ledgers; Post agrees with the preview.
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Check and preview do not post item entries.');
        Assert.AreEqual(BeforePhysical, PhysicalEntries.Count(), 'Check and preview do not post physical entries.');
        Assert.IsTrue(Line.GetBySystemId(LineId), 'Preview keeps the counted line.');
        Assert.AreEqual(8, Line."Qty. (Phys. Inventory)", 'Preview preserves the count.');
        Assert.IsTrue(BlankLine.GetBySystemId(BlankId), 'Read operations do not delete the empty row.');
        Dispatch("Message Type ori"::"Inventory.PhysInventory.Post", Batch, Request, Response);
        GlobalLanguage(PreviousLanguage);
        AssertText(Response, 'status', 'Success');
        AssertNumber(Response, 'postedLineCount', 1);
        Entries.SetRange("Item No.", Line."Item No.");
        Entries.SetRange(Quantity, -2);
        Assert.AreEqual(1, Entries.Count(), 'Post creates the actual shortage predicted by preview.');
        if SelectSubset then
            Assert.IsTrue(InvalidLine.GetBySystemId(InvalidLine.SystemId), 'The unselected invalid row remains untouched.');
    end;

    local procedure VerifyBlankOnly(LanguageId: Integer)
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        BlankLine: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Selected: JsonArray;
        PreviousLanguage: Integer;
        BeforeEntries: Integer;
    begin
        // [GIVEN] Only an empty row is selected; a valid count outside the selection must not leak in.
        CreatePhysical(Batch, Line);
        CreateBlank(Batch, Line."Line No." + 10000, BlankLine);
        Selected.Add(BlankLine.SystemId);
        Request.Add('lineSystemIds', Selected);
        BeforeEntries := Entries.Count();
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Check, Preview and Post receive the identical empty selection.
        Dispatch("Message Type ori"::"Inventory.PhysInventory.Check", Batch, Request, Response);
        AssertText(Response, 'status', 'Success');
        AssertText(Response, 'validationResult', 'NotReady');
        AssertNumber(Response, 'lineCount', 0);
        AssertCheckProblem(Response, 'PreconditionFailed');
        Dispatch("Message Type ori"::"Inventory.PhysInventory.PreviewPost", Batch, Request, Response);
        AssertRefusal(Response, 'PreconditionFailed');
        Dispatch("Message Type ori"::"Inventory.PhysInventory.Post", Batch, Request, Response);
        GlobalLanguage(PreviousLanguage);
        AssertRefusal(Response, 'PreconditionFailed');
        // [THEN] Empty selection never becomes a successful no-op or posts the unselected line.
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Empty selection does not post.');
        Assert.IsTrue(Line.GetBySystemId(Line.SystemId), 'The unselected count remains.');
        Assert.IsTrue(BlankLine.GetBySystemId(BlankLine.SystemId), 'The empty row remains.');
    end;

    local procedure VerifyMissingItem(LanguageId: Integer)
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        InvalidLine: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        PhysicalEntries: Record "Phys. Inventory Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        BeforeEntries: Integer;
        BeforePhysical: Integer;
        QuantityField: Integer;
    begin
        // [GIVEN] Valid owned stock plus a row missing Item No. with one populated quantity field.
        CreatePhysical(Batch, Line);
        CreateBlank(Batch, Line."Line No." + 10000, InvalidLine);
        BeforeEntries := Entries.Count();
        BeforePhysical := PhysicalEntries.Count();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        for QuantityField := 1 to 3 do begin
            InvalidLine.Quantity := 0;
            InvalidLine."Qty. (Calculated)" := 0;
            InvalidLine."Qty. (Phys. Inventory)" := 0;
            case QuantityField of
                1:
                    InvalidLine.Quantity := 1;
                2:
                    InvalidLine."Qty. (Calculated)" := 1;
                3:
                    InvalidLine."Qty. (Phys. Inventory)" := 1;
            end;
            InvalidLine.Modify(false);
            Commit();
            // [WHEN] All three public operations validate the same malformed batch.
            Dispatch("Message Type ori"::"Inventory.PhysInventory.Check", Batch, Request, Response);
            AssertText(Response, 'status', 'Success');
            AssertText(Response, 'validationResult', 'NotReady');
            AssertNumber(Response, 'lineCount', 2);
            AssertCheckProblem(Response, 'BusinessCentralError');
            Dispatch("Message Type ori"::"Inventory.PhysInventory.PreviewPost", Batch, Request, Response);
            AssertRefusal(Response, 'BusinessCentralError');
            Dispatch("Message Type ori"::"Inventory.PhysInventory.Post", Batch, Request, Response);
            AssertRefusal(Response, 'BusinessCentralError');
            // [THEN] The shared typed refusal keeps all rows and both ledgers unchanged.
            Assert.AreEqual(BeforeEntries, Entries.Count(), 'Invalid row cannot cause partial item posting.');
            Assert.AreEqual(BeforePhysical, PhysicalEntries.Count(), 'Invalid row cannot cause partial physical posting.');
            Assert.IsTrue(Line.GetBySystemId(Line.SystemId), 'The valid count is not consumed.');
            Assert.IsTrue(InvalidLine.GetBySystemId(InvalidLine.SystemId), 'The invalid row is not silently discarded.');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Batch: Record "Item Journal Batch"; Request: JsonObject; var Response: JsonObject)
    begin
        Clear(Response);
        Helper.ProcessMessage(MessageType, Batch."Journal Template Name" + '|' + Batch.Name, Request, Response);
    end;

    local procedure AssertText(Response: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        Assert.IsTrue(Response.Get(Name, Token), ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), ResponseText);
    end;

    local procedure AssertNumber(Response: JsonObject; Name: Text; Expected: Integer)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), Name + ' is returned.');
        Assert.AreEqual(Expected, Token.AsValue().AsInteger(), Name);
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    begin
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', ExpectedCode);
    end;

    local procedure AssertCheckProblem(Response: JsonObject; ExpectedCode: Text)
    var
        Token: JsonToken;
    begin
        AssertNumber(Response, 'errorCount', 1);
        Assert.IsTrue(Response.Get('errors', Token), 'Check returns its typed problems.');
        Assert.IsTrue(Token.AsArray().Get(0, Token), 'Check returns the failing line.');
        AssertText(Token.AsObject(), 'code', ExpectedCode);
    end;

    local procedure CreatePhysical(var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    var
        Item: Record Item;
        StockBatch: Record "Item Journal Batch";
        StockLine: Record "Item Journal Line";
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        CalculateInventory: Report "Calculate Inventory";
    begin
        ContractLibrary.EnablePhysicalInventory();
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
        Item.Rename(CopyStr('X186' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Item."No.")));
        CreateBatch(StockBatch, "Item Journal Template Type"::Item);
        LibraryInventory.CreateItemJournalLine(StockLine, StockBatch."Journal Template Name", StockBatch.Name, StockLine."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        StockLine.Validate("Posting Date", WorkDate());
        StockLine.Validate("Document No.", 'X186-STOCK');
        StockLine.Validate("Unit Amount", 12);
        StockLine.Modify(true);
        LibraryInventory.PostItemJournalLine(StockBatch."Journal Template Name", StockBatch.Name);
        CreateBatch(Batch, "Item Journal Template Type"::"Phys. Inventory");
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        Item.SetRange("No.", Item."No.");
        CalculateInventory.SetItemJnlLine(Line);
        CalculateInventory.InitializeRequest(WorkDate(), 'X186-COUNT', false, false);
        CalculateInventory.SetTableView(Item);
        CalculateInventory.UseRequestPage(false);
        CalculateInventory.RunModal();
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
        Line.FindFirst();
        Line.Validate("Qty. (Phys. Inventory)", 8);
        Line.Modify(true);
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch"; JournalType: Enum "Item Journal Template Type")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalType);
        JournalTemplate.Rename(CopyStr('X' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(JournalTemplate.Name)));
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        Batch.Rename(JournalTemplate.Name, 'X186');
    end;

    local procedure CreateBlank(Batch: Record "Item Journal Batch"; LineNo: Integer; var Line: Record "Item Journal Line")
    begin
        Clear(Line);
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        Line."Line No." := LineNo;
        Line.Insert(false);
    end;
}
