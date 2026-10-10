namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.AdjustCost.Run. Runs report 795 with the same filters as the job queue request page.
/// </summary>
codeunit 70013460 "Adjust Cost Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks whether the existing costing domain and Item write gates are enabled.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, true, true));
    end;

    /// <summary>Runs the existing costing operation after its domain gate succeeds.</summary>
    /// <param name="Argument">Carries the request and receives the existing response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Adjust Cost Run Process ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit;
        Process.RunAdjustCost(Argument);
    end;

    /// <summary>Returns the Item table used by the existing selection contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Returns the existing costing selection description.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Run Adjust Cost - Item Entries for a filtered set of items, and optionally post the corrections to the general ledger.');
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    begin
        exit('adjust cost,item entry correction,post to g/l,report 795');
    end;

    /// <summary>Describes the existing costing execution.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Runs report 795 with optional item or category filter and explicit postToGL option.');
    end;

    /// <summary>Identifies this operation as an inbound write.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Returns the envelope chapter for the existing costing operation.</summary>
    /// <param name="Envelope">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read by this operation."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the target chapter for the existing costing operation.</summary>
    /// <param name="Target">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[]');
        exit(true);
    end;

    /// <summary>Returns the parameters chapter for the existing costing operation.</summary>
    /// <param name="Parameters">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"itemNoFilter","type":"string","required":false,"description":"Optional itemNoFilter passed to report 795 after truncation to 250 characters. Only one effective item/category filter may be nonempty. Original text is echoed.","default":""},{"name":"itemCategoryFilter","type":"string","required":false,"description":"Optional itemCategoryFilter passed to report 795 after truncation to 250 characters. Only one effective item/category filter may be nonempty. Original text is echoed.","default":""},{"name":"postToGL","type":"boolean","required":false,"description":"Optional request to report 795 via SetPostToGL; false when absent or a non-value token. Actual posting depends on standard report/setup state.","default":false}]');
        exit(true);
    end;

    /// <summary>Returns the response chapter for the existing costing operation.</summary>
    /// <param name="Response">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success after the standard report returns successfully and response construction completes; not proof of G/L posting."},{"name":"itemNoFilter","type":"string","description":"Original request value echoed by the current implementation."},{"name":"itemCategoryFilter","type":"string","description":"Original request value echoed by the current implementation."},{"name":"postToGL","type":"boolean","description":"Original request value echoed by the current implementation."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors chapter for the existing costing operation.</summary>
    /// <param name="Errors">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"InvalidParameter","when":"The company Costing domain is disabled.","fix":"Turn on the Costing domain in Inventory Setup."},{"code":"PermissionDenied","when":"The existing inventory posting gate denies the caller.","fix":"Have the administrator review the existing inventory posting permission policy."},{"code":"InvalidOperation","when":"The standard report Run returns false; response carries GetLastErrorText. A raised report error is a separate failure path.","fix":"Review the standard report error and current ledger state before deciding whether retry is safe."},{"code":"BusinessCentralError","when":"Through the normal Foundation scheduled-task error-handler path, an uncollected task/report/conversion error is answered by Message Error as BusinessCentralError. Synchronous dispatcher execution does not itself invoke that scheduled failure codeunit. Report 795 raises an error when both effective filters are nonempty. Direct invocation may raise instead; scalar/null conversion outcomes require supported-platform verification.","fix":"Review the actual report or conversion error and current ledger state; no rollback or safe-retry guarantee is declared."}]');
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Report 795 adjusts item/value-entry costs. postToGL is passed to SetPostToGL; actual G/L changes depend on report/setup state.","idempotent":false,"preconditions":["The company Costing domain and existing posting gate permit execution.","Standard report setup and caller permissions permit execution.","Only one of itemNoFilter and itemCategoryFilter may remain nonempty after truncation to 250 characters; report 795 rejects both nonempty."]}');
        exit(true);
    end;

    /// <summary>Returns the metering chapter for the existing costing operation.</summary>
    /// <param name="Metering">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    /// <summary>Returns the related chapter for the existing costing operation.</summary>
    /// <param name="Related">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.CostToGL.Post","useInsteadWhen":"Run report 1002 separately after adjustment; report completion alone does not prove posting."}]');
        exit(true);
    end;

    /// <summary>Returns the workflow chapter for the existing costing operation.</summary>
    /// <param name="Workflow">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    /// <summary>Returns the examples chapter for the existing costing operation.</summary>
    /// <param name="Examples">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Run report 795 without requesting G/L posting.","request":{"type":"Inventory.AdjustCost.Run","version":"1.0","data":{"itemNoFilter":"1000","itemCategoryFilter":"","postToGL":false}},"response":{"status":"Success","itemNoFilter":"1000","itemCategoryFilter":"","postToGL":false}}]');
        exit(true);
    end;

    /// <summary>Returns the overview chapter for the existing costing operation.</summary>
    /// <param name="Overview">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Runs report 795 with optional item or category filter and explicit postToGL option.';
        exit(true);
    end;

    /// <summary>Returns the notes chapter for the existing costing operation.</summary>
    /// <param name="Notes">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'Absent or object/array-valued fields fall back to empty text or false in local readers. Scalar and null conversion outcomes require exact BC28/BC29 runtime tests. No preview, rollback, idempotence or safe-retry guarantee is declared. Filter selection is truncated to 250 characters, but response echoes full original values. Report 795 rejects both effective filters nonempty.';
        exit(true);
    end;
}
