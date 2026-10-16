namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Native tests for Inventory.Reservation.Create and Inventory.Reservation.Cancel.</summary>
codeunit 96923 "Reservation Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        IsInitialized := true;
    end;

    [Test]
    procedure Create_MissingSourceType_ReturnsError()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ParameterToken: JsonToken;
    begin
        // [SCENARIO] Reservation.Create without a source type does not call AutoReserve.
        Initialize();
        RequestJson.Add('sourceNo', 'TO-NONE');
        RequestJson.Add('sourceLineNo', 10000);
        RequestJson.Add('quantity', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Missing sourceType is an error');
        Assert.IsTrue(ResponseJson.Get('parameter', ParameterToken), 'parameter missing');
        Assert.AreEqual('sourceType', ParameterToken.AsValue().AsText(), 'parameter is sourceType');
    end;

    [Test]
    procedure Create_UnknownSourceLine_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        CodeToken: JsonToken;
    begin
        // [SCENARIO] Reservation.Create against a missing transfer line is RecordNotFound.
        Initialize();
        RequestJson.Add('sourceType', Database::"Transfer Line");
        RequestJson.Add('sourceNo', 'NO-SUCH-TO');
        RequestJson.Add('sourceLineNo', 10000);
        RequestJson.Add('quantity', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Unknown source line is an error');
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('RecordNotFound', CodeToken.AsValue().AsText(), 'code is RecordNotFound');
    end;

    [Test]
    procedure Create_TransferLine_ReturnsEntryAndCancelWorks()
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        EntryToken: JsonToken;
        EntryNo: Integer;
    begin
        // [SCENARIO] Reservation.Create against a transfer line returns an entry that Cancel can remove.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 6);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();

        RequestJson.Add('sourceType', Database::"Transfer Line");
        RequestJson.Add('sourceNo', TransferHeader."No.");
        RequestJson.Add('sourceLineNo', TransferLine."Line No.");
        RequestJson.Add('quantity', 3);
        RequestJson.Add('itemNo', Item."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'create status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Create should reserve against the transfer line. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('entryNo', EntryToken), 'entryNo missing');
        EntryNo := EntryToken.AsValue().AsInteger();
        Assert.AreNotEqual(0, EntryNo, 'entryNo should be populated');
        ReservationEntry.SetRange("Entry No.", EntryNo);
        Assert.IsTrue(ReservationEntry.FindFirst(), 'Reservation entry should exist');

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('entryNo', EntryNo);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'cancel status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Cancel should work on the created entry');
        ReservationEntry.SetRange("Entry No.", EntryNo);
        Assert.IsFalse(ReservationEntry.FindFirst(), 'Reservation entry should be removed');
    end;

    local procedure JsonText(ResponseJson: JsonObject): Text
    var
        TextValue: Text;
    begin
        ResponseJson.WriteTo(TextValue);
        exit(TextValue);
    end;
}
