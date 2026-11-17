namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.PlanningWorksheet.Calculate and CarryOut. Native planning commits, so each test removes its own
/// XP117 fixtures and commits that cleanup.
/// </summary>
codeunit 96995 "Plan Wksh Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    EventSubscriberInstance = Manual;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        NativeFailure: Text;

    [Test]
    procedure Calculate_Regenerative_ThenCarryOut_CreatesPurchaseOrder()
    var
        Item: Record Item;
        PurchHeader: Record "Purchase Header";
        Request: JsonObject;
        Response: JsonObject;
        Orders: JsonArray;
        OrderToken: JsonToken;
        LineToken: JsonToken;
        ResponseText: Text;
        DocumentNo: Code[20];
    begin
        // [SCENARIO] Issue117 AC01 and AC02 | Time: a one-year horizon from the work date | Risk: creates and deletes one purchase order.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePurchaseItem(Item);
        CreatePlanningWorksheet();
        Request.Add('mode', 'regenerative');
        Request.Add('startingDate', IsoDate(HorizonStart()));
        Request.Add('endingDate', IsoDate(HorizonEnd()));
        Request.Add('itemNo', Item."No.");
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'XP117T|XP117W', Request, false);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', TextValue(Response, 'status'), ResponseText);
        Assert.AreEqual('regenerative', TextValue(Response, 'mode'), ResponseText);
        Assert.IsTrue(IntegerValue(Response, 'lineCount') >= 1, ResponseText);
        Assert.IsTrue(Response.Get('lines', LineToken), ResponseText);
        Assert.IsTrue(LineToken.AsArray().Count() >= 1, ResponseText);

        Clear(Request);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'XP117T|XP117W', Request, false);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', TextValue(Response, 'status'), ResponseText);
        Assert.IsTrue(IntegerValue(Response, 'linesConsumed') >= 1, ResponseText);
        Assert.IsTrue(Response.Get('orders', OrderToken), ResponseText);
        Orders := OrderToken.AsArray();
        Assert.IsTrue(Orders.Count() >= 1, ResponseText);
        Orders.Get(0, OrderToken);
        Assert.AreEqual('Purchase', TextValue(OrderToken.AsObject(), 'documentType'), ResponseText);
        DocumentNo := CopyStr(TextValue(OrderToken.AsObject(), 'documentNo'), 1, MaxStrLen(DocumentNo));
        Assert.IsTrue(PurchHeader.Get(PurchHeader."Document Type"::Order, DocumentNo), ResponseText);

        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Scenario_AC01_Calculate_PreservesOtherWorksheet()
    var
        Item: Record Item;
        OtherLine: Record "Requisition Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #117 AC01 | Time: one-year work-date horizon | Risk: owned worksheets only.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePurchaseItem(Item);
        CreatePlanningWorksheet();
        CreateWorksheet('XP117OTHER', Enum::"Req. Worksheet Template Type"::Planning);
        OtherLine.Init();
        OtherLine."Worksheet Template Name" := 'XP117OTHER';
        OtherLine."Journal Batch Name" := 'XP117W';
        OtherLine."Line No." := 10000;
        OtherLine.Type := OtherLine.Type::Item;
        OtherLine."No." := Item."No.";
        OtherLine.Quantity := 7;
        OtherLine."Due Date" := HorizonStart();
        OtherLine."Action Message" := OtherLine."Action Message"::New;
        OtherLine.Insert(false);
        Commit();
        Request.Add('mode', 'regenerative');
        Request.Add('startingDate', IsoDate(HorizonStart()));
        Request.Add('endingDate', IsoDate(HorizonEnd()));
        Request.Add('itemNo', Item."No.");
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'XP117T|XP117W', Request, false);
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Calculation succeeds.');
        Assert.IsTrue(IntegerValue(Response, 'lineCount') > 0, 'Selected worksheet receives suggestions.');
        Assert.IsTrue(OtherLine.Get('XP117OTHER', 'XP117W', 10000), 'Other worksheet line survives native calculation.');
        Assert.AreEqual(7, OtherLine.Quantity, 'Other worksheet quantity is unchanged.');
        Assert.AreEqual(Item."No.", OtherLine."No.", 'Other worksheet still names the same item.');
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Scenario_AC02_CarryOut_CreatesTransferOrder()
    var
        Item: Record Item;
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Route: Record "Transfer Route";
        ReqLine: Record "Requisition Line";
        Header: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        Warehouse: Codeunit "Library - Warehouse";
        Observer: Codeunit "Plan Wksh Tests ori";
        Response: JsonObject;
        Request: JsonObject;
    begin
        // Issue #117 AC02 | Time: work date | Risk: owned unposted transfer only.
        BindSubscription(Observer);
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePurchaseItem(Item);
        CreatePlanningWorksheet();
        Warehouse.CreateLocationWMS(FromLocation, false, false, false, false, false);
        Warehouse.CreateLocationWMS(ToLocation, false, false, false, false, false);
        FromLocation.Name := 'XP117 transfer source';
        FromLocation.Modify();
        ToLocation.Name := 'XP117 transfer destination';
        ToLocation.Modify();
        Warehouse.CreateInTransitLocation(InTransitLocation);
        InTransitLocation.Name := 'XP117 transfer in transit';
        InTransitLocation.Modify();
        Warehouse.CreateTransferRoute(Route, FromLocation.Code, ToLocation.Code);
        Route.Validate("In-Transit Code", InTransitLocation.Code);
        Route.Modify(true);
        CreateNewSuggestion(ReqLine, Item);
        ReqLine.Validate("Location Code", ToLocation.Code);
        ReqLine.Validate("Replenishment System", ReqLine."Replenishment System"::Transfer);
        ReqLine."Ref. Order Type" := ReqLine."Ref. Order Type"::Transfer;
        ReqLine.Validate("Transfer-from Code", FromLocation.Code);
        ReqLine."Transfer Shipment Date" := HorizonStart();
        ReqLine.Modify(true);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'XP117T|XP117W', Request, false);
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Native transfer carry-out succeeds: ' + TextValue(Response, 'error') + ' ' + Observer.GetNativeFailure());
        Assert.AreEqual(1, IntegerValue(Response, 'linesConsumed'), 'One suggestion is consumed.');
        Header.Get(CreatedOrderNo(Response, 'Transfer'));
        Assert.AreEqual(FromLocation.Code, Header."Transfer-from Code", 'Native source location.');
        Assert.AreEqual(ToLocation.Code, Header."Transfer-to Code", 'Native destination location.');
        TransferLine.SetRange("Document No.", Header."No.");
        Assert.IsTrue(TransferLine.FindFirst(), 'Native transfer line exists.');
        Assert.AreEqual(Item."No.", TransferLine."Item No.", 'Transfer carries the requested item.');
        Assert.AreEqual(2, TransferLine.Quantity, 'Transfer carries the requested quantity.');
        Header.Delete(true);
        Route.Delete(true);
        InTransitLocation.Delete(true);
        FromLocation.Delete(true);
        ToLocation.Delete(true);
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Scenario_AC02_CarryOut_CreatesAssemblyOrder()
    var
        Item: Record Item;
        Component: Record Item;
        ReqLine: Record "Requisition Line";
        Header: Record "Assembly Header";
        PlanningError: Record "Planning Error Log";
        Helper: Codeunit "Assembly Order Test Helper";
        FailureDetail: Text;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Issue #117 AC02 | Time: work date | Risk: owned unposted assembly only.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        Helper.CreateAssemblyItemWithBOM(Item, Component);
        Item.Description := 'XP117 assembly';
        Item.Modify();
        Component.Description := 'XP117 component';
        Component.Modify();
        CreatePlanningWorksheet();
        CreateNewSuggestion(ReqLine, Item);
        ReqLine.Validate("Replenishment System", ReqLine."Replenishment System"::Assembly);
        ReqLine."Ref. Order Type" := ReqLine."Ref. Order Type"::Assembly;
        ReqLine.Modify(true);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'XP117T|XP117W', Request, false);
        if PlanningError.FindLast() then
            FailureDetail := PlanningError."Error Description";
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Native assembly carry-out succeeds: ' + TextValue(Response, 'error') + ' ' + FailureDetail);
        Assert.AreEqual(1, IntegerValue(Response, 'linesConsumed'), 'One suggestion is consumed.');
        Header.Get(Header."Document Type"::Order, CreatedOrderNo(Response, 'Assembly'));
        Assert.AreEqual(Item."No.", Header."Item No.", 'Native assembly uses the requested item.');
        Assert.AreEqual(2, Header.Quantity, 'Native assembly quantity.');
        Header.Delete(true);
        CleanupFixtures();
        Commit();
    end;

    /// <summary>Returns the native failure captured for this test worksheet.</summary>
    procedure GetNativeFailure(): Text
    begin
        exit(NativeFailure);
    end;

    [EventSubscriber(ObjectType::Report, Report::"Carry Out Action Msg. - Plan.", OnCarryOutActionsOnAfterUpdateCounterFailed, '', false, false)]
    local procedure RecordNativeFailure(var RequisitionLine: Record "Requisition Line"; WkshTempl: Code[10]; WkshName: Code[10])
    begin
        if RequisitionLine."Worksheet Template Name" = 'XP117T' then
            NativeFailure := GetLastErrorText();
    end;

    local procedure CreateNewSuggestion(var ReqLine: Record "Requisition Line"; Item: Record Item)
    begin
        ReqLine.Init();
        ReqLine."Worksheet Template Name" := 'XP117T';
        ReqLine."Journal Batch Name" := 'XP117W';
        ReqLine."Line No." := 10000;
        ReqLine.Insert(true);
        ReqLine.Validate(Type, ReqLine.Type::Item);
        ReqLine.Validate("No.", Item."No.");
        ReqLine.Validate(Quantity, 2);
        ReqLine.Validate("Due Date", HorizonStart());
        ReqLine."Starting Date" := HorizonStart();
        ReqLine."Ending Date" := HorizonStart();
        ReqLine."Action Message" := ReqLine."Action Message"::New;
        ReqLine."Accept Action Message" := true;
        ReqLine.Modify(true);
    end;

    local procedure CreatedOrderNo(Response: JsonObject; ExpectedType: Text): Code[20]
    var
        Orders: JsonToken;
        Order: JsonToken;
    begin
        Assert.IsTrue(Response.Get('orders', Orders), 'Created order list exists.');
        Assert.AreEqual(1, Orders.AsArray().Count(), 'Exactly one new order.');
        Orders.AsArray().Get(0, Order);
        Assert.AreEqual(ExpectedType, TextValue(Order.AsObject(), 'documentType'), 'Native document type.');
        exit(CopyStr(TextValue(Order.AsObject(), 'documentNo'), 1, 20));
    end;

    /// <summary>Creates a fresh owned worksheet and purchase item for explicit MCP verification.</summary>
    procedure SeedMcpFixtures(): Text
    var
        Item: Record Item;
        Worksheet: Record "Requisition Wksh. Name";
    begin
        Assert.IsFalse(Worksheet.Get('XP117T', 'XP117W'), 'Clean the existing owned worksheet before seeding.');
        EnablePlanning();
        CreatePurchaseItem(Item);
        CreatePlanningWorksheet();
        Commit();
        exit(Item."No." + '|' + IsoDate(HorizonStart()) + '|' + IsoDate(HorizonEnd()));
    end;

    /// <summary>Removes only this codeunit's owned planning fixtures and created orders after MCP verification.</summary>
    procedure CleanupMcpFixtures()
    begin
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Calculate_NetChangeWithoutAssignment_ReturnsNoLines()
    var
        Item: Record Item;
        PlanningAssignment: Record "Planning Assignment";
        Request: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        // [SCENARIO] Issue117 edge | Time: a one-year horizon | Risk: the calculation commits and leaves no lines.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePurchaseItem(Item);
        PlanningAssignment.SetRange("Item No.", Item."No.");
        if not PlanningAssignment.IsEmpty() then
            PlanningAssignment.DeleteAll(false);
        CreatePlanningWorksheet();
        Request.Add('mode', 'netChange');
        Request.Add('startingDate', IsoDate(HorizonStart()));
        Request.Add('endingDate', IsoDate(HorizonEnd()));
        Request.Add('itemNo', Item."No.");
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'XP117T|XP117W', Request, false);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', TextValue(Response, 'status'), ResponseText);
        Assert.AreEqual('netChange', TextValue(Response, 'mode'), ResponseText);
        Assert.AreEqual(0, IntegerValue(Response, 'lineCount'), ResponseText);
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Calculate_InvalidMode_InvalidParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue117 invalid input | Time: dates are present so the refusal is the mode | Risk: no worksheet write.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePlanningWorksheet();
        Request.Add('mode', 'weekly');
        Request.Add('startingDate', IsoDate(HorizonStart()));
        Request.Add('endingDate', IsoDate(HorizonEnd()));
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'XP117T|XP117W', Request, false);
        AssertRefusal(Response, 'InvalidParameter');
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Calculate_EndingBeforeStart_InvalidParameter()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue117 invalid input | Time: ending date is the day before the start | Risk: refused before calculation.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePlanningWorksheet();
        Request.Add('mode', 'regenerative');
        Request.Add('startingDate', IsoDate(HorizonEnd()));
        Request.Add('endingDate', IsoDate(HorizonStart()));
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'XP117T|XP117W', Request, false);
        AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('endingDate', TextValue(Response, 'parameter'), 'endingDate');
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Calculate_UnknownWorksheet_RecordNotFound_BothLanguages()
    var
        Request: JsonObject;
        Response: JsonObject;
        EnglishNext: Text;
        IcelandicNext: Text;
    begin
        // [SCENARIO] Issue117 AC03 and AC04 | Time: none | Risk: no worksheet is created.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        Request.Add('mode', 'regenerative');
        Request.Add('startingDate', IsoDate(HorizonStart()));
        Request.Add('endingDate', IsoDate(HorizonEnd()));
        // Dispatcher.Execute forces the company default language. Pass the Windows language id
        // through EnqueueAndProcess so the refusal is built in 1033 and then in 1039.
        Response := DispatchInLanguage("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'NOSUCH|NAME', Request, 1033);
        Assert.AreEqual('RecordNotFound', TextValue(Response, 'code'), 'English code');
        EnglishNext := TextValue(Response, 'nextStep');
        Assert.AreNotEqual('', EnglishNext, 'English nextStep');
        Response := DispatchInLanguage("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'NOSUCH|NAME', Request, 1039);
        Assert.AreEqual('RecordNotFound', TextValue(Response, 'code'), 'Icelandic code');
        IcelandicNext := TextValue(Response, 'nextStep');
        Assert.AreNotEqual('', IcelandicNext, 'Icelandic nextStep');
        Assert.AreNotEqual(EnglishNext, IcelandicNext, 'Icelandic nextStep is translated.');
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure Calculate_RequisitionTemplate_RecordNotFound()
    var
        Item: Record Item;
        ReqLine: Record "Requisition Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue117 | Time: none | Risk: a requisition worksheet line is not calculated or deleted.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePurchaseItem(Item);
        CreateRequisitionWorksheet();
        ReqLine.Init();
        ReqLine."Worksheet Template Name" := 'XP117R';
        ReqLine."Journal Batch Name" := 'XP117W';
        ReqLine."Line No." := 10000;
        ReqLine.Type := ReqLine.Type::Item;
        ReqLine."No." := Item."No.";
        ReqLine.Quantity := 1;
        ReqLine.Insert(false);
        Commit();
        Request.Add('mode', 'regenerative');
        Request.Add('startingDate', IsoDate(HorizonStart()));
        Request.Add('endingDate', IsoDate(HorizonEnd()));
        Request.Add('itemNo', Item."No.");
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.Calculate", 'XP117R|XP117W', Request, false);
        AssertRefusal(Response, 'RecordNotFound');
        Assert.IsTrue(ReqLine.Get('XP117R', 'XP117W', 10000), 'The requisition line stays.');
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure CarryOut_CancelLine_RefusesBeforeWrite()
    var
        Item: Record Item;
        ReqLine: Record "Requisition Line";
        PurchLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue117 | Time: none | Risk: an accepted Cancel line must not create or delete a document.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        CreatePurchaseItem(Item);
        CreatePlanningWorksheet();
        ReqLine.Init();
        ReqLine."Worksheet Template Name" := 'XP117T';
        ReqLine."Journal Batch Name" := 'XP117W';
        ReqLine."Line No." := 10000;
        ReqLine.Type := ReqLine.Type::Item;
        ReqLine."No." := Item."No.";
        ReqLine.Quantity := 1;
        ReqLine."Action Message" := ReqLine."Action Message"::Cancel;
        ReqLine."Accept Action Message" := true;
        ReqLine."Replenishment System" := ReqLine."Replenishment System"::Purchase;
        ReqLine."Ref. Order Type" := ReqLine."Ref. Order Type"::Purchase;
        ReqLine."Ref. Order No." := 'XP117EXIST';
        ReqLine.Insert(false);
        Commit();
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'XP117T|XP117W', Request, false);
        AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(ReqLine.Get('XP117T', 'XP117W', 10000), 'The cancel line stays.');
        PurchLine.SetRange(Type, PurchLine.Type::Item);
        PurchLine.SetRange("No.", Item."No.");
        Assert.IsTrue(PurchLine.IsEmpty(), 'No purchase line was created.');
        CleanupFixtures();
        Commit();
    end;

    [Test]
    procedure CarryOut_UnknownWorksheet_RecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [SCENARIO] Issue117 AC03 | Time: none | Risk: no document is created.
        CleanupFixtures();
        Commit();
        EnablePlanning();
        Response := Library.ExecuteType("Message Type ori"::"Inventory.PlanningWorksheet.CarryOut", 'NOSUCH|NAME', Request, false);
        AssertRefusal(Response, 'RecordNotFound');
        CleanupFixtures();
        Commit();
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    var
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Error', TextValue(Response, 'status'), ResponseText);
        Assert.AreEqual(ExpectedCode, TextValue(Response, 'code'), ResponseText);
        Assert.AreNotEqual('', TextValue(Response, 'nextStep'), ResponseText);
    end;

    local procedure EnablePlanning()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        if Setup.Planning then
            exit;
        Setup.Planning := true;
        Setup.Modify(true);
    end;

    local procedure CreatePurchaseItem(var Item: Record Item)
    var
        Vendor: Record Vendor;
    begin
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Validate(Name, CopyStr('XP117 ' + Vendor."No.", 1, MaxStrLen(Vendor.Name)));
        Vendor.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate(Description, CopyStr('XP117 ' + Item."No.", 1, MaxStrLen(Item.Description)));
        Item.Validate("Replenishment System", Item."Replenishment System"::Purchase);
        Item.Validate("Vendor No.", Vendor."No.");
        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Fixed Reorder Qty.");
        Item.Validate("Reorder Point", 10);
        Item.Validate("Reorder Quantity", 25);
        Item.Modify(true);
    end;

    local procedure CreatePlanningWorksheet()
    begin
        CreateWorksheet('XP117T', Enum::"Req. Worksheet Template Type"::Planning);
    end;

    local procedure CreateRequisitionWorksheet()
    begin
        CreateWorksheet('XP117R', Enum::"Req. Worksheet Template Type"::"Req.");
    end;

    local procedure CreateWorksheet(TemplateName: Code[10]; TemplateType: Enum "Req. Worksheet Template Type")
    var
        WkshTemplate: Record "Req. Wksh. Template";
        Worksheet: Record "Requisition Wksh. Name";
    begin
        if not WkshTemplate.Get(TemplateName) then begin
            WkshTemplate.Init();
            WkshTemplate.Name := TemplateName;
            WkshTemplate.Validate(Type, TemplateType);
            WkshTemplate.Recurring := false;
            WkshTemplate.Description := 'XP117';
            WkshTemplate.Insert(true);
        end;
        if Worksheet.Get(TemplateName, 'XP117W') then
            exit;
        Worksheet.Init();
        Worksheet."Worksheet Template Name" := TemplateName;
        Worksheet.Name := 'XP117W';
        Worksheet.Description := 'XP117';
        Worksheet.Insert(true);
    end;

    local procedure CleanupFixtures()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        AssemblyHeader: Record "Assembly Header";
        BOMComponent: Record "BOM Component";
        Location: Record Location;
        Route: Record "Transfer Route";
        ReqLine: Record "Requisition Line";
        Worksheet: Record "Requisition Wksh. Name";
        WkshTemplate: Record "Req. Wksh. Template";
        ItemNos: List of [Code[20]];
        DocumentNos: List of [Code[20]];
        ItemNo: Code[20];
        DocumentNo: Code[20];
    begin
        Item.SetFilter(Description, 'XP117*');
        if Item.FindSet() then
            repeat
                ItemNos.Add(Item."No.");
            until Item.Next() = 0;
        foreach ItemNo in ItemNos do begin
            TransferLine.Reset();
            TransferLine.SetRange("Item No.", ItemNo);
            while TransferLine.FindFirst() do begin
                TransferHeader.Get(TransferLine."Document No.");
                TransferHeader.Delete(true);
            end;
            AssemblyHeader.Reset();
            AssemblyHeader.SetRange("Document Type", AssemblyHeader."Document Type"::Order);
            AssemblyHeader.SetRange("Item No.", ItemNo);
            while AssemblyHeader.FindFirst() do
                AssemblyHeader.Delete(true);
            PurchLine.Reset();
            PurchLine.SetRange(Type, PurchLine.Type::Item);
            PurchLine.SetRange("No.", ItemNo);
            if PurchLine.FindSet() then
                repeat
                    if not DocumentNos.Contains(PurchLine."Document No.") then
                        DocumentNos.Add(PurchLine."Document No.");
                until PurchLine.Next() = 0;
            ReqLine.Reset();
            ReqLine.SetRange(Type, ReqLine.Type::Item);
            ReqLine.SetRange("No.", ItemNo);
            if not ReqLine.IsEmpty() then
                ReqLine.DeleteAll(true);
        end;
        foreach DocumentNo in DocumentNos do
            if PurchHeader.Get(PurchHeader."Document Type"::Order, DocumentNo) then
                PurchHeader.Delete(true);
        ReqLine.Reset();
        ReqLine.SetFilter("Worksheet Template Name", 'XP117*');
        if not ReqLine.IsEmpty() then
            ReqLine.DeleteAll(true);
        foreach ItemNo in ItemNos do begin
            BOMComponent.SetRange("Parent Item No.", ItemNo);
            BOMComponent.DeleteAll(true);
        end;
        foreach ItemNo in ItemNos do
            if Item.Get(ItemNo) then
                Item.Delete(true);
        Location.SetFilter(Name, 'XP117 transfer*');
        if Location.FindSet() then
            repeat
                Route.SetRange("Transfer-from Code", Location.Code);
                Route.DeleteAll(true);
                Route.SetRange("Transfer-from Code");
                Route.SetRange("Transfer-to Code", Location.Code);
                Route.DeleteAll(true);
                Route.SetRange("Transfer-to Code");
            until Location.Next() = 0;
        while Location.FindFirst() do
            Location.Delete(true);
        Vendor.SetFilter(Name, 'XP117*');
        if Vendor.FindSet() then
            repeat
                Vendor.Delete(true);
            until Vendor.Next() = 0;
        if Worksheet.Get('XP117T', 'XP117W') then
            Worksheet.Delete(true);
        if Worksheet.Get('XP117R', 'XP117W') then
            Worksheet.Delete(true);
        if Worksheet.Get('XP117OTHER', 'XP117W') then
            Worksheet.Delete(true);
        if WkshTemplate.Get('XP117OTHER') then
            WkshTemplate.Delete(true);
        if WkshTemplate.Get('XP117T') then
            WkshTemplate.Delete(true);
        if WkshTemplate.Get('XP117R') then
            WkshTemplate.Delete(true);
    end;

    local procedure HorizonStart(): Date
    begin
        if WorkDate() = 0D then
            exit(Today());
        exit(WorkDate());
    end;

    local procedure HorizonEnd(): Date
    begin
        exit(CalcDate('<+1Y>', HorizonStart()));
    end;

    local procedure IsoDate(DateValue: Date): Text
    begin
        exit(Format(DateValue, 0, 9));
    end;

    local procedure DispatchInLanguage(MessageType: Enum "Message Type ori"; Subject: Text[250]; RequestJson: JsonObject; WindowsLanguageId: Integer) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageId: Guid;
        ResponseTime: Duration;
        EmptyTaskId: Guid;
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(
            MessageType,
            "Message Version ori"::"1.0",
            Subject,
            '',
            '',
            RequestContent,
            EmptyTaskId,
            WindowsLanguageId,
            MessageId,
            ResponseContent,
            ResponseContentType,
            ResponseTime);
        if ResponseContent.Length() > 0 then begin
            ResponseContent.GetSubText(ResponseText, 1);
            ResponseJson.ReadFrom(ResponseText);
        end;
    end;

    local procedure TextValue(Object: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure IntegerValue(Object: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) then
            exit(0);
        if not Token.IsValue() then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;
}
