namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013481 "Transf Undo Rcpt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Refuses transfer receipt undo because this BC version has no supported native path.', Comment = 'is-IS=Hafnar afturköllun flutningsmóttöku þar sem þessi útgáfa BC hefur enga studda innbyggða leið.';
        KeywordsLbl: Label 'undo transfer receipt', Comment = 'is-IS=afturkalla móttöku flutnings';
        SelectionDescriptionLbl: Label 'Reports the native transfer receipt undo limitation without modifying posted entries.', Comment = 'is-IS=Tilkynnir takmörkun innbyggðrar afturköllunar flutningsmóttöku án þess að breyta bókuðum færslum.';
        OverviewLbl: Label 'Refuses to undo a posted transfer receipt in this Business Central version.', Comment = 'is-IS=Hafnar afturköllun bókaðrar flutningsmóttöku í þessari útgáfu Business Central.';
        NotesLbl: Label 'A posted transfer receipt that exists returns an error, never a false success.', Comment = 'is-IS=Bókuð flutningsmóttaka sem er til skilar villu, aldrei rangri staðfestingu á árangri.';

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
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.Add('messageType', 'Inventory.Transfer.UndoReceipt');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        Clear(Target);
        TargetJson.Add('table', 'Transfer Receipt Header');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'Posted transfer receipt number. This operation refuses receipt undo.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Error; this version has no successful receipt undo path.'));
        Fields.Add(ContractMgt.ResponseField('error', 'string', 'Refusal text; no native receipt or ledger changes are made.'));
        Fields.Add(ContractMgt.ResponseField('hint', 'string', 'Foundation help hint when present.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.TextErrorEntry('documentNo must be specified.', 'documentNo is absent.', 'Supply a posted receipt number.'));
        Errors.Add(ContractMgt.TextErrorEntry('Posted transfer receipt %1 was not found.', 'The posted receipt does not exist.', 'Check the posted receipt number.'));
        Errors.Add(ContractMgt.TextErrorEntry('Posted transfer receipts cannot be undone in this Business Central version.', 'The posted receipt exists, but this version has no supported native undo path.', 'Use the supported Business Central correction process; receipt undo is not available here.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Required Inventory, table or posting permission is missing.', 'Request the required permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The company Inventory domain is disabled.', 'Enable the domain from Inventory Setup.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.Transfer.UndoShipment', 'Undo a posted transfer shipment. Receipt undo is not available in this version.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReceiptHeader: Record "Transfer Receipt Header";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocErr: Label 'documentNo must be specified.', Comment = 'is-IS=Tilgreina verður documentNo.';
        NotFoundErr: Label 'Posted transfer receipt %1 was not found.', Comment = '%1 = document no.; is-IS=Bókuð flutningsmóttaka %1 fannst ekki.';
        NotSupportedErr: Label 'Posted transfer receipts cannot be undone in this Business Central version.', Comment = 'is-IS=Ekki er hægt að afturkalla bókaðar flutningsmóttökur í þessari útgáfu Business Central.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Receipt Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('documentNo', Token) then begin
            Argument.RespondWithError(MissingDocErr);
            exit;
        end;
        DocumentNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(DocumentNo));
        if not ReceiptHeader.Get(DocumentNo) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DocumentNo));
            exit;
        end;
        Argument.RespondWithError(NotSupportedErr);
    end;
}
