namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Missing itemNo on Inventory.Cost.Get and Inventory.TrackingAvailability.Get
/// returns MissingParameter in en-US and is-IS.
/// </summary>
codeunit 96922 "Inventory Item Refusal Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    procedure CostGet_MissingItemNo_IsMissingParameterIn1033()
    begin
        AssertMissing("Message Type ori"::"Inventory.Cost.Get", 1033, 'itemNo is required.', 'A non-empty item number in data.itemNo.', 'Send the item number in data.itemNo.');
    end;

    [Test]
    procedure CostGet_MissingItemNo_IsMissingParameterIn1039()
    begin
        AssertMissing("Message Type ori"::"Inventory.Cost.Get", 1039, 'itemNo er nauðsynlegt.', 'Ótómt vörunúmer í data.itemNo.', 'Sendu vörunúmerið í data.itemNo.');
    end;

    [Test]
    procedure TrackingGet_MissingItemNo_IsMissingParameterIn1033()
    begin
        AssertMissing("Message Type ori"::"Inventory.TrackingAvailability.Get", 1033, 'itemNo must be specified.', 'A non-empty item number in data.itemNo.', 'Send the item number in data.itemNo.');
    end;

    [Test]
    procedure TrackingGet_MissingItemNo_IsMissingParameterIn1039()
    begin
        AssertMissing("Message Type ori"::"Inventory.TrackingAvailability.Get", 1039, 'itemNo verður að vera tilgreint.', 'Ótómt vörunúmer í data.itemNo.', 'Sendu vörunúmerið í data.itemNo.');
    end;

    local procedure AssertMissing(MessageType: Enum "Message Type ori"; LanguageId: Integer; ExpectedError: Text; ExpectedExpected: Text; ExpectedNext: Text)
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage(MessageType, RequestJson, ResponseJson);
        GlobalLanguage(PreviousLanguage);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'status');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('MissingParameter', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual('itemNo', Token.AsValue().AsText(), 'parameter');
        Assert.IsTrue(ResponseJson.Get('error', Token), 'error missing');
        Assert.AreEqual(ExpectedError, Token.AsValue().AsText(), 'error');
        Assert.IsTrue(ResponseJson.Get('expected', Token), 'expected missing');
        Assert.AreEqual(ExpectedExpected, Token.AsValue().AsText(), 'expected');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.AreEqual(ExpectedNext, Token.AsValue().AsText(), 'nextStep');
    end;
}
