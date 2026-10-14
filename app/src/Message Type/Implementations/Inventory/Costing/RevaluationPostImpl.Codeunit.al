namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Posts a revaluation journal through native Item Jnl.-Post Batch.</summary>
codeunit 70013403 "Revaluation Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv Reval Post Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv Reval Post Process ori", Argument) then
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
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"templateName","type":"string","required":false},{"name":"batchName","type":"string","required":false},{"name":"batchId","type":"string","required":false},{"name":"id","type":"string","required":false},{"name":"systemId","type":"string","required":false},{"name":"recordSystemId","type":"string","required":false}]');
        exit(true);
    end;

    /// <summary>Returns the native revaluation response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"status":"Success","templateName":"","batchName":"","linesPosted":0,"totalQuantity":0,"totalAmount":0,"itemRegisterNo":0,"fromEntryNo":0,"toEntryNo":0,"fromValueEntryNo":0,"toValueEntryNo":0}');
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
        exit('Posts a revaluation journal through native Item Jnl.-Post Batch.');
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Posts a revaluation journal through native Item Jnl.-Post Batch.');
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit('Posts a revaluation journal through native Item Jnl.-Post Batch.');
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := 'Posts a revaluation journal through native Item Jnl.-Post Batch. Explicit Revaluation batch required. Calculate refuses a nonempty batch and never updates Standard Cost. Post/PreviewPost require native revaluation lines. Normal licensed dispatch applies.';
        exit(true);
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := 'Posts a revaluation journal through native Item Jnl.-Post Batch. Explicit Revaluation batch required. Calculate refuses a nonempty batch and never updates Standard Cost. Post/PreviewPost require native revaluation lines. Normal licensed dispatch applies.';
        exit(true);
    end;
}
