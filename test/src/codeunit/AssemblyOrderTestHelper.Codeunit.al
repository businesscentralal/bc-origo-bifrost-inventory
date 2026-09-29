namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Shared test helper for Assembly Order tests.
/// Creates assembly items with BOM, locations, assembly headers, and seeds component stock.
/// </summary>
codeunit 96903 "Assembly Order Test Helper"
{
    Access = Internal;

    var
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssembly: Codeunit "Library - Assembly";

    /// <summary>
    /// Creates a parent (assembly) item with a BOM composed of one component item.
    /// </summary>
    /// <param name="ParentItem">Parent (assembled) item.</param>
    /// <param name="ComponentItem">Component item used in the BOM.</param>
    internal procedure CreateAssemblyItemWithBOM(var ParentItem: Record Item; var ComponentItem: Record Item)
    var
        BOMComponent: Record "BOM Component";
    begin
        LibraryInventory.CreateItem(ComponentItem);
        LibraryInventory.CreateItem(ParentItem);
        ParentItem.Validate("Replenishment System", ParentItem."Replenishment System"::Assembly);
        ParentItem.Validate("Assembly Policy", ParentItem."Assembly Policy"::"Assemble-to-Stock");
        ParentItem.Modify(true);
        LibraryAssembly.CreateAssemblyListComponent(
            BOMComponent.Type::Item, ComponentItem."No.", ParentItem."No.", '', BOMComponent."Resource Usage Type", 1, true);
    end;

    /// <summary>
    /// Creates an Assembly Order header (Document Type = Order) for the given parent item.
    /// </summary>
    internal procedure CreateAssemblyOrder(var AssemblyHeader: Record "Assembly Header"; ItemNo: Code[20]; Qty: Decimal)
    begin
        LibraryAssembly.CreateAssemblyHeader(AssemblyHeader, WorkDate(), ItemNo, '', Qty, '');
    end;

    /// <summary>
    /// Posts a positive item-journal adjustment to seed component inventory.
    /// </summary>
    internal procedure CreatePositiveAdjustment(ItemNo: Code[20]; Qty: Decimal)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::Item, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        LibraryInventory.CreateItemJournalLine(
            ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name,
            "Item Ledger Entry Type"::"Positive Adjmt.", ItemNo, Qty);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    /// <summary>
    /// Dispatches an Assembly Order message through the public dispatcher and returns the parsed
    /// response JSON.
    /// </summary>
    /// <param name="MessageType">The message type to dispatch.</param>
    /// <param name="RequestJson">The request JSON payload.</param>
    /// <param name="ResponseJson">Receives the parsed response JSON.</param>
    internal procedure ProcessMessage(MessageType: Enum "Message Type ori"; RequestJson: JsonObject; var ResponseJson: JsonObject)
    begin
        ProcessMessage(MessageType, '', RequestJson, ResponseJson);
    end;

    /// <summary>
    /// Dispatches a Bifrost message with a subject through the public dispatcher.
    /// The subject is the document number when the message type reads it from there.
    /// </summary>
    /// <param name="MessageType">The message type to dispatch.</param>
    /// <param name="Subject">Document number or other subject. Pass empty when the request JSON identifies the record.</param>
    /// <param name="RequestJson">The request JSON payload.</param>
    /// <param name="ResponseJson">Receives the parsed response JSON.</param>
    internal procedure ProcessMessage(MessageType: Enum "Message Type ori"; Subject: Text[250]; RequestJson: JsonObject; var ResponseJson: JsonObject)
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[50];
        MessageId: Guid;
        ResponseTime: Duration;
        EmptyTaskId: Guid;
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        if RequestText <> '' then
            RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(
            MessageType,
            "Message Version ori"::"1.0",
            Subject,
            '',
            '',
            RequestContent,
            EmptyTaskId,
            0,
            MessageId,
            ResponseContent,
            ResponseContentType,
            ResponseTime);
        if ResponseContent.Length() > 0 then begin
            ResponseContent.GetSubText(ResponseText, 1);
            ResponseJson.ReadFrom(ResponseText);
        end;
    end;
}
