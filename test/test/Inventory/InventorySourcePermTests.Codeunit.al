namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Restricted native source and tracking read refusal tests, without any licensed-dispatch bypass.</summary>
codeunit 96929 "Inventory Source Perm. Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Source access is refused by permissions before resolving a potentially foreign SystemId.</summary>
    [Test]
    procedure SourceReadWithoutPermissionReturnsStructuredRefusal()
    var
        SalesLine: Record "Sales Line";
        TempArgument: Record "Message Argument ori" temporary;
        Specification: Record "Tracking Specification";
        Resolver: Codeunit "Inventory Source Resolve ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        Request: JsonObject;
    begin
        InitArgument(TempArgument);
        Request := SourceRequest();
        LowerPermissions.PushPermissionSetWithoutDefaults('Inv Source Deny Test');
        Assert.IsFalse(SalesLine.ReadPermission(), 'The refusal test must actually lack source read permission.');

        Assert.IsFalse(Resolver.Resolve(TempArgument, Request, 'source', false, SourceRef, Specification, Direction), 'Read access must be refused before record lookup.');

        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>A caller with source read permission cannot invoke source tracking writes.</summary>
    [Test]
    procedure SourceReadPermissionDoesNotGrantWrite()
    var
        SalesLine: Record "Sales Line";
        TempArgument: Record "Message Argument ori" temporary;
        Specification: Record "Tracking Specification";
        Resolver: Codeunit "Inventory Source Resolve ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        Request: JsonObject;
    begin
        InitArgument(TempArgument);
        Request := SourceRequest();
        LowerPermissions.PushPermissionSetWithoutDefaults('Inv Source Read Test');
        Assert.IsTrue(SalesLine.ReadPermission(), 'The test has real source read access.');
        Assert.IsFalse(SalesLine.WritePermission(), 'The test must actually lack write access.');

        Assert.IsFalse(Resolver.Resolve(TempArgument, Request, 'source', true, SourceRef, Specification, Direction), 'Read permission cannot authorize a source write.');

        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>Reservation read cannot leak rows to a caller without reservation tabledata read permission.</summary>
    [Test]
    procedure ReservationReadWithoutPermissionReturnsStructuredRefusal()
    var
        Entry: Record "Reservation Entry";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
    begin
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('Inv Source Deny Test');
        Assert.IsFalse(Entry.ReadPermission(), 'The test must actually lack reservation read permission.');

        TrackingRead.ReadReservations(TempArgument);

        AssertPermissionDenied(TempArgument);
    end;

    local procedure SourceRequest() Request: JsonObject
    var
        Source: JsonObject;
    begin
        Source.Add('type', 'SalesLine');
        Source.Add('systemId', Format(CreateGuid(), 0, 4));
        Request.Add('source', Source);
    end;

    local procedure InitArgument(var Argument: Record "Message Argument ori")
    begin
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);
    end;

    local procedure AssertPermissionDenied(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        Response := Argument.GetResponseJson();
        Response.WriteTo(Serialized);
        Assert.IsTrue(Response.Get('status', Token), Serialized);
        Assert.AreEqual('Error', Token.AsValue().AsText(), Serialized);
        Assert.IsTrue(Serialized.Contains('PermissionDenied'), 'Permission refusal must not be disguised as missing record. ' + Serialized);
    end;
}
