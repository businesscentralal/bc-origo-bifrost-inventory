namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Posts a revaluation journal through native Item Jnl.-Post Batch.</summary>
codeunit 10076866 "Revaluation Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Posts all lines of a Revaluation item journal batch.', Comment = 'is-IS=Bókar allar línur í endurmatsbókarkeyrslu vöru.';
        SelectionLbl: Label 'Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        KeywordsLbl: Label 'inventory,revaluation,inventory value,calculate,preview,post', Comment = 'is-IS=birgðir,endurmat,birgðavirði,reikna,forskoða,bóka';
        OverviewLbl: Label 'Posts every line of an existing non-recurring Revaluation item journal batch in one run, and Business Central commits the posting. Name the batch with the subject (TEMPLATE|BATCH or a SystemId), a SystemId key, or templateName and batchName.', Comment = 'is-IS=Bókar allar línur í fyrirliggjandi endurmatsbókarkeyrslu vöru, sem er ekki ítrekunarbók, í einu lagi og Business Central staðfestir bókunina. Auðkenndu keyrsluna með subject (TEMPLATE|BATCH eða SystemId), SystemId-lykli, eða templateName og batchName.';
        NotesLbl: Label 'The whole batch is posted in one run; no subset of lines can be chosen, and a refusal posts nothing. The batch must be an existing non-recurring batch of a Revaluation journal template with Revaluation lines that have an item number. Name it with the subject (TEMPLATE|BATCH or the SystemId of the batch), one SystemId key, or templateName and batchName; with a subject the data keys are not used, and any other data key is refused. Posting commits: Business Central commits the posting when the call finishes, or the caller does under Omit Commit. It is irreversible and not idempotent: posted lines leave the batch, so a second call is refused. The caller needs BIFROST Full ori and BIFROST InvPost ori, and the Costing domain must be on in Inventory Setup. Use Inventory.Revaluation.PreviewPost first to see the entries.', Comment = 'is-IS=Öll keyrslan er bókuð í einu lagi; ekki er hægt að velja hluta línanna og höfnun bókar ekkert. Keyrslan verður að vera til, ekki ítrekunarbók og af endurmatsbókarsniði, með endurmatslínum sem hafa vörunúmer. Auðkenndu hana með subject (TEMPLATE|BATCH eða SystemId keyrslunnar), einum SystemId-lykli, eða templateName og batchName; með subject eru data-lyklar ekki notaðir og öðrum data-lyklum er hafnað. Bókun er staðfest: Business Central staðfestir bókunina þegar kallinu lýkur, eða kallandinn gerir það með Omit Commit. Bókunin er óafturkræf og ekki endurtakanleg: bókaðar línur fara úr keyrslunni og því er öðru kalli hafnað. Kallandinn þarf BIFROST Full ori og BIFROST InvPost ori og Costing-svið verður að vera virkt í uppsetningu birgða. Notaðu Inventory.Revaluation.PreviewPost fyrst til að sjá færslurnar.';

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
        Process: Codeunit "Inventory Write Process ori";
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('RevaluationPost');
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
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success for a completed native operation.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The resolved native journal template.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The resolved native journal batch.'));
        Fields.Add(ContractMgt.ResponseField('linesPosted', 'integer', 'Number of selected revaluation lines posted.'));
        Fields.Add(ContractMgt.ResponseField('totalQuantity', 'decimal', 'Total native journal quantity.'));
        Fields.Add(ContractMgt.ResponseField('totalAmount', 'decimal', 'Total selected revaluation amount.'));
        Fields.Add(ContractMgt.ResponseField('itemRegisterNo', 'integer', 'Native item register created by posting.'));
        Fields.Add(ContractMgt.ResponseField('fromEntryNo', 'integer', 'First item ledger entry number in the native register.'));
        Fields.Add(ContractMgt.ResponseField('toEntryNo', 'integer', 'Last item ledger entry number in the native register.'));
        Fields.Add(ContractMgt.ResponseField('fromValueEntryNo', 'integer', 'First value entry number in the native register.'));
        Fields.Add(ContractMgt.ResponseField('toValueEntryNo', 'integer', 'Last value entry number in the native register.'));
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
        Effect.Add('effect', 'irreversible');
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        Effect.Add('rollback', false);
        Effect.Add('changes', 'Posts every line of the identified Revaluation journal batch in one run: revaluation value entries and an item register are created and the posted lines leave the batch. Business Central commits the posting when the call finishes; under Omit Commit the commit is left to the caller. A refusal posts nothing.');
        Effect.Add('idempotent', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.PreviewPost', 'Use it first to see the entries the batch would create; it posts nothing.'));
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
            'Post the Revaluation batch DEFAULT of template REVAL',
            '{"type":"Inventory.Revaluation.Post","data":{"templateName":"REVAL","batchName":"DEFAULT"}}',
            '{"status":"Success","templateName":"REVAL","batchName":"DEFAULT","linesPosted":2,"totalQuantity":0,"totalAmount":120.5,"itemRegisterNo":58,"fromValueEntryNo":912,"toValueEntryNo":913}'));
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
