namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

codeunit 70013467 "Cost To GL Test Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Runs native report 1003 for selected pending inventory costs and returns warnings without posting.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('test post inventory cost to gl, cost to gl test');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Runs native report 1003 for selected pending inventory costs and returns warnings without posting.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"No subject selection."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[]');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"itemNo","type":"string","required":false,"description":"Native Item No. filter; blank selects all pending entries. Legacy itemNoFilter is accepted only when equal if both are present.","default":""},{"name":"postingDate","type":"string","required":false,"description":"Native Posting Date filter on pending value entries. Legacy postingDateFilter is accepted.","default":""},{"name":"perPostingGroup","type":"boolean","required":false,"description":"False posts/tests per entry; true summarizes by posting group.","default":false},{"name":"documentNo","type":"string","required":false,"description":"Output document number required with perPostingGroup=true; forbidden with per-entry posting. This is not a document filter.","default":""},{"name":"itemNoFilter","type":"string","required":false,"default":"","description":"Legacy alias of itemNo; conflicting simultaneous values are refused."},{"name":"postingDateFilter","type":"string","required":false,"default":"","description":"Legacy alias of postingDate; conflicting simultaneous values are refused."}]');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success when the native report completes."},{"name":"posted","type":"boolean","description":"False for test; true for completed posting mode, even if the native report leaves entries pending."},{"name":"entriesSelected","type":"integer","description":"Selected pending-entry count before execution."},{"name":"errors","type":"array","description":"Native report 1003 warning objects with message text."}]}');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"InvalidParameter","when":"Company Costing domain is disabled.","fix":"Enable Costing in Inventory Setup."},{"code":"PermissionDenied","when":"The domain or Item read permission gate refuses the caller.","fix":"Review permissions."},{"code":"PreconditionFailed","when":"Request validation or the native report fails; no native commit rollback is promised.","fix":"Review the returned error and actual ledger state."},{"code":"BusinessCentralError","when":"Foundation scheduled-task failure handler maps uncaught failures. Direct invocation may raise instead.","fix":"Review the native error and current ledger state before retrying."}]');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"readOnly","writes":false,"posts":false,"changes":"Runs native report 1003 for selected pending inventory costs and returns warnings without posting.","idempotent":true,"preconditions":["Company Costing and permission gates allow execution.","The native report setup and permissions allow execution.","Item and posting-date filters select pending value entries; documentNo is an output option."]}');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.CostToGL.Post', 'Post inventory cost to the general ledger after the test.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Adjust item costs before posting them to the general ledger.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Runs native report 1003 for selected pending inventory costs and returns warnings without posting.","request":{"type":"Inventory.CostToGL.Test","version":"1.0","data":{"itemNo":"XITEM"}}}]');
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs native report 1003 for selected pending inventory costs and returns warnings without posting.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Native report 1003 warnings are returned in errors[]. entriesSelected is the pre-run pending-entry count, not a count of successfully validated entries. No report 795 execution or posting occurs. Journal Templ. Name Mandatory is refused because the native test report otherwise consumes a number. documentNo is an output option, not a filter.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Response: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not TryTestCostToGL(Argument.GetRequestJson(), Response) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryTestCostToGL(Request: JsonObject; var Response: JsonObject)
    var
        CostReports: Codeunit "Inventory Cost Reports ori";
    begin
        CostReports.TestCostToGL(Request, Response);
    end;
}
