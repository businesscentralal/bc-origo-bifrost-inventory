namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Inventory.Transfer.UndoShipment. Runs codeunit 9030 Undo Transfer Shipment.
/// </summary>
codeunit 70013480 "Transfer Undo Shpt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Undoes selected posted transfer shipment lines with native corrective entries.', Comment = 'is-IS=Afturkallar valdar línur bókaðrar flutningsafhendingar með innbyggðum leiðréttingarfærslum.';
        KeywordsLbl: Label 'undo transfer shipment', Comment = 'is-IS=afturkalla afhendingu flutnings';
        SelectionDescriptionLbl: Label 'Selects a shipment by documentNo and optionally distinct lineNos.', Comment = 'is-IS=Velur afhendingu eftir documentNo og valkvæðum aðgreindum lineNos.';
        OverviewLbl: Label 'Calls native codeunit 9030 Undo Transfer Shipment. Preserves the posted document.', Comment = 'is-IS=Kallar á innbyggða keyrslueiningu 9030 Undo Transfer Shipment. Varðveitir bókaða skjalið.';
        NotesLbl: Label 'Received, corrected or missing source lines are refused. Unselected shipment lines are preserved.', Comment = 'is-IS=Línum sem hafa verið mótteknar eða leiðréttar og línum án upprunalínu er hafnað. Óvaldar afhendingarlínur eru varðveittar.';

    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Shipment Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope('Inventory.Transfer.UndoShipment');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, ''));
        Parameters.Add(ContractMgt.Parameter('lineNos', 'array', false, ''));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Checks company, posting, native write and license permissions before isolated native undo.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Shipment Header", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv Native Undo Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv Native Undo Process ori", Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
