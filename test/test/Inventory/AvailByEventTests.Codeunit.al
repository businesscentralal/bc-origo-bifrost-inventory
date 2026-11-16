namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 104: event availability contracts, arithmetic, filters and refusals.</summary>
codeunit 96990 "Avail. By Event Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";

    /// <summary>AC01 SupplyAndDemand ReturnSignedTimeline.</summary>
    [Test]
    procedure Scenario_AC01_SupplyAndDemand_ReturnSignedTimeline()
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Response: JsonObject;
        Events: JsonArray;
    begin
        // Story #104, AC01 | Time: fixed dates, WorkDate ignored | Risk: None
        // [GIVEN] An isolated item with supply of 10 and demand of 4.
        Initialize();
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchaseDocumentWithItem(PurchaseHeader, PurchaseLine, PurchaseHeader."Document Type"::Order, '', Item."No.", 10, '', 20261110D);
        LibrarySales.CreateSalesDocumentWithItem(SalesHeader, SalesLine, SalesHeader."Document Type"::Order, '', Item."No.", 4, '', 20261111D);
        // [WHEN] The public dispatcher reads both dates inclusively.
        Response := Execute(Request(Item."No.", 20261110D, 20261111D));
        // [THEN] Each source document and its signed quantity are returned.
        Events := EventArray(Response);
        Assert.AreEqual(2, Events.Count(), 'One supply and one demand event.');
        AssertEvent(Events, 0, 20261110D, PurchaseHeader."No.", 10, 10);
        AssertEvent(Events, 1, 20261111D, SalesHeader."No.", -4, 6);
        AssertStandardProjection(Item, Events);
    end;

    /// <summary>AC01 EarlierSupply ContributesToOpeningBalance.</summary>
    [Test]
    procedure Scenario_AC01_EarlierSupply_ContributesToOpeningBalance()
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Response: JsonObject;
        Events: JsonArray;
    begin
        // Story #104, AC01 | Time: fixed dates, WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] Supply outside the output range precedes demand inside it.
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchaseDocumentWithItem(PurchaseHeader, PurchaseLine, PurchaseHeader."Document Type"::Order, '', Item."No.", 10, '', 20261109D);
        LibrarySales.CreateSalesDocumentWithItem(SalesHeader, SalesLine, SalesHeader."Document Type"::Order, '', Item."No.", 4, '', 20261110D);
        // [WHEN] Reading a single date.
        Response := Execute(Request(Item."No.", 20261110D, 20261110D));
        // [THEN] Earlier supply affects the balance but is not emitted.
        AssertDecimal(Response, 'openingInventory', 10);
        Events := EventArray(Response);
        Assert.AreEqual(1, Events.Count(), 'Only the demand is in range.');
        AssertEvent(Events, 0, 20261110D, SalesHeader."No.", -4, 6);
    end;

    /// <summary>AC01 ExactVariantAndLocation ExcludeOtherEvents.</summary>
    [Test]
    procedure Scenario_AC01_ExactVariantAndLocation_ExcludeOtherEvents()
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        OtherHeader: Record "Purchase Header";
        OtherLine: Record "Purchase Line";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Payload: JsonObject;
        Events: JsonArray;
    begin
        // Story #104, AC01 | Time: fixed dates, WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] One selected variant/location and one unselected supply line.
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemVariant(Variant, Item."No.");
        LibraryWarehouse.CreateLocation(Location);
        LibraryPurchase.CreatePurchaseDocumentWithItem(PurchaseHeader, PurchaseLine, PurchaseHeader."Document Type"::Order, '', Item."No.", 8, Location.Code, 20261110D);
        PurchaseLine.Validate("Variant Code", Variant.Code);
        PurchaseLine.Modify(true);
        LibraryPurchase.CreatePurchaseDocumentWithItem(OtherHeader, OtherLine, OtherHeader."Document Type"::Order, '', Item."No.", 5, '', 20261110D);
        Payload := Request(Item."No.", 20261110D, 20261110D);
        Payload.Add('variant', Variant.Code);
        Payload.Add('location', Location.Code);
        // [WHEN] Both exact codes are sent.
        Events := EventArray(Execute(Payload));
        // [THEN] Only the selected source is included.
        Assert.AreEqual(1, Events.Count(), 'Filters exclude the other source.');
        AssertEvent(Events, 0, 20261110D, PurchaseHeader."No.", 8, 8);
    end;

    /// <summary>AC02 UnknownItem ReturnsRecordNotFound.</summary>
    [Test]
    procedure Scenario_AC02_UnknownItem_ReturnsRecordNotFound()
    begin
        // Story #104, AC02 | Time: fixed dates | Risk: None
        Initialize();
        AssertRefusal(Execute(Request(CopyStr(Format(CreateGuid(), 0, 4), 1, 20), 20261110D, 20261110D)), 'RecordNotFound');
    end;

    /// <summary>AC03 RepeatedReads PreserveSupplyAndDemand.</summary>
    [Test]
    procedure Scenario_AC03_RepeatedReads_PreserveSupplyAndDemand()
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        BeforeLine: Record "Purchase Line";
        FirstResponse: JsonObject;
        SecondResponse: JsonObject;
        FirstText: Text;
        SecondText: Text;
    begin
        // Story #104, AC03 | Time: fixed dates | Risk: None
        Initialize();
        // [GIVEN] A source line and its exact persisted state.
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchaseDocumentWithItem(PurchaseHeader, PurchaseLine, PurchaseHeader."Document Type"::Order, '', Item."No.", 10, '', 20261110D);
        BeforeLine := PurchaseLine;
        // [WHEN] Reading twice.
        FirstResponse := Execute(Request(Item."No.", 20261110D, 20261110D));
        SecondResponse := Execute(Request(Item."No.", 20261110D, 20261110D));
        // [THEN] Output and source values are unchanged.
        FirstResponse.WriteTo(FirstText);
        SecondResponse.WriteTo(SecondText);
        Assert.AreEqual(FirstText, SecondText, 'Read is repeatable.');
        PurchaseLine.Get(BeforeLine."Document Type", BeforeLine."Document No.", BeforeLine."Line No.");
        Assert.AreEqual(BeforeLine.SystemModifiedAt, PurchaseLine.SystemModifiedAt, 'Source line was not modified.');
        Assert.AreEqual(BeforeLine."Outstanding Qty. (Base)", PurchaseLine."Outstanding Qty. (Base)", 'Outstanding quantity is unchanged.');
    end;

    /// <summary>AC04 NoEvents ReturnsEmptyArray.</summary>
    [Test]
    procedure Scenario_AC04_NoEvents_ReturnsEmptyArray()
    var
        Item: Record Item;
        Response: JsonObject;
        Events: JsonArray;
    begin
        // Story #104, AC04 | Time: fixed dates | Risk: None
        Initialize();
        LibraryInventory.CreateItem(Item);
        Response := Execute(Request(Item."No.", 20261110D, 20261110D));
        Events := EventArray(Response);
        Assert.AreEqual(0, Events.Count(), 'No invented events.');
        AssertDecimal(Response, 'openingInventory', 0);
    end;

    /// <summary>AC04 ReversedDates ReturnsInvalidParameter.</summary>
    [Test]
    procedure Scenario_AC04_ReversedDates_ReturnsInvalidParameter()
    begin
        // Story #104, AC04 | Time: fixed dates | Risk: None
        Initialize();
        AssertRefusal(Execute(Request('ANY', 20261111D, 20261110D)), 'InvalidParameter');
    end;

    /// <summary>AC04 MissingItem ReturnsMissingParameter.</summary>
    [Test]
    procedure Scenario_AC04_MissingItem_ReturnsMissingParameter()
    var
        Payload: JsonObject;
    begin
        // Story #104, AC04 | Time: fixed dates | Risk: None
        Initialize();
        Payload := Request('ANY', 20261110D, 20261110D);
        Payload.Remove('itemNo');
        AssertRefusal(Execute(Payload), 'MissingParameter');
    end;

    /// <summary>AC04 InvalidTypesAndDates ReturnCodedRefusals.</summary>
    [Test]
    procedure Scenario_AC04_InvalidTypesAndDates_ReturnCodedRefusals()
    var
        Payload: JsonObject;
    begin
        // Story #104, AC04 | Time: strict ISO dates | Risk: None
        Initialize();
        Payload := Request('ANY', 20261110D, 20261110D);
        Payload.Replace('itemNo', 123);
        AssertRefusal(Execute(Payload), 'InvalidParameterFormat');
        Payload.Replace('itemNo', 'ANY');
        Payload.Replace('from', '2026-02-30');
        AssertRefusal(Execute(Payload), 'InvalidParameterFormat');
        Payload.Replace('from', '');
        AssertRefusal(Execute(Payload), 'MissingParameter');
        Payload.Replace('from', '0D');
        AssertRefusal(Execute(Payload), 'InvalidParameterFormat');
    end;

    /// <summary>AC04 UnknownKey ReturnsUnknownParameter.</summary>
    [Test]
    procedure Scenario_AC04_UnknownKey_ReturnsUnknownParameter()
    var
        Payload: JsonObject;
    begin
        // Story #104, AC04 | Time: fixed dates | Risk: None
        Initialize();
        Payload := Request('ANY', 20261110D, 20261110D);
        Payload.Add('warehouse', 'BLUE');
        AssertRefusal(Execute(Payload), 'UnknownParameter');
    end;

    /// <summary>AC04 UnknownVariantOrLocation ReturnsRecordNotFound.</summary>
    [Test]
    procedure Scenario_AC04_UnknownVariantOrLocation_ReturnsRecordNotFound()
    var
        Item: Record Item;
        Payload: JsonObject;
    begin
        // Story #104, AC04 | Time: fixed dates | Risk: None
        Initialize();
        LibraryInventory.CreateItem(Item);
        Payload := Request(Item."No.", 20261110D, 20261110D);
        Payload.Add('variant', 'NO-SUCH-VARIANT');
        AssertRefusal(Execute(Payload), 'RecordNotFound');
        Payload.Remove('variant');
        Payload.Add('location', 'NO-SUCH-LOCATION');
        AssertRefusal(Execute(Payload), 'RecordNotFound');
    end;

    /// <summary>AC04 NonInventoryItem ReturnsPreconditionFailed.</summary>
    [Test]
    procedure Scenario_AC04_NonInventoryItem_ReturnsPreconditionFailed()
    var
        Item: Record Item;
    begin
        // Story #104, AC04 | Time: fixed dates | Risk: None
        Initialize();
        LibraryInventory.CreateItem(Item);
        Item.Validate(Type, Item.Type::Service);
        Item.Modify(true);
        AssertRefusal(Execute(Request(Item."No.", 20261110D, 20261110D)), 'PreconditionFailed');
    end;

    /// <summary>AC04 BilingualHelpAndRefusals AreLocalized.</summary>
    [Test]
    procedure Scenario_AC04_BilingualHelpAndRefusals_AreLocalized()
    var
        Impl: Codeunit "Avail. By Event Impl ori";
        EnDescription: Text;
        EnOverview: Text;
        IsOverview: Text;
        EnResponse: JsonObject;
        IsResponse: JsonObject;
        OriginalLanguage: Integer;
    begin
        // Story #104, AC04 | Time: fixed dates; explicit LCIDs | Risk: None
        Initialize();
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnDescription := Impl.GetDescription();
        Impl.GetOverview(EnOverview);
        EnResponse := ExecuteDirect(Request('MISSING-104', 20261110D, 20261110D));
        GlobalLanguage(1039);
        Assert.AreNotEqual(EnDescription, Impl.GetDescription(), 'Catalogue text is translated.');
        Impl.GetOverview(IsOverview);
        Assert.AreNotEqual(EnOverview, IsOverview, 'Overview is translated.');
        IsResponse := ExecuteDirect(Request('MISSING-104', 20261110D, 20261110D));
        AssertRefusal(EnResponse, 'RecordNotFound');
        AssertRefusal(IsResponse, 'RecordNotFound');
        Assert.AreNotEqual(TextValue(EnResponse, 'nextStep'), TextValue(IsResponse, 'nextStep'), 'Recovery text is translated.');
        GlobalLanguage(OriginalLanguage);
    end;

    /// <summary>AC05 TypeNameAndEffect DeclareThreePartsAndRead.</summary>
    [Test]
    procedure Scenario_AC05_TypeNameAndEffect_DeclareThreePartsAndRead()
    var
        Impl: Codeunit "Avail. By Event Impl ori";
        Effect: JsonObject;
        Parts: List of [Text];
        TypeName: Text;
    begin
        // Story #104, AC05 and AC03 | Time: none | Risk: None
        Initialize();
        TypeName := 'Inventory.AvailabilityByEvent.Get';
        Parts := TypeName.Split('.');
        Assert.AreEqual(3, Parts.Count(), 'Three-part message name.');
        Assert.IsTrue(Impl.GetEffect(Effect), 'Effect is explicitly declared.');
        Assert.AreEqual('read', TextValue(Effect, 'effect'), 'Real effect is read.');
        Assert.AreEqual('false', TextValue(Effect, 'writes'), 'No business writes.');
    end;

    local procedure Initialize()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Library.Initialize();
        Setup.InsertIfNotExists();
        Setup.Availability := true;
        Setup.Modify(true);
    end;

    local procedure Request(ItemNo: Text; FromDate: Date; ToDate: Date) Payload: JsonObject
    begin
        Payload.Add('itemNo', ItemNo);
        Payload.Add('from', Format(FromDate, 0, 9));
        Payload.Add('to', Format(ToDate, 0, 9));
    end;

    local procedure Execute(Payload: JsonObject): JsonObject
    begin
        exit(Library.ExecuteType("Message Type ori"::"Inventory.AvailabilityByEvent.Get", '', Payload, false));
    end;

    local procedure ExecuteDirect(Payload: JsonObject) Response: JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Avail. By Event Impl ori";
    begin
        TempArgument.SetRequestJson(Payload);
        Impl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure EventArray(Response: JsonObject): JsonArray
    var
        Token: JsonToken;
    begin
        Library.AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.Get('events', Token), 'events is present.');
        exit(Token.AsArray());
    end;

    local procedure AssertEvent(Events: JsonArray; Index: Integer; EventDate: Date; DocumentNo: Code[20]; Quantity: Decimal; Projected: Decimal)
    var
        Token: JsonToken;
        EventJson: JsonObject;
    begin
        Events.Get(Index, Token);
        EventJson := Token.AsObject();
        Assert.AreEqual(Format(EventDate, 0, 9), TextValue(EventJson, 'date'), 'Event date.');
        Assert.AreEqual(DocumentNo, TextValue(EventJson, 'sourceDocument'), 'Source document.');
        Assert.AreNotEqual('', TextValue(EventJson, 'type'), 'Event type is present.');
        AssertDecimal(EventJson, 'quantity', Quantity);
        AssertDecimal(EventJson, 'projectedInventory', Projected);
    end;

    local procedure AssertStandardProjection(var Item: Record Item; Events: JsonArray)
    var
        TempPageData: Record "Inventory Page Data" temporary;
        CalcInventoryPageData: Codeunit "Calc. Inventory Page Data";
        RunningInventory: Decimal;
        RunningForecast: Decimal;
        RunningSuggestion: Decimal;
        Token: JsonToken;
        Index: Integer;
    begin
        Index := 0;
        CalcInventoryPageData.Initialize(Item, '', false, 0D, false);
        CalcInventoryPageData.CreatePeriodEntries(TempPageData, 0);
        TempPageData.SetCurrentKey("Period Start", "Line No.");
        TempPageData.SetRange(Level, 0);
        if TempPageData.FindSet() then
            repeat
                CalcInventoryPageData.DetailsForPeriodEntry(TempPageData, true);
                CalcInventoryPageData.DetailsForPeriodEntry(TempPageData, false);
            until TempPageData.Next() = 0;
        TempPageData.SetRange(Level, 1);
        if TempPageData.FindSet() then
            repeat
                TempPageData.UpdateInventorys(RunningInventory, RunningForecast, RunningSuggestion);
                Events.Get(Index, Token);
                AssertDecimal(Token.AsObject(), 'projectedInventory', TempPageData."Projected Inventory");
                Index += 1;
            until TempPageData.Next() = 0;
        Assert.AreEqual(Events.Count(), Index, 'All standard detail rows are returned.');
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual(ExpectedCode, TextValue(Response, 'code'), 'Bifrost error code.');
        Assert.AreNotEqual('', TextValue(Response, 'nextStep'), 'Actionable recovery is required.');
    end;

    local procedure TextValue(Object: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Object.Get(KeyName, Token), KeyName + ' is present.');
        exit(Token.AsValue().AsText());
    end;

    local procedure AssertDecimal(Object: JsonObject; KeyName: Text; Expected: Decimal)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Object.Get(KeyName, Token), KeyName + ' is present.');
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), KeyName);
    end;
}
