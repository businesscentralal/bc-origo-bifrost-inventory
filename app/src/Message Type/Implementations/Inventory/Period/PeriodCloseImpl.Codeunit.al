namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Close. Reproduces the platform inventory-period close checks and writes. Codeunit 5820 is not run.
/// </summary>
codeunit 10076877 "Period Close Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Closes the inventory period that ends on the given ending date.', Comment = 'is-IS=Lokar birgðatímabilinu sem endar á gefinni lokadagsetningu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'close inventory period, lock inventory period', Comment = 'is-IS=loka birgðatímabili, læsa birgðatímabili';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Closes an inventory period. An already closed period returns success.', Comment = 'is-IS=Lokar birgðatímabili. Tímabil sem er þegar lokað skilar árangri.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
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
        PlatformError: Text;
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
        if not InventoryPeriod.Closed then begin
            // Codeunit.Run of Close Inventory Period is a nested try function and cannot insert the entry.
            // The same read-only checks are answered here. A passing period is closed in this transaction.
            PlatformError := PlatformCloseRefusal(EndingDate);
            if PlatformError <> '' then begin
                Argument.RespondWithError(PlatformError);
                exit;
            end;
            PeriodWrite.ApplyClose(InventoryPeriod);
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
        Parameter := ContractMgt.Parameter('endingDate', 'string', true, 'Ending date of the inventory period to close, YYYY-MM-DD. An inventory period that ends on this date must exist.');
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the period is closed.'));
        Fields.Add(ContractMgt.ResponseField('endingDate', 'string', 'Ending date of the period, YYYY-MM-DD.'));
        Fields.Add(ContractMgt.ResponseField('name', 'string', 'Name of the period.'));
        Fields.Add(ContractMgt.ResponseField('closed', 'boolean', 'Closed flag of the period after the call; true.'));
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
        Effect.Add('changes', 'Closes the Inventory Period that ends on endingDate by reproducing the checks and inventory period entries of Close Inventory Period (5820), without running 5820, so OnRunOnBeforeCheck is not raised. The close also closes earlier open inventory periods and writes an inventory period entry for each period it closes. A period that is already closed is left as it is and answered Success. Nothing is posted. The change is saved with the caller''s transaction.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Reopen', 'Use it to reopen the period instead.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Period.Get', 'Read the periods and pick the ending date to close.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Period.Close', 'Close the period.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Period.Reopen', 'Reopen the period if it was closed by mistake.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Close the period that ends on 30 September 2026',
            '{"type":"Inventory.Period.Close","data":{"endingDate":"2026-09-30"}}',
            '{"status":"Success","endingDate":"2026-09-30","name":"September 2026","closed":true}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Closes the inventory period that ends on the given date by reproducing the platform close checks and writes. Close Inventory Period (5820) is not run, so OnRunOnBeforeCheck is not raised. A period that is already closed is answered Success unchanged.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Closes the Inventory Period identified by endingDate by reproducing the checks and writes of Close Inventory Period (5820). This message does not run 5820, so its OnRunOnBeforeCheck integration event is not raised. The close also closes every earlier open inventory period and writes an inventory period entry for each period it closes. A refusal, such as unadjusted cost, an unadjusted finished order or open negative inventory, is returned as an error and writes nothing. The call is idempotent: a period that is already closed is not modified and the close is not applied again. Only an existing period can be changed, and no message type creates periods, so an endingDate that matches no period is answered RecordNotFound. The Inventory Period domain must be turned on in Inventory Setup (a missing setup row counts as on). The caller needs write permission on the Inventory Period table; no posting permission set is required. The change is saved with the caller''s transaction. Use Inventory.Period.Get first to see the periods and Inventory.Period.Reopen to undo the change.', Comment = 'is-IS=Lokar birgðatímabilinu sem endingDate vísar á með því að endurgera athuganir og skrif Close Inventory Period (5820). Skilaboðin keyra ekki 5820, svo samþættingaratburðurinn OnRunOnBeforeCheck er ekki vakinn. Lokunin lokar einnig hverju eldra opnu birgðatímabili og skrifar birgðatímabilsfærslu fyrir hvert tímabil sem hún lokar. Höfnun, svo sem óleiðréttur kostnaður, óleiðrétt lokin pöntun eða opin neikvæð birgðastaða, kemur til baka sem villa og skrifar ekkert. Kallið er óbreytilegt: tímabili sem er þegar lokað er ekki breytt og lokunin er ekki framkvæmd aftur. Aðeins tímabil sem þegar er til er hægt að breyta og engin skilaboð stofna tímabil, svo endingDate sem passar við ekkert tímabil fær svarið RecordNotFound. Lénið Inventory Period verður að vera kveikt í Inventory Setup (vöntun á uppsetningarlínu telst sem kveikt). Kallarinn þarf skrifheimild á töfluna Inventory Period; ekki er krafist bókunarheimildar. Breytingin er vistuð með færslu kallandans. Notaðu Inventory.Period.Get fyrst til að sjá tímabilin og Inventory.Period.Reopen til að afturkalla breytinguna.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>
    /// Same refusal order as the platform inventory-period close, without raising Error().
    /// </summary>
    local procedure PlatformCloseRefusal(EndingDate: Date): Text
    var
        InvtAdjmtEntryOrder: Record "Inventory Adjmt. Entry (Order)";
        ValueEntry: Record "Value Entry";
        ItemLedgEntry: Record "Item Ledger Entry";
        AvgCostEntryPointHandler: Codeunit "Avg. Cost Entry Point Handler";
        UnadjustedErr: Label 'The Inventory Period cannot be closed because there is at least one item with unadjusted entries in the current period.\Run the Close Inventory Period - Test report to identify item ledger entries for the affected items.', Comment = 'is-IS=Ekki er hægt að loka birgðatímabilinu vegna þess að að minnsta kosti ein vara hefur óleiðréttar færslur á tímabilinu.\Keyrðu prófunarskýrsluna Loka birgðatímabili til að finna vörufærslurnar.';
        NegativeErr: Label 'The Inventory Period cannot be closed because there is negative inventory for one or more items.\Run the Close Inventory Period - Test report to identify item ledger entries for the affected items.', Comment = 'is-IS=Ekki er hægt að loka birgðatímabilinu vegna þess að ein eða fleiri vörur eru með neikvæða birgðastöðu.\Keyrðu prófunarskýrsluna Loka birgðatímabili til að finna vörufærslurnar.';
        OrderErr: Label 'The Inventory Period cannot be closed because there is at least one %1 Order in the current period that has not been adjusted.\Run the Close Inventory Period - Test report to identify the affected orders.', Comment = '%1 = order type, is-IS=Ekki er hægt að loka birgðatímabilinu vegna þess að að minnsta kosti ein %1 pöntun á tímabilinu hefur ekki verið leiðrétt.\Keyrðu prófunarskýrsluna Loka birgðatímabili til að finna viðkomandi pantanir.';
    begin
        if not AvgCostEntryPointHandler.IsEntriesAdjusted('', EndingDate) then
            exit(UnadjustedErr);

        InvtAdjmtEntryOrder.SetCurrentKey("Cost is Adjusted");
        InvtAdjmtEntryOrder.SetRange("Cost is Adjusted", false);
        InvtAdjmtEntryOrder.SetRange("Is Finished", true);
        if InvtAdjmtEntryOrder.FindSet() then
            repeat
                ValueEntry.SetCurrentKey("Order Type", "Order No.", "Order Line No.");
                ValueEntry.SetRange("Order Type", InvtAdjmtEntryOrder."Order Type");
                ValueEntry.SetRange("Order No.", InvtAdjmtEntryOrder."Order No.");
                ValueEntry.SetRange("Order Line No.", InvtAdjmtEntryOrder."Order Line No.");
                ValueEntry.SetFilter("Item Ledger Entry Type", '%1|%2',
                  ValueEntry."Item Ledger Entry Type"::Output, ValueEntry."Item Ledger Entry Type"::"Assembly Output");
                ValueEntry.SetRange("Valuation Date", 0D, EndingDate);
                if not ValueEntry.IsEmpty() then
                    exit(StrSubstNo(OrderErr, InvtAdjmtEntryOrder."Order Type"));
            until InvtAdjmtEntryOrder.Next() = 0;

        ItemLedgEntry.SetRange(Open, true);
        ItemLedgEntry.SetRange(Positive, false);
        ItemLedgEntry.SetRange("Posting Date", 0D, EndingDate);
        if not ItemLedgEntry.IsEmpty() then
            exit(NegativeErr);
    end;
}
