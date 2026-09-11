namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Registers Bifrost Inventory with Foundation's application registry.
/// No setup page in v1 — SetupPageId is 0.
/// </summary>
codeunit 10036912 "Inventory Registration ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), 0);
    end;
}
