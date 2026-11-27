namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Adds the Inventory Setup page to the Bifröst page's Related menu, right after Bifrost Setup.
/// </summary>
pageextension 10077001 "Bifrost Inventory Setup ori" extends "Bifrost ori"
{
    actions
    {
        addafter(BifrostSetup)
        {
            action(BifrostInventorySetup)
            {
                ApplicationArea = All;
                Caption = 'Inventory Setup', Comment = 'is-IS=Uppsetning birgða';
                ToolTip = 'Open Inventory Setup, where Bifrost Inventory domains are switched on or off for this company.', Comment = 'is-IS=Opna uppsetningu birgða þar sem svið Bifröst birgða eru virkjuð eða óvirkjuð fyrir þetta fyrirtæki.';
                Image = Setup;
                RunObject = page "Inventory Setup ori";
            }
        }
    }
}
