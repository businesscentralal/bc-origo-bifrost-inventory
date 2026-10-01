namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.TransferOrder.Release message type.
/// Releases a transfer order so it can be processed and posted.
/// </summary>

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013416 "Transf. Order Release Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Releases a transfer order, changing its status from Open to Released.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'release transfer order, transfer ready to ship, lock the transfer', Comment = 'is-IS=losa millifærslupöntun, staðfesta millifærslupöntun, millifærsla tilbúin til afhendingar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Releases an open transfer order so it can be posted; use Reopen to edit a released order.', Comment = 'is-IS=Leyfir opna millifærslupöntun svo hægt sé að bóka hana; notaðu Reopen til að breyta leyfðri pöntun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.TransferOrder.Release');
        exit(true);
    end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.TransferOrder.Release');
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
        Response := Parts.GetResponse('Inventory.TransferOrder.Release');
        exit(true);
    end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.TransferOrder.Release');
        exit(true);
    end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.TransferOrder.Release');
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
        Related := Parts.GetRelated('Inventory.TransferOrder.Release');
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
        Overview := Parts.GetOverview('Inventory.TransferOrder.Release');
        exit(Overview <> '');
    end;
    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        ResponseJson: JsonObject;
        StatusBefore: Option Open,Released;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindTransferHeader(TransferHeader) then
            exit;

        StatusBefore := TransferHeader.Status;

        if TransferHeader.Status = TransferHeader.Status::Released then begin
            BuildSuccessResponse(TransferHeader, StatusBefore, ResponseJson);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit;
        end;

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader)
        else
            if not Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader) then begin
                Argument.RespondWithError(GetLastErrorText());
                exit;
            end;

        TransferHeader.Find();

        BuildSuccessResponse(TransferHeader, StatusBefore, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildSuccessResponse(TransferHeader: Record "Transfer Header"; StatusBefore: Option Open,Released; var ResponseJson: JsonObject)
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', TransferHeader."No.");
        ResponseJson.Add('transferFromCode', TransferHeader."Transfer-from Code");
        ResponseJson.Add('transferToCode', TransferHeader."Transfer-to Code");
        ResponseJson.Add('directTransfer', TransferHeader."Direct Transfer");
        ResponseJson.Add('statusBefore', StatusToText(StatusBefore));
        ResponseJson.Add('statusAfter', StatusToText(TransferHeader.Status));
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
