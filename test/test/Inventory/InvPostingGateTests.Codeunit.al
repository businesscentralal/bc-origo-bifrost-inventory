namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Story #20 AC-05. Restrictive permissions omit the Item Posting gate table, so
/// HasPostingPermission is false. Post IsEnabled must then be false. PreviewPost
/// IsEnabled must stay true, and a preview call must not answer with the posting-denied error.
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
        codeunit "Posting Gate ori" = X;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC05_TransferPost_MissingItemPosting_IsDisabled()
    var
        PostImpl: Codeunit "Transfer Order Post Impl ori";
    begin
        // Story #20, AC-05 | Time: none | Risk: None
        // [SCENARIO] TransferOrder.Post is disabled when the user cannot write the Item posting gate.
        Assert.IsFalse(PostImpl.IsEnabled(), 'Transfer post should be disabled without Item posting permission');
    end;

    [Test]
    procedure Scenario_AC05_AssemblyPost_MissingItemPosting_IsDisabled()
    var
        PostImpl: Codeunit "Assembly Order Post Impl ori";
    begin
        // Story #20, AC-05 | Time: none | Risk: None
        // [SCENARIO] AssemblyOrder.Post is disabled when the user cannot write the Item posting gate.
        Assert.IsFalse(PostImpl.IsEnabled(), 'Assembly post should be disabled without Item posting permission');
    end;

    [Test]
    procedure Scenario_AC05_TransferPreview_MissingItemPosting_StillPreviews()
    var
        Argument: Record "Message Argument ori";
        PreviewImpl: Codeunit "Transf Doc Prev. Post Impl ori";
    begin
        // Story #20, AC-05 | Time: none | Risk: None
        // [SCENARIO] TransferOrder.PreviewPost stays enabled and does not return the posting-denied error.
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Transfer preview should stay enabled without Item posting permission');

        PrepareUnlicensedArgument(Argument);
        asserterror PreviewImpl.ExecuteBifrostTask(Argument);
        Assert.AreNotEqual(0, StrPos(GetLastErrorText(), 'license'), 'Expected the license check, not a posting-gate denial');
        Assert.AreEqual(0, StrPos(GetLastErrorText(), 'Posting denied'), 'Preview must not be blocked by the posting gate');
    end;

    [Test]
    procedure Scenario_AC05_AssemblyPreview_MissingItemPosting_StillPreviews()
    var
        Argument: Record "Message Argument ori";
        PreviewImpl: Codeunit "Asm. Doc Prev. Post Impl ori";
    begin
        // Story #20, AC-05 | Time: none | Risk: None
        // [SCENARIO] AssemblyOrder.PreviewPost stays enabled and does not return the posting-denied error.
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Assembly preview should stay enabled without Item posting permission');

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
