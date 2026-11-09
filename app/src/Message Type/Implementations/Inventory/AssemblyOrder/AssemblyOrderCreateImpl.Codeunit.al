namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Origo.Bifrost;

codeunit 10076854 "Assembly Order Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        DescriptionLbl: Label 'Creates a new assembly order header for a parent item, optionally refreshing component lines from the BOM.', Comment = 'is-IS=Býr til nýjan haus samsetningarpöntunar fyrir móðurvöru og getur endurnýjað íhlutalínur úr uppskrift.';
    begin
        exit(DescriptionLbl);
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
        AssemblyHeader: Record "Assembly Header";
        Item: Record Item;
        Location: Record Location;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestValueReader: Codeunit "Request Value Reader ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
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
        MissingQuantityErr: Label 'quantity must be specified and greater than 0 in the request JSON.', Comment = 'is-IS=Magn verður að vera tilgreint og stærra en 0 í JSON-beiðninni.';
        QuantityExpectedTxt: Label 'A quantity greater than 0 in data.quantity.', Comment = 'is-IS=Magn stærra en 0 í data.quantity.';
        QuantityNextStepTxt: Label 'Send the quantity to assemble in data.quantity.', Comment = 'is-IS=Sendu magnið sem á að setja saman í data.quantity.';
        FieldWriteRestrictedErr: Label 'Field %1 is restricted for write. Cannot use value ''%2''.', Comment = '%1 = field caption, %2 = field value, is-IS=Skrif í reitinn %1 eru takmörkuð. Ekki er hægt að nota gildið ''%2''.';
        ReadOk: Boolean;
        MissingRecordErr: Label '%1 %2 was not found.', Comment = '%1 = parameter name, %2 = requested value; is-IS=%1 %2 fannst ekki.';
        ExistingItemTxt: Label 'An existing item number.', Comment = 'is-IS=Vörunúmer sem er til.';
        ExistingLocationTxt: Label 'An existing location code.', Comment = 'is-IS=Staðsetningarkóði sem er til.';
        LookupNextStepTxt: Label 'Select an existing item and location, then correct every reported value.', Comment = 'is-IS=Veldu vöru og staðsetningu sem eru til og leiðréttu öll tilgreind gildi.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Assembly Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        ItemNo := CopyStr(Parts.ReadRequestText(RequestJson, 'itemNo', Argument, true, 20), 1, 20);
        VariantCode := CopyStr(Parts.ReadRequestText(RequestJson, 'variantCode', Argument, false, 10), 1, 10);
        LocationCode := CopyStr(Parts.ReadRequestText(RequestJson, 'locationCode', Argument, false, 10), 1, 10);
        BinCode := CopyStr(Parts.ReadRequestText(RequestJson, 'binCode', Argument, false, 20), 1, 20);
        UnitOfMeasureCode := CopyStr(Parts.ReadRequestText(RequestJson, 'unitOfMeasureCode', Argument, false, 10), 1, 10);
        Description := CopyStr(Parts.ReadRequestText(RequestJson, 'description', Argument, false, 100), 1, 100);
        ReadOk := RequestValueReader.TryReadDecimal(Argument, RequestJson, 'quantity', true, Quantity);
        if ReadOk and (Quantity <= 0) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, MissingQuantityErr, 'quantity', Format(Quantity, 0, 9), QuantityExpectedTxt, QuantityNextStepTxt);
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
        RefreshLines := true;
        if not RequestValueReader.TryReadBoolean(Argument, RequestJson, 'refreshLines', false, RefreshLines) then
            ReadOk := false;
        if (ItemNo <> '') and not Item.Get(ItemNo) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingRecordErr, 'itemNo', ItemNo), 'itemNo', ItemNo, ExistingItemTxt, LookupNextStepTxt);
        if (LocationCode <> '') and not Location.Get(LocationCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingRecordErr, 'locationCode', LocationCode), 'locationCode', LocationCode, ExistingLocationTxt, LookupNextStepTxt);
        if Parts.RespondToProblems(Argument) or not ReadOk then
            exit;
        if RequestValueReader.IsFieldWriteRestricted(Database::"Assembly Header", AssemblyHeader.FieldNo("Item No.")) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(FieldWriteRestrictedErr, AssemblyHeader.FieldCaption("Item No."), ItemNo), 'itemNo', ItemNo, ExistingItemTxt, LookupNextStepTxt);
            exit;
        end;
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
