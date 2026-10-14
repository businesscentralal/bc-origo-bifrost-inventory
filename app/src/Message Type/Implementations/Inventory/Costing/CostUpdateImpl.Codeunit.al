namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Intentional non-Standard card-cost writes behind company, native permission, license and transaction boundaries.</summary>
codeunit 70013435 "Cost Update Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

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
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Codeunit.Run(Codeunit::"Inventory Cost Write Proc. ori", Argument) then
            Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Describes guarded card-cost changes.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Updates current Item costs through native validation; refuses Standard-costed items.');
    end;

    /// <summary>Describes guarded card-cost changes.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Selects exactly one item using the Foundation subject, identifier or tableView rules.');
    end;

    /// <summary>Describes guarded card-cost changes.</summary>
    procedure GetKeywords(): Text
    begin
        exit('item cost, unit cost, last direct cost, standard cost, intentional cost update');
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
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"itemNo","type":"string","required":false,"description":"Exact item number."},{"name":"itemId","type":"string","required":false,"description":"Item SystemId."},{"name":"id","type":"string","required":false,"description":"SystemId alias."},{"name":"systemId","type":"string","required":false,"description":"SystemId alias."},{"name":"recordSystemId","type":"string","required":false,"description":"SystemId alias."},{"name":"tableView","type":"string","required":false,"description":"Must resolve exactly one Item."},{"name":"unitCost","type":"number","required":false,"description":"Validate Item Unit Cost."},{"name":"lastDirectCost","type":"number","required":false,"description":"Validate Item Last Direct Cost."},{"name":"standardCost","type":"number","required":false,"description":"Validate Item Standard Cost on non-Standard items only."},{"name":"allowBlocked","type":"boolean","required":false,"description":"Explicitly permit a blocked Item; default false."},{"name":"expectedCostingMethod","type":"string","required":false,"description":"Optional case-insensitive native costing-method name guard."}]');
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
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"RecordNotFound","when":"Item selection finds nothing.","fix":"Supply an existing item."},{"code":"PermissionDenied","when":"Company/native write gate refuses caller.","fix":"Review permissions and company setup."},{"code":"PreconditionFailed","when":"Standard-costed or blocked Item, method mismatch, field restriction, ambiguous selection or native validation failure.","fix":"Use native revaluation for Standard-costed items; otherwise correct the request."},{"code":"InvalidParameter","when":"Company Costing is disabled or request parameters are malformed.","fix":"Enable the domain or correct the request."}]');
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
        Related.ReadFrom('[{"name":"Inventory.Cost.Get","useInsteadWhen":"Read current costs without writing."},{"name":"Inventory.Revaluation.Post","useInsteadWhen":"Change Standard inventory value through native revaluation."}]');
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
        Overview := 'Writes current Item card costs through Validate. It does not revalue inventory or post ledger entries.';
        exit(true);
    end;

    /// <summary>Explains intentional cost-write behavior.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Standard-costed items always refuse with a revaluation instruction. Native field restrictions, blocked-item opt-in and expectedCostingMethod are checked before any validation. Missing or multi-item selections refuse. Failures use the Codeunit.Run boundary; direct internal invocation can raise.';
        exit(true);
    end;
}
