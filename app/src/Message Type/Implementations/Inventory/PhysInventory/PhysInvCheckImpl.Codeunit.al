namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Checks physical-inventory journal lines through native Item Jnl.-Check Line.</summary>
codeunit 10076884 "Phys. Inv. Check Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Checks the lines of a physical inventory journal with the standard item journal line checks, without writing or posting.', Comment = 'is-IS=Athugar línur talningarbókar með stöðluðum athugunum á vörubókarlínum án þess að skrifa eða bóka.';
        SelectionLbl: Label 'Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'check physical count, validate count journal, count journal errors, ready to post count', Comment = 'is-IS=athuga birgðatalningu, sannprófa talningarbók, villur í talningarbók, talning tilbúin til bókunar';
        OverviewLbl: Label 'Runs the standard item journal line checks on the lines of one Phys. Inventory journal batch and answers Ready, ReadyWithWarnings or NotReady. Nothing is written or posted.', Comment = 'is-IS=Keyrir stöðluðu athuganirnar á vörubókarlínum fyrir línur einnar bókarkeyrslu af gerðinni Phys. Inventory og svarar Ready, ReadyWithWarnings eða NotReady. Ekkert er skrifað eða bókað.';

    /// <summary>Checks the company domain and the native permissions required by this operation.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false));
    end;

    /// <summary>Returns the batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Physical inventory checks use outbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Journal.Check(Argument, "Item Journal Template Type"::"Phys. Inventory");
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success whenever the check ran, whatever the verdict. Read validationResult.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The journal template of the selected batch.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The selected journal batch.'));
        Fields.Add(ContractMgt.ResponseField('validationResult', 'string', 'Ready, ReadyWithWarnings or NotReady.'));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Number of lines selected for the check.'));
        Fields.Add(ContractMgt.ResponseField('errorCount', 'integer', 'Number of problems in errors.'));
        Fields.Add(ContractMgt.ResponseField('warningCount', 'integer', 'Number of problems in warnings.'));
        Field := ContractMgt.ResponseField('errors', 'array', 'Problems that stop posting.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('code', 'string', 'BusinessCentralError for a failing line or a Business Central error message, PreconditionFailed for an empty batch.'));
        Children.Add(ContractMgt.ResponseField('error', 'string', 'The text of the problem.'));
        Children.Add(ContractMgt.ResponseField('parameter', 'string', 'line N for a problem of one line, otherwise empty or batchName.'));
        Children.Add(ContractMgt.ResponseField('nextStep', 'string', 'What to do about it.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Field := ContractMgt.ResponseField('warnings', 'array', 'Problems that do not stop posting, such as a posting date after the work date (code InvalidLine).');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('code', 'string', 'InvalidLine for a posting date after the work date, otherwise BusinessCentralError.'));
        Children.Add(ContractMgt.ResponseField('error', 'string', 'The text of the problem.'));
        Children.Add(ContractMgt.ResponseField('parameter', 'string', 'line N for a problem of one line, otherwise empty.'));
        Children.Add(ContractMgt.ResponseField('nextStep', 'string', 'What to do about it.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Unsupported journal parameter %1.', 'A key is sent that this type does not read.', 'Remove the key; only the batch selectors and the declared parameters are accepted.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'lineSystemIds must be a nonempty array of distinct SystemIds belonging to the identified journal batch.', 'lineSystemIds is not an array, is empty, repeats an id, or names a line outside the batch.', 'Send distinct SystemIds of lines in the selected batch, or omit lineSystemIds.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Identify one existing journal batch using templateName and batchName or subject TEMPLATE|BATCH or SystemId.', 'No batch is identified, the selectors name different batches, the subject is neither TEMPLATE|BATCH nor a SystemId, the batch does not exist, or its template is not a Phys. Inventory template or is recurring.', 'Identify one existing batch of a non-recurring Phys. Inventory template with consistent selectors.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Physical Inventory domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no read permission on the Item Journal Line table.', 'Ask an administrator for a permission set that grants it, for example Bifrost Read-Only.'));
        exit(true);
    end;

    /// <summary>Returns the effect chapter of the contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is written or posted. The selected journal lines are checked and the verdict is returned.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'Bifrost Read-Only');
        Effect.Add('writes', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Calculate', 'Use it to create the journal lines before checking them.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.RecordCount', 'Use it to correct the counted quantities that the check flags.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.PreviewPost', 'Use it to see the entries a posting would create, not only the line problems.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Post', 'Use it to post the lines once the check is acceptable.'));
        exit(true);
    end;

    /// <summary>Returns the workflow chapter of the contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.RecordCount', 'Enter the counted quantities first.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Check', 'Find line problems without writing anything.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.PreviewPost', 'See the entries the posting would create.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Post', 'Post the count when the check is acceptable.'));
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
            'Check every line of the batch DEFAULT',
            '{"type":"Inventory.PhysInventory.Check","subject":"PHYS. INV.|DEFAULT"}',
            '{"status":"Success","templateName":"PHYS. INV.","batchName":"DEFAULT","validationResult":"Ready","lineCount":2,"errorCount":0,"warningCount":0,"errors":[],"warnings":[]}'));
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
        Notes := 'Read only: nothing is written, posted or rolled back. Every line of the batch, or only the lines in lineSystemIds, gets the standard item journal line checks and the physical inventory rules: the line has an item that is not blocked, is a physical inventory line, has the entry type Positive Adjmt. or Negative Adjmt., the value entry type Direct Cost and no item charge. ' +
            'A failing line is added to errors with code BusinessCentralError and parameter line N, and the check continues with the next line. A posting date after the work date is added to warnings with code InvalidLine. ' +
            'The answer is Success whatever the verdict: read validationResult (Ready, ReadyWithWarnings or NotReady), errorCount and warningCount. A batch without lines is not refused but answered NotReady with one PreconditionFailed entry in errors. ' +
            'An unidentifiable batch, a template that is not a non-recurring Phys. Inventory template, a lineSystemIds value that does not fit the batch and any key that is not declared are refused with BusinessCentralError. The Physical Inventory domain must be turned on in Inventory Setup (a missing setup row counts as on). ' +
            'Use Inventory.PhysInventory.PreviewPost to see the entries and Inventory.PhysInventory.Post to post.';
        exit(true);
    end;
}
