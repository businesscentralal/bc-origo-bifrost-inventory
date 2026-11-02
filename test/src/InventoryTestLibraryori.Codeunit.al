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

    /// <summary>Explicitly enables the reservation domain for a test of its independent behavior or permissions.</summary>
    procedure EnableReservations()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Reservations := true;
        Setup.Modify(true);
    end;

    /// <summary>Explicitly enables the physical inventory domain for a test of its independent behavior or permissions.</summary>
    procedure EnablePhysicalInventory()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup."Phys. Inventory" := true;
        Setup.Modify(true);
    end;

    /// <summary>Explicitly enables the item price domain for a test of its independent behavior or permissions.</summary>
    procedure EnableItemPrice()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup."Item Price" := true;
        Setup.Modify(true);
    end;

    /// <summary>Dispatches a message type via Foundation Dispatcher and returns the response JSON.</summary>
    procedure ExecuteType(MessageType: Enum "Message Type ori"; Subject: Text[250]; RequestJson: JsonObject; OmitCommit: Boolean) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
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
        Item.SetLoadFields("No.", SystemId, Blocked, Type, Description);
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
        Item.SetLoadFields("No.", SystemId, Blocked, Type, Description);
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
    /// <summary>Checks actual native success responses against the shipped typed contract, including every returned key.</summary>
    procedure AssertResponseContract(MessageType: Enum "Message Type ori"; Response: JsonObject)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Chapter: JsonObject;
        Field: JsonObject;
        Token: JsonToken;
        Value: JsonToken;
        Fields: JsonArray;
        Keys: List of [Text];
        Names: List of [Text];
        ResponseKey: Text;
        Name: Text;
        JsonType: Text;
        Serialized: Text;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Public contract must exist.');
        Assert.IsTrue(Contract.Get('response', Token), 'Response chapter must exist.');
        Chapter := Token.AsObject();
        Assert.IsTrue(Chapter.Get('fields', Token), 'Response must declare fields, not a sample payload.');
        Fields := Token.AsArray();
        Assert.IsTrue(Fields.Count() > 0, 'Success response schema cannot be empty.');
        foreach Token in Fields do begin
            Field := Token.AsObject();
            Field.Get('name', Value);
            Name := Value.AsValue().AsText();
            Assert.IsFalse(Names.Contains(Name), 'Duplicate response field ' + Name);
            Names.Add(Name);
            Field.Get('type', Value);
            JsonType := Value.AsValue().AsText();
            if Response.Get(Name, Value) then begin
                Value.WriteTo(Serialized);
                case JsonType of
                    'array':
                        Assert.IsTrue(Value.IsArray(), Name + ' must be an array.');
                    'object':
                        Assert.IsTrue(Value.IsObject(), Name + ' must be an object.');
                    'string':
                        Assert.IsTrue(Serialized.StartsWith('"'), Name + ' must be a JSON string.');
                    'boolean':
                        Assert.IsTrue(Serialized in ['true', 'false'], Name + ' must be a JSON Boolean.');
                    'integer', 'decimal', 'number':
                        Assert.IsTrue(Value.IsValue() and not Serialized.StartsWith('"') and not (Serialized in ['true', 'false', 'null']), Name + ' must be a JSON number.');
                    else
                        Assert.Fail('Unsupported response schema type ' + JsonType);
                end;
            end;
        end;
        Keys := Response.Keys();
        foreach ResponseKey in Keys do
            Assert.IsTrue(Names.Contains(ResponseKey), 'Returned key is missing from the public schema: ' + ResponseKey);
    end;
}
