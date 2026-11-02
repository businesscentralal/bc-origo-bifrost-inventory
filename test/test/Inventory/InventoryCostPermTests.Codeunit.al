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
        DomainSetup: Codeunit "Inventory Test Library ori";
        Assert: Codeunit "Library Assert";

    /// <summary>A real read-only caller reads native cost and stock without card or posting rights.</summary>
    [Test]
    procedure CostGet_ReadOnlyCaller_ReturnsSnapshotWithoutWriteRights()
    var
        Item: Record Item;
        PendingEntry: Record "Post Value Entry to G/L";
        TempArgument: Record "Message Argument ori" temporary;
        ReadCosts: Codeunit "Inventory Cost Read ori";
        ReadImpl: Codeunit "Cost Get Impl ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        Rows: JsonArray;
        ModifiedAt: DateTime;
        PendingCount: Integer;
    begin
        // Story #4 AC01/AC02 | Time: independent | Risk: a semantic read accidentally requires native writes.
        CreateOwnedPendingCost(Item);
        Item.Get(Item."No.");
        PendingEntry.SetRange("Item No.", Item."No.");
        PendingCount := PendingEntry.Count();
        Assert.IsTrue(PendingCount > 0, 'Read permission is exercised with actual owned pending cost entries.');
        ModifiedAt := Item.SystemModifiedAt;
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Request.Add('itemNo', Item."No.");
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsTrue(Item.ReadPermission(), 'Caller has actual native Item read access.');
        Assert.IsFalse(Item.WritePermission() or PendingEntry.WritePermission(), 'Caller cannot change Item or pending-cost records.');
        Assert.IsTrue(PendingEntry.ReadPermission(), 'Cost-is-posted FlowField requires native pending-cost read access.');
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
        Assert.AreEqual(2, Token.AsValue().AsDecimal(), 'Owned posted stock can be read without posting rights.');
        Row.Get('costIsPostedToGL', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Owned pending cost is truthfully reported as not posted to G/L.');
        Assert.AreEqual(PendingCount, PendingEntry.Count(), 'Read leaves owned costs pending.');
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
        // Prepare the company toggle before restoring the exact restricted caller below.
        LowerPermissions.SetOutsideO365Scope();
        DomainSetup.EnableItemPrice();
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
        // Prepare the company toggle before restoring the exact restricted caller below.
        LowerPermissions.SetOutsideO365Scope();
        DomainSetup.EnableItemPrice();
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Write Test');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Price write does not require a posting token.');
        Assert.IsTrue(PriceImpl.IsEnabled(), 'Shipping full role grants execution and native Item rights allow discovery.');
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

    local procedure AssertPermissionDenied(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Response := Argument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Structured refusal precedes license and report work.');
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
}
