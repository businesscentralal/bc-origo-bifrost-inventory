namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.StandardCost;
using Origo.Bifrost;

/// <summary>Runs native standard cost reports and returns only the selected worksheet or new journal lines.</summary>
codeunit 10076937 "Std. Cost Suggest Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Worksheet: Record "Standard Cost Worksheet";
        Item: Record Item;
        Management: Codeunit "Std. Cost Management ori";
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        WorksheetCode: Code[10];
    begin
        // Lock in the native implementation order and repeat all validation to close the check/write gap.
        Worksheet.LockTable();
        Item.LockTable();
        if not Management.ValidateSuggest(Rec) then
            exit;
        Request := Rec.GetRequestJson();
        WorksheetCode := CopyStr(Management.ReadText(Request, 'worksheetName'), 1, 10);
        SuggestCosts(Request, WorksheetCode, Lines);
        Response.Add('status', 'Success');
        Response.Add('worksheetName', WorksheetCode);
        Response.Add('lineCount', Lines.Count());
        Response.Add('lines', Lines);
        Response.Add('posted', false);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure SuggestCosts(Request: JsonObject; WorksheetCode: Code[10]; var Lines: JsonArray)
    var
        Item: Record Item;
        Worksheet: Record "Standard Cost Worksheet";
        Suggest: Report "Suggest Item Standard Cost";
        Management: Codeunit "Std. Cost Management ori";
        Factor: Decimal;
        Row: JsonObject;
    begin
        Management.FilterItems(Item, Management.ReadText(Request, 'itemFilter'));
        Management.ReadFactor(Request, Factor);
        Suggest.Initialize(WorksheetCode, Factor, 1, 1, '', '', '');
        Suggest.SetTableView(Item);
        Suggest.UseRequestPage(false);
        Suggest.RunModal();
        if Item.FindSet() then
            repeat
                Worksheet.Get(WorksheetCode, Worksheet.Type::Item, Item."No.");
                Clear(Row);
                Row.Add('itemNo', Worksheet."No.");
                Row.Add('standardCost', Worksheet."Standard Cost");
                Row.Add('newStandardCost', Worksheet."New Standard Cost");
                Row.Add('implemented', Worksheet.Implemented);
                Lines.Add(Row);
            until Item.Next() = 0;
    end;

}
