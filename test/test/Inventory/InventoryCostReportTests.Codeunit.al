namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Purchases.Document;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Native report selections, refusal safety and real G/L test/post behavior using self-created stock.</summary>
codeunit 96931 "Inventory Cost Report Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        CostReports: Codeunit "Inventory Cost Reports ori";

    /// <summary>Report 795 receives escaped native fields and explicit boolean options.</summary>
    [Test]
    procedure AdjustmentRequestUsesNativeOptions()
    var
        Item: Record Item;
        Request: JsonObject;
        Document: XmlDocument;
        Node: XmlNode;
        Parameters: Text;
    begin
        Request.Add('itemNo', 'X*&<>XBAD');
        Request.Add('postToGL', true);
        Request.Add('itemByItem', true);
        Parameters := CostReports.PrepareAdjustment(Request, Item);
        XmlDocument.ReadFrom(Parameters, Document);
        Document.SelectSingleNode('/ReportParameters/Options/Field[@name="ItemNoFilter"]', Node);
        Assert.AreEqual('X*&<>XBAD', Node.AsXmlElement().InnerText(), 'Native filter must survive XML escaping.');
        Document.SelectSingleNode('/ReportParameters/Options/Field[@name="PostToGL"]', Node);
        Assert.AreEqual('true', Node.AsXmlElement().InnerText(), 'One native optional G/L pass.');
        Document.SelectSingleNode('/ReportParameters/Options/Field[@name="ByItemCommit"]', Node);
        Assert.AreEqual('true', Node.AsXmlElement().InnerText(), 'Native item-by-item option.');
        Assert.AreEqual('X*&<>XBAD', Item.GetFilter("No."), 'Selection matches report options.');
    end;

    /// <summary>Conflicting legacy and canonical selections cannot widen a write.</summary>
    [Test]
    procedure ConflictingAliasRefusesBeforeWrites()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        Request.Add('itemNo', 'XONE');
        Request.Add('itemNoFilter', 'XTWO');
        asserterror CostReports.PrepareAdjustment(Request, Item);
        Assert.ExpectedError('must have the same value');
    end;

    /// <summary>A native report 795 filter must not be truncated.</summary>
    [Test]
    procedure AdjustmentRefusesOverlongFilter()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        Request.Add('itemNo', PadStr('X', 251, 'X'));
        asserterror CostReports.PrepareAdjustment(Request, Item);
        Assert.ExpectedError('must not exceed 250');
    end;

    /// <summary>Exactly 250 characters are retained.</summary>
    [Test]
    procedure AdjustmentAcceptsFilterBoundary()
    var
        Item: Record Item;
        Request: JsonObject;
        Parameters: Text;
    begin
        Request.Add('itemNo', PadStr('', 125, 'X').Replace('X', 'X|').TrimEnd('|') + '*');
        Parameters := CostReports.PrepareAdjustment(Request, Item);
        Assert.AreEqual(250, StrLen(Item.GetFilter("No.")), 'Boundary remains intact.');
        Assert.IsTrue(Parameters <> '', 'Native request generated.');
    end;

    /// <summary>A date selection that native report 795 cannot honor fails before any report execution.</summary>
    [Test]
    procedure UnsupportedAdjustmentDateRefusesWithoutWrites()
    var
        ValueEntry: Record "Value Entry";
        GLEntry: Record "G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
        ValueCount: Integer;
        GLCount: Integer;
    begin
        ValueCount := ValueEntry.Count();
        GLCount := GLEntry.Count();
        Request.Add('postingDate', '2026-01-01..2026-01-31');
        asserterror CostReports.AdjustCost(Request, Response);
        Assert.ExpectedError('does not support the postingDate filter');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'No value entry write on refusal.');
        Assert.AreEqual(GLCount, GLEntry.Count(), 'No G/L write on refusal.');
    end;

    /// <summary>Neither an object filter nor a textual boolean may default to an unfiltered report.</summary>
    [Test]
    procedure MalformedOptionsRefuseBeforeReport()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        Request.ReadFrom('{"itemNo":{}}');
        asserterror CostReports.PrepareAdjustment(Request, Item);
        Assert.ExpectedError('must be text');
        Request.ReadFrom('{"postToGL":"true"}');
        asserterror CostReports.PrepareAdjustment(Request, Item);
        Assert.ExpectedError('must be boolean');
    end;

    /// <summary>Both incompatible report 795 filters are rejected even with no inventory.</summary>
    [Test]
    procedure AdjustmentRejectsBothFilters()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        Request.Add('itemNo', 'XONE');
        Request.Add('itemCategoryCode', 'XCAT');
        asserterror CostReports.PrepareAdjustment(Request, Item);
        Assert.ExpectedError('not both');
    end;

    /// <summary>Report 1002/1003 use the actual pending-entry dataitem filters.</summary>
    [Test]
    procedure GLRequestFiltersIntersect()
    var
        PendingEntry: Record "Post Value Entry to G/L";
        Request: JsonObject;
        DocumentNo: Code[20];
        PerPostingGroup: Boolean;
    begin
        Request.Add('itemNoFilter', 'XONE|XTWO');
        Request.Add('postingDateFilter', Format(WorkDate(), 0, 9));
        CostReports.PrepareCostToGL(Request, PendingEntry, PerPostingGroup, DocumentNo);
        Assert.AreEqual('XONE|XTWO', PendingEntry.GetFilter("Item No."), 'Legacy item filter selects pending entries.');
        Assert.AreEqual(WorkDate(), PendingEntry.GetRangeMin("Posting Date"), 'Date filter is effective.');
        Assert.IsFalse(PerPostingGroup, 'Default is per entry.');
        Assert.AreEqual('', DocumentNo, 'No invented output number.');
    end;

    /// <summary>Unsupported document filters must not be echoed as though applied.</summary>
    [Test]
    procedure GLDocumentFilterRefuses()
    var
        PendingEntry: Record "Post Value Entry to G/L";
        Request: JsonObject;
        DocumentNo: Code[20];
        PerPostingGroup: Boolean;
    begin
        Request.Add('documentNoFilter', 'XINVOICE');
        asserterror CostReports.PrepareCostToGL(Request, PendingEntry, PerPostingGroup, DocumentNo);
        Assert.ExpectedError('does not support the documentNoFilter');
    end;

    /// <summary>Per-group posting requires an explicit output document number.</summary>
    [Test]
    procedure GLPostingGroupRequiresDocumentOption()
    var
        PendingEntry: Record "Post Value Entry to G/L";
        Request: JsonObject;
        DocumentNo: Code[20];
        PerPostingGroup: Boolean;
    begin
        Request.Add('perPostingGroup', true);
        asserterror CostReports.PrepareCostToGL(Request, PendingEntry, PerPostingGroup, DocumentNo);
        Assert.ExpectedError('documentNo is required');
        Request.Add('documentNo', 'XGLTEST');
        CostReports.PrepareCostToGL(Request, PendingEntry, PerPostingGroup, DocumentNo);
        Assert.AreEqual('XGLTEST', DocumentNo, 'Native output number.');
    end;

    /// <summary>Report 1003 exercises actual unposted inventory without changing G/L or costing state.</summary>
    [Test]
    procedure NativeTestDoesNotPostOrConsumePendingEntries()
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        PendingEntry: Record "Post Value Entry to G/L";
        GLEntry: Record "G/L Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        GLCount: Integer;
        ValueCount: Integer;
        PendingCount: Integer;
    begin
        CreateUnpostedCost(Item);
        Request.Add('itemNo', Item."No.");
        GLCount := GLEntry.Count();
        ValueCount := ValueEntry.Count();
        PendingCount := PendingEntry.Count();
        CostReports.TestCostToGL(Request, Response);
        Response.Get('posted', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Test report does not post.');
        Response.Get('entriesSelected', Token);
        Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'Real pending cost entries were tested.');
        Assert.AreEqual(GLCount, GLEntry.Count(), 'No G/L entries added.');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'No value entries added.');
        Assert.AreEqual(PendingCount, PendingEntry.Count(), 'No pending entries consumed.');
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'No costing state changed.');
    end;

    /// <summary>Native posting-date errors are returned, rather than a fabricated empty error list.</summary>
    [Test]
    procedure NativeTestReturnsPostingDateWarnings()
    var
        Item: Record Item;
        GLSetup: Record "General Ledger Setup";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateUnpostedCost(Item);
        GLSetup.Get();
        GLSetup."Allow Posting From" := WorkDate() + 1;
        GLSetup.Modify();
        Request.Add('itemNo', Item."No.");
        CostReports.TestCostToGL(Request, Response);
        Response.Get('errors', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Report 1003 must expose native warnings for blocked posting dates.');
    end;

    /// <summary>Mandatory journal setup cannot turn a read-only test into number-series consumption.</summary>
    [Test]
    procedure NativeTestRefusesNumberSeriesSideEffect()
    var
        GLSetup: Record "General Ledger Setup";
        Request: JsonObject;
        Response: JsonObject;
    begin
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := true;
        GLSetup.Modify();
        asserterror CostReports.TestCostToGL(Request, Response);
        Assert.ExpectedError('read-only operation refuses');
    end;

    /// <summary>Post=true posts real selected costs while another self-created item remains pending.</summary>
    [Test]
    [HandlerFunctions('PostingMessageHandler')]
    procedure NativePostRespectsItemFilter()
    var
        Item: Record Item;
        OtherItem: Record Item;
        ValueEntry: Record "Value Entry";
        PendingEntry: Record "Post Value Entry to G/L";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateUnpostedCost(Item);
        CreateUnpostedCost(OtherItem);
        Request.Add('itemNo', Item."No.");
        CostReports.PostCostToGL(Request, Response);
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.IsTrue(ValueEntry."Cost Posted to G/L" <> 0, 'Selected cost really posted to G/L.');
        ValueEntry.SetRange("Item No.", OtherItem."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'Unselected cost remains unposted.');
        PendingEntry.SetRange("Item No.", OtherItem."No.");
        Assert.IsFalse(PendingEntry.IsEmpty(), 'Unselected pending entry is preserved.');
    end;

    /// <summary>Report 795 adjusts only the selected self-posted item through its real request-page path.</summary>
    [Test]
    procedure NativeAdjustmentHonorsItemSelection()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Observer: Codeunit "Inventory Cost Observer";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateUnpostedCost(Item);
        CreateUnpostedCost(OtherItem);
        Item.Get(Item."No.");
        OtherItem.Get(OtherItem."No.");
        Assert.IsFalse(Item."Cost is Adjusted", 'Selected fixture must require real adjustment.');
        Assert.IsFalse(OtherItem."Cost is Adjusted", 'Other fixture must require adjustment.');
        Request.Add('itemNo', Item."No.");
        Request.Add('itemByItem', true);
        Request.Add('postToGL', false);
        BindSubscription(Observer);
        CostReports.AdjustCost(Request, Response);
        Assert.AreEqual(Item."No.", Observer.ItemFilter(), 'Native report receives exact selected item.');
        Assert.IsTrue(Observer.ItemByItem(), 'Native report receives itemByItem=true.');
        UnbindSubscription(Observer);
        Item.Get(Item."No.");
        OtherItem.Get(OtherItem."No.");
        Assert.IsTrue(Item."Cost is Adjusted", 'Native report adjusted selected item.');
        Assert.IsFalse(OtherItem."Cost is Adjusted", 'Unselected item is unchanged.');
    end;

    /// <summary>Report 795 posts selected costs through its own option without executing a second report 1002.</summary>
    [Test]
    procedure NativeAdjustmentPostsToGLOnce()
    var
        Item: Record Item;
        InventorySetup: Record "Inventory Setup";
        OtherItem: Record Item;
        ValueEntry: Record "Value Entry";
        Observer: Codeunit "Inventory Cost Observer";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateUnpostedCost(Item);
        CreateUnpostedCost(OtherItem);
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := true;
        InventorySetup.Modify();
        Request.Add('itemNo', Item."No.");
        Request.Add('postToGL', true);
        BindSubscription(Observer);
        CostReports.AdjustCost(Request, Response);
        Assert.IsTrue(Observer.PostToGLOption(), 'Native report receives postToGL=true.');
        Assert.AreEqual(0, Observer.Report1002Runs(), 'No additional report 1002 is run.');
        UnbindSubscription(Observer);
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Posted to G/L", "Cost Amount (Actual)");
        Assert.IsTrue(ValueEntry."Cost Amount (Actual)" <> 0, 'Fixture contains actual cost.');
        Assert.AreEqual(ValueEntry."Cost Amount (Actual)", ValueEntry."Cost Posted to G/L", 'Selected actual cost posts exactly once.');
        ValueEntry.SetRange("Item No.", OtherItem."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'Unselected item remains unposted.');
    end;

    /// <summary>A disabled native G/L option refuses before adjustment or ledger writes.</summary>
    [Test]
    procedure AdjustmentRefusesUnavailableGLPosting()
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateUnpostedCost(Item);
        Request.Add('itemNo', Item."No.");
        Request.Add('postToGL', true);
        asserterror CostReports.AdjustCost(Request, Response);
        Assert.ExpectedError('requires Automatic Cost Posting');
        Item.Get(Item."No.");
        Assert.IsFalse(Item."Cost is Adjusted", 'Refusal occurs before adjustment.');
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'Refusal never posts to G/L.');
    end;

    /// <summary>An explicitly disabled G/L option is honored even when automatic posting is enabled.</summary>
    [Test]
    procedure NativeAdjustmentHonorsExplicitNoGLPosting()
    var
        Item: Record Item;
        InventorySetup: Record "Inventory Setup";
        ValueEntry: Record "Value Entry";
        Observer: Codeunit "Inventory Cost Observer";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateUnpostedCost(Item);
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := true;
        InventorySetup.Modify();
        Request.Add('itemNo', Item."No.");
        Request.Add('postToGL', false);
        BindSubscription(Observer);
        CostReports.AdjustCost(Request, Response);
        Assert.IsFalse(Observer.PostToGLOption(), 'Explicit false overrides the native setup default.');
        UnbindSubscription(Observer);
        Item.Get(Item."No.");
        Assert.IsTrue(Item."Cost is Adjusted", 'Cost adjustment still runs.');
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'G/L cost remains unposted.');
    end;

    /// <summary>The native posting report refuses a blocked posting date without posting the selected entry.</summary>
    [Test]
    procedure NativePostRefusesBlockedPostingDate()
    var
        Item: Record Item;
        GLSetup: Record "General Ledger Setup";
        ValueEntry: Record "Value Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateUnpostedCost(Item);
        GLSetup.Get();
        GLSetup."Allow Posting From" := WorkDate() + 1;
        GLSetup.Modify();
        Request.Add('itemNo', Item."No.");
        asserterror CostReports.PostCostToGL(Request, Response);
        Assert.ExpectedError('Posting Date is not within');
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Posted to G/L");
        Assert.AreEqual(0, ValueEntry."Cost Posted to G/L", 'Blocked date did not post.');
    end;

    /// <summary>A nonmatching posting-date filter excludes an otherwise eligible self-created value entry.</summary>
    [Test]
    procedure NativeTestHonorsPostingDateFilter()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateUnpostedCost(Item);
        Request.Add('itemNo', Item."No.");
        Request.Add('postingDate', Format(WorkDate() + 1, 0, 9));
        CostReports.TestCostToGL(Request, Response);
        Response.Get('entriesSelected', Token);
        Assert.AreEqual(0, Token.AsValue().AsInteger(), 'Nonmatching date excludes the pending entry.');
        Request.Replace('postingDate', Format(WorkDate(), 0, 9));
        CostReports.TestCostToGL(Request, Response);
        Response.Get('entriesSelected', Token);
        Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'Matching date includes the same pending entry.');
    end;

    /// <summary>Native expected-cost exclusions remain pending and are returned as skipped entry numbers.</summary>
    [Test]
    [HandlerFunctions('PostingMessageHandler')]
    procedure NativePostReturnsExpectedCostExclusion()
    var
        Item: Record Item;
        InventoryPostingSetup: Record "Inventory Posting Setup";
        GeneralPostingSetup: Record "General Posting Setup";
        InventorySetup: Record "Inventory Setup";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        PendingEntry: Record "Post Value Entry to G/L";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryERM: Codeunit "Library - ERM";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateUnpostedCost(Item);
        InventorySetup.Get();
        InventorySetup."Expected Cost Posting to G/L" := true;
        InventorySetup.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        PurchaseLine.Validate("Direct Unit Cost", 15);
        PurchaseLine.Modify(true);
        InventoryPostingSetup.Get('', Item."Inventory Posting Group");
        InventoryPostingSetup.Validate("Inventory Account (Interim)", LibraryERM.CreateGLAccountNo());
        InventoryPostingSetup.Modify(true);
        GeneralPostingSetup.Get(PurchaseLine."Gen. Bus. Posting Group", PurchaseLine."Gen. Prod. Posting Group");
        GeneralPostingSetup.Validate("Invt. Accrual Acc. (Interim)", LibraryERM.CreateGLAccountNo());
        GeneralPostingSetup.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        PendingEntry.SetRange("Item No.", Item."No.");
        Assert.AreEqual(2, PendingEntry.Count(), 'Fixture has both actual and expected costs pending before configuration changes.');
        InventorySetup.Get();
        InventorySetup."Expected Cost Posting to G/L" := false;
        InventorySetup.Modify();
        Request.Add('itemNo', Item."No.");
        CostReports.PostCostToGL(Request, Response);
        Response.Get('skippedEntries', Token);
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Native expected-cost exclusion appears in report output.');
        PendingEntry.SetRange("Item No.", Item."No.");
        Assert.IsFalse(PendingEntry.IsEmpty(), 'Expected-cost exclusion stays pending.');
    end;

    /// <summary>Handles the actual native report posting summary without hiding unexpected messages.</summary>
    [MessageHandler]
    procedure PostingMessageHandler(MessageText: Text[1024])
    begin
        Assert.IsTrue(MessageText.Contains('value entries have been posted to the general ledger'), 'Expected native posting summary: ' + MessageText);
    end;

    /// <summary>Checks generated request parameter names against the platform request page itself.</summary>
    [Test]
    [HandlerFunctions('AdjustmentRequestHandler')]
    procedure AdjustmentParametersMatchNativeRequestPage()
    var
        Parameters: Text;
        Document: XmlDocument;
        Node: XmlNode;
    begin
        Parameters := Report.RunRequestPage(Report::"Adjust Cost - Item Entries");
        XmlDocument.ReadFrom(Parameters, Document);
        Assert.IsTrue(Document.SelectSingleNode('/ReportParameters/Options/Field[@name="ItemNoFilter"]', Node), Parameters);
        Assert.AreEqual('XITEM', Node.AsXmlElement().InnerText(), Parameters);
    end;

    /// <summary>Supplies explicit native request options while obtaining the platform XML, without running the report.</summary>
    [RequestPageHandler]
    procedure AdjustmentRequestHandler(var RequestPage: TestRequestPage "Adjust Cost - Item Entries")
    begin
        RequestPage.FilterItemNo.SetValue('XITEM');
        RequestPage."Item-by-Item Adjustment".SetValue(true);
        RequestPage.OK().Invoke();
    end;

    local procedure CreateUnpostedCost(var Item: Record Item)
    var
        InventorySetup: Record "Inventory Setup";
        GLSetup: Record "General Ledger Setup";
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
        Item.Rename(CopyStr('X' + Item."No.", 1, MaxStrLen(Item."No.")));
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 2);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
    end;
}
