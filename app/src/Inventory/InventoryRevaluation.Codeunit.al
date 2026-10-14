namespace Origo.Bifrost.Inventory;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>Native revaluation calculation, posting and preview with explicit batch identification.</summary>
codeunit 70013400 "Inventory Revaluation ori"
{
    Access = Internal;

    var
        BatchErr: Label 'Identify a revaluation batch using subject TEMPLATE|BATCH, its SystemId or templateName and batchName.', Comment = 'is-IS=Auðkenndu endurmatskeyrslu með subject TEMPLATE|BATCH, SystemId eða templateName og batchName.';
        EmptyErr: Label 'The revaluation batch has no lines to post.', Comment = 'is-IS=Endurmatskeyrslan hefur engar línur til að bóka.';
        NotEmptyErr: Label 'Calculate requires an empty revaluation batch to avoid duplicate proposals.', Comment = 'is-IS=Útreikningur krefst tómrar endurmatskeyrslu til að forðast tvíteknar tillögur.';
        ParameterErr: Label 'Unsupported revaluation parameter %1.', Comment = '%1 = parameter name; is-IS=Endurmatsfæribreytan %1 er ekki studd.';
        TextErr: Label 'Parameter %1 must be nonempty text of at most %2 characters.', Comment = '%1 = parameter name; %2 = maximum length; is-IS=Færibreytan %1 verður að vera texti sem er ekki tómur og er að hámarki %2 stafir.';
        CalcPerErr: Label 'calculatePer must be Item or Item Ledger Entry.', Comment = 'is-IS=calculatePer verður að vera Item eða Item Ledger Entry.';
        GroupErr: Label 'byLocation and byVariant require calculatePer=Item.', Comment = 'is-IS=byLocation og byVariant krefjast calculatePer=Item.';
        NothingPostedErr: Label 'No native item register was produced.', Comment = 'is-IS=Engin innbyggð vöruskrá var mynduð.';
        NextStepLbl: Label 'Review the revaluation journal lines before posting.', Comment = 'is-IS=Farðu yfir línur endurmatsbókarinnar áður en bókað er.';

    /// <summary>Fills an empty revaluation batch through report 5899; does not post or change standard costs.</summary>
    procedure Calculate(var Argument: Record "Message Argument ori")
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Item: Record Item;
        CalculateValue: Report "Calculate Inventory Value";
        Reader: Codeunit "Request Value Reader ori";
        Request: JsonObject;
        Response: JsonObject;
        ParameterName: Text;
        DocumentNo: Code[20];
        PostingDate: Date;
        CalculatePer: Enum "Inventory Value Calc. Per";
        ByLocation: Boolean;
        ByVariant: Boolean;
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['templateName', 'batchName', 'batchId', 'id', 'systemId', 'recordSystemId', 'itemNo', 'locationCode', 'variantCode', 'postingDate', 'documentNo', 'calculatePer', 'byLocation', 'byVariant']) then
                Error(ParameterErr, ParameterName);
        if not ResolveBatch(Argument, Batch, Line) then
            exit;
        Line.LockTable();
        if not Line.IsEmpty() then
            Error(NotEmptyErr);
        if not Reader.TryReadDate(Argument, Request, 'postingDate', true, PostingDate) then
            exit;
        DocumentNo := CopyStr(ReadText(Request, 'documentNo', 20), 1, 20);
        CalculatePer := CalculatePer::"Item Ledger Entry";
        if Request.Contains('calculatePer') then
            case LowerCase(ReadText(Request, 'calculatePer', 30)) of
                'item':
                    CalculatePer := CalculatePer::Item;
                'item ledger entry':
                    ;
                else
                    Error(CalcPerErr);
            end;
        if not Reader.TryReadBoolean(Argument, Request, 'byLocation', Request.Contains('byLocation'), ByLocation) then
            exit;
        if not Reader.TryReadBoolean(Argument, Request, 'byVariant', Request.Contains('byVariant'), ByVariant) then
            exit;
        if (CalculatePer = CalculatePer::"Item Ledger Entry") and (ByLocation or ByVariant) then
            Error(GroupErr);
        if Request.Contains('itemNo') then
            Item.SetFilter("No.", ReadText(Request, 'itemNo', 2048));
        if Request.Contains('locationCode') then
            Item.SetFilter("Location Filter", ReadText(Request, 'locationCode', 2048));
        if Request.Contains('variantCode') then
            Item.SetFilter("Variant Filter", ReadText(Request, 'variantCode', 2048));
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        CalculateValue.SetItemJnlLine(Line);
        CalculateValue.SetParameters(PostingDate, DocumentNo, false, CalculatePer, ByLocation, ByVariant, false, "Inventory Value Calc. Base"::" ", false);
        CalculateValue.SetTableView(Item);
        CalculateValue.UseRequestPage(false);
        CalculateValue.Run();
        FilterLines(Batch, Line);
        Response.Add('status', 'Success');
        Response.Add('templateName', Batch."Journal Template Name");
        Response.Add('batchName', Batch.Name);
        Response.Add('linesCreated', Line.Count());
        Line.CalcSums(Quantity, "Inventory Value (Calculated)", "Inventory Value (Revalued)");
        Response.Add('totalQuantity', Line.Quantity);
        Response.Add('calculatedValue', Line."Inventory Value (Calculated)");
        Response.Add('revaluedValue', Line."Inventory Value (Revalued)");
        Response.Add('posted', false);
        SetResponse(Argument, Response);
    end;

    /// <summary>Posts the native revaluation batch with commits suppressed inside the owning process transaction.</summary>
    procedure Post(var Argument: Record "Message Argument ori")
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Register: Record "Item Register";
        PostBatch: Codeunit "Item Jnl.-Post Batch";
        Response: JsonObject;
        LinesToPost: Integer;
        TotalQuantity: Decimal;
        TotalAmount: Decimal;
    begin
        CheckPostParameters(Argument.GetRequestJson());
        if not ResolveBatch(Argument, Batch, Line) then
            exit;
        Line.LockTable();
        ReadTotals(Line, LinesToPost, TotalQuantity, TotalAmount);
        PostBatch.SetSuppressCommit(true);
        PostBatch.Run(Line);
        if (Line."Line No." = 0) or not Register.Get(Line."Line No.") then
            Error(NothingPostedErr);
        Response.Add('status', 'Success');
        Response.Add('templateName', Batch."Journal Template Name");
        Response.Add('batchName', Batch.Name);
        Response.Add('linesPosted', LinesToPost);
        Response.Add('totalQuantity', TotalQuantity);
        Response.Add('totalAmount', TotalAmount);
        Response.Add('itemRegisterNo', Register."No.");
        Response.Add('fromEntryNo', Register."From Entry No.");
        Response.Add('toEntryNo', Register."To Entry No.");
        Response.Add('fromValueEntryNo', Register."From Value Entry No.");
        Response.Add('toValueEntryNo', Register."To Value Entry No.");
        SetResponse(Argument, Response);
    end;

    /// <summary>Runs native posting preview and serializes only captured rolled-back entries through the public Foundation helper.</summary>
    procedure Preview(var Argument: Record "Message Argument ori")
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempDocumentEntry: Record "Document Entry" temporary;
        NativePreview: Codeunit "Gen. Jnl.-Post Preview";
        ItemPost: Codeunit "Item Jnl.-Post";
        Handler: Codeunit "Posting Preview Event Handler";
        PreviewHelper: Codeunit "Posting Preview Helper ori";
        Fields: List of [Text];
        PreviewEntries: JsonArray;
        Totals: JsonObject;
        Response: JsonObject;
        LinesToPost: Integer;
        EntryCount: Integer;
        GLEntryCount: Integer;
        TotalQuantity: Decimal;
        TotalAmount: Decimal;
        Balanced: Boolean;
    begin
        CheckPostParameters(Argument.GetRequestJson());
        if not ResolveBatch(Argument, Batch, Line) then
            exit;
        ReadTotals(Line, LinesToPost, TotalQuantity, TotalAmount);
        BindSubscription(ItemPost);
        NativePreview.SetContext(ItemPost, Line);
        if NativePreview.Run() then;
        UnbindSubscription(ItemPost);
        if not NativePreview.IsSuccess() then begin
            PreviewHelper.RespondWithPreviewError(Argument, GetLastErrorText(), NextStepLbl);
            exit;
        end;
        NativePreview.GetPreviewHandler(Handler);
        PreviewHelper.GetPreviewFieldNames(Fields);
        Handler.FillDocumentEntry(TempDocumentEntry);
        if TempDocumentEntry.FindSet() then
            repeat
                PreviewHelper.AddTableToPreview(PreviewEntries, Handler, TempDocumentEntry."Table ID", TempDocumentEntry."Table Name", Fields);
            until TempDocumentEntry.Next() = 0;
        if not PreviewHelper.EvaluatePreviewOutcome(Argument, PreviewEntries, Handler, NextStepLbl, Totals, Balanced, EntryCount, GLEntryCount) then
            exit;
        Response.Add('status', 'Success');
        Response.Add('templateName', Batch."Journal Template Name");
        Response.Add('batchName', Batch.Name);
        Response.Add('linesToPost', LinesToPost);
        Response.Add('rollback', true);
        Response.Add('preview', PreviewEntries);
        Response.Add('totals', Totals);
        PreviewHelper.AddEntryCounts(Response, EntryCount, GLEntryCount);
        SetResponse(Argument, Response);
    end;

    local procedure ResolveBatch(var Argument: Record "Message Argument ori"; var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line"): Boolean
    var
        JournalTemplate: Record "Item Journal Template";
        TemplateName: Code[10];
        BatchName: Code[10];
        BatchId: Guid;
        Request: JsonObject;
        Parts: List of [Text];
        Identifier: Text;
    begin
        Request := Argument.GetRequestJson();
        if Argument.Subject <> '' then begin
            if not Evaluate(BatchId, Argument.Subject) then begin
                Parts := Argument.Subject.Split('|');
                if Parts.Count() <> 2 then
                    Error(BatchErr);
                if (StrLen(Parts.Get(1)) > 10) or (StrLen(Parts.Get(2)) > 10) or (Parts.Get(1) = '') or (Parts.Get(2) = '') then
                    Error(BatchErr);
                TemplateName := CopyStr(Parts.Get(1), 1, 10);
                BatchName := CopyStr(Parts.Get(2), 1, 10);
            end;
        end else begin
            foreach Identifier in Request.Keys() do
                if Identifier in ['batchId', 'id', 'systemId', 'recordSystemId'] then begin
                    if not IsNullGuid(BatchId) then
                        Error(BatchErr);
                    if not Evaluate(BatchId, ReadText(Request, Identifier, 50)) or IsNullGuid(BatchId) then
                        Error(BatchErr);
                end;
            if IsNullGuid(BatchId) then begin
                TemplateName := CopyStr(ReadText(Request, 'templateName', 10), 1, 10);
                BatchName := CopyStr(ReadText(Request, 'batchName', 10), 1, 10);
            end;
        end;
        if not IsNullGuid(BatchId) then begin
            if not Batch.GetBySystemId(BatchId) then
                Error(BatchErr);
        end else
            Batch.Get(TemplateName, BatchName);
        JournalTemplate.Get(Batch."Journal Template Name");
        JournalTemplate.TestField(Type, JournalTemplate.Type::Revaluation);
        JournalTemplate.TestField(Recurring, false);
        FilterLines(Batch, Line);
        exit(true);
    end;

    local procedure FilterLines(Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    begin
        Line.Reset();
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
    end;

    local procedure ReadTotals(var Line: Record "Item Journal Line"; var LinesToPost: Integer; var TotalQuantity: Decimal; var TotalAmount: Decimal)
    begin
        if not Line.FindSet() then
            Error(EmptyErr);
        repeat
            Line.TestField("Item No.");
            Line.TestField("Value Entry Type", Line."Value Entry Type"::Revaluation);
            LinesToPost += 1;
            TotalQuantity += Line.Quantity;
            TotalAmount += Line.Amount;
        until Line.Next() = 0;
        Line.FindFirst();
    end;

    local procedure CheckPostParameters(Request: JsonObject)
    var
        ParameterName: Text;
    begin
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['templateName', 'batchName', 'batchId', 'id', 'systemId', 'recordSystemId']) then
                Error(ParameterErr, ParameterName);
    end;

    local procedure ReadText(Request: JsonObject; ParameterName: Text; MaxLength: Integer): Text
    var
        Token: JsonToken;
        Serialized: Text;
        Value: Text;
    begin
        if not Request.Get(ParameterName, Token) then
            Error(TextErr, ParameterName, MaxLength);
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then
            Error(TextErr, ParameterName, MaxLength);
        Value := Token.AsValue().AsText();
        if (Value.Trim() = '') or (StrLen(Value) > MaxLength) then
            Error(TextErr, ParameterName, MaxLength);
        exit(Value);
    end;

    local procedure SetResponse(var Argument: Record "Message Argument ori"; Response: JsonObject)
    begin
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
