namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Manufacturing.StandardCost;
using Origo.Bifrost;

/// <summary>Runs native standard cost reports and returns only the selected worksheet or new journal lines.</summary>
codeunit 10076935 "Std. Cost Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Worksheet: Record "Standard Cost Worksheet";
        Item: Record Item;
        SKU: Record "Stockkeeping Unit";
        Line: Record "Item Journal Line";
        Management: Codeunit "Std. Cost Management ori";
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        WorksheetCode: Code[10];
    begin
        // Lock in the native implementation order and repeat all validation to close the check/write gap.
        Line.LockTable();
        Worksheet.LockTable();
        Item.LockTable();
        SKU.LockTable();
        if not Management.ValidateImplement(Rec) then
            exit;
        Request := Rec.GetRequestJson();
        WorksheetCode := CopyStr(Management.ReadText(Request, 'worksheetName'), 1, 10);
        ImplementCosts(Request, WorksheetCode, Lines);
        Response.Add('status', 'Success');
        Response.Add('worksheetName', WorksheetCode);
        Response.Add('lineCount', Lines.Count());
        Response.Add('lines', Lines);
        Response.Add('posted', false);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure ImplementCosts(Request: JsonObject; WorksheetCode: Code[10]; var Lines: JsonArray)
    var
        Worksheet: Record "Standard Cost Worksheet";
        Line: Record "Item Journal Line";
        ImplementReport: Report "Implement Standard Cost Change";
        Management: Codeunit "Std. Cost Management ori";
        TemplateCode: Code[10];
        BatchCode: Code[10];
        DocumentNo: Code[20];
        PostingDate: Date;
        Row: JsonObject;
    begin
        TemplateCode := CopyStr(Management.ReadText(Request, 'journalTemplateName'), 1, 10);
        BatchCode := CopyStr(Management.ReadText(Request, 'journalBatchName'), 1, 10);
        DocumentNo := CopyStr(Management.ReadText(Request, 'documentNo'), 1, 20);
        Evaluate(PostingDate, Management.ReadText(Request, 'postingDate'), 9);
        Worksheet.SetRange("Standard Cost Worksheet Name", WorksheetCode);
        Worksheet.SetRange(Type, Worksheet.Type::Item);
        ImplementReport.SetTableView(Worksheet);
        ImplementReport.SetStdCostWksh(WorksheetCode);
        ImplementReport.Initialize(DocumentNo, PostingDate, TemplateCode, BatchCode, true);
        ImplementReport.UseRequestPage(false);
        ImplementReport.RunModal();
        Line.SetRange("Journal Template Name", TemplateCode);
        Line.SetRange("Journal Batch Name", BatchCode);
        if Line.FindSet() then
            repeat
                Clear(Row);
                Row.Add('journalTemplateName', Line."Journal Template Name");
                Row.Add('journalBatchName', Line."Journal Batch Name");
                Row.Add('lineNo', Line."Line No.");
                Row.Add('itemNo', Line."Item No.");
                Row.Add('postingDate', Format(Line."Posting Date", 0, 9));
                Row.Add('documentNo', Line."Document No.");
                Row.Add('quantity', Line.Quantity);
                Row.Add('unitCostRevalued', Line."Unit Cost (Revalued)");
                Row.Add('inventoryValueRevalued', Line."Inventory Value (Revalued)");
                Lines.Add(Row);
            until Line.Next() = 0;
    end;
}
