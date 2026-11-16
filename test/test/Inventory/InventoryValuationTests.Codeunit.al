namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 109: seeded value entries prove historical valuation, paging, refusals and read-only behavior.</summary>
codeunit 96989 "Inventory Valuation Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        Valuation: Codeunit "Valuation Get Impl ori";

    /// <summary>Actual costs, expected reversals and zero-quantity adjustments use posting date.</summary>
    [Test]
    procedure Scenario_AC01_HistoricalCosts()
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        BeforeCount: Integer;
        ModifiedAt: DateTime;
    begin
        CreateItem(Item);
        SeedEntry(Item."No.", '', '', 20260101D, 10, 0, 100);
        SeedEntry(Item."No.", '', '', 20260102D, 0, 120, -100);
        SeedEntry(Item."No.", '', '', 20260102D, 0, 5, 0);
        SeedEntry(Item."No.", '', '', 20260103D, -2, -24, 0);
        BeforeCount := ValueEntry.Count();
        ModifiedAt := Item.SystemModifiedAt;
        Request := RequestFor(Item."No.", '2026-01-01');
        Response := Read(Request);
        Row := RowAt(Response, 0);
        AssertNumber(Row, 'quantity', 10);
        AssertNumber(Row, 'actualCost', 0);
        AssertNumber(Row, 'expectedCost', 100);
        Request.Replace('asOfDate', '2026-01-02');
        Response := Read(Request);
        Row := RowAt(Response, 0);
        AssertNumber(Row, 'quantity', 10);
        AssertNumber(Row, 'actualCost', 125);
        AssertNumber(Row, 'expectedCost', 0);
        AssertNumber(Row, 'totalCost', 125);
        Request.Replace('asOfDate', '2026-01-03');
        Row := RowAt(Read(Request), 0);
        AssertNumber(Row, 'quantity', 8);
        AssertNumber(Row, 'actualCost', 101);
        Assert.AreEqual(BeforeCount, ValueEntry.Count(), 'Read creates no value entries.');
        ValueEntry.SetRange("Item No.", Item."No.");
        ValueEntry.CalcSums("Cost Amount (Actual)", "Cost Amount (Expected)");
        Assert.AreEqual(101, ValueEntry."Cost Amount (Actual)", 'Read preserves native actual costs.');
        Assert.AreEqual(0, ValueEntry."Cost Amount (Expected)", 'Read preserves expected reversals.');
        Item.Get(Item."No.");
        Assert.AreEqual(ModifiedAt, Item.SystemModifiedAt, 'Read preserves the item.');
    end;

    /// <summary>Grouping is sorted before paging, including empty location and variant codes.</summary>
    [Test]
    procedure Scenario_AC02_GroupedPaging()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateItem(Item);
        SeedEntry(Item."No.", 'XLOC', 'XVAR', 20260101D, 2, 20, 0);
        SeedEntry(Item."No.", '', '', 20260101D, 1, 10, 0);
        SeedEntry(Item."No.", 'XLOC', '', 20260101D, 3, 30, 0);
        SeedEntry(Item."No.", 'XLOC', 'XVAR', 20260101D, 4, 40, 0);
        Request := RequestFor(Item."No.", '2026-01-01');
        Request.Add('take', 1);
        Response := Read(Request);
        AssertNumber(Response, 'totalCount', 3);
        AssertNumber(RowAt(Response, 0), 'quantity', 1);
        AssertText(RowAt(Response, 0), 'locationCode', '');
        Response.Get('hasMore', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'More groups remain.');
        Request.Add('skip', 1);
        Response := Read(Request);
        AssertNumber(RowAt(Response, 0), 'quantity', 3);
        Request.Replace('skip', 2);
        Response := Read(Request);
        AssertNumber(RowAt(Response, 0), 'quantity', 6);
        Response.Get('hasMore', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Last group has no next page.');
        Request.Replace('skip', 2147483647);
        Response := Read(Request);
        AssertNumber(Response, 'totalCount', 3);
        Response.Get('rows', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Large skip returns an empty page without overflow.');
        Request.Replace('take', 1000);
        Request.Replace('skip', 0);
        Response := Read(Request);
        Response.Get('rows', Token);
        Assert.AreEqual(3, Token.AsArray().Count(), 'Maximum take includes all groups.');
    end;

    /// <summary>Every filter is applied and service items are excluded as in report 1001.</summary>
    [Test]
    procedure Scenario_AC01_FiltersAndItemType()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateItem(Item);
        CreateItem(OtherItem);
        OtherItem.Type := OtherItem.Type::Service;
        OtherItem.Modify();
        SeedEntry(Item."No.", 'XLOC', 'XVAR', 20260101D, 2, 20, 0);
        SeedEntry(Item."No.", 'XOTHER', 'XVAR', 20260101D, 7, 70, 0);
        SeedEntry(Item."No.", 'XLOC', 'XOTHER', 20260101D, 8, 80, 0);
        SeedEntry(OtherItem."No.", 'XLOC', 'XVAR', 20260101D, 9, 90, 0);
        Request := RequestFor(Item."No." + '|' + OtherItem."No.", '2026-01-01');
        Request.Add('locationFilter', 'XLOC');
        Request.Add('variantFilter', 'XVAR');
        Request.Add('inventoryPostingGroupFilter', 'XVAL');
        Response := Read(Request);
        AssertNumber(Response, 'totalCount', 1);
        AssertNumber(RowAt(Response, 0), 'quantity', 2);
        Request.Replace('inventoryPostingGroupFilter', 'XMISSING');
        Response := Read(Request);
        Response.Get('rows', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Posting-group mismatch is empty.');
    end;

    /// <summary>Future entries do not create historical groups; zero balances with entries remain visible.</summary>
    [Test]
    procedure Scenario_AC04_EmptyAndZeroBalance()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateItem(Item);
        SeedEntry(Item."No.", '', '', 20260102D, 1, 10, 0);
        SeedEntry(Item."No.", '', '', 20260102D, -1, -10, 0);
        Request := RequestFor(Item."No.", '2026-01-01');
        Response := Read(Request);
        Response.Get('rows', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Future entries are excluded.');
        Request.Replace('asOfDate', '2026-01-02');
        Response := Read(Request);
        AssertNumber(Response, 'totalCount', 1);
        AssertNumber(RowAt(Response, 0), 'quantity', 0);
        AssertNumber(RowAt(Response, 0), 'totalCost', 0);
        Request.Replace('asOfDate', '9999-12-31');
        AssertNumber(Read(Request), 'totalCount', 1);
        Request.Replace('asOfDate', '0001-01-01');
        AssertNumber(Read(Request), 'totalCount', 0);
    end;

    /// <summary>Missing and malformed dates, filter types and paging values return coded next steps in both locales.</summary>
    [Test]
    procedure Scenario_AC04_InvalidInputsBothLocales()
    var
        OriginalLanguage: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        CheckInvalidInputs();
        GlobalLanguage(1039);
        CheckInvalidInputs();
        GlobalLanguage(OriginalLanguage);
    end;

    /// <summary>All help text is translated, the effect is read and the name has three parts.</summary>
    [Test]
    procedure Scenario_AC05_LocalizedReadContract()
    var
        Contract: Interface "Msg Contract ori";
        Discovery: Interface "Msg Discovery ori";
        Effect: JsonObject;
        Response: JsonObject;
        Parameters: JsonArray;
        Errors: JsonArray;
        OriginalLanguage: Integer;
        EnglishText: Text;
        IcelandicText: Text;
        Names: List of [Text];
    begin
        Contract := "Message Type ori"::"Inventory.Valuation.Get";
        Discovery := "Message Type ori"::"Inventory.Valuation.Get";
        EnglishText := 'Inventory.Valuation.Get';
        Names := EnglishText.Split('.');
        Assert.AreEqual(3, Names.Count(), 'Exactly three name parts.');
        Contract.GetEffect(Effect);
        AssertText(Effect, 'effect', 'read');
        Contract.GetResponse(Response);
        Assert.IsTrue(Response.Contains('fields'), 'Response has documented fields.');
        Contract.GetParameters(Parameters);
        Assert.AreEqual(7, Parameters.Count(), 'Every request parameter is documented.');
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Contract.GetNotes(EnglishText);
        Contract.GetErrors(Errors);
        Assert.IsTrue(Errors.Count() >= 5, 'Every refusal class is documented.');
        GlobalLanguage(1039);
        Contract.GetNotes(IcelandicText);
        Assert.AreNotEqual(EnglishText, IcelandicText, 'Icelandic notes differ.');
        Assert.AreNotEqual('', Discovery.GetSelectionDescription(), 'Translated discovery is available.');
        GlobalLanguage(OriginalLanguage);
    end;

    /// <summary>Disabling Costing yields a typed refusal with an actionable next step.</summary>
    [Test]
    procedure Scenario_AC04_DisabledDomain()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Costing := false;
        Setup.Modify();
        InitArgument(TempArgument);
        Request.Add('asOfDate', '2026-01-01');
        TempArgument.SetRequestJson(Request);
        Valuation.ReadValuation(TempArgument);
        AssertRefusal(TempArgument.GetResponseJson(), 'InvalidParameter');
        Assert.IsFalse(Valuation.IsEnabled(), 'Disabled Costing hides the message.');
    end;

    /// <summary>A real read-only caller can read totals but cannot modify native inventory data.</summary>
    [Test]
    procedure Scenario_AC03_ReadOnlyPermissions()
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
    begin
        CreateItem(Item);
        SeedEntry(Item."No.", '', '', 20260101D, 2, 20, 0);
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Costing := true;
        Setup.Modify();
        InitArgument(TempArgument);
        Request := RequestFor(Item."No.", '2026-01-01');
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Item.WritePermission() or ValueEntry.WritePermission(), 'Native writes are not granted.');
        Assert.IsTrue(Valuation.IsEnabled(), 'Read-only caller can discover valuation.');
        Valuation.ReadValuation(TempArgument);
        AssertNumber(RowAt(TempArgument.GetResponseJson(), 0), 'totalCost', 20);
    end;

    /// <summary>A caller lacking native reads gets a coded refusal and cannot discover the message.</summary>
    [Test]
    procedure Scenario_AC04_DeniedPermissions()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Costing := true;
        Setup.Modify();
        InitArgument(TempArgument);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsFalse(Valuation.IsEnabled(), 'No native reads means no discovery.');
        Valuation.ReadValuation(TempArgument);
        AssertRefusal(TempArgument.GetResponseJson(), 'PermissionDenied');
    end;

    local procedure CheckInvalidInputs()
    begin
        Refuses('{}', 'MissingParameter');
        Refuses('{"asOfDate":"not-a-date"}', 'InvalidParameterFormat');
        Refuses('{"asOfDate":"2026-02-30"}', 'InvalidParameterFormat');
        Refuses('{"asOfDate":"2026-01-01","take":0}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","take":1001}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","take":1.5}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","take":"1"}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","skip":-1}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","skip":2147483648}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","skip":null}', 'InvalidParameter');
        Refuses('{"asOfDate":"2026-01-01","itemFilter":{}}', 'InvalidParameterFormat');
        Refuses('{"asOfDate":"2026-01-01","locationFilter":true}', 'InvalidParameterFormat');
        Refuses('{"asOfDate":"2026-01-01","variantFilter":[]}', 'InvalidParameterFormat');
        Refuses('{"asOfDate":"2026-01-01","inventoryPostingGroupFilter":42}', 'InvalidParameterFormat');
        Refuses('{"asOfDate":"2026-01-01","itemFilter":"("}', 'BusinessCentralError');
    end;

    local procedure Refuses(RequestText: Text; ExpectedCode: Text)
    var
        Request: JsonObject;
    begin
        Request.ReadFrom(RequestText);
        AssertRefusal(Read(Request), ExpectedCode);
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    var
        Token: JsonToken;
    begin
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', ExpectedCode);
        Assert.IsTrue(Response.Get('nextStep', Token), 'Refusal includes nextStep.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Next step is actionable.');
    end;

    local procedure CreateItem(var Item: Record Item)
    begin
        Item.Init();
        Item."No." := CopyStr('XVAL' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Item.Type := Item.Type::Inventory;
        Item."Inventory Posting Group" := 'XVAL';
        Item.Insert();
    end;

    local procedure SeedEntry(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; PostingDate: Date; Quantity: Decimal; ActualCost: Decimal; ExpectedCost: Decimal)
    var
        ValueEntry: Record "Value Entry";
        NextNo: Integer;
    begin
        NextNo := 0;
        ValueEntry.LockTable();
        if ValueEntry.FindLast() then
            NextNo := ValueEntry."Entry No.";
        ValueEntry.Init();
        ValueEntry."Entry No." := NextNo + 1;
        ValueEntry."Item No." := ItemNo;
        ValueEntry."Location Code" := LocationCode;
        ValueEntry."Variant Code" := VariantCode;
        ValueEntry."Posting Date" := PostingDate;
        ValueEntry."Valuation Date" := 20251201D;
        ValueEntry."Item Ledger Entry Quantity" := Quantity;
        ValueEntry."Cost Amount (Actual)" := ActualCost;
        ValueEntry."Cost Amount (Expected)" := ExpectedCost;
        ValueEntry.Insert();
    end;

    local procedure RequestFor(ItemFilter: Text; DateText: Text) Request: JsonObject
    begin
        Request.Add('asOfDate', DateText);
        Request.Add('itemFilter', ItemFilter);
    end;

    local procedure Read(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Costing := true;
        Setup.Modify();
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        Valuation.ReadValuation(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary)
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
    end;

    local procedure RowAt(Response: JsonObject; Index: Integer): JsonObject
    var
        Token: JsonToken;
        Row: JsonToken;
    begin
        AssertText(Response, 'status', 'Success');
        Response.Get('rows', Token);
        Token.AsArray().Get(Index, Row);
        exit(Row.AsObject());
    end;

    local procedure AssertNumber(Response: JsonObject; Name: Text; Expected: Decimal)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Response includes ' + Name);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), Name);
    end;

    local procedure AssertText(Response: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Response includes ' + Name);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Name);
    end;
}
