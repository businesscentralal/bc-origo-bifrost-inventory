namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Unapply. Removes an application entry and marks the item for adjustment.
/// </summary>
codeunit 70013491 "Item Appl. Unapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

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
        exit('Unapplies an item application entry and marks the item for adjustment.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('unapply item, item application');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Unapplies an item application entry. Adjust Cost stays a separate type.');
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
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemApplicationEntry: Record "Item Application Entry";
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
        MissingEntryErr: Label 'entryNo is required.', Locked = true;
        NotFoundErr: Label 'Item application entry %1 was not found.', Comment = '%1 = entry no.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('entryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingEntryErr, 'entryNo', '', '', '');
            exit;
        end;
        EntryNo := Token.AsValue().AsInteger();
        if not ItemApplicationEntry.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EntryNo), 'entryNo', '', '', '');
            exit;
        end;
        if Item.Get(ItemApplicationEntry."Item No.") then
            if Item."Cost is Adjusted" then begin
                Item."Cost is Adjusted" := false;
                Item.Modify(true);
            end;
        ItemApplicationEntry.Delete(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemNo', ItemApplicationEntry."Item No.");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
