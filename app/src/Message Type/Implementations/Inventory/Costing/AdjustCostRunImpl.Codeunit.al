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

    var
        DescriptionLbl: Label 'Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.', Comment = 'is-IS=Keyrir innbyggða keyrslu 795 fyrir vöru- eða vöruflokksval, kostnaðarleiðréttingu hverrar vöru og valfrjálsa fjárhagsbókun.';
        SelectionLbl: Label 'Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.', Comment = 'is-IS=Keyrir innbyggða keyrslu 795 fyrir vöru- eða vöruflokksval, kostnaðarleiðréttingu hverrar vöru og valfrjálsa fjárhagsbókun.';
        KeywordsLbl: Label 'adjust cost,item entry correction,post to g/l,report 795', Comment = 'is-IS=leiðrétta kostnað,vörufærslur,bóka í fjárhag,keyrsla 795';
        OverviewLbl: Label 'Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.', Comment = 'is-IS=Keyrir innbyggða keyrslu 795 fyrir vöru- eða vöruflokksval, kostnaðarleiðréttingu hverrar vöru og valfrjálsa fjárhagsbókun.';
        NotesLbl: Label 'Report 795 has no postingDate or inventoryPostingGroup request filter in BC28.5; nonempty values are refused before execution. Item/category filters are never truncated. Native commits remain effective on partial failure; no preview, rollback or retry-safety is promised. itemsSelected is the pre-run selection count; itemsProcessed counts distinct completed native item adjustments during this run. reportCompleted is false on the native early exit before adjustment. errors is empty on success; failures use the structured process error boundary, and may follow native commits.', Comment = 'is-IS=Keyrsla 795 hefur engar postingDate eða inventoryPostingGroup síur í BC28.5; gildum sem eru ekki tóm er hafnað fyrir keyrslu. Vöru- og vöruflokkssíur eru aldrei styttar. Innbyggð staðfesting breytinga helst þótt hluti keyrslu mistakist; engin forskoðun, bakfærsla eða örugg endurtekning er tryggð. itemsSelected er fjöldi valinna vara fyrir keyrslu; itemsProcessed telur aðgreindar vörur sem luku innbyggðri kostnaðarleiðréttingu í keyrslunni. reportCompleted er false ef innbyggða keyrslan stöðvast áður en leiðrétting hefst. errors er tómt við árangur; villur fara um skilgreinda villumeðhöndlun og geta komið eftir staðfestar breytingar.';

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
        exit(SelectionLbl);
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes the existing costing execution.</summary>
    procedure GetDescription(): Text[250]
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ParameterJson: JsonObject;
    begin
        Clear(Parameters);
        ParameterJson := ContractMgt.Parameter('itemNo', 'string', false, 'Native item filter, at most 250 characters. Legacy itemNoFilter is accepted.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('itemCategoryCode', 'string', false, 'Native category filter, mutually exclusive with itemNo; at most 250 characters. Legacy itemCategoryFilter is accepted.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('itemByItem', 'boolean', false, 'Native item-by-item adjustment option; may commit each item.');
        ParameterJson.Add('default', false);
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('postToGL', 'boolean', false, 'Use the native report 795 G/L option; report 1002 is not additionally run.');
        ParameterJson.Add('default', false);
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('itemNoFilter', 'string', false, 'Legacy alias of itemNo; conflicting simultaneous values are refused.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('itemCategoryFilter', 'string', false, 'Legacy alias of itemCategoryCode; conflicting simultaneous values are refused.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    /// <summary>Returns the response chapter for the existing costing operation.</summary>
    /// <param name="Response">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success when the native report completes."},{"name":"itemsProcessed","type":"integer","description":"Distinct items observed completing the native item adjustment in this invocation; not the selected-item count."},{"name":"reportCompleted","type":"boolean","description":"False when the native report exits before adjustment because the ledger is empty."},{"name":"errors","type":"array","description":"Empty on successful report completion; failures return the structured process error response and may follow native commits."},{"name":"itemsSelected","type":"integer","description":"Pre-run item selection count; not a processed count."},{"name":"postToGL","type":"boolean","description":"Requested native G/L option."},{"name":"itemByItem","type":"boolean","description":"Requested native item-by-item option."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors chapter for the existing costing operation.</summary>
    /// <param name="Errors">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Company Costing domain is disabled.', 'Enable Costing in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The existing domain/posting gate refuses the caller.', 'Review permissions.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native selection, validation or report error.','Request validation or the native report fails; no native commit rollback is promised. The direct native call may raise; the process wrapper returns text without a typed code.','Review the returned error and actual ledger state.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Foundation scheduled-task failure handler maps uncaught failures. Direct invocation may raise instead.', 'Review the native error and current ledger state before retrying.'));
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.","idempotent":false,"preconditions":["Company Costing and permission gates allow execution.","The native report setup and permissions allow execution; postToGL=true requires Automatic Cost Posting.","Only one of itemNo and itemCategoryCode may be nonempty; filters longer than 250 characters are refused."]}');
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
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Returns the notes chapter for the existing costing operation.</summary>
    /// <param name="Notes">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;
}
