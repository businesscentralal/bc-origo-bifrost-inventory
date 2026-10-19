namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Exercises strict lookup failures through the shipping message dispatcher.</summary>
codeunit 96923 "Inv. Lookup Format Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    /// <summary>Transfer rejects ArrayData before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_ArrayData_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '[]');
        AssertLookupError(Response, 'InvalidParameterFormat', 'data', 'a JSON object');
    end;

    /// <summary>Transfer rejects InvalidJson before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_InvalidJson_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', 'not json');
        AssertLookupError(Response, 'InvalidParameterFormat', 'data', 'a JSON object');
    end;

    /// <summary>Transfer rejects ObjectIdentifier before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_ObjectIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":{}}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', '{}');
    end;

    /// <summary>Transfer rejects NullIdentifier before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_NullIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":null}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', 'null');
    end;

    /// <summary>Transfer rejects NumericIdentifier before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_NumericIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":123}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', '123');
    end;

    /// <summary>Transfer rejects ArrayIdentifier before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_ArrayIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":[]}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', '[]');
    end;

    /// <summary>Transfer rejects BooleanIdentifier before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_BooleanIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":true}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', 'true');
    end;

    /// <summary>Transfer rejects NullSystemId before returning any statistics.</summary>
    [Test]
    procedure TransferStatistics_NullSystemId_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"systemId":null}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'systemId', 'a JSON string');
        AssertText(Response, 'received', 'null');
    end;

    /// <summary>Transfer aggregates wrong keys in Foundation read order.</summary>
    [Test]
    procedure TransferStatistics_TwoWrongKeys_OrderedErrors()
    var
        Response: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        Errors: JsonArray;
    begin
        // [GIVEN] Reversed payload key order; [WHEN] dispatch; [THEN] systemId precedes documentNo.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":[],"systemId":{}}');
        AssertLookupError(Response, 'MultipleErrors', '', '');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected errors');
        Errors := Token.AsArray();
        Assert.AreEqual(2, Errors.Count(), 'Both malformed keys must be reported');
        Errors.Get(0, Entry);
        AssertLookupError(Entry.AsObject(), 'InvalidParameterFormat', 'systemId', 'a JSON string');
        Errors.Get(1, Entry);
        AssertLookupError(Entry.AsObject(), 'InvalidParameterFormat', 'documentNo', 'a JSON string');
    end;

    /// <summary>Transfer keeps an empty string as a missing identifier.</summary>
    [Test]
    procedure TransferStatistics_EmptyIdentifier_MissingParameter()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Empty identifier; [WHEN] dispatch; [THEN] MissingParameter, not a format error.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", '', '{"documentNo":""}');
        AssertLookupError(Response, 'MissingParameter', '', '');
    end;

    /// <summary>Assembly rejects ArrayData before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_ArrayData_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '[]');
        AssertLookupError(Response, 'InvalidParameterFormat', 'data', 'a JSON object');
    end;

    /// <summary>Assembly rejects InvalidJson before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_InvalidJson_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', 'not json');
        AssertLookupError(Response, 'InvalidParameterFormat', 'data', 'a JSON object');
    end;

    /// <summary>Assembly rejects ObjectIdentifier before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_ObjectIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":{}}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', '{}');
    end;

    /// <summary>Assembly rejects NullIdentifier before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_NullIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":null}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', 'null');
    end;

    /// <summary>Assembly rejects NumericIdentifier before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_NumericIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":123}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', '123');
    end;

    /// <summary>Assembly rejects ArrayIdentifier before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_ArrayIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":[]}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', '[]');
    end;

    /// <summary>Assembly rejects BooleanIdentifier before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_BooleanIdentifier_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":true}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        AssertText(Response, 'received', 'true');
    end;

    /// <summary>Assembly rejects NullSystemId before returning any statistics.</summary>
    [Test]
    procedure AssemblyStatistics_NullSystemId_TypedError()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Wrong JSON shape; [WHEN] dispatch; [THEN] precise format error and no totals.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"systemId":null}');
        AssertLookupError(Response, 'InvalidParameterFormat', 'systemId', 'a JSON string');
        AssertText(Response, 'received', 'null');
    end;

    /// <summary>Assembly aggregates wrong keys in Foundation read order.</summary>
    [Test]
    procedure AssemblyStatistics_TwoWrongKeys_OrderedErrors()
    var
        Response: JsonObject;
        Token: JsonToken;
        Entry: JsonToken;
        Errors: JsonArray;
    begin
        // [GIVEN] Reversed payload key order; [WHEN] dispatch; [THEN] systemId precedes documentNo.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":[],"systemId":{}}');
        AssertLookupError(Response, 'MultipleErrors', '', '');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected errors');
        Errors := Token.AsArray();
        Assert.AreEqual(2, Errors.Count(), 'Both malformed keys must be reported');
        Errors.Get(0, Entry);
        AssertLookupError(Entry.AsObject(), 'InvalidParameterFormat', 'systemId', 'a JSON string');
        Errors.Get(1, Entry);
        AssertLookupError(Entry.AsObject(), 'InvalidParameterFormat', 'documentNo', 'a JSON string');
    end;

    /// <summary>Assembly keeps an empty string as a missing identifier.</summary>
    [Test]
    procedure AssemblyStatistics_EmptyIdentifier_MissingParameter()
    var
        Response: JsonObject;
    begin
        // [GIVEN] Empty identifier; [WHEN] dispatch; [THEN] MissingParameter, not a format error.
        Library.Initialize();
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", '', '{"documentNo":""}');
        AssertLookupError(Response, 'MissingParameter', '', '');
    end;

    /// <summary>An existing transfer subject must not mask a malformed explicit identifier.</summary>
    [Test]
    procedure TransferStatistics_ExistingSubjectWrongKey_NoTotals()
    var
        Header: Record "Transfer Header";
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        Helper: Codeunit "Transfer Order Test Helper";
        Response: JsonObject;
    begin
        // [GIVEN] A self-created valid order and subject.
        Library.Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        // [WHEN] An explicit identifier has the wrong type.
        Response := Dispatch("Message Type ori"::"Inventory.TransferOrder.Statistics", Header."No.", '{"documentNo":{}}');
        // [THEN] The subject cannot override validation, and no totals escape.
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        Assert.IsTrue(Header.Get(Header."No."), 'Read failure must preserve the source');
    end;

    /// <summary>An existing assembly subject must not mask a malformed explicit identifier.</summary>
    [Test]
    procedure AssemblyStatistics_ExistingSubjectWrongKey_NoTotals()
    var
        Header: Record "Assembly Header";
        Parent: Record Item;
        Component: Record Item;
        Helper: Codeunit "Assembly Order Test Helper";
        LibraryAssembly: Codeunit "Library - Assembly";
        Response: JsonObject;
    begin
        // [GIVEN] A self-created valid order and subject.
        Library.Initialize();
        Helper.CreateAssemblyItemWithBOM(Parent, Component);
        LibraryAssembly.CreateAssemblyHeader(Header, CalcDate('<1M>', WorkDate()), Parent."No.", '', 1, '');
        // [WHEN] An explicit identifier has the wrong type.
        Response := Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Statistics", Header."No.", '{"documentNo":{}}');
        // [THEN] The subject cannot override validation, and no totals escape.
        AssertLookupError(Response, 'InvalidParameterFormat', 'documentNo', 'a JSON string');
        Assert.IsTrue(Header.Get(Header."Document Type", Header."No."), 'Read failure must preserve the source');
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Subject: Text[250]; Payload: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageId: Guid;
        EmptyTaskId: Guid;
        ResponseTime: Duration;
        ResponseText: Text;
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        RequestContent.AddText(Payload);
        Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", Subject, '', '', RequestContent,
            EmptyTaskId, 0, MessageId, ResponseContent, ResponseContentType, ResponseTime);
        GlobalLanguage(PreviousLanguage);
        ResponseContent.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Shipping response must be a JSON object');
        AssertText(Response, 'status', 'Error');
        Assert.IsFalse(Response.Contains('callstack'), 'Structured refusals must not expose the platform call stack');
    end;

    local procedure AssertLookupError(Response: JsonObject; Code: Text; Parameter: Text; Expected: Text)
    begin
        // Nested collected errors do not carry their own status.
        if Response.Contains('status') then
            AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', Code);
        if Parameter <> '' then
            AssertText(Response, 'parameter', Parameter);
        if Expected <> '' then
            AssertText(Response, 'expected', Expected);
        Assert.IsFalse(Response.Contains('totals'), 'A refused lookup must not return totals');
    end;

    local procedure AssertText(Response: JsonObject; Name: Text; Expected: Text)
    var
        Value: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Value), 'Required field ' + Name);
        Assert.AreEqual(Expected, Value.AsValue().AsText(), 'Exact ' + Name);
    end;
}
