namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Runs native revaluation posting preview and returns captured entries without committing.</summary>
codeunit 70013404 "Reval Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

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
        Revaluation: Codeunit "Inventory Revaluation ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Revaluation.Preview(Argument);
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
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('batchId', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, ''));
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
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the native revaluation errors contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"PreconditionFailed","when":"Wrong journal type, recurring or invalid batch, or native calculation/posting failure."},{"code":"PermissionDenied","when":"Company/native permission or posting gate refuses caller."},{"code":"InvalidParameter","when":"Parameters are malformed or unsupported."}]');
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
        exit('Runs native revaluation posting preview and returns captured entries without committing.');
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Runs native revaluation posting preview and returns captured entries without committing.');
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit('Runs native revaluation posting preview and returns captured entries without committing.');
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := 'Runs native revaluation posting preview and returns captured entries without committing. Explicit Revaluation batch required. Calculate refuses a nonempty batch and never updates Standard Cost. Post/PreviewPost require native revaluation lines. Normal licensed dispatch applies.';
        exit(true);
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := 'Runs native revaluation posting preview and returns captured entries without committing. Explicit Revaluation batch required. Calculate refuses a nonempty batch and never updates Standard Cost. Post/PreviewPost require native revaluation lines. Normal licensed dispatch applies.';
        exit(true);
    end;
}
