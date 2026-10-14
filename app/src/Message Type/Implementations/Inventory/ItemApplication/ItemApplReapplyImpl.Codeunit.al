namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

codeunit 70013492 "Item Appl. Reapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Reapplies an item ledger entry through Item Jnl.-Post Line.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('reapply item application, apply item ledger entry');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reapplies an outbound item ledger entry to an inbound entry.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemApplication.Reapply');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Item Jnl.-Post Line');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parameter: JsonObject;
    begin
        Clear(Parameter);
        Parameter.Add('name', 'outboundEntryNo');
        Parameter.Add('type', 'integer');
        Parameter.Add('required', true);
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'inboundEntryNo');
        Parameter.Add('type', 'integer');
        Parameter.Add('required', true);
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'quantity');
        Parameter.Add('type', 'decimal');
        Parameter.Add('required', true);
        Parameters.Add(Parameter);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('itemLedgerEntryNo', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'either item ledger entry was not found');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Item Application Entry');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Unapply the item ledger entry instead of reapplying it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Read the item application before reapplying it.'));
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
        Overview := 'Reapplies an item ledger entry through the standard posting line codeunit.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Calls Item Jnl.-Post Line. It does not insert table 339 directly.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv Application Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv Application Process ori", Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
