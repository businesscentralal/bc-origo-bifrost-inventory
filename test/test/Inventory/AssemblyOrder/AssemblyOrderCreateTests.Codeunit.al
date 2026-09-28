namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AssemblyOrder.Create message type.
/// </summary>
codeunit 96908 "Assembly Order Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure Create_AllRequiredFields_ReturnsSuccess()
    var
        ParentItem, ComponentItem : Record Item;
        AssemblyHeader: Record "Assembly Header";
        RequestJson, ResponseJson : JsonObject;
        DocumentNoToken, StatusToken : JsonToken;
    begin
        // [SCENARIO] Create assembly order with item, quantity and due date
        // [GIVEN] An assembly item with BOM
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);

        // [GIVEN] Create request
        RequestJson.Add('itemNo', ParentItem."No.");
        RequestJson.Add('quantity', 5);
        RequestJson.Add('dueDate', Format(WorkDate(), 0, 9));

        // [WHEN] Task runs
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Create", RequestJson, ResponseJson);

        // [THEN] Success response with documentNo, and header exists
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('documentNo', DocumentNoToken), 'documentNo missing');
        Assert.IsTrue(
            AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, DocumentNoToken.AsValue().AsCode()),
            'Assembly header should exist');
        Assert.AreEqual(ParentItem."No.", AssemblyHeader."Item No.", 'Item No. mismatch');
    end;

    [Test]
    procedure Create_MissingItemNo_ReturnsError()
    var
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Missing itemNo produces Error response
        // [GIVEN] Request with no itemNo
        RequestJson.Add('quantity', 1);

        // [WHEN] Task runs
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Create", RequestJson, ResponseJson);

        // [THEN] Error response
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [Test]
    procedure AssemblyCreate_BadPostingDate_IsAnError()
    var
        RequestJson, ResponseJson : JsonObject;
        ResponseText: Text;
    begin
        GlobalLanguage(1033);
        // [SCENARIO] Inventory.AssemblyOrder.Create rejects a bad postingDate instead of ignoring it.
        RequestJson.Add('itemNo', 'ITEM-DATE');
        RequestJson.Add('quantity', 1);
        RequestJson.Add('postingDate', '26.09.2026');
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.Create", RequestJson, ResponseJson);

        ResponseJson.WriteTo(ResponseText);
        Assert.IsTrue(StrPos(ResponseText, 'postingDate') > 0, ResponseText);
        Assert.IsTrue(StrPos(ResponseText, '2026-09-26') > 0, ResponseText);
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        // Swallow BC base-app informational messages (e.g. due-date warning on assembly lines).
    end;
}
