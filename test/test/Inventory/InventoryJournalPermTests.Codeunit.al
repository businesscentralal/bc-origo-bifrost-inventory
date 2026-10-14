namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Restricted native callers prove physical posting uses Foundation's existing item-post gate.</summary>
codeunit 96964 "Inventory Journal Perm. Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Native journal writes without ItemPost refuse before licensing or reading a batch.</summary>
    [Test]
    procedure Scenario_AC07_NoItemPostToken_Refuses()
    var
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        PostImpl: Codeunit "Phys. Invt. Post Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
        Token: JsonToken;
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Jnl Write Test');
        Assert.IsTrue(Line.WritePermission(), 'Caller has native journal writes.');
        Assert.IsFalse(PostImpl.IsEnabled(), 'ItemPost token is independently required.');
        PostImpl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Posting permission fails before licensing.');
    end;

    /// <summary>Foundation ItemPost plus native writes enable physical posting without the unrelated Inventory token.</summary>
    [Test]
    procedure Scenario_AC07_FoundationItemPost_Enables()
    var
        PostImpl: Codeunit "Phys. Invt. Post Impl ori";
        PreviewImpl: Codeunit "Phys. Inv. Preview Impl ori";
        InvGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Jnl Write Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsFalse(InvGate.HasPostingPermission(), 'No unrelated Inventory posting token.');
        Assert.IsTrue(PostImpl.IsEnabled(), 'Native public Foundation gate admits the caller.');
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Preview has the same native posting permission.');
    end;
}
