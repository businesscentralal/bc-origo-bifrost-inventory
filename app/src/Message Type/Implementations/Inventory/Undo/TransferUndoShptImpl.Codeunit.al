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
    begin
        Clear(Envelope);
        Envelope.Add('messageType', 'Inventory.Transfer.UndoShipment');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'Nonempty posted shipment number, at most 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('lineNos', 'array', false, 'Distinct positive shipment line numbers. Omit to undo all remaining original lines; an empty array is refused.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the native correction.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'Posted shipment number; the posted document is preserved.'));
        Fields.Add(ContractMgt.ResponseField('undoneLineCount', 'integer', 'Number of selected original shipment lines corrected.'));
        Fields.Add(ContractMgt.ResponseField('result', 'array', 'Selected original lines: lineNo (integer), itemNo (string), quantity (decimal).'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.TextErrorEntry('documentNo must be nonempty text of at most 20 characters.', 'Missing, empty, overlong or non-text documentNo.', 'Supply the posted shipment number as text.'));
        Errors.Add(ContractMgt.TextErrorEntry('lineNos must be a nonempty array of distinct positive line numbers on this shipment.', 'Invalid or duplicate line selection.', 'Send distinct positive integer line numbers from this shipment, or omit lineNos.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native shipment validation error.', 'Unknown document or line, received or corrected lines, missing transfer source, unsupported keys or native posting refusal.', 'Correct the selection and resolve the native error before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Required Inventory, table or posting permission is missing.', 'Request the required permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The company Inventory domain is disabled.', 'Enable the domain from Inventory Setup.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('type', 'irreversible');
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
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
