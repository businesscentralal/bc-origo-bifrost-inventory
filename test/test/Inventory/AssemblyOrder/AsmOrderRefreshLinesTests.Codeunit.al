namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AssemblyOrder.RefreshLines message type.
/// </summary>
codeunit 96906 "Asm. Order RefreshLines Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure RefreshLines_ExistingOrder_ReturnsSuccess()
    var
        ParentItem, ComponentItem : Record Item;
        AssemblyHeader: Record "Assembly Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Refresh lines for an existing assembly order
        // [GIVEN] An assembly order
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 3);

        RequestJson.Add('documentNo', AssemblyHeader."No.");

        // [WHEN]
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.RefreshLines", RequestJson, ResponseJson);

        // [THEN]
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
    end;

    [Test]
    procedure RefreshLines_MissingIdentifier_ReturnsError()
    var
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Missing identifier returns Error
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.RefreshLines", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        // Swallow BC base-app informational messages (e.g. due-date warning on assembly lines).
    end;
}
