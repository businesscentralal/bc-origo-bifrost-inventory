namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 6 permission boundaries using actual restricted callers and Foundation's native item posting capability.</summary>
codeunit 96945 "Inventory Physical Perm Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        DomainSetup: Codeunit "Inventory Test Library ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Native journal write rights alone never enable physical posting.</summary>
    [Test]
    procedure Scenario_AC07_JournalWriterWithoutItemPost_IsDenied()
    var
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        NativeJournal: Codeunit "Inventory Native Journal ori";
        PostImpl: Codeunit "Phys. Invt. Post Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] An actual journal writer without the Foundation item-posting token.
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerToNativeWriter(LowerPermissions);
        Assert.IsTrue(Line.WritePermission(), 'Native journal write permission is present.');

        // [WHEN] The native capability and shipping discovery gate are evaluated.
        Assert.IsFalse(NativeJournal.HasItemPostingPermission(), 'Journal rights alone do not grant item posting.');
        Assert.IsFalse(PostImpl.IsEnabled(), 'Physical Post stays disabled without BIFROST ItemPost ori.');
        Assert.IsFalse(NativeJournal.AssertItemPostingPermission(TempArgument), 'Native guard refuses before any journal write.');

        // [THEN] The refusal is typed and names the required existing permission set.
        Response := TempArgument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Posting denial uses the public permission code.');
        Assert.IsTrue(TempArgument.GetResponseText().Contains('BIFROST ItemPost ori'), 'Refusal identifies the existing item-posting capability.');
    end;

    /// <summary>The existing item-posting token enables the physical posting adapter.</summary>
    [Test]
    procedure Scenario_AC07_JournalWriterWithItemPost_IsEnabled()
    var
        NativeJournal: Codeunit "Inventory Native Journal ori";
        PostImpl: Codeunit "Phys. Invt. Post Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] The same native journal writer receives the existing Foundation capability.
        LowerToNativeWriter(LowerPermissions);
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');

        // [WHEN/THEN] Both the native adapter and shipping discovery gate enable posting.
        Assert.IsTrue(NativeJournal.HasItemPostingPermission(), 'Existing BIFROST ItemPost ori supplies the native capability.');
        Assert.IsTrue(PostImpl.IsEnabled(), 'Physical Post uses the Foundation item capability, with no new posting token.');
    end;

    /// <summary>Preview uses the same existing posting capability as Foundation ItemJournal.PreviewPost.</summary>
    [Test]
    procedure Scenario_AC07_PreviewMirrorsFoundationItemPostGate()
    var
        NativeJournal: Codeunit "Inventory Native Journal ori";
        PreviewImpl: Codeunit "Phys. Inv. Preview Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] A native journal writer has no posting token.
        LowerToNativeWriter(LowerPermissions);
        Assert.IsFalse(NativeJournal.HasItemPostingPermission(), 'The test caller has no item-posting capability.');

        // [WHEN/THEN] Foundation preview requires the existing item-posting capability too.
        Assert.IsFalse(PreviewImpl.IsEnabled(), 'Preview mirrors Foundation ItemJournal.PreviewPost permission denial.');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'The existing Foundation capability enables physical preview.');
    end;

    local procedure LowerToNativeWriter(var LowerPermissions: Codeunit "Library - Lower Permissions")
    begin
        // Prepare the company toggle before restoring the exact restricted caller below.
        LowerPermissions.SetOutsideO365Scope();
        DomainSetup.EnablePhysicalInventory();
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Phys Native Test');
    end;
}
