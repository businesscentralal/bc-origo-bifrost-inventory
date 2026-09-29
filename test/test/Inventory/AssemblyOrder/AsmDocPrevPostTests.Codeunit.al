namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AssemblyOrder.PreviewPost message type.
/// </summary>
codeunit 96905 "Asm. Doc Prev. Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure PreviewPost_OrderWithStock_ReturnsLedgerEntries()
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
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.PreviewPost", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');

        // Source order remains Open after preview (no real posting)
        AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, AssemblyHeader."No.");
        Assert.AreEqual(AssemblyHeader.Status::Open, AssemblyHeader.Status, 'Source should remain Open after preview');
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure PreviewPost_NothingToAssemble_ReturnsNothingToPreview()
    var
        ParentItem, ComponentItem : Record Item;
        AssemblyHeader: Record "Assembly Header";
        RequestJson, ResponseJson : JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] #140: an assembly order with Quantity to Assemble 0 never previews as Success.
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 1);
        AssemblyHeader.Validate("Quantity to Assemble", 0);
        AssemblyHeader.Modify(true);

        RequestJson.Add('documentNo', AssemblyHeader."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.PreviewPost", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Never Success when nothing would be assembled');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code');
        Assert.AreEqual('NothingToPreview', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep');
        Assert.IsTrue(Token.AsValue().AsText().Contains('Inventory.AssemblyOrder.Statistics'), 'nextStep names the Statistics type');
    end;

    [Test]
    procedure PreviewPost_MissingIdentifier_ReturnsError()
    var
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.PreviewPost", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        // Swallow BC base-app informational messages (e.g. due-date warning on assembly lines).
    end;
}
