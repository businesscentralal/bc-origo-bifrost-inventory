namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>Executes one owned request in a real background session through native application/reservation processes.</summary>
codeunit 96991 "Inv Contention Worker"
{
    TableNo = "Inv Contention Probe";

    trigger OnRun()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inv Contention Observer";
        Request: JsonObject;
        Source: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Serialized: Text;
        NativeError: Text;
        Succeeded: Boolean;
        Remaining: Duration;
    begin
        Rec.Get(Rec.Id);
        Rec.TestField(State, Rec.State::Ready);
        Remaining := Rec."Release At" - CurrentDateTime();
        if Remaining > 0 then
            Sleep(Remaining);
        Rec.State := Rec.State::Running;
        Rec."Session Id" := SessionId();
        Rec."Started At" := CurrentDateTime();
        Rec.Modify();
        Commit();
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        if Rec.Scenario = Rec.Scenario::Reservation then begin
            TempArgument.Type := "Message Type ori"::"Inventory.Reservation.Create";
            Source.Add('type', 'SalesLine');
            Source.Add('systemId', Rec."Source Id");
            Request.Add('source', Source);
            Request.Add('itemLedgerEntryNo', Rec."Inbound Entry No.");
        end else begin
            TempArgument.Type := "Message Type ori"::"Inventory.ItemApplication.Reapply";
            Request.Add('outboundEntryNo', Rec."Outbound Entry No.");
            Request.Add('inboundEntryNo', Rec."Inbound Entry No.");
        end;
        Request.Add('quantity', Rec.Quantity);
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        Observer.SetFixture(Rec."Item No.", Rec."Outbound Entry No.");
        BindSubscription(Observer);
        ClearLastError();
        if Rec.Scenario = Rec.Scenario::Reservation then
            Succeeded := Codeunit.Run(Codeunit::"Inventory Reserv. Write ori", TempArgument)
        else
            Succeeded := Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument);
        NativeError := GetLastErrorText();
        UnbindSubscription(Observer);
        Response := TempArgument.GetResponseJson();
        if Succeeded then
            Succeeded := Response.Get('status', Token) and (Token.AsValue().AsText() = 'Success');
        Response.WriteTo(Serialized);
        Rec.Get(Rec.Id);
        Rec."Finished At" := CurrentDateTime();
        Observer.GetTiming(Rec."Hold Started At", Rec."Hold Finished At");
        Rec."Error Text" := CopyStr(NativeError, 1, MaxStrLen(Rec."Error Text"));
        Rec."Response Text" := CopyStr(Serialized, 1, MaxStrLen(Rec."Response Text"));
        if Succeeded then
            Rec.State := Rec.State::Succeeded
        else
            Rec.State := Rec.State::Refused;
        Rec.Modify();
        Commit();
    end;
}
