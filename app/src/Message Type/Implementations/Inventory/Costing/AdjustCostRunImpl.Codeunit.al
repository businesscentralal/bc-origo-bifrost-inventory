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
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
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
        exit('Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.');
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    begin
        exit('adjust cost,item entry correction,post to g/l,report 795');
    end;

    /// <summary>Describes the existing costing execution.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.');
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
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"No subject selection."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
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
        Parameters.ReadFrom('[{"name":"itemNo","type":"string","required":false,"description":"Native item filter, at most 250 characters. Legacy itemNoFilter is accepted.","default":""},{"name":"itemCategoryCode","type":"string","required":false,"description":"Native category filter, mutually exclusive with itemNo; at most 250 characters. Legacy itemCategoryFilter is accepted.","default":""},{"name":"itemByItem","type":"boolean","required":false,"description":"Native item-by-item adjustment option; may commit each item.","default":false},{"name":"postToGL","type":"boolean","required":false,"description":"Use the native report 795 G/L option; report 1002 is not additionally run.","default":false},{"name":"itemNoFilter","type":"string","required":false,"default":"","description":"Legacy alias of itemNo; conflicting simultaneous values are refused."},{"name":"itemCategoryFilter","type":"string","required":false,"default":"","description":"Legacy alias of itemCategoryCode; conflicting simultaneous values are refused."}]');
        exit(true);
    end;

    /// <summary>Returns the response chapter for the existing costing operation.</summary>
    /// <param name="Response">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success when the native report completes."},{"name":"itemsSelected","type":"integer","description":"Pre-run item selection count; not a processed count."},{"name":"postToGL","type":"boolean","description":"Requested native G/L option."},{"name":"itemByItem","type":"boolean","description":"Requested native item-by-item option."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors chapter for the existing costing operation.</summary>
    /// <param name="Errors">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"InvalidParameter","when":"Company Costing domain is disabled.","fix":"Enable Costing in Inventory Setup."},{"code":"PermissionDenied","when":"The existing domain/posting gate refuses the caller.","fix":"Review permissions."},{"code":"PreconditionFailed","when":"Request validation or the native report fails; no native commit rollback is promised.","fix":"Review the returned error and actual ledger state."},{"code":"BusinessCentralError","when":"Foundation scheduled-task failure handler maps uncaught failures. Direct invocation may raise instead.","fix":"Review the native error and current ledger state before retrying."}]');
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.","idempotent":false,"preconditions":["Company Costing and permission gates allow execution.","The native report setup and permissions allow execution.","Only one of itemNo and itemCategoryCode may be nonempty; filters longer than 250 characters are refused."]}');
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
        Examples.ReadFrom('[{"title":"Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.","request":{"type":"Inventory.AdjustCost.Run","version":"1.0","data":{"itemNo":"XITEM"}}}]');
        exit(true);
    end;

    /// <summary>Returns the overview chapter for the existing costing operation.</summary>
    /// <param name="Overview">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.';
        exit(true);
    end;

    /// <summary>Returns the notes chapter for the existing costing operation.</summary>
    /// <param name="Notes">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Report 795 has no postingDate or inventoryPostingGroup request filter in BC28.5; nonempty values are refused before execution. Item/category filters are never truncated. Native commits remain effective on partial failure; no preview, rollback, retry-safety or actual-items-processed count is promised. itemsSelected is the pre-run selection count.';
        exit(true);
    end;
}
