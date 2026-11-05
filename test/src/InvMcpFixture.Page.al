namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

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
            action(CheckMissingReservation)
            {
                ApplicationArea = All;
                Caption = 'Check missing reservation';
                ToolTip = 'Displays the real cancellation refusal for a verified absent selector in the owned test company.';
                Image = TestReport;
                trigger OnAction()
                begin
                    ShowMissingReservation();
                end;
            }
            action(CreateRefusals)
            {
                ApplicationArea = All;
                Caption = 'Create owned151 fixtures';
                ToolTip = 'Creates new owned physical-count batches and periods once; refuses existing fixtures.';
                Image = New;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.CreateRefusalFixtures();
                    SeedState := 'Create owned151 fixtures completed.';
                end;
            }
            action(CreateTracking)
            {
                ApplicationArea = All;
                Caption = 'Create owned tracking';
                ToolTip = 'Creates four new owned lot and serial source lines for bilingual tracking verification; refuses existing fixtures.';
                Image = New;
                trigger OnAction()
                var
                    Seed: Codeunit "Inv. MCP Fixture ori";
                begin
                    Seed.CreateTrackingFixtures();
                    SeedState := 'Create owned tracking completed.';
                end;
            }
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

    local procedure ShowMissingReservation()
    var
        ReservationEntry: Record "Reservation Entry";
        Helper: Codeunit "Transfer Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('Only the owned CRONUS verification company is supported.');
        ReservationEntry.SetRange("Entry No.", 2147483000);
        if not ReservationEntry.IsEmpty() then
            Error('The test selector exists; no cancellation was attempted.');
        Request.Add('entryNo', 2147483000);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
        Response.WriteTo(SeedState);
    end;

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
