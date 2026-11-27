namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>Reapplies item ledger entries using the native worksheet path.</summary>
codeunit 10076868 "Item Appl. Reapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Reapplies an item ledger entry through standard item application posting.', Comment = 'is-IS=Jafnar vörufærslu aftur með hefðbundinni vörujöfnun. (jafna vöru aftur, jafna vörufærslu).';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the keywords contract chapter.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reapply item application, apply item ledger entry', Comment = 'is-IS=jafna vöru aftur, jafna vörufærslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the selectiondescription contract chapter.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reapplies an outbound item ledger entry to an inbound entry.', Comment = 'is-IS=Jafnar útleiðandi vörufærslu aftur við innleiðandi færslu.';
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
        Target.Add(ContractMgt.TargetEntry('data.outboundEntryNo', 'entry no.', 'The negative item ledger entry to apply for the requested quantity.'));
        Target.Add(ContractMgt.TargetEntry('data.inboundEntryNo', 'entry no.', 'The positive item ledger entry to apply against.'));
        Target.Add(ContractMgt.TargetEntry('data.itemLedgerEntryNo', 'entry no.', 'The Entry No. of the item ledger entry that is reapplied.'));
        Target.Add(ContractMgt.TargetEntry('data.applyToEntryNo', 'entry no.', 'The Entry No. of the item ledger entry it is applied to.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Help401Lbl: Label 'Negative item ledger entry. Use with inboundEntryNo and quantity; legacy itemLedgerEntryNo/applyToEntryNo remain supported.', Comment = 'is-IS=Neikvæð vörufærsla. Notaðu með inboundEntryNo og quantity; eldri itemLedgerEntryNo/applyToEntryNo eru enn studd.';
        Help402Lbl: Label 'Positive item ledger entry of the same item, location and variant.', Comment = 'is-IS=Jákvæð vörufærsla fyrir sömu vöru, birgðageymslu og afbrigði.';
        Help403Lbl: Label 'Positive quantity in base units, required with outboundEntryNo/inboundEntryNo. Must be available on both entries; the exact quantity is applied or the entire change is rolled back.', Comment = 'is-IS=Jákvætt magn í grunneiningum, nauðsynlegt með outboundEntryNo/inboundEntryNo. Verður að vera tiltækt á báðum færslum; nákvæmlega þetta magn er jafnað eða breytingin öll afturkölluð.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', false, 'The Entry No. of the item ledger entry to reapply, sent as a JSON integer.'));
        Parameters.Add(ContractMgt.Parameter('applyToEntryNo', 'integer', false, 'The Entry No. of the item ledger entry to apply it to, sent as a JSON integer.'));
        Parameters.Add(ContractMgt.Parameter('outboundEntryNo', 'integer', false, Help401Lbl));
        Parameters.Add(ContractMgt.Parameter('inboundEntryNo', 'integer', false, Help402Lbl));
        Parameters.Add(ContractMgt.Parameter('quantity', 'decimal', false, Help403Lbl));
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
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry that was reapplied.'));
        Fields.Add(ContractMgt.ResponseField('applyToEntryNo', 'integer', 'The item ledger entry it was applied to.'));
        Fields.Add(ContractMgt.ResponseField('outboundEntryNo', 'integer', 'Present when quantity was supplied: the negative ledger entry.'));
        Fields.Add(ContractMgt.ResponseField('inboundEntryNo', 'integer', 'Present when quantity was supplied: the positive ledger entry.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Present when quantity was supplied: exact applied base quantity.'));
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
        Effect.Add('changes', 'Applies one item ledger entry to another with the standard item application logic: item application entries and the remaining quantities of the two entries change, and item costs can need a new adjustment run. No document is posted. Business Central commits the change when the call finishes.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('The Item Application domain is turned on in Inventory Setup.');
        Preconditions.Add('Both item ledger entries exist.');
        Preconditions.Add('The posting date of the entry is in an open inventory period.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Use it to remove an existing application entry; this type applies an entry to another one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Use it to read the application entries of an item ledger entry before reapplying it.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Get', 'Read the application entries of the item ledger entry.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Unapply', 'Remove the application entry that should go.'));
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
            'Apply item ledger entry 45 to entry 12',
            '{"type":"Inventory.ItemApplication.Reapply","data":{"itemLedgerEntryNo":45,"applyToEntryNo":12}}',
            '{"status":"Success","itemLedgerEntryNo":45,"applyToEntryNo":12}'));
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Applies one item ledger entry to another with the standard item application logic. It posts no document, and Business Central commits the change.';
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Send outboundEntryNo, inboundEntryNo and positive quantity in base units. The entries must be negative and positive respectively, for the same item, variant and location, with enough unreserved remaining quantity. The native worksheet path applies exactly that quantity or rolls back. Legacy itemLedgerEntryNo/applyToEntryNo still apply the native remaining quantity when quantity is absent. Do not mix the two selector forms. Missing keys return MissingParameter, invalid formats return InvalidParameterFormat, missing entries return RecordNotFound and native refusals return BusinessCentralError. Item costs remain pending adjustment; run Inventory.AdjustCost.Run separately. No document is posted.', Comment = 'is-IS=Sendu outboundEntryNo, inboundEntryNo og jákvætt quantity í grunneiningum. Færslurnar verða að vera neikvæð og jákvæð í þeirri röð, fyrir sömu vöru, afbrigði og birgðageymslu, með nægu ófráteknu eftirstandandi magni. Stöðluð jöfnun jafnar nákvæmlega þetta magn eða afturkallar aðgerðina. Eldri itemLedgerEntryNo/applyToEntryNo jafna enn eftirstandandi magn samkvæmt kerfinu þegar quantity vantar. Ekki blanda valsniðunum. Vantaðir lyklar skila MissingParameter, rangt snið InvalidParameterFormat, vantaðar færslur RecordNotFound og kerfishöfnun BusinessCentralError. Vörukostnaður bíður leiðréttingar; keyrðu Inventory.AdjustCost.Run sérstaklega. Ekkert skjal er bókað.';
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
        ItemLedgerEntry: Record "Item Ledger Entry";
        ApplyToItemLedgerEntry: Record "Item Ledger Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Inventory Write Process ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemLedgerEntryNo: Integer;
        ApplyToEntryNo: Integer;
        Quantity: Decimal;
        HasQuantity: Boolean;
        OutboundParameter: Text;
        InboundParameter: Text;
        EntryNotFoundErr: Label 'Item ledger entry %1 was not found.', Comment = '%1 = entry no., is-IS=Vörufærsla %1 fannst ekki.';
        ExpectedLbl: Label 'an existing item application or item ledger entry', Comment = 'is-IS=fyrirliggjandi vörujöfnunarfærsla eða vörufærsla';
        NextLbl: Label 'Read Inventory.ItemApplication.Get and send the entry number of an existing record.', Comment = 'is-IS=Lestu Inventory.ItemApplication.Get og sendu færslunúmer fyrirliggjandi færslu.';
        NativeNextLbl: Label 'Correct the item application according to the Business Central refusal and retry.', Comment = 'is-IS=Leiðréttu vörujöfnunina samkvæmt höfnun Business Central og reyndu aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ReadSelection(RequestJson, Argument, ItemLedgerEntryNo, ApplyToEntryNo, Quantity, HasQuantity) then
            exit;
        OutboundParameter := 'itemLedgerEntryNo';
        InboundParameter := 'applyToEntryNo';
        if RequestJson.Contains('outboundEntryNo') then begin
            OutboundParameter := 'outboundEntryNo';
            InboundParameter := 'inboundEntryNo';
        end;
        if not ItemLedgerEntry.Get(ItemLedgerEntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, Format(ItemLedgerEntryNo, 0, 9)), OutboundParameter, Format(ItemLedgerEntryNo, 0, 9), ExpectedLbl, NextLbl);
            exit;
        end;
        if not ApplyToItemLedgerEntry.Get(ApplyToEntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, Format(ApplyToEntryNo, 0, 9)), InboundParameter, Format(ApplyToEntryNo, 0, 9), ExpectedLbl, NextLbl);
            exit;
        end;

        Argument.SetErrorContext(OutboundParameter, ExpectedLbl, NativeNextLbl);
        Process.SetOperation('ItemApplicationReapply');
        Process.SetApplicationEntries(ItemLedgerEntryNo, ApplyToEntryNo);
        if HasQuantity then
            Process.SetApplicationQuantity(Quantity);
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemLedgerEntryNo', ItemLedgerEntryNo);
        ResponseJson.Add('applyToEntryNo', ApplyToEntryNo);
        if HasQuantity then begin
            ResponseJson.Add('outboundEntryNo', ItemLedgerEntryNo);
            ResponseJson.Add('inboundEntryNo', ApplyToEntryNo);
            ResponseJson.Add('quantity', Quantity);
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadSelection(Request: JsonObject; var Argument: Record "Message Argument ori"; var OutboundEntryNo: Integer; var InboundEntryNo: Integer; var Quantity: Decimal; var HasQuantity: Boolean): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        Token: JsonToken;
        Serialized: Text;
        Canonical: Boolean;
        SelectionErr: Label 'Send outboundEntryNo, inboundEntryNo and quantity together, or the legacy entry numbers.', Comment = 'is-IS=Sendu outboundEntryNo, inboundEntryNo og quantity saman, eða eldri færslunúmerin.';
        QuantityErr: Label 'quantity must be a positive JSON number in base units.', Comment = 'is-IS=quantity verður að vera jákvæð JSON-tala í grunneiningum.';
        NextLbl: Label 'Read Inventory.ItemApplication.Get and select matching positive and negative entries with enough remaining quantity.', Comment = 'is-IS=Lestu Inventory.ItemApplication.Get og veldu samsvarandi jákvæða og neikvæða færslu með nægu eftirstandandi magni.';
    begin
        Canonical := Request.Contains('outboundEntryNo') or Request.Contains('inboundEntryNo');
        if Canonical then begin
            if Request.Contains('itemLedgerEntryNo') or Request.Contains('applyToEntryNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SelectionErr, 'outboundEntryNo', '', SelectionErr, NextLbl);
                exit(false);
            end;
            if not Parts.TryReadEntryNo(Request, 'outboundEntryNo', Argument, OutboundEntryNo) then
                exit(false);
            if not Parts.TryReadEntryNo(Request, 'inboundEntryNo', Argument, InboundEntryNo) then
                exit(false);
        end else begin
            if not Parts.TryReadEntryNo(Request, 'itemLedgerEntryNo', Argument, OutboundEntryNo) then
                exit(false);
            if not Parts.TryReadEntryNo(Request, 'applyToEntryNo', Argument, InboundEntryNo) then
                exit(false);
        end;
        HasQuantity := Request.Get('quantity', Token);
        if Canonical and not HasQuantity then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, QuantityErr, 'quantity', '', QuantityErr, NextLbl);
            exit(false);
        end;
        if HasQuantity then begin
            Token.WriteTo(Serialized);
            if not Token.IsValue() or (DelChr(Serialized, '=', '-+0123456789.eE') <> '') or not Evaluate(Quantity, Serialized, 9) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, QuantityErr, 'quantity', Serialized, QuantityErr, NextLbl);
                exit(false);
            end;
            if Quantity <= 0 then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, QuantityErr, 'quantity', Serialized, QuantityErr, NextLbl);
                exit(false);
            end;
        end;
        exit(true);
    end;
}
