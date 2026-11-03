namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
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
        ComponentItem.Get(ComponentItem."No.");
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

    /// <summary>
    /// postingDate and quantityToAssemble are used by the preview and do not stay on the order.
    /// </summary>
    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure PreviewPost_Adjustments_LeaveOrderUnchanged()
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        PostedAssemblyHeader: Record "Posted Assembly Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        OriginalPostingDate: Date;
        PreviewPostingDate: Date;
        OriginalQuantity: Decimal;
        LineQuantity: Decimal;
        ResponseText: Text;
    begin
        // [SCENARIO] #159 review: both preview keys run against an order with lines and roll back.
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        Helper.CreatePositiveAdjustment(ComponentItem."No.", 100);
        // Remaining quantity is the order quantity. Preview a smaller legal quantity so the
        // platform check "cannot be higher than the Remaining Quantity" does not refuse the call.
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 4);
        OriginalPostingDate := AssemblyHeader."Posting Date";
        OriginalQuantity := AssemblyHeader."Quantity to Assemble";
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.FindFirst();
        LineQuantity := AssemblyLine."Quantity to Consume";
        PreviewPostingDate := CalcDate('<+10D>', OriginalPostingDate);

        RequestJson.Add('documentNo', AssemblyHeader."No.");
        RequestJson.Add('postingDate', Format(PreviewPostingDate, 0, 9));
        RequestJson.Add('quantityToAssemble', OriginalQuantity - 2);
        Helper.ProcessMessage("Message Type ori"::"Inventory.AssemblyOrder.PreviewPost", RequestJson, ResponseJson);

        ResponseJson.WriteTo(ResponseText);
        Assert.IsTrue(ResponseJson.Get('status', Token), ResponseText);
        Assert.AreEqual('Success', Token.AsValue().AsText(), ResponseText);
        Assert.IsTrue(ResponseJson.Get('quantityToAssemble', Token), ResponseText);
        Assert.AreEqual(OriginalQuantity - 2, Token.AsValue().AsDecimal(), 'The preview answer uses the requested quantity.');
        AssertAdjustedPreview(ResponseJson, OriginalQuantity - 2, PreviewPostingDate);

        AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, AssemblyHeader."No.");
        Assert.AreEqual(OriginalPostingDate, AssemblyHeader."Posting Date", 'Preview must not keep postingDate.');
        Assert.AreEqual(OriginalQuantity, AssemblyHeader."Quantity to Assemble", 'Preview must not keep quantityToAssemble.');
        AssemblyLine.FindFirst();
        Assert.AreEqual(LineQuantity, AssemblyLine."Quantity to Consume", 'Preview must not keep the component quantity.');
        PostedAssemblyHeader.SetCurrentKey("Order No.");
        PostedAssemblyHeader.SetRange("Order No.", AssemblyHeader."No.");
        Assert.IsTrue(PostedAssemblyHeader.IsEmpty(), 'Preview must not post the order.');
    end;

    local procedure AssertAdjustedPreview(ResponseJson: JsonObject; ExpectedQuantity: Decimal; ExpectedPostingDate: Date)
    var
        PreviewToken: JsonToken;
        TableToken: JsonToken;
        EntryToken: JsonToken;
        FieldsToken: JsonToken;
        ValueToken: JsonToken;
        EntriesToken: JsonToken;
        TableJson: JsonObject;
        EntryJson: JsonObject;
        Fields: JsonObject;
        Entries: JsonArray;
        ResponseText: Text;
        FoundOutput: Boolean;
        FoundPostingDate: Boolean;
        TableId: Integer;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.IsTrue(ResponseJson.Get('preview', PreviewToken), ResponseText);
        foreach TableToken in PreviewToken.AsArray() do begin
            TableJson := TableToken.AsObject();
            if not TableJson.Get('tableId', ValueToken) then
                continue;
            TableId := ValueToken.AsValue().AsInteger();
            if not TableJson.Get('entries', EntriesToken) then
                continue;
            Entries := EntriesToken.AsArray();
            foreach EntryToken in Entries do begin
                EntryJson := EntryToken.AsObject();
                if not EntryJson.Get('fields', FieldsToken) then
                    continue;
                Fields := FieldsToken.AsObject();
                if TableId = Database::"Item Ledger Entry" then
                    if Fields.Get('EntryType', ValueToken) then
                        if ValueToken.AsValue().AsText() = 'Assembly Output' then begin
                            if Fields.Get('Quantity', ValueToken) then
                                if ValueToken.AsValue().AsText() = Format(ExpectedQuantity, 0, 9) then
                                    FoundOutput := true;
                            // This Foundation build includes Posting Date on the item ledger preview.
                            // G/L Entry is absent when the preview posts no general ledger lines.
                            if Fields.Get('PostingDate', ValueToken) then
                                if ValueToken.AsValue().AsText() = Format(ExpectedPostingDate, 0, 9) then
                                    FoundPostingDate := true;
                        end;
                if TableId = Database::"G/L Entry" then
                    if Fields.Get('PostingDate', ValueToken) then
                        if ValueToken.AsValue().AsText() = Format(ExpectedPostingDate, 0, 9) then
                            FoundPostingDate := true;
            end;
        end;
        Assert.IsTrue(FoundOutput, 'Preview output quantity must be the requested quantity. ' + ResponseText);
        Assert.IsTrue(FoundPostingDate, 'Preview G/L posting date must be the requested date. ' + ResponseText);
    end;

}
