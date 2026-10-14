namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
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
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
        GLEntry: Record "G/L Entry";
        ValueEntry: Record "Value Entry";
        CostReports: Codeunit "Inventory Cost Reports ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        GLCount: Integer;
        ValueCount: Integer;
    begin
        // Story #35 native read-only report | Time: WorkDate() fixture | Risk: native test is not licensed MCP.
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
