namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
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
