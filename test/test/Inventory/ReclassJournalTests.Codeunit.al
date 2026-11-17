namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 34: Reclassification Check validates lines natively; Post and Preview accept lineSystemIds and Post returns the item register.</summary>
codeunit 96964 "Reclass Journal Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Helper: Codeunit "Assembly Order Test Helper";

    /// <summary>Check ValidBatch 1033 IsReady.</summary>
    [Test]
    procedure Scenario_AC34_Check_ValidBatch_1033_IsReady()
    begin
        VerifyCheck(1033, false, false);
    end;

    /// <summary>Check ValidBatch 1039 IsReady.</summary>
    [Test]
    procedure Scenario_AC34_Check_ValidBatch_1039_IsReady()
    begin
        VerifyCheck(1039, false, false);
    end;

    /// <summary>Check BlockedItemLine IsNotReady.</summary>
    [Test]
    procedure Scenario_AC34_Check_BlockedItemLine_IsNotReady()
    begin
        VerifyCheck(1033, true, false);
    end;

    /// <summary>Check SubsetSkipsInvalidLine.</summary>
    [Test]
    procedure Scenario_AC34_Check_SubsetSkipsInvalidLine()
    begin
        VerifyCheck(1033, true, true);
    end;

    /// <summary>Post Subset PostsOnlySelectedLine 1033.</summary>
    [Test]
    procedure Scenario_AC34_Post_Subset_PostsOnlySelectedLine_1033()
    begin
        VerifyPost(1033);
    end;

    /// <summary>Post Subset PostsOnlySelectedLine 1039.</summary>
    [Test]
    procedure Scenario_AC34_Post_Subset_PostsOnlySelectedLine_1039()
    begin
        VerifyPost(1039);
    end;

    /// <summary>Post ForeignLineSystemId IsRefused.</summary>
    [Test]
    procedure Scenario_AC34_Post_ForeignLineSystemId_IsRefused()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        OtherBatch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        OtherLine: Record "Item Journal Line";
        Location: Record Location;
        Entries: Record "Item Ledger Entry";
        Ids: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeEntries: Integer;
    begin
        // [GIVEN] A line that belongs to another batch.
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        CreateBatch(OtherBatch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        CreateLine(OtherLine, OtherBatch, Item, Location, 1);
        Ids.Add(Format(OtherLine.SystemId, 0, 4));
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('lineSystemIds', Ids);
        Request.Add('expectedCount', 1);
        BeforeEntries := Entries.Count();
        Commit();
        // [WHEN] Posting with the foreign SystemId.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        // [THEN] The request is refused and nothing is posted.
        Assert.IsTrue(Response.Get('code', Token), 'Refusal is coded.');
        Assert.AreEqual('InvalidParameter', Token.AsValue().AsText(), 'Foreign line id code.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Nothing is posted.');
    end;

    /// <summary>Post ItemTemplate IsRefusedAsPreconditionFailed.</summary>
    [Test]
    procedure Scenario_AC34_Post_ItemTemplate_IsRefusedAsPreconditionFailed()
    var
        Batch: Record "Item Journal Batch";
        JournalTemplate: Record "Item Journal Template";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        EnableDomain();
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, "Item Journal Template Type"::Item);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('expectedCount', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        Assert.IsTrue(Response.Get('code', Token), 'Refusal is coded.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Only Transfer templates post.');
    end;

    /// <summary>PreviewAndPost TemplateNameAndBatchNameAliases AreAccepted.</summary>
    [Test]
    procedure Scenario_AC34_PreviewAndPost_TemplateNameAndBatchNameAliases_AreAccepted()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Location: Record Location;
        Entries: Record "Item Ledger Entry";
        Register: Record "Item Register";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ResponseText: Text;
    begin
        // [GIVEN] A reclassification batch addressed with templateName and batchName, the aliases the contract declares.
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        Commit();
        // [WHEN] Previewing and then posting.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.PreviewPost", Request, Response);
        Response.WriteTo(ResponseText);
        // [THEN] The preview does not refuse and the line is still in the journal.
        Assert.IsFalse(Response.Contains('code'), ResponseText);
        Assert.IsTrue(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Preview leaves the line.');
        Clear(Response);
        Request.Add('expectedCount', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        Response.WriteTo(ResponseText);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Response.Get('postedLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'The aliased batch is posted.');
        Response.Get('itemRegisterNo', Token);
        Assert.IsTrue(Register.Get(Token.AsValue().AsInteger()), 'The item register exists.');
        Entries.SetRange("Item No.", Item."No.");
        Entries.SetRange("Entry Type", Entries."Entry Type"::Transfer);
        Assert.IsFalse(Entries.IsEmpty(), 'Item ledger entries of type Transfer are written.');
    end;

    /// <summary>Check CanonicalNamesWinOverAliases.</summary>
    [Test]
    procedure Scenario_AC34_Check_CanonicalNamesWinOverAliases()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Location: Record Location;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #34 AC34 | Time: WorkDate for stock | Risk: alias resolution selects a different batch.
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        Request.Add('journalTemplateName', 'XUNKNOWN');
        Request.Add('journalBatchName', 'XUNKNOWN');
        Commit();
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Check", Request, Response);
        Assert.IsTrue(Response.Get('validationResult', Token), 'The canonical batch is checked.');
        Assert.AreEqual('Ready', Token.AsValue().AsText(), 'Unused aliases do not change the selection.');
        Assert.IsTrue(Response.Get('messageType', Token), 'The released response key remains.');
        Assert.AreEqual('Inventory.Reclassification.Check', Token.AsValue().AsText(), 'The released message type value remains.');
    end;

    /// <summary>PreviewPost JournalNamesWinOverAliases.</summary>
    [Test]
    procedure Scenario_AC34_PreviewPost_JournalNamesWinOverAliases()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Location: Record Location;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #34 AC34 | Time: WorkDate for stock | Risk: alias resolution selects a different batch.
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('templateName', 'XUNKNOWN');
        Request.Add('batchName', 'XUNKNOWN');
        Commit();
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.PreviewPost", Request, Response);
        Assert.IsTrue(Response.Get('rollback', Token), 'The canonical batch is previewed.');
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'Native preview rolled back.');
        Assert.IsTrue(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Preview leaves its source.');
        Request.Add('expectedCount', 1);
        Clear(Response);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        Assert.IsTrue(Response.Get('postedLineCount', Token), 'The canonical batch is posted.');
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'One selected line posted.');
        // Standard whole-batch posting leaves one blank placeholder line at the first line number; the posted content must be gone.
        if Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No.") then
            Assert.AreEqual('', Line."Item No.", 'Posted source leaves the journal.');
    end;

    /// <summary>Post NonTransferEntry IsRefused.</summary>
    [Test]
    procedure Scenario_AC34_Post_NonTransferEntry_IsRefused()
    begin
        VerifyWrongEntryType("Message Type ori"::"Inventory.Reclassification.Post");
    end;

    /// <summary>Preview NonTransferEntry IsRefused.</summary>
    [Test]
    procedure Scenario_AC34_Preview_NonTransferEntry_IsRefused()
    begin
        VerifyWrongEntryType("Message Type ori"::"Inventory.Reclassification.PreviewPost");
    end;

    /// <summary>CountHelp StatesBatchOperationInBothLanguages.</summary>
    [Test]
    procedure Scenario_AC34_CountHelp_StatesBatchOperationInBothLanguages()
    var
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Parameter: JsonToken;
        Token: JsonToken;
        Found: Boolean;
        LanguageId: Integer;
        PreviousLanguage: Integer;
    begin
        // Story #34 AC34 | Time: none | Risk: count guidance disagrees with the fixed confirmation count.
        Contract := "Message Type ori"::"Inventory.Reclassification.Post";
        PreviousLanguage := GlobalLanguage();
        for LanguageId := 1033 to 1039 do
            if LanguageId in [1033, 1039] then begin
                GlobalLanguage(LanguageId);
                Clear(Effect);
                Contract.GetEffect(Effect);
                Effect.Get('changes', Token);
                Assert.IsTrue(Token.AsValue().AsText().Contains('expectedCount'), 'Effect names the confirmation count.');
                Assert.IsTrue(Token.AsValue().AsText().Contains('1'), 'The batch operation count is one.');
                Clear(Parameters);
                Contract.GetParameters(Parameters);
                Found := false;
                foreach Parameter in Parameters do begin
                    Parameter.AsObject().Get('name', Token);
                    if Token.AsValue().AsText() = 'expectedCount' then begin
                        Parameter.AsObject().Get('description', Token);
                        Assert.IsTrue(Token.AsValue().AsText().Contains('expectedCount'), 'Parameter states its count unit.');
                        Assert.IsTrue(Token.AsValue().AsText().Contains('1'), 'Parameter states the fixed count.');
                        Found := true;
                    end;
                end;
                // Foundation without the confirmation protocol advertises no expectedCount; the declaration follows the deployed protocol.
                Assert.AreEqual(Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired'), Found, 'Post declares expectedCount with its specific unit exactly when Foundation supports confirmation.');
            end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure VerifyWrongEntryType(MessageType: Enum "Message Type ori")
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Location: Record Location;
        Entries: Record "Item Ledger Entry";
        Values: Record "Value Entry";
        GLEntries: Record "G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeEntries: Integer;
        BeforeValues: Integer;
        BeforeGLEntries: Integer;
    begin
        // Story #34 AC34 | Time: WorkDate for stock | Risk: adjustment entries posted through a Transfer batch.
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        Line."Entry Type" := Line."Entry Type"::"Positive Adjmt.";
        Line.Modify(false);
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        if MessageType = "Message Type ori"::"Inventory.Reclassification.Post" then
            Request.Add('expectedCount', 1);
        BeforeEntries := Entries.Count();
        BeforeValues := Values.Count();
        BeforeGLEntries := GLEntries.Count();
        Commit();
        Helper.ProcessMessage(MessageType, Request, Response);
        Assert.IsTrue(Response.Get('status', Token), 'Refusal has a status.');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'A Transfer template cannot post an adjustment entry.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'Item ledger is unchanged.');
        Assert.AreEqual(BeforeValues, Values.Count(), 'Value ledger is unchanged.');
        Assert.AreEqual(BeforeGLEntries, GLEntries.Count(), 'General ledger is unchanged.');
        Assert.IsTrue(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Refused source line remains.');
    end;

    local procedure VerifyCheck(LanguageId: Integer; WithBlockedLine: Boolean; Subset: Boolean)
    var
        Item: Record Item;
        BlockedItem: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        BadLine: Record "Item Journal Line";
        Location: Record Location;
        Ids: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
        ResponseText: Text;
    begin
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 1);
        if WithBlockedLine then begin
            CreateStock(BlockedItem);
            CreateLine(BadLine, Batch, BlockedItem, Location, 1);
            BlockedItem.Find();
            BlockedItem.Blocked := true;
            BlockedItem.Modify();
        end;
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        if Subset then begin
            Ids.Add(Format(Line.SystemId, 0, 4));
            Request.Add('lineSystemIds', Ids);
        end;
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Check", Request, Response);
        GlobalLanguage(PreviousLanguage);
        Response.WriteTo(ResponseText);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Response.Get('validationResult', Token);
        if WithBlockedLine and not Subset then begin
            Assert.AreEqual('NotReady', Token.AsValue().AsText(), ResponseText);
            Response.Get('errorCount', Token);
            Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'The blocked item is reported.');
            Response.Get('lineCount', Token);
            Assert.AreEqual(2, Token.AsValue().AsInteger(), 'Both lines are checked.');
        end else begin
            Assert.AreEqual('Ready', Token.AsValue().AsText(), ResponseText);
            Response.Get('lineCount', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only the valid line is checked.');
            Response.Get('postedLineCount', Token);
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Compatibility count equals lineCount.');
        end;
    end;

    local procedure VerifyPost(LanguageId: Integer)
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        SecondLine: Record "Item Journal Line";
        Location: Record Location;
        Entries: Record "Item Ledger Entry";
        Register: Record "Item Register";
        Ids: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
        ResponseText: Text;
    begin
        EnableDomain();
        CreateStock(Item);
        CreateBatch(Batch);
        LibraryWarehouse.CreateLocationWMS(Location, false, false, false, false, false);
        CreateLine(Line, Batch, Item, Location, 2);
        CreateLine(SecondLine, Batch, Item, Location, 1);
        Ids.Add(Format(Line.SystemId, 0, 4));
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('lineSystemIds', Ids);
        Request.Add('expectedCount', 1);
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reclassification.Post", Request, Response);
        GlobalLanguage(PreviousLanguage);
        Response.WriteTo(ResponseText);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Response.Get('postedLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Only the selected line is posted.');
        Response.Get('itemRegisterNo', Token);
        Assert.IsTrue(Register.Get(Token.AsValue().AsInteger()), 'The item register exists.');
        Response.Get('result', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One result per posted line.');
        Assert.IsTrue(Response.Contains('journalBatchName'), 'Earlier response key is kept.');
        Entries.SetRange("Item No.", Item."No.");
        Entries.SetRange("Entry Type", Entries."Entry Type"::Transfer);
        Assert.IsFalse(Entries.IsEmpty(), 'Item ledger entries of type Transfer are written.');
        Assert.IsFalse(Line.Get(Line."Journal Template Name", Line."Journal Batch Name", Line."Line No."), 'Posted line leaves the journal.');
        Assert.IsTrue(SecondLine.Get(SecondLine."Journal Template Name", SecondLine."Journal Batch Name", SecondLine."Line No."), 'Unselected line remains.');
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

    local procedure CreateBatch(var Batch: Record "Item Journal Batch")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, "Item Journal Template Type"::Transfer);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;

    local procedure CreateLine(var Line: Record "Item Journal Line"; Batch: Record "Item Journal Batch"; Item: Record Item; Location: Record Location; Quantity: Decimal)
    begin
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::Transfer, Item."No.", Quantity);
        Line.Validate("New Location Code", Location.Code);
        Line.Modify(true);
    end;

    local procedure CreateStock(var Item: Record Item)
    var
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
    begin
        Clear(Item);
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
