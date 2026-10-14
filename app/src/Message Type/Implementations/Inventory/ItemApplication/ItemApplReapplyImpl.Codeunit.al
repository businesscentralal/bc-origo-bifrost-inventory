namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

codeunit 70013492 "Item Appl. Reapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reapplies an exact base quantity between native outbound and inbound item ledger entries.', Comment = 'is-IS=Endurjafnar nákvæmt magn í grunneiningu milli innbyggðra útleiðar- og innleiðarbirgðafærslna.';
        KeywordsLbl: Label 'reapply item application, apply item ledger entry', Comment = 'is-IS=endurjafna jöfnun vöru, jafna birgðafærslu fyrir vöru';
        SelectionDescriptionLbl: Label 'Requires outboundEntryNo, inboundEntryNo and a positive quantity in base units.', Comment = 'is-IS=Krefst outboundEntryNo, inboundEntryNo og jákvæðs quantity í grunneiningum.';
        OverviewLbl: Label 'Uses Item Jnl.-Post Line.ReApply with a pair-scoped native quantity limit and exact result validation.', Comment = 'is-IS=Notar Item Jnl.-Post Line.ReApply með innbyggðri magntakmörkun fyrir færslupar og nákvæmri sannprófun niðurstöðu.';
        NotesLbl: Label 'Preserves native worksheet checks and marks adjustment required. Adjust Cost is a separate operation.', Comment = 'is-IS=Varðveitir innbyggðar athuganir vinnublaðsins og merkir að kostnaðarleiðréttingar sé þörf. Kostnaðarleiðrétting er aðskilin aðgerð.';

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.Add('messageType', 'Inventory.ItemApplication.Reapply');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        Clear(Target);
        TargetJson.Add('codeunit', 'Item Jnl.-Post Line');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('outboundEntryNo', 'integer', false, 'Negative outbound ledger entry; use this pair or the legacy pair.'));
        Parameters.Add(ContractMgt.Parameter('inboundEntryNo', 'integer', false, 'Positive inbound ledger entry; required with outboundEntryNo.'));
        Parameters.Add(ContractMgt.Parameter('quantity', 'decimal', false, 'Positive base quantity required with the canonical pair.'));
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', false, 'Legacy outbound selector; use only with applyToEntryNo.'));
        Parameters.Add(ContractMgt.Parameter('applyToEntryNo', 'integer', false, 'Legacy inbound selector; cannot be mixed with the canonical pair.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Response.Add('status', 'Success');
        Response.Add('outboundEntryNo', 0);
        Response.Add('inboundEntryNo', 0);
        Response.Add('quantity', 0);
        Response.Add('adjustmentRequired', true);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after native reapplication.'));
        Fields.Add(ContractMgt.ResponseField('outboundEntryNo', 'integer', 'Selected negative outbound ledger entry.'));
        Fields.Add(ContractMgt.ResponseField('inboundEntryNo', 'integer', 'Selected positive inbound ledger entry.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Exact applied base quantity.'));
        Fields.Add(ContractMgt.ResponseField('adjustmentRequired', 'boolean', 'True; Adjust Cost remains a separate operation.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.TextErrorEntry('Native application validation error.', 'Missing, conflicting or invalid selectors or quantity, wrong entry signs, item mismatch, unavailable or reserved quantity, or native worksheet refusal.', 'Select eligible matching entries and a valid base quantity; failed writes are rolled back.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Required Inventory, table or posting permission is missing.', 'Request the required permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The company Inventory domain is disabled.', 'Enable the domain from Inventory Setup.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('writes', 'Item Application Entry');
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Unapply the item ledger entry instead of reapplying it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Read the item application before reapplying it.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv Application Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv Application Process ori", Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
