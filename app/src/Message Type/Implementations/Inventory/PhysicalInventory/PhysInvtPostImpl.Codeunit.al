namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Posts native physical-inventory lines and returns item and physical inventory ledger ranges.</summary>
codeunit 10076881 "Phys. Invt. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Posts the lines of a physical inventory journal and returns the item register and the entry number ranges.', Comment = 'is-IS=Bókar línur talningarbókar og skilar vörubókarskrá og númeraröðum færslna.';
        SelectionLbl: Label 'Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'post physical count, post count journal, book stock take, post inventory count', Comment = 'is-IS=bóka birgðatalningu, bóka talningarbók, færa vörutalningu, bóka talin birgðamagn';
        OverviewLbl: Label 'Posts the lines of one Phys. Inventory journal batch, or only the lines in lineSystemIds, and returns the item register and the entry number ranges. Posting is permanent and needs the item posting permission.', Comment = 'is-IS=Bókar línur einnar bókarkeyrslu af gerðinni Phys. Inventory, eða aðeins línurnar í lineSystemIds, og skilar vörubókarskrá og númeraröðum færslna. Bókun er varanleg og krefst heimildar til vörubókunar.';

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

    /// <summary>Physical inventory requests use inbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
        Process: Codeunit "Inventory Write Process ori";
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the lines were posted.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The journal template of the selected batch.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The selected journal batch.'));
        Fields.Add(ContractMgt.ResponseField('postedLineCount', 'integer', 'Number of lines that were selected and posted.'));
        Fields.Add(ContractMgt.ResponseField('itemRegisterNo', 'integer', 'Number of the item register the posting created.'));
        Fields.Add(ContractMgt.ResponseField('fromEntryNo', 'integer', 'First item ledger entry number of the register.'));
        Fields.Add(ContractMgt.ResponseField('toEntryNo', 'integer', 'Last item ledger entry number of the register.'));
        Fields.Add(ContractMgt.ResponseField('fromPhysInventoryEntryNo', 'integer', 'First physical inventory ledger entry number of the register; 0 when the posting created none.'));
        Fields.Add(ContractMgt.ResponseField('toPhysInventoryEntryNo', 'integer', 'Last physical inventory ledger entry number of the register; 0 when the posting created none.'));
        Field := ContractMgt.ResponseField('result', 'array', 'The lines that were posted, as they were before posting.');
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
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors chapter of the contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected journal batch does not exist.', 'Check templateName and batchName or send the SystemId of an existing physical inventory batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selected journal contains no lines.', 'Select a batch with lines or a valid line subset.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the item posting permission (BIFROST ItemPost ori) or write permission on the item journal.', 'Ask an administrator for BIFROST ItemPost ori.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Physical Inventory domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central posting error text', 'The posting fails, for example because a line fails the item journal checks, or a selected line is not a valid physical inventory line. Nothing is posted.', 'Run Inventory.PhysInventory.Check, correct the lines named in its answer and retry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Unsupported journal parameter %1.', 'A key is sent that this type does not read.', 'Remove the key; only the batch selectors and the declared parameters are accepted.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Identify one existing journal batch using templateName and batchName or subject TEMPLATE|BATCH or SystemId.', 'No batch is identified, the selectors name different batches, the subject is neither TEMPLATE|BATCH nor a SystemId, its template is not a Phys. Inventory template or is recurring.', 'Identify one existing batch of a non-recurring Phys. Inventory template with consistent selectors.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'lineSystemIds must be a nonempty array of distinct SystemIds belonging to the identified journal batch.', 'lineSystemIds is not an array, is empty, repeats an id, or names a line outside the batch.', 'Send distinct SystemIds of lines in the selected batch, or omit lineSystemIds.'));
        exit(true);
    end;

    /// <summary>Returns the effect chapter of the contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Posts the selected lines of the Phys. Inventory journal batch through the standard item journal batch posting: item ledger entries, physical inventory ledger entries, value entries and an item register are created and the posted lines leave the journal. The posting commits with the answer; under Omit Commit the caller''s transaction commits instead. It cannot be undone by a message type of this app.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori and BIFROST ItemPost ori');
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        Effect.Add('rollback', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Check', 'Use it first to list line problems without posting.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.PreviewPost', 'Use it first to see the entries the posting would create.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.RecordCount', 'Use it to change the counted quantities before posting.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Calculate', 'Use it to fill an empty batch with the expected stock before counting.'));
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
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.PreviewPost', 'See the entries the posting would create.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Post', 'Post the count; the adjustments are written to the ledger.'));
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
            'Post the whole batch DEFAULT',
            '{"type":"Inventory.PhysInventory.Post","subject":"PHYS. INV.|DEFAULT"}',
            '{"status":"Success","templateName":"PHYS. INV.","batchName":"DEFAULT","postedLineCount":1,"itemRegisterNo":1250,"fromEntryNo":8812,"toEntryNo":8812,"fromPhysInventoryEntryNo":410,"toPhysInventoryEntryNo":410,"result":[{"systemId":"6f1c1d2e-0000-0000-0000-000000000001","lineNo":10000,"itemNo":"1000","quantity":2,"locationCode":"","newLocationCode":"","binCode":"","newBinCode":"","lotNo":"","newLotNo":"","serialNo":"","newSerialNo":"","packageNo":"","newPackageNo":"","tracking":[]}]}'));
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
        Notes := 'Posting is permanent and commits: the posting commits with the answer, and under Omit Commit the caller''s transaction commits instead. The commits inside Business Central''s batch posting are held back, so a failure rolls back the whole posting. Under Omit Commit an error is raised to the caller instead of being answered with the error text. ' +
            'Without lineSystemIds every line of the batch is posted; with lineSystemIds only those lines (distinct SystemIds of lines in the batch). A batch without lines is refused with PreconditionFailed. ' +
            'Every selected line must have an item that is not blocked, be a physical inventory line, have the entry type Positive Adjmt. or Negative Adjmt., the value entry type Direct Cost and no item charge, and must pass the item journal checks; otherwise nothing is posted and the error text is answered without a code. ' +
            'The caller needs the item posting permission (BIFROST ItemPost ori) as well as write access to the journal; without it the call is refused with PermissionDenied. The Physical Inventory domain must be turned on in Inventory Setup (a missing setup row counts as on). ' +
            'fromPhysInventoryEntryNo and toPhysInventoryEntryNo are 0 when the posting created no physical inventory ledger entry. ' +
            'Use Inventory.PhysInventory.Check and Inventory.PhysInventory.PreviewPost first.';
        exit(true);
    end;
}
