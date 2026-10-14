namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

codeunit 70013468 "Cost Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Reads item cost fields that are not exposed by the foundation app.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('read item cost, unit cost, inventory value');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Returns current costing fields and native filtered inventory for one or more items.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["itemNo","systemId"],"description":"Subject wins over data identifiers and tableView."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[{"table":"Item","selection":"subject, itemNo, itemId/id/systemId/recordSystemId, tableView, otherwise unblocked items"}]');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Exact Item No.; subject takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Item SystemId; used after itemNo.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias for Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias for Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias for Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'Foundation Item table view; supports multiple items.'));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, 'Native Location Filter applied to inventory; does not change card costs.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant selection for inventory; does not change card costs.'));
        Parameters.Add(ContractMgt.Parameter('asOfDate', 'string', false, 'ISO posting-date upper bound for inventory quantity only. Costs and adjustment/G/L flags remain current.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success."},{"name":"items","type":"array","description":"One current cost snapshot per selected item.","children":[{"name":"itemNo","type":"string","description":"Item number."},{"name":"itemId","type":"string","description":"Item SystemId."},{"name":"costingMethod","type":"string","description":"Invariant costing-method member name."},{"name":"unitCost","type":"number","description":"Current Item Unit Cost."},{"name":"standardCost","type":"number","description":"Current Item Standard Cost."},{"name":"lastDirectCost","type":"number","description":"Current Item Last Direct Cost."},{"name":"indirectCostPct","type":"number","description":"Current Item Indirect Cost %."},{"name":"costIsAdjusted","type":"boolean","description":"Current Item adjustment flag."},{"name":"costIsPostedToGL","type":"boolean","description":"Native current pending-cost FlowField."},{"name":"inventory","type":"number","description":"Native stock quantity with location/variant and optional asOfDate."},{"name":"locationFilter","type":"string","description":"Effective native location filter."},{"name":"variantFilter","type":"string","description":"Effective native variant filter."},{"name":"asOfDate","type":"string","description":"Optional ISO upper posting date for inventory only."}]}]}');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"RecordNotFound","when":"No Item matches Foundation selection.","fix":"Use an existing identifier or tableView."},{"code":"InvalidParameter","when":"Invalid optional text parameter.","fix":"Send text filters."},{"code":"InvalidParameterFormat","when":"Invalid date or identifier.","fix":"Use ISO date and valid identifiers."},{"code":"PermissionDenied","when":"Native Item read permission is absent.","fix":"Assign the appropriate read role."}]');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"readOnly","writes":false,"posts":false,"idempotent":true,"changes":"None. Reads current Item costs and filtered native inventory quantities."}');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Adjust item costs with report 795.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Calculate', 'Write a new cost on the revaluation journal.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reads item cost and inventory for one item.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Foundation item selection order applies. Card costs and adjustment/G/L flags are current values. locationFilter, variantCode and asOfDate constrain inventory quantity only; no historical card cost or SKU-cost claim. No item, ledger, or posting data is written.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        CostRead: Codeunit "Inventory Cost Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        CostRead.ReadCosts(Argument);
    end;
}
