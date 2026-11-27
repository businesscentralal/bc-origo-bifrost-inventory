namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Get. Reads Item Application Entry.
/// </summary>
codeunit 10076867 "Item Appl. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks availability.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false) and
            DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Ledger Entry", false, false));
    end;

    /// <summary>Returns the filtertableno contract chapter.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    /// <summary>Returns the description contract chapter.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads item applications and joined ledger entries by item or ledger entry.', Comment = 'is-IS=Les vörujafnanir og tengdar vörufærslur eftir vöru eða færslu. (vörujöfnun, jafnaðar færslur).';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the keywords contract chapter.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item application, applied entries', Comment = 'is-IS=vörujöfnun, jafnaðar færslur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the selectiondescription contract chapter.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads application entries. Unapply and reapply are separate types.', Comment = 'is-IS=Les jöfnunarfærslur. Afturköllun og endurjöfnun eru aðskildar tegundir.';
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
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The item whose application entries are listed.'));
        Target.Add(ContractMgt.TargetEntry('data.itemLedgerEntryNo', 'entry no.', 'The Entry No. of the item ledger entry whose application entries are listed.'));
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Help401Lbl: Label 'Item number. Send itemNo or itemLedgerEntryNo; when both are sent they must both match.', Comment = 'is-IS=Vörunúmer. Sendu itemNo eða itemLedgerEntryNo; ef bæði eru send verða bæði að passa.';
        Help402Lbl: Label 'Optional exact location on the selected ledger entry; an empty string selects the blank location.', Comment = 'is-IS=Valfrjáls nákvæm birgðageymsla á valinni vörufærslu; tómur strengur velur auða birgðageymslu.';
        Help403Lbl: Label 'Optional exact variant on the selected ledger entry; an empty string selects the blank variant.', Comment = 'is-IS=Valfrjálst nákvæmt afbrigði á valinni vörufærslu; tómur strengur velur autt afbrigði.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', false, 'The Entry No. of an item ledger entry, sent as a JSON integer. An entry number that does not exist gives an empty list, not an error.'));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, Help401Lbl));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, Help402Lbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, Help403Lbl));
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Entries: JsonObject;
        Children: JsonArray;
        Help404Lbl: Label 'Joined inbound item ledger entry: entryNo, itemNo, locationCode, variantCode, quantity, remainingQuantity and positive. Empty if there is no entry.', Comment = 'is-IS=Tengd innleiðandi vörufærsla: entryNo, itemNo, locationCode, variantCode, quantity, remainingQuantity og positive. Tómt ef engin færsla er til.';
        Help405Lbl: Label 'Joined outbound item ledger entry with the same fields. Empty if there is no outbound entry.', Comment = 'is-IS=Tengd útleiðandi vörufærsla með sömu reitum. Tómt ef engin útleiðandi færsla er til.';
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry number that was asked for.'));
        Children.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The Entry No. of the item application entry; use it as entryNo in Inventory.ItemApplication.Unapply.'));
        Children.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry the application entry is recorded under.'));
        Children.Add(ContractMgt.ResponseField('inboundItemEntryNo', 'integer', 'The inbound item ledger entry of the application.'));
        Children.Add(ContractMgt.ResponseField('outboundItemEntryNo', 'integer', 'The outbound item ledger entry of the application; 0 when there is none.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The applied quantity of the application entry.'));
        Children.Add(ContractMgt.ResponseField('inboundEntry', 'object', Help404Lbl));
        Children.Add(ContractMgt.ResponseField('outboundEntry', 'object', Help405Lbl));
        Entries := ContractMgt.ResponseField('entries', 'array', 'The distinct applications linked to matching item ledger entries; empty when there are none.');
        Entries.Add('children', Children);
        Fields.Add(Entries);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ErrorHelp1Lbl: Label 'itemLedgerEntryNo is not sent.', Comment = 'is-IS=itemLedgerEntryNo vantar.';
        ErrorHelp2Lbl: Label 'Send the Entry No. of the item ledger entry in data.itemLedgerEntryNo.', Comment = 'is-IS=Sendu færslunúmer vörufærslunnar í data.itemLedgerEntryNo.';
        ErrorHelp3Lbl: Label 'The Item Application domain is turned off in Inventory Setup.', Comment = 'is-IS=Slökkt er á vörujöfnun í birgðauppsetningu.';
        ErrorHelp4Lbl: Label 'Turn on the Item Application domain in Inventory Setup.', Comment = 'is-IS=Kveiktu á vörujöfnun í birgðauppsetningu.';
        ErrorHelp5Lbl: Label 'The caller cannot read item application entries.', Comment = 'is-IS=Kallandi getur ekki lesið vörujöfnunarfærslur.';
        ErrorHelp6Lbl: Label 'Request read permission on item application entries from an administrator.', Comment = 'is-IS=Biddu stjórnanda um lesheimild á vörujöfnunarfærslum.';
        ErrorHelp7Lbl: Label 'itemLedgerEntryNo is not a JSON integer.', Comment = 'is-IS=itemLedgerEntryNo er ekki JSON-heiltala.';
        ErrorHelp8Lbl: Label 'Send the entry number as a JSON integer.', Comment = 'is-IS=Sendu færslunúmerið sem JSON-heiltölu.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorHelp1Lbl, ErrorHelp2Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp3Lbl, ErrorHelp4Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorHelp5Lbl, ErrorHelp6Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp7Lbl, ErrorHelp8Lbl));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. Lists applications linked to matching item ledger entries, with both joined entries.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Item Application domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read item application entries.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Use it to remove one application entry that this type listed; this type changes nothing.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Reapply', 'Use it to apply an item ledger entry to another entry; this type changes nothing.'));
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'List the application entries recorded under item ledger entry 12',
            '{"type":"Inventory.ItemApplication.Get","data":{"itemLedgerEntryNo":12}}',
            '{"status":"Success","itemLedgerEntryNo":12,"entries":[{"entryNo":25,"itemLedgerEntryNo":12,"inboundItemEntryNo":3,"outboundItemEntryNo":12,"quantity":-5}]}'));
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Lists item applications and their inbound and outbound ledger entries. Select itemNo or itemLedgerEntryNo, optionally locationCode and variantCode. It reads only.';
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Send itemNo or itemLedgerEntryNo. Optional locationCode and variantCode are exact filters on the selected ledger entry; empty strings select blank codes. Applications recorded under or linked to a matching entry are returned once, with both joined entries. Missing matches return an empty list. Use itemLedgerEntryNo to unapply linked real applications, or entryNo for one legacy application. Native read permissions and the Item Application domain are required.', Comment = 'is-IS=Sendu itemNo eða itemLedgerEntryNo. Valfrjáls locationCode og variantCode eru nákvæmar síur á valinni vörufærslu; tómir strengir velja auða kóða. Jafnanir skráðar á eða tengdar samsvarandi færslu koma einu sinni fyrir ásamt báðum tengdum færslum. Ef ekkert passar fæst tómur listi. Notaðu itemLedgerEntryNo til að afturkalla tengdar raunverulegar jafnanir eða entryNo fyrir eina eldri jöfnun. Lesheimildir og virkt vörujöfnunarsvið eru nauðsynleg.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the messagedirection contract chapter.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Reads applications of matching ledger entries without changing inventory.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        TempApplications: Record "Item Application Entry" temporary;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        Token: JsonToken;
        ItemLedgerEntryNo: Integer;
        ItemNo: Text;
        LocationCode: Text;
        VariantCode: Text;
        MissingEntryErr: Label 'itemLedgerEntryNo is required.', Comment = 'is-IS=itemLedgerEntryNo er nauðsynlegt.';
        NotIntegerErr: Label 'itemLedgerEntryNo must be a JSON integer.', Comment = 'is-IS=itemLedgerEntryNo verður að vera JSON heiltala.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Ledger Entry", false, false) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        ItemNo := Parts.ReadRequestText(RequestJson, 'itemNo', Argument, false, 20);
        LocationCode := Parts.ReadRequestText(RequestJson, 'locationCode', Argument, false, 10);
        VariantCode := Parts.ReadRequestText(RequestJson, 'variantCode', Argument, false, 10);
        if Parts.RespondToProblems(Argument) then
            exit;
        if not RequestJson.Contains('itemLedgerEntryNo') and (ItemNo = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingEntryErr, 'itemLedgerEntryNo', '', '', '');
            exit;
        end;
        Ledger.ReadIsolation := IsolationLevel::ReadCommitted;
        Ledger.SetLoadFields("Entry No.", "Item No.", "Location Code", "Variant Code");
        if RequestJson.Get('itemLedgerEntryNo', Token) then begin
            if not TryReadEntryNo(Token, ItemLedgerEntryNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, NotIntegerErr, 'itemLedgerEntryNo', '', 'integer', '');
                exit;
            end;
            Ledger.SetRange("Entry No.", ItemLedgerEntryNo);
        end;
        if ItemNo <> '' then
            Ledger.SetRange("Item No.", ItemNo);
        if RequestJson.Contains('locationCode') then
            Ledger.SetRange("Location Code", LocationCode);
        if RequestJson.Contains('variantCode') then
            Ledger.SetRange("Variant Code", VariantCode);
        Application.ReadIsolation := IsolationLevel::ReadCommitted;
        if Ledger.FindSet() then
            repeat
                Application.FilterGroup(-1);
                Application.SetRange("Item Ledger Entry No.", Ledger."Entry No.");
                Application.SetRange("Inbound Item Entry No.", Ledger."Entry No.");
                Application.SetRange("Outbound Item Entry No.", Ledger."Entry No.");
                if Application.FindSet() then
                    repeat
                        if not TempApplications.Get(Application."Entry No.") then begin
                            TempApplications := Application;
                            TempApplications.Insert();
                        end;
                    until Application.Next() = 0;
            until Ledger.Next() = 0;
        if TempApplications.FindSet() then
            repeat
                Clear(EntryJson);
                EntryJson.Add('entryNo', TempApplications."Entry No.");
                EntryJson.Add('itemLedgerEntryNo', TempApplications."Item Ledger Entry No.");
                EntryJson.Add('inboundItemEntryNo', TempApplications."Inbound Item Entry No.");
                EntryJson.Add('outboundItemEntryNo', TempApplications."Outbound Item Entry No.");
                EntryJson.Add('quantity', TempApplications.Quantity);
                EntryJson.Add('inboundEntry', LedgerJson(TempApplications."Inbound Item Entry No."));
                EntryJson.Add('outboundEntry', LedgerJson(TempApplications."Outbound Item Entry No."));
                Entries.Add(EntryJson);
            until TempApplications.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemLedgerEntryNo', ItemLedgerEntryNo);
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure LedgerJson(EntryNo: Integer) Result: JsonObject
    var
        Ledger: Record "Item Ledger Entry";
    begin
        Ledger.ReadIsolation := IsolationLevel::ReadCommitted;
        if (EntryNo = 0) or not Ledger.Get(EntryNo) then
            exit(Result);
        Result.Add('entryNo', Ledger."Entry No.");
        Result.Add('itemNo', Ledger."Item No.");
        Result.Add('locationCode', Ledger."Location Code");
        Result.Add('variantCode', Ledger."Variant Code");
        Result.Add('quantity', Ledger.Quantity);
        Result.Add('remainingQuantity', Ledger."Remaining Quantity");
        Result.Add('positive', Ledger.Positive);
    end;

    [TryFunction]
    local procedure TryReadEntryNo(Token: JsonToken; var ItemLedgerEntryNo: Integer)
    begin
        ItemLedgerEntryNo := Token.AsValue().AsInteger();
    end;
}
