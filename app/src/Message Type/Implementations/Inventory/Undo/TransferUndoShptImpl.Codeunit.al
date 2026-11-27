namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Inventory.Transfer.UndoShipment. Runs the standard Undo Transfer Shipment codeunit (9030).
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
        DescriptionLbl: Label 'Undoes a posted transfer shipment with corrective entries.', Comment = 'is-IS=Afturkallar bókaða millifærsluafhendingu með leiðréttingarfærslum. (afturkalla millifærsluafhendingu).';
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
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'No. of the posted transfer shipment to undo, at most 20 characters; a longer value is cut to 20. When lineNos is omitted, every line that is not a correction line is selected.'));
        Parameters.Add(ContractMgt.Parameter('lineNos', 'array', false, 'Optional array of 1 to 100 distinct positive posted shipment line numbers. Every selected line must exist and not be a correction line. Omit to undo all non-correction lines.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks Inv. Posting Gate or cannot write Transfer Shipment Header records.', 'Assign Inv. Posting Gate, the Bifrost "Full Access" permission set (extended by Inventory write permissions) and a Business Central permission set that can change the posted transfer tables.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'documentNo was not sent.', 'Send documentNo, the number of the posted transfer shipment.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'lineNos has the wrong JSON format.', 'Send a document number and, optionally, an array of positive integer line numbers.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'lineNos is empty, has duplicate or non-positive values, or has more than 100 values.', 'Send 1 to 100 distinct positive line numbers or omit lineNos.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No Transfer Shipment Header has that number.', 'Check the number of the posted transfer shipment.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Posted transfer shipment %1 has no lines to undo.', 'The posted transfer shipment has no line that is not a correction line, so there is nothing to undo.', 'Check that the shipment is the original posted shipment and not one that only holds correction lines.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Transfer shipment %1 has already been received and cannot be undone.', 'The selected shipment line has already been received.', 'Create a new transfer order to return the received goods to their original location.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The error text of Business Central', 'Business Central refuses the undo of one line, for example because the line was already undone. The answer carries BusinessCentralError and Business Central''s own error text.', 'Read the text and correct the cause in Business Central. The native operation is atomic: no selected line remains undone after a refusal.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The posted transfer shipment exists and has at least one line that is not a correction line.');
        Preconditions.Add('The undo checks of Business Central pass for every line.');
        Effect.Add('effect', 'irreversible');
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        Effect.Add('changes', CountUnit() + ' ' + 'Undoes selected lines of the posted transfer shipment that are not correction lines, as one filtered native undo operation, which posts the corrective entries. The posted document is not deleted. The undo is committed with the message (the message task commits, or the caller''s transaction under Omit Commit).');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    local procedure CountUnit(): Text
    var
        CountLbl: Label 'expectedCount counts the one posted transfer shipment document, always 1, not the selected lines or corrective entries. When Bifrost Setup requires confirmation, omit expectedCount to obtain the count without changing data. Otherwise omission executes the operation. is-IS: expectedCount telur eina bókaða flutningsafhendingarskjalið, alltaf 1, ekki valdar línur eða leiðréttingarfærslur. Þegar uppsetning Bifröst krefst staðfestingar má sleppa expectedCount til að fá fjöldann án þess að breyta gögnum. Annars er aðgerðin framkvæmd án expectedCount.', Comment = 'is-IS=expectedCount telur eina bókaða flutningsafhendingarskjalið, alltaf 1, ekki valdar línur eða leiðréttingarfærslur. Þegar uppsetning Bifröst krefst staðfestingar má sleppa expectedCount til að fá fjöldann án þess að breyta gögnum. Annars er aðgerðin framkvæmd án expectedCount.';
    begin
        exit(CountLbl);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
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
        ParameterExample1Lbl: Label 'Select existing line numbers from your own document or worksheet', Comment = 'is-IS=Velja fyrirliggjandi línunúmer úr eigin skjali eða vinnublaði';
    begin
        Examples.Add(ContractMgt.Example('Undo posted transfer shipment 108001', '{"type":"Inventory.Transfer.UndoShipment","data":{"expectedCount":1,"documentNo":"108001"}}', '{"status":"Success","documentNo":"108001"}'));
        Examples.Add(ContractMgt.Example(ParameterExample1Lbl, '{"type":"Inventory.Transfer.UndoShipment","data":{"expectedCount":1,"documentNo":"108001","lineNos":[10000]}}', '{"status":"Success","documentNo":"108001"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Undoes a posted transfer shipment by its posted document number, with optional lineNos selecting posted line numbers, with the standard Business Central undo of a transfer shipment line. The posted document is not deleted. The call changes inventory and cannot itself be undone.';
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
        TransferLine: Record "Transfer Line";
        TransferReceiptLine: Record "Transfer Receipt Line";
        Gate: Codeunit "Inventory Domain Gate ori";
        UndoShipment: Codeunit "Undo Transfer Shipment";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocErr: Label 'documentNo is required.', Comment = 'is-IS=documentNo er nauðsynlegt.';
        NotFoundErr: Label 'Posted transfer shipment %1 was not found.', Comment = '%1 = document no., is-IS=Bókuð millifærsluafhending %1 fannst ekki.';
        ReceivedErr: Label 'Transfer shipment %1 has already been received and cannot be undone.', Comment = '%1 = document number, is-IS=Flutningsafhending %1 hefur þegar verið móttekin og er ekki hægt að afturkalla hana.';
        ReceivedNextStepTxt: Label 'Create a new transfer order to return the received goods to the original location.', Comment = 'is-IS=Stofnaðu nýja flutningspöntun til að skila mótteknum vörum á upprunalega birgðageymslu.';
        UnreceivedTxt: Label 'A posted shipment whose selected transfer lines have not been received.', Comment = 'is-IS=Bókuð afhending þar sem valdar flutningslínur hafa ekki verið mótteknar.';
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
        if not SelectLines(RequestJson, TransferShipmentLine, Argument) then
            exit;
        TransferShipmentLine.SetRange("Correction Line", false);
        if not TransferShipmentLine.FindSet() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoLinesErr, DocumentNo), '', '', '', '');
            exit;
        end;
        repeat
            TransferReceiptLine.SetRange("Transfer Order No.", TransferShipmentLine."Transfer Order No.");
            TransferReceiptLine.SetRange("Line No.", TransferShipmentLine."Trans. Order Line No.");
            TransferReceiptLine.SetFilter(Quantity, '<>0');
            if (not TransferReceiptLine.IsEmpty()) or
               (TransferLine.Get(TransferShipmentLine."Transfer Order No.", TransferShipmentLine."Trans. Order Line No.") and
                (TransferLine."Qty. Received (Base)" > 0))
            then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ReceivedErr, DocumentNo), 'documentNo', DocumentNo, UnreceivedTxt, ReceivedNextStepTxt);
                exit;
            end;
        until TransferShipmentLine.Next() = 0;
        TransferShipmentLine.FindSet();
        UndoShipment.SetHideDialog(true);
        if Argument."Omit Commit" then
            UndoShipment.Run(TransferShipmentLine)
        else
            if not UndoShipment.Run(TransferShipmentLine) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
                exit;
            end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure SelectLines(Request: JsonObject; var ShipmentLine: Record "Transfer Shipment Line"; var Argument: Record "Message Argument ori"): Boolean
    var
        SelectedLine: Record "Transfer Shipment Line";
        Token: JsonToken;
        LineToken: JsonToken;
        LineNumbers: JsonArray;
        Seen: List of [Integer];
        LineNo: Integer;
        Serialized: Text;
        LineFilter: Text;
        FormatErr: Label 'lineNos must contain 1 to 100 distinct positive JSON integers.', Comment = 'is-IS=lineNos verður að innihalda 1 til 100 ólíkar jákvæðar JSON-heiltölur.';
        ExpectedTxt: Label 'Existing non-correction line numbers from this posted transfer shipment.', Comment = 'is-IS=Númer fyrirliggjandi lína úr þessari bókuðu flutningsafhendingu sem eru ekki leiðréttingarlínur.';
        NextTxt: Label 'Read the posted shipment lines and send their line numbers in lineNos, or omit lineNos to select all non-correction lines.', Comment = 'is-IS=Lestu línur bókuðu afhendingarinnar og sendu línunúmer þeirra í lineNos eða slepptu lineNos til að velja allar línur sem eru ekki leiðréttingarlínur.';
        MissingErr: Label 'Shipment line %1 was not found on document %2.', Comment = '%1 = line number, %2 = document number; is-IS=Afhendingarlína %1 fannst ekki á skjali %2.';
        UndoneErr: Label 'Shipment line %1 is already undone or is a correction line.', Comment = '%1 = line number; is-IS=Afhendingarlína %1 hefur þegar verið afturkölluð eða er leiðréttingarlína.';
    begin
        if not Request.Get('lineNos', Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if not Token.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, 'lineNos', Serialized, ExpectedTxt, NextTxt);
            exit(false);
        end;
        LineNumbers := Token.AsArray();
        if (LineNumbers.Count() = 0) or (LineNumbers.Count() > 100) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, FormatErr, 'lineNos', Serialized, ExpectedTxt, NextTxt);
            exit(false);
        end;
        foreach LineToken in LineNumbers do begin
            LineToken.WriteTo(Serialized);
            if not LineToken.IsValue() or (DelChr(Serialized, '=', '0123456789') <> '') or
               not Evaluate(LineNo, Serialized, 9)
            then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, 'lineNos', Serialized, ExpectedTxt, NextTxt);
                exit(false);
            end;
            if (LineNo <= 0) or Seen.Contains(LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, FormatErr, 'lineNos', Serialized, ExpectedTxt, NextTxt);
                exit(false);
            end;
            if not SelectedLine.Get(ShipmentLine.GetRangeMin("Document No."), LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingErr, LineNo, ShipmentLine.GetRangeMin("Document No.")), 'lineNos', Serialized, ExpectedTxt, NextTxt);
                exit(false);
            end;
            if SelectedLine."Correction Line" then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(UndoneErr, LineNo), 'lineNos', Serialized, ExpectedTxt, NextTxt);
                exit(false);
            end;
            Seen.Add(LineNo);
            if LineFilter <> '' then
                LineFilter += '|';
            LineFilter += Format(LineNo, 0, 9);
        end;
        ShipmentLine.SetFilter("Line No.", LineFilter);
        exit(true);
    end;
}
