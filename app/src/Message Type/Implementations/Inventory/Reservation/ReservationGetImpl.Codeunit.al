namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013490 "Reservation Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Reads reservation entries for an item.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('reservation, reserved quantity');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reads reservation entries. Cancel is a separate type.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
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
    begin
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('itemNo', Token) then
            ItemNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(ItemNo));
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
