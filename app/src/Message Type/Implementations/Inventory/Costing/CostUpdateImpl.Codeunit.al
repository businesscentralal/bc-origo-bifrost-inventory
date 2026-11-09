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
        NotesLbl: Label 'Select exactly one item with the message subject, data.itemNo, an item SystemId key or data.tableView; several matches are refused. Send at least one of unitCost, lastDirectCost and standardCost. Standard-costed items are always refused; use Inventory.Revaluation.Post for them. A blocked item is refused unless allowBlocked is true, and expectedCostingMethod must match the costing method of the item when it is sent. All checks run before the first field is changed, so a refusal changes nothing; the fields are then validated and the item is saved in one step. before and after show the three cost fields around the change. Nothing is revalued or posted. In a chained Omit Commit call, the write remains in the caller transaction and a native failure propagates so the whole chain can roll back.', Comment = 'is-IS=Veldu nákvæmlega eina vöru með subject, data.itemNo, SystemId-lykli vöru eða data.tableView; ef fleiri vörur passa er kallinu hafnað. Sendu að minnsta kosti eitt af unitCost, lastDirectCost og standardCost. Vörum með staðlað kostnaðarverð er alltaf hafnað; notaðu Inventory.Revaluation.Post fyrir þær. Lokaðri vöru er hafnað nema allowBlocked sé true, og expectedCostingMethod verður að passa við kostnaðaraðferð vörunnar ef það er sent. Allar athuganir eru gerðar áður en fyrsti reiturinn er breyttur, svo höfnun breytir engu; reitirnir eru síðan sannprófaðir og varan vistuð í einu skrefi. before og after sýna kostnaðarreitina þrjá fyrir og eftir breytingu. Engu er endurmetið eða bókað. Í keðjuðu Omit Commit kalli helst skrifunin í færslu kallandans og innbyggð villa berst áfram svo hægt sé að afturkalla alla keðjuna.';

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
        Request: JsonObject;
        Token: JsonToken;
        ItemSelection: Text;
        NativeExpectedTxt: Label 'Cost fields that pass native item validation.', Comment = 'is-IS=Kostnaðarreitir sem standast innbyggða vörusannprófun.';
        NativeNextStepTxt: Label 'Review the selected item; use lastDirectCost if unitCost is refused for an item with entries, or Inventory.Revaluation.Post for Standard costing.', Comment = 'is-IS=Farðu yfir valda vöru; notaðu lastDirectCost ef unitCost er hafnað fyrir vöru með færslum eða Inventory.Revaluation.Post fyrir staðalkostnað.';
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ItemSelection := Argument.Subject;
        Request := Argument.GetRequestJson();
        if (ItemSelection = '') and Request.Get('itemNo', Token) then
            ItemSelection := Format(Token);
        Process.SetOperation('CostUpdate');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'itemNo', ItemSelection, NativeExpectedTxt, NativeNextStepTxt);
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item; used when subject is empty.'));
        Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the Item; any one of the four keys.'));
        Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view that selects the item it must select exactly one item.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract for guarded cost writes.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'The No. of the Item; used when subject is empty.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'The SystemId of the Item; used after the subject and itemNo.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'An Item table view; it must select exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('unitCost', 'number', false, 'The new Unit Cost of the item, as a JSON number or an invariant decimal text such as 12.5.'));
        Parameters.Add(ContractMgt.Parameter('lastDirectCost', 'number', false, 'The new Last Direct Cost of the item, as a JSON number or an invariant decimal text.'));
        Parameters.Add(ContractMgt.Parameter('standardCost', 'number', false, 'The new Standard Cost of the item, as a JSON number or an invariant decimal text. Items with the Standard costing method are refused whatever you send.'));
        Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'true permits changing a blocked item; default false.'));
        Parameters.Add(ContractMgt.Parameter('expectedCostingMethod', 'string', false, 'Optional guard: the costing method the item must have, for example FIFO or Average; the comparison ignores case.'));
        exit(true);
    end;

    /// <summary>Returns the response contract for guarded cost writes.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Before: JsonObject;
        After: JsonObject;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The No. of the updated Item.'));
        Fields.Add(ContractMgt.ResponseField('itemId', 'string', 'The SystemId of the updated Item.'));
        Fields.Add(ContractMgt.ResponseField('costingMethod', 'string', 'The costing method name of the item, for example FIFO or Average.'));
        Before := ContractMgt.ResponseField('before', 'object', 'The three card cost fields before the change.');
        Before.Add('children', CostFieldChildren());
        Fields.Add(Before);
        After := ContractMgt.ResponseField('after', 'object', 'The same three card cost fields after the change.');
        After.Add('children', CostFieldChildren());
        Fields.Add(After);
        Fields.Add(ContractMgt.ResponseField('warnings', 'array', 'Always empty on a successful call.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract for guarded cost writes.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The subject, itemNo, SystemId key or tableView matches no item.', 'Supply an existing item.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on items.', 'Review the permissions of the caller.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Costing domain is turned off in Inventory Setup.', 'Turn on the Costing domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'unitCost, lastDirectCost, standardCost or allowBlocked has the wrong format, or an item selection key is invalid.', 'Use JSON numbers or invariant decimal text for the costs, JSON true or false for allowBlocked, and valid identifiers.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'unitCost, lastDirectCost or standardCost is present but null or empty.', 'Supply a numeric cost value or leave the key out.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several request format or lookup values are invalid.', 'Correct every errors[] entry before retrying; no item was changed.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Item selection or all three cost keys are absent.', 'Select one item and send at least one cost value.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, 'The selection matches several items.', 'Select exactly one item.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The item is Standard-costed, blocked without opt-in, or expectedCostingMethod differs.', 'Use Inventory.Revaluation.Post for Standard costing; otherwise correct the named guard.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native cost field validation fails.', 'Inspect the selected item; use lastDirectCost when native unitCost validation refuses an item with entries.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract for guarded cost writes.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Changes the unit cost, last direct cost and standard cost you send on one Item card. No revaluation, no value entries and no ledger entries are created. All checks run before the first field is changed, and a failure changes nothing. Business Central commits the change when the call finishes.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('Exactly one Item selected.');
        Preconditions.Add('Non-Standard costing method.');
        Preconditions.Add('Native Item write access and each supplied field permission.');
        Preconditions.Add('Costing domain and normal licensed dispatch.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Returns the related contract for guarded cost writes.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.Cost.Get', 'Use it to read the current costs before or after the update; it changes nothing.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Post', 'Use it to change the value of Standard-costed items, which this type refuses.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Price.Update', 'Use it to change the unit price; this type never changes prices.'));
        exit(true);
    end;

    /// <summary>Returns the examples contract for guarded cost writes.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Update the unit cost and last direct cost of item 1000, guarded by its costing method',
            '{"type":"Inventory.Cost.Update","data":{"itemNo":"1000","unitCost":12,"lastDirectCost":10,"expectedCostingMethod":"FIFO"}}',
            '{"status":"Success","itemNo":"1000","itemId":"6f1c1d2e-0000-0000-0000-000000000001","costingMethod":"FIFO","before":{"unitCost":11,"lastDirectCost":9,"standardCost":0},"after":{"unitCost":12,"lastDirectCost":10,"standardCost":0},"warnings":[]}'));
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Cost.Get', 'Read the current costs and the costing method of the item.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Cost.Update', 'Change the card cost fields of a non-Standard item.'));
        Workflow.Add('steps', Steps);
        exit(true);
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

    local procedure CostFieldChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('unitCost', 'decimal', 'The Unit Cost of the item.'));
        Children.Add(ContractMgt.ResponseField('lastDirectCost', 'decimal', 'The Last Direct Cost of the item.'));
        Children.Add(ContractMgt.ResponseField('standardCost', 'decimal', 'The Standard Cost of the item.'));
    end;
}
