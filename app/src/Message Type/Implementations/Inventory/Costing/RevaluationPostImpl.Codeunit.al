namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Posts a revaluation journal through native Item Jnl.-Post Batch.</summary>
codeunit 70013406 "Revaluation Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Posts a revaluation journal through native Item Jnl.-Post Batch.', Comment = 'is-IS=Bókar endurmatsbók með innbyggðri vörubókun.';
        SelectionLbl: Label 'Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        KeywordsLbl: Label 'inventory,revaluation,inventory value,calculate,preview,post', Comment = 'is-IS=birgðir,endurmat,birgðavirði,reikna,forskoða,bóka';
        OverviewLbl: Label 'Posts a revaluation journal through native Item Jnl.-Post Batch. Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Bókar endurmatsbók með innbyggðri vörubókun. Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        NotesLbl: Label 'Post requires native revaluation lines and posting permission. The whole batch is posted atomically; no line subset is supported. Normal licensing and company domain gates apply.', Comment = 'is-IS=Post krefst innbyggðra endurmatslína og bókunarheimildar. Öll keyrslan er bókuð sem ein heild; ekki er hægt að velja hluta línanna. Venjulegar leyfis- og fyrirtækisheimildir gilda.';

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
                Argument.RespondWithError(GetLastErrorText());
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
    begin
        Clear(Target);
        Target.ReadFrom('[{"table":"Item Journal Batch","selection":"An explicitly identified Revaluation template batch."}]');
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
        Errors.Add(ContractMgt.TextErrorEntry('Native selection, validation or report error.','Wrong journal type, recurring or invalid batch, or native calculation/posting failure. The direct native call may raise; the process wrapper returns text without a typed code.','Correct the selected batch, input or native validation error before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Company/native permission or posting gate refuses caller.', 'Request the required native permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Company Costing is disabled or a typed request value is invalid.', 'Enable the company domain or correct the request value.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"writes":true,"posts":true,"rollback":false,"changes":"Posts a revaluation journal through native Item Jnl.-Post Batch."}');
        exit(true);
    end;

    /// <summary>Returns the native revaluation related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.Revaluation.Calculate","useInsteadWhen":"Calculate the journal."},{"name":"Inventory.Revaluation.PreviewPost","useInsteadWhen":"PreviewPost the journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native revaluation examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Posts a revaluation journal through native Item Jnl.-Post Batch.","request":{"type":"Inventory.Revaluation.Post","subject":"REVAL|OWNED"}}]');
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
    begin
        Clear(Value);
        exit(false);
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
