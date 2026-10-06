namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.TransferOrder.Reopen message type.
/// Reopens a released transfer order so it can be edited again.
/// </summary>

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013417 "Transfer Order Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Reopens a transfer order, changing its status from Released to Open.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reopen transfer order, change released transfer, unlock transfer', Comment = 'is-IS=opna millifærslupöntun aftur, breyta staðfestri millifærslu, aflæsa millifærslu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reopens a released transfer order for editing; use Release to prepare it for posting again.', Comment = 'is-IS=Opnar leyfða millifærslupöntun aftur til breytinga; notaðu Release til að undirbúa hana fyrir bókun á ný.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.TransferOrder.Reopen');
        exit(true);
    end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.TransferOrder.Reopen');
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
        Response := Parts.GetResponse('Inventory.TransferOrder.Reopen');
        exit(true);
    end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.TransferOrder.Reopen');
        exit(true);
    end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.TransferOrder.Reopen');
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
        Related := Parts.GetRelated('Inventory.TransferOrder.Reopen');
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
        Overview := Parts.GetOverview('Inventory.TransferOrder.Reopen');
        exit(Overview <> '');
    end;
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := '';
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        DocumentLookup: Codeunit "Document Lookup ori";
        ResponseJson: JsonObject;
        StatusBefore: Option Open,Released;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not DocumentLookup.FindTransferHeader(Argument, TransferHeader) then
            exit;

        StatusBefore := TransferHeader.Status;

        if TransferHeader.Status = TransferHeader.Status::Open then begin
            BuildSuccessResponse(TransferHeader, StatusBefore, ResponseJson);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit;
        end;

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Transf. Order Reopen Proc. ori", TransferHeader)
        else
            if not Codeunit.Run(Codeunit::"Transf. Order Reopen Proc. ori", TransferHeader) then begin
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
