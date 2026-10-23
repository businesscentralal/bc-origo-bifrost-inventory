namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.Price.Update. Validates Item.Unit Price. This is not a cost update.
/// </summary>
codeunit 10076886 "Price Update Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Updates an item unit price.', Comment = 'is-IS=Uppfærir einingarverð vöru.';
        SelectionLbl: Label 'Selects exactly one item using the Foundation subject, identifier or tableView rules.', Comment = 'is-IS=Velur nákvæmlega eina vöru samkvæmt reglum grunnforritsins um subject, auðkenni eða tableView.';
        KeywordsLbl: Label 'update item price, unit price', Comment = 'is-IS=uppfæra vöruverð,einingarverð';
        OverviewLbl: Label 'Updates the unit price of one item.', Comment = 'is-IS=Uppfærir einingarverð einnar vöru.';
        NotesLbl: Label 'Select exactly one item with the message subject, itemNo, an item SystemId key or tableView; a key other than those, unitPrice and allowBlocked is refused, and a selection key must be non-empty text. unitPrice is required. A blocked item is refused unless allowBlocked is true. Only the Unit Price of the Item card changes: price lists, discounts and costs are not touched. All checks run before the change, so a refusal changes nothing.', Comment = 'is-IS=Veldu nákvæmlega eina vöru með subject, itemNo, SystemId-lykli vöru eða tableView; lykli öðrum en þessum, unitPrice og allowBlocked er hafnað og valslykill verður að vera texti sem er ekki tómur. unitPrice er nauðsynlegt. Lokaðri vöru er hafnað nema allowBlocked sé true. Aðeins einingarverð á vöruspjaldi breytist: verðlistar, afslættir og kostnaður breytast ekki. Allar athuganir eru gerðar áður en breytt er, svo höfnun breytir engu.';

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemPrice, Database::Item, true, false));
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["itemNo","systemId"],"description":"Exactly one item; Foundation subject precedence applies."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
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

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'The No. of the Item; used when subject is empty. A selection key must be non-empty text.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'The SystemId of the Item; used after the subject and itemNo. A selection key must be non-empty text.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'An Item table view; it must select exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('unitPrice', 'number', true, 'The new Unit Price of the item, as a JSON number or an invariant decimal text such as 25.5.'));
        Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'true permits changing a blocked item; default false.'));
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success for a completed native operation.'));
        Fields.Add(ContractMgt.ResponseField('messageType', 'string', 'Stable message type name.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The resolved item number.'));
        Fields.Add(ContractMgt.ResponseField('itemId', 'string', 'The resolved Item SystemId.'));
        Fields.Add(ContractMgt.ResponseField('previousUnitPrice', 'decimal', 'Unit Price before native validation.'));
        Fields.Add(ContractMgt.ResponseField('unitPrice', 'decimal', 'Unit Price after native validation.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'unitPrice is absent, null or empty.', 'Supply the new unit price.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Item Price domain is turned off in Inventory Setup.', 'Turn on the Item Price domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The subject, itemNo, SystemId key or tableView matches no item.', 'Select an existing item.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on items.', 'Request the required permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'unitPrice is not a number or allowBlocked is not a Boolean.', 'Use a JSON number or invariant decimal text for unitPrice, and JSON true or false for allowBlocked.'));
        Errors.Add(ContractMgt.TextErrorEntry('The refusal or validation text of Business Central.', 'No item is selected or several items match, a selection key is not non-empty text, a key other than the selection keys, unitPrice and allowBlocked is sent, the item is blocked without allowBlocked, Unit Price is restricted for the caller, or Business Central validation fails. The text is returned as it is, with code BusinessCentralError, and nothing is changed.', 'Correct the selection or the request and send it again.'));
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Sets the Unit Price on one Item card. No price list, no cost and no ledger entries are changed. All checks run before the change, and a failure changes nothing. Business Central commits the change when the call finishes; under Omit Commit the commit is left to the caller.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('The Item Price domain is turned on in Inventory Setup.');
        Preconditions.Add('Exactly one item is selected, and it is not blocked unless allowBlocked is true.');
        Preconditions.Add('The caller can write items and the Unit Price field.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Item.Price.Get', 'Use it to read the prices of items before or after the update; it changes nothing.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Cost.Update', 'Use it to change the cost fields of an item; this type changes only the Unit Price.'));
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Item.Price.Get', 'Read the current unit price of the item.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Price.Update', 'Change the Unit Price on the Item card.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Set the unit price of item 1000 to 25',
            '{"type":"Inventory.Price.Update","data":{"itemNo":"1000","unitPrice":25}}',
            '{"status":"Success","messageType":"Inventory.Price.Update","itemNo":"1000","itemId":"6f1c1d2e-0000-0000-0000-000000000001","previousUnitPrice":20,"unitPrice":25}'));
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs the licensed native price transaction.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Process: Codeunit "Inventory Write Process ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemPrice, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('PriceUpdate');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
