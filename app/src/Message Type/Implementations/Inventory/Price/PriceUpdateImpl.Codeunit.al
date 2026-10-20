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
        NotesLbl: Label 'Requires one explicit item selection, native Item and Unit Price field access, and unitPrice. Unsupported fields refuse. Uses Validate and Modify in a Codeunit.Run boundary. Writes no price list or inventory revaluation. Normal licensing and company setup apply.', Comment = 'is-IS=Krefst afdráttarlauss vals á einni vöru, innbyggðs aðgangs að vöru og einingarverði og unitPrice. Óstuddum reitum er hafnað. Notar Validate og Modify innan Codeunit.Run. Skráir hvorki verðlista né birgðaendurmat. Venjulegar leyfis- og fyrirtækisstillingar gilda.';

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
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item');
        Target.Add(TargetJson);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Nonempty native Item selection; must resolve exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Nonempty native Item selection; must resolve exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Nonempty native Item selection; must resolve exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Nonempty native Item selection; must resolve exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Nonempty native Item selection; must resolve exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'Nonempty native Item selection; must resolve exactly one item.'));
        Parameters.Add(ContractMgt.Parameter('unitPrice', 'decimal', true, 'Native Item Unit Price; JSON number or invariant decimal string.'));
        Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'Explicitly permit a blocked item; default false.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'unitPrice is absent.', 'Supply the required value.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Company Costing is disabled or a typed value is invalid; unsupported keys raise a native text error.', 'Enable the company domain or correct the request value.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Item selection finds nothing.', 'Select an existing record.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Native Item or Unit Price field permission refuses the caller.', 'Request the required native permission from an administrator.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native selection, validation or report error.','Selection is ambiguous, item is blocked without opt-in or native validation fails. The direct native call may raise; the process wrapper returns text without a typed code.','Correct the selected batch, input or native validation error before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A date, decimal or Boolean request value has the wrong format.', 'Use ISO dates, invariant decimals and JSON Booleans.'));
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Update one item price","request":{"type":"Inventory.Price.Update","subject":"OWNED-ITEM","data":{"unitPrice":25}}}]');
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
