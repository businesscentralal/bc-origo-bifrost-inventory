namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Previews native physical-inventory posting with rollback and captured ledger entries.</summary>
codeunit 10076885 "Phys. Inv. Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Previews posting a physical inventory journal: returns the ledger entries it would create, then rolls everything back.', Comment = 'is-IS=Forskoðar bókun talningarbókar: skilar þeim færslum sem hún myndi stofna og bakfærir síðan allt.';
        SelectionLbl: Label 'Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'preview physical count posting, preview count journal, count journal ledger entries, simulate stock take posting', Comment = 'is-IS=forskoða bókun birgðatalningar, forskoða talningarbók, færslur talningarbókar, líkja eftir bókun vörutalningar';
        OverviewLbl: Label 'Runs the posting of one Phys. Inventory journal batch as a preview, returns the entries it would create and rolls everything back. It needs the item posting permission.', Comment = 'is-IS=Keyrir bókun einnar bókarkeyrslu af gerðinni Phys. Inventory sem forskoðun, skilar þeim færslum sem hún myndi stofna og bakfærir allt. Krefst heimildar til vörubókunar.';

    /// <summary>Checks the company domain and the native permissions required by this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false) and NativeJournal.HasItemPostingPermission());
    end;

    /// <summary>Returns the batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Physical inventory requests use inbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;
    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        FailureJournal: Codeunit "Inventory Native Journal ori";
        Gate: Codeunit "Inventory Domain Gate ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
        Process: Codeunit "Inventory Read Process ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false) then
            exit;
        if not NativeJournal.AssertItemPostingPermission(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('PhysicalPreview');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                FailureJournal.RespondWithFailure(Argument);
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

    /// <summary>Returns the envelope chapter of the contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|BATCH","systemId"],"description":"Identifies the journal batch as TEMPLATE|BATCH, or as the SystemId of the Item Journal Batch. Without a subject, send templateName and batchName in data. Every selector that is sent must name the same batch."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the target chapter of the contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('subject', 'TEMPLATE|BATCH', 'The journal template name and the batch name, each at most 10 characters, separated by a vertical bar. The template must be a Phys. Inventory template that is not recurring.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item Journal Batch.'));
        Target.Add(ContractMgt.TargetEntry('data.templateName, data.batchName', 'journal template and batch name', 'The template and the batch together. data.journalTemplateName and data.journalBatchName are accepted as aliases.'));
        exit(true);
    end;

    /// <summary>Returns the parameters chapter of the contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Name of an existing Phys. Inventory journal template that is not recurring, at most 10 characters. Send it with batchName unless subject identifies the batch.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Name of an existing journal batch of that template, at most 10 characters. Every selector that is sent must name the same batch.'));
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'Alias of templateName. A value that differs from templateName, ignoring case, is refused.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'Alias of batchName. A value that differs from batchName, ignoring case, is refused.'));
        Parameters.Add(ContractMgt.Parameter('lineSystemIds', 'array', false, 'Nonempty array of distinct SystemIds of journal lines in the selected batch. Only those lines are used. Omit it to use every line of the batch.'));
        exit(true);
    end;

    /// <summary>Returns the response chapter of the contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Field: JsonObject;
        Fields: JsonArray;
        Children: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the preview ran and captured entries.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The journal template of the selected batch.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The selected journal batch.'));
        Fields.Add(ContractMgt.ResponseField('linesToPost', 'integer', 'Number of selected lines in the preview.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true: the preview entries were rolled back.'));
        Field := ContractMgt.ResponseField('preview', 'array', 'The captured entries, one object per table.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('tableId', 'integer', 'Number of the table of the entries.'));
        Children.Add(ContractMgt.ResponseField('tableName', 'string', 'Name of the table.'));
        Children.Add(ContractMgt.ResponseField('tableCaption', 'string', 'Caption of the table.'));
        Children.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Number of entries captured for the table.'));
        Children.Add(ContractMgt.ResponseField('entries', 'array', 'The captured entries with their main fields.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Fields.Add(ContractMgt.ResponseField('totals', 'object', 'G/L totals of the preview: totalDebitLCY, totalCreditLCY and, only when G/L entries were captured, balanced.'));
        Field := ContractMgt.ResponseField('result', 'array', 'The selected lines that were previewed.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('systemId', 'string', 'SystemId of the journal line.'));
        Children.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number in the batch.'));
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number of the line.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The adjustment quantity of the line.'));
        Children.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code of the line.'));
        Children.Add(ContractMgt.ResponseField('newLocationCode', 'string', 'New location code of the line.'));
        Children.Add(ContractMgt.ResponseField('binCode', 'string', 'Bin code of the line.'));
        Children.Add(ContractMgt.ResponseField('newBinCode', 'string', 'New bin code of the line.'));
        Children.Add(ContractMgt.ResponseField('lotNo', 'string', 'Lot number; empty when the line has no single tracking assignment.'));
        Children.Add(ContractMgt.ResponseField('newLotNo', 'string', 'New lot number.'));
        Children.Add(ContractMgt.ResponseField('serialNo', 'string', 'Serial number; empty when the line has no single tracking assignment.'));
        Children.Add(ContractMgt.ResponseField('newSerialNo', 'string', 'New serial number.'));
        Children.Add(ContractMgt.ResponseField('packageNo', 'string', 'Package number; empty when the line has no single tracking assignment.'));
        Children.Add(ContractMgt.ResponseField('newPackageNo', 'string', 'New package number.'));
        Children.Add(ContractMgt.ResponseField('tracking', 'array', 'Every item tracking assignment of the line: lotNo, newLotNo, serialNo, newSerialNo, packageNo, newPackageNo and quantityBase.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total number of captured entries.'));
        Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Number of captured G/L entries.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors chapter of the contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selected journal contains no lines.', 'Select a batch with lines or a valid line subset.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'The preview captured no entry, so the posting would create nothing.', 'Check that the lines have a quantity to post.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the posting preview; the answer carries its own text.', 'Correct the cause in the text and retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Unsupported journal parameter %1.', 'A key is sent that this type does not read.', 'Remove the key; only the batch selectors and the declared parameters are accepted.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Identify one existing journal batch using templateName and batchName or subject TEMPLATE|BATCH or SystemId.', 'No batch is identified, the selectors name different batches, the subject is neither TEMPLATE|BATCH nor a SystemId, the batch does not exist, or its template is not a Phys. Inventory template or is recurring.', 'Identify one existing batch of a non-recurring Phys. Inventory template with consistent selectors.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Physical Inventory domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the item posting permission (BIFROST ItemPost ori) or write permission on the item journal.', 'Ask an administrator for BIFROST ItemPost ori.'));
        exit(true);
    end;

    /// <summary>Returns the effect chapter of the contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is kept. The posting is run as a preview and every entry it creates is rolled back; the journal lines stay as they are.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori and BIFROST ItemPost ori');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('rollback', true);
        exit(true);
    end;

    /// <summary>Returns the metering chapter of the contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the related chapter of the contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Check', 'Use it to list line problems; it does not simulate the posting.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.RecordCount', 'Use it to change the counted quantities before previewing again.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Post', 'Use it to post the lines for real.'));
        exit(true);
    end;

    /// <summary>Returns the workflow chapter of the contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Check', 'Find line problems first.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.PreviewPost', 'See the entries the posting would create; everything is rolled back.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Post', 'Post the count when the preview is acceptable.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Returns the examples chapter of the contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Preview the posting of the batch DEFAULT',
            '{"type":"Inventory.PhysInventory.PreviewPost","subject":"PHYS. INV.|DEFAULT"}',
            '{"status":"Success","templateName":"PHYS. INV.","batchName":"DEFAULT","linesToPost":1,"rollback":true,"preview":[{"tableId":32,"tableName":"Item Ledger Entry","tableCaption":"Item Ledger Entry","entryCount":1,"entries":[{"ItemNo_":"1000"}]}],"totals":{"totalDebitLCY":0,"totalCreditLCY":0},"result":[{"systemId":"6f1c1d2e-0000-0000-0000-000000000001","lineNo":10000,"itemNo":"1000","quantity":2}],"entryCount":1,"glEntryCount":0}'));
        exit(true);
    end;

    /// <summary>Returns the overview chapter of the contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Returns the notes chapter of the contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Runs the standard posting preview of the journal lines and rolls it back, so no ledger entry, item register or journal change is kept. rollback is true in every Success answer. ' +
            'The type needs the item posting permission (BIFROST ItemPost ori), like Inventory.PhysInventory.Post; without it the call is refused with PermissionDenied. ' +
            'The whole batch is previewed, or only the lines in lineSystemIds. preview lists the captured entries per table; totals carries totalDebitLCY and totalCreditLCY and carries balanced only when G/L entries were captured. ' +
            'A batch without lines is refused with PreconditionFailed. A preview that would create nothing is answered NothingToPreview. An error that the preview raises is answered with code BusinessCentralError and Business Central''s own text. ' +
            'Each selected line must be a valid physical inventory line (item set and not blocked, adjustment entry type, Direct Cost value entry type, no item charge); otherwise the call fails with BusinessCentralError. Use Inventory.PhysInventory.Check for a list of line problems.';
        exit(true);
    end;
}
