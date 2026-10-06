namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013424 "Assembly Order Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Assembly Header", true, false));
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
        KeywordsLbl: Label 'assembly order, assemble, kit, build a product, bill of materials, bom, make to order, bundle', Comment = 'is-IS=samsetningarpöntun, setja saman, vörusett, smíða vöru, uppskrift, íhlutalisti, framleiða eftir pöntun, vöruknippi';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Creates a new assembly order for a parent item; use RefreshLines, Release or Post after creation.', Comment = 'is-IS=Býr til nýja samsetningarpöntun fyrir móðurvöru; notaðu RefreshLines, Release eða Post eftir stofnun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := Parts.GetParameters('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Related := Parts.GetRelated('Inventory.AssemblyOrder.Create');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Workflow := Parts.GetWorkflow('Inventory.AssemblyOrder.Create');
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Examples := Parts.GetExamples('Inventory.AssemblyOrder.Create');
        exit(Examples.Count() > 0);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.AssemblyOrder.Create');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := Parts.GetNotes('Inventory.AssemblyOrder.Create');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        AssemblyHeader: Record "Assembly Header";
        RequestValueReader: Codeunit "Request Value Reader ori";
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
        MissingItemErr: Label 'itemNo must be specified in the request JSON.', Locked = true;
        MissingQuantityErr: Label 'quantity must be specified and greater than 0 in the request JSON.', Locked = true;
        FieldWriteRestrictedErr: Label 'Field %1 is restricted for write. Cannot use value ''%2''.', Comment = '%1 = field caption, %2 = field value', Locked = true;
        ReadOk: Boolean;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Assembly Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('itemNo', Token) then
            ItemNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(ItemNo))
        else begin
            Argument.RespondWithError(MissingItemErr);
            exit;
        end;
        if not RequestValueReader.TryReadDecimal(Argument, RequestJson, 'quantity', false, Quantity) then
            exit;
        if Quantity <= 0 then begin
            Argument.RespondWithError(MissingQuantityErr);
            exit;
        end;
        if RequestValueReader.IsFieldWriteRestricted(Database::"Assembly Header", AssemblyHeader.FieldNo("Item No.")) then begin
            Argument.RespondWithError(StrSubstNo(FieldWriteRestrictedErr, AssemblyHeader.FieldCaption("Item No."), ItemNo));
            exit;
        end;
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
        ReadOk := true;
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'postingDate', false, PostingDate) then
            ReadOk := false;
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'dueDate', false, DueDate) then
            ReadOk := false;
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'startingDate', false, StartingDate) then
            ReadOk := false;
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'endingDate', false, EndingDate) then
            ReadOk := false;
        if not RequestValueReader.TryReadDecimal(Argument, RequestJson, 'quantityToAssemble', false, QuantityToAssemble) then
            ReadOk := false;
        if not ReadOk then
            exit;
        RefreshLines := true;
        if not RequestValueReader.TryReadBoolean(Argument, RequestJson, 'refreshLines', false, RefreshLines) then
            exit;
        if PostingDate = 0D then
            PostingDate := WorkDate();
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
        if QuantityToAssemble > 0 then
            AssemblyHeader.Validate("Quantity to Assemble", QuantityToAssemble);
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
