namespace Origo.Bifrost.Inventory;

using Microsoft.Pricing.Asset;
using Microsoft.Pricing.PriceList;
using Microsoft.Pricing.Source;
using Origo.Bifrost;

/// <summary>Runs native price-list upserts or activation in one Codeunit.Run transaction.</summary>
codeunit 10076982 "Price List Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        InvalidRequestLbl: Label 'Invalid price-list parameter: %1.', Comment = '%1 = parameter, is-IS=Ógild verðlistafæribreyta: %1.';
        CorrectRequestLbl: Label 'Correct %1 using the Price.List.Set or Price.List.Activate help and retry.', Comment = '%1 = parameter, is-IS=Leiðréttu %1 samkvæmt hjálp fyrir Price.List.Set eða Price.List.Activate og reyndu aftur.';
        DraftRequiredLbl: Label 'Price list %1 must be Draft.', Comment = '%1 = list code, is-IS=Verðlisti %1 verður að vera í stöðunni Drög.';
        DraftNextLbl: Label 'Use the Price Lists page to review the list and change it to Draft before retrying.', Comment = 'is-IS=Notaðu síðuna Verðlistar til að yfirfara listann og breyta honum í Drög áður en reynt er aftur.';
        MissingListLbl: Label 'Price list %1 does not exist.', Comment = '%1 = list code, is-IS=Verðlisti %1 er ekki til.';
        MissingNextLbl: Label 'Create the list with Price.List.Set first.', Comment = 'is-IS=Stofnaðu listann fyrst með Price.List.Set.';
        DuplicateLbl: Label 'Price list %1 has conflicting price lines.', Comment = '%1 = list code, is-IS=Verðlisti %1 inniheldur verðlínur sem stangast á.';
        DuplicateNextLbl: Label 'Review conflicts in the response and correct their product, source, quantity, unit or date ranges on the Price Lists page, then retry activation.', Comment = 'is-IS=Yfirfarðu árekstra í svarinu og leiðréttu vöru, uppruna, magn, einingu eða dagsetningabil á síðunni Verðlistar áður en virkjun er reynd aftur.';
        EmptyListLbl: Label 'The price list has no lines to activate.', Comment = 'is-IS=Verðlistinn hefur engar línur til að virkja.';
        EmptyNextLbl: Label 'Add lines with Price.List.Set before activation.', Comment = 'is-IS=Bættu við línum með Price.List.Set áður en virkjað er.';

    trigger OnRun()
    begin
        if Rec.Type = Rec.Type::"Price.List.Activate" then
            Activate(Rec)
        else
            Upsert(Rec);
    end;

    /// <summary>Rejects malformed requests before any write or native conversion.</summary>
    procedure ValidateRequest(var Argument: Record "Message Argument ori"; Activating: Boolean): Boolean
    var
        Request: JsonObject;
        Line: JsonObject;
        Token: JsonToken;
        LineToken: JsonToken;
        Lines: JsonArray;
        LineNumbers: List of [Integer];
        LineNo: Integer;
        PriceType: Text;
    begin
        Request := Argument.GetRequestJson();
        if Activating then begin
            if not CheckKeys(Argument, Request, 'code') then
                exit(false);
        end else
            if not CheckKeys(Argument, Request, 'code,priceType,sourceType,sourceNo,description,currencyCode,startingDate,endingDate,lines') then
                exit(false);
        if not CheckText(Argument, Request, 'code', 20, true) then
            exit(false);
        if Activating then
            exit(true);
        if not CheckText(Argument, Request, 'priceType', 10, true) then
            exit(false);
        PriceType := TextValue(Request, 'priceType');
        if not (PriceType in ['Sales', 'Purchase']) then
            exit(Refuse(Argument, 'priceType'));
        if not CheckText(Argument, Request, 'sourceType', 20, false) then
            exit(false);
        if Request.Contains('sourceType') then
            if ((PriceType = 'Sales') and not (TextValue(Request, 'sourceType') in ['All Customers', 'Customer'])) or
               ((PriceType = 'Purchase') and not (TextValue(Request, 'sourceType') in ['All Vendors', 'Vendor'])) then
                exit(Refuse(Argument, 'sourceType'));
        if not CheckText(Argument, Request, 'sourceNo', 20, false) then
            exit(false);
        if not CheckText(Argument, Request, 'description', 250, false) then
            exit(false);
        if not CheckText(Argument, Request, 'currencyCode', 10, false) then
            exit(false);
        if not CheckDate(Argument, Request, 'startingDate') then
            exit(false);
        if not CheckDate(Argument, Request, 'endingDate') then
            exit(false);
        if not Request.Get('lines', Token) then
            exit(Refuse(Argument, 'lines'));
        if not Token.IsArray() then
            exit(Refuse(Argument, 'lines'));
        Lines := Token.AsArray();
        if (Lines.Count() = 0) or (Lines.Count() > 200) then
            exit(Refuse(Argument, 'lines (1..200)'));
        foreach LineToken in Lines do begin
            if not LineToken.IsObject() then
                exit(Refuse(Argument, 'lines[]'));
            Line := LineToken.AsObject();
            if not CheckKeys(Argument, Line, 'lineNo,assetType,productNo,unitOfMeasureCode,minimumQuantity,unitPrice,lineDiscountPercent,startingDate,endingDate') then
                exit(false);
            if not CheckNumber(Argument, Line, 'lineNo', true, 1, 2147483647, true) then
                exit(false);
            LineNo := NumberValue(Line, 'lineNo');
            if LineNumbers.Contains(LineNo) then
                exit(Refuse(Argument, 'lineNo (duplicate)'));
            LineNumbers.Add(LineNo);
            if not CheckText(Argument, Line, 'assetType', 30, false) then
                exit(false);
            if Line.Contains('assetType') then
                if not (TextValue(Line, 'assetType') in ['Item', 'Resource', 'Resource Group', 'Item Discount Group', 'G/L Account']) then
                    exit(Refuse(Argument, 'assetType'));
            if not CheckText(Argument, Line, 'productNo', 20, true) then
                exit(false);
            if not CheckText(Argument, Line, 'unitOfMeasureCode', 10, false) then
                exit(false);
            if not CheckNumber(Argument, Line, 'minimumQuantity', false, 0, 999999999999.0, false) then
                exit(false);
            if not CheckNumber(Argument, Line, 'unitPrice', false, 0, 999999999999.0, false) then
                exit(false);
            if not CheckNumber(Argument, Line, 'lineDiscountPercent', false, 0, 100, false) then
                exit(false);
            if not CheckDate(Argument, Line, 'startingDate') then
                exit(false);
            if not CheckDate(Argument, Line, 'endingDate') then
                exit(false);
        end;
        exit(true);
    end;

    local procedure Upsert(var Argument: Record "Message Argument ori")
    var
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
        Created: Boolean;
        ListCode: Code[20];
        PriceType: Enum "Price Type";
    begin
        Request := Argument.GetRequestJson();
        ListCode := CopyStr(TextValue(Request, 'code'), 1, MaxStrLen(ListCode));
        Header.LockTable();
        Line.LockTable();
        Created := not Header.Get(ListCode);
        if not Created then
            if Header.Status <> Header.Status::Draft then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DraftRequiredLbl, ListCode), 'code', ListCode, 'Draft', DraftNextLbl);
                exit;
            end;
        if TextValue(Request, 'priceType') = 'Sales' then
            PriceType := PriceType::Sale
        else
            PriceType := PriceType::Purchase;
        if not Created then
            if Header."Price Type" <> PriceType then begin
                Refuse(Argument, 'priceType (existing list)');
                exit;
            end;
        if Created then begin
            Header.Init();
            Header."Price Type" := PriceType;
            Header.Validate(Code, ListCode);
            if PriceType = PriceType::Sale then
                Header.Validate("Source Type", "Price Source Type"::"All Customers")
            else
                Header.Validate("Source Type", "Price Source Type"::"All Vendors");
            Header.Validate("Amount Type", "Price Amount Type"::Any);
            Header.Validate("Allow Updating Defaults", true);
            Header.Insert(true);
        end;
        if Request.Contains('sourceType') then
            case TextValue(Request, 'sourceType') of
                'All Customers':
                    Header.Validate("Source Type", "Price Source Type"::"All Customers");
                'Customer':
                    Header.Validate("Source Type", "Price Source Type"::Customer);
                'All Vendors':
                    Header.Validate("Source Type", "Price Source Type"::"All Vendors");
                'Vendor':
                    Header.Validate("Source Type", "Price Source Type"::Vendor);
            end;
        if Request.Contains('sourceNo') then
            Header.Validate("Source No.", CopyStr(TextValue(Request, 'sourceNo'), 1, MaxStrLen(Header."Source No.")));
        if Request.Contains('description') then
            Header.Validate(Description, CopyStr(TextValue(Request, 'description'), 1, MaxStrLen(Header.Description)));
        if Request.Contains('currencyCode') then
            Header.Validate("Currency Code", CopyStr(TextValue(Request, 'currencyCode'), 1, MaxStrLen(Header."Currency Code")));
        if Request.Contains('startingDate') then
            Header.Validate("Starting Date", DateValue(Request, 'startingDate'));
        if Request.Contains('endingDate') then
            Header.Validate("Ending Date", DateValue(Request, 'endingDate'));
        Header.Modify(true);
        Request.Get('lines', Token);
        Lines := Token.AsArray();
        foreach Token in Lines do
            UpsertLine(Header, Token.AsObject());
        Response.Add('status', 'Success');
        Response.Add('priceListCode', Header.Code);
        Response.Add('created', Created);
        Response.Add('priceType', TextValue(Request, 'priceType'));
        Response.Add('priceListStatus', 'Draft');
        Response.Add('linesWritten', Lines.Count());
        Argument.SetResponseJson(Response);
    end;

    local procedure UpsertLine(Header: Record "Price List Header"; Request: JsonObject)
    var
        Line: Record "Price List Line";
        Created: Boolean;
        LineNo: Integer;
    begin
        LineNo := NumberValue(Request, 'lineNo');
        Created := not Line.Get(Header.Code, LineNo);
        if Created then begin
            Line.Init();
            Line."Price List Code" := Header.Code;
            Line."Line No." := LineNo;
            Line.CopyFrom(Header, true);
        end;
        if Request.Contains('assetType') then
            case TextValue(Request, 'assetType') of
                'Item':
                    Line.Validate("Asset Type", "Price Asset Type"::Item);
                'Resource':
                    Line.Validate("Asset Type", "Price Asset Type"::Resource);
                'Resource Group':
                    Line.Validate("Asset Type", "Price Asset Type"::"Resource Group");
                'Item Discount Group':
                    Line.Validate("Asset Type", "Price Asset Type"::"Item Discount Group");
                'G/L Account':
                    Line.Validate("Asset Type", "Price Asset Type"::"G/L Account");
            end;
        if Created or (Line."Product No." <> UpperCase(TextValue(Request, 'productNo'))) then
            Line.Validate("Product No.", CopyStr(TextValue(Request, 'productNo'), 1, MaxStrLen(Line."Product No.")));
        if Request.Contains('unitOfMeasureCode') then
            Line.Validate("Unit of Measure Code", CopyStr(TextValue(Request, 'unitOfMeasureCode'), 1, MaxStrLen(Line."Unit of Measure Code")));
        if Request.Contains('minimumQuantity') then
            Line.Validate("Minimum Quantity", NumberValue(Request, 'minimumQuantity'));
        if Request.Contains('startingDate') then
            Line.Validate("Starting Date", DateValue(Request, 'startingDate'));
        if Request.Contains('endingDate') then
            Line.Validate("Ending Date", DateValue(Request, 'endingDate'));
        if Request.Contains('unitPrice') then
            if Header."Price Type" = Header."Price Type"::Sale then
                Line.Validate("Unit Price", NumberValue(Request, 'unitPrice'))
            else
                Line.Validate("Direct Unit Cost", NumberValue(Request, 'unitPrice'));
        if Request.Contains('lineDiscountPercent') then
            Line.Validate("Line Discount %", NumberValue(Request, 'lineDiscountPercent'));
        if Created then
            Line.Insert(true)
        else
            Line.Modify(true);
    end;

    local procedure Activate(var Argument: Record "Message Argument ori")
    var
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        TempDuplicate: Record "Duplicate Price Line" temporary;
        Management: Codeunit "Price List Management";
        Response: JsonObject;
        ListCode: Code[20];
        LineCount: Integer;
    begin
        ListCode := CopyStr(TextValue(Argument.GetRequestJson(), 'code'), 1, MaxStrLen(ListCode));
        Header.LockTable();
        Line.LockTable();
        if not Header.Get(ListCode) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingListLbl, ListCode), 'code', ListCode, '', MissingNextLbl);
            exit;
        end;
        if Header.Status <> Header.Status::Draft then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DraftRequiredLbl, ListCode), 'code', ListCode, 'Draft', DraftNextLbl);
            exit;
        end;
        Line.SetRange("Price List Code", Header.Code);
        LineCount := Line.Count();
        if LineCount = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, EmptyListLbl, 'code', ListCode, '', EmptyNextLbl);
            exit;
        end;
        Management.VerifyLines(Line);
        if Management.FindDuplicatePrices(Header, Line, true, TempDuplicate) then begin
            RespondDuplicates(Argument, Header.Code, TempDuplicate);
            exit;
        end;
        if Management.FindDuplicatePrices(Header, Line, false, TempDuplicate) then begin
            RespondDuplicates(Argument, Header.Code, TempDuplicate);
            exit;
        end;
        // Native status validation verifies the source, verifies every line and synchronizes line statuses.
        Header.Validate(Status, Header.Status::Active);
        Header.TestField(Status, Header.Status::Active);
        Header.Modify(true);
        Response.Add('status', 'Success');
        Response.Add('priceListCode', Header.Code);
        Response.Add('priceListStatus', 'Active');
        Response.Add('linesActivated', LineCount);
        Argument.SetResponseJson(Response);
    end;

    local procedure RespondDuplicates(var Argument: Record "Message Argument ori"; ListCode: Code[20]; var TempDuplicate: Record "Duplicate Price Line" temporary)
    var
        Response: JsonObject;
        Conflict: JsonObject;
        Conflicts: JsonArray;
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DuplicateLbl, ListCode), 'code', ListCode, '', DuplicateNextLbl);
        Response := Argument.GetResponseJson();
        if TempDuplicate.FindSet() then
            repeat
                Clear(Conflict);
                Conflict.Add('code', TempDuplicate."Price List Code");
                Conflict.Add('lineNo', TempDuplicate."Price List Line No.");
                Conflicts.Add(Conflict);
            until TempDuplicate.Next() = 0;
        Response.Add('conflicts', Conflicts);
        Argument.SetResponseJson(Response);
    end;

    local procedure CheckKeys(var Argument: Record "Message Argument ori"; Request: JsonObject; Allowed: Text): Boolean
    var
        ParameterName: Text;
    begin
        foreach ParameterName in Request.Keys() do
            if not (',' + Allowed + ',').Contains(',' + ParameterName + ',') then
                exit(Refuse(Argument, ParameterName));
        exit(true);
    end;

    local procedure CheckText(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text; MaxLength: Integer; Required: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(ParameterName, Token) then
            if Required then
                exit(Refuse(Argument, ParameterName))
            else
                exit(true);
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then
            exit(Refuse(Argument, ParameterName));
        if (StrLen(Token.AsValue().AsText()) > MaxLength) or (Required and (DelChr(Token.AsValue().AsText(), '=', ' ') = '')) then
            exit(Refuse(Argument, ParameterName));
        exit(true);
    end;

    local procedure CheckNumber(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text; Required: Boolean; Minimum: Decimal; Maximum: Decimal; Whole: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Value: Decimal;
    begin
        if not Request.Get(ParameterName, Token) then
            if Required then
                exit(Refuse(Argument, ParameterName))
            else
                exit(true);
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or not Evaluate(Value, Raw, 9) then
            exit(Refuse(Argument, ParameterName));
        if (Value < Minimum) or (Value > Maximum) or (Whole and (Value <> Round(Value, 1))) then
            exit(Refuse(Argument, ParameterName));
        exit(true);
    end;

    local procedure CheckDate(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text): Boolean
    var
        Token: JsonToken;
        Value: Date;
        Raw: Text;
    begin
        if not Request.Contains(ParameterName) then
            exit(true);
        if not CheckText(Argument, Request, ParameterName, 10, true) then
            exit(false);
        Request.Get(ParameterName, Token);
        Raw := Token.AsValue().AsText();
        if (StrLen(Raw) <> 10) or not Evaluate(Value, Raw, 9) then
            exit(Refuse(Argument, ParameterName));
        exit(true);
    end;

    local procedure TextValue(Request: JsonObject; ParameterName: Text): Text
    var
        Token: JsonToken;
    begin
        if Request.Get(ParameterName, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure NumberValue(Request: JsonObject; ParameterName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if Request.Get(ParameterName, Token) then
            exit(Token.AsValue().AsDecimal());
        exit(0);
    end;

    local procedure DateValue(Request: JsonObject; ParameterName: Text): Date
    var
        Value: Date;
    begin
        Evaluate(Value, TextValue(Request, ParameterName), 9);
        exit(Value);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Parameter: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidRequestLbl, Parameter), CopyStr(Parameter, 1, 250), '', '', StrSubstNo(CorrectRequestLbl, Parameter));
        exit(false);
    end;
}
