namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;
using System.Security.AccessControl;

/// <summary>Exercises Inventory registration when a restricted licence administrator opens Foundation setup.</summary>
codeunit 96972 "Inv. Registration Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    /// <summary>AC02: Setup opens without granting the licence administrator general Bifrost administration.</summary>
    [Test]
    procedure AC02_LicAdm_OpensSetupWithInventoryInstalled()
    var
        BifrostSetup: Record "Setup ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        SetupPage: TestPage "Setup ori";
        HasDirectSetupWrite: Boolean;
        IsSetupEditable: Boolean;
        IsRefreshLicenseVisible: Boolean;
        NotificationRoleId: Code[20];
    begin
        // Story #173 AC02 | Time: independent | Risk: an event subscriber requires extra Execute grants.
        BifrostSetup.InsertIfNotExists();

        NotificationRoleId := CreateNotificationPermissionFixture();
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        // Test-only Foundation/platform access also supports Foundation 28.0.3.530.
        LowerPermissions.AddPermissionSet('Inv Setup Test');
        LowerPermissions.AddPermissionSet(NotificationRoleId);
        HasDirectSetupWrite := BifrostSetup.WritePermission();

        SetupPage.OpenView();
        IsSetupEditable := SetupPage.Editable();
        IsRefreshLicenseVisible := SetupPage.RefreshLicense.Visible();
        SetupPage.Close();
        LowerPermissions.StopLoggingNAVPermissions();
        DeleteNotificationPermissionFixture(NotificationRoleId);

        Assert.IsFalse(HasDirectSetupWrite, 'Licence administration must not grant direct Setup writes.');
        Assert.IsFalse(IsSetupEditable, 'A licence administrator must not become a Bifrost administrator.');
        Assert.IsTrue(IsRefreshLicenseVisible, 'The licence-administrator action remains available.');
    end;

    // Foundation 530 keeps Setup Notifications internal, so another app cannot name it
    // in an AL permission set. Seed one test-owned tenant role instead: Execute on
    // that one Foundation object, no Inventory codeunit, data write or user assignment.
    // The isolated runner rolls this back on failure; successful runs delete it explicitly.
    local procedure CreateNotificationPermissionFixture() RoleId: Code[20]
    var
        TenantPermissionSet: Record "Tenant Permission Set";
        TenantPermission: Record "Tenant Permission";
        EmptyGuid: Guid;
    begin
        RoleId := CopyStr('I173N' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(RoleId));
        TenantPermissionSet.Init();
        TenantPermissionSet."App ID" := EmptyGuid;
        TenantPermissionSet."Role ID" := RoleId;
        TenantPermissionSet.Name := RoleId;
        TenantPermissionSet.Insert();
        TenantPermission.Init();
        TenantPermission."App ID" := EmptyGuid;
        TenantPermission."Role ID" := RoleId;
        TenantPermission."Object Type" := TenantPermission."Object Type"::Codeunit;
        TenantPermission."Object ID" := 10078318; // Foundation Setup Notifications ori, stable at the supported floor.
        TenantPermission."Execute Permission" := TenantPermission."Execute Permission"::Yes;
        TenantPermission.Insert();
    end;

    local procedure DeleteNotificationPermissionFixture(RoleId: Code[20])
    var
        TenantPermissionSet: Record "Tenant Permission Set";
        TenantPermission: Record "Tenant Permission";
        EmptyGuid: Guid;
    begin
        TenantPermission.Get(EmptyGuid, RoleId, TenantPermission."Object Type"::Codeunit, 10078318);
        TenantPermission.Delete();
        TenantPermissionSet.Get(EmptyGuid, RoleId);
        TenantPermissionSet.Delete();
    end;
}
