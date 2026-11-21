namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Upgrade;
using System.TestLibraries.Utilities;
using System.Upgrade;

/// <summary>Issue 267: Inventory domains are off by default, Suggest Setup turns on what the company can use. Each test rolls back in an owned company.</summary>
codeunit 97901 "Inventory Suggest Setup Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        SuggestSetup: Codeunit "Inventory Suggest Setup ori";
        ConfirmReply: Boolean;
        ConfirmCount: Integer;
        ConfirmText: Text;

    [Test]
    procedure Default_NewSetupHasEveryDomainOff()
    var
        Setup: Record "Inventory Setup ori";
        Domain: Enum "Inventory Domain ori";
        Ordinal: Integer;
    begin
        // [SCENARIO] Issue267 AC01 | A new setup row has every switch off even when the company has items.
        ClearSources();
        CreateItem();
        // [WHEN] The row is created.
        Setup.DeleteAll(false);
        Setup.InsertIfNotExists();
        Setup.Get();
        // [THEN] Nothing is on.
        foreach Ordinal in Domain.Ordinals() do
            Assert.IsFalse(Setup.IsDomainEnabled(Enum::"Inventory Domain ori".FromInteger(Ordinal)), 'New row: every switch is off.');
    end;

    [Test]
    procedure Default_MissingRowCountsAsOff()
    var
        Setup: Record "Inventory Setup ori";
        Domain: Enum "Inventory Domain ori";
        Ordinal: Integer;
    begin
        // [SCENARIO] Issue267 AC01 | No row counts as off.
        Setup.DeleteAll(false);
        foreach Ordinal in Domain.Ordinals() do
            Assert.IsFalse(Setup.IsDomainEnabled(Enum::"Inventory Domain ori".FromInteger(Ordinal)), 'No row: every domain is off.');
        Assert.IsFalse(Setup.Get(), 'Reading must not create the row.');
    end;

    [Test]
    procedure Rule_Transfer_NeedsInTransitAndTwoOtherLocations()
    var
        Reason: Text;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Transfer Orders rule both ways.
        ClearSources();
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::TransferOrders, Reason), 'No locations: off.');
        Assert.IsTrue(Reason.Contains('no in-transit location (Use As In-Transit)'), 'Reason names the in-transit location.');
        CreateLocation('ZZ267A', false);
        CreateLocation('ZZ267B', false);
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::TransferOrders, Reason), 'Two plain locations but no in-transit: off.');
        CreateLocation('ZZ267T', true);
        Assert.IsTrue(SuggestSetup.Evaluate("Inventory Domain ori"::TransferOrders, Reason), 'In-transit plus two other locations: on.');
        DeleteLocation('ZZ267B');
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::TransferOrders, Reason), 'In-transit plus one other location: off.');
        Assert.IsTrue(Reason.Contains('fewer than two other locations'), 'Reason names the missing locations.');
    end;

    [Test]
    procedure Rule_Assembly_NeedsBomComponentOfTypeItem()
    var
        BOMComponent: Record "BOM Component";
        Reason: Text;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Assembly rule both ways.
        ClearSources();
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::Assembly, Reason), 'No BOM: off.');
        BOMComponent.Init();
        BOMComponent."Parent Item No." := 'ZZ267P';
        BOMComponent."Line No." := 10000;
        BOMComponent.Type := BOMComponent.Type::Resource;
        BOMComponent."No." := 'ZZ267R';
        BOMComponent.Insert(false);
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::Assembly, Reason), 'A resource component is not an item BOM: off.');
        BOMComponent.Type := BOMComponent.Type::Item;
        BOMComponent.Modify(false);
        Assert.IsTrue(SuggestSetup.Evaluate("Inventory Domain ori"::Assembly, Reason), 'An item component: on.');
    end;

    [Test]
    procedure Rule_ItemTracking_NeedsItemUsingATrackingCode()
    var
        Item: Record Item;
        Reason: Text;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Item Tracking rule both ways.
        ClearSources();
        CreateItem();
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::ItemTracking, Reason), 'Item without code: off.');
        Item.FindFirst();
        Item."Item Tracking Code" := 'ZZ267';
        Item.Modify(false);
        Assert.IsTrue(SuggestSetup.Evaluate("Inventory Domain ori"::ItemTracking, Reason), 'Item with code: on.');
    end;

    [Test]
    procedure Rule_ItemCharge_NeedsAnItemCharge()
    var
        ItemCharge: Record "Item Charge";
        Reason: Text;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Item Charge rule both ways.
        ClearSources();
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::ItemCharge, Reason), 'No charge: off.');
        ItemCharge.Init();
        ItemCharge."No." := 'ZZ267';
        ItemCharge.Insert(false);
        Assert.IsTrue(SuggestSetup.Evaluate("Inventory Domain ori"::ItemCharge, Reason), 'A charge: on.');
    end;

    [Test]
    procedure Rule_InventoryPeriod_NeedsAnInventoryPeriod()
    var
        InventoryPeriod: Record "Inventory Period";
        Reason: Text;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Inventory Period rule both ways.
        ClearSources();
        Assert.IsFalse(SuggestSetup.Evaluate("Inventory Domain ori"::InventoryPeriod, Reason), 'No period: off.');
        InventoryPeriod.Init();
        InventoryPeriod."Ending Date" := 20991231D;
        InventoryPeriod.Insert(false);
        Assert.IsTrue(SuggestSetup.Evaluate("Inventory Domain ori"::InventoryPeriod, Reason), 'A period: on.');
    end;

    [Test]
    procedure Rule_OtherDomains_NeedAtLeastOneItem()
    var
        Domain: Enum "Inventory Domain ori";
        Reason: Text;
        Ordinal: Integer;
        Checked: Integer;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Every other domain follows the item rule both ways.
        ClearSources();
        foreach Ordinal in Domain.Ordinals() do
            if IsItemRuleDomain(Enum::"Inventory Domain ori".FromInteger(Ordinal)) then begin
                Assert.IsFalse(SuggestSetup.Evaluate(Enum::"Inventory Domain ori".FromInteger(Ordinal), Reason), 'No item: off.');
                Assert.AreNotEqual('', Reason, 'Off carries a reason.');
                Checked += 1;
            end;
        Assert.AreEqual(14, Checked, 'Fourteen domains follow the item rule.');
        CreateItem();
        foreach Ordinal in Domain.Ordinals() do
            if IsItemRuleDomain(Enum::"Inventory Domain ori".FromInteger(Ordinal)) then
                Assert.IsTrue(SuggestSetup.Evaluate(Enum::"Inventory Domain ori".FromInteger(Ordinal), Reason), 'An item: on.');
    end;

    [Test]
    procedure Reasons_AreTranslated_1033_and_1039()
    var
        Reason: Text;
        PreviousLanguage: Integer;
    begin
        // [SCENARIO] Issue267 AC05 | Reason texts exist in en-US and is-IS.
        ClearSources();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        SuggestSetup.Evaluate("Inventory Domain ori"::TransferOrders, Reason);
        Assert.AreEqual('Transfer Orders: no in-transit location (Use As In-Transit) is set up', Reason, 'en-US reason.');
        GlobalLanguage(1039);
        SuggestSetup.Evaluate("Inventory Domain ori"::TransferOrders, Reason);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(Reason.StartsWith('Flutningspantanir'), 'is-IS reason: ' + Reason);
    end;

    [Test]
    procedure Upgrade_NoRow_FillsRowOnceBehindTag()
    var
        Setup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
        UpgradeTagLibrary: Codeunit "Upgrade Tag Library";
        PerCompanyTags: List of [Code[250]];
    begin
        // [SCENARIO] Issue267 AC03/AC06 | The tag runs once; install and upgrade register it.
        ClearSources();
        CreateItem();
        Setup.DeleteAll(false);
        UpgradeTagLibrary.DeleteUpgradeTag(SuggestSetup.GetSuggestSetupTag(), CopyStr(CompanyName(), 1, 30));
        // [WHEN] The company has no row and the run is due.
        SuggestSetup.RunOncePerCompany();
        // [THEN] The row exists with the item-rule domains on, and the tag is set.
        Assert.IsTrue(Setup.Get(), 'Row created.');
        Assert.IsTrue(Setup.Availability, 'Item rule domain on.');
        Assert.IsFalse(Setup."Transfer Orders", 'No in-transit location: off.');
        Assert.IsTrue(UpgradeTag.HasUpgradeTag(SuggestSetup.GetSuggestSetupTag()), 'Tag set.');
        // [WHEN] The administrator turns a domain off and the run happens again with the tag set.
        Setup.Availability := false;
        Setup.Modify(false);
        SuggestSetup.RunOncePerCompany();
        // [THEN] The tag stops a second run.
        Setup.Get();
        Assert.IsFalse(Setup.Availability, 'Tag stops a second run.');
        UpgradeTag.GetPerCompanyUpgradeTags(PerCompanyTags);
        Assert.IsTrue(PerCompanyTags.Contains(SuggestSetup.GetSuggestSetupTag()), 'Tag is registered for fresh installs.');
    end;

    [Test]
    procedure Upgrade_ExistingRow_IsNeverChanged()
    var
        Setup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
        UpgradeTagLibrary: Codeunit "Upgrade Tag Library";
        Before: Text;
    begin
        // [SCENARIO] Issue267 AC03/AC06 | An existing row is the administrator's choice.
        ClearSources();
        CreateItem();
        Setup.DeleteAll(false);
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Reservations := true;
        Setup.Modify(false);
        Before := Format(Setup);
        UpgradeTagLibrary.DeleteUpgradeTag(SuggestSetup.GetSuggestSetupTag(), CopyStr(CompanyName(), 1, 30));
        // [WHEN] The run is due.
        SuggestSetup.RunOncePerCompany();
        // [THEN] The row is unchanged even though items exist, and the tag is set.
        Setup.Get();
        Assert.AreEqual(Before, Format(Setup), 'Existing row untouched.');
        Assert.IsFalse(Setup.Availability, 'Items do not turn anything on in an existing row.');
        Assert.IsTrue(UpgradeTag.HasUpgradeTag(SuggestSetup.GetSuggestSetupTag()), 'Tag set.');
    end;

    [Test]
    [HandlerFunctions('ProposalHandler,MessageHandler')]
    procedure Manual_AppliesOnlyAfterConfirmation_AndIsRepeatable()
    var
        Setup: Record "Inventory Setup ori";
        After: Text;
    begin
        // [SCENARIO] Issue267 AC02/AC06 | Manual Suggest Setup shows the proposal and applies after Yes; twice gives the same result.
        ClearSources();
        CreateItem();
        Setup.DeleteAll(false);
        Setup.InsertIfNotExists();
        // [WHEN] The administrator answers No.
        ConfirmReply := false;
        ConfirmCount := 0;
        Assert.IsFalse(SuggestSetup.RunWithConfirmation(Setup), 'No change after No.');
        Setup.Get();
        Assert.IsFalse(Setup.Availability, 'Nothing applied after No.');
        Assert.AreEqual(1, ConfirmCount, 'The proposal was shown.');
        Assert.IsTrue(ConfirmText.Contains('leave off - Transfer Orders: no in-transit location'), 'Proposal has the reason: ' + ConfirmText);
        Assert.IsTrue(ConfirmText.Contains('turn on - Availability: the company has items'), 'Proposal lists what turns on.');
        // [WHEN] The administrator answers Yes.
        ConfirmReply := true;
        Assert.IsTrue(SuggestSetup.RunWithConfirmation(Setup), 'Applied after Yes.');
        Setup.Get();
        Assert.IsTrue(Setup.Availability, 'Item rule domain turned on.');
        Assert.IsFalse(Setup."Transfer Orders", 'No in-transit location: stays off.');
        After := Format(Setup);
        // [WHEN] It runs again.
        Assert.IsFalse(SuggestSetup.RunWithConfirmation(Setup), 'Second run proposes nothing.');
        Setup.Get();
        Assert.AreEqual(After, Format(Setup), 'Twice gives the same result.');
        Assert.AreEqual(2, ConfirmCount, 'The second run shows no proposal page, only a message.');
    end;

    [Test]
    procedure Gate_SwitchOff_HidesButStillExecutes()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        // [SCENARIO] Issue267 AC06 / #36 | A type is listed only when its switch is on; execution is never refused for a switch.
        Setup.DeleteAll(false);
        Setup.InsertIfNotExists();
        Setup.Get();
        Assert.IsFalse(Gate.IsEnabled("Inventory Domain ori"::Availability, Database::Item, false, false), 'Switch off: not listed.');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Assert.IsTrue(Gate.AssertEnabled(TempArgument, "Inventory Domain ori"::Availability, Database::Item, false, false), 'Switch off: still executes.');
        Setup.Availability := true;
        Setup.Modify(false);
        Assert.IsTrue(Gate.IsEnabled("Inventory Domain ori"::Availability, Database::Item, false, false), 'Switch on: listed.');
    end;

    [ModalPageHandler]
    procedure ProposalHandler(var ProposalPage: TestPage "Inventory Suggest Setup ori")
    begin
        ConfirmCount += 1;
        ConfirmText := ProposalPage.ProposalText.Value();
        if ConfirmReply then
            ProposalPage.OK().Invoke()
        else
            ProposalPage.Cancel().Invoke();
    end;

    [MessageHandler]
    procedure MessageHandler(Text: Text[1024])
    begin
        ConfirmText := Text;
    end;

    local procedure IsItemRuleDomain(Domain: Enum "Inventory Domain ori"): Boolean
    begin
        exit(not (Domain in [Domain::TransferOrders, Domain::Assembly, Domain::ItemTracking, Domain::ItemCharge, Domain::InventoryPeriod]));
    end;

    local procedure ClearSources()
    var
        Location: Record Location;
        Item: Record Item;
        BOMComponent: Record "BOM Component";
        ItemCharge: Record "Item Charge";
        InventoryPeriod: Record "Inventory Period";
    begin
        // Only the individually owned verification company; the test runner rolls the transaction back.
        Location.DeleteAll(false);
        Item.DeleteAll(false);
        BOMComponent.DeleteAll(false);
        ItemCharge.DeleteAll(false);
        InventoryPeriod.DeleteAll(false);
    end;

    local procedure CreateItem()
    var
        Item: Record Item;
    begin
        Item.Init();
        Item."No." := 'ZZ267ITEM';
        Item.Insert(false);
    end;

    local procedure CreateLocation(LocationCode: Code[10]; InTransit: Boolean)
    var
        Location: Record Location;
    begin
        Location.Init();
        Location.Code := LocationCode;
        Location."Use As In-Transit" := InTransit;
        Location.Insert(false);
    end;

    local procedure DeleteLocation(LocationCode: Code[10])
    var
        Location: Record Location;
    begin
        Location.Get(LocationCode);
        Location.Delete(false);
    end;
}
