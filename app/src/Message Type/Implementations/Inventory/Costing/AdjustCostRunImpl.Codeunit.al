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
    var
        SelectionDescriptionLbl: Label 'Run Adjust Cost - Item Entries for a filtered set of items, and optionally post the corrections to the general ledger.', Comment = 'is-IS=Keyrir Leiðrétta kostnað - vörufærslur fyrir síað safn vara og getur bókað leiðréttingarnar á fjárhag.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'adjust cost,item entry correction,post to g/l,cost adjustment', Comment = 'is-IS=leiðrétta kostnað,leiðrétting vörufærslu,bóka á fjárhag,kostnaðarleiðrétting';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes the existing costing execution.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Adjusts item costs with an optional item or category filter and an explicit postToGL option.', Comment = 'is-IS=Leiðréttir vörukostnað með valkvæðri vöru- eða flokkssíu og skýru postToGL-vali. (leiðrétta kostnað, leiðrétting vörufærslu, bóka á fjárhag, kostnaðarleiðrétting).';
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
        Parts: Codeunit "Inventory Contract Parts ori";
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
        Parameter := ContractMgt.Parameter('postToGL', 'boolean', false, 'true makes the batch job post the cost adjustments to the general ledger in the same run. false leaves the general ledger alone. A missing key defaults to false. A supplied value must be the JSON boolean true or false; other values are refused before the report runs.');
        Parameter.Add('default', false);
        Parameters.Add(Parameter);
        Parts.AddExpectedCountParameter(Parts.CountUnitAdjustCost(), Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter for the existing costing operation.</summary>
    /// <param name="Response">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success after the standard report returns successfully and response construction completes; not proof of G/L posting."},{"name":"itemNoFilter","type":"string","description":"Original request value echoed by the current implementation."},{"name":"itemCategoryFilter","type":"string","description":"Original request value echoed by the current implementation."},{"name":"postToGL","type":"boolean","description":"Original request value echoed by the current implementation."},{"name":"itemsProcessed","type":"integer","description":"Number of items the item and item category filters select, counted before the report runs. It is the scope of the run, not a count of items whose cost changed."},{"name":"errors","type":"array","description":"Always empty on Success. A report error is answered as an error response with code BusinessCentralError instead."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors chapter for the existing costing operation.</summary>
    /// <param name="Errors">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"InvalidParameterFormat","when":"A filter is not text or postToGL is not a JSON boolean.","fix":"Use the reported parameter, expected format and nextStep. No adjustment is run for invalid request values."},{"code":"MultipleErrors","when":"Several request values have invalid formats.","fix":"Correct every errors[] entry before retrying."},{"code":"InvalidParameter","when":"Both effective filters are nonempty, or a filter is invalid. Filter refusals happen before the report runs.","fix":"Send at most one valid item or category filter. No adjustment runs for an invalid selection."},{"code":"PermissionDenied","when":"The caller does not hold the Inv. Posting Gate permission set.","fix":"Ask an administrator to assign Inv. Posting Gate."},{"code":"BusinessCentralError","error":"The error text of the Adjust Cost - Item Entries batch job.","when":"The batch job stops with an error after request formats and filter selection have passed validation. The error text is returned with code BusinessCentralError.","fix":"Correct the filters or the cost data named in the error text and check the item entries before you retry; no rollback or safe retry is promised."},{"code":"BusinessCentralError","when":"Through the normal Foundation scheduled-task error-handler path, an uncollected task/report/conversion error is answered by Message Error as BusinessCentralError. Synchronous dispatcher execution does not itself invoke that scheduled failure handler. Both-filter and invalid-filter refusals are InvalidParameter before the report; scalar format refusals are InvalidParameterFormat.","fix":"Review the actual report or conversion error and current ledger state; no rollback or safe-retry guarantee is declared."}]');
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        Changes: JsonToken;
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Adjusts the cost of the matching item entries by running the Adjust Cost - Item Entries batch job. When postToGL is true the batch job also posts the adjustments to the general ledger in the same run. Business Central commits the result when the call finishes; under Omit Commit the commit is left to the caller. There is no preview, and no rollback is promised if the job fails part way.","idempotent":false,"permissionSet":"BIFROST Full ori","preconditions":["The company Costing domain and existing posting gate permit execution.","Standard report setup and caller permissions permit execution.","Only one of itemNoFilter and itemCategoryFilter may remain nonempty after truncation to 250 characters; the cost adjustment rejects both nonempty."]}');
        Effect.Get('changes', Changes);
        Effect.Replace('changes', Changes.AsValue().AsText() + ' ' + ConfirmationCountNote());
        Parts.AddCountUnit(Parts.CountUnitAdjustCost(), Effect);
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
            '{"type":"Inventory.AdjustCost.Run","data":{"expectedCount":1,"itemNoFilter":"1000","postToGL":false}}',
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
            'The caller needs the Inv. Posting Gate permission set, and the Costing domain must be on in Inventory Setup. postingDate, inventoryPostingGroup and itemByItem are not parameters and are refused as UnknownParameter before anything runs. itemsProcessed is the number of items the filters select, counted before the run. Read costIsAdjusted with Inventory.Cost.Get to see whether items still need an adjustment run.';
        Notes += ' ' + ConfirmationCountNote();
        exit(true);
    end;

    local procedure ConfirmationCountNote(): Text
    var
        CountNoteLbl: Label 'For named requests, omitting expectedCount returns a confirmation preview only when the company setting Require Irreversible Confirm is enabled. When confirmation is not required, omitting expectedCount runs the operation immediately after normal validation and permission checks. For a named request subject, expectedCount counts the one cost adjustment run (1), not the items or value entries selected by the filters. It does not bound the number of entries changed. An unnamed request follows Foundation no-subject confirmation behavior; do not assume that omitting expectedCount previews an unnamed run.', Comment = 'is-IS=Fyrir nafngreindar beiðnir skilar það að sleppa expectedCount aðeins staðfestingarforskoðun þegar fyrirtækisstillingin Require Irreversible Confirm er virk. Þegar staðfestingar er ekki krafist keyrir aðgerðin strax eftir venjulega sannprófun og heimildaathuganir ef expectedCount er sleppt. Fyrir beiðni með nafngreindu subject telur expectedCount eina kostnaðarleiðréttingarkeyrslu (1), ekki vörurnar eða virðisfærslurnar sem síurnar velja. Það takmarkar ekki fjölda færslna sem breytast. Beiðni án subject fylgir staðfestingarhegðun Foundation fyrir ónafngreindar beiðnir; ekki gera ráð fyrir að það að sleppa expectedCount forskoði ónafngreinda keyrslu.';
    begin
        exit(CountNoteLbl);
    end;
}
