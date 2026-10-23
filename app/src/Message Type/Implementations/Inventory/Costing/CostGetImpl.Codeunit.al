namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

codeunit 10076860 "Cost Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads item cost fields that are not exposed by the foundation app.', Comment = 'is-IS=Les kostnaðarreiti vöru sem grunnforritið birtir ekki.';
        SelectionLbl: Label 'Returns current costing fields and native filtered inventory for one or more items.', Comment = 'is-IS=Skilar núverandi kostnaðarreitum og innbyggðum síuðum birgðum fyrir eina eða fleiri vörur.';
        KeywordsLbl: Label 'read item cost, unit cost, inventory value', Comment = 'is-IS=lesa vörukostnað,kostnaðarverð,birgðavirði';
        OverviewLbl: Label 'Reads current item costs and filtered inventory for one or more items.', Comment = 'is-IS=Les núverandi vörukostnað og síað birgðamagn fyrir eina eða fleiri vörur.';
        NotesLbl: Label 'Select the item with the message subject (an item number or SystemId), data.itemNo, an item SystemId key or data.tableView; a call with none of them is refused. One selected item is also answered at the top level, several items only in items. Unit cost, standard cost, last direct cost, indirect cost percent and both flags are current card values. locationFilter, variantCode and asOfDate change the inventory quantity only: asOfDate counts item ledger entries up to that posting date, and no historical card cost is available. costIsAdjusted false means Inventory.AdjustCost.Run is due; costIsPostedToGL false means value entries are not yet posted to the general ledger. Nothing is changed.', Comment = 'is-IS=Veldu vöruna með subject (vörunúmer eða SystemId), data.itemNo, SystemId-lykli vöru eða data.tableView; kalli án þessara er hafnað. Ef ein vara er valin er svarið einnig á efsta stigi, en ef fleiri vörur eru valdar eingöngu í items. Kostnaðarverð, staðalkostnaður, síðasta beina kostnaðarverð, óbeinn kostnaður í prósentum og báðar stöðurnar eru núverandi gildi á vöruspjaldi. locationFilter, variantCode og asOfDate breyta aðeins birgðamagni: asOfDate telur vörufærslur til og með bókunardagsetningunni og enginn sögulegur spjaldkostnaður er í boði. costIsAdjusted false þýðir að tímabært er að keyra Inventory.AdjustCost.Run; costIsPostedToGL false þýðir að virðisfærslur hafa ekki enn verið bókaðar á fjárhag. Engu er breytt.';

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
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["itemNo","systemId"],"description":"Subject wins over data identifiers and tableView."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item; used when subject is empty.'));
        Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the Item; any one of the four keys.'));
        Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view that selects the item it can select several items, and the answer then lists them in items.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoDescriptionTxt: Label 'Item number. The message subject is the same item number when this key is omitted; a different item number in subject and itemNo is refused. Required unless a SystemId or tableView selects the items.', Comment = 'is-IS=Vörunúmer. Subject er sama vörunúmer þegar lykillinn er ekki sendur; ólík vörunúmer í subject og itemNo er hafnað. Nauðsynlegt nema SystemId eða tableView velji vörurnar.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoDescriptionTxt));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'The SystemId of the Item; used after the subject and itemNo.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'An Item table view; it can select several items.'));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, 'Business Central filter on the location code, applied to the inventory quantity only; card costs do not change.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant code, applied to the inventory quantity only; card costs do not change.'));
        Parameters.Add(ContractMgt.Parameter('asOfDate', 'string', false, 'Upper bound for the posting date as YYYY-MM-DD, applied to the inventory quantity only. Costs and the two cost flags stay current.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success."},{"name":"itemNo","type":"string","description":"Item number; only when exactly one item is selected."},{"name":"itemId","type":"string","description":"Item SystemId; only when exactly one item is selected."},{"name":"costingMethod","type":"string","description":"Invariant costing-method member name; only when exactly one item is selected."},{"name":"unitCost","type":"decimal","description":"Current Item Unit Cost; only when exactly one item is selected."},{"name":"standardCost","type":"decimal","description":"Current Item Standard Cost; only when exactly one item is selected."},{"name":"lastDirectCost","type":"decimal","description":"Current Item Last Direct Cost; only when exactly one item is selected."},{"name":"indirectCostPct","type":"decimal","description":"Current Item Indirect Cost %; only when exactly one item is selected."},{"name":"costIsAdjusted","type":"boolean","description":"Current Item adjustment flag; only when exactly one item is selected."},{"name":"costIsPostedToGL","type":"boolean","description":"Native current pending-cost FlowField; only when exactly one item is selected."},{"name":"inventory","type":"decimal","description":"Calculated stock quantity with location/variant and optional asOfDate; only when exactly one item is selected."},{"name":"locationFilter","type":"string","description":"Effective native location filter; only when exactly one item is selected."},{"name":"variantFilter","type":"string","description":"Effective native variant filter; only when exactly one item is selected."},{"name":"asOfDate","type":"string","description":"Optional ISO upper posting date for inventory only; only when exactly one item is selected."},{"name":"items","type":"array","description":"One current cost snapshot per selected item.","children":[{"name":"itemNo","type":"string","description":"Item number."},{"name":"itemId","type":"string","description":"Item SystemId."},{"name":"costingMethod","type":"string","description":"Invariant costing-method member name."},{"name":"unitCost","type":"decimal","description":"Current Item Unit Cost."},{"name":"standardCost","type":"decimal","description":"Current Item Standard Cost."},{"name":"lastDirectCost","type":"decimal","description":"Current Item Last Direct Cost."},{"name":"indirectCostPct","type":"decimal","description":"Current Item Indirect Cost %."},{"name":"costIsAdjusted","type":"boolean","description":"Current Item adjustment flag."},{"name":"costIsPostedToGL","type":"boolean","description":"Native current pending-cost FlowField."},{"name":"inventory","type":"decimal","description":"Native stock quantity with location/variant and optional asOfDate."},{"name":"locationFilter","type":"string","description":"Effective native location filter."},{"name":"variantFilter","type":"string","description":"Effective native variant filter."},{"name":"asOfDate","type":"string","description":"Optional ISO upper posting date for inventory only."}]}]}');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ContractParts: Codeunit "Inventory Contract Parts ori";
        NotFoundErr: Label 'Item {itemNo} was not found.', Comment = 'is-IS=Vara {itemNo} fannst ekki.';
        NotFoundWhenTxt: Label 'The item number, SystemId or tableView matches no item.', Comment = 'is-IS=Vörunúmerið, SystemId eða tableView passar ekki við neina vöru.';
        NotFoundFixTxt: Label 'Check the item number or the selection.', Comment = 'is-IS=Athugaðu vörunúmerið eða valið.';
    begin
        Clear(Errors);
        ContractParts.AddItemNoSubjectErrors(Errors, true);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, NotFoundWhenTxt, NotFoundFixTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'locationFilter or variantCode is not text, or the Costing domain is turned off in Inventory Setup.', 'Send locationFilter and variantCode as JSON text, or turn on the Costing domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Invalid date or identifier.', 'Use ISO date and valid identifiers.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Native Item read permission is absent.', 'Assign the appropriate read role.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native inventory filter error.','A location or inventory filter cannot be applied.','Correct the native filter syntax.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. Reads the current Item cost fields and the filtered inventory quantity.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Costing domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read items.');
        Effect.Add('preconditions', Preconditions);
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
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Use it when costIsAdjusted is false, to bring item costs up to date.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Calculate', 'Use it to read the remaining quantity and value of one item from its open item ledger entries; this type reads the current card costs.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Read the current cost and inventory of item 1000 as of a date',
            '{"type":"Inventory.Cost.Get","data":{"itemNo":"1000","asOfDate":"2026-10-14"}}',
            '{"status":"Success","itemNo":"1000","itemId":"6f1c1d2e-0000-0000-0000-000000000001","costingMethod":"FIFO","unitCost":12.5,"standardCost":0,"lastDirectCost":12,"indirectCostPct":0,"costIsAdjusted":true,"costIsPostedToGL":true,"inventory":40,"locationFilter":"","variantFilter":"","asOfDate":"2026-10-14","items":[{"itemNo":"1000","itemId":"6f1c1d2e-0000-0000-0000-000000000001","costingMethod":"FIFO","unitCost":12.5,"standardCost":0,"lastDirectCost":12,"indirectCostPct":0,"costIsAdjusted":true,"costIsPostedToGL":true,"inventory":40,"locationFilter":"","variantFilter":"","asOfDate":"2026-10-14"}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
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
