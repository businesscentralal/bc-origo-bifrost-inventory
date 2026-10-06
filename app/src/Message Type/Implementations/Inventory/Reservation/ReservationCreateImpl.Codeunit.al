namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013531 "Reservation Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Creates a reservation through Reservation Management.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('create reservation, auto reserve, reserve item');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reserves quantity for an item through Reservation Management.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.Create');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Reservation Management');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'quantity');
        ParameterJson.Add('type', 'decimal');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'locationCode');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('reserved', true);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'itemNo or quantity is missing');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Reservation Entry');
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('Inventory.Reservation.Get');
        Related.Add('Inventory.Reservation.Cancel');
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
        Overview := 'Calls Reservation Management.AutoReserveOneLineReserve for the requested item quantity.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Source document fields can be added by the compiler pass if AutoReserve needs a source record.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ReservationManagement: Codeunit "Reservation Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        LocationCode: Code[10];
        Quantity: Decimal;
        FullAutoReservation: Boolean;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError('itemNo is required.');
            exit;
        end;
        ItemNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ItemNo));
        if not RequestJson.Get('quantity', Token) then begin
            Argument.RespondWithError('quantity is required.');
            exit;
        end;
        Quantity := Token.AsValue().AsDecimal();
        if RequestJson.Get('locationCode', Token) then
            LocationCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(LocationCode));

        ReservationEntry.Init();
        ReservationEntry."Item No." := ItemNo;
        ReservationEntry."Location Code" := LocationCode;
        ReservationEntry.Quantity := Quantity;
        ReservationEntry."Quantity (Base)" := Quantity;
        ReservationEntry.Positive := Quantity > 0;
        ReservationManagement.SetReservSource(ReservationEntry);
        ReservationManagement.AutoReserveOneLineReserve(FullAutoReservation, ItemNo, WorkDate(), Quantity, Quantity);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('quantity', Quantity);
        ResponseJson.Add('fullAutoReservation', FullAutoReservation);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
