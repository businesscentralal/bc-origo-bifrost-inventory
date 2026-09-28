namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.Create message type.
/// Creates a new Assembly Order header (Assembly Header with Document Type = Order)
/// for a parent item with optional posting/due dates, location, variant, dimensions,
/// and refreshes the component lines from the item's BOM when requested.
/// </summary>

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013424 "Assembly Order Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetFilterTableNo());
        exit(RecRef.WritePermission());
    end;
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Assembly Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Creates a new assembly order header for a parent item, optionally refreshing component lines from the BOM.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assembly order, assemble, kit, build a product, bill of materials, bom, make to order, bundle', Comment = 'is-IS=samsetningarpöntun, setja saman, vörusett, smíða vöru, uppskrift, íhlutalisti, framleiða eftir pöntun';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Assembly Order Create Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        FieldRestrictionMgt: Codeunit "Field Access ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        VariantCode: Code[10];
        LocationCode: Code[10];
        BinCode: Code[20];
        UnitOfMeasureCode: Code[10];
        Description: Text[100];
        PostingDate: Date;
        DueDate: Date;
        StartingDate: Date;
        EndingDate: Date;
        Quantity: Decimal;
        QuantityToAssemble: Decimal;
        RefreshLines: Boolean;
        DecimalValue: Decimal;
        MissingItemErr: Label 'itemNo must be specified in the request JSON.', Locked = true;
        MissingQuantityErr: Label 'quantity must be specified and greater than 0 in the request JSON.', Locked = true;
        FieldWriteRestrictedErr: Label 'Field %1 is restricted for write. Cannot use value ''%2''.', Comment = '%1 = field caption, %2 = field value', Locked = true;
        ReadOk: Boolean;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();

        // Required: itemNo
        if RequestJson.Get('itemNo', Token) then
            ItemNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(ItemNo))
        else begin
            Argument.RespondWithError(MissingItemErr);
            exit;
        end;

        // Required: quantity. A missing or non-positive value keeps the quantity error; a bad decimal is a format error.
        if not Argument.TryReadDecimal(RequestJson, 'quantity', false, Quantity) then
            exit;
        if Quantity <= 0 then begin
            Argument.RespondWithError(MissingQuantityErr);
            exit;
        end;

        // Enforce field-level write restriction on the principal Item No. field
        if FieldRestrictionMgt.IsFieldWriteRestricted(Database::"Assembly Header", AssemblyHeader.FieldNo("Item No.")) then begin
            Argument.RespondWithError(StrSubstNo(FieldWriteRestrictedErr, AssemblyHeader.FieldCaption("Item No."), ItemNo));
            exit;
        end;

        // Optional fields
        if RequestJson.Get('variantCode', Token) then
            VariantCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(VariantCode));
        if RequestJson.Get('locationCode', Token) then
            LocationCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(LocationCode));
        if RequestJson.Get('binCode', Token) then
            BinCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(BinCode));
        if RequestJson.Get('unitOfMeasureCode', Token) then
            UnitOfMeasureCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(UnitOfMeasureCode));
        if RequestJson.Get('description', Token) then
            Description := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Description));
        // Every typed value is read before stopping, so all bad ones are reported together (#136).
        ReadOk := true;
        if not Argument.TryReadDate(RequestJson, 'postingDate', false, PostingDate) then
            ReadOk := false;
        if not Argument.TryReadDate(RequestJson, 'dueDate', false, DueDate) then
            ReadOk := false;
        if not Argument.TryReadDate(RequestJson, 'startingDate', false, StartingDate) then
            ReadOk := false;
        if not Argument.TryReadDate(RequestJson, 'endingDate', false, EndingDate) then
            ReadOk := false;
        if not Argument.TryReadDecimal(RequestJson, 'quantityToAssemble', false, QuantityToAssemble) then
            ReadOk := false;
        if not ReadOk then
            exit;
        RefreshLines := true; // default: refresh BOM lines
        if not Argument.TryReadBoolean(RequestJson, 'refreshLines', false, RefreshLines) then
            exit;

        if PostingDate = 0D then
            PostingDate := WorkDate();

        // Initialize the Assembly Header. Use Insert(true) to fire OnInsert and assign the No. from series.
        AssemblyHeader.Init();
        AssemblyHeader."Document Type" := AssemblyHeader."Document Type"::Order;
        AssemblyHeader."No." := '';
        AssemblyHeader.Insert(true);

        AssemblyHeader.SetHideValidationDialog(true);
        AssemblyHeader.Validate("Posting Date", PostingDate);
        AssemblyHeader.Validate("Item No.", ItemNo);
        if VariantCode <> '' then
            AssemblyHeader.Validate("Variant Code", VariantCode);
        if LocationCode <> '' then
            AssemblyHeader.Validate("Location Code", LocationCode);
        if UnitOfMeasureCode <> '' then
            AssemblyHeader.Validate("Unit of Measure Code", UnitOfMeasureCode);
        if DueDate <> 0D then
            AssemblyHeader.Validate("Due Date", DueDate);
        if EndingDate <> 0D then
            AssemblyHeader.Validate("Ending Date", EndingDate);
        if StartingDate <> 0D then
            AssemblyHeader.Validate("Starting Date", StartingDate);
        AssemblyHeader.Validate(Quantity, Quantity);
        if BinCode <> '' then
            AssemblyHeader.Validate("Bin Code", BinCode);
        if Description <> '' then
            AssemblyHeader.Validate(Description, Description);
        DecimalValue := QuantityToAssemble;
        if DecimalValue > 0 then
            AssemblyHeader.Validate("Quantity to Assemble", DecimalValue);
        AssemblyHeader.Modify(true);

        if RefreshLines then begin
            AssemblyHeader.Validate("Item No.", AssemblyHeader."Item No.");
            AssemblyHeader.Modify(true);
        end;

        AssemblyHeader.Find();

        BuildSuccessResponse(AssemblyHeader, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildSuccessResponse(AssemblyHeader: Record "Assembly Header"; var ResponseJson: JsonObject)
    var
        AssemblyLine: Record "Assembly Line";
    begin
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('systemId', Format(AssemblyHeader.SystemId, 0, 4));
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('variantCode', AssemblyHeader."Variant Code");
        ResponseJson.Add('description', AssemblyHeader.Description);
        ResponseJson.Add('locationCode', AssemblyHeader."Location Code");
        ResponseJson.Add('binCode', AssemblyHeader."Bin Code");
        ResponseJson.Add('unitOfMeasureCode', AssemblyHeader."Unit of Measure Code");
        ResponseJson.Add('quantity', AssemblyHeader.Quantity);
        ResponseJson.Add('quantityToAssemble', AssemblyHeader."Quantity to Assemble");
        ResponseJson.Add('postingDate', Format(AssemblyHeader."Posting Date", 0, 9));
        ResponseJson.Add('dueDate', Format(AssemblyHeader."Due Date", 0, 9));
        ResponseJson.Add('startingDate', Format(AssemblyHeader."Starting Date", 0, 9));
        ResponseJson.Add('endingDate', Format(AssemblyHeader."Ending Date", 0, 9));
        ResponseJson.Add('statusAfter', StatusToText(AssemblyHeader.Status));
        ResponseJson.Add('lineCount', AssemblyLine.Count());
    end;

    local procedure StatusToText(StatusValue: Option Open,Released): Text
    begin
        case StatusValue of
            StatusValue::Open:
                exit('Open');
            StatusValue::Released:
                exit('Released');
        end;
        exit('');
    end;
}
