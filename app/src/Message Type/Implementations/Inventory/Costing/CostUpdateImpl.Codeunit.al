namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Intentional non-Standard card-cost writes behind company, native permission, license and transaction boundaries.</summary>
codeunit 10076863 "Cost Update Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Updates current Item costs through native validation; refuses Standard-costed items.', Comment = 'is-IS=Uppfærir núverandi vörukostnað með innbyggðri sannprófun; hafnar vörum með staðlað kostnaðarverð.';
        SelectionLbl: Label 'Selects exactly one item using the Foundation subject, identifier or tableView rules.', Comment = 'is-IS=Velur nákvæmlega eina vöru samkvæmt reglum grunnforritsins um subject, auðkenni eða tableView.';
        KeywordsLbl: Label 'item cost, unit cost, last direct cost, standard cost, intentional cost update', Comment = 'is-IS=vörukostnaður,kostnaðarverð,síðasta beina kostnaðarverð,staðlað kostnaðarverð,kostnaðaruppfærsla';
        OverviewLbl: Label 'Writes current Item card costs through Validate. It does not revalue inventory or post ledger entries.', Comment = 'is-IS=Skráir núverandi kostnað á vöruspjald með Validate. Endurmetur ekki birgðir og bókar engar fjárhagsfærslur.';
        NotesLbl: Label 'Standard-costed items always refuse with a revaluation instruction. Native field restrictions, blocked-item opt-in and expectedCostingMethod are checked before any validation. Missing or multi-item selections refuse. Failures use the Codeunit.Run boundary; direct internal invocation can raise.', Comment = 'is-IS=Vörum með staðlað kostnaðarverð er alltaf hafnað með leiðbeiningu um endurmat. Innbyggðar reitatakmarkanir, samþykki fyrir lokaðri vöru og expectedCostingMethod eru athuguð áður en sannprófun hefst. Vöntun á vöruvali eða val margra vara er hafnað. Villur fara um Codeunit.Run; bein innri köll geta kastað villu.';

    /// <summary>Requires native Item write permission and the company Costing flag.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, true, false));
    end;

    /// <summary>Returns the native Item selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Intentional card writes are inbound.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs native validation through Codeunit.Run; no licensing or company-gate bypass.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Process: Codeunit "Inventory Write Process ori";
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('CostUpdate');
        if not Process.Run(Argument) then
            Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Describes guarded card-cost changes.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Describes guarded card-cost changes.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes guarded card-cost changes.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the envelope contract for guarded cost writes.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["itemNo","systemId"],"description":"Exactly one item; subject precedes data identifiers."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the target contract for guarded cost writes.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[{"table":"Item","selection":"Exactly one native Item."}]');
        exit(true);
    end;

    /// <summary>Returns the parameters contract for guarded cost writes.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Exact item number.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'Must resolve exactly one Item.'));
        Parameters.Add(ContractMgt.Parameter('unitCost', 'number', false, 'Validate Item Unit Cost.'));
        Parameters.Add(ContractMgt.Parameter('lastDirectCost', 'number', false, 'Validate Item Last Direct Cost.'));
        Parameters.Add(ContractMgt.Parameter('standardCost', 'number', false, 'Validate Item Standard Cost on non-Standard items only.'));
        Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'Explicitly permit a blocked Item; default false.'));
        Parameters.Add(ContractMgt.Parameter('expectedCostingMethod', 'string', false, 'Optional case-insensitive native costing-method name guard.'));
        exit(true);
    end;

    /// <summary>Returns the response contract for guarded cost writes.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success."},{"name":"itemNo","type":"string","description":"Updated Item No."},{"name":"itemId","type":"string","description":"Updated Item SystemId."},{"name":"costingMethod","type":"string","description":"Native invariant method name."},{"name":"before","type":"object","description":"Card unitCost, lastDirectCost and standardCost before native validation."},{"name":"after","type":"object","description":"The same card fields after native validation."},{"name":"warnings","type":"array","description":"Empty on success; no Standard-cost waiver."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors contract for guarded cost writes.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Item selection finds nothing.', 'Supply an existing item.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Company/native write gate refuses caller.', 'Review permissions and company setup.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native selection, validation or report error.','Standard-costed or blocked Item, method mismatch, field restriction, ambiguous selection or native validation failure. The direct native call may raise; the process wrapper returns text without a typed code.','Use native revaluation for Standard-costed items; otherwise correct the request.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Company Costing is disabled or request parameters are malformed.', 'Enable the domain or correct the request.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A date, decimal or Boolean request value has the wrong format.', 'Use ISO dates, invariant decimals and JSON Booleans.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A supplied required cost value is null or empty.', 'Supply a numeric cost value.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract for guarded cost writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"write","writes":true,"posts":false,"idempotent":false,"changes":"Validates supplied Item cost fields and modifies the Item. No ledger revaluation or posting.","preconditions":["Exactly one Item selected.","Non-Standard costing method.","Native Item write access and each supplied field permission.","Costing domain and normal licensed dispatch."]}');
        exit(true);
    end;

    /// <summary>Returns the related contract for guarded cost writes.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.Cost.Get","useInsteadWhen":"Read current costs without writing."}]');
        exit(true);
    end;

    /// <summary>Returns the examples contract for guarded cost writes.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Update FIFO card costs with a method guard","request":{"type":"Inventory.Cost.Update","subject":"OWNED-ITEM","data":{"unitCost":12,"lastDirectCost":10,"expectedCostingMethod":"FIFO"}}}]');
        exit(true);
    end;

    /// <summary>No metering override is supplied.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    /// <summary>No workflow override is supplied.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    /// <summary>Explains intentional cost-write behavior.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains intentional cost-write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;
}
