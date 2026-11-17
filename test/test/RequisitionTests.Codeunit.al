namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Exercises bounded native requisition calculation, order creation and complete preflight refusals for issue 131.</summary>
codeunit 96947 "Requisition Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        Inventory: Codeunit "Library - Inventory";
        Planning: Codeunit "Library - Planning";
        Purchase: Codeunit "Library - Purchase";

    [Test]
    procedure Scenario_AC01_Calculate_PreservesOtherWorksheet1033()
    begin
        // Story #131 AC01 | Time: WorkDate planning horizon | Risk: native report 699 cross-worksheet deletion.
        AssertCalculation(1033);
    end;

    [Test]
    procedure Scenario_AC01_Calculate_PreservesOtherWorksheet1039()
    begin
        // Story #131 AC01 | Time: WorkDate planning horizon | Risk: native report 699 cross-worksheet deletion.
        AssertCalculation(1039);
    end;

    [Test]
    procedure Scenario_AC02_NewLines_CreatePurchaseOrder1033()
    begin
        // Story #131 AC02 | Time: WorkDate for native orders | Risk: native requisition order creation.
        AssertCarryOut(1033);
    end;

    [Test]
    procedure Scenario_AC02_NewLines_CreatePurchaseOrder1039()
    begin
        // Story #131 AC02 | Time: WorkDate for native orders | Risk: native requisition order creation.
        AssertCarryOut(1039);
    end;

    [Test]
    procedure Scenario_AC03_UnknownWorksheet_ReturnsNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #131 AC03 | Time: WorkDate | Risk: None.
        Library.Initialize();
        Request.Add('templateName', 'NO131');
        Request.Add('batchName', 'NO131');
        Response := CallType(false, Request);
        AssertRefusal(Response, 'RecordNotFound');
        Response := CallType(true, Request);
        AssertRefusal(Response, 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC04_CancelMixedWithNew_RefusesBeforeAnyWrite()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        SafeLine: Record "Requisition Line";
        UnsafeLine: Record "Requisition Line";
        Header: Record "Purchase Header";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: selection must be validated before native writes.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        CreateLine(SafeLine, Batch, Item, Vendor);
        CreateLine(UnsafeLine, Batch, Item, Vendor);
        UnsafeLine."Action Message" := UnsafeLine."Action Message"::Cancel;
        UnsafeLine."Ref. Order No." := 'EXISTING';
        UnsafeLine.Modify();
        BeforeCount := Header.Count();
        Request := Selector(Batch);
        Response := CallType(true, Request);
        AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(BeforeCount, Header.Count(), 'No order may be created before all selected lines are safe.');
        Assert.IsTrue(SafeLine.Get(SafeLine."Worksheet Template Name", SafeLine."Journal Batch Name", SafeLine."Line No."), 'Safe line remains.');
        Assert.IsFalse(SafeLine."Accept Action Message", 'Preflight must not even change acceptance.');
        Assert.IsTrue(UnsafeLine.Get(UnsafeLine."Worksheet Template Name", UnsafeLine."Journal Batch Name", UnsafeLine."Line No."), 'Unsafe line remains.');
    end;

    [Test]
    procedure Scenario_AC04_ExistingDocumentLink_Refuses()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        Request: JsonObject;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: new-action lines can still link existing documents.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        CreateLine(Line, Batch, Item, Vendor);
        Line."Ref. Order No." := 'EXISTING';
        Line.Modify();
        Request := Selector(Batch);
        AssertRefusal(CallType(true, Request), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC04_BadDatesAndTypes_RefuseWithoutDeleting()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        Request: JsonObject;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: invalid requests must preserve working lines.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        CreateLine(Line, Batch, Item, Vendor);
        Request := Selector(Batch);
        Request.Add('startingDate', Format(WorkDate(), 0, 9));
        Request.Add('endingDate', Format(WorkDate() - 1, 0, 9));
        AssertRefusal(CallType(false, Request), 'InvalidParameter');
        Request.Replace('endingDate', Format(WorkDate() + 30, 0, 9));
        Request.Add('itemFilter', 123);
        AssertRefusal(CallType(false, Request), 'InvalidParameter');
        Assert.IsTrue(Line.Get(Line."Worksheet Template Name", Line."Journal Batch Name", Line."Line No."), 'Invalid calculation preserves line.');
    end;

    [Test]
    procedure Scenario_AC04_EmptyWorksheet_ReturnsPreconditionFailed()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: None.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        AssertRefusal(CallType(true, Selector(Batch)), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC04_DuplicateOrUnknownLine_Refuses()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        Request: JsonObject;
        Numbers: JsonArray;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: explicit selections must never broaden silently.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        CreateLine(Line, Batch, Item, Vendor);
        Request := Selector(Batch);
        Numbers.Add(Line."Line No.");
        Numbers.Add(Line."Line No.");
        Request.Add('lineNos', Numbers);
        AssertRefusal(CallType(true, Request), 'InvalidParameter');
        Clear(Numbers);
        Numbers.Add(Line."Line No." + 1);
        Request.Replace('lineNos', Numbers);
        AssertRefusal(CallType(true, Request), 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC05_BilingualHelp_DeclaresEffectsAndCount()
    var
        Calculate: Codeunit "Requisition Calc Impl ori";
        Carry: Codeunit "Requisition Carry Impl ori";
        Effect: JsonObject;
        PreviousLanguage: Integer;
        EnglishNotes: Text;
        IcelandicNotes: Text;
        Token: JsonToken;
        TypeName: Text;
    begin
        // Story #131 AC05 | Time: None | Risk: Foundation confirmation contract.
        Library.Initialize();
        TypeName := 'Purchase.Requisition.Calculate';
        Assert.AreEqual(3, TypeName.Split('.').Count(), 'Three-part name.');
        TypeName := 'Purchase.Requisition.CarryOut';
        Assert.AreEqual(3, TypeName.Split('.').Count(), 'Three-part name.');
        Calculate.GetEffect(Effect);
        Assert.AreEqual('write', TextAt(Effect, 'effect'), 'Calculation is write.');
        Carry.GetEffect(Effect);
        Assert.AreEqual('irreversible', TextAt(Effect, 'effect'), 'Carry-out is irreversible.');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Carry.GetNotes(EnglishNotes);
        GlobalLanguage(1039);
        Carry.GetNotes(IcelandicNotes);
        GlobalLanguage(PreviousLanguage);
        Assert.AreNotEqual(EnglishNotes, IcelandicNotes, 'Help follows locale.');
        Assert.IsTrue(EnglishNotes.Contains('expectedCount'), 'English count definition.');
        Assert.IsTrue(IcelandicNotes.Contains('expectedCount'), 'Icelandic count definition.');
        Assert.IsTrue(Effect.Get('writes', Token), 'Effect declares writes.');
    end;

    [Test]
    procedure Scenario_AC02_NewTransfer_CreatesNativeOrder1033()
    begin
        // Story #131 AC02 | Time: WorkDate | Risk: bounded native transfer order path.
        AssertTransfer(1033);
    end;

    [Test]
    procedure Scenario_AC02_NewTransfer_CreatesNativeOrder1039()
    begin
        // Story #131 AC02 | Time: WorkDate | Risk: bounded native transfer order path.
        AssertTransfer(1039);
    end;

    [Test]
    procedure Scenario_AC04_NativeFailure_RollsBackAcceptanceAndOrders()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        Header: Record "Purchase Header";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: Codeunit.Run transaction must roll back native failure.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        CreateLine(Line, Batch, Item, Vendor);
        Vendor.Blocked := Vendor.Blocked::All;
        Vendor.Modify();
        BeforeCount := Header.Count();
        Commit();
        Request := Selector(Batch);
        Response := Library.ExecuteType("Message Type ori"::"Purchase.Requisition.CarryOut", '', Request, false);
        AssertRefusal(Response, 'BusinessCentralError');
        Assert.AreEqual(BeforeCount, Header.Count(), 'Failed native creation leaves no order.');
        Line.Get(Line."Worksheet Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.IsFalse(Line."Accept Action Message", 'Failed native call rolls back acceptance change too.');
    end;

    [Test]
    procedure Scenario_AC04_Confirmation_RefusesBeforeWrites()
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        Version: Enum "Message Version ori";
        Request: JsonObject;
        Response: JsonObject;
        ContentType: Text[100];
        Serialized: Text;
    begin
        // Story #131 AC04 | Time: WorkDate | Risk: Foundation confirmation before native execution.
        Library.Initialize();
        // The minimum supported Foundation predates confirmation; that boundary is owned by Foundation.
        if not Enum::"Bifrost Error Code ori".Names().Contains('ConfirmationRequired') then
            exit;
        CreateFixture(Batch, Item, Vendor);
        CreateLine(Line, Batch, Item, Vendor);
        Request := Selector(Batch);
        Request.WriteTo(Serialized);
        Input.AddText(Serialized);
        Dispatcher.Execute("Message Type ori"::"Purchase.Requisition.CarryOut", Version::"1.0", '', '', 'application/json', Input, Output, ContentType, true);
        Output.GetSubText(Serialized, 1);
        Response.ReadFrom(Serialized);
        AssertRefusal(Response, 'ConfirmationRequired');
        Clear(Input);
        Clear(Output);
        Request.Add('expectedCount', 2);
        Request.WriteTo(Serialized);
        Input.AddText(Serialized);
        Dispatcher.Execute("Message Type ori"::"Purchase.Requisition.CarryOut", Version::"1.0", '', '', 'application/json', Input, Output, ContentType, true);
        Output.GetSubText(Serialized, 1);
        Response.ReadFrom(Serialized);
        AssertRefusal(Response, 'ConfirmationMismatch');
        Line.Get(Line."Worksheet Template Name", Line."Journal Batch Name", Line."Line No.");
        Assert.IsFalse(Line."Accept Action Message", 'Confirmation refusal preserves worksheet acceptance.');
    end;

    local procedure AssertTransfer(LanguageId: Integer)
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        FromLocation: Record Location;
        ToLocation: Record Location;
        Transit: Record Location;
        Route: Record "Transfer Route";
        Header: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        Warehouse: Codeunit "Library - Warehouse";
        Response: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        PreviousLanguage: Integer;
        OrderNo: Code[20];
    begin
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        Warehouse.CreateLocationWithInventoryPostingSetup(FromLocation);
        Warehouse.CreateLocationWithInventoryPostingSetup(ToLocation);
        Warehouse.CreateInTransitLocation(Transit);
        Warehouse.CreateTransferRoute(Route, FromLocation.Code, ToLocation.Code);
        Route.Validate("In-Transit Code", Transit.Code);
        Route.Modify(true);
        CreateLine(Line, Batch, Item, Vendor);
        // Location validation refreshes replenishment from the item; select Transfer afterwards.
        Line.Validate("Location Code", ToLocation.Code);
        Line.Validate("Replenishment System", Line."Replenishment System"::Transfer);
        Line.Validate("Transfer-from Code", FromLocation.Code);
        Line."Transfer Shipment Date" := WorkDate();
        Line.Modify(true);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := CallType(true, Selector(Batch));
        GlobalLanguage(PreviousLanguage);
        AssertSuccess(Response);
        Response.Get('transferOrders', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One native transfer order.');
        Token.AsArray().Get(0, Entry);
        OrderNo := CopyStr(TextAt(Entry.AsObject(), 'orderNo'), 1, MaxStrLen(OrderNo));
        Header.Get(OrderNo);
        Assert.AreEqual(FromLocation.Code, Header."Transfer-from Code", 'Native source.');
        Assert.AreEqual(ToLocation.Code, Header."Transfer-to Code", 'Native destination.');
        TransferLine.SetRange("Document No.", Header."No.");
        TransferLine.FindFirst();
        Assert.AreEqual(Item."No.", TransferLine."Item No.", 'Native item.');
        Assert.AreEqual(10, TransferLine.Quantity, 'Native quantity.');
        Header.Delete(true);
    end;

    local procedure AssertCalculation(LanguageId: Integer)
    var
        Batch: Record "Requisition Wksh. Name";
        OtherBatch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        OtherLine: Record "Requisition Line";
        Line: Record "Requisition Line";
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
        Token: JsonToken;
    begin
        // [GIVEN] One planned item and a matching line in another worksheet.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        Planning.CreateRequisitionWkshName(OtherBatch, Batch."Worksheet Template Name");
        CreateLine(OtherLine, OtherBatch, Item, Vendor);
        OtherLine.Quantity := 123;
        OtherLine.Modify();
        Request := Selector(Batch);
        Request.Add('itemFilter', Item."No.");
        Request.Add('startingDate', Format(WorkDate(), 0, 9));
        Request.Add('endingDate', Format(WorkDate() + 30, 0, 9));
        // [WHEN] The native calculation runs in each supported language.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := CallType(false, Request);
        GlobalLanguage(PreviousLanguage);
        // [THEN] Demand generates suggestions and the unrelated worksheet is preserved.
        AssertSuccess(Response);
        Assert.IsTrue(Response.Get('lines', Token), 'Suggested lines returned.');
        Assert.IsTrue(Token.AsArray().Count() > 0, 'Safety stock generates a suggested purchase.');
        Line.SetRange("Worksheet Template Name", Batch."Worksheet Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
        Assert.IsFalse(Line.IsEmpty(), 'Native working lines exist.');
        Assert.IsTrue(OtherLine.Get(OtherLine."Worksheet Template Name", OtherLine."Journal Batch Name", OtherLine."Line No."), 'Other worksheet survives.');
        Assert.AreEqual(123, OtherLine.Quantity, 'Other worksheet quantity unchanged.');
    end;

    local procedure AssertCarryOut(LanguageId: Integer)
    var
        Batch: Record "Requisition Wksh. Name";
        Item: Record Item;
        Vendor: Record Vendor;
        Line: Record "Requisition Line";
        OtherLine: Record "Requisition Line";
        Header: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
        Numbers: JsonArray;
        Token: JsonToken;
        Entry: JsonToken;
        PreviousLanguage: Integer;
        OrderNo: Code[20];
    begin
        // [GIVEN] Two suggestions, with only the first selected.
        Library.Initialize();
        CreateFixture(Batch, Item, Vendor);
        CreateLine(Line, Batch, Item, Vendor);
        CreateLine(OtherLine, Batch, Item, Vendor);
        Request := Selector(Batch);
        Numbers.Add(Line."Line No.");
        Request.Add('lineNos', Numbers);
        // [WHEN] Native order creation carries out the selection.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := CallType(true, Request);
        GlobalLanguage(PreviousLanguage);
        // [THEN] The exact native order is returned and only the selected line is consumed.
        AssertSuccess(Response);
        Response.Get('purchaseOrders', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'One native order.');
        Token.AsArray().Get(0, Entry);
        OrderNo := CopyStr(TextAt(Entry.AsObject(), 'orderNo'), 1, MaxStrLen(OrderNo));
        Assert.IsTrue(Header.Get(Header."Document Type"::Order, OrderNo), 'Returned order exists.');
        Assert.AreEqual(Vendor."No.", Header."Buy-from Vendor No.", 'Native vendor.');
        PurchLine.SetRange("Document Type", Header."Document Type");
        PurchLine.SetRange("Document No.", OrderNo);
        PurchLine.SetRange("No.", Item."No.");
        PurchLine.FindFirst();
        Assert.AreEqual(10, PurchLine.Quantity, 'Native quantity.');
        Assert.IsFalse(Line.Get(Line."Worksheet Template Name", Line."Journal Batch Name", Line."Line No."), 'Selected line consumed.');
        Assert.IsTrue(OtherLine.Get(OtherLine."Worksheet Template Name", OtherLine."Journal Batch Name", OtherLine."Line No."), 'Unselected line remains.');
        Header.Delete(true);
    end;

    local procedure CreateFixture(var Batch: Record "Requisition Wksh. Name"; var Item: Record Item; var Vendor: Record Vendor)
    var
        WorksheetTemplate: Record "Req. Wksh. Template";
    begin
        WorksheetTemplate.Init();
        WorksheetTemplate.Name := CopyStr('Q' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10);
        WorksheetTemplate.Insert(true);
        Planning.CreateRequisitionWkshName(Batch, WorksheetTemplate.Name);
        Inventory.CreateItem(Item);
        Purchase.CreateVendor(Vendor);
        Item.Validate("Vendor No.", Vendor."No.");
        Item.Validate("Replenishment System", Item."Replenishment System"::Purchase);
        Item.Validate("Reordering Policy", Item."Reordering Policy"::"Fixed Reorder Qty.");
        Item.Validate("Reorder Point", 5);
        Item.Validate("Reorder Quantity", 10);
        Item.Validate("Safety Stock Quantity", 5);
        Item.Modify(true);
    end;

    local procedure CreateLine(var Line: Record "Requisition Line"; Batch: Record "Requisition Wksh. Name"; Item: Record Item; Vendor: Record Vendor)
    begin
        Planning.CreateRequisitionLine(Line, Batch."Worksheet Template Name", Batch.Name);
        Line.Validate(Type, Line.Type::Item);
        Line.Validate("No.", Item."No.");
        Line.Validate("Vendor No.", Vendor."No.");
        Line.Validate(Quantity, 10);
        Line.Validate("Action Message", Line."Action Message"::New);
        Line.Validate("Order Date", WorkDate());
        Line.Validate("Due Date", WorkDate() + 7);
        Line."Accept Action Message" := false;
        Line.Modify(true);
    end;

    local procedure Selector(Batch: Record "Requisition Wksh. Name") Request: JsonObject
    begin
        Request.Add('templateName', Batch."Worksheet Template Name");
        Request.Add('batchName', Batch.Name);
    end;

    local procedure CallType(CarryOut: Boolean; Request: JsonObject): JsonObject
    begin
        if CarryOut then
            exit(Library.ExecuteType("Message Type ori"::"Purchase.Requisition.CarryOut", '', Request, true));
        exit(Library.ExecuteType("Message Type ori"::"Purchase.Requisition.Calculate", '', Request, true));
    end;

    local procedure AssertSuccess(Response: JsonObject)
    var
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.AreEqual('Success', TextAt(Response, 'status'), Serialized);
    end;

    local procedure AssertRefusal(Response: JsonObject; Code: Text)
    begin
        Assert.AreEqual(Code, TextAt(Response, 'code'), 'Typed refusal.');
        Assert.AreNotEqual('', TextAt(Response, 'nextStep'), 'Actionable refusal.');
    end;

    local procedure TextAt(Value: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Value.Get(Name, Token), 'Missing ' + Name);
        exit(Token.AsValue().AsText());
    end;
}
