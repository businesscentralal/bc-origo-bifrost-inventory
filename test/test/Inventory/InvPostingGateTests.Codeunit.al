namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Deny path for the inventory posting gate.
/// The session is lowered to BIFROST Full ori, which already carries InvWrite, plus document-table
/// write, and without BIFROST InvPost ori. Both Post implementations are then disabled and
/// AssertCanPost names BIFROST InvPost ori. PreviewPost stays enabled.
/// </summary>
codeunit 96918 "Inv. Posting Gate Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AssemblyUndo_WithoutInvPost_EnforcesGate()
    var
        Header: Record "Posted Assembly Header";
        Impl: Codeunit "Assembly Undo Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(Header.WritePermission(), 'Document access must be present before checking the posting token.');
        Assert.IsFalse(Impl.IsEnabled(), 'Undo posts reversing entries and requires the posting token.');
    end;

    [Test]
    procedure TransferUndoShipment_WithoutInvPost_EnforcesGate()
    var
        Header: Record "Transfer Shipment Header";
        Impl: Codeunit "Transfer Undo Shpt Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(Header.WritePermission(), 'Document access must be present before checking the posting token.');
        Assert.IsFalse(Impl.IsEnabled(), 'Undo posts reversing entries and requires the posting token.');
    end;

    [Test]
    procedure InventoryRead_PreservesAttributeReadOnlyPermissions()
    var
        ItemAttribute: Record "Item Attribute";
        AttributeValue: Record "Item Attribute Value";
        AttributeMapping: Record "Item Attribute Value Mapping";
        AttributeTranslation: Record "Item Attr. Value Translation";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LibraryLowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        Assert.IsTrue(ItemAttribute.ReadPermission(), 'Read role must retain attribute read.');
        Assert.IsTrue(AttributeValue.ReadPermission(), 'Read role must retain value read.');
        Assert.IsTrue(AttributeMapping.ReadPermission(), 'Read role must retain mapping read.');
        Assert.IsTrue(AttributeTranslation.ReadPermission(), 'Read role must retain translation read.');
        Assert.IsFalse(ItemAttribute.WritePermission(), 'Read role must not gain attribute writes.');
        Assert.IsFalse(AttributeValue.WritePermission(), 'Read role must not gain value writes.');
        Assert.IsFalse(AttributeMapping.WritePermission(), 'Read role must not gain mapping writes.');
        Assert.IsFalse(AttributeTranslation.WritePermission(), 'Read role must not gain translation writes.');
    end;

    [Test]
    procedure InventoryFull_PreservesAttributeWritePermissions()
    var
        ItemAttribute: Record "Item Attribute";
        AttributeValue: Record "Item Attribute Value";
        AttributeMapping: Record "Item Attribute Value Mapping";
        AttributeTranslation: Record "Item Attr. Value Translation";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LibraryLowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        Assert.IsTrue(ItemAttribute.WritePermission(), 'Full role must retain attribute writes.');
        Assert.IsTrue(AttributeValue.WritePermission(), 'Full role must retain value writes.');
        Assert.IsTrue(AttributeMapping.WritePermission(), 'Full role must retain mapping writes.');
        Assert.IsTrue(AttributeTranslation.WritePermission(), 'Full role must retain translation writes.');
    end;

    [Test]
    procedure TransferPost_WithoutInvPost_IsDisabled()
    var
        TransferHeader: Record "Transfer Header";
        PostImpl: Codeunit "Transfer Order Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] TransferOrder.Post is disabled when the caller cannot write the inventory posting token.
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(TransferHeader.WritePermission(), 'Transfer Header write must be present so IsEnabled tests the gate');
        Assert.IsFalse(PostImpl.IsEnabled(), 'Transfer post should be disabled without BIFROST InvPost ori');
    end;

    [Test]
    procedure AssemblyPost_WithoutInvPost_IsDisabled()
    var
        AssemblyHeader: Record "Assembly Header";
        PostImpl: Codeunit "Assembly Order Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] AssemblyOrder.Post is disabled when the caller cannot write the inventory posting token.
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(AssemblyHeader.WritePermission(), 'Assembly Header write must be present so IsEnabled tests the gate');
        Assert.IsFalse(PostImpl.IsEnabled(), 'Assembly post should be disabled without BIFROST InvPost ori');
    end;

    [Test]
    procedure AssertCanPost_WithoutInvPost_NamesInvPostSet()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        ErrorToken: JsonToken;
    begin
        // [SCENARIO] Denial names BIFROST InvPost ori, carries PermissionDenied, and does not mention BIFROST ItemPost ori.
        LowerToInvWrite(LibraryLowerPermissions);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);

        Assert.IsFalse(PostingGate.AssertCanPost(TempArgument), 'AssertCanPost should deny without the token');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'HasPostingPermission should be false without the token');

        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('error', ErrorToken), 'error missing');
        Assert.AreNotEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST InvPost ori'), ErrorToken.AsValue().AsText());
        Assert.AreEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST ItemPost ori'), ErrorToken.AsValue().AsText());
    end;

    [Test]
    procedure TransferPreview_WithoutInvPost_StaysEnabled()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PreviewImpl: Codeunit "Transf Doc Prev. Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] TransferOrder.PreviewPost stays enabled and does not return the posting-denied error.
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Transfer preview should stay enabled without BIFROST InvPost ori');

        PrepareUnlicensedArgument(TempArgument);
        asserterror PreviewImpl.ExecuteBifrostTask(TempArgument);
        Assert.AreNotEqual(0, StrPos(GetLastErrorText(), 'license'), 'Expected the license check, not a posting-gate denial');
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'Posting denied'), 'Preview must not be blocked by the posting gate');
    end;

    [Test]
    procedure AssemblyPreview_WithoutInvPost_StaysEnabled()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PreviewImpl: Codeunit "Asm. Doc Prev. Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] AssemblyOrder.PreviewPost stays enabled and does not return the posting-denied error.
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Assembly preview should stay enabled without BIFROST InvPost ori');

        PrepareUnlicensedArgument(TempArgument);
        asserterror PreviewImpl.ExecuteBifrostTask(TempArgument);
        Assert.AreNotEqual(0, StrPos(GetLastErrorText(), 'license'), 'Expected the license check, not a posting-gate denial');
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'Posting denied'), 'Preview must not be blocked by the posting gate');
    end;

    local procedure LowerToInvWrite(var LibraryLowerPermissions: Codeunit "Library - Lower Permissions")
    begin
        // Restrictive tests start as D365 Full Access until this library replaces that set.
        LibraryLowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LibraryLowerPermissions.AddPermissionSet('Inv Post Gate Test');
    end;

    local procedure PrepareUnlicensedArgument(var TempArgument: Record "Message Argument ori")
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
    end;
}
