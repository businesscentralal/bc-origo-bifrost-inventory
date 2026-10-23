namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AssemblyOrder.Post message type.
/// </summary>
codeunit 96909 "Assembly Order Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure Post_FailureKeepsRequestedQuantity_ENU()
    begin
        VerifyFailedPostKeepsQuantity(1033);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure Post_FailureKeepsRequestedQuantity_ISL()
    begin
        VerifyFailedPostKeepsQuantity(1039);
    end;

    local procedure VerifyFailedPostKeepsQuantity(LanguageId: Integer)
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        Header: Record "Assembly Header";
        PostedHeader: Record "Posted Assembly Header";
        Entries: Record "Item Ledger Entry";
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
        PreviousLanguage: Integer;
    begin
        // #159 AC2: the public message deliberately commits the requested quantity before native posting.
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreateAssemblyOrder(Header, ParentItem."No.", 2);
        Helper.CreatePositiveAdjustment(ComponentItem."No.", 100);
        Assert.AreEqual(2, Header."Quantity to Assemble", 'Fixture starts with a different quantity.');
        Entries.SetFilter("Item No.", '%1|%2', ParentItem."No.", ComponentItem."No.");
        BeforeCount := Entries.Count();
        Observer.SetAssemblyPostFailure(Header."No.");
        BindSubscription(Observer);
        Request.Add('documentNo', Header."No.");
        Request.Add('quantityToAssemble', 1);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Post", Request, Response);
        GlobalLanguage(PreviousLanguage);
        UnbindSubscription(Observer);

        Assert.IsTrue(Response.Get('status', Token), 'Failed post returns a result.');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Native posting failure is returned.');
        Response.Get('error', Token);
        Assert.AreNotEqual(0, StrPos(Token.AsValue().AsText(), 'Owned assembly posting failure after output.'), 'Failure occurs after native output writes.');
        Header.Get(Header."Document Type", Header."No.");
        Assert.AreEqual(1, Header."Quantity to Assemble", 'Gunnar decision: the pre-post quantity survives failure.');
        Assert.AreEqual(0, Header."Assembled Quantity", 'Failed native output is rolled back.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Failed posting leaves no new item entries.');
        PostedHeader.SetRange("Order No.", Header."No.");
        Assert.IsTrue(PostedHeader.IsEmpty(), 'Failed posting leaves no posted assembly header.');
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure UndoAssembly_NativeFailureRollsBackEntriesAndHeader()
    begin
        VerifyAssemblyUndo(true);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure UndoAssembly_PostsReversingEntries()
    begin
        VerifyAssemblyUndo(false);
    end;

    local procedure VerifyAssemblyUndo(InjectFailure: Boolean)
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        Header: Record "Assembly Header";
        PostedHeader: Record "Posted Assembly Header";
        Entries: Record "Item Ledger Entry";
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeCount: Integer;
    begin
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreateAssemblyOrder(Header, ParentItem."No.", 1);
        Helper.CreatePositiveAdjustment(ComponentItem."No.", 100);
        Request.Add('documentNo', Header."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Post", Request, Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Owned assembly fixture posts.');
        PostedHeader.SetRange("Order No.", Header."No.");
        PostedHeader.FindFirst();
        BeforeCount := Entries.Count();
        if InjectFailure then begin
            Observer.SetUndoFailure('', PostedHeader."No.");
            BindSubscription(Observer);
        end;
        Clear(Request);
        Clear(Response);
        Request.Add('documentNo', PostedHeader."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Assembly.UndoPost", Request, Response);
        if InjectFailure then
            UnbindSubscription(Observer);
        PostedHeader.Get(PostedHeader."No.");
        Response.Get('status', Token);
        if InjectFailure then begin
            Assert.AreEqual('Error', Token.AsValue().AsText(), 'Injected native failure returned.');
            Response.Get('error', Token);
            Assert.AreNotEqual(0, StrPos(Token.AsValue().AsText(), 'Owned assembly undo failure'), 'Failure occurred after native undo writes.');
            Assert.IsFalse(PostedHeader.Reversed, 'Header reversal rolls back.');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'Native reversing entries roll back.');
        end else begin
            Assert.AreEqual('Success', Token.AsValue().AsText(), 'Undo succeeds.');
            Assert.IsTrue(PostedHeader.Reversed, 'Native header reversal saved.');
            Assert.IsTrue(Entries.Count() > BeforeCount, 'Native reversing entries saved.');
        end;
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure Post_OrderWithStock_ReturnsSuccess()
    var
        ParentItem, ComponentItem : Record Item;
        AssemblyHeader: Record "Assembly Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 1);
        Helper.CreatePositiveAdjustment(ComponentItem."No.", 100);

        RequestJson.Add('documentNo', AssemblyHeader."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Post", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
    end;

    [Test]
    procedure Post_MissingIdentifier_ReturnsError()
    var
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Post", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        // Swallow BC base-app informational messages (e.g. due-date warning on assembly lines).
    end;
}
