namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
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
        Errors.Add(ContractMgt.TextErrorEntry('documentNo is required.', 'documentNo was not sent. The answer carries the error text and no code.', 'Send documentNo, the number of the posted assembly.'));
        Errors.Add(ContractMgt.TextErrorEntry('Posted assembly %1 was not found.', 'No Posted Assembly Header has that number. The answer carries the error text and no code.', 'Check the number. It is the posted assembly number, not the assembly order number.'));
        Errors.Add(ContractMgt.TextErrorEntry('The error text of Business Central', 'Business Central refuses the undo, for example when the posted assembly cannot be undone. The answer carries Business Central''s own error text and no code.', 'Read the text, correct the cause in Business Central and send the call again.'));
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
    begin
        Notes := 'The undo commits: the message task commits when the message completes, and under Omit Commit the caller''s transaction commits instead. The type itself does not commit. ' +
            'documentNo is the number of the posted assembly (the posted document), not the number of the assembly order; the type looks it up in the Posted Assembly Header table only. ' +
            'The caller needs the Assembly domain turned on in Inventory Setup and write permission on the posted assembly table. The BIFROST InvPost ori permission set is required because undo posts reversing entries. ' +
            'A refusal from Business Central is answered with its error text and no error code. The type does not read subject. ' +
            'Post the assembly again with Inventory.AssemblyOrder.Post, or create a new assembly order with Inventory.AssemblyOrder.Create, once the posted assembly is undone.';
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocErr: Label 'documentNo is required.', Comment = 'is-IS=documentNo er nauðsynlegt.';
        NotFoundErr: Label 'Posted assembly %1 was not found.', Comment = '%1 = document no., is-IS=Bókuð samsetning %1 fannst ekki.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, false) then
            exit;
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('documentNo', Token) then begin
            Argument.RespondWithError(MissingDocErr);
            exit;
        end;
        DocumentNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DocumentNo));
        if not PostedAssemblyHeader.Get(DocumentNo) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DocumentNo));
            exit;
        end;

        if not TryUndoPostedAssembly(PostedAssemblyHeader) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryUndoPostedAssembly(var PostedAssemblyHeader: Record "Posted Assembly Header")
    var
        AssemblyPost: Codeunit "Assembly-Post";
    begin
        AssemblyPost.Undo(PostedAssemblyHeader, false);
    end;
}
