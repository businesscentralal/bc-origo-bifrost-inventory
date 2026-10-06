namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Inventory.Transfer.UndoShipment. Runs codeunit 5815 Undo Transfer Shipment.
/// </summary>
codeunit 70013480 "Transfer Undo Shpt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Shipment Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Undoes a posted transfer shipment with corrective entries.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('undo transfer shipment');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Same action as Undo Shipment on a posted transfer shipment.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope('Inventory.Transfer.UndoShipment');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Calls codeunit 5815. Does not delete the posted document.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Receipt undo is a separate type.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferShipmentHeader: Record "Transfer Shipment Header";
        Gate: Codeunit "Inventory Domain Gate ori";
        UndoShipment: Codeunit "Undo Transfer Shipment";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocErr: Label 'documentNo is required.', Locked = true;
        NotFoundErr: Label 'Posted transfer shipment %1 was not found.', Comment = '%1 = document no.', Locked = true;
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('documentNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingDocErr, 'documentNo', '', '', '');
            exit;
        end;
        DocumentNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(DocumentNo));
        if not TransferShipmentHeader.Get(DocumentNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, DocumentNo), 'documentNo', '', '', '');
            exit;
        end;
        UndoShipment.SetHideDialog(true);
        if not UndoShipment.Run(TransferShipmentHeader) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
