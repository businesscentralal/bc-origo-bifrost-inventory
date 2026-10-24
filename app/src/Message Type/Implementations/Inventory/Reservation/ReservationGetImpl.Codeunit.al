namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 10076894 "Reservation Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads reservation entries for an item.', Comment = 'is-IS=Les frátekningarfærslur fyrir vöru.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reservation, reserved quantity', Comment = 'is-IS=frátekning, frátekið magn';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads reservation entries. Cancel is a separate type.', Comment = 'is-IS=Les frátekningarfærslur. Afturköllun er aðskilin tegund.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Forms.Add('item no.');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The No. of the Item whose reservation entries are read; data.itemNo is used when subject is blank, and with neither every reservation entry is read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item; it takes precedence over data.itemNo. A subject and a data.itemNo that name different items are refused.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item, used when subject is blank. Leave both out to read the reservation entries of every item.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoDescriptionTxt: Label 'Item number. The message subject is the same item number when this key is omitted. Without either, every reservation entry is returned.', Comment = 'is-IS=Vörunúmer. Subject er sama vörunúmer þegar lykillinn er ekki sendur. Án beggja eru allar frátekningarfærslur skilaðar.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoDescriptionTxt));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        EntryFields: JsonArray;
        EntriesField: JsonObject;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the reservation entries were read.'));
        EntryFields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number of the reservation entry.'));
        EntryFields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the entry.'));
        EntryFields.Add(ContractMgt.ResponseField('locationCode', 'string', 'The location code of the entry.'));
        EntryFields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The signed quantity of the entry in the unit of the line; positive on the supply side, negative on the demand side.'));
        EntryFields.Add(ContractMgt.ResponseField('reservationStatus', 'string', 'Reservation, Tracking, Surplus or Prospect.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceId', 'string', 'The document number of the source the entry belongs to.'));
        EntriesField := ContractMgt.ResponseField('entries', 'array', 'The reservation entries of the item, or of every item when no item is selected, in entry number order. The array is empty when nothing matches.');
        EntriesField.Add('children', EntryFields);
        Fields.Add(EntriesField);
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Clear(Errors);
        ContractParts.AddItemNoSubjectErrors(Errors, false);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Reservations domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read the Reservation Entry table.');
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. The reservation entries are read as they are; nothing is reserved, cancelled or posted.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Effect.Add('preconditions', Preconditions);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a reservation instead of reading it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Create', 'Create a reservation instead of reading reservations.'));
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
        Examples.Add(ContractMgt.Example(
            'Read the reservation entries of item 1000',
            '{"type":"Inventory.Reservation.Get","subject":"1000"}',
            '{"status":"Success","entries":[{"entryNo":101,"itemNo":"1000","locationCode":"BLUE","quantity":-5,"reservationStatus":"Reservation","sourceId":"101005"}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewTxt: Label 'Reads reservation entries for the item named by data.itemNo or subject, or every entry when both are omitted.', Comment = 'is-IS=Les bókanir fyrir vöruna sem data.itemNo eða subject nefnir, eða allar færslur þegar hvorugt er sent.';
    begin
        Overview := OverviewTxt;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesTxt: Label 'Read only. Cancel is a separate message type. data.itemNo or subject limits the entries to that item.', Comment = 'is-IS=Aðeins lestur. Afpöntun er sérstök skilaboðategund. data.itemNo eða subject takmarkar færslurnar við þá vöru.';
    begin
        Notes := NotesTxt;
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ContractParts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        ItemNo: Code[20];
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ContractParts.TryResolveItemNo(Argument, RequestJson, false, ItemNo) then
            exit;
        if ItemNo <> '' then
            ReservationEntry.SetRange("Item No.", ItemNo);
        if ReservationEntry.FindSet() then
            repeat
                Clear(EntryJson);
                EntryJson.Add('entryNo', ReservationEntry."Entry No.");
                EntryJson.Add('itemNo', ReservationEntry."Item No.");
                EntryJson.Add('locationCode', ReservationEntry."Location Code");
                EntryJson.Add('quantity', ReservationEntry.Quantity);
                EntryJson.Add('reservationStatus', ReservationEntry."Reservation Status".Names().Get(ReservationEntry."Reservation Status".Ordinals().IndexOf(ReservationEntry."Reservation Status".AsInteger())));
                EntryJson.Add('sourceId', ReservationEntry."Source ID");
                Entries.Add(EntryJson);
            until ReservationEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
