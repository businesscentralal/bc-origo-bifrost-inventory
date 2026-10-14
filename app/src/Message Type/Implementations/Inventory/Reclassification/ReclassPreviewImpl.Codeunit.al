namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Previews selected Transfer journal lines through native posting rollback.</summary>
codeunit 70013474 "Reclass Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Previews selected Transfer journal lines through native posting rollback.', Comment = 'is-IS=Forskoðar bókun endurflokkunarbókar án þess að varðveita bókaðar færslur.';
        SelectionLbl: Label 'Identify one existing nonrecurring Transfer journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Transfer sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'inventory journal reclassification transfer check preview post', Comment = 'is-IS=birgðir bók endurflokkun millifærsla athuga forskoða bóka';
        OverviewLbl: Label 'Previews selected Transfer journal lines through native posting rollback. Identify one existing nonrecurring Transfer journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree. Requires the native item-posting permission. Preview entries are rolled back; selected journal lines remain unchanged. Licensed dispatch and company domain gates apply.', Comment = 'is-IS=Forskoðar bókun endurflokkunarbókar án þess að varðveita bókaðar færslur. Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Transfer sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu. Krefst innbyggðrar heimildar til vörubókunar. Forskoðunarfærslum er bakfært og bókarlínur haldast óbreyttar. Leyfis- og sviðsheimildir fyrirtækis gilda.';

    /// <summary>Checks the company domain and the native permissions required by this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true));
    end;

    /// <summary>Returns the batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Reclassification requests use inbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Journal.Preview(Argument, "Item Journal Template Type"::Transfer);
    end;

    /// <summary>Returns the native journal envelope contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|BATCH","systemId"]},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the native journal target contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[{"table":"Item Journal Batch","selection":"An explicitly identified Transfer template batch."}]');
        exit(true);
    end;

    /// <summary>Returns the native journal parameters contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Existing journal template name, at most 10 characters. Supply with batchName unless subject identifies the same batch.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Existing journal batch name, at most 10 characters. All supplied selectors must agree.'));
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'Legacy alias for templateName; conflicting aliases are refused.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'Legacy alias for batchName; conflicting aliases are refused.'));
        Parameters.Add(ContractMgt.Parameter('lineSystemIds', 'array', false, 'Optional nonempty array of distinct line SystemIds in the selected batch. Omit to select the whole batch.'));
        exit(true);
    end;

    /// <summary>Returns the native journal response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success for a completed native operation.'));
        Fields.Add(ContractMgt.ResponseField('linesToPost', 'integer', 'Number of selected lines included in the rollback preview.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'True: native preview entries have been rolled back.'));
        Fields.Add(ContractMgt.ResponseField('preview', 'array', 'Captured native preview entries grouped by table.'));
        Fields.Add(ContractMgt.ResponseField('result', 'array', 'Selected lines: systemId, lineNo, itemNo, quantity, locationCode/newLocationCode, binCode/newBinCode, lotNo/newLotNo, serialNo/newSerialNo and packageNo/newPackageNo.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The resolved native journal template.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The resolved native journal batch.'));
        Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Native preview G/L totals.'));
        Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total native preview entry count.'));
        Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Native preview G/L entry count.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the native journal errors contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.TextErrorEntry('Native journal selection or validation error.', 'Missing or conflicting batch selectors, invalid template, recurring batch, malformed line selection, unsupported parameters or native validation failure.', 'Select an existing batch of the required template type and correct the native error before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Required Inventory, native table or item-posting permission is missing.', 'Request the required permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The company domain is disabled or a typed request value is invalid.', 'Enable the domain or correct the indicated request value.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selected journal contains no lines.', 'Select a nonempty journal batch or valid line subset.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native posting preview error.', 'Native posting preview fails or produces no acceptable preview entries.', 'Correct the native posting error before retrying; preview does not retain ledger changes.'));
        exit(true);
    end;

    /// <summary>Returns the native journal effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"writes":false,"posts":false,"rollback":true}');
        exit(true);
    end;

    /// <summary>Returns the native journal related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.Reclassification.Check","useInsteadWhen":"Check the journal."},{"name":"Inventory.Reclassification.Post","useInsteadWhen":"Post the journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native journal examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Nonempty array of {lineNo or systemId, qtyCounted?}. Distinct lines in the same batch; supplied selectors must agree. Omitted qtyCounted preserves the count; zero writes zero. Required for RecordCount; legacy Record may instead use lineNo and quantity. Replace example identifiers with your own batch and lines.","request":{"type":"Inventory.Reclassification.PreviewPost","subject":"RECLASS|OWNED"}}]');
        exit(true);
    end;

    /// <summary>No override is provided.</summary>
    procedure GetMetering(var Value: JsonObject): Boolean
    begin
        Clear(Value);
        exit(false);
    end;

    /// <summary>No override is provided.</summary>
    procedure GetWorkflow(var Value: JsonObject): Boolean
    begin
        Clear(Value);
        exit(false);
    end;

    /// <summary>Describes native journal behavior.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Describes native journal behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes native journal behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains native journal constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains native journal constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := OverviewLbl;
        exit(true);
    end;
}
