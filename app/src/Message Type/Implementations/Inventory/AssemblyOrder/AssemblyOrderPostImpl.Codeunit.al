namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
using Origo.Bifrost;

codeunit 10076855 "Assembly Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        if not DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Assembly Header", false, true) then
            exit(false);
        exit(PostingGate.HasPostingPermission());
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Assembly Header");
    end;

    procedure GetDescription() Description: Text[250]
    var
        DescriptionLbl: Label 'Posts an assembly order with the standard Business Central assembly posting and returns the posted assembly document number.', Comment = 'is-IS=Bókar samsetningarpöntun með venjulegri samsetningarbókun Business Central og skilar númeri bókaða samsetningarskjalsins.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post assembly, finish assembly, assembled, output the kit, consume components', Comment = 'is-IS=bóka samsetningu, ljúka samsetningu, samsett, skila vörusetti, nota íhluti';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Posts an assembly order and consumes components; use PreviewPost to inspect predicted entries first.', Comment = 'is-IS=Bókar samsetningarpöntun og notar íhluti; notaðu PreviewPost til að skoða væntanlegar færslur fyrst.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.Post');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.AssemblyOrder.Post');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := Parts.GetParameters('Inventory.AssemblyOrder.Post');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.AssemblyOrder.Post');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.AssemblyOrder.Post');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.AssemblyOrder.Post');
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
        Related := Parts.GetRelated('Inventory.AssemblyOrder.Post');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Workflow := Parts.GetWorkflow('Inventory.AssemblyOrder.Post');
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Examples := Parts.GetExamples('Inventory.AssemblyOrder.Post');
        exit(Examples.Count() > 0);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.AssemblyOrder.Post');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := Parts.GetNotes('Inventory.AssemblyOrder.Post');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Checks the assembly order and its lines before confirmation or posting. Does not write quantity.</summary>
    procedure ValidateForConfirm(var Argument: Record "Message Argument ori"; var AssemblyHeader: Record "Assembly Header"; var PostingDate: Date; var QuantityToAssemble: Decimal; var ReplacePostingDate: Boolean): Boolean
    var
        AssemblyLine: Record "Assembly Line";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        DocumentLookup: Codeunit "Document Lookup ori";
        RequestValueReader: Codeunit "Request Value Reader ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        RequestJson: JsonObject;
        NoLinesErr: Label 'Assembly order %1 has no lines to post.', Comment = '%1 = document no., is-IS=Samsetningarpöntun %1 hefur engar línur til að bóka.';
        NoLinesNextLbl: Label 'Refresh the assembly lines, then send the call again.', Comment = 'is-IS=Endurnýjaðu samsetningarlínurnar og sendu kallið aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Assembly Header", false, true) then
            exit(false);
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not PostingGate.AssertCanPost(Argument) then
            exit(false);
        RequestJson := Argument.GetRequestJson();
        if not DocumentLookup.FindAssemblyHeader(Argument, AssemblyHeader) then
            exit(false);
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'postingDate', false, PostingDate) then
            exit(false);
        ReplacePostingDate := PostingDate <> 0D;
        if not RequestValueReader.TryReadDecimal(Argument, RequestJson, 'quantityToAssemble', false, QuantityToAssemble) then
            exit(false);
        AssemblyHeader.ReadIsolation := IsolationLevel::UpdLock;
        if not AssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.") then
            exit(false);
        AssemblyLine.ReadIsolation := IsolationLevel::UpdLock;
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        if AssemblyLine.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoLinesErr, AssemblyHeader."No."), 'documentNo', AssemblyHeader."No.", NoLinesErr, NoLinesNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        PostedAsmHeader: Record "Posted Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
        ResponseJson: JsonObject;
        PostingDate: Date;
        QuantityToAssemble: Decimal;
        ReplacePostingDate: Boolean;
        PostingNoBefore: Code[20];
        AssembledQtyBefore: Decimal;
        PostedDocNo: Code[20];
        AssembleToOrder: Boolean;
    begin
        if not ValidateForConfirm(Argument, AssemblyHeader, PostingDate, QuantityToAssemble, ReplacePostingDate) then
            exit;
        if QuantityToAssemble > 0 then begin
            AssemblyHeader.SetHideValidationDialog(true);
            AssemblyHeader.Validate("Quantity to Assemble", QuantityToAssemble);
            AssemblyHeader.Modify(true);
        end;
        PostingNoBefore := AssemblyHeader."Posting No.";
        AssembledQtyBefore := AssemblyHeader."Assembled Quantity";
        AssembleToOrder := AssemblyHeader."Assemble to Order";
        if ReplacePostingDate then
            AssemblyPost.SetPostingDate(true, PostingDate);
        Commit();
        if not AssemblyPost.Run(AssemblyHeader) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
            exit;
        end;
        PostedDocNo := PostingNoBefore;
        if PostedDocNo = '' then
            PostedDocNo := AssemblyHeader."No.";
        PostedAsmHeader.SetCurrentKey("Order No.");
        PostedAsmHeader.SetRange("Order No.", AssemblyHeader."No.");
        if PostedAsmHeader.FindLast() then
            PostedDocNo := PostedAsmHeader."No.";
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('postedDocumentNo', PostedDocNo);
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('postingDate', Format(AssemblyHeader."Posting Date", 0, 9));
        ResponseJson.Add('assembledQuantityBefore', AssembledQtyBefore);
        ResponseJson.Add('assembleToOrder', AssembleToOrder);
        if PostedAsmHeader."No." <> '' then begin
            ResponseJson.Add('postedSystemId', Format(PostedAsmHeader.SystemId, 0, 4));
            ResponseJson.Add('postedQuantity', PostedAsmHeader.Quantity);
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
