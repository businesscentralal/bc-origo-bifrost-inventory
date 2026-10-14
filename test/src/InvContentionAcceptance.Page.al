namespace Origo.Bifrost.Inventory.Test;

/// <summary>Runs native independent-session diagnostics only in an individually owned verification company.</summary>
page 96994 "Inv Contention Acceptance"
{
    PageType = List;
    SourceTable = "Inv Contention Probe";
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    Caption = 'Owned Native Contention';

    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field(Scenario; Rec.Scenario) { ToolTip = 'Specifies the native scenario.'; }
                field(ItemNo; Rec."Item No.") { ToolTip = 'Specifies the self-created fixture item.'; }
                field(SessionId; Rec."Session Id") { ToolTip = 'Specifies the actual independent BC session.'; }
                field(State; Rec.State) { ToolTip = 'Specifies the actual native request result.'; }
                field(StartedAt; Rec."Started At") { ToolTip = 'Specifies the actual request start.'; }
                field(FinishedAt; Rec."Finished At") { ToolTip = 'Specifies the actual request finish.'; }
                field(AssertionPassed; Rec."Assertion Passed") { ToolTip = 'Specifies whether overlap and persisted quantity assertions passed.'; }
                field(ErrorText; Rec."Error Text") { ToolTip = 'Specifies the actual native error.'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(RunOwnedAcceptance)
            {
                Caption = 'Run Owned Acceptance';
                ToolTip = 'Creates isolated native fixtures and two actual sessions per scenario. Use only in an owned disposable development container.';
                Image = TestReport;
                trigger OnAction()
                var
                    Coordinator: Codeunit "Inv Contention Coordinator";
                begin
                    Coordinator.Run();
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
