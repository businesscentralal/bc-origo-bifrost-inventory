namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>Posts selected transfer order quantities through Inventory.TransferOrder.Ship.</summary>
codeunit 10077020 "Transfer Ship Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks the transfer domain and posting permission.</summary>
    procedure IsEnabled(): Boolean
    var
        ExistingPost: Codeunit "Transfer Order Post Impl ori";
    begin
        exit(ExistingPost.IsEnabled());
    end;

    /// <summary>Returns the transfer header table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Header");
    end;

    /// <summary>Describes the operation.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Ships selected quantities on a transfer order and returns the posted document.', Comment = 'is-IS=Afhendir valið magn á flutningspöntun og skilar bókaða skjalinu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'partial transfer, ship transfer order, selected lines, quantity', Comment = 'is-IS=hlutaflutningur, flutningspöntun, valdar línur, magn';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes when to select this operation.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Uses the inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates and posts only the selected quantities.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        PartialTransfer: Codeunit "Partial Transfer Mgt ori";
    begin
        PartialTransfer.Execute(Argument, true);
    end;

    /// <summary>Returns the localized envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Envelope := Contract.GetEnvelope(true);
        exit(true);
    end;

    /// <summary>Returns the localized target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Target := Contract.GetTarget(true);
        exit(true);
    end;

    /// <summary>Returns the localized parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Parameters := Contract.GetParameters(true);
        exit(true);
    end;

    /// <summary>Returns the localized response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Response := Contract.GetResponse(true);
        exit(true);
    end;

    /// <summary>Returns the localized errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Errors := Contract.GetErrors(true);
        exit(true);
    end;

    /// <summary>Returns the localized effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Effect := Contract.GetEffect(true);
        exit(true);
    end;

    /// <summary>Returns the localized related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Related := Contract.GetRelated(true);
        exit(true);
    end;

    /// <summary>Returns the localized examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Examples := Contract.GetExamples(true);
        exit(true);
    end;

    /// <summary>Returns the localized overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Overview := Contract.GetOverview(true);
        exit(true);
    end;

    /// <summary>Returns the localized notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Notes := Contract.GetNotes(true);
        exit(true);
    end;

    /// <summary>No additional metering chapter is defined.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the partial shipment and receipt workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Partial Transfer Contract ori";
    begin
        Workflow := Contract.GetWorkflow();
        exit(true);
    end;
}
