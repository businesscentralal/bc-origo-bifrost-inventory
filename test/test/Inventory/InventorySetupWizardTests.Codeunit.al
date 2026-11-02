namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost.Inventory;
using System.Apps;
using System.Environment.Configuration;
using System.Media;
using System.TestLibraries.Utilities;

/// <summary>Exercises registration, navigation, read-only status and explicit completion without consent or HTTP writes.</summary>
codeunit 96920 "Inventory Setup Wizard Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        WizardMgt: Codeunit "Inventory Wizard Mgt ori";
        Registration: Codeunit "Inventory Wizard Reg. ori";
        GuidedExperience: Codeunit "Guided Experience";

    [Test]
    procedure Registration_IsIncomplete_EN()
    begin
        CheckRegistration(1033);
    end;

    [Test]
    procedure Registration_IsIncomplete_IS()
    begin
        CheckRegistration(1039);
    end;

    [Test]
    procedure Wizard_FinishCompletes_EN()
    begin
        CheckFinish(1033);
    end;

    [Test]
    procedure Wizard_FinishCompletes_IS()
    begin
        CheckFinish(1039);
    end;

    [Test]
    procedure Wizard_CancelPreservesSetup_EN()
    begin
        CheckCancel(1033);
    end;

    [Test]
    procedure Wizard_CancelPreservesSetup_IS()
    begin
        CheckCancel(1039);
    end;

    [Test]
    procedure Finish_RejectsEarlyStep_EN()
    begin
        CheckEarlyFinish(1033);
    end;

    [Test]
    procedure Finish_RejectsEarlyStep_IS()
    begin
        CheckEarlyFinish(1039);
    end;

    [Test]
    procedure Domains_ReadExistingFlagsWithoutMutation()
    var
        Setup: Record "Inventory Setup ori";
        Saved: Record "Inventory Setup ori";
        Domain: Enum "Inventory Domain ori";
        Ordinal: Integer;
    begin
        Setup.InsertIfNotExists();
        Setup.Attributes := false;
        Setup.Reclassification := true;
        Setup.Modify();
        Saved := Setup;
        foreach Ordinal in Domain.Ordinals() do
            Assert.AreEqual(Setup.IsDomainEnabled("Inventory Domain ori".FromInteger(Ordinal)),
                WizardMgt.ReadDomain("Inventory Domain ori".FromInteger(Ordinal)), 'Every domain uses the effective company state.');
        Setup.Get();
        Assert.AreEqual(Format(Saved), Format(Setup), 'Reading domains must not change setup.');
    end;

    [Test]
    procedure Domains_MissingSetupDoesNotInsert()
    var
        Setup: Record "Inventory Setup ori";
        Domain: Enum "Inventory Domain ori";
        Ordinal: Integer;
    begin
        if Setup.Get() then
            Setup.Delete();
        foreach Ordinal in Domain.Ordinals() do
            Assert.IsTrue(WizardMgt.ReadDomain("Inventory Domain ori".FromInteger(Ordinal)), 'Missing setup means every domain is enabled.');
        Assert.IsFalse(Setup.Get(), 'Read must not create a setup row.');
    end;

    [Test]
    procedure Http_ReadsOwnModuleWithoutWriting()
    var
        AppSetting: Record "NAV App Setting";
        Enabled: Boolean;
        CanChange: Boolean;
        Expected: Boolean;
        HadSetting: Boolean;
        AppId: Guid;
    begin
        // This test only reads the existing setting; it never enables HTTP or manufactures another state.
        AppId := '{02701c94-c962-4825-92c7-ef9f70311a2b}';
        HadSetting := AppSetting.Get(AppId);
        if HadSetting then
            Expected := AppSetting."Allow HttpClient Requests";
        Assert.IsTrue(WizardMgt.ReadHttpStatus(Enabled, CanChange), 'Test caller can read app settings.');
        Assert.AreEqual(Expected, Enabled, 'Must inspect the Inventory module, not Foundation or the test module.');
        Assert.AreEqual(HadSetting, AppSetting.Get(AppId), 'Read must not create a setting.');
        if HadSetting then
            Assert.AreEqual(Expected, AppSetting."Allow HttpClient Requests", 'Read must not change HTTP.');
    end;

    [Test]
    procedure Access_PreservesActualAssignableSet()
    var
        Sets: List of [Text];
    begin
        Sets := WizardMgt.GetAssignableSets();
        Assert.AreEqual(1, Sets.Count(), 'The two attribute sets remain non-assignable included roles.');
        Assert.AreEqual('BIFROST InvPost ori', Sets.Get(1), 'Posting remains the assignable Inventory gate.');
    end;

    [Test]
    [HandlerFunctions('InventorySetupHandler')]
    procedure Domains_OpenSetupAndRefresh()
    var
        Setup: Record "Inventory Setup ori";
        Wizard: TestPage "Inventory Setup Wizard ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Attributes := true;
        Setup.Modify();
        Wizard.OpenView();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.Attributes.AssertEquals(true);
        Wizard.OpenInventorySetup.Invoke();
        Wizard.Attributes.AssertEquals(false);
        Wizard.Close();
        Setup.Get();
        Assert.IsFalse(Setup.Attributes, 'Only the explicitly opened setup page changes the domain.');
    end;

    [ModalPageHandler]
    procedure InventorySetupHandler(var SetupPage: TestPage "Inventory Setup ori")
    begin
        SetupPage.Attributes.SetValue(false);
        SetupPage.OK().Invoke();
    end;

    local procedure ResetGuide()
    begin
        Registration.Register();
        GuidedExperience.ResetAssistedSetup(ObjectType::Page, Page::"Inventory Setup Wizard ori");
    end;

    local procedure CheckRegistration(LanguageId: Integer)
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        GuidedExperience.Remove(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"Inventory Setup Wizard ori");
        Registration.Register();
        Assert.IsTrue(GuidedExperience.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Wizard registered.');
        Assert.IsTrue(GuidedExperience.AssistedSetupExistsAndIsNotComplete(ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Registration cannot mark completion.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckFinish(LanguageId: Integer)
    var
        Wizard: TestPage "Inventory Setup Wizard ori";
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ResetGuide();
        Wizard.OpenView();
        Wizard.NextStep.Invoke();
        Wizard.Verify.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.BackStep.Invoke();
        Wizard.NextStep.Invoke();
        Wizard.NextStep.Invoke();
        Assert.IsFalse(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Reaching Finish is not completion.');
        Wizard.Finish.Invoke();
        Assert.IsTrue(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Explicit Finish completes the guide.');
        Registration.Register();
        Assert.IsTrue(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Registration must preserve existing completion.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckCancel(LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        Wizard: TestPage "Inventory Setup Wizard ori";
        PreviousLanguage: Integer;
        BeforeState: Text;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ResetGuide();
        Setup.InsertIfNotExists();
        BeforeState := Format(Setup);
        Wizard.OpenView();
        Wizard.NextStep.Invoke();
        Wizard.Verify.Invoke();
        Wizard.Close();
        Assert.IsFalse(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Early close is not completion.');
        Setup.Get();
        Assert.AreEqual(BeforeState, Format(Setup), 'Cancelling cannot change domains.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckEarlyFinish(LanguageId: Integer)
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ResetGuide();
        asserterror WizardMgt.Finish(0);
        if LanguageId = 1039 then
            Assert.ExpectedError('Farðu í gegnum')
        else
            Assert.ExpectedError('Complete the five setup steps');
        Assert.IsFalse(GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"Inventory Setup Wizard ori"), 'Invalid step cannot complete setup.');
        GlobalLanguage(PreviousLanguage);
    end;
}
