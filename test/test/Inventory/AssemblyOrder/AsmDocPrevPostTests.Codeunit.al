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
        Assert.IsTrue(ResponseJson.Contains('entryCount'), 'Preview helper must return entry counts');
        Assert.IsTrue(ResponseJson.Contains('glEntryCount'), 'Preview helper must return GL entry counts');
        Assert.IsTrue(ResponseJson.Contains('summary'), 'Preview helper must return its summary');
        Assert.IsFalse(ResponseJson.Contains('callstack'), 'Preview must not expose a callstack');

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

    /// <summary>Preview helper migration preserves failure and the source order when no lines exist.</summary>
    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure PreviewPost_NoLines_ReturnsErrorAndPreservesOrder()
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // PR #29 B2 | Time: WorkDate for fixture | Risk: None
        // [GIVEN] An order whose lines were removed before preview.
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 1);
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.DeleteAll(true);
        RequestJson.Add('documentNo', AssemblyHeader."No.");
        // [WHEN] Preview is requested through production message dispatch.
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.PreviewPost", RequestJson, ResponseJson);
        // [THEN] The error remains actionable and no posting occurs.
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('NothingToPreview', Token.AsValue().AsText(), 'No-line preview code');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.IsTrue(Token.AsValue().AsText().Contains('Inventory.AssemblyOrder.Statistics'), 'Actionable next step');
        Assert.IsFalse(ResponseJson.Contains('callstack'), 'Preview response must not expose a callstack');
        Assert.IsTrue(AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, AssemblyHeader."No."), 'Order must remain');
        Assert.AreEqual(AssemblyHeader.Status::Open, AssemblyHeader.Status, 'Preview must not change status');
    end;

    /// <summary>Real posting-preview failure is returned without posting the order.</summary>
    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure PreviewPost_NoComponentStock_ReturnsPostingError()
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        AssemblyHeader: Record "Assembly Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // PR #29 B2 | Time: WorkDate for fixture | Risk: None
        // [GIVEN] Components cannot go negative and no component stock exists.
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        ComponentItem.Validate("Prevent Negative Inventory", ComponentItem."Prevent Negative Inventory"::Yes);
        ComponentItem.Modify(true);
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 1);
        RequestJson.Add('documentNo', AssemblyHeader."No.");
        // [WHEN] Actual BC posting-preview execution fails inside the migrated helper path.
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.PreviewPost", RequestJson, ResponseJson);
        // [THEN] Preserve the error and source document; do not manufacture Success.
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Unavailable component must fail posting preview');
        Assert.IsTrue(ResponseJson.Get('error', Token), 'Posting error missing');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Preserve the BC posting error');
        Assert.IsFalse(ResponseJson.Contains('callstack'), 'Posting errors must not expose a callstack');
        Assert.IsTrue(AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, AssemblyHeader."No."), 'Order must remain');
        Assert.AreEqual(AssemblyHeader.Status::Open, AssemblyHeader.Status, 'Failure must not post source');
    end;

}
