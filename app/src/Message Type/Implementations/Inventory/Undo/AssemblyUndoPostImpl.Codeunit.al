namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.History;
using Origo.Bifrost;

codeunit 10076909 "Assembly Undo Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, false) and
            DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Posted Assembly Header");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Undoes a posted assembly document through the standard posted assembly undo.', Comment = 'is-IS=Afturkallar bókað samsetningarskjal með staðlaðri afturköllun bókaðrar samsetningar.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'undo assembly, reverse posted assembly', Comment = 'is-IS=afturkalla samsetningu, bakfæra bókaða samsetningu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Undoes a posted assembly by document number.', Comment = 'is-IS=Afturkallar bókaða samsetningu eftir skjalnúmeri.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The posted assembly is named under data.documentNo; subject is not read.');
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
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', 'The No. of the Posted Assembly Header to undo. It is the posted assembly number, not the number of the assembly order.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'No. of the posted assembly to undo, at most 20 characters; a longer value is cut to 20.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The posted assembly No. that was undone, as sent (cut to 20 characters).'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Assembly domain is turned off for this company.', 'Turn the domain on from the Inventory Setup page, then send the call again.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks BIFROST InvPost ori or cannot write Posted Assembly Header records.', 'Assign BIFROST InvPost ori, BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change the posted assembly tables.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'documentNo was not sent or is empty.', 'Send the posted assembly number in documentNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'documentNo is not text.', 'Send a JSON string of at most20characters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The posted assembly does not exist.', 'Use the posted number, not the assembly order number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native undo refuses the selected posted assembly.', 'Correct the document named by the refusal; the isolated undo leaves no partial reversal.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The posted assembly exists.');
        Preconditions.Add('The undo checks of Business Central pass.');
        Effect.Add('effect', 'irreversible');
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        Effect.Add('changes', 'Undoes the posted assembly with the standard Business Central undo of a posted assembly, which posts the reversing entries. The undo is committed with the message (the message task commits, or the caller''s transaction under Omit Commit).');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori and BIFROST InvPost ori');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Post an assembly order instead of undoing a posted assembly.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Create', 'Create a new assembly order with the corrected data after the posted assembly was undone.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post the assembly order; the answer carries the posted document number in postedDocumentNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Assembly.UndoPost', 'Undo that posted assembly when the posting was wrong, with the posted document number as documentNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Create', 'Create a new assembly order with the corrected data.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Undo posted assembly 132001', '{"type":"Inventory.Assembly.UndoPost","data":{"documentNo":"132001"}}', '{"status":"Success","documentNo":"132001"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Undoes a posted assembly by its posted document number with the standard Business Central undo. Business Central posts the reversing entries, so the call changes inventory and cannot itself be undone.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Use the posted assembly number in documentNo, not the assembly order number. The Assembly domain, native document write permission and BIFROST InvPost ori are required. Native undo commits are suppressed inside one isolated transaction: a failure rolls back reversing entries and the header change. Standalone undo commits its isolated operation; chained Omit Commit calls remain in the caller transaction and propagate native failures. Subject is not used.', Comment = 'is-IS=Notaðu númer bókaðrar samsetningar í documentNo, ekki númer samsetningarpöntunar. Samsetningarsviðið, innbyggð skrifheimild á skjalið og BIFROST InvPost ori eru nauðsynleg. Innbyggðar staðfestingar afturköllunar eru bældar í einni einangraðri færslu: villa afturkallar mótfærslur og breytingu á haus. Sjálfstætt kall staðfestir einangruðu aðgerðina; keðjuð Omit Commit köll haldast í færslu kallandans og láta innbyggðar villur berast áfram. Subject er ekki notað.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        PostedAssemblyHeader: Record "Posted Assembly Header";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Inventory Write Process ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        DocumentNo: Code[20];
        DocumentExpectedTxt: Label 'An existing posted assembly document that can be undone.', Comment = 'is-IS=Bókað samsetningarskjal sem er til og hægt er að afturkalla.';
        DocumentNextStepTxt: Label 'Send the posted assembly number in documentNo and resolve its native posting constraints.', Comment = 'is-IS=Sendu númer bókaðrar samsetningar í documentNo og leystu innbyggðar bókunartakmarkanir þess.';
        NotFoundErr: Label 'Posted assembly %1 was not found.', Comment = '%1 = document no., is-IS=Bókuð samsetning %1 fannst ekki.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, false) then
            exit;
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        DocumentNo := CopyStr(Parts.ReadRequestText(Argument, RequestJson, 'documentNo', true, 20), 1, 20);
        if Parts.RespondToProblems(Argument) then
            exit;
        if not PostedAssemblyHeader.Get(DocumentNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, DocumentNo), 'documentNo', DocumentNo, DocumentExpectedTxt, DocumentNextStepTxt);
            exit;
        end;

        Process.SetOperation('AssemblyUndo');
        Process.SetPostedAssemblyNo(DocumentNo);
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'documentNo', DocumentNo, DocumentExpectedTxt, DocumentNextStepTxt);
                exit;
            end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

}
