namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Inventory.Transfer.UndoShipment. Runs codeunit 5815 Undo Transfer Shipment.
/// </summary>
codeunit 10076910 "Transfer Undo Shpt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, false) and
            Gate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Shipment Header");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Undoes a posted transfer shipment with corrective entries.', Comment = 'is-IS=Afturkallar bókaða millifærsluafhendingu með leiðréttingarfærslum.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'undo transfer shipment', Comment = 'is-IS=afturkalla millifærsluafhendingu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Same action as Undo Shipment on a posted transfer shipment.', Comment = 'is-IS=Sama aðgerð og Afturkalla afhendingu á bókaðri millifærsluafhendingu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        // Own envelope: the shared one declares subject optional, but this type reads only data.documentNo.
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The posted transfer shipment is named under data.documentNo; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', 'The No. of the Transfer Shipment Header to undo.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'No. of the posted transfer shipment to undo, at most 20 characters; a longer value is cut to 20. Every line that is not a correction line is undone.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The posted transfer shipment No. that was undone, as sent (cut to 20 characters).'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Transfer Orders domain is turned off for this company.', 'Turn the domain on from the Inventory Setup page, then send the call again.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks Inv. Posting Gate or cannot write Transfer Shipment Header records.', 'Assign Inv. Posting Gate, Bifrost Full Access (extended by Inventory write permissions) and a Business Central permission set that can change the posted transfer tables.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'documentNo was not sent.', 'Send documentNo, the number of the posted transfer shipment.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No Transfer Shipment Header has that number.', 'Check the number of the posted transfer shipment.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Posted transfer shipment %1 has no lines to undo.', 'The posted transfer shipment has no line that is not a correction line, so there is nothing to undo. The answer carries the error text and no code.', 'Check that the shipment is the original posted shipment and not one that only holds correction lines.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The error text of Business Central', 'Business Central refuses the undo of one line, for example because the line was already undone. The answer carries Business Central''s own error text and no code.', 'Read the text and correct the cause in Business Central. Lines that came before the refused line may already be undone: read the posted shipment before you send the call again.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The posted transfer shipment exists and has at least one line that is not a correction line.');
        Preconditions.Add('The undo checks of Business Central pass for every line.');
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Undoes every line of the posted transfer shipment that is not a correction line, as one filtered native undo operation, which posts the corrective entries. The posted document is not deleted. The undo is committed with the message (the message task commits, or the caller''s transaction under Omit Commit).');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'Bifrost Full Access and Inv. Posting Gate');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Transfer.UndoReceipt', 'Use it for a posted transfer receipt; it only answers that receipt undo is not available in this version.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Post', 'Post the transfer order instead of undoing a posted shipment.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Ship the transfer order; the answer carries the posted shipment number in postedShipmentNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Transfer.UndoShipment', 'Undo that posted shipment when the shipping was wrong, with the posted shipment number as documentNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Ship the transfer order again with the corrected data when it is still needed.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Undo posted transfer shipment 108001', '{"type":"Inventory.Transfer.UndoShipment","data":{"documentNo":"108001"}}', '{"status":"Success","documentNo":"108001"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Undoes a posted transfer shipment by its posted document number, line by line, with the standard Business Central undo of a transfer shipment line. The posted document is not deleted. The call changes inventory and cannot itself be undone.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Use the posted transfer shipment number in documentNo. Only non-correction lines of that document are selected and passed together to native undo. A failure rolls back all selected lines and reversing entries; other shipments are untouched. Standalone undo commits its isolated operation; chained Omit Commit calls remain in the caller transaction and propagate native failures. Transfer Orders, native shipment write permission and Inv. Posting Gate are required. A shipment with no lines to undo is refused. Receipt undo is a separate unavailable operation. Subject is not used.', Comment = 'is-IS=Notaðu númer bókaðrar millifærsluafhendingar í documentNo. Aðeins línur þess skjals sem eru ekki leiðréttingarlínur eru valdar og sendar saman í innbyggða afturköllun. Villa afturkallar allar valdar línur og mótfærslur; öðrum afhendingum er ekki breytt. Sjálfstætt kall staðfestir einangruðu aðgerðina; keðjuð Omit Commit köll haldast í færslu kallandans og láta innbyggðar villur berast áfram. Flutningspöntunarsviðið, innbyggð skrifheimild á afhendinguna og Bókunarhlið birgða eru nauðsynleg. Afhendingu án lína til afturköllunar er hafnað. Afturköllun móttöku er aðskilin aðgerð sem er ekki í boði. Subject er ekki notað.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferShipmentLine: Record "Transfer Shipment Line";
        Gate: Codeunit "Inventory Domain Gate ori";
        UndoShipment: Codeunit "Undo Transfer Shipment";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocErr: Label 'documentNo is required.', Comment = 'is-IS=documentNo er nauðsynlegt.';
        NotFoundErr: Label 'Posted transfer shipment %1 was not found.', Comment = '%1 = document no., is-IS=Bókuð millifærsluafhending %1 fannst ekki.';
        NoLinesErr: Label 'Posted transfer shipment %1 has no lines to undo.', Comment = '%1 = document no., is-IS=Bókuð millifærsluafhending %1 hefur engar línur til að afturkalla.';
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, false) then
            exit;
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, true) then
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
        TransferShipmentLine.SetRange("Document No.", TransferShipmentHeader."No.");
        TransferShipmentLine.SetRange("Correction Line", false);
        if not TransferShipmentLine.FindSet() then begin
            Argument.RespondWithError(StrSubstNo(NoLinesErr, DocumentNo));
            exit;
        end;
        UndoShipment.SetHideDialog(true);
        if Argument."Omit Commit" then
            UndoShipment.Run(TransferShipmentLine)
        else
            if not UndoShipment.Run(TransferShipmentLine) then begin
                Argument.RespondWithError(GetLastErrorText());
                exit;
            end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
