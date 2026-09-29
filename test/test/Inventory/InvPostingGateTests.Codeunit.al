namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Transfer;
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
        Argument: Record "Message Argument ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        ErrorToken: JsonToken;
    begin
        // [SCENARIO] Denial names BIFROST InvPost ori, carries PermissionDenied, and does not mention BIFROST ItemPost ori.
        LowerToInvWrite(LibraryLowerPermissions);
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);

        Assert.IsFalse(PostingGate.AssertCanPost(Argument), 'AssertCanPost should deny without the token');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'HasPostingPermission should be false without the token');

        ResponseJson := Argument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('error', ErrorToken), 'error missing');
        Assert.AreNotEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST InvPost ori'), ErrorToken.AsValue().AsText());
        Assert.AreEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST ItemPost ori'), ErrorToken.AsValue().AsText());
    end;

    [Test]
    procedure TransferPreview_WithoutInvPost_StaysEnabled()
    var
        Argument: Record "Message Argument ori";
        PreviewImpl: Codeunit "Transf Doc Prev. Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] TransferOrder.PreviewPost stays enabled and does not return the posting-denied error.
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Transfer preview should stay enabled without BIFROST InvPost ori');

        PrepareUnlicensedArgument(Argument);
        asserterror PreviewImpl.ExecuteBifrostTask(Argument);
        Assert.AreNotEqual(0, StrPos(GetLastErrorText(), 'license'), 'Expected the license check, not a posting-gate denial');
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'Posting denied'), 'Preview must not be blocked by the posting gate');
    end;

    [Test]
    procedure AssemblyPreview_WithoutInvPost_StaysEnabled()
    var
        Argument: Record "Message Argument ori";
        PreviewImpl: Codeunit "Asm. Doc Prev. Post Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO] AssemblyOrder.PreviewPost stays enabled and does not return the posting-denied error.
        LowerToInvWrite(LibraryLowerPermissions);
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Assembly preview should stay enabled without BIFROST InvPost ori');

        PrepareUnlicensedArgument(Argument);
        asserterror PreviewImpl.ExecuteBifrostTask(Argument);
        Assert.AreNotEqual(0, StrPos(GetLastErrorText(), 'license'), 'Expected the license check, not a posting-gate denial');
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'Posting denied'), 'Preview must not be blocked by the posting gate');
    end;

    local procedure LowerToInvWrite(var LibraryLowerPermissions: Codeunit "Library - Lower Permissions")
    begin
        // Restrictive tests start as D365 Full Access until this library replaces that set.
        LibraryLowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LibraryLowerPermissions.AddPermissionSet('Inv Post Gate Test');
    end;

    local procedure PrepareUnlicensedArgument(var Argument: Record "Message Argument ori")
    begin
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);
    end;
}
