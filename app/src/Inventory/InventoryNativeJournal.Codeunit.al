namespace Origo.Bifrost.Inventory;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;
using System.Utilities;

/// <summary>Native validation, filtered posting and rollback preview for dedicated inventory journals.</summary>
codeunit 70013463 "Inventory Native Journal ori"
{
    Access = Internal;

    var
        BatchErr: Label 'Identify one existing journal batch using templateName and batchName or subject TEMPLATE|BATCH or SystemId.', Comment = 'is-IS=Auðkenndu eina fyrirliggjandi bókarkeyrslu með templateName og batchName eða subject TEMPLATE|BATCH eða SystemId.';
        EmptyErr: Label 'The selected journal contains no lines.', Comment = 'is-IS=Valin bók inniheldur engar línur.';
        ParameterErr: Label 'Unsupported journal parameter %1.', Comment = '%1 = parameter name; is-IS=Bókafæribreytan %1 er ekki studd.';
        TextErr: Label 'Parameter %1 must be nonempty text of at most %2 characters.', Comment = '%1 = parameter name; %2 = maximum length; is-IS=Færibreytan %1 verður að vera texti sem er ekki tómur og er að hámarki %2 stafir.';
        SelectionErr: Label 'lineSystemIds must be a nonempty array of distinct SystemIds belonging to the identified journal batch.', Comment = 'is-IS=lineSystemIds verður að vera fylki sem er ekki tómt með aðgreindum SystemId sem tilheyra auðkenndri bókarkeyrslu.';
        NothingPostedErr: Label 'No native item register was produced.', Comment = 'is-IS=Engin innbyggð vöruskrá var mynduð.';
        NextStepLbl: Label 'Correct the selected journal lines before posting.', Comment = 'is-IS=Leiðréttu valdar bókarlínur áður en bókað er.';
        FutureDateLbl: Label 'Line %1 has a future posting date.', Comment = '%1 = line number; is-IS=Lína %1 hefur bókunardagsetningu í framtíðinni.';
        LineParameterTok: Label 'line %1', Locked = true;

    /// <summary>Runs native line checks and returns readiness, errors and warnings without posting.</summary>
    procedure Check(var Argument: Record "Message Argument ori"; JournalType: Enum "Item Journal Template Type")
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        TempErrorMessage: Record "Error Message" temporary;
        ErrorContext: Codeunit "Error Context Element";
        ErrorManagement: Codeunit "Error Message Management";
        ErrorHandler: Codeunit "Error Message Handler";
        Response: JsonObject;
        Errors: JsonArray;
        Warnings: JsonArray;
        LineCount: Integer;
        Verdict: Text;
    begin
        if not Resolve(Argument, JournalType, Batch, Line) then
            exit;
        LineCount := Line.Count();
        ErrorManagement.Activate(ErrorHandler);
        ErrorManagement.PushContext(ErrorContext, Database::"Item Journal Batch", 0, '');
        if Line.FindSet() then
            repeat
                ClearLastError();
                if not TryCheckLine(Line, JournalType) then
                    AddProblem(Errors, 'BusinessCentralError', GetLastErrorText(), StrSubstNo(LineParameterTok, Line."Line No."));
                if Line."Posting Date" > WorkDate() then
                    AddProblem(Warnings, 'InvalidLine', StrSubstNo(FutureDateLbl, Line."Line No."), StrSubstNo(LineParameterTok, Line."Line No."));
            until Line.Next() = 0
        else
            AddProblem(Errors, 'PreconditionFailed', EmptyErr, 'batchName');
        ErrorHandler.AppendTo(TempErrorMessage);
        if TempErrorMessage.FindSet() then
            repeat
                if TempErrorMessage."Message Type" = TempErrorMessage."Message Type"::Error then
                    AddProblem(Errors, 'BusinessCentralError', TempErrorMessage."Message", '')
                else
                    AddProblem(Warnings, 'BusinessCentralError', TempErrorMessage."Message", '');
            until TempErrorMessage.Next() = 0;
        Verdict := 'Ready';
        if Warnings.Count() > 0 then
            Verdict := 'ReadyWithWarnings';
        if Errors.Count() > 0 then
            Verdict := 'NotReady';
        AddBatch(Response, Batch);
        Response.Add('validationResult', Verdict);
        Response.Add('lineCount', LineCount);
        Response.Add('errorCount', Errors.Count());
        Response.Add('warningCount', Warnings.Count());
        Response.Add('errors', Errors);
        Response.Add('warnings', Warnings);
        SetResponse(Argument, Response);
    end;

    /// <summary>Posts the selected native lines with inner commits suppressed; called inside Codeunit.Run isolation.</summary>
    procedure Post(var Argument: Record "Message Argument ori"; JournalType: Enum "Item Journal Template Type")
    var
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Register: Record "Item Register";
        PostBatch: Codeunit "Item Jnl.-Post Batch";
        Response: JsonObject;
        Results: JsonArray;
    begin
        Line.LockTable();
        if not Resolve(Argument, JournalType, Batch, Line) then
            exit;
        ReadLines(Line, JournalType, Results);
        PostBatch.SetSuppressCommit(true);
        PostBatch.Run(Line);
        if (Line."Line No." = 0) or not Register.Get(Line."Line No.") then
            Error(NothingPostedErr);
        AddBatch(Response, Batch);
        Response.Add('postedLineCount', Results.Count());
        Response.Add('itemRegisterNo', Register."No.");
        Response.Add('fromEntryNo', Register."From Entry No.");
        Response.Add('toEntryNo', Register."To Entry No.");
        Response.Add('fromPhysInventoryEntryNo', Register."From Phys. Inventory Entry No.");
        Response.Add('toPhysInventoryEntryNo', Register."To Phys. Inventory Entry No.");
        Response.Add('result', Results);
        SetResponse(Argument, Response);
    end;

    /// <summary>Uses native posting preview and the public Foundation serializer for captured rollback entries.</summary>
    procedure Preview(var Argument: Record "Message Argument ori"; JournalType: Enum "Item Journal Template Type")
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
        Results: JsonArray;
        Totals: JsonObject;
        Response: JsonObject;
        EntryCount: Integer;
        GLEntryCount: Integer;
        Balanced: Boolean;
    begin
        if not Resolve(Argument, JournalType, Batch, Line) then
            exit;
        ReadLines(Line, JournalType, Results);
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
        AddBatch(Response, Batch);
        Response.Add('linesToPost', Results.Count());
        Response.Add('rollback', true);
        Response.Add('preview', PreviewEntries);
        Response.Add('totals', Totals);
        Response.Add('result', Results);
        PreviewHelper.AddEntryCounts(Response, EntryCount, GLEntryCount);
        SetResponse(Argument, Response);
    end;

    local procedure Resolve(var Argument: Record "Message Argument ori"; JournalType: Enum "Item Journal Template Type"; var Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line"): Boolean
    var
        JournalTemplate: Record "Item Journal Template";
        Request: JsonObject;
        ParameterName: Text;
        TemplateName: Code[10];
        BatchName: Code[10];
        BatchId: Guid;
        Parts: List of [Text];
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['templateName', 'batchName', 'journalTemplateName', 'journalBatchName', 'lineSystemIds']) then
                Error(ParameterErr, ParameterName);
        NormalizeAlias(Request, 'journalTemplateName', 'templateName');
        NormalizeAlias(Request, 'journalBatchName', 'batchName');
        if Request.Contains('templateName') or Request.Contains('batchName') then begin
            TemplateName := CopyStr(ReadText(Request, 'templateName', 10), 1, 10);
            BatchName := CopyStr(ReadText(Request, 'batchName', 10), 1, 10);
        end;
        if Argument.Subject <> '' then
            if not Evaluate(BatchId, Argument.Subject) then begin
                Parts := Argument.Subject.Split('|');
                if Parts.Count() <> 2 then
                    Error(BatchErr);
                if (Parts.Get(1) = '') or (Parts.Get(2) = '') or (StrLen(Parts.Get(1)) > 10) or (StrLen(Parts.Get(2)) > 10) then
                    Error(BatchErr);
                if (TemplateName <> '') and ((TemplateName <> UpperCase(Parts.Get(1))) or (BatchName <> UpperCase(Parts.Get(2)))) then
                    Error(BatchErr);
                TemplateName := CopyStr(Parts.Get(1), 1, 10);
                BatchName := CopyStr(Parts.Get(2), 1, 10);
            end else
                if IsNullGuid(BatchId) then
                    Error(BatchErr);
        if IsNullGuid(BatchId) and ((TemplateName = '') or (BatchName = '')) then
            Error(BatchErr);
        if not IsNullGuid(BatchId) then begin
            if not Batch.GetBySystemId(BatchId) then
                Error(BatchErr);
            if (TemplateName <> '') and ((TemplateName <> Batch."Journal Template Name") or (BatchName <> Batch.Name)) then
                Error(BatchErr);
        end else
            Batch.Get(TemplateName, BatchName);
        JournalTemplate.Get(Batch."Journal Template Name");
        JournalTemplate.TestField(Type, JournalType);
        JournalTemplate.TestField(Recurring, false);
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
        SelectLines(Request, Batch, Line);
        exit(true);
    end;

    local procedure NormalizeAlias(var Request: JsonObject; AliasName: Text; Name: Text)
    var
        Value: Text;
    begin
        if Request.Contains(AliasName) then begin
            Value := ReadText(Request, AliasName, 10);
            if Request.Contains(Name) then begin
                if UpperCase(ReadText(Request, Name, 10)) <> UpperCase(Value) then
                    Error(BatchErr);
            end else
                Request.Add(Name, Value);
            Request.Remove(AliasName);
        end;
        if Request.Contains(Name) then
            ReadText(Request, Name, 10);
    end;

    local procedure ReadText(Request: JsonObject; Name: Text; Maximum: Integer): Text
    var
        Token: JsonToken;
        Serialized: Text;
        Value: Text;
    begin
        if not Request.Get(Name, Token) or not Token.IsValue() then
            Error(TextErr, Name, Maximum);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            Error(TextErr, Name, Maximum);
        Value := Token.AsValue().AsText();
        if (Value = '') or (StrLen(Value) > Maximum) then
            Error(TextErr, Name, Maximum);
        exit(Value);
    end;

    local procedure SelectLines(Request: JsonObject; Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    var
        SelectedLine: Record "Item Journal Line";
        Token: JsonToken;
        Entry: JsonToken;
        Ids: List of [Guid];
        Id: Guid;
        FilterText: Text;
        Serialized: Text;
    begin
        if not Request.Get('lineSystemIds', Token) then
            exit;
        if not Token.IsArray() then
            Error(SelectionErr);
        if Token.AsArray().Count() = 0 then
            Error(SelectionErr);
        foreach Entry in Token.AsArray() do begin
            Entry.WriteTo(Serialized);
            if not Entry.IsValue() or (CopyStr(Serialized, 1, 1) <> '"') then
                Error(SelectionErr);
            if not Evaluate(Id, Entry.AsValue().AsText()) or IsNullGuid(Id) then
                Error(SelectionErr);
            if Ids.Contains(Id) then
                Error(SelectionErr);
            Ids.Add(Id);
            if not SelectedLine.GetBySystemId(Id) then
                Error(SelectionErr);
            if (SelectedLine."Journal Template Name" <> Batch."Journal Template Name") or (SelectedLine."Journal Batch Name" <> Batch.Name) then
                Error(SelectionErr);
            if FilterText <> '' then
                FilterText += '|';
            FilterText += Format(SelectedLine."Line No.", 0, 9);
        end;
        Line.SetFilter("Line No.", FilterText);
    end;

    local procedure ReadLines(var Line: Record "Item Journal Line"; JournalType: Enum "Item Journal Template Type"; var Results: JsonArray)
    var
        Result: JsonObject;
    begin
        if not Line.FindSet() then
            Error(EmptyErr);
        repeat
            CheckLineType(Line, JournalType);
            Clear(Result);
            Result.Add('systemId', Line.SystemId);
            Result.Add('lineNo', Line."Line No.");
            Result.Add('itemNo', Line."Item No.");
            Result.Add('quantity', Line.Quantity);
            Result.Add('locationCode', Line."Location Code");
            Result.Add('newLocationCode', Line."New Location Code");
            Result.Add('binCode', Line."Bin Code");
            Result.Add('newBinCode', Line."New Bin Code");
            Result.Add('lotNo', Line."Lot No.");
            Result.Add('newLotNo', Line."New Lot No.");
            Result.Add('serialNo', Line."Serial No.");
            Result.Add('newSerialNo', Line."New Serial No.");
            Result.Add('packageNo', Line."Package No.");
            Result.Add('newPackageNo', Line."New Package No.");
            Results.Add(Result);
        until Line.Next() = 0;
        Line.FindFirst();
    end;

    [TryFunction]
    local procedure TryCheckLine(var Line: Record "Item Journal Line"; JournalType: Enum "Item Journal Template Type")
    var
        CheckLine: Codeunit "Item Jnl.-Check Line";
    begin
        CheckLineType(Line, JournalType);
        CheckLine.RunCheck(Line);
    end;

    local procedure CheckLineType(Line: Record "Item Journal Line"; JournalType: Enum "Item Journal Template Type")
    begin
        if JournalType = JournalType::Transfer then begin
            Line.TestField("Entry Type", Line."Entry Type"::Transfer);
            Line.TestField("Phys. Inventory", false);
        end else begin
            Line.TestField("Phys. Inventory", true);
            if not (Line."Entry Type" in [Line."Entry Type"::"Positive Adjmt.", Line."Entry Type"::"Negative Adjmt."]) then
                Line.FieldError("Entry Type");
        end;
        Line.TestField("Value Entry Type", Line."Value Entry Type"::"Direct Cost");
        Line.TestField("Item Charge No.", '');
    end;

    local procedure AddProblem(var Problems: JsonArray; Code: Text; MessageText: Text; Parameter: Text)
    var
        Problem: JsonObject;
    begin
        Problem.Add('code', Code);
        Problem.Add('error', MessageText);
        Problem.Add('parameter', Parameter);
        Problem.Add('nextStep', NextStepLbl);
        Problems.Add(Problem);
    end;

    local procedure AddBatch(var Response: JsonObject; Batch: Record "Item Journal Batch")
    begin
        Response.Add('status', 'Success');
        Response.Add('templateName', Batch."Journal Template Name");
        Response.Add('batchName', Batch.Name);
    end;

    local procedure SetResponse(var Argument: Record "Message Argument ori"; Response: JsonObject)
    begin
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
