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

/// <summary>Issue 159: real reclassification preview captures native entries without persisting posting changes.</summary>
codeunit 96977 "Reclass Preview Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Helper: Codeunit "Assembly Order Test Helper";
        ContractLibrary: Codeunit "Inventory Test Library ori";

    [Test]
    procedure Scenario_AC03_ValidBatch1033_CapturesRollbackEntries()
    begin
        VerifyPreview(1033, false);
    end;

    [Test]
    procedure Scenario_AC03_ValidBatch1039_CapturesRollbackEntries()
    begin
        VerifyPreview(1039, false);
    end;

    [Test]
    procedure Scenario_AC03_InvalidSecondLine_PreservesJournalAndLedgers()
    begin
        VerifyPreview(1033, true);
    end;

    [Test]
    procedure Scenario_AC03_WrongTemplate_RefusesBeforePreview()
    begin
        VerifyRefusal("Item Journal Template Type"::Item, 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC03_EmptyTransferBatch_RefusesWithoutSuccess()
    begin
        VerifyRefusal("Item Journal Template Type"::Transfer, 'PreconditionFailed');
    end;

    local procedure VerifyPreview(LanguageId: Integer; InvalidSecondLine: Boolean)
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        OtherBatch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        BadLine: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        Location: Record Location;
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeItemEntries: Integer;
        BeforeValueEntries: Integer;
        BeforeGLEntries: Integer;
        PreviousLanguage: Integer;
        LineId: Guid;
        OtherLineId: Guid;
        ModifiedAt: DateTime;
        ResponseText: Text;
    begin
        // Story #159 AC03 | Time: WorkDate for native postings | Risk: preview consumes journal or commits partial posting.
        CreateStock(Item);
        CreateBatch(Batch, "Item Journal Template Type"::Transfer);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", 2);
        Line.Validate("New Location Code", Location.Code);
        Line.Modify(true);
        LineId := Line.SystemId;
        ModifiedAt := Line.SystemModifiedAt;
        CreateBatch(OtherBatch, "Item Journal Template Type"::Transfer);
        LibraryInventory.CreateItemJournalLine(OtherLine, OtherBatch."Journal Template Name", OtherBatch.Name, OtherLine."Entry Type"::Transfer, Item."No.", 1);
        OtherLine.Validate("New Location Code", Location.Code);
        OtherLine.Modify(true);
        OtherLineId := OtherLine.SystemId;
        if InvalidSecondLine then begin
            BadLine := Line;
            BadLine."Line No." := Line."Line No." + 10000;
            Clear(BadLine.SystemId);
            BadLine."Item No." := 'W8-NOT-AN-ITEM';
            BadLine.Insert(false);
        end;
        BeforeItemEntries := ItemEntry.Count();
        BeforeValueEntries := ValueEntry.Count();
        BeforeGLEntries := GLEntry.Count();
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] The public dispatcher runs real native preview.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.PreviewPost", Request, Response);
        GlobalLanguage(PreviousLanguage);
        Response.WriteTo(ResponseText);
        Response.Get('status', Token);
        if InvalidSecondLine then begin
            Assert.AreEqual('Error', Token.AsValue().AsText(), ResponseText);
            Assert.IsTrue(Response.Get('code', Token), 'Native failure has a stable code.');
            Assert.IsFalse(Response.Contains('rollback'), 'Failure must not masquerade as a successful preview.');
        end else begin
            Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
            ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Reclassification.PreviewPost", Response);
            Response.Get('rollback', Token);
            Assert.IsTrue(Token.AsValue().AsBoolean(), 'Native preview completed its rollback.');
            Response.Get('entryCount', Token);
            Assert.IsTrue(Token.AsValue().AsInteger() >= 2, 'Transfer captures native outgoing and incoming entries.');
            Response.Get('preview', Token);
            Assert.IsTrue(Token.AsArray().Count() > 0, 'Real ledger tables are captured.');
            Response.Get('lineCount', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only the selected batch is previewed.');
        end;
        // [THEN] Both success and failure preserve every posting boundary and the unselected batch.
        Assert.AreEqual(BeforeItemEntries, ItemEntry.Count(), 'Item ledger unchanged.');
        Assert.AreEqual(BeforeValueEntries, ValueEntry.Count(), 'Value ledger unchanged.');
        Assert.AreEqual(BeforeGLEntries, GLEntry.Count(), 'G/L unchanged.');
        Assert.IsTrue(Line.GetBySystemId(LineId), 'Selected journal line remains.');
        Assert.AreEqual(ModifiedAt, Line.SystemModifiedAt, 'Preview does not persist a journal modification.');
        Assert.AreEqual(2, Line.Quantity, 'Selected quantity unchanged.');
        Assert.IsTrue(OtherLine.GetBySystemId(OtherLineId), 'Unselected batch remains.');
        Assert.AreEqual(1, OtherLine.Quantity, 'Unselected quantity unchanged.');
        if InvalidSecondLine then
            Assert.IsTrue(BadLine.Get(Batch."Journal Template Name", Batch.Name, BadLine."Line No."), 'Invalid later line also remains.');
    end;

    local procedure VerifyRefusal(JournalType: Enum "Item Journal Template Type"; ExpectedCode: Text)
    var
        Batch: Record "Item Journal Batch";
        ItemEntry: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeEntries: Integer;
    begin
        // Story #159 AC03 | Time: none | Risk: empty or wrong journal returns false Success.
        EnableDomain();
        CreateBatch(Batch, JournalType);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        BeforeEntries := ItemEntry.Count();
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.PreviewPost", Request, Response);
        Assert.IsTrue(Response.Get('code', Token), 'Refusal is coded.');
        Assert.AreEqual(ExpectedCode, Token.AsValue().AsText(), 'Journal refusal code.');
        Assert.AreEqual(BeforeEntries, ItemEntry.Count(), 'Refusal leaves ledger unchanged.');
    end;

    local procedure EnableDomain()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Reclassification := true;
        Setup.Modify(true);
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch"; JournalType: Enum "Item Journal Template Type")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalType);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;
    local procedure CreateStock(var Item: Record Item)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
    begin
        EnableDomain();
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

}
