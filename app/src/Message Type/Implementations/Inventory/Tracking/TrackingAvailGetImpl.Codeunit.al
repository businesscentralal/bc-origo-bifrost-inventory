namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013473 "Tracking Avail. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Ledger Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads remaining quantity by lot, serial, and package.', Comment = 'is-IS=Les eftirstandandi magn eftir lotu, raðnúmeri og pakka.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'tracking availability, lot availability, serial availability, package', Comment = 'is-IS=rakningarráðstöfun, loturáðstöfun, raðnúmeraráðstöfun, pakki';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads open item ledger quantity for an item by tracking number.', Comment = 'is-IS=Les opið magn vörufærslna fyrir vöru eftir rakningarnúmeri.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.TrackingAvailability.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'locationCode');
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
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'MissingParameter');
        ErrorJson.Add('when', 'itemNo is missing');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking after reading availability.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete an item tracking specification instead of reading availability.'));
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
        Overview := 'Reads remaining tracked quantity. Does not assign tracking.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        MissingItemErr: Label 'itemNo must be specified.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError(MissingItemErr);
            exit;
        end;
        ItemNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(ItemNo));
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>0');
        if RequestJson.Get('locationCode', Token) then
            ItemLedgerEntry.SetRange("Location Code", CopyStr(Token.AsValue().AsCode(), 1, 10));
        if ItemLedgerEntry.FindSet() then
            repeat
                Clear(EntryJson);
                EntryJson.Add('entryNo', ItemLedgerEntry."Entry No.");
                EntryJson.Add('lotNo', ItemLedgerEntry."Lot No.");
                EntryJson.Add('serialNo', ItemLedgerEntry."Serial No.");
                EntryJson.Add('packageNo', ItemLedgerEntry."Package No.");
                EntryJson.Add('locationCode', ItemLedgerEntry."Location Code");
                EntryJson.Add('remainingQuantity', ItemLedgerEntry."Remaining Quantity");
                Entries.Add(EntryJson);
            until ItemLedgerEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
