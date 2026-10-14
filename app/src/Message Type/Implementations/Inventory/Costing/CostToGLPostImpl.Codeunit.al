namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.CostToGL.Post. Runs report 1002 when Adjust Cost was run with postToGL false.
/// </summary>
codeunit 70013462 "Cost To GL Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.', Comment = 'is-IS=Bókar valinn óbókaðan birgðakostnað í fjárhag með innbyggðri keyrslu 1002 og virku Post.';
        SelectionLbl: Label 'Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.', Comment = 'is-IS=Bókar valinn óbókaðan birgðakostnað í fjárhag með innbyggðri keyrslu 1002 og virku Post.';
        KeywordsLbl: Label 'post inventory cost,general ledger,report 1002', Comment = 'is-IS=bóka birgðakostnað,fjárhagur,keyrsla 1002';
        OverviewLbl: Label 'Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.', Comment = 'is-IS=Bókar valinn óbókaðan birgðakostnað í fjárhag með innbyggðri keyrslu 1002 og virku Post.';
        NotesLbl: Label 'itemNo and postingDate filter Post Value Entry to G/L. documentNo is an output option; nonempty documentNoFilter is refused. Post is explicitly true. Native skips and commits remain in force; posted means posting mode completed, not that every entry posted. entriesRemaining records the selected entries still pending. Native report errors use the structured failure boundary.', Comment = 'is-IS=itemNo og postingDate sía óbókaðar virðisfærslur til fjárhags. documentNo er úttaksvalkostur; documentNoFilter sem er ekki tómt er hafnað. Post er sérstaklega true. Innbyggð slepping færslna og staðfesting breytinga gilda áfram; posted merkir að bókunarhamur lauk, ekki að allar færslur hafi verið bókaðar. entriesRemaining sýnir valdar færslur sem enn bíða bókunar. Innbyggðar keyrsluvillur fara um skilgreinda villumeðhöndlun.';

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
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Codeunit.Run(Codeunit::"Inventory Cost Post Proc. ori", Argument) then
            Argument.RespondWithError(GetLastErrorText());
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
        ParameterJson := ContractMgt.Parameter('itemNo', 'string', false, 'Native Item No. filter; blank selects all pending entries. Legacy itemNoFilter is accepted only when equal if both are present.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('postingDate', 'string', false, 'Native Posting Date filter on pending value entries. Legacy postingDateFilter is accepted.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('perPostingGroup', 'boolean', false, 'False posts/tests per entry; true summarizes by posting group.');
        ParameterJson.Add('default', false);
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('documentNo', 'string', false, 'Output document number required with perPostingGroup=true; forbidden with per-entry posting. This is not a document filter.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('itemNoFilter', 'string', false, 'Legacy alias of itemNo; conflicting simultaneous values are refused.');
        ParameterJson.Add('default', '');
        Parameters.Add(ParameterJson);
        ParameterJson := ContractMgt.Parameter('postingDateFilter', 'string', false, 'Legacy alias of postingDate; conflicting simultaneous values are refused.');
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
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success when the native report completes."},{"name":"posted","type":"boolean","description":"False for test; true for completed posting mode, even if the native report leaves entries pending."},{"name":"entriesSelected","type":"integer","description":"Selected pending-entry count before execution."},{"name":"entriesRemaining","type":"integer","description":"Selected pending entries remaining after native posting."},{"name":"skippedEntries","type":"array","description":"Value Entry numbers from the native report 1002 skipped-entry dataset."}]}');
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
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.","idempotent":false,"preconditions":["Company Costing and permission gates allow execution.","The native report setup and permissions allow execution.","Item and posting-date filters select pending value entries; documentNo is an output option."]}');
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
        Related.ReadFrom('[{"name":"Inventory.AdjustCost.Run","useInsteadWhen":"Adjust item costs with report 795 first when that is the required operation."}]');
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
        Examples.ReadFrom('[{"title":"Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.","request":{"type":"Inventory.CostToGL.Post","version":"1.0","data":{"itemNo":"XITEM"}}}]');
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
