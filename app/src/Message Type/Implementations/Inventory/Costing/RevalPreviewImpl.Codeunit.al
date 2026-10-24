namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Runs native revaluation posting preview and returns captured entries without committing.</summary>
codeunit 10076864 "Reval Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Runs native revaluation posting preview and returns captured entries without committing.', Comment = 'is-IS=Forskoðar innbyggða endurmatsbókun og skilar færslum án þess að varðveita þær.';
        SelectionLbl: Label 'Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        KeywordsLbl: Label 'inventory,revaluation,inventory value,calculate,preview,post', Comment = 'is-IS=birgðir,endurmat,birgðavirði,reikna,forskoða,bóka';
        OverviewLbl: Label 'Runs native revaluation posting preview and returns captured entries without committing. Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Forskoðar innbyggða endurmatsbókun og skilar færslum án þess að varðveita þær. Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        NotesLbl: Label 'The batch is posted and rolled back, so nothing is committed and the journal lines stay unchanged; the answer carries rollback true, the entries grouped by table in preview, totals and the entry counts. The batch is identified as in Inventory.Revaluation.Post and must have Revaluation lines that have an item number. A preview that would create no entries is answered with NothingToPreview, and a refusal from Business Central is returned as BusinessCentralError with its own text. The call can be repeated freely. The caller needs BIFROST Full ori and BIFROST InvPost ori, as for posting, and the Costing domain must be on in Inventory Setup.', Comment = 'is-IS=Keyrslan er bókuð og bakfærð, svo ekkert er staðfest og bókarlínur haldast óbreyttar; svarið inniheldur rollback true, færslurnar flokkaðar eftir töflu í preview, heildartölur og fjölda færslna. Keyrslan er auðkennd eins og í Inventory.Revaluation.Post og verður að hafa endurmatslínur sem hafa vörunúmer. Forskoðun sem myndi ekki búa til neinar færslur fær svarið NothingToPreview, og höfnun frá Business Central er skilað sem BusinessCentralError með eigin texta. Hægt er að endurtaka kallið að vild. Kallandinn þarf BIFROST Full ori og BIFROST InvPost ori, eins og fyrir bókun, og Costing-svið verður að vera virkt í uppsetningu birgða.';

    /// <summary>Requires company Costing, native journal writes and a posting token.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::Costing, Database::"Item Journal Line", true, true));
    end;

    /// <summary>Returns the batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Revaluation requests use inbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        FailureJournal: Codeunit "Inventory Native Journal ori";
        Gate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Inventory Read Process ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('RevaluationPreview');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                FailureJournal.RespondWithFailure(Argument);
    end;

    /// <summary>Returns the native revaluation envelope contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|BATCH","systemId"]},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the native revaluation target contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('subject', 'TEMPLATE|BATCH', 'The template name and the batch name of the Revaluation journal batch, separated by a vertical bar; each part is at most 10 characters.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item Journal Batch.'));
        Target.Add(ContractMgt.TargetEntry('data.batchId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the batch. Used only when subject is empty, and only one of the four keys may be sent.'));
        Target.Add(ContractMgt.TargetEntry('data.templateName, data.batchName', 'template name and batch name', 'The Revaluation template and its batch, used when neither subject nor a SystemId key is sent.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation parameters contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Existing Revaluation template, at most 10 characters; supply with batchName if no subject or SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Existing batch, at most 10 characters. Subject or SystemId selection takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('batchId', 'string', false, 'Batch SystemId; only one SystemId alias may be supplied when subject is absent.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias of batchId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias of batchId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias of batchId.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Totals: JsonObject;
        TotalsChildren: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The template of the identified journal batch.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The identified journal batch.'));
        Fields.Add(ContractMgt.ResponseField('linesToPost', 'integer', 'The number of lines of the batch that the preview included.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true: the previewed entries were rolled back and nothing is kept.'));
        Fields.Add(ContractMgt.ResponseField('preview', 'array', 'The entries the posting would create, grouped by table.'));
        TotalsChildren.Add(ContractMgt.ResponseField('balanced', 'boolean', 'True when debit and credit totals agree; present only when the preview has G/L entries.'));
        TotalsChildren.Add(ContractMgt.ResponseField('totalDebitLCY', 'decimal', 'The total debit amount of the previewed G/L entries.'));
        TotalsChildren.Add(ContractMgt.ResponseField('totalCreditLCY', 'decimal', 'The total credit amount of the previewed G/L entries.'));
        Totals := ContractMgt.ResponseField('totals', 'object', 'The totals of the previewed G/L entries.');
        Totals.Add('children', TotalsChildren);
        Fields.Add(Totals);
        Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'The number of previewed entries in all tables.'));
        Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'The number of previewed G/L entries.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the native revaluation errors contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Costing domain is turned off in Inventory Setup.', 'Turn on the Costing domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not hold the BIFROST InvPost ori permission set.', 'Ask an administrator to assign BIFROST InvPost ori.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'The preview would create no entries, so nothing would be posted.', 'Check the lines of the Revaluation batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A batch selector is malformed or an unsupported parameter is supplied.', 'Use the named parameter and expected value to select one revaluation batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A batch name or identifier is not nonempty text in the required format.', 'Correct the named parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No revaluation batch matches templateName and batchName.', 'Select an existing owned batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The revaluation batch is empty.', 'Calculate the revaluation lines before posting or previewing.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native validation or posting fails; known validation failures name lineNo and its document.', 'Correct the selected journal line; no failed posting is committed.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('rollback', true);
        Effect.Add('changes', 'None. Runs the revaluation posting for the batch, returns the entries it would create, and rolls everything back. Nothing is committed and the journal lines stay unchanged.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori and BIFROST InvPost ori');
        Preconditions.Add('The Costing domain is turned on in Inventory Setup.');
        Preconditions.Add('The batch is an existing non-recurring batch of a Revaluation journal template with at least one Revaluation line.');
        Preconditions.Add('The caller holds BIFROST InvPost ori and can write item journal lines.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Returns the native revaluation related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Post', 'Use it to post the batch once the preview is acceptable.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Calculate', 'Use it to read the remaining quantity and value of an item; it does not touch the journal.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Preview the Revaluation batch DEFAULT of template REVAL',
            '{"type":"Inventory.Revaluation.PreviewPost","data":{"templateName":"REVAL","batchName":"DEFAULT"}}',
            '{"status":"Success","templateName":"REVAL","batchName":"DEFAULT","linesToPost":2,"rollback":true,"preview":[],"totals":{"balanced":true,"totalDebitLCY":120.5,"totalCreditLCY":120.5},"entryCount":6,"glEntryCount":4}'));
        exit(true);
    end;

    /// <summary>No override is provided.</summary>
    procedure GetMetering(var Value: JsonObject): Boolean
    begin
        Clear(Value);
        exit(false);
    end;

    /// <summary>No override is provided.</summary>
    procedure GetWorkflow(var Value: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Value);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Revaluation.Calculate', 'Read the remaining quantity and value of an item to decide the new value.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Revaluation.PreviewPost', 'Preview the entries the Revaluation batch would create.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Revaluation.Post', 'Post the batch once the preview is acceptable.'));
        Value.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := NotesLbl;
        exit(true);
    end;
}
