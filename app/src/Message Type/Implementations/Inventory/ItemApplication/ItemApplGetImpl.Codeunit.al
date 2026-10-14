namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Get. Reads Item Application Entry.
/// </summary>
codeunit 70013490 "Item Appl. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Reads item application entries for an item ledger entry.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('item application, applied entries');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reads application entries. Unapply and reapply are separate types.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemApplication.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item Application Entry');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parameter: JsonObject;
        Name: Text;
        Names: List of [Text];
    begin
        Names.Add('itemNo');
        Names.Add('itemLedgerEntryNo');
        Names.Add('locationCode');
        Names.Add('variantCode');
        foreach Name in Names do begin
            Clear(Parameter);
            Parameter.Add('name', Name);
            if Name = 'itemLedgerEntryNo' then
                Parameter.Add('type', 'integer')
            else
                Parameter.Add('type', 'string');
            Parameter.Add('required', false);
            Parameters.Add(Parameter);
        end;
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('itemLedgerEntryNo', 0);
        Response.Add('entries', 'array');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'MissingParameter');
        ErrorJson.Add('when', 'itemLedgerEntryNo is required.');
        Errors.Add(ErrorJson);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Unapply an item application entry instead of reading it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Reapply', 'Reapply an item ledger entry instead of reading applications.'));
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
        Overview := 'Reads item applications with both ledger sides for one item or ledger entry.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only. Unapply and reapply are separate message types.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        NativeRead: Codeunit "Inventory Application Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        NativeRead.Read(Argument);
    end;
}
