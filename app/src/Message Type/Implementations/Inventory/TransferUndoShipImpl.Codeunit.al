namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Inventory.Transfer.UndoShipment. Undoes a posted transfer shipment via codeunit 5815.
/// </summary>
codeunit 70013471 "Transfer Undo Ship Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled(Enum::"Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Shipment Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Undoes a posted transfer shipment. Does not delete the posted document.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'undo transfer shipment, reverse posted transfer ship', Comment = 'is-IS=afturkalla flutningsafhendingu, bakfæra bókaða flutningsafhendingu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Reverses a posted transfer shipment when the quantity is still available and not reserved.', Comment = 'is-IS=Bakfærir bókaða flutningsafhendingu ef magn er enn til og ekki frátekið.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
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
    begin
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        UndoTransferShipment: Codeunit "Undo Transfer Shipment";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", false, true) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('documentNo', Token) and Token.IsValue() then
            DocumentNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(DocumentNo));
        if DocumentNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'documentNo is required.', 'documentNo', '', '', '');
            exit;
        end;
        if not TransferShipmentHeader.Get(DocumentNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'Transfer shipment was not found.', 'documentNo', DocumentNo, '', '');
            exit;
        end;

        UndoTransferShipment.SetHideDialog(true);
        UndoTransferShipment.Run(TransferShipmentHeader);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
