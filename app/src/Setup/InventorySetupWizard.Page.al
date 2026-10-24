namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;
using System.Security.User;
using System.Security.AccessControl;

/// <summary>Explains Inventory setup and delegates HTTP changes to Foundation.</summary>
page 10076836 "Inventory Setup Wizard ori"
{
    PageType = NavigatePage;
    Caption = 'Set up Bifrost Inventory', Comment = 'is-IS=Setja upp Bifröst birgðir';
    ApplicationArea = All;
    ContextSensitiveHelpPage = 'inventory-setup';
    layout
    {
        area(Content)
        {
            group(Welcome)
            {
                Caption = 'Welcome', Comment = 'is-IS=Velkomin';
                Visible = CurrentStep = 1;
                InstructionalText = 'Bifrost Inventory adds transfer and assembly orders from creation to posting and undoing posted assemblies; item tracking, reservations and order tracking; availability by period, item references, charges, categories and attributes; physical inventory, reclassification and item application; unit costs and prices, cost adjustment and posting to the general ledger, revaluation and inventory periods. These operations belong to the Inventory domain.', Comment = 'is-IS=Bifröst birgðir bæta við flutnings- og samsetningarpöntunum frá stofnun til bókunar og afturköllun bókaðra samsetninga; vörurakningu, frátektum og pöntunarrakningu; framboði eftir tímabilum, vörutilvísunum, kostnaðaraukum, flokkum og eiginleikum; birgðatalningu, endurflokkun og vörujöfnun; einingarkostnaði og verði, kostnaðarleiðréttingu og bókun í fjárhag, endurmati og birgðatímabilum. Þessar aðgerðir tilheyra birgðasviðinu.';
                group(AccessExplanation)
                {
                    ShowCaption = false;
                    InstructionalText = 'AI assistants and other systems use these operations through Bifrost as the signed-in user and within that user’s permissions. The installed operations are listed on Bifrost Message Types. Read more in the Inventory documentation.', Comment = 'is-IS=Gervigreindaraðstoðarmenn og önnur kerfi nota þessar aðgerðir í gegnum Bifröst sem innskráður notandi og innan heimilda hans. Uppsettar aðgerðir eru á síðunni Skilaboðategundir Bifröst. Lestu meira í hjálp fyrir birgðir.';
                }
            }
            group(Http)
            {
                Caption = 'HTTP', Comment = 'is-IS=HTTP';
                Visible = CurrentStep = 2;
                InstructionalText = 'Bifrost needs outbound HTTP for licensing. Enable it through Bifrost Setup.', Comment = 'is-IS=Bifröst þarf útleið HTTP fyrir leyfisveitingar. Virkjaðu hana í uppsetningu Bifröst.';
                field(HttpStatus; HttpStatusText)
                {
                    Caption = 'Allow HttpClient Requests', Comment = 'is-IS=Leyfa HttpClient-beiðnir';
                    ToolTip = 'Shows whether this Inventory extension may make outbound HTTP requests.', Comment = 'is-IS=Sýnir hvort þessi birgðaviðbót megi senda HTTP-beiðnir út.';
                    Editable = false;
                }
                group(Administrator)
                {
                    ShowCaption = false;
                    Visible = not CanChangeHttp;
                    InstructionalText = 'You do not have permission to change extension settings. Ask an administrator with the SUPER permission set (or write permission on table NAV App Setting) to enable Allow HttpClient Requests for the applications listed above.', Comment = 'is-IS=Þú hefur ekki heimild til að breyta stillingum viðbóta. Biddu kerfisstjóra sem hefur SUPER heimildasamstæðuna (eða skrifheimild á töfluna NAV App Setting) um að virkja Leyfa HttpClient-beiðnir fyrir forritin hér að ofan.';
                }
            }
            group(AccessStep)
            {
                Caption = 'Access', Comment = 'is-IS=Aðgangur';
                Visible = CurrentStep = 3;
                InstructionalText = 'Assign BIFROST InvPost ori to users who post inventory documents. Users also need Foundation Bifrost permission sets. Assign sets to users or through a Microsoft Entra security group.', Comment = 'is-IS=Úthlutaðu BIFROST InvPost ori til notenda sem bóka birgðaskjöl. Notendur þurfa einnig heimildasamstæður Bifröst Foundation. Úthlutaðu þeim til notenda eða með Microsoft Entra öryggishópi.';
                group(AttributeAccess)
                {
                    ShowCaption = false;
                    InstructionalText = 'BIFROST InvAttrRead ori permits reading item attributes and is included through BIFROST Read ori. BIFROST InvAttrWrite ori permits changing item attributes and is included through BIFROST Full ori. These two Inventory sets cannot be assigned separately.', Comment = 'is-IS=BIFROST InvAttrRead ori heimilar lestur vörueiginleika og fylgir BIFROST Read ori. BIFROST InvAttrWrite ori heimilar breytingar á vörueiginleikum og fylgir BIFROST Full ori. Ekki er hægt að úthluta þessum tveimur birgðaheimildasamstæðum sérstaklega.';
                }
            }
            group(Domains)
            {
                Caption = 'Domains', Comment = 'is-IS=Svið';
                Visible = CurrentStep = 4;
                InstructionalText = 'Review the enabled Inventory domains for this company. Open Inventory Setup to change them; this guide only reads their status.', Comment = 'is-IS=Farðu yfir virk birgðasvið þessa fyrirtækis. Opnaðu Uppsetningu birgða til að breyta þeim; leiðarvísirinn les aðeins stöðuna.';
                field(Attributes; DomainEnabled[1])
                {
                    Caption = 'Attributes', Comment = 'is-IS=Eiginleikar';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(TransferOrders; DomainEnabled[2])
                {
                    Caption = 'Transfer orders', Comment = 'is-IS=Flutningspantanir';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(Assembly; DomainEnabled[3])
                {
                    Caption = 'Assembly', Comment = 'is-IS=Samsetning';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(Reservations; DomainEnabled[4])
                {
                    Caption = 'Reservations', Comment = 'is-IS=Frátektir';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(ItemTracking; DomainEnabled[5])
                {
                    Caption = 'Item tracking', Comment = 'is-IS=Vörurakning';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(PhysInventory; DomainEnabled[6])
                {
                    Caption = 'Physical inventory', Comment = 'is-IS=Birgðatalning';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(Costing; DomainEnabled[7])
                {
                    Caption = 'Costing', Comment = 'is-IS=Kostnaður';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(Reclassification; DomainEnabled[8])
                {
                    Caption = 'Reclassification', Comment = 'is-IS=Endurflokkun';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(ItemApplication; DomainEnabled[9])
                {
                    Caption = 'Item application', Comment = 'is-IS=Vörujöfnun';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(InventoryPeriod; DomainEnabled[10])
                {
                    Caption = 'Inventory periods', Comment = 'is-IS=Birgðatímabil';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(ItemPrice; DomainEnabled[11])
                {
                    Caption = 'Item prices', Comment = 'is-IS=Vöruverð';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(ItemReference; DomainEnabled[12])
                {
                    Caption = 'Item references', Comment = 'is-IS=Vörutilvísanir';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(Availability; DomainEnabled[13])
                {
                    Caption = 'Availability', Comment = 'is-IS=Framboð';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(ItemCharge; DomainEnabled[14])
                {
                    Caption = 'Item charges', Comment = 'is-IS=Kostnaðaraukar';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
                field(ItemCategory; DomainEnabled[15])
                {
                    Caption = 'Item categories', Comment = 'is-IS=Vöruflokkar';
                    ToolTip = 'Specifies whether this domain is enabled in this company.', Comment = 'is-IS=Tilgreinir hvort þetta svið sé virkt í þessu fyrirtæki.';
                    Editable = false;
                }
            }
            group(FinishStep)
            {
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                Visible = CurrentStep = 5;
                InstructionalText = 'Finish records that you reviewed the guide. It does not enable HTTP, assign access or change domains.', Comment = 'is-IS=Ljúka skráir að þú hafir farið yfir leiðarvísinn. Það virkjar ekki HTTP, úthlutar ekki aðgangi og breytir ekki sviðum.';
                field(WelcomeSummary; DoneText)
                {
                    Caption = 'Welcome', Comment = 'is-IS=Velkomin';
                    ToolTip = 'Shows that the operations overview was reviewed.', Comment = 'is-IS=Sýnir að yfirlit aðgerða hafi verið lesið.';
                    Editable = false;
                }
                field(HttpSummary; HttpSummaryText)
                {
                    Caption = 'HTTP', Comment = 'is-IS=HTTP';
                    ToolTip = 'Shows whether HTTP is enabled or needs an administrator.', Comment = 'is-IS=Sýnir hvort HTTP sé virkt eða þurfi kerfisstjóra.';
                    Editable = false;
                }
                field(AccessSummary; AccessSummaryText)
                {
                    Caption = 'Access', Comment = 'is-IS=Aðgangur';
                    ToolTip = 'Reminds an administrator to assign the required permission sets.', Comment = 'is-IS=Minnir kerfisstjóra á að úthluta nauðsynlegum heimildasamstæðum.';
                    Editable = false;
                }
                field(DomainSummary; DoneText)
                {
                    Caption = 'Domains', Comment = 'is-IS=Svið';
                    ToolTip = 'Shows that the company domain states were reviewed.', Comment = 'is-IS=Sýnir að staða sviða fyrirtækisins hafi verið yfirfarin.';
                    Editable = false;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ShowOperations)
            {
                Caption = 'Show operations', Comment = 'is-IS=Sýna aðgerðir';
                ToolTip = 'Opens Bifrost Message Types.', Comment = 'is-IS=Opnar Skilaboðategundir Bifröst.';
                Image = List;
                InFooterBar = true;
                Visible = CurrentStep = 1;
                trigger OnAction()
                begin
                    WizardMgt.OpenPage(Page::"Message Type List ori");
                end;
            }
            action(Documentation)
            {
                Caption = 'Documentation', Comment = 'is-IS=Hjálparskjöl';
                ToolTip = 'Opens the Inventory documentation.', Comment = 'is-IS=Opnar hjálparskjöl fyrir birgðir.';
                Image = Help;
                InFooterBar = true;
                Visible = CurrentStep = 1;
                trigger OnAction()
                begin
                    Hyperlink('https://docs.bifrost.origo.is/en-us/inventory/');
                end;
            }
            action(EnableHttp)
            {
                Caption = 'Enable HTTP in Bifrost Setup', Comment = 'is-IS=Virkja HTTP í uppsetningu Bifröst';
                ToolTip = 'Opens Foundation setup; this guide does not change HTTP settings.', Comment = 'is-IS=Opnar uppsetningu Foundation; þessi leiðarvísir breytir ekki HTTP-stillingum.';
                Image = Setup;
                InFooterBar = true;
                Visible = CurrentStep = 2;
                trigger OnAction()
                begin
                    WizardMgt.OpenPage(Page::"Setup Wizard ori");
                    RefreshStatus();
                end;
            }
            action(Verify)
            {
                Caption = 'Verify', Comment = 'is-IS=Staðfesta';
                ToolTip = 'Reads this app’s current HTTP status.', Comment = 'is-IS=Les núverandi HTTP-stöðu þessa forrits.';
                Image = Refresh;
                InFooterBar = true;
                Visible = CurrentStep = 2;
                trigger OnAction()
                begin
                    RefreshStatus();
                end;
            }
            action(OpenUsers)
            {
                Caption = 'Open Users', Comment = 'is-IS=Opna notendur';
                ToolTip = 'Opens Users for an administrator to manage access.', Comment = 'is-IS=Opnar Notendur svo kerfisstjóri geti stjórnað aðgangi.';
                Image = Users;
                InFooterBar = true;
                Visible = CurrentStep = 3;
                trigger OnAction()
                begin
                    WizardMgt.OpenPage(Page::Users);
                end;
            }
            action(OpenPermissionSets)
            {
                Caption = 'Open Permission Sets', Comment = 'is-IS=Opna heimildasamstæður';
                ToolTip = 'Opens the standard Permission Sets page.', Comment = 'is-IS=Opnar staðlaða síðu heimildasamstæðna.';
                Image = Permission;
                InFooterBar = true;
                Visible = CurrentStep = 3;
                trigger OnAction()
                begin
                    WizardMgt.OpenPage(Page::"Permission Sets");
                end;
            }
            action(OpenInventorySetup)
            {
                Caption = 'Open Inventory Setup', Comment = 'is-IS=Opna uppsetningu birgða';
                ToolTip = 'Opens Inventory Setup to change domain settings.', Comment = 'is-IS=Opnar Uppsetningu birgða til að breyta sviðum.';
                Image = Setup;
                InFooterBar = true;
                Visible = CurrentStep = 4;
                trigger OnAction()
                begin
                    WizardMgt.OpenPage(Page::"Inventory Setup ori");
                    RefreshStatus();
                end;
            }
            action(BackStep)
            {
                Caption = 'Back', Comment = 'is-IS=Til baka';
                ToolTip = 'Returns to the previous step.', Comment = 'is-IS=Fer í fyrra skref.';
                Image = PreviousRecord;
                InFooterBar = true;
                Visible = CurrentStep > 1;
                trigger OnAction()
                begin
                    CurrentStep -= 1;
                    RefreshStatus();
                end;
            }
            action(NextStep)
            {
                Caption = 'Next', Comment = 'is-IS=Áfram';
                ToolTip = 'Continues to the next step.', Comment = 'is-IS=Fer í næsta skref.';
                Image = NextRecord;
                InFooterBar = true;
                Visible = CurrentStep < 5;
                trigger OnAction()
                begin
                    CurrentStep += 1;
                    RefreshStatus();
                end;
            }
            action(Finish)
            {
                Caption = 'Finish', Comment = 'is-IS=Ljúka';
                ToolTip = 'Marks this assisted setup complete.', Comment = 'is-IS=Merkir þessa leiðsögðu uppsetningu sem lokið.';
                Image = Approve;
                InFooterBar = true;
                Visible = CurrentStep = 5;
                trigger OnAction()
                begin
                    WizardMgt.Finish(CurrentStep);
                    CurrPage.Close();
                end;
            }
        }
    }
    var
        WizardMgt: Codeunit "Inventory Wizard Mgt ori";
        CurrentStep: Integer;
        DomainEnabled: array[15] of Boolean;
        CanChangeHttp: Boolean;
        HttpStatusText: Text;
        HttpSummaryText: Text;
        DoneText: Text;
        AccessSummaryText: Text;
        EnabledLbl: Label 'Enabled', Comment = 'is-IS=Virkt';
        DisabledLbl: Label 'Disabled — needs an administrator', Comment = 'is-IS=Óvirkt — þarf kerfisstjóra';
        DoneLbl: Label 'Done', Comment = 'is-IS=Lokið';
        NeedsAdminLbl: Label 'Needs an administrator', Comment = 'is-IS=Þarf kerfisstjóra';
        UnknownLbl: Label 'Cannot read the setting. Ask an administrator to verify it.', Comment = 'is-IS=Ekki er hægt að lesa stillinguna. Biddu kerfisstjóra að staðfesta hana.';

    trigger OnOpenPage()
    begin
        CurrentStep := 1;
        DoneText := DoneLbl;
        AccessSummaryText := NeedsAdminLbl;
        RefreshStatus();
    end;

    local procedure RefreshStatus()
    var
        HttpEnabled: Boolean;
    begin
        if WizardMgt.ReadHttpStatus(HttpEnabled, CanChangeHttp) then
            if HttpEnabled then begin
                HttpStatusText := EnabledLbl;
                HttpSummaryText := DoneLbl;
            end else begin
                HttpStatusText := DisabledLbl;
                HttpSummaryText := NeedsAdminLbl;
            end
        else begin
            HttpStatusText := UnknownLbl;
            HttpSummaryText := NeedsAdminLbl;
        end;
        DomainEnabled[1] := WizardMgt.ReadDomain("Inventory Domain ori"::Attributes);
        DomainEnabled[2] := WizardMgt.ReadDomain("Inventory Domain ori"::TransferOrders);
        DomainEnabled[3] := WizardMgt.ReadDomain("Inventory Domain ori"::Assembly);
        DomainEnabled[4] := WizardMgt.ReadDomain("Inventory Domain ori"::Reservations);
        DomainEnabled[5] := WizardMgt.ReadDomain("Inventory Domain ori"::ItemTracking);
        DomainEnabled[6] := WizardMgt.ReadDomain("Inventory Domain ori"::PhysInventory);
        DomainEnabled[7] := WizardMgt.ReadDomain("Inventory Domain ori"::Costing);
        DomainEnabled[8] := WizardMgt.ReadDomain("Inventory Domain ori"::Reclassification);
        DomainEnabled[9] := WizardMgt.ReadDomain("Inventory Domain ori"::ItemApplication);
        DomainEnabled[10] := WizardMgt.ReadDomain("Inventory Domain ori"::InventoryPeriod);
        DomainEnabled[11] := WizardMgt.ReadDomain("Inventory Domain ori"::ItemPrice);
        DomainEnabled[12] := WizardMgt.ReadDomain("Inventory Domain ori"::ItemReference);
        DomainEnabled[13] := WizardMgt.ReadDomain("Inventory Domain ori"::Availability);
        DomainEnabled[14] := WizardMgt.ReadDomain("Inventory Domain ori"::ItemCharge);
        DomainEnabled[15] := WizardMgt.ReadDomain("Inventory Domain ori"::ItemCategory);
    end;
}
