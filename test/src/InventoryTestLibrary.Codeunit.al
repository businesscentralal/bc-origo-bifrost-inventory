namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Shared Initialize / fixture helpers for Bifrost Inventory tests.
/// </summary>
codeunit 96902 "Inventory Test Library ori"
{
    Access = Internal;

    var
        Assert: Codeunit "Library Assert";
        IsInitialized: Boolean;

    /// <summary>One-time test company setup.</summary>
    procedure Initialize()
    begin
        if IsInitialized then
            exit;
        IsInitialized := true;
    end;

    /// <summary>Dispatches a message type via Foundation Dispatcher and returns the response JSON.</summary>
    procedure ExecuteType(MessageType: Enum "Message Type ori"; Subject: Text[250]; RequestJson: JsonObject; OmitCommit: Boolean) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[50];
        MessageVersion: Enum "Message Version ori";
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.Execute(MessageType, MessageVersion::"1.0", Subject, '', 'application/json', RequestContent, ResponseContent, ResponseContentType, OmitCommit);
        ResponseContent.GetSubText(ResponseText, 1);
        if ResponseText <> '' then
            ResponseJson.ReadFrom(ResponseText);
    end;

    /// <summary>Creates a unique Option attribute with two option values.</summary>
    procedure CreateOptionAttribute(NamePrefix: Text; var ItemAttribute: Record "Item Attribute"; var ValueA: Record "Item Attribute Value"; var ValueB: Record "Item Attribute Value")
    var
        UniqueName: Text[250];
    begin
        UniqueName := CopyStr(NamePrefix + Format(CreateGuid(), 0, 4), 1, MaxStrLen(UniqueName));
        ItemAttribute.Init();
        ItemAttribute.Validate(Name, UniqueName);
        ItemAttribute.Validate(Type, ItemAttribute.Type::Option);
        ItemAttribute.Insert(true);

        ValueA.Init();
        ValueA."Attribute ID" := ItemAttribute.ID;
        ValueA.Validate(Value, 'Blue');
        ValueA.Insert(true);

        ValueB.Init();
        ValueB."Attribute ID" := ItemAttribute.ID;
        ValueB.Validate(Value, 'Red');
        ValueB.Insert(true);
    end;

    /// <summary>Finds any non-blocked Inventory item, or creates a minimal one.</summary>
    procedure EnsureInventoryItem(var Item: Record Item)
    begin
        Item.Reset();
        Item.SetLoadFields("No.", SystemId, Blocked, Type);
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Inventory);
        if Item.FindFirst() then
            exit;
        Item.Init();
        Item.Validate("No.", CopyStr('BI' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Item."No.")));
        Item.Validate(Description, 'Bifrost Inventory Test Item');
        Item.Insert(true);
    end;

    /// <summary>Finds or creates a Service-type item for AC-6.</summary>
    procedure EnsureServiceItem(var Item: Record Item)
    begin
        Item.Reset();
        Item.SetLoadFields("No.", SystemId, Blocked, Type);
        Item.SetRange(Blocked, false);
        Item.SetRange(Type, Item.Type::Service);
        if Item.FindFirst() then
            exit;
        Item.Init();
        Item.Validate("No.", CopyStr('BS' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Item."No.")));
        Item.Validate(Description, 'Bifrost Inventory Service Item');
        Item.Validate(Type, Item.Type::Service);
        Item.Insert(true);
    end;

    /// <summary>Asserts response status equals expected.</summary>
    procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    var
        StatusToken: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'Response missing status');
        Assert.AreEqual(Expected, StatusToken.AsValue().AsText(), 'Unexpected status');
    end;
}
