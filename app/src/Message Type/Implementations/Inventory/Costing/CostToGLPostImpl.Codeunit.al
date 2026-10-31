namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.CostToGL.Post. Runs report 1002 when Adjust Cost was run with postToGL false.
/// </summary>
codeunit 10076861 "Cost To GL Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        Process: Codeunit "Inventory Write Process ori";
        RequestJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        Process.SetOperation('CostToGLPost');
        Process.SetCostPostingSelection(ReadText(RequestJson, 'itemNoFilter'), ReadText(RequestJson, 'documentNoFilter'),
            CopyStr(ReadText(RequestJson, 'journalTemplateName'), 1, 10), CopyStr(ReadText(RequestJson, 'journalBatchName'), 1, 10));
        // Posting is an independent transaction, including when the caller requests Omit Commit.
        Commit();
        if not Process.Run(Argument) then
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;

    /// <summary>Returns the Item table used by the existing selection contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Returns the existing costing selection description.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Post inventory value entries that are not yet posted to the general ledger.', Comment = 'is-IS=Bókar virðisfærslur birgða sem ekki hafa verið bókaðar á fjárhag.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post inventory cost,general ledger,report 1002', Comment = 'is-IS=bóka birgðakostnað,fjárhagur,skýrsla 1002';
    begin
        exit(KeywordsLbl);
    end;

    local procedure ReadText(RequestJson: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    /// <summary>Describes the existing costing execution.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Posts selected pending inventory costs to G/L per entry and returns actual posted and remaining counts.', Comment = 'is-IS=Bókar valinn óbókaðan birgðakostnað á fjárhag fyrir hverja færslu og skilar raunfjölda bókaðra og eftirstandandi færslna.';
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
        Parameter := ContractMgt.Parameter('itemNoFilter', 'string', false, 'Item number filter in Business Central filter syntax; only matching pending value entries are selected.');
        Parameter.Add('default', '');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter := ContractMgt.Parameter('documentNoFilter', 'string', false, 'Document number filter in Business Central filter syntax; combined with itemNoFilter before posting.');
        Parameter.Add('default', '');
        Parameters.Add(Parameter);
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'G/L journal template name required when General Ledger Setup requires a journal template.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'G/L journal batch with a number series, required with journalTemplateName.'));
        exit(true);
    end;

    /// <summary>Returns the response chapter for the existing costing operation.</summary>
    /// <param name="Response">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success after native posting completes; inspect the counts for entries not posted."},{"name":"itemNoFilter","type":"string","description":"Applied item filter."},{"name":"documentNoFilter","type":"string","description":"Applied document filter."},{"name":"postedValueEntryCount","type":"integer","description":"Selected pending value entries removed by successful native posting."},{"name":"remainingValueEntryCount","type":"integer","description":"Selected pending value entries still not posted; review the native posting setup and entries."},{"name":"posted","type":"boolean","description":"True only when at least one selected pending value entry was posted."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors chapter for the existing costing operation.</summary>
    /// <param name="Errors">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"InvalidParameter","when":"The Costing domain is disabled.","fix":"Turn on Costing in Inventory Setup."},{"code":"PermissionDenied","when":"The inventory posting token is missing.","fix":"Assign BIFROST InvPost ori in addition to native posting permissions."},{"code":"BusinessCentralError","when":"Native posting or selection fails.","fix":"Correct the native setup or selected entries. If journal templates are mandatory, supply journalTemplateName and journalBatchName with a number series."}]');
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Posts matching pending value entries to G/L with native per-entry posting. Both filters are applied. Commits the caller transaction before an isolated posting run; Omit Commit does not suppress this posting boundary. postedValueEntryCount and remainingValueEntryCount report the actual selected queue outcome.","idempotent":false,"permissionSet":"BIFROST Full ori and BIFROST InvPost ori","preconditions":["The company Costing domain and existing posting gate permit execution.","Standard report setup and caller permissions permit execution."]}');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Use it first to adjust item costs; with postToGL true it also posts the adjustments to the general ledger in the same run.'));
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
            'Post pending inventory cost for one item',
            '{"type":"Inventory.CostToGL.Post","data":{"itemNoFilter":"1000","documentNoFilter":""}}',
            '{"status":"Success","itemNoFilter":"1000","documentNoFilter":"","posted":true,"postedValueEntryCount":1,"remainingValueEntryCount":0}'));
        exit(true);
    end;

    /// <summary>Returns the overview chapter for the existing costing operation.</summary>
    /// <param name="Overview">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Posts selected pending inventory value entries to G/L using native per-entry posting. The response reports actual posted and remaining counts.', Comment = 'is-IS=Bókar valdar óbókaðar virðisfærslur birgða á fjárhag með innbyggðri bókun fyrir hverja færslu. Svarið sýnir raunfjölda bókaðra og eftirstandandi færslna.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'itemNoFilter and documentNoFilter are combined before posting; empty filters select all pending entries. Native per-entry posting uses each entry document number. If G/L journal templates are mandatory, send journalTemplateName and journalBatchName with a valid number series. This Post call commits before its isolated native posting run even under Omit Commit. Success means the run completed: posted is true only if postedValueEntryCount is positive; remainingValueEntryCount identifies entries still requiring attention. No eligible entries returns posted=false and zero counts.', Comment = 'is-IS=itemNoFilter og documentNoFilter eru sameinaðar áður en bókað er; tómar síur velja allar óbókaðar færslur. Innbyggð bókun fyrir hverja færslu notar fylgiskjalsnúmer færslunnar. Ef fjárhagsbókarsniðmát er skylda skaltu senda journalTemplateName og journalBatchName með gildri númeraröð. Þetta Post kall staðfestir færsluna fyrir einangraða innbyggða bókun, einnig með Omit Commit. Success merkir að keyrslu lauk: posted er aðeins true ef postedValueEntryCount er jákvætt; remainingValueEntryCount sýnir færslur sem enn þarfnast athugunar. Engar gjaldgengar færslur skila posted=false og núllfjölda.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

}
