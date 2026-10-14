namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Purchases.Document;
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

    /// <summary>Unreadable company setup makes discovery false and execution a structured permission refusal.</summary>
    [Test]
    procedure UnreadableSetupRefusesWithoutLeakingDomainState()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument);
        LowerPermissions.PushPermissionSetWithoutDefaults('Inv Source Deny Test');
        Assert.IsFalse(Setup.ReadPermission(), 'The caller really lacks company-setup read permission.');

        Assert.IsFalse(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Sales Line", false, false), 'Discovery must not throw or disclose an unreadable domain.');
        Assert.IsFalse(DomainGate.AssertEnabled(TempArgument, "Inventory Domain ori"::Reservations, Database::"Sales Line", false, false), 'Execution must refuse before accessing setup.');

        AssertPermissionDenied(TempArgument);
    end;

    /// <summary>A native document tracking read succeeds under read-only permissions and preserves its source.</summary>
    [Test]
    procedure Scenario_AC1_ReadOnlyCallerReadsDocumentTracking()
    begin
        AssertReadOnlyTracking(false);
    end;

    /// <summary>A native posted-item tracking read and availability rollup need no write or posting rights.</summary>
    [Test]
    procedure Scenario_AC2_AC4_ReadOnlyCallerReadsStockAvailability()
    begin
        AssertReadOnlyTracking(true);
    end;

    local procedure AssertReadOnlyTracking(PostedStock: Boolean)
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Ledger: Record "Item Ledger Entry";
        Specification: Record "Tracking Specification";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        EntryCount: Integer;
        LedgerCount: Integer;
        SpecificationCount: Integer;
        ItemModifiedAt: DateTime;
        LineModifiedAt: DateTime;
    begin
        // Story #5 AC01/AC02/AC04 | Time: WorkDate() native receipt | Risk: native reads are not licensed MCP.
        CreateOwnedTracking(PurchaseLine, PostedStock);
        Item.Get(PurchaseLine."No.");
        ItemModifiedAt := Item.SystemModifiedAt;
        LineModifiedAt := PurchaseLine.SystemModifiedAt;
        EntryCount := Entry.Count();
        LedgerCount := Ledger.Count();
        SpecificationCount := Specification.Count();
        if PostedStock then
            Request.Add('itemNo', Item."No.")
        else begin
            Request.Add('documentType', 'Purchase.Order');
            Request.Add('documentNo', PurchaseLine."Document No.");
            Request.Add('lineNo', PurchaseLine."Line No.");
        end;
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('D365 READ');
        Assert.IsTrue(Item.ReadPermission() and PurchaseLine.ReadPermission() and Entry.ReadPermission() and Ledger.ReadPermission() and Specification.ReadPermission(), 'Native read permissions are actually granted.');
        Assert.IsFalse(Item.WritePermission() or PurchaseLine.WritePermission() or Entry.WritePermission() or Ledger.WritePermission() or Specification.WritePermission(), 'Read-only caller has no native table write permission.');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'Tracking reads do not gain posting permission.');

        TrackingRead.ReadTracking(TempArgument);
        AssertOwnedReadRow(TempArgument, 'trackingLines', 'quantityBase', 2);
        if PostedStock then begin
            TrackingRead.ReadAvailability(TempArgument);
            AssertOwnedReadRow(TempArgument, 'availability', 'inventory', 2);
            AssertOwnedReadRow(TempArgument, 'availability', 'qtyReserved', 0);
            AssertOwnedReadRow(TempArgument, 'availability', 'availableQuantity', 2);
        end;

        Assert.AreEqual(EntryCount, Entry.Count(), 'Read-only calls leave reservation count unchanged.');
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'Read-only calls leave ledger count unchanged.');
        Assert.AreEqual(SpecificationCount, Specification.Count(), 'Read-only calls leave specification count unchanged.');
        Item.Get(Item."No.");
        Assert.AreEqual(ItemModifiedAt, Item.SystemModifiedAt, 'Read-only calls leave the item unchanged.');
        if not PostedStock then begin
            PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
            Assert.AreEqual(LineModifiedAt, PurchaseLine.SystemModifiedAt, 'Document read leaves the source unchanged.');
        end;
    end;

    local procedure CreateOwnedTracking(var PurchaseLine: Record "Purchase Line"; PostedStock: Boolean)
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        PurchaseHeader: Record "Purchase Header";
        TempArgument: Record "Message Argument ori" temporary;
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
        Source: JsonObject;
        Request: JsonObject;
        Tracking: JsonObject;
        Entries: JsonArray;
    begin
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode."Lot Specific Tracking" := true;
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        Source.Add('type', 'PurchaseLine');
        Source.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        Request.Add('source', Source);
        Tracking.Add('lotNo', 'READ-ONLY-LOT');
        Tracking.Add('quantity', 2);
        Entries.Add(Tracking);
        Request.Add('entries', Entries);
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        TrackingWrite.Run(TempArgument);
        AssertOwnedReadRowAfterAssignment(TempArgument);
        if PostedStock then
            LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, true);
    end;

    local procedure AssertOwnedReadRowAfterAssignment(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Response := Argument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Owned native fixture assignment must succeed. ' + Argument.GetResponseText());
    end;

    local procedure AssertOwnedReadRow(var Argument: Record "Message Argument ori"; ArrayName: Text; QuantityName: Text; ExpectedQuantity: Decimal)
    var
        Response: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        Rows: JsonArray;
    begin
        Response := Argument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Read-only native call succeeds. ' + Argument.GetResponseText());
        Response.Get(ArrayName, Token);
        Rows := Token.AsArray();
        Assert.AreEqual(1, Rows.Count(), 'Only the owned lot is returned.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Row.Get('lotNo', Token);
        Assert.AreEqual('READ-ONLY-LOT', Token.AsValue().AsText(), 'Native tracking identity reaches the read-only caller.');
        Row.Get(QuantityName, Token);
        Assert.AreEqual(ExpectedQuantity, Token.AsValue().AsDecimal(), 'Native quantity reaches the read-only caller.');
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
