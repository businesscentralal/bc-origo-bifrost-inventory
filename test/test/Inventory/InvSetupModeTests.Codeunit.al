namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Pricing.PriceList;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Setup mode for this app's protected tables (#235): Inventory Setup is the only setup/configuration table this app
/// restricts and opens in setup mode; every other restricted table stays restricted. The public Foundation facade is
/// read-only, so the open-versus-closed decision is tested through the decision procedure with the setup-mode flag
/// supplied, and the real Foundation predicate is tested with setup mode off.
/// </summary>
codeunit 96997 "Inv Setup Mode Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure SetupTable_Restricted_WhenSetupModeOff()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Restrict: Codeunit "Inventory Setup Restrict ori";
    begin
        // [SCENARIO AC04] Inventory Setup is refused through Data.Records.Set while setup mode is off.
        Assert.IsTrue(Restrict.IsTableRestricted(Database::"Inventory Setup ori", false), 'Decision: closed when setup mode is off.');
        TempArgument.Init();
        TempArgument.Insert(true);
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Inventory Setup ori", false), 'Foundation predicate: closed when setup mode is off.');
    end;

    [Test]
    procedure SetupTable_Open_WhenSetupModeOn()
    var
        Restrict: Codeunit "Inventory Setup Restrict ori";
    begin
        // [SCENARIO AC02/AC04] While setup mode is on, this app no longer restricts Inventory Setup.
        Assert.IsFalse(Restrict.IsTableRestricted(Database::"Inventory Setup ori", true), 'Decision: open when setup mode is on.');
    end;

    [Test]
    procedure OtherTables_NotRestrictedByThisCodeunit_InEitherMode()
    var
        Restrict: Codeunit "Inventory Setup Restrict ori";
    begin
        // [SCENARIO AC04] This codeunit only ever speaks for Inventory Setup. An unrelated table is not made restricted by it.
        Assert.IsFalse(Restrict.IsTableRestricted(Database::Item, false), 'Item off.');
        Assert.IsFalse(Restrict.IsTableRestricted(Database::Item, true), 'Item on.');
    end;

    [Test]
    procedure ProtectedTables_StayRestricted_WithSetupModeOff()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // [SCENARIO AC02/AC04] Every other table the app restricts is business data routed through message types.
        // None of their subscribers reads setup mode, so they stay closed in both modes; here they are checked closed
        // through the real Foundation predicate (setup mode off), and the open-in-setup-mode list is exactly one table.
        TempArgument.Init();
        TempArgument.Insert(true);
        AssertClosed(TempArgument, Database::"Stockkeeping Unit");
        AssertClosed(TempArgument, Database::"Item Category");
        AssertClosed(TempArgument, Database::"Item Attribute Value Mapping");
        AssertClosed(TempArgument, Database::"Item Attribute");
        AssertClosed(TempArgument, Database::"Item Attribute Value");
        AssertClosed(TempArgument, Database::"Item Attr. Value Translation");
        AssertClosed(TempArgument, Database::"Item Variant");
        AssertClosed(TempArgument, Database::"Price List Header");
        AssertClosed(TempArgument, Database::"Price List Line");
        AssertClosed(TempArgument, Database::"Reservation Entry");
        AssertClosed(TempArgument, Database::"Tracking Specification");
        AssertClosed(TempArgument, Database::"Item Charge Assignment (Purch)");
        AssertClosed(TempArgument, Database::"Item Charge Assignment (Sales)");
    end;

    local procedure AssertClosed(var TempArgument: Record "Message Argument ori" temporary; TableNo: Integer)
    begin
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(TableNo, false), 'Table ' + Format(TableNo) + ' must stay write restricted.');
    end;
}
