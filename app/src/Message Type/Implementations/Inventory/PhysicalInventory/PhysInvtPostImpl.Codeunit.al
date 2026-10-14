namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Posts native physical-inventory lines and returns item and physical inventory ledger ranges.</summary>
codeunit 70013465 "Phys. Invt. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Posts native physical-inventory lines and returns item and physical inventory ledger ranges.', Comment = 'is-IS=Bókar talningarbók og skilar númerum stofnaðra birgða- og talningarfærslna.';
        SelectionLbl: Label 'Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'inventory journal physical count calculate check preview post', Comment = 'is-IS=birgðir bók talning reikna athuga forskoða bóka';
        OverviewLbl: Label 'Posts native physical-inventory lines and returns item and physical inventory ledger ranges. Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree. Requires the native item-posting permission. Only selected lines are posted; native failure rolls back the operation. Licensed dispatch and company domain gates apply.', Comment = 'is-IS=Bókar talningarbók og skilar númerum stofnaðra birgða- og talningarfærslna. Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu. Krefst innbyggðrar heimildar til vörubókunar. Aðeins valdar línur eru bókaðar og villa bakfærir aðgerðina. Leyfis- og sviðsheimildir fyrirtækis gilda.';

    /// <summary>Checks the company domain and the native permissions required by this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false) and NativeJournal.HasItemPostingPermission());
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
        NativeJournal: Codeunit "Inventory Native Journal ori";
        Process: Codeunit "Inv Native Journal Process ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false) then
            exit;
        if not NativeJournal.AssertItemPostingPermission(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetJournalType("Item Journal Template Type"::"Phys. Inventory");
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
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
        Target.ReadFrom('[{"table":"Item Journal Batch","selection":"An explicitly identified Phys. Inventory template batch."}]');
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
        Fields.Add(ContractMgt.ResponseField('postedLineCount', 'integer', 'Number of selected journal lines posted.'));
        Fields.Add(ContractMgt.ResponseField('itemRegisterNo', 'integer', 'Native item register created by posting.'));
        Fields.Add(ContractMgt.ResponseField('fromEntryNo', 'integer', 'First item ledger entry number in the native register.'));
        Fields.Add(ContractMgt.ResponseField('toEntryNo', 'integer', 'Last item ledger entry number in the native register.'));
        Fields.Add(ContractMgt.ResponseField('fromPhysInventoryEntryNo', 'integer', 'First physical inventory ledger entry in the native register; may be zero for nonphysical journals.'));
        Fields.Add(ContractMgt.ResponseField('toPhysInventoryEntryNo', 'integer', 'Last physical inventory ledger entry in the native register; may be zero for nonphysical journals.'));
        Fields.Add(ContractMgt.ResponseField('result', 'array', 'Selected lines: systemId, lineNo, itemNo, quantity, locationCode/newLocationCode, binCode/newBinCode, lotNo/newLotNo, serialNo/newSerialNo and packageNo/newPackageNo.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The resolved native journal template.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The resolved native journal batch.'));
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
        exit(true);
    end;

    /// <summary>Returns the native journal effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"writes":true,"posts":true,"rollback":false}');
        exit(true);
    end;

    /// <summary>Returns the native journal related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.PhysInventory.Calculate","useInsteadWhen":"Calculate the physical inventory journal."},{"name":"Inventory.PhysInventory.RecordCount","useInsteadWhen":"RecordCount the physical inventory journal."},{"name":"Inventory.PhysInventory.Check","useInsteadWhen":"Check the physical inventory journal."},{"name":"Inventory.PhysInventory.PreviewPost","useInsteadWhen":"PreviewPost the physical inventory journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native journal examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Nonempty array of {lineNo or systemId, qtyCounted?}. Distinct lines in the same batch; supplied selectors must agree. Omitted qtyCounted preserves the count; zero writes zero. Required for RecordCount; legacy Record may instead use lineNo and quantity. Replace example identifiers with your own batch and lines.","request":{"type":"Inventory.PhysInventory.Post","subject":"PHYS|OWNED"}}]');
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
