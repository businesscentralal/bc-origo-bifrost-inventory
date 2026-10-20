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
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Reservation Entry');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
        ItemNoDescriptionTxt: Label 'Item number. The message subject is the same item number when this key is omitted. Without either, every reservation entry is returned.', Comment = 'is-IS=Vörunúmer. Subject er sama vörunúmer þegar lykillinn er ekki sendur. Án hvors tveggja koma allar bókanir.';
    begin
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', ItemNoDescriptionTxt);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('entries', 'array');
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
    begin
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
    begin
        exit(false);
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
                EntryJson.Add('reservationStatus', Format(ReservationEntry."Reservation Status"));
                EntryJson.Add('sourceId', ReservationEntry."Source ID");
                Entries.Add(EntryJson);
            until ReservationEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
