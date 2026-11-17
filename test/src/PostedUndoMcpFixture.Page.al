namespace Origo.Bifrost.Inventory.Test;

/// <summary>Explicit test-only seed and cleanup actions for issue 134 on the worker's owned tenant.</summary>
page 96997 "Posted Undo MCP Fixture ori"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'Owned posted undo fixture';
    layout
    {
        area(Content)
        {
            field(Result; Result)
            {
                ApplicationArea = All;
                Caption = 'Fixture result';
                ToolTip = 'Shows the identifiers created by the explicit test action.';
                Editable = false;
                MultiLine = true;
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Seed)
            {
                ApplicationArea = All;
                Caption = 'Seed owned undo';
                ToolTip = 'Creates isolated posted documents once for bilingual MCP undo verification.';
                Image = New;
                trigger OnAction()
                var
                    Fixture: Codeunit "Posted Undo MCP Fixture ori";
                begin
                    Result := Fixture.Seed();
                end;
            }
            action(Cleanup)
            {
                ApplicationArea = All;
                Caption = 'Clean owned undo';
                ToolTip = 'Removes only the explicitly prefixed owned test data after verification.';
                Image = Delete;
                trigger OnAction()
                var
                    Fixture: Codeunit "Posted Undo MCP Fixture ori";
                begin
                    Fixture.Cleanup();
                    Result := 'Owned undo fixtures removed.';
                end;
            }
        }
    }
    var
        Result: Text;
}
