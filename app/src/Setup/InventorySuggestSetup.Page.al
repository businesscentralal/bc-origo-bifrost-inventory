namespace Origo.Bifrost.Inventory;

/// <summary>Shows what Suggest Setup would turn on or leave off, and why. OK applies the proposal; Cancel changes nothing.</summary>
page 10076837 "Inventory Suggest Setup ori"
{
    PageType = StandardDialog;
    Caption = 'Suggest Setup', Comment = 'is-IS=Tillaga að uppsetningu';
    ApplicationArea = All;
    ContextSensitiveHelpPage = 'inventory-setup';
    Extensible = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(Proposal)
            {
                Caption = 'Proposal', Comment = 'is-IS=Tillaga';
                InstructionalText = 'Choose OK to turn on the domains marked turn on. Nothing is turned off and nothing changes until you choose OK. Domains only decide which message types are listed.', Comment = 'is-IS=Veldu Í lagi til að virkja svið sem eru merkt virkja. Ekkert er gert óvirkt og ekkert breytist fyrr en þú velur Í lagi. Svið ráða aðeins hvaða skilaboðategundir eru listaðar.';
                field(ProposalText; ProposalText)
                {
                    ShowCaption = false;
                    MultiLine = true;
                    ToolTip = 'Specifies, per domain, whether Suggest Setup would turn it on or leave it off, and why.', Comment = 'is-IS=Tilgreinir fyrir hvert svið hvort Tillaga að uppsetningu myndi virkja það eða hafa það óvirkt, og hvers vegna.';
                }
            }
        }
    }

    var
        ProposalText: Text;

    internal procedure SetProposal(NewProposal: Text)
    begin
        ProposalText := NewProposal;
    end;
}
