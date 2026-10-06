namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013426 "Asm. Order Release Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Releases an open assembly order so it can be posted (status Open -> Released).');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'release assembly order, assembly ready, lock the assembly order', Comment = 'is-IS=losa samsetningarpöntun, staðfesta samsetningarpöntun, samsetning tilbúin';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Releases an open assembly order so it can be posted; use Reopen to edit a released order.', Comment = 'is-IS=Leyfir opna samsetningarpöntun svo hægt sé að bóka hana; notaðu Reopen til að breyta leyfðri pöntun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.Release');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.AssemblyOrder.Release');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.AssemblyOrder.Release');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.AssemblyOrder.Release');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.AssemblyOrder.Release');
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
        Related := Parts.GetRelated('Inventory.AssemblyOrder.Release');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.AssemblyOrder.Release');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := '';
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        AssemblyHeader: Record "Assembly Header";
        DocumentLookup: Codeunit "Document Lookup ori";
        ReleaseAssemblyDoc: Codeunit "Release Assembly Document";
        ResponseJson: JsonObject;
        StatusBefore: Text;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Assembly Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DocumentLookup.FindAssemblyHeader(Argument, AssemblyHeader) then
            exit;
        StatusBefore := StatusToText(AssemblyHeader.Status);
        if AssemblyHeader.Status = AssemblyHeader.Status::Released then begin
            BuildSuccessResponse(AssemblyHeader, StatusBefore, ResponseJson);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit;
        end;
        ReleaseAssemblyDoc.Run(AssemblyHeader);
        AssemblyHeader.Find();
        BuildSuccessResponse(AssemblyHeader, StatusBefore, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildSuccessResponse(AssemblyHeader: Record "Assembly Header"; StatusBefore: Text; var ResponseJson: JsonObject)
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('systemId', Format(AssemblyHeader.SystemId, 0, 4));
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('statusBefore', StatusBefore);
        ResponseJson.Add('statusAfter', StatusToText(AssemblyHeader.Status));
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
