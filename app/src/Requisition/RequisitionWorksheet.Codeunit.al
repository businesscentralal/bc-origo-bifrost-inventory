namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>Shared bounded worksheet validation, native execution and serialization for requisition facades.</summary>
codeunit 10076944 "Requisition Worksheet ori"
{
    Access = Internal;

    var
        InvalidErr: Label 'The requisition request is invalid.', Comment = 'is-IS=Innkaupabeiðnin er ógild.';
        InvalidNextLbl: Label 'Correct the named parameter using the message help and retry.', Comment = 'is-IS=Leiðréttu tilgreinda færibreytu samkvæmt hjálp skilaboðanna og reyndu aftur.';
        NotFoundErr: Label 'The selected worksheet or line does not exist.', Comment = 'is-IS=Valið vinnublað eða lína er ekki til.';
        NotFoundNextLbl: Label 'Select an existing requisition worksheet and existing line numbers.', Comment = 'is-IS=Veldu fyrirliggjandi innkaupavinnublað og línunúmer sem eru til.';
        UnsafeErr: Label 'The selection contains a line that cannot create a new order safely.', Comment = 'is-IS=Valið inniheldur línu sem getur ekki stofnað nýja pöntun á öruggan hátt.';
        UnsafeNextLbl: Label 'Select only new purchase or transfer suggestions without existing document links, drop shipments or special orders. Cancel and change actions are refused.', Comment = 'is-IS=Veldu aðeins tillögur að nýjum innkaupa- eða millifærslupöntunum án tenginga við fyrirliggjandi skjöl, beinna sendinga eða sérpantana. Afturköllun og breytingaraðgerðum er hafnað.';
        EmptyErr: Label 'The selected worksheet has no lines to carry out.', Comment = 'is-IS=Valið vinnublað hefur engar línur til framkvæmda.';
        EmptyNextLbl: Label 'Calculate the worksheet or select existing suggestions before carrying out.', Comment = 'is-IS=Reiknaðu vinnublaðið eða veldu fyrirliggjandi tillögur áður en þær eru framkvæmdar.';
        PermissionErr: Label 'Permission to write requisition lines and new order documents is required.', Comment = 'is-IS=Heimild til að skrifa innkaupalínur og ný pöntunarskjöl er nauðsynleg.';
        PermissionNextLbl: Label 'Ask an administrator for the native worksheet and order permissions required by this operation.', Comment = 'is-IS=Biddu kerfisstjóra um heimildir fyrir vinnublað og pantanir sem aðgerðin krefst.';

    /// <summary>Checks native permissions without granting table access on behalf of the caller.</summary>
    procedure IsEnabled(CarryOut: Boolean): Boolean
    var
        Line: Record "Requisition Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
    begin
        if not Line.WritePermission() then
            exit(false);
        if CarryOut then
            exit(PurchaseHeader.WritePermission() and PurchaseLine.WritePermission() and TransferHeader.WritePermission() and TransferLine.WritePermission());
        exit(true);
    end;

    /// <summary>Calculates one bounded requisition worksheet through native report 699.</summary>
    procedure CalculateRequest(var Argument: Record "Message Argument ori")
    var
        WorksheetTemplate: Record "Req. Wksh. Template";
        Batch: Record "Requisition Wksh. Name";
        Line: Record "Requisition Line";
        Scope: Codeunit "Requisition Native Scope ori";
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        StartDate: Date;
        EndDate: Date;
    begin
        Request := Argument.GetRequestJson();
        if not ValidateKeys(Argument, Request, false) then
            exit;
        if not Prepare(Argument, WorksheetTemplate, Batch, Line, false) then
            exit;
        if not ReadDates(Argument, Request, StartDate, EndDate) then
            exit;
        Scope.Initialize(WorksheetTemplate.Name, Batch.Name);
        BindSubscription(Scope);
        if not Calculate(Argument, Request, WorksheetTemplate.Name, Batch.Name, StartDate, EndDate) then begin
            UnbindSubscription(Scope);
            exit;
        end;
        SerializeLines(Line, Lines);
        UnbindSubscription(Scope);
        Response.Add('status', 'Success');
        Response.Add('templateName', WorksheetTemplate.Name);
        Response.Add('batchName', Batch.Name);
        Response.Add('lines', Lines);
        Response.Add('noOfLines', Lines.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Creates new orders after validating every selected worksheet line.</summary>
    procedure CarryOutRequest(var Argument: Record "Message Argument ori")
    var
        WorksheetTemplate: Record "Req. Wksh. Template";
        Batch: Record "Requisition Wksh. Name";
        Line: Record "Requisition Line";
        Scope: Codeunit "Requisition Native Scope ori";
        Request: JsonObject;
        Response: JsonObject;
        Purchases: JsonArray;
        Transfers: JsonArray;
        LineCount: Integer;
    begin
        Request := Argument.GetRequestJson();
        if not ValidateKeys(Argument, Request, true) then
            exit;
        if not Prepare(Argument, WorksheetTemplate, Batch, Line, true) then
            exit;
        if not SelectLines(Argument, Request, Line) then
            exit;
        if not ValidateLines(Argument, Line) then
            exit;
        LineCount := Line.Count();
        Scope.Initialize(WorksheetTemplate.Name, Batch.Name);
        BindSubscription(Scope);
        CarryOutLines(Line);
        Scope.GetOrders(Purchases, Transfers);
        UnbindSubscription(Scope);
        Response.Add('status', 'Success');
        Response.Add('templateName', WorksheetTemplate.Name);
        Response.Add('batchName', Batch.Name);
        Response.Add('linesCarriedOut', LineCount);
        Response.Add('purchaseOrders', Purchases);
        Response.Add('transferOrders', Transfers);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure Prepare(var Argument: Record "Message Argument ori"; var WorksheetTemplate: Record "Req. Wksh. Template"; var Batch: Record "Requisition Wksh. Name"; var Line: Record "Requisition Line"; CarryOut: Boolean): Boolean
    var
        Request: JsonObject;
        TemplateName: Text;
        BatchName: Text;
    begin
        if not IsEnabled(CarryOut) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', PermissionNextLbl);
            exit(false);
        end;
        Request := Argument.GetRequestJson();
        if not ReadText(Request, 'templateName', Argument, true, 10, TemplateName) then
            exit(false);
        if not ReadText(Request, 'batchName', Argument, true, 10, BatchName) then
            exit(false);
        if not WorksheetTemplate.Get(TemplateName) or not Batch.Get(TemplateName, BatchName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'batchName', BatchName, '', NotFoundNextLbl);
            exit(false);
        end;
        // Recurring and auto-increment templates can retain lines or rename/delete the batch.
        if WorksheetTemplate.Recurring or WorksheetTemplate."Increment Batch Name" or (WorksheetTemplate.Type.AsInteger() <> 0) then begin
            Invalid(Argument, 'templateName');
            exit(false);
        end;
        Line.LockTable();
        Line.SetRange("Worksheet Template Name", WorksheetTemplate.Name);
        Line.SetRange("Journal Batch Name", Batch.Name);
        exit(true);
    end;

    local procedure ValidateKeys(var Argument: Record "Message Argument ori"; Request: JsonObject; CarryOut: Boolean): Boolean
    var
        ParameterName: Text;
        Allowed: List of [Text];
    begin
        Allowed.Add('templateName');
        Allowed.Add('batchName');
        if CarryOut then begin
            Allowed.Add('lineNos');
            Allowed.Add('expectedCount');
        end else begin
            Allowed.Add('itemFilter');
            Allowed.Add('locationFilter');
            Allowed.Add('variantFilter');
            Allowed.Add('startingDate');
            Allowed.Add('endingDate');
        end;
        foreach ParameterName in Request.Keys() do
            if not Allowed.Contains(ParameterName) then begin
                Invalid(Argument, ParameterName);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadText(Request: JsonObject; ParameterName: Text; var Argument: Record "Message Argument ori"; Required: Boolean; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Clear(Value);
        if not Request.Get(ParameterName, Token) then begin
            if not Required then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, InvalidErr, ParameterName, '', '', InvalidNextLbl);
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then begin
            Invalid(Argument, ParameterName);
            exit(false);
        end;
        Value := Token.AsValue().AsText().Trim();
        if (StrLen(Value) > MaxLength) or (Required and (Value = '')) then begin
            Invalid(Argument, ParameterName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDates(var Argument: Record "Message Argument ori"; Request: JsonObject; var StartDate: Date; var EndDate: Date): Boolean
    var
        Value: Text;
    begin
        if not ReadText(Request, 'startingDate', Argument, true, 10, Value) then
            exit(false);
        if not Evaluate(StartDate, Value, 9) or (StartDate = 0D) then begin
            Invalid(Argument, 'startingDate');
            exit(false);
        end;
        if not ReadText(Request, 'endingDate', Argument, true, 10, Value) then
            exit(false);
        if not Evaluate(EndDate, Value, 9) or (EndDate < StartDate) then begin
            Invalid(Argument, 'endingDate');
            exit(false);
        end;
        exit(true);
    end;

    local procedure SelectLines(var Argument: Record "Message Argument ori"; Request: JsonObject; var Line: Record "Requisition Line"): Boolean
    var
        Selected: Record "Requisition Line";
        Token: JsonToken;
        Entry: JsonToken;
        Numbers: List of [Integer];
        Number: Integer;
        Serialized: Text;
        Filter: Text;
    begin
        if not Request.Get('lineNos', Token) then
            exit(true);
        if not Token.IsArray() then begin
            Invalid(Argument, 'lineNos');
            exit(false);
        end;
        if (Token.AsArray().Count() = 0) or (Token.AsArray().Count() > 500) then begin
            Invalid(Argument, 'lineNos');
            exit(false);
        end;
        foreach Entry in Token.AsArray() do begin
            Entry.WriteTo(Serialized);
            if not Evaluate(Number, Serialized, 9) or (Number <= 0) or Numbers.Contains(Number) then begin
                Invalid(Argument, 'lineNos');
                exit(false);
            end;
            Selected.CopyFilters(Line);
            Selected.SetRange("Line No.", Number);
            if Selected.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'lineNos', Serialized, '', NotFoundNextLbl);
                exit(false);
            end;
            Numbers.Add(Number);
            if Filter <> '' then
                Filter += '|';
            Filter += Format(Number, 0, 9);
        end;
        Line.SetFilter("Line No.", Filter);
        exit(true);
    end;

    local procedure ValidateLines(var Argument: Record "Message Argument ori"; var Line: Record "Requisition Line"): Boolean
    begin
        if not Line.FindSet() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, EmptyErr, 'batchName', '', '', EmptyNextLbl);
            exit(false);
        end;
        repeat
            if not (Line."Action Message" in [Line."Action Message"::New, Line."Action Message"::" "]) or
                not (Line."Replenishment System" in [Line."Replenishment System"::Purchase, Line."Replenishment System"::Transfer]) or
                (Line.Type <> Line.Type::Item) or (Line."No." = '') or (Line.Quantity <= 0) or
                (Line."Ref. Order No." <> '') or (Line."Sales Order No." <> '') or (Line."Sales Order Line No." <> 0) or
                Line."Drop Shipment" or (Line."Purchasing Code" <> '') or (Line."Demand Order No." <> '') or
                (Line."Demand Type" <> 0) or Line.Reserve
            then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, UnsafeErr, 'lineNo', Format(Line."Line No.", 0, 9), '', UnsafeNextLbl);
                exit(false);
            end;
        until Line.Next() = 0;
        exit(true);
    end;

    local procedure Calculate(var Argument: Record "Message Argument ori"; Request: JsonObject; TemplateName: Code[10]; BatchName: Code[10]; StartDate: Date; EndDate: Date): Boolean
    var
        Item: Record Item;
        NativeCalculate: Report "Calculate Plan - Req. Wksh.";
        Value: Text;
    begin
        if not ReadText(Request, 'itemFilter', Argument, false, 2048, Value) then
            exit(false);
        if Value <> '' then
            Item.SetFilter("No.", Value);
        if not ReadText(Request, 'locationFilter', Argument, false, 2048, Value) then
            exit(false);
        if Value <> '' then
            Item.SetFilter("Location Filter", Value);
        if not ReadText(Request, 'variantFilter', Argument, false, 2048, Value) then
            exit(false);
        if Value <> '' then
            Item.SetFilter("Variant Filter", Value);
        NativeCalculate.SetTableView(Item);
        NativeCalculate.SetTemplAndWorksheet(TemplateName, BatchName);
        NativeCalculate.InitializeRequest(StartDate, EndDate);
        NativeCalculate.UseRequestPage(false);
        NativeCalculate.RunModal();
        exit(true);
    end;

    local procedure CarryOutLines(var Line: Record "Requisition Line")
    var
        Header: Record "Purchase Header";
        NativeCarryOut: Codeunit "Req. Wksh.-Make Order";
    begin
        Line.ModifyAll("Accept Action Message", true);
        Line.FindFirst();
        NativeCarryOut.Set(Header, 0D, false);
        NativeCarryOut.SetSuppressCommit(true);
        NativeCarryOut.CarryOutBatchAction(Line);
    end;

    local procedure SerializeLines(var Line: Record "Requisition Line"; var Lines: JsonArray)
    var
        Entry: JsonObject;
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Clear(Lines);
        if Line.FindSet() then
            repeat
                Clear(Entry);
                Entry.Add('lineNo', Line."Line No.");
                Entry.Add('itemNo', Line."No.");
                Entry.Add('quantity', Line.Quantity);
                Entry.Add('vendorNo', Line."Vendor No.");
                Entry.Add('locationCode', Line."Location Code");
                Entry.Add('variantCode', Line."Variant Code");
                Entry.Add('dueDate', Format(Line."Due Date", 0, 9));
                Names := Line."Action Message".Names();
                Ordinals := Line."Action Message".Ordinals();
                Entry.Add('actionMessage', Names.Get(Ordinals.IndexOf(Line."Action Message".AsInteger())));
                Names := Line."Replenishment System".Names();
                Ordinals := Line."Replenishment System".Ordinals();
                Entry.Add('replenishmentSystem', Names.Get(Ordinals.IndexOf(Line."Replenishment System".AsInteger())));
                Lines.Add(Entry);
            until Line.Next() = 0;
    end;

    local procedure Invalid(var Argument: Record "Message Argument ori"; Parameter: Text)
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidErr, Parameter, '', '', InvalidNextLbl);
    end;
}
