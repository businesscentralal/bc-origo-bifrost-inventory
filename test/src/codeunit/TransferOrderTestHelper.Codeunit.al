namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Shared test helper for Transfer Order tests.
/// Creates locations (From, To, In-Transit), items with initial stock, and transfer orders.
/// </summary>
codeunit 96904 "Transfer Order Test Helper"
{
    Access = Internal;

    var
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";

    /// <summary>
    /// Creates three locations (From, To, In-Transit) and an item with positive stock at From.
    /// </summary>
    internal procedure SetupLocationsAndItem(
        var FromLocation: Record Location;
        var ToLocation: Record Location;
        var InTransitLocation: Record Location;
        var Item: Record Item;
        InitialQty: Decimal)
    begin
        LibraryWarehouse.CreateLocationWMS(FromLocation, false, false, false, false, false);
        LibraryWarehouse.CreateLocationWMS(ToLocation, false, false, false, false, false);
        LibraryWarehouse.CreateInTransitLocation(InTransitLocation);
        LibraryInventory.CreateItem(Item);
        if InitialQty > 0 then
            CreatePositiveAdjustment(Item."No.", FromLocation.Code, InitialQty);
    end;

    /// <summary>
    /// Posts a positive item-journal adjustment to seed inventory at a location.
    /// </summary>
    internal procedure CreatePositiveAdjustment(ItemNo: Code[20]; LocationCode: Code[10]; Qty: Decimal)
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
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    /// <summary>
    /// Creates a Transfer Order header with the specified locations.
    /// </summary>
    internal procedure CreateTransferHeader(
        var TransferHeader: Record "Transfer Header";
        FromLocationCode: Code[10];
        ToLocationCode: Code[10];
        InTransitLocationCode: Code[10])
    begin
        LibraryWarehouse.CreateTransferHeader(TransferHeader, FromLocationCode, ToLocationCode, InTransitLocationCode);
    end;

    /// <summary>
    /// Creates a Transfer Order line.
    /// </summary>
    internal procedure CreateTransferLine(
        var TransferHeader: Record "Transfer Header";
        ItemNo: Code[20];
        Qty: Decimal)
    var
        TransferLine: Record "Transfer Line";
    begin
        LibraryWarehouse.CreateTransferLine(TransferHeader, TransferLine, ItemNo, Qty);
    end;

    /// <summary>
    /// Dispatches a Bifrost message through the public dispatcher and returns the parsed JSON response.
    /// </summary>
    internal procedure ProcessMessage(MessageType: Enum "Message Type ori"; RequestJson: JsonObject; var ResponseJson: JsonObject)
    begin
        ProcessMessage(MessageType, '', RequestJson, ResponseJson);
    end;

    /// <summary>
    /// Dispatches a Bifrost message with a subject through the public dispatcher.
    /// The subject is the document number when the message type reads it from there.
    /// </summary>
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
