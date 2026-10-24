namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;

/// <summary>Explicit Web Client entry point for creating the test app's owned MCP fixtures; never included in the product app.</summary>
page 96973 "Inv. MCP Fixture ori"
{
    PageType = Card;
    Caption = 'Owned Inventory MCP fixture';
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            field(SeedState; SeedState)
            {
                ApplicationArea = All;
                Caption = 'Seed state';
                ToolTip = 'Shows whether the explicit owned fixture already exists. Read actual records before any retry.';
                Editable = false;
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(CreateOwnedFixture)
            {
                ApplicationArea = All;
                Caption = 'Create owned fixture';
                ToolTip = 'Creates the test app fixture once in the owned verification company. It refuses an existing fixture.';
                Image = New;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.Run();
                    ReadState();
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        ReadState();
    end;

    var
        SeedState: Text;

    local procedure ReadState()
    var
        Item: Record Item;
    begin
        if Item.Get('W8PRV-EN') then
            SeedState := 'Fixture exists; inspect records, do not replay.'
        else
            SeedState := 'Fixture absent.';
    end;
}
