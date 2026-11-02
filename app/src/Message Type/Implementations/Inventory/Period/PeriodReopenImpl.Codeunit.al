namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Reopen. Reopens a closed inventory period.
/// </summary>
codeunit 10076879 "Period Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Inventory Period");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reopens a closed inventory period.', Comment = 'is-IS=Enduropnar lokað birgðatímabil.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reopen inventory period', Comment = 'is-IS=enduropna birgðatímabil';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reopens a closed inventory period.', Comment = 'is-IS=Opnar lokað birgðatímabil aftur.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        InventoryPeriod: Record "Inventory Period";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Reader: Codeunit "Request Value Reader ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        EndingDate: Date;
        PeriodExpectedTxt: Label 'An existing inventory period ending on the ISO date YYYY-MM-DD.', Comment = 'is-IS=Birgðatímabil sem er til og endar á ISO-dagsetningunni YYYY-MM-DD.';
        PeriodNextStepTxt: Label 'Read Inventory.Period.Get and send an existing endingDate as YYYY-MM-DD.', Comment = 'is-IS=Lestu Inventory.Period.Get og sendu endingDate tímabils sem er til á sniðinu YYYY-MM-DD.';
        NotFoundErr: Label 'Inventory period ending %1 was not found.', Comment = '%1 = ending date, is-IS=Birgðatímabil sem endar %1 fannst ekki.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not Reader.TryReadDate(Argument, RequestJson, 'endingDate', true, EndingDate) then
            exit;
        if not InventoryPeriod.Get(EndingDate) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, Format(EndingDate, 0, 9)), 'endingDate', Format(EndingDate, 0, 9), PeriodExpectedTxt, PeriodNextStepTxt);
            exit;
        end;
        if InventoryPeriod.Closed then begin
            InventoryPeriod.Validate(Closed, false);
            InventoryPeriod.Modify(true);
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson.Add('name', InventoryPeriod.Name);
        ResponseJson.Add('closed', InventoryPeriod.Closed);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"No subject is used; the period is identified by data.endingDate."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.endingDate', 'date', 'The Ending Date of the Inventory Period, which is the key of the period. The period must already exist.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
    begin
        Clear(Parameters);
        Parameter := ContractMgt.Parameter('endingDate', 'string', true, 'Ending date of the inventory period to reopen, YYYY-MM-DD. An inventory period that ends on this date must exist.');
        Parameter.Add('format', 'YYYY-MM-DD');
        Parameters.Add(Parameter);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the period is open.'));
        Fields.Add(ContractMgt.ResponseField('endingDate', 'string', 'Ending date of the period, YYYY-MM-DD.'));
        Fields.Add(ContractMgt.ResponseField('name', 'string', 'Name of the period.'));
        Fields.Add(ContractMgt.ResponseField('closed', 'boolean', 'Closed flag of the period after the call; false.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'endingDate is absent.', 'Send endingDate as YYYY-MM-DD.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'endingDate is not a JSON string in YYYY-MM-DD format.', 'Use the expected ISO date format; no period was changed.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No inventory period ends on endingDate.', 'Read the periods with Inventory.Period.Get and send the ending date of one of them.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central error text', 'Business Central refuses the change of the selected period.', 'Send endingDate as YYYY-MM-DD, or correct the cause in the text and retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Inventory Period domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on the Inventory Period table.', 'Ask an administrator for a permission set that grants it, for example BIFROST Full ori.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Clears the Closed flag of the Inventory Period that ends on endingDate through the table validation. A period that is already open is left as it is and answered Success. Nothing is posted. The change commits with the answer; under Omit Commit the caller''s transaction commits instead.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('writes', true);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Get', 'Use it to read the periods and their ending dates before changing one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Close', 'Use it to close the period instead.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Period.Get', 'Read the periods and pick the closed one to reopen.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Period.Reopen', 'Reopen the period.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Period.Close', 'Close the period again when the correction is done.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Reopen the period that ends on 30 September 2026',
            '{"type":"Inventory.Period.Reopen","data":{"endingDate":"2026-09-30"}}',
            '{"status":"Success","endingDate":"2026-09-30","name":"September 2026","closed":false}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reopens the inventory period that ends on the given date. A period that is already open is answered Success unchanged.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Clears the Closed flag of the Inventory Period identified by endingDate and returns the period. It posts nothing and runs no other function; the change goes through the validation of the Inventory Period table. ' +
            'The call is idempotent: a period that already has the requested state is not modified. Only an existing period can be changed, and no message type creates periods, so an endingDate that matches no period is answered RecordNotFound. ' +
            'The Inventory Period domain must be turned on in Inventory Setup (a missing setup row counts as on). The caller needs write permission on the Inventory Period table; no posting permission set is required. ' +
            'The change commits with the answer; under Omit Commit the caller''s transaction commits instead. ' +
            'Use Inventory.Period.Get first to see the periods and Inventory.Period.Close to undo the change.';
        exit(true);
    end;
}
