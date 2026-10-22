namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Calculates expected stock into an existing empty physical-inventory journal with native report 790.</summary>
codeunit 10076883 "Phys. Inv. Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Fills an empty physical inventory journal with the expected stock per item, using the Calculate Inventory function.', Comment = 'is-IS=Fyllir tóma talningarbók með væntum birgðum á hverja vöru með aðgerðinni Reikna birgðir.';
        SelectionLbl: Label 'Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'calculate inventory, physical count, stock take, count journal, fill count journal', Comment = 'is-IS=reikna birgðir, birgðatalning, vörutalning, talningarbók, fylla talningarbók';
        OverviewLbl: Label 'Fills an empty Phys. Inventory journal batch with one line per eligible item, using the Calculate Inventory function; nothing is posted. postingDate and documentNo are required.', Comment = 'is-IS=Fyllir tóma bókarkeyrslu af gerðinni Phys. Inventory (talningarbók) með einni línu fyrir hverja gjaldgenga vöru með aðgerðinni Reikna birgðir; ekkert er bókað. postingDate og documentNo eru nauðsynleg.';

    /// <summary>Checks the company domain and the native permissions required by this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false));
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
        Process: Codeunit "Inventory Write Process ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('Calculate');
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
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|BATCH","systemId"],"description":"Identifies the journal batch as TEMPLATE|BATCH, or as the SystemId of the Item Journal Batch. Without a subject, send templateName and batchName in data. Every selector that is sent must name the same batch."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
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
        Parameter: JsonObject;
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Name of an existing Phys. Inventory journal template that is not recurring, at most 10 characters. Send it with batchName unless subject identifies the batch.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Name of an existing journal batch of that template, at most 10 characters. Every selector that is sent must name the same batch.'));
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'Alias of templateName. A value that differs from templateName, ignoring case, is refused.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'Alias of batchName. A value that differs from batchName, ignoring case, is refused.'));
        Parameter := ContractMgt.Parameter('postingDate', 'string', true, 'Posting date written to every calculated journal line, YYYY-MM-DD.');
        Parameter.Add('format', 'YYYY-MM-DD');
        Parameters.Add(Parameter);
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'Document number written to every calculated journal line, at most 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Item number filter, a Business Central filter expression of at most 2048 characters such as 1000..1999. Omit it to include every eligible item.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Location filter for the calculation, a filter expression of at most 2048 characters.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Variant filter for the calculation, a filter expression of at most 2048 characters.'));
        Parameter := ContractMgt.Parameter('itemsNotOnInventory', 'boolean', false, 'Include items with zero inventory. Default false.');
        Parameter.Add('default', false);
        Parameters.Add(Parameter);
        Parameter := ContractMgt.Parameter('includeItemsWithNoTransactions', 'boolean', false, 'Include items with no ledger transactions. Default false.');
        Parameter.Add('default', false);
        Parameters.Add(Parameter);
        exit(true);
    end;

    /// <summary>Returns the response chapter of the contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the calculation ran.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The journal template of the selected batch.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The selected journal batch.'));
        Fields.Add(ContractMgt.ResponseField('linesCreated', 'integer', 'Number of lines the batch has after the calculation; 0 when no item was eligible.'));
        Fields.Add(ContractMgt.ResponseField('posted', 'boolean', 'Always false: the journal is not posted.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors chapter of the contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'postingDate is absent, null or empty.', 'Send postingDate as YYYY-MM-DD.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'postingDate is not a date in YYYY-MM-DD form, or itemsNotOnInventory or includeItemsWithNoTransactions is not a JSON boolean.', 'Correct the value as the answer indicates.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Physical Inventory domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on the Item Journal Line table.', 'Ask an administrator for a permission set that grants it, for example BIFROST Full ori.'));
        Errors.Add(ContractMgt.TextErrorEntry('Calculate requires an empty physical inventory batch.', 'The batch already has lines.', 'Use an empty batch, or work on the existing lines with Inventory.PhysInventory.RecordCount.'));
        Errors.Add(ContractMgt.TextErrorEntry('Parameter documentNo must be nonempty text of at most 20 characters.', 'documentNo is absent, empty, not text or longer than 20 characters.', 'Send a document number of at most 20 characters.'));
        Errors.Add(ContractMgt.TextErrorEntry('Unsupported journal parameter %1.', 'A key is sent that this type does not read.', 'Remove the key; only the batch selectors and the declared parameters are accepted.'));
        Errors.Add(ContractMgt.TextErrorEntry('Identify one existing journal batch using templateName and batchName or subject TEMPLATE|BATCH or SystemId.', 'No batch is identified, the selectors name different batches, the subject is neither TEMPLATE|BATCH nor a SystemId, the batch does not exist, or its template is not a Phys. Inventory template or is recurring.', 'Identify one existing batch of a non-recurring Phys. Inventory template with consistent selectors.'));
        exit(true);
    end;

    /// <summary>Returns the effect chapter of the contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Inserts one line per eligible item into the empty Phys. Inventory journal batch, with the calculated quantity, the posting date and the document number. Nothing is posted and no ledger entry is created. The lines are committed with the answer; under Omit Commit the caller''s transaction commits instead.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.RecordCount', 'Use it to enter the counted quantities on the lines this call created.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Check', 'Use it to find line problems before posting the count.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.PreviewPost', 'Use it to see the entries a posting would create without keeping them.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Post', 'Use it to post the counted lines to the ledger.'));
        exit(true);
    end;

    /// <summary>Returns the workflow chapter of the contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Calculate', 'Fill the empty journal batch with the expected stock.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.RecordCount', 'Enter the counted quantity on each line.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Check', 'Find line problems before posting.'));
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
            'Calculate the expected stock of item 1000 into an empty batch',
            '{"type":"Inventory.PhysInventory.Calculate","subject":"PHYS. INV.|DEFAULT","data":{"postingDate":"2026-10-14","documentNo":"COUNT-001","itemNo":"1000"}}',
            '{"status":"Success","templateName":"PHYS. INV.","batchName":"DEFAULT","linesCreated":1,"posted":false}'));
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
        Notes := 'Runs the Calculate Inventory function of the physical inventory journal into one empty batch. Nothing is posted and no ledger entry is created. ' +
            'The batch must already exist, belong to a Phys. Inventory template that is not recurring, and have no lines; a batch with lines is refused. ' +
            'postingDate (YYYY-MM-DD) and documentNo (at most 20 characters) are required and are written to every line. itemNo, locationCode and variantCode are Business Central filter expressions of at most 2048 characters; without them every eligible item is calculated. itemsNotOnInventory and includeItemsWithNoTransactions default to false. ' +
            'linesCreated is the number of lines the batch has afterwards and can be 0. Any key that is not declared is refused. ' +
            'The lines are committed with the answer; under Omit Commit the caller''s transaction commits instead. A failure rolls back the lines already created. Under Omit Commit an error is raised to the caller instead of being answered with the error text. ' +
            'The Physical Inventory domain must be turned on in Inventory Setup (a missing setup row counts as on) and the caller needs write permission on the Item Journal Line table. ' +
            'Call Inventory.PhysInventory.RecordCount next to enter the counted quantities.';
        exit(true);
    end;
}
