namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Grant path for the inventory posting gate. The caller holds tabledata on Inv. Posting ori,
/// so both Post implementations are enabled and AssertCanPost writes no error.
/// </summary>
codeunit 96919 "Inv. Posting Gate Grant Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata "Inv. Posting ori" = RIMD,
        tabledata "Transfer Header" = RIMD,
        tabledata "Assembly Header" = RIMD,
        codeunit "Transfer Order Post Impl ori" = X,
        codeunit "Assembly Order Post Impl ori" = X,
        codeunit "Inv. Posting Gate ori" = X;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure TransferPost_WithInvPost_IsEnabled()
    var
        PostImpl: Codeunit "Transfer Order Post Impl ori";
    begin
        // [SCENARIO] TransferOrder.Post is enabled when the caller can write the inventory posting token.
        Assert.IsTrue(PostImpl.IsEnabled(), 'Transfer post should be enabled with BIFROST InvPost ori');
    end;

    [Test]
    procedure AssemblyPost_WithInvPost_IsEnabled()
    var
        PostImpl: Codeunit "Assembly Order Post Impl ori";
    begin
        // [SCENARIO] AssemblyOrder.Post is enabled when the caller can write the inventory posting token.
        Assert.IsTrue(PostImpl.IsEnabled(), 'Assembly post should be enabled with BIFROST InvPost ori');
    end;

    [Test]
    procedure HasPostingPermission_WithInvPost_IsTrue()
    var
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        Assert.IsTrue(PostingGate.HasPostingPermission(), 'HasPostingPermission should be true with the token');
    end;

    [Test]
    procedure AssertCanPost_WithInvPost_WritesNoError()
    var
        Argument: Record "Message Argument ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        // [SCENARIO] A granted caller passes the gate and the argument is left unchanged.
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);

        Assert.IsTrue(PostingGate.AssertCanPost(Argument), 'AssertCanPost should allow the token');
        Assert.AreEqual(0, Argument.GetResponseContentLength(), 'AssertCanPost must not write an error');
    end;
}
