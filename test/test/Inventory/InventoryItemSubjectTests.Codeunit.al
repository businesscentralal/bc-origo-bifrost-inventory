namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.Reservation.Get and Inventory.Cost.Get treat subject as the item number.
/// </summary>
codeunit 96931 "Inventory Item Subject Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    procedure CostGet_SubjectAndDifferentItemNo_ReturnsConflict()
    var
        ItemA: Record Item;
        ItemB: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        LibraryInventory.CreateItem(ItemA);
        LibraryInventory.CreateItem(ItemB);
        RequestJson.Add('itemNo', ItemB."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Cost.Get", ItemA."No.", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('ConflictingIdentifiers', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('itemNo', Token.AsValue().AsText(), 'parameter');
        Assert.IsTrue(ResponseJson.Get('expected', Token), 'expected missing');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'expected');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'nextStep');
    end;

    [Test]
    procedure CostGet_Subject_ReturnsThatItem()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        LibraryInventory.CreateItem(Item);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Cost.Get", Item."No.", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'status');
        Assert.IsTrue(ResponseJson.Get('itemNo', Token), 'itemNo missing');
        Assert.AreEqual(Item."No.", Token.AsValue().AsText(), 'itemNo');
    end;

    [Test]
    procedure CostGet_MissingItemNoAndSubject_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        Helper.ProcessMessage("Message Type ori"::"Inventory.Cost.Get", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('itemNo', Token.AsValue().AsText(), 'parameter');
        Assert.IsTrue(ResponseJson.Get('expected', Token), 'expected missing');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'expected');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'nextStep');
    end;

    [Test]
    procedure ReservationGet_Subject_ExcludesOtherItems()
    var
        ItemA: Record Item;
        ItemB: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        Entry: JsonObject;
        Token: JsonToken;
        Index: Integer;
        SawItemA: Boolean;
    begin
        LibraryInventory.CreateItem(ItemA);
        LibraryInventory.CreateItem(ItemB);
        InsertReservation(ItemA."No.", 'INVSUBJA');
        InsertReservation(ItemB."No.", 'INVSUBJB');
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Get", ItemA."No.", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'status');
        Assert.IsTrue(ResponseJson.Get('entries', Token), 'entries missing');
        Entries := Token.AsArray();
        Assert.IsTrue(Entries.Count() > 0, 'subject returns the item reservation');
        for Index := 0 to Entries.Count() - 1 do begin
            Entries.Get(Index, Token);
            Entry := Token.AsObject();
            Assert.IsTrue(Entry.Get('itemNo', Token), 'entry itemNo');
            Assert.AreEqual(ItemA."No.", Token.AsValue().AsText(), 'subject must not return another item');
            if Entry.Get('sourceId', Token) then
                if Token.AsValue().AsText() = 'INVSUBJA' then
                    SawItemA := true;
        end;
        Assert.IsTrue(SawItemA, 'the reservation created for the subject item is returned');
    end;

    local procedure InsertReservation(ItemNo: Code[20]; SourceId: Code[20])
    var
        ReservationEntry: Record "Reservation Entry";
        NextEntryNo: Integer;
    begin
        if ReservationEntry.FindLast() then
            NextEntryNo := ReservationEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        ReservationEntry.Init();
        ReservationEntry."Entry No." := NextEntryNo;
        ReservationEntry.Positive := true;
        ReservationEntry."Item No." := ItemNo;
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Reservation;
        ReservationEntry."Source Type" := Database::"Sales Line";
        ReservationEntry."Source Subtype" := 1;
        ReservationEntry."Source ID" := SourceId;
        ReservationEntry."Source Ref. No." := 10000;
        ReservationEntry.Quantity := 1;
        ReservationEntry."Quantity (Base)" := 1;
        ReservationEntry.Insert(false);
    end;
}
