namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>Unapplies selected item applications using the native worksheet path.</summary>
codeunit 10076869 "Item Appl. Unapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks availability.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false));
    end;

    /// <summary>Returns the filtertableno contract chapter.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    /// <summary>Returns the description contract chapter.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Unapplies an item application entry through standard item application posting.', Comment = 'is-IS=Afturkallar vörujöfnun með hefðbundinni vörujöfnun.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the keywords contract chapter.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'unapply item application, undo application', Comment = 'is-IS=afturkalla vörujöfnun, afturkalla jöfnun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the selectiondescription contract chapter.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Unapplies linked item applications by ledger entry, or one application by entryNo.', Comment = 'is-IS=Afturkallar tengdar vörujafnanir eftir vörufærslu eða eina jöfnun eftir entryNo.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read; the entries are named in data."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.itemLedgerEntryNo', 'entry no.', 'The ledger entry whose real applications are unapplied.'));
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'entry no.', 'The Entry No. of the item application entry to unapply.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Help401Lbl: Label 'Unapply the real applications linked to this item ledger entry atomically. Send this or the legacy single-application entryNo, not both.', Comment = 'is-IS=Afturkallar allar raunverulegar jafnanir tengdar þessari vörufærslu í einni færslu. Sendu þetta eða eldra entryNo fyrir eina jöfnun, ekki bæði.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', false, 'The Entry No. of the item application entry to unapply, sent as a JSON integer. It is the entryNo that Inventory.ItemApplication.Get lists, not an item ledger entry number.'));
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', false, Help401Lbl));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The Entry No. of the item application entry that was removed.'));
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry the removed application entry was recorded under.'));
        Fields.Add(ContractMgt.ResponseField('applicationCount', 'integer', 'Number of real applications removed by the native operation.'));
        Fields.Add(ContractMgt.ResponseField('inboundItemEntryNo', 'integer', 'The inbound item ledger entry of the removed application entry.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ErrorHelp1Lbl: Label 'The Item Application domain is turned off in Inventory Setup.', Comment = 'is-IS=Slökkt er á vörujöfnun í birgðauppsetningu.';
        ErrorHelp2Lbl: Label 'Turn on the Item Application domain in Inventory Setup.', Comment = 'is-IS=Kveiktu á vörujöfnun í birgðauppsetningu.';
        ErrorHelp3Lbl: Label 'The caller has no write permission on item application entries.', Comment = 'is-IS=Kallandi hefur ekki skrifheimild á vörujöfnunarfærslum.';
        ErrorHelp4Lbl: Label 'Request the permission from an administrator.', Comment = 'is-IS=Biddu stjórnanda um heimildina.';
        ErrorHelp5Lbl: Label 'A required entry number is absent.', Comment = 'is-IS=Nauðsynlegt færslunúmer vantar.';
        ErrorHelp6Lbl: Label 'Send the documented entry number parameters.', Comment = 'is-IS=Sendu skjalfestar færslunúmerabreytur.';
        ErrorHelp7Lbl: Label 'An entry number is not a JSON integer.', Comment = 'is-IS=Færslunúmer er ekki JSON-heiltala.';
        ErrorHelp8Lbl: Label 'Send entry numbers as JSON integers.', Comment = 'is-IS=Sendu færslunúmer sem JSON-heiltölur.';
        ErrorHelp9Lbl: Label 'The selected entry does not exist.', Comment = 'is-IS=Valin færsla er ekki til.';
        ErrorHelp10Lbl: Label 'Read Inventory.ItemApplication.Get and select an existing entry.', Comment = 'is-IS=Lestu Inventory.ItemApplication.Get og veldu fyrirliggjandi færslu.';
        ErrorHelp11Lbl: Label 'Business Central refuses the application change.', Comment = 'is-IS=Business Central hafnar breytingu á jöfnun.';
        ErrorHelp12Lbl: Label 'Correct the application according to the native refusal and retry.', Comment = 'is-IS=Leiðréttu jöfnunina samkvæmt villuboðum kerfisins og reyndu aftur.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp1Lbl, ErrorHelp2Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorHelp3Lbl, ErrorHelp4Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorHelp5Lbl, ErrorHelp6Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ErrorHelp7Lbl, ErrorHelp8Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorHelp9Lbl, ErrorHelp10Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ErrorHelp11Lbl, ErrorHelp12Lbl));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Removes the selected real item applications with the standard unapply logic: the application row is deleted and kept in the application history, and the remaining quantities of the two item ledger entries are corrected. Item costs can need a new adjustment run. No document is posted. Business Central commits the change when the call finishes.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('The Item Application domain is turned on in Inventory Setup.');
        Preconditions.Add('The item application entry exists and its posting date is in an open inventory period.');
        Preconditions.Add('The application is not to an outbound transfer and not a drop shipment.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Returns the metering contract chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Use it to find the entryNo of the application entry before unapplying it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Reapply', 'Use it to apply the item ledger entry to another entry after unapplying it.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Get', 'Read the application entries and take the entryNo of the one to remove.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Unapply', 'Remove that application entry.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Reapply', 'Apply the item ledger entry to the entry it should be applied to.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Unapply item application entry 25',
            '{"type":"Inventory.ItemApplication.Unapply","data":{"entryNo":25}}',
            '{"status":"Success","entryNo":25,"itemLedgerEntryNo":12,"inboundItemEntryNo":3}'));
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Removes one item application entry with the standard unapply logic. It posts no document, and Business Central commits the change.';
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Send itemLedgerEntryNo to unapply every real application linked to that ledger entry in one transaction. Alternatively, legacy entryNo removes one application. Do not send both. Inbound self-applications cannot be unapplied. Native worksheet rules reject closed periods, transfers, drop shipments and other unsupported changes. A native refusal returns BusinessCentralError and rolls back the entire operation. The item and ledger entries remain marked for adjustment; run Inventory.AdjustCost.Run separately. No document is posted.', Comment = 'is-IS=Sendu itemLedgerEntryNo til að afturkalla allar raunverulegar jafnanir tengdar vörufærslunni í einni gagnagrunnsfærslu. Eldra entryNo afturkallar eina jöfnun. Ekki senda bæði. Ekki er hægt að afturkalla sjálfsjöfnun innleiðandi færslu. Staðlaðar reglur jöfnunarvinnublaðs hafna lokuðum tímabilum, flutningum, beinum afhendingum og öðrum óstuddum breytingum. Kerfishöfnun skilar BusinessCentralError og afturkallar alla aðgerðina. Vara og vörufærslur eru merktar til leiðréttingar; keyrðu Inventory.AdjustCost.Run sérstaklega. Ekkert skjal er bókað.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the messagedirection contract chapter.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Executes the item application request.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemApplicationEntry: Record "Item Application Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Inventory Write Process ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        EntryNo: Integer;
        ItemLedgerEntryNo: Integer;
        ApplicationCount: Integer;
        NotFoundErr: Label 'Item application entry %1 was not found.', Comment = '%1 = entry no., is-IS=Vörujöfnunarfærsla %1 fannst ekki.';
        ExpectedLbl: Label 'an existing item application or item ledger entry', Comment = 'is-IS=fyrirliggjandi vörujöfnunarfærsla eða vörufærsla';
        NextLbl: Label 'Read Inventory.ItemApplication.Get and send the entry number of an existing record.', Comment = 'is-IS=Lestu Inventory.ItemApplication.Get og sendu færslunúmer fyrirliggjandi færslu.';
        SelectorErr: Label 'Send either itemLedgerEntryNo or entryNo, not both.', Comment = 'is-IS=Sendu annaðhvort itemLedgerEntryNo eða entryNo, ekki bæði.';
        NativeNextLbl: Label 'Correct the item application according to the Business Central refusal and retry.', Comment = 'is-IS=Leiðréttu vörujöfnunina samkvæmt höfnun Business Central og reyndu aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Contains('itemLedgerEntryNo') then begin
            if RequestJson.Contains('entryNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SelectorErr, 'itemLedgerEntryNo', '', ExpectedLbl, NextLbl);
                exit;
            end;
            if not Parts.TryReadEntryNo(RequestJson, 'itemLedgerEntryNo', Argument, ItemLedgerEntryNo) then
                exit;
            if ItemLedgerEntryNo > 0 then begin
                ItemApplicationEntry.FilterGroup(-1);
                ItemApplicationEntry.SetRange("Inbound Item Entry No.", ItemLedgerEntryNo);
                ItemApplicationEntry.SetRange("Outbound Item Entry No.", ItemLedgerEntryNo);
                ItemApplicationEntry.FilterGroup(0);
                ItemApplicationEntry.SetFilter("Outbound Item Entry No.", '<>0');
                if ItemApplicationEntry.FindFirst() then begin
                    EntryNo := ItemApplicationEntry."Entry No.";
                    ApplicationCount := ItemApplicationEntry.Count();
                end;
            end;
        end else begin
            if not Parts.TryReadEntryNo(RequestJson, 'entryNo', Argument, EntryNo) then
                exit;
            ApplicationCount := 1;
        end;
        if not ItemApplicationEntry.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, Format(EntryNo, 0, 9)), 'entryNo', Format(EntryNo, 0, 9), ExpectedLbl, NextLbl);
            exit;
        end;

        Argument.SetErrorContext('entryNo', ExpectedLbl, NativeNextLbl);
        Process.SetOperation('ItemApplicationUnapply');
        Process.SetApplicationEntries(EntryNo, 0);
        if RequestJson.Contains('itemLedgerEntryNo') then
            Process.SetApplicationLedger(ItemLedgerEntryNo);
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        if ItemLedgerEntryNo <> 0 then
            ResponseJson.Add('itemLedgerEntryNo', ItemLedgerEntryNo)
        else
            ResponseJson.Add('itemLedgerEntryNo', ItemApplicationEntry."Item Ledger Entry No.");
        ResponseJson.Add('inboundItemEntryNo', ItemApplicationEntry."Inbound Item Entry No.");
        ResponseJson.Add('applicationCount', ApplicationCount);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
