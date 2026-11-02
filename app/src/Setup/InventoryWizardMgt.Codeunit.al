namespace Origo.Bifrost.Inventory;

using System.Apps;
using System.Environment.Configuration;
using System.Media;

/// <summary>Read-only setup inspection and explicit assisted-setup completion. Never changes HTTP, domains or access.</summary>
codeunit 10076927 "Inventory Wizard Mgt ori"
{
    Access = Internal;

    /// <summary>Reads only this extension's HTTP setting. False means the caller cannot inspect it.</summary>
    procedure ReadHttpStatus(var Enabled: Boolean; var CanChange: Boolean): Boolean
    var
        AppSetting: Record "NAV App Setting";
        Module: ModuleInfo;
    begin
        Enabled := false;
        CanChange := AppSetting.WritePermission();
        if not AppSetting.ReadPermission() then
            exit(false);
        NavApp.GetCurrentModuleInfo(Module);
        if AppSetting.Get(Module.Id()) then
            Enabled := AppSetting."Allow HttpClient Requests";
        exit(true);
    end;

    /// <summary>Reads effective per-company domain states, including the all-enabled missing-row default.</summary>
    procedure ReadDomain(Domain: Enum "Inventory Domain ori"): Boolean
    var
        Setup: Record "Inventory Setup ori";
    begin
        exit(Setup.IsDomainEnabled(Domain));
    end;

    /// <summary>Returns the actual assignable Inventory permission set; attribute sets remain included in Foundation roles.</summary>
    procedure GetAssignableSets(): List of [Text]
    var
        Sets: List of [Text];
    begin
        Sets.Add('BIFROST InvPost ori');
        exit(Sets);
    end;

    /// <summary>Completes only an explicitly finished guide; opening or cancelling has no write path.</summary>
    procedure Finish(CurrentStep: Integer)
    var
        Registration: Codeunit "Inventory Wizard Reg. ori";
        GuidedExperience: Codeunit "Guided Experience";
        StepErr: Label 'Complete the five setup steps before finishing. Return to the guide and choose Next.', Comment = 'is-IS=Farðu í gegnum öll fimm uppsetningarskrefin áður en þú lýkur. Farðu aftur í leiðarvísinn og veldu Áfram.';
    begin
        if CurrentStep <> 5 then
            Error(StepErr);
        Registration.Register();
        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"Inventory Setup Wizard ori");
    end;

    /// <summary>Opens a standard setup page and explains a failed action without altering permissions.</summary>
    procedure OpenPage(PageId: Integer)
    var
        OpenErr: Label 'The page could not be opened: %1. Ask an administrator to check your page permissions, then try again.', Comment = '%1 = original error, is-IS=Ekki tókst að opna síðuna: %1. Biddu kerfisstjóra að athuga síðuheimildir þínar og reyndu svo aftur.';
    begin
        ClearLastError();
        if not TryOpenPage(PageId) then
            Message(OpenErr, GetLastErrorText());
    end;

    [TryFunction]
    local procedure TryOpenPage(PageId: Integer)
    begin
        Page.RunModal(PageId);
    end;
}
