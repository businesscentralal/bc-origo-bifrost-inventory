namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013477 "Reservation Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        Clear(Parameters);
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'source');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'entryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
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
    begin
        exit(false);
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
    begin
        Overview := 'Reads reservation entries, optionally for one item.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only. Cancel is a separate message type.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        SourceSpecification: Record "Tracking Specification";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Resolver: Codeunit "Inventory Source Resolve ori";
        Reader: Codeunit "Request Value Reader ori";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        EntryNo: Decimal;
        ItemNoText: Text;
        MissingEntryErr: Label 'The reservation entry does not exist.', Comment = 'is-IS=Frátektarfærslan er ekki til.';
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
        if not Resolver.ReadText(Argument, RequestJson, 'itemNo', false, ItemNoText) then
            exit;
        ItemNo := CopyStr(ItemNoText, 1, MaxStrLen(ItemNo));
        if RequestJson.Get('source', Token) then begin
            if not Resolver.Resolve(Argument, RequestJson, 'source', false, SourceRef, SourceSpecification, Direction) then
                exit;
            ReservationEntry.TransferFields(SourceSpecification);
            ReservationEntry.SetPointerFilter();
        end;
        if RequestJson.Get('entryNo', Token) then begin
            if not Reader.TryReadDecimal(Argument, RequestJson, 'entryNo', true, EntryNo) then
                exit;
            if (EntryNo <= 0) or (EntryNo <> Round(EntryNo, 1)) or (EntryNo > 2147483647) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, MissingEntryErr, 'entryNo', Format(EntryNo, 0, 9), 'positive integer', '');
                exit;
            end;
            ReservationEntry.SetRange("Entry No.", EntryNo);
            if ReservationEntry.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingEntryErr, 'entryNo', Format(EntryNo, 0, 9), '', '');
                exit;
            end;
        end;
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
                EntryJson.Add('sourceType', ReservationEntry."Source Type");
                EntryJson.Add('sourceSubtype', ReservationEntry."Source Subtype");
                EntryJson.Add('sourceRefNo', ReservationEntry."Source Ref. No.");
                EntryJson.Add('positive', ReservationEntry.Positive);
                EntryJson.Add('quantityBase', ReservationEntry."Quantity (Base)");
                EntryJson.Add('lotNo', ReservationEntry."Lot No.");
                EntryJson.Add('serialNo', ReservationEntry."Serial No.");
                EntryJson.Add('packageNo', ReservationEntry."Package No.");
                EntryJson.Add('expirationDate', ReservationEntry."Expiration Date");
                Entries.Add(EntryJson);
            until ReservationEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
