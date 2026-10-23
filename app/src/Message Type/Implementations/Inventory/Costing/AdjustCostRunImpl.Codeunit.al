namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.AdjustCost.Run. Runs report 795 with the same filters as the job queue request page.
/// </summary>
codeunit 10076858 "Adjust Cost Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        SelectionDescriptionLbl: Label 'Run Adjust Cost - Item Entries for a filtered set of items, and optionally post the corrections to the general ledger.', Comment = 'is-IS=Keyrir Leiðrétta kostnað - vörufærslur fyrir síað safn vara og getur bókað leiðréttingarnar á fjárhag.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'adjust cost,item entry correction,post to g/l,report 795', Comment = 'is-IS=leiðrétta kostnað,leiðrétting vörufærslu,bóka á fjárhag,skýrsla 795';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes the existing costing execution.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Runs report 795 with optional item or category filter and explicit postToGL option.', Comment = 'is-IS=Keyrir skýrslu 795 með valkvæmri vöru- eða flokkssíu og skýru postToGL-vali.';
    begin
        exit(DescriptionLbl);
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
    begin
        Clear(Parameters);
        Parameter := ContractMgt.Parameter('itemNoFilter', 'string', false, 'Optional item number filter in Business Central filter syntax, for example 1000 or 1000..2000. It is cut to 250 characters before it is used, and the answer echoes the text you sent. Leave it empty to adjust all items, and do not send it together with itemCategoryFilter.');
        Parameter.Add('default', '');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter := ContractMgt.Parameter('itemCategoryFilter', 'string', false, 'Optional item category filter in Business Central filter syntax. It is cut to 250 characters before it is used, and the answer echoes the text you sent. Do not send it together with itemNoFilter.');
        Parameter.Add('default', '');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter := ContractMgt.Parameter('postToGL', 'boolean', false, 'true makes the batch job post the cost adjustments to the general ledger in the same run. false leaves the general ledger alone. A missing key, or a value that is not a JSON value, counts as false.');
        Parameter.Add('default', false);
        Parameters.Add(Parameter);
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
        Errors.ReadFrom('[{"code":"InvalidParameter","when":"The Costing domain is turned off in Inventory Setup.","fix":"Turn on the Costing domain in Inventory Setup."},{"code":"PermissionDenied","when":"The caller does not hold the BIFROST InvPost ori permission set.","fix":"Ask an administrator to assign BIFROST InvPost ori."},{"error":"The error text of the Adjust Cost - Item Entries batch job.","when":"The batch job stops with an error, for example when itemNoFilter and itemCategoryFilter are both filled in or a filter is not valid. The error text is returned as it is, with code BusinessCentralError.","fix":"Correct the filters or the cost data named in the error text and check the item entries before you retry; no rollback or safe retry is promised."},{"code":"BusinessCentralError","when":"Through the normal Foundation scheduled-task error-handler path, an uncollected task/report/conversion error is answered by Message Error as BusinessCentralError. Synchronous dispatcher execution does not itself invoke that scheduled failure codeunit. Report 795 raises an error when both effective filters are nonempty. Direct invocation may raise instead; scalar/null conversion outcomes require supported-platform verification.","fix":"Review the actual report or conversion error and current ledger state; no rollback or safe-retry guarantee is declared."}]');
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Adjusts the cost of the matching item entries by running the Adjust Cost - Item Entries batch job. When postToGL is true the batch job also posts the adjustments to the general ledger in the same run. Business Central commits the result when the call finishes; under Omit Commit the commit is left to the caller. There is no preview, and no rollback is promised if the job fails part way.","idempotent":false,"permissionSet":"BIFROST Full ori and BIFROST InvPost ori","preconditions":["The company Costing domain and existing posting gate permit execution.","Standard report setup and caller permissions permit execution.","Only one of itemNoFilter and itemCategoryFilter may remain nonempty after truncation to 250 characters; report 795 rejects both nonempty."]}');
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.CostToGL.Post', 'Use it to start the inventory cost posting as a separate step when postToGL was false. It takes no item filter, so read its notes first.'));
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Adjust the costs of item 1000 without posting to the general ledger',
            '{"type":"Inventory.AdjustCost.Run","data":{"itemNoFilter":"1000","postToGL":false}}',
            '{"status":"Success","itemNoFilter":"1000","itemCategoryFilter":"","postToGL":false}'));
        exit(true);
    end;

    /// <summary>Returns the overview chapter for the existing costing operation.</summary>
    /// <param name="Overview">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Adjusts item costs by running the Adjust Cost - Item Entries batch job for all items, or for one item or item category filter, and can post the adjustments to the general ledger in the same run.';
        exit(true);
    end;

    /// <summary>Returns the notes chapter for the existing costing operation.</summary>
    /// <param name="Notes">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'With both filters empty the batch job runs for all items; send itemNoFilter or itemCategoryFilter to limit it, never both. Each filter is cut to 250 characters before it is used and the answer echoes the text you sent. ' +
            'postToGL defaults to false. With true the batch job posts the adjustments to the general ledger in the same run, so Inventory.CostToGL.Post is not needed afterwards. ' +
            'The batch job ends quietly when there are no item, application or value entries yet, and the answer is still Success: Success shows that the job finished, not that anything was adjusted or posted. ' +
            'Business Central commits the result when the call finishes; under Omit Commit the commit is left to the caller. There is no preview, the call is not idempotent, and no rollback or safe retry is promised if the job fails part way. ' +
            'The caller needs the BIFROST InvPost ori permission set, and the Costing domain must be on in Inventory Setup. Read costIsAdjusted with Inventory.Cost.Get to see whether items still need an adjustment run.';
        exit(true);
    end;
}
