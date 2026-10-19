namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Runs native revaluation posting preview and returns captured entries without committing.</summary>
codeunit 70013407 "Reval Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Runs native revaluation posting preview and returns captured entries without committing.', Comment = 'is-IS=Forskoðar innbyggða endurmatsbókun og skilar færslum án þess að varðveita þær.';
        SelectionLbl: Label 'Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        KeywordsLbl: Label 'inventory,revaluation,inventory value,calculate,preview,post', Comment = 'is-IS=birgðir,endurmat,birgðavirði,reikna,forskoða,bóka';
        OverviewLbl: Label 'Runs native revaluation posting preview and returns captured entries without committing. Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Forskoðar innbyggða endurmatsbókun og skilar færslum án þess að varðveita þær. Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        NotesLbl: Label 'PreviewPost requires native revaluation lines and posting permission. Preview entries are rolled back; journal lines remain unchanged. Normal licensing and company domain gates apply.', Comment = 'is-IS=PreviewPost krefst innbyggðra endurmatslína og bókunarheimildar. Forskoðunarfærslur eru bakfærðar; bókarlínur haldast óbreyttar. Venjulegar leyfis- og fyrirtækisheimildir gilda.';

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
        Gate: Codeunit "Inventory Domain Gate ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        NativeJournal.PreviewRevaluation(Argument);
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
        Fields.Add(ContractMgt.ResponseField('linesToPost', 'integer', 'Number of selected lines included in the rollback preview.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'True: native preview entries have been rolled back.'));
        Fields.Add(ContractMgt.ResponseField('preview', 'array', 'Captured native preview entries grouped by table.'));
        Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Native preview G/L totals.'));
        Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total native preview entry count.'));
        Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Native preview G/L entry count.'));
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
        Errors.Add(ContractMgt.TextErrorEntry('Native posting preview error.','Native preview fails or its captured entries cannot be accepted.','Correct the native posting error; failed preview retains no ledger changes.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"writes":false,"posts":false,"rollback":true,"changes":"Runs native revaluation posting preview and returns captured entries without committing."}');
        exit(true);
    end;

    /// <summary>Returns the native revaluation related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.Revaluation.Calculate","useInsteadWhen":"Calculate the journal."},{"name":"Inventory.Revaluation.Post","useInsteadWhen":"Post the journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native revaluation examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Runs native revaluation posting preview and returns captured entries without committing.","request":{"type":"Inventory.Revaluation.PreviewPost","subject":"REVAL|OWNED"}}]');
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
