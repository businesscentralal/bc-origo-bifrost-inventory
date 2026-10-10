namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.CostToGL.Post. Runs report 1002 when Adjust Cost was run with postToGL false.
/// </summary>
codeunit 70013462 "Cost To GL Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        PostInventoryCost: Report "Post Inventory Cost to G/L";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit;
        RequestJson := Argument.GetRequestJson();
        PostInventoryCost.UseRequestPage(false);
        if not PostInventoryCost.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidOperation, GetLastErrorText(), '', '', '', '');
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNoFilter', ReadText(RequestJson, 'itemNoFilter'));
        ResponseJson.Add('documentNoFilter', ReadText(RequestJson, 'documentNoFilter'));
        Argument.RespondWithSuccess(ResponseJson);
    end;

    /// <summary>Returns the Item table used by the existing selection contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Returns the existing costing selection description.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Post inventory value entries that are not yet posted to the general ledger.');
    end;

    /// <summary>Returns the existing costing discovery keywords.</summary>
    procedure GetKeywords(): Text
    begin
        exit('post inventory cost,general ledger,report 1002');
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
    begin
        exit('Runs report 1002 without request selection or explicit Post initialization; success means report completion, not proof of G/L posting.');
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
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"itemNoFilter","type":"string","required":false,"description":"Echoed in the success response only; does not filter report 1002.","default":""},{"name":"documentNoFilter","type":"string","required":false,"description":"Echoed in the success response only; does not filter report 1002.","default":""}]');
        exit(true);
    end;

    /// <summary>Returns the response chapter for the existing costing operation.</summary>
    /// <param name="Response">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success after the standard report returns successfully and response construction completes; not proof of G/L posting."},{"name":"itemNoFilter","type":"string","description":"Original request value echoed by the current implementation."},{"name":"documentNoFilter","type":"string","description":"Original request value echoed by the current implementation."}]}');
        exit(true);
    end;

    /// <summary>Returns the errors chapter for the existing costing operation.</summary>
    /// <param name="Errors">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"InvalidParameter","when":"The company Costing domain is disabled.","fix":"Turn on the Costing domain in Inventory Setup."},{"code":"PermissionDenied","when":"The existing inventory posting gate denies the caller.","fix":"Have the administrator review the existing inventory posting permission policy."},{"code":"InvalidOperation","when":"The standard report Run returns false; response carries GetLastErrorText. This branch precedes response-echo conversion.","fix":"Review the standard report error and current ledger state before deciding whether retry is safe."},{"code":"BusinessCentralError","when":"Through the normal Foundation scheduled-task error-handler path, an uncollected task/report/conversion failure is answered by Message Error as BusinessCentralError. Synchronous dispatcher execution does not itself invoke that scheduled failure codeunit. Direct invocation may raise instead; exact scalar/null conversions still require supported-platform runtime verification.","fix":"Review the actual report or conversion error and current ledger state; no rollback or safe-retry guarantee is declared."}]');
        exit(true);
    end;

    /// <summary>Returns the effect chapter for the existing costing operation.</summary>
    /// <param name="Effect">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"effect":"irreversible","writes":true,"posts":true,"changes":"Report 1002 may write or post under its standard/runtime options. The caller neither initializes Post nor applies request filter fields. Report completion does not prove G/L posting.","idempotent":false,"preconditions":["The company Costing domain and existing posting gate permit execution.","Standard report setup and caller permissions permit execution."]}');
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
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.AdjustCost.Run","useInsteadWhen":"Adjust item costs with report 795 first when that is the required operation."}]');
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
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Run report 1002; filters are response echoes and Success only means completion.","request":{"type":"Inventory.CostToGL.Post","version":"1.0","data":{"itemNoFilter":"1000","documentNoFilter":""}},"response":{"status":"Success","itemNoFilter":"1000","documentNoFilter":""}}]');
        exit(true);
    end;

    /// <summary>Returns the overview chapter for the existing costing operation.</summary>
    /// <param name="Overview">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Runs report 1002 without request selection or explicit Post initialization; success means report completion, not proof of G/L posting.';
        exit(true);
    end;

    /// <summary>Returns the notes chapter for the existing costing operation.</summary>
    /// <param name="Notes">Receives this contract chapter.</param>
    /// <returns>True when this chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'Absent or object/array-valued echo fields fall back to empty text in the local text reader. Scalar and null conversion outcomes require exact BC28/BC29 runtime tests. No preview, rollback, idempotence or safe-retry guarantee is declared. Request data is obtained before report execution, but filter echo conversion occurs after report 1002 completes. Malformed echoes are not preflight validation. Request filters do not select records. Post/PostMethod/saved-option/runtime effects remain unverified.';
        exit(true);
    end;
}
