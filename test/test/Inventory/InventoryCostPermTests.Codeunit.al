namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Real restricted callers prove costing read/write grants, direction, and the separate native/posting gates.</summary>
codeunit 96933 "Inventory Cost Perm. Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>A real read-only caller reads native cost and stock without card or posting rights.</summary>
    [Test]
    procedure CostGet_ReadOnlyCaller_ReturnsSnapshotWithoutWriteRights()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        ReadCosts: Codeunit "Inventory Cost Read ori";
        ReadImpl: Codeunit "Cost Get Impl ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        Rows: JsonArray;
        ModifiedAt: DateTime;
    begin
        // Story #4 AC01/AC02 | Time: independent | Risk: a semantic read accidentally requires native writes.
        LibraryInventory.CreateItem(Item);
        Item.Validate("Unit Cost", 12);
        Item.Modify(true);
        ModifiedAt := Item.SystemModifiedAt;
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Request.Add('itemNo', Item."No.");
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsTrue(Item.ReadPermission(), 'Caller has actual native Item read access.');
        Assert.IsFalse(Item.WritePermission(), 'Caller cannot change Item records.');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Cost reads do not gain posting rights.');
        Assert.IsTrue(ReadImpl.IsEnabled(), 'Semantic cost reads are discoverable for this read-only caller.');
        Assert.AreEqual("Msg Direction ori"::Outbound, ReadImpl.GetMessageDirection(), 'Cost reads are Outbound.');

        ReadCosts.ReadCosts(TempArgument);

        Response := TempArgument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Native reader returns Success with read-only permissions: ' + TempArgument.GetResponseText());
        Response.Get('items', Token);
        Rows := Token.AsArray();
        Assert.AreEqual(1, Rows.Count(), 'The owned selector returns exactly one item.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Row.Get('unitCost', Token);
        Assert.AreEqual(12, Token.AsValue().AsDecimal(), 'Native cost reaches the caller unchanged.');
        Row.Get('inventory', Token);
        Assert.AreEqual(0, Token.AsValue().AsDecimal(), 'Stock FlowField can be read without posting.');
        Item.Get(Item."No.");
        Assert.AreEqual(ModifiedAt, Item.SystemModifiedAt, 'The read did not modify the item.');
    end;

    /// <summary>The public cost implementation refuses a caller without native Item read before licensing.</summary>
    [Test]
    procedure CostGet_NoItemRead_RefusesBeforeLicense()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        ReadImpl: Codeunit "Cost Get Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #4 AC02 | Time: independent | Risk: discovery and execution disagree on denied native reads.
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsFalse(Item.ReadPermission(), 'The caller actually lacks native Item read permission.');
        Assert.IsFalse(ReadImpl.IsEnabled(), 'Cost read discovery is disabled without native Item read.');
        ReadImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>Card-cost execution refuses a real read-only caller before licensing or field writes.</summary>
    [Test]
    procedure CostUpdate_ReadOnlyCaller_RefusesBeforeLicense()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        CostImpl: Codeunit "Cost Update Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsTrue(Item.ReadPermission(), 'Caller retains native Item read permission.');
        Assert.IsFalse(Item.WritePermission(), 'Caller really lacks native Item write permission.');
        Assert.IsFalse(CostImpl.IsEnabled(), 'Card-cost write is hidden without native write access.');
        CostImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>Card-cost discovery requires native writes but does not acquire an inventory posting token.</summary>
    [Test]
    procedure CostUpdate_NativeWriteWithoutPostToken_Enabled()
    var
        Item: Record Item;
        CostImpl: Codeunit "Cost Update Impl ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Write Test');
        Assert.IsTrue(Item.WritePermission(), 'Native Item writes are present.');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Card-cost writes do not confer a posting token.');
        Assert.IsTrue(CostImpl.IsEnabled(), 'Native Item write permission enables card-cost discovery.');
    end;

    /// <summary>Price discovery and execution refuse a caller with only native Item read access.</summary>
    [Test]
    procedure PriceUpdate_ReadOnlyCaller_RefusesBeforeLicense()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        PriceImpl: Codeunit "Price Update Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Item.WritePermission(), 'Caller really lacks native Item write permission.');
        Assert.IsFalse(PriceImpl.IsEnabled(), 'Price write is hidden without native write access.');
        PriceImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>Price update needs native Item writes but not an inventory posting token.</summary>
    [Test]
    procedure PriceUpdate_NativeWriteWithoutPostToken_Enabled()
    var
        PriceImpl: Codeunit "Price Update Impl ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Write Test');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Price write does not require a posting token.');
        Assert.IsTrue(PriceImpl.IsEnabled(), 'Shipping full role grants execution and native Item rights allow discovery.');
    end;

    /// <summary>The shipping read role can discover read-only costing without a posting token.</summary>
    [Test]
    procedure TestCost_ReadCaller_EnabledOutboundWithoutPost()
    var
        Item: Record Item;
        TestImpl: Codeunit "Cost To GL Test Impl ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #35 read-only contract | Time: independent | Risk: #36 shared permission gate.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsTrue(Item.ReadPermission(), 'Caller has actual native Item read access.');
        Assert.IsFalse(Item.WritePermission(), 'Read caller must not gain Item writes.');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Read caller must not gain the posting token.');
        Assert.IsTrue(TestImpl.IsEnabled(), 'Shipping read execution grant must permit native test discovery.');
        Assert.AreEqual("Msg Direction ori"::Outbound, TestImpl.GetMessageDirection(), 'Read-only validation is Outbound.');
    end;

    /// <summary>A restricted read caller can resolve dedicated cost/price hints without being granted card writes.</summary>
    [Test]
    procedure CostFieldHints_ReadCaller_KeepWritePermissionsAbsent()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #4 field guard and #35 caller permissions | Time: independent | Risk: event subscriber must be executable for readers.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Item.WritePermission(), 'Hint access confers no native card writes.');
        Assert.IsTrue(TempArgument.GetDedicatedMessageTypeHintForField(Database::Item, Item.FieldNo("Unit Cost")).Contains('Inventory.Cost.Update'), 'Restricted read caller can execute the hint subscriber.');
        Assert.AreEqual('Inventory.Price.Update', TempArgument.GetDedicatedMessageTypeHintForField(Database::Item, Item.FieldNo("Unit Price")), 'Read caller can discover the price hint.');
    end;

    /// <summary>A reader cannot use discovery or execution to access Item data it cannot read.</summary>
    [Test]
    procedure TestCost_NoItemRead_RefusesBeforeLicense()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        TestImpl: Codeunit "Cost To GL Test Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #35 permission contract | Time: independent | Risk: no license bypass.
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsFalse(Item.ReadPermission(), 'Fixture must actually lack Item read access.');
        Assert.IsFalse(TestImpl.IsEnabled(), 'Unreadable Item hides this type.');
        TestImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>Native write access does not confer the additional posting token.</summary>
    [Test]
    procedure CostWrites_WithoutPostToken_RefuseExecution()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        AdjustImpl: Codeunit "Adjust Cost Run Impl ori";
        PostImpl: Codeunit "Cost To GL Post Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #35 posting contract | Time: independent | Risk: no native report may run.
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Write Test');
        Assert.IsTrue(Item.WritePermission(), 'Native write is present; this isolates the token gate.');
        Assert.IsFalse(AdjustImpl.IsEnabled(), 'Adjustment still needs the posting token.');
        Assert.IsFalse(PostImpl.IsEnabled(), 'G/L posting still needs the posting token.');
        AdjustImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument);
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        PostImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>The posting token must not replace the native table permission requirement.</summary>
    [Test]
    procedure CostWrites_PostTokenWithoutItemWrite_Disabled()
    var
        Item: Record Item;
        AdjustImpl: Codeunit "Adjust Cost Run Impl ori";
        PostImpl: Codeunit "Cost To GL Post Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #35/#36 permission conjunction | Time: independent | Risk: shared gate regression.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsFalse(Item.WritePermission(), 'Token must not grant native writes.');
        Assert.IsFalse(AdjustImpl.IsEnabled(), 'Adjustment needs both native write and posting permissions.');
        Assert.IsFalse(PostImpl.IsEnabled(), 'G/L posting needs both native write and posting permissions.');
    end;

    /// <summary>Explicit full role, native write permission and posting token enable both writes.</summary>
    [Test]
    procedure CostWrites_NativeWriteAndPostToken_Enabled()
    var
        AdjustImpl: Codeunit "Adjust Cost Run Impl ori";
        PostImpl: Codeunit "Cost To GL Post Impl ori";
        TestImpl: Codeunit "Cost To GL Test Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // Story #35 granted caller | Time: independent | Risk: discovery is not licensed execution proof.
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Write Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(AdjustImpl.IsEnabled(), 'Granted adjustment caller is enabled.');
        Assert.IsTrue(PostImpl.IsEnabled(), 'Granted G/L caller is enabled.');
        Assert.IsTrue(TestImpl.IsEnabled(), 'Full role retains read-only native test access.');
    end;

    /// <summary>Native report 1003 works with actual read-only native permissions and cannot post.</summary>
    [Test]
    procedure NativeTest_ReadOnlyCaller_TestsPendingCostWithoutWrites()
    var
        Item: Record Item;
        GLEntry: Record "G/L Entry";
        ValueEntry: Record "Value Entry";
        CostReports: Codeunit "Inventory Cost Reports ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        GLCount: Integer;
        ValueCount: Integer;
    begin
        // Story #35 native read-only report | Time: WorkDate() fixture | Risk: native test is not licensed MCP.
        CreateOwnedPendingCost(Item);
        Request.Add('itemNo', Item."No.");
        GLCount := GLEntry.Count();
        ValueCount := ValueEntry.Count();
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('D365 READ');
        Assert.IsFalse(Item.WritePermission(), 'Native reader must actually lack Item write access.');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Native reader must not get the Inventory posting token.');
        CostReports.TestCostToGL(Request, Response);
        Response.Get('entriesSelected', Token);
        Assert.IsTrue(Token.AsValue().AsInteger() > 0, 'Native report actually evaluates seeded pending costs.');
        Response.Get('posted', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Read-only native test never posts.');
        Assert.AreEqual(GLCount, GLEntry.Count(), 'No new G/L entries.');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'No new value entries.');
    end;

    /// <summary>A real read-only caller refuses mandatory journal numbering without consuming a number or posting costs.</summary>
    [Test]
    procedure Scenario_AC35_MandatoryTemplateRefusalPreservesNumberSeries()
    var
        Item: Record Item;
        GLSetup: Record "General Ledger Setup";
        JournalTemplate: Record "Gen. Journal Template";
        JournalBatch: Record "Gen. Journal Batch";
        SeriesLine: Record "No. Series Line";
        PendingEntry: Record "Post Value Entry to G/L";
        GLEntry: Record "G/L Entry";
        ValueEntry: Record "Value Entry";
        CostReports: Codeunit "Inventory Cost Reports ori";
        LibraryERM: Codeunit "Library - ERM";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Response: JsonObject;
        LastNoUsed: Code[20];
        LastDateUsed: Date;
        SeriesModifiedAt: DateTime;
        PendingCount: Integer;
        GLCount: Integer;
        ValueCount: Integer;
    begin
        // Story #35 native refusal per6157312634 | Time: WorkDate() fixture | Risk: full mandatory-template support remains pending.
        CreateOwnedPendingCost(Item);
        LibraryERM.CreateGenJournalTemplate(JournalTemplate);
        LibraryERM.CreateGenJournalBatch(JournalBatch, JournalTemplate.Name);
        JournalBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        JournalBatch.Modify(true);
        SeriesLine.SetRange("Series Code", JournalBatch."No. Series");
        SeriesLine.FindFirst();
        LastNoUsed := SeriesLine."Last No. Used";
        LastDateUsed := SeriesLine."Last Date Used";
        SeriesModifiedAt := SeriesLine.SystemModifiedAt;
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := true;
        GLSetup.Modify();
        PendingEntry.SetRange("Item No.", Item."No.");
        PendingCount := PendingEntry.Count();
        Assert.IsTrue(PendingCount > 0, 'The refusal protects actual owned pending inventory costs.');
        GLCount := GLEntry.Count();
        ValueCount := ValueEntry.Count();
        Request.Add('itemNo', Item."No.");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('D365 READ');
        Assert.IsTrue(SeriesLine.ReadPermission(), 'Caller can read the owned series.');
        Assert.IsFalse(SeriesLine.WritePermission() or GLEntry.WritePermission() or ValueEntry.WritePermission(), 'Caller cannot consume series or write posted costs.');

        asserterror CostReports.TestCostToGL(Request, Response);
        Assert.ExpectedError('read-only operation refuses');

        SeriesLine.FindFirst();
        Assert.AreEqual(LastNoUsed, SeriesLine."Last No. Used", 'Refusal consumes no number.');
        Assert.AreEqual(LastDateUsed, SeriesLine."Last Date Used", 'Refusal changes no number-series date.');
        Assert.AreEqual(SeriesModifiedAt, SeriesLine.SystemModifiedAt, 'Refusal does not modify the number series.');
        Assert.AreEqual(PendingCount, PendingEntry.Count(), 'Selected costs stay pending.');
        Assert.AreEqual(GLCount, GLEntry.Count(), 'Refusal creates no G/L entries.');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'Refusal creates no value entries.');
    end;

    local procedure CreateOwnedPendingCost(var Item: Record Item)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 2);
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
    end;

    local procedure AssertPermissionDenied(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Response := Argument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Structured refusal precedes license and report work.');
    end;
}
