namespace Origo.Bifrost.Inventory.Test;

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
            action(ConfigureReservationVAT)
            {
                ApplicationArea = All;
                Caption = 'Complete owned reservation setup';
                ToolTip = 'Creates native owned VAT setup for the isolated reservation fixtures without changing any write guard.';
                Image = Setup;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.ConfigureReservationVAT();
                    SeedState := 'Complete owned reservation setup completed.';
                end;
            }
            action(CompletePreview)
            {
                ApplicationArea = All;
                Caption = 'Complete inspected preview fixture';
                ToolTip = 'Runs the explicit guarded test fixture action once; inspect existing records before recovery.';
                Image = New;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.CompletePreviewFixture();
                    SeedState := 'Complete inspected preview fixture completed.';
                end;
            }
            action(CreatePostingEN)
            {
                ApplicationArea = All;
                Caption = 'Create owned posting EN';
                ToolTip = 'Runs the explicit guarded test fixture action once; inspect existing records before recovery.';
                Image = New;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.CreatePostingFixtures('EN');
                    SeedState := 'Create owned posting EN completed.';
                end;
            }
            action(CreatePostingIS)
            {
                ApplicationArea = All;
                Caption = 'Create owned posting IS';
                ToolTip = 'Runs the explicit guarded test fixture action once; inspect existing records before recovery.';
                Image = New;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.CreatePostingFixtures('IS');
                    SeedState := 'Create owned posting IS completed.';
                end;
            }
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
        Seed: Codeunit "Inv. MCP Fixture ori";
    begin
        if Seed.FixtureExists() then
            SeedState := 'Fixture exists; inspect records, do not replay.'
        else
            SeedState := 'Fixture absent.';
    end;
}
