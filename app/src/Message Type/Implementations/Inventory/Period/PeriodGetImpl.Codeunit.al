namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Get. Reads inventory periods.
/// </summary>
codeunit 10076878 "Period Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Inventory Period");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads inventory periods.', Comment = 'is-IS=Les birgðatímabil.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'inventory period, closed period', Comment = 'is-IS=birgðatímabil, lokað tímabil';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads inventory periods. Close and reopen are separate types.', Comment = 'is-IS=Les birgðatímabil. Lokun og enduropnun eru aðskildar tegundir.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        InventoryPeriod: Record "Inventory Period";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ResponseJson: JsonObject;
        Periods: JsonArray;
        PeriodJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if InventoryPeriod.FindSet() then
            repeat
                Clear(PeriodJson);
                PeriodJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
                PeriodJson.Add('name', InventoryPeriod.Name);
                PeriodJson.Add('closed', InventoryPeriod.Closed);
                Periods.Add(PeriodJson);
            until InventoryPeriod.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('periods', Periods);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"No subject is used; every inventory period is returned."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('none', 'all inventory periods', 'No single record is addressed and no identifier is read; every Inventory Period is returned.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Field: JsonObject;
        Fields: JsonArray;
        Children: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the periods were read.'));
        Field := ContractMgt.ResponseField('periods', 'array', 'Every inventory period, in the order of the ending date; empty when the company has none.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('endingDate', 'string', 'Ending date of the period, YYYY-MM-DD.'));
        Children.Add(ContractMgt.ResponseField('name', 'string', 'Name of the period.'));
        Children.Add(ContractMgt.ResponseField('closed', 'boolean', 'True when the period is closed.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Inventory Period domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no read permission on the Inventory Period table.', 'Ask an administrator for a permission set that grants it, for example Bifrost Read-Only.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. The inventory periods are only read.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'Bifrost Read-Only');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Close', 'Use it to close an inventory period that this call shows as open.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Reopen', 'Use it to reopen a period that this call shows as closed.'));
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
            'Read all inventory periods',
            '{"type":"Inventory.Period.Get"}',
            '{"status":"Success","periods":[{"endingDate":"2026-09-30","name":"September 2026","closed":true},{"endingDate":"2026-10-31","name":"October 2026","closed":false}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Returns every inventory period with its ending date, name and whether it is closed. It reads only and takes no parameters.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only. Every Inventory Period of the company is returned in the order of the ending date, with no filter and no limit; a company without periods gets an empty periods array. ' +
            'The Inventory Period domain must be turned on in Inventory Setup (a missing setup row counts as on) and the caller needs read permission on the Inventory Period table. ' +
            'Use Inventory.Period.Close or Inventory.Period.Reopen to change a period.';
        exit(true);
    end;
}
