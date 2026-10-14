namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Native posted fixtures verify undo selection, recreate-order semantics and rollback after real corrective entries.</summary>
codeunit 96980 "Inventory Native Undo Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ContractLibrary: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryAssembly: Codeunit "Library - Assembly";
        NativeUndo: Codeunit "Inventory Native Undo ori";

    /// <summary>Only the selected posted transfer line is corrected; the other shipment line stays available.</summary>
    [Test]
    procedure Shipment_Subset_CorrectsOnlySelectedLine()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        OtherLine: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        LineNos: JsonArray;
        FirstLineNo: Integer;
        BeforeCount: Integer;
    begin
        CreateShipment(Header, Shipment, false);
        Line.SetRange("Document No.", Shipment."No.");
        Line.FindFirst();
        FirstLineNo := Line."Line No.";
        OtherLine.Copy(Line);
        OtherLine.FindLast();
        LineNos.Add(FirstLineNo);
        Request.Add('documentNo', Shipment."No.");
        Request.Add('lineNos', LineNos);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        BeforeCount := Entries.Count();
        Commit();
        Assert.IsTrue(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), GetLastErrorText());
        Assert.IsTrue(Entries.Count() > BeforeCount, 'Native undo emits corrective ledger entries.');
        Line.Get(Shipment."No.", FirstLineNo);
        Assert.IsTrue(Line."Correction Line", 'Selected original line is marked corrected.');
        OtherLine.Get(OtherLine."Document No.", OtherLine."Line No.");
        Assert.IsFalse(OtherLine."Correction Line", 'Unselected original line is unchanged.');
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Transfer.UndoShipment", Response);
        Response.Get('undoneLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Exactly one original line undone.');
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Already-undone explicit line refuses.');
        Assert.ExpectedError('Correction must be equal');
    end;

    /// <summary>Native undo refuses received shipments without corrective ledger writes.</summary>
    [Test]
    procedure Shipment_AlreadyReceived_RefusesWithoutWrites()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        CreateShipment(Header, Shipment, true);
        Request.Add('documentNo', Shipment."No.");
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        BeforeCount := Entries.Count();
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Native path must reject received quantity.');
        Assert.ExpectedError('received');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'No correction after native refusal.');
    end;

    /// <summary>An injected error after a real corrective Item Ledger Entry proves whole undo rollback.</summary>
    [Test]
    procedure Shipment_AfterLedgerInsertFailure_RollsBack()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inv Journal Write Observer";
        Request: JsonObject;
        BeforeCount: Integer;
        FirstLineNo: Integer;
    begin
        CreateShipment(Header, Shipment, false);
        Line.SetRange("Document No.", Shipment."No.");
        Line.FindFirst();
        FirstLineNo := Line."Line No.";
        Request.Add('documentNo', Shipment."No.");
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        Observer.SetItem(Line."Item No.");
        BindSubscription(Observer);
        BeforeCount := Entries.Count();
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Actual corrective insertion fails the isolated process.');
        Assert.ExpectedError('Owned native journal insert failure');
        UnbindSubscription(Observer);
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Corrective ledger insertion rolled back.');
        Line.Get(Shipment."No.", FirstLineNo);
        Assert.IsFalse(Line."Correction Line", 'Original shipment remains uncorrected.');
    end;

    /// <summary>Duplicate and empty subsets cannot widen a shipment undo.</summary>
    [Test]
    procedure Shipment_InvalidSubsets_Refuse()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        LineNos: JsonArray;
    begin
        CreateShipment(Header, Shipment, false);
        Line.SetRange("Document No.", Shipment."No.");
        Line.FindFirst();
        LineNos.Add(Line."Line No.");
        LineNos.Add(Line."Line No.");
        Request.Add('documentNo', Shipment."No.");
        Request.Add('lineNos', LineNos);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        Commit();
        asserterror NativeUndo.UndoShipment(TempArgument);
        Assert.ExpectedError('lineNos');
        Clear(LineNos);
        Request.Replace('lineNos', LineNos);
        TempArgument.SetRequestJson(Request);
        Commit();
        asserterror NativeUndo.UndoShipment(TempArgument);
        Assert.ExpectedError('lineNos');
    end;

    /// <summary>Native assembly undo respects recreateOrder=true and preserves the posted document as reversed.</summary>
    [Test]
    procedure Assembly_RecreateOrderTrue_ReversesAndRecreates()
    var
        PostedHeader: Record "Posted Assembly Header";
        Order: Record "Assembly Header";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreatePostedAssembly(PostedHeader);
        Assert.IsFalse(Order.Get(Order."Document Type"::Order, PostedHeader."Order No."), 'Fully posted fixture order has been removed natively.');
        Request.Add('documentNo', PostedHeader."No.");
        Request.Add('recreateOrder', true);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Assembly.UndoPost");
        Commit();
        Assert.IsTrue(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), GetLastErrorText());
        PostedHeader.Get(PostedHeader."No.");
        Assert.IsTrue(PostedHeader.Reversed, 'Posted assembly is reversed, never deleted.');
        Assert.IsTrue(Order.Get(Order."Document Type"::Order, PostedHeader."Order No."), 'Native recreateOrder produces the original order.');
        Response := TempArgument.GetResponseJson();
        ContractLibrary.AssertResponseContract("Message Type ori"::"Inventory.Assembly.UndoPost", Response);
        Response.Get('orderExists', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'Response observes actual recreated order.');
    end;

    /// <summary>False recreation leaves the fully posted order absent and repeat undo fails without new entries.</summary>
    [Test]
    procedure Assembly_RecreateOrderFalse_DoesNotRecreate()
    var
        PostedHeader: Record "Posted Assembly Header";
        Order: Record "Assembly Header";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        AfterCount: Integer;
    begin
        CreatePostedAssembly(PostedHeader);
        Request.Add('documentNo', PostedHeader."No.");
        Request.Add('recreateOrder', false);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Assembly.UndoPost");
        Commit();
        Assert.IsTrue(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), GetLastErrorText());
        Assert.IsFalse(Order.Get(Order."Document Type"::Order, PostedHeader."Order No."), 'False cannot recreate a deleted order.');
        AfterCount := Entries.Count();
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Already reversed assembly refuses.');
        Assert.ExpectedError('Reversed');
        Assert.AreEqual(AfterCount, Entries.Count(), 'Repeat cannot emit more corrective rows.');
    end;

    /// <summary>Native consumed-output refusal rolls back and retains the posted assembly.</summary>
    [Test]
    procedure Assembly_ConsumedOutput_Refuses()
    var
        PostedHeader: Record "Posted Assembly Header";
        Item: Record Item;
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        CreatePostedAssembly(PostedHeader);
        Item.Get(PostedHeader."Item No.");
        PostStock(Item, '', -1);
        Request.Add('documentNo', PostedHeader."No.");
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Assembly.UndoPost");
        BeforeCount := Entries.Count();
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Consumed output fails the native undo preconditions.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Consumed-output refusal has no ledger side effects.');
        PostedHeader.Get(PostedHeader."No.");
        Assert.IsFalse(PostedHeader.Reversed, 'Posted assembly remains unreversed.');
    end;

    /// <summary>Malformed document identifiers never resolve or change a posted shipment.</summary>
    [Test]
    procedure Shipment_MalformedDocumentNumbers_PreservePostedRows()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Payloads: List of [Text];
        Payload: Text;
        BeforeCount: Integer;
    begin
        // Issue #39 | Time: WorkDate fixture posting | Risk: truncation could target another document.
        CreateShipment(Header, Shipment, false);
        BeforeCount := Entries.Count();
        Payloads.Add('{}');
        Payloads.Add('{"documentNo":""}');
        Payloads.Add('{"documentNo":null}');
        Payloads.Add('{"documentNo":123}');
        Payloads.Add('{"documentNo":true}');
        Payloads.Add('{"documentNo":{}}');
        Payloads.Add('{"documentNo":[]}');
        Payloads.Add('{"documentNo":"123456789012345678901"}');
        foreach Payload in Payloads do begin
            Clear(Request);
            Request.ReadFrom(Payload);
            InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
            Commit();
            Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Malformed documentNo must refuse.');
            Assert.ExpectedError('documentNo');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'Invalid identifier cannot emit ledger corrections.');
            Shipment.Get(Shipment."No.");
        end;
    end;

    /// <summary>Malformed line selections cannot widen undo or alter any original line.</summary>
    [Test]
    procedure Shipment_MalformedLineNumbers_PreserveEveryLine()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        LineToken: JsonToken;
        Values: List of [Text];
        Value: Text;
        BeforeCount: Integer;
    begin
        CreateShipment(Header, Shipment, false);
        BeforeCount := Entries.Count();
        Values.Add('null');
        Values.Add('{}');
        Values.Add('"10000"');
        Values.Add('["10000"]');
        Values.Add('[0]');
        Values.Add('[-1]');
        Values.Add('[1.5]');
        Values.Add('[2147483648]');
        Values.Add('[true]');
        Values.Add('[null]');
        Values.Add('[{}]');
        foreach Value in Values do begin
            Clear(Request);
            Request.Add('documentNo', Shipment."No.");
            LineToken.ReadFrom(Value);
            Request.Add('lineNos', LineToken);
            InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
            Commit();
            Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Malformed lineNos must refuse.');
            Assert.ExpectedError('lineNos');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'Invalid line selection has no ledger effects.');
            Line.SetRange("Document No.", Shipment."No.");
            Line.SetRange("Correction Line", true);
            Assert.IsTrue(Line.IsEmpty(), 'Every original shipment line remains uncorrected.');
        end;
    end;

    /// <summary>Unknown keys are refused before native undo even when the posted document is valid.</summary>
    [Test]
    procedure Shipment_UnsupportedSelection_RefusesBeforeNativeWrites()
    var
        Header: Record "Transfer Header";
        Shipment: Record "Transfer Shipment Header";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        CreateShipment(Header, Shipment, false);
        BeforeCount := Entries.Count();
        Request.Add('documentNo', Shipment."No.");
        Request.Add('lineNo', 10000);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Native Undo Process ori", TempArgument), 'Unknown selector must not become an all-lines undo.');
        Assert.ExpectedError('Unsupported undo parameter lineNo');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Unsupported key cannot emit ledger corrections.');
    end;

    /// <summary>Malformed recreateOrder returns the documented format error without reversing the assembly.</summary>
    [Test]
    procedure Assembly_MalformedRecreation_ReturnsFormatErrorWithoutWrites()
    var
        PostedHeader: Record "Posted Assembly Header";
        Entries: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
    begin
        CreatePostedAssembly(PostedHeader);
        BeforeCount := Entries.Count();
        Request.Add('documentNo', PostedHeader."No.");
        Request.Add('recreateOrder', 'invalid');
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.Assembly.UndoPost");
        NativeUndo.UndoAssembly(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.IsTrue(Response.Get('code', Token), 'Typed refusal returns its code.');
        Assert.AreEqual('InvalidParameterFormat', Token.AsValue().AsText(), 'Matches the public Help format error.');
        Assert.IsTrue(Response.Get('parameter', Token), 'Typed refusal names the parameter.');
        Assert.AreEqual('recreateOrder', Token.AsValue().AsText(), 'Bad option is identified.');
        PostedHeader.Get(PostedHeader."No.");
        Assert.IsFalse(PostedHeader.Reversed, 'Invalid option cannot reverse the assembly.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Invalid option cannot write corrective entries.');
    end;

    local procedure CreateShipment(var Header: Record "Transfer Header"; var Shipment: Record "Transfer Shipment Header"; Receive: Boolean)
    var
        Item: Record Item;
        FromLocation: Record Location;
        ToLocation: Record Location;
        TransitLocation: Record Location;
        Line: Record "Transfer Line";
        OrderNo: Code[20];
    begin
        InitializePosting();
        LibraryInventory.CreateItem(Item);
        LibraryWarehouse.CreateTransferLocations(FromLocation, ToLocation, TransitLocation);
        PostStock(Item, FromLocation.Code, 10);
        LibraryInventory.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, TransitLocation.Code);
        LibraryInventory.CreateTransferLine(Header, Line, Item."No.", 2);
        LibraryInventory.CreateTransferLine(Header, Line, Item."No.", 3);
        OrderNo := Header."No.";
        LibraryInventory.PostTransferHeader(Header, true, Receive);
        Shipment.SetRange("Transfer Order No.", OrderNo);
        Shipment.FindLast();
    end;

    local procedure CreatePostedAssembly(var PostedHeader: Record "Posted Assembly Header")
    var
        ParentItem: Record Item;
        Component: Record Item;
        Header: Record "Assembly Header";
        Line: Record "Assembly Line";
        OrderNo: Code[20];
    begin
        InitializePosting();
        LibraryInventory.CreateItem(ParentItem);
        LibraryInventory.CreateItem(Component);
        PostStock(Component, '', 10);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), ParentItem."No.", '', 2, '');
        LibraryAssembly.CreateAssemblyLine(Header, Line, Line.Type::Item, Component."No.", Component."Base Unit of Measure", 2, 1, '');
        OrderNo := Header."No.";
        LibraryAssembly.PostAssemblyHeader(Header, '');
        PostedHeader.SetRange("Order No.", OrderNo);
        PostedHeader.FindLast();
    end;

    local procedure InitializePosting()
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
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
    end;

    local procedure PostStock(Item: Record Item; LocationCode: Code[10]; Quantity: Decimal)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", Quantity);
        Line.Validate("Posting Date", WorkDate());
        Line.Validate("Location Code", LocationCode);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary; Request: JsonObject; MessageType: Enum "Message Type ori")
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Type := MessageType;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
    end;
}
