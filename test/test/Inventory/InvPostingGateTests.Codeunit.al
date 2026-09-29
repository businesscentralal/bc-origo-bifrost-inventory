namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Deny path for the inventory posting gate. Restrictive permissions omit Inv. Posting ori,
/// so both Post implementations are disabled and AssertCanPost names BIFROST InvPost ori.
/// PreviewPost stays enabled and does not answer with the posting-denied error.
/// </summary>
codeunit 96918 "Inv. Posting Gate Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata "Transfer Header" = RIMD,
        tabledata "Assembly Header" = RIMD,
        codeunit "Transfer Order Post Impl ori" = X,
        codeunit "Assembly Order Post Impl ori" = X,
        codeunit "Transf Doc Prev. Post Impl ori" = X,
        codeunit "Asm. Doc Prev. Post Impl ori" = X,
        codeunit "Inv. Posting Gate ori" = X;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure TransferPost_WithoutInvPost_IsDisabled()
    var
        PostImpl: Codeunit "Transfer Order Post Impl ori";
    begin
        // [SCENARIO] TransferOrder.Post is disabled when the caller cannot write the inventory posting token.
        Assert.IsFalse(PostImpl.IsEnabled(), 'Transfer post should be disabled without BIFROST InvPost ori');
    end;

    [Test]
    procedure AssemblyPost_WithoutInvPost_IsDisabled()
    var
        PostImpl: Codeunit "Assembly Order Post Impl ori";
    begin
        // [SCENARIO] AssemblyOrder.Post is disabled when the caller cannot write the inventory posting token.
        Assert.IsFalse(PostImpl.IsEnabled(), 'Assembly post should be disabled without BIFROST InvPost ori');
    end;

    [Test]
    procedure AssertCanPost_WithoutInvPost_NamesInvPostSet()
    var
        Argument: Record "Message Argument ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        ResponseJson: JsonObject;
        ErrorToken: JsonToken;
    begin
        // [SCENARIO] Denial names BIFROST InvPost ori and does not mention BIFROST ItemPost ori.
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);

        Assert.IsFalse(PostingGate.AssertCanPost(Argument), 'AssertCanPost should deny without the token');
        Assert.IsFalse(PostingGate.HasPostingPermission(), 'HasPostingPermission should be false without the token');

        ResponseJson := Argument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('error', ErrorToken), 'error missing');
        Assert.AreNotEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST InvPost ori'), ErrorToken.AsValue().AsText());
        Assert.AreEqual(0, StrPos(ErrorToken.AsValue().AsText(), 'BIFROST ItemPost ori'), ErrorToken.AsValue().AsText());
    end;

    [Test]
    procedure TransferPreview_WithoutInvPost_StaysEnabled()
    var
        Argument: Record "Message Argument ori";
        PreviewImpl: Codeunit "Transf Doc Prev. Post Impl ori";
    begin
        // [SCENARIO] TransferOrder.PreviewPost stays enabled and does not return the posting-denied error.
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
    begin
        // [SCENARIO] AssemblyOrder.PreviewPost stays enabled and does not return the posting-denied error.
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Assembly preview should stay enabled without BIFROST InvPost ori');

        PrepareUnlicensedArgument(Argument);
        asserterror PreviewImpl.ExecuteBifrostTask(Argument);
        Assert.AreNotEqual(0, StrPos(GetLastErrorText(), 'license'), 'Expected the license check, not a posting-gate denial');
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'Posting denied'), 'Preview must not be blocked by the posting gate');
    end;

    local procedure PrepareUnlicensedArgument(var Argument: Record "Message Argument ori")
    begin
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);
    end;
}
