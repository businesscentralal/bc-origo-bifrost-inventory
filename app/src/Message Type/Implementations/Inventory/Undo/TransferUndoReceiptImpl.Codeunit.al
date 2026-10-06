namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Inventory.Transfer.UndoReceipt. Calls codeunit 5816. Does not delete the posted document.
/// </summary>
codeunit 70013481 "Transf Undo Rcpt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Receipt Header", false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Receipt Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Undoes a posted transfer receipt by writing corrective item ledger entries.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('undo transfer receipt');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Undoes a posted transfer receipt. Does not delete the posted document.');
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

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TransferReceiptLine: Record "Transfer Receipt Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocumentErr: Label 'documentNo is required.', Locked = true;
        NothingToUndoErr: Label 'Transfer receipt %1 has no lines to undo.', Comment = '%1 = document no.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Receipt Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('documentNo', Token) then begin
            Argument.RespondWithError(MissingDocumentErr);
            exit;
        end;
        DocumentNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DocumentNo));
        TransferReceiptLine.SetRange("Document No.", DocumentNo);
        TransferReceiptLine.SetRange(Correction, false);
        if not TransferReceiptLine.FindSet() then begin
            Argument.RespondWithError(StrSubstNo(NothingToUndoErr, DocumentNo));
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Undo Transfer Receipt", TransferReceiptLine) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.Transfer.UndoReceipt');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
    end;
}
