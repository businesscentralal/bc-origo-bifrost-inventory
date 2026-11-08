namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Reopen. Reproduces the platform inventory-period reopen writes. Codeunit 5820 is not run.
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
        PeriodWrite: Codeunit "Period Platform Write ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EndingDate: Date;
        MissingDateErr: Label 'endingDate is required.', Comment = 'is-IS=endingDate er nauðsynlegt.';
        NotFoundErr: Label 'Inventory period ending %1 was not found.', Comment = '%1 = ending date, is-IS=Birgðatímabil sem endar %1 fannst ekki.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('endingDate', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingDateErr, 'endingDate', '', '', '');
            exit;
        end;
        EndingDate := Token.AsValue().AsDate();
        if not InventoryPeriod.Get(EndingDate) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EndingDate), 'endingDate', '', '', '');
            exit;
        end;
        if InventoryPeriod.Closed then begin
            // Codeunit.Run of Close Inventory Period is a nested try function and cannot insert the entry.
            PeriodWrite.ApplyReopen(InventoryPeriod);
            InventoryPeriod.Get(EndingDate);
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No inventory period ends on endingDate.', 'Read the periods with Inventory.Period.Get and send the ending date of one of them.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central error text', 'endingDate is not a date, or Business Central refuses the change of the period.', 'Send endingDate as YYYY-MM-DD, or correct the cause in the text and retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Inventory Period domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on the Inventory Period table.', 'Ask an administrator for a permission set that grants it, for example the Bifrost "Full Access" permission set.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Reopens the Inventory Period that ends on endingDate by reproducing the inventory period entries of Close Inventory Period (5820), without running 5820, so OnRunOnBeforeCheck is not raised. The reopen also reopens every later closed inventory period and writes an inventory period entry for each period it reopens. A period that is already open is left as it is and answered Success. Nothing is posted. The change is saved with the caller''s transaction.');
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
        Overview := 'Reopens the inventory period that ends on the given date by reproducing the platform reopen writes. Close Inventory Period (5820) is not run, so OnRunOnBeforeCheck is not raised. A period that is already open is answered Success unchanged.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Reopens the Inventory Period identified by endingDate by reproducing the writes of Close Inventory Period (5820). This message does not run 5820, so its OnRunOnBeforeCheck integration event is not raised. The reopen also reopens every later closed inventory period and writes an inventory period entry for each period it reopens. The call is idempotent: a period that is already open is not modified and the reopen is not applied again. Only an existing period can be changed, and no message type creates periods, so an endingDate that matches no period is answered RecordNotFound. The Inventory Period domain must be turned on in Inventory Setup (a missing setup row counts as on). The caller needs write permission on the Inventory Period table; no posting permission set is required. The change is saved with the caller''s transaction. Use Inventory.Period.Get first to see the periods and Inventory.Period.Close to undo the change.', Comment = 'is-IS=Enduropnar birgðatímabilið sem endingDate vísar á með því að endurgera skrif Close Inventory Period (5820). Skilaboðin keyra ekki 5820, svo samþættingaratburðurinn OnRunOnBeforeCheck er ekki vakinn. Enduropnunin opnar einnig hvert síðara lokað birgðatímabil og skrifar birgðatímabilsfærslu fyrir hvert tímabil sem hún opnar. Kallið er óbreytilegt: tímabili sem er þegar opið er ekki breytt og enduropnunin er ekki framkvæmd aftur. Aðeins tímabil sem þegar er til er hægt að breyta og engin skilaboð stofna tímabil, svo endingDate sem passar við ekkert tímabil fær svarið RecordNotFound. Lénið Inventory Period verður að vera kveikt í Inventory Setup (vöntun á uppsetningarlínu telst sem kveikt). Kallarinn þarf skrifheimild á töfluna Inventory Period; ekki er krafist bókunarheimildar. Breytingin er vistuð með færslu kallandans. Notaðu Inventory.Period.Get fyrst til að sjá tímabilin og Inventory.Period.Close til að afturkalla breytinguna.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;
}
