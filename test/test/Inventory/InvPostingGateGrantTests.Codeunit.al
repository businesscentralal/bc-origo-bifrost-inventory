namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Grant path for the inventory posting gate.
/// Same lowered sets as the deny path, plus BIFROST InvPost ori.
/// Both Post implementations are then enabled and AssertCanPost writes no error.
/// </summary>
codeunit 96919 "Inv. Posting Gate Grant Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AssemblyUndo_WithInvPost_EnforcesGate()
    var
        Header: Record "Posted Assembly Header";
        Impl: Codeunit "Assembly Undo Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerToInvPost(LibraryLowerPermissions);
        Assert.IsTrue(Header.WritePermission(), 'Document access must be present before checking the posting token.');
        Assert.IsTrue(Impl.IsEnabled(), 'Undo posts reversing entries and requires the posting token.');
    end;

    [Test]
    procedure TransferUndoShipment_WithInvPost_EnforcesGate()
    var
        Header: Record "Transfer Shipment Header";
        Impl: Codeunit "Transfer Undo Shpt Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerToInvPost(LibraryLowerPermissions);
        Assert.IsTrue(Header.WritePermission(), 'Document access must be present before checking the posting token.');
        Assert.IsTrue(Impl.IsEnabled(), 'Undo posts reversing entries and requires the posting token.');
    end;

    [Test]
    procedure TransferPost_WithInvPost_IsEnabled()
    var
        TransferHeader: Record "Transfer Header";
        PostImpl: Codeunit "Transfer Order Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] TransferOrder.Post is enabled when the caller can write the inventory posting token.
        LowerToInvPost(LibraryLowerPermissions);
        Assert.IsTrue(TransferHeader.WritePermission(), 'Transfer Header write must be present so IsEnabled tests the gate');
        Assert.IsTrue(PostImpl.IsEnabled(), 'Transfer post should be enabled with BIFROST InvPost ori');
    end;

    [Test]
    procedure AssemblyPost_WithInvPost_IsEnabled()
    var
        AssemblyHeader: Record "Assembly Header";
        PostImpl: Codeunit "Assembly Order Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] AssemblyOrder.Post is enabled when the caller can write the inventory posting token.
        LowerToInvPost(LibraryLowerPermissions);
        Assert.IsTrue(AssemblyHeader.WritePermission(), 'Assembly Header write must be present so IsEnabled tests the gate');
        Assert.IsTrue(PostImpl.IsEnabled(), 'Assembly post should be enabled with BIFROST InvPost ori');
    end;

    [Test]
    procedure HasPostingPermission_WithInvPost_IsTrue()
    var
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerToInvPost(LibraryLowerPermissions);
        Assert.IsTrue(PostingGate.HasPostingPermission(), 'HasPostingPermission should be true with the token');
    end;

    [Test]
    procedure AssertCanPost_WithInvPost_WritesNoError()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] A granted caller passes the gate and the argument is left unchanged.
        LowerToInvPost(LibraryLowerPermissions);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);

        Assert.IsTrue(PostingGate.AssertCanPost(TempArgument), 'AssertCanPost should allow the token');
        Assert.AreEqual(0, TempArgument.GetResponseContentLength(), 'AssertCanPost must not write an error');
    end;

    local procedure LowerToInvPost(var LibraryLowerPermissions: Codeunit "Library - Lower Permissions")
    begin
        // Restrictive tests start as D365 Full Access until this library replaces that set.
        LibraryLowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LibraryLowerPermissions.AddPermissionSet('Inv Post Gate Test');
        LibraryLowerPermissions.AddPermissionSet('BIFROST InvPost ori');
    end;
}
