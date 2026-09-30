namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.Create message type.
/// </summary>
codeunit 96913 "Transfer Order Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then exit;
        IsInitialized := true;
    end;

    [Test]
    procedure Create_AllRequiredFields_ReturnsSuccess()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        DocumentNoToken, StatusToken : JsonToken;
    begin
        // [SCENARIO] Create a transfer order with all required fields
        Initialize();

        // [GIVEN] Locations and an item exist
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);

        // [GIVEN] A Create message with all required fields
        RequestJson.Add('transferFromCode', FromLocation.Code);
        RequestJson.Add('transferToCode', ToLocation.Code);
        RequestJson.Add('inTransitCode', InTransitLocation.Code);

        // [WHEN] Task runs
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Create", RequestJson, ResponseJson);

        // [THEN] Response is Success and a Transfer Header exists
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('documentNo', DocumentNoToken), 'documentNo missing');
        Assert.IsTrue(TransferHeader.Get(DocumentNoToken.AsValue().AsCode()), 'Transfer Header should exist');
        Assert.AreEqual(FromLocation.Code, TransferHeader."Transfer-from Code", 'From location mismatch');
        Assert.AreEqual(ToLocation.Code, TransferHeader."Transfer-to Code", 'To location mismatch');
    end;

    [Test]
    procedure Create_MissingFromCode_ReturnsError()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Missing transferFromCode produces an Error response
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);

        RequestJson.Add('transferToCode', ToLocation.Code);
        RequestJson.Add('inTransitCode', InTransitLocation.Code);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Create", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
        Assert.IsTrue(ResponseJson.Get('code', StatusToken), 'code missing');
        Assert.AreEqual('MissingParameter', StatusToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', StatusToken), 'parameter missing');
        Assert.AreEqual('transferFromCode', StatusToken.AsValue().AsText(), 'parameter');
    end;

    [Test]
    procedure Create_WithItemLine_ReturnsLineAndQuantityTotal()
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        TransferLine: Record "Transfer Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        LineJson: JsonObject;
        LinesToken: JsonToken;
        LineToken: JsonToken;
        ValueToken: JsonToken;
        TotalsToken: JsonToken;
        TotalsObject: JsonObject;
        LinesArray: JsonArray;
        DocumentNo: Code[20];
    begin
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);
        LineJson.Add('itemNo', Item."No.");
        LineJson.Add('quantity', 4);
        Lines.Add(LineJson);
        RequestJson.Add('transferFromCode', FromLocation.Code);
        RequestJson.Add('transferToCode', ToLocation.Code);
        RequestJson.Add('inTransitCode', InTransitLocation.Code);
        RequestJson.Add('lines', Lines);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Create", RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('lines', LinesToken), 'Response should contain lines');
        LinesArray := LinesToken.AsArray();
        LinesArray.Get(0, LineToken);
        LineToken.AsObject().Get('lineNo', ValueToken);
        Assert.AreEqual(10000, ValueToken.AsValue().AsInteger(), 'Line number');
        LineToken.AsObject().Get('itemNo', ValueToken);
        Assert.AreEqual(Item."No.", ValueToken.AsValue().AsText(), 'Item no.');
        LineToken.AsObject().Get('description', ValueToken);
        Assert.AreEqual(Item.Description, ValueToken.AsValue().AsText(), 'Description from the item');
        Assert.IsTrue(ResponseJson.Get('totals', TotalsToken), 'Response should contain totals');
        TotalsObject := TotalsToken.AsObject();
        TotalsObject.Get('quantity', ValueToken);
        Assert.AreEqual(4, ValueToken.AsValue().AsDecimal(), 'Quantity total');
        ResponseJson.Get('documentNo', ValueToken);
        DocumentNo := CopyStr(ValueToken.AsValue().AsCode(), 1, MaxStrLen(DocumentNo));
        TransferLine.SetRange("Document No.", DocumentNo);
        Assert.AreEqual(1, TransferLine.Count(), 'One transfer line stored');
    end;

    [Test]
    procedure Create_BadLines_ReturnsEveryProblemAndNoHeader()
    var
        TransferHeader: Record "Transfer Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        Line1: JsonObject;
        Line2: JsonObject;
        ErrorToken: JsonToken;
        ErrorText: Text;
        HeaderCount: Integer;
    begin
        Initialize();
        HeaderCount := TransferHeader.Count();
        Line1.Add('itemNo', 'NO-SUCH-ITEM');
        Line1.Add('quantity', 1);
        Line2.Add('itemNo', 'ALSO-MISSING');
        Line2.Add('quantity', 'abc');
        Lines.Add(Line1);
        Lines.Add(Line2);
        RequestJson.Add('transferFromCode', 'FROM');
        RequestJson.Add('transferToCode', 'TO');
        RequestJson.Add('inTransitCode', 'TRANSIT');
        RequestJson.Add('lines', Lines);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Create", RequestJson, ResponseJson);
        ResponseJson.Get('error', ErrorToken);
        ResponseJson.WriteTo(ErrorText); // lines[n] is the "parameter" of each entry
        Assert.IsTrue(StrPos(ErrorText, 'lines[1].itemNo') > 0, ErrorText);
        Assert.IsTrue(StrPos(ErrorText, 'lines[2].quantity') > 0, ErrorText);
        Assert.IsTrue(StrPos(ErrorText, 'is not a number') > 0, ErrorText);
        Assert.AreEqual(HeaderCount, TransferHeader.Count(), 'No transfer header created');
    end;

    [Test]
    procedure Create_WithoutLines_OmitsLinesFromResponse()
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
    begin
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);
        RequestJson.Add('transferFromCode', FromLocation.Code);
        RequestJson.Add('transferToCode', ToLocation.Code);
        RequestJson.Add('inTransitCode', InTransitLocation.Code);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Create", RequestJson, ResponseJson);
        ResponseJson.Get('status', StatusToken);
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status');
        Assert.IsFalse(ResponseJson.Contains('lines'), 'Header-only response has no lines');
    end;
}
