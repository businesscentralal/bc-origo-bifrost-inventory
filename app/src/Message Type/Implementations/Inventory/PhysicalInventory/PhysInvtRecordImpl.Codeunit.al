namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Records batched counted quantities through native Validate; omitted leaves unchanged and zero means counted zero.</summary>
codeunit 10076882 "Phys. Invt. Record Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Records counted quantities on lines of a physical inventory journal; an omitted quantity leaves the count unchanged and zero counts as counted zero.', Comment = 'is-IS=Skráir talið magn á línur í talningarbók; magn sem er sleppt skilur talninguna eftir óbreytta og núll telst talið núll.';
        SelectionLbl: Label 'Identify one existing nonrecurring Phys. Inventory journal batch using templateName/batchName or subject TEMPLATE|BATCH or SystemId. All supplied selectors must agree.', Comment = 'is-IS=Veldu eina fyrirliggjandi bókarkeyrslu af gerðinni Phys. Inventory sem er ekki ítrekunarbók, með templateName/batchName eða subject TEMPLATE|BATCH eða SystemId. Öll auðkenni verða að vísa á sömu keyrslu.';
        KeywordsLbl: Label 'enter counted quantity, record count, record physical count, set counted quantity, count lines', Comment = 'is-IS=skrá talið magn, skrá talningu, skrá birgðatalningu, setja talið magn, talningarlínur';
        OverviewLbl: Label 'Sets the counted quantity on lines of a Phys. Inventory journal batch, for both Inventory.PhysInventory.RecordCount and the legacy Inventory.PhysInventory.Record. An entry without qtyCounted leaves its line unchanged, zero is written as counted zero, and nothing is posted.', Comment = 'is-IS=Stillir talið magn á línum í bókarkeyrslu af gerðinni Phys. Inventory, bæði fyrir Inventory.PhysInventory.RecordCount og eldri gerðina Inventory.PhysInventory.Record. Færsla án qtyCounted skilur línuna eftir óbreytta, núll er skráð sem talið núll og ekkert er bókað.';

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

    /// <summary>Reclassification requests use inbound dispatch.</summary>
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
        if not LegacyLineExists(Argument) then
            exit;
        Process.SetOperation('RecordCount');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;



    /// <summary>The single-line Record form names its line by template, batch and lineNo; an unknown line is a coded refusal before any write.</summary>
    local procedure LegacyLineExists(var Argument: Record "Message Argument ori"): Boolean
    var
        ItemJournalLine: Record "Item Journal Line";
        Request: JsonObject;
        TemplateToken: JsonToken;
        BatchToken: JsonToken;
        LineToken: JsonToken;
        LineNo: Integer;
        LineNotFoundErr: Label 'Physical inventory line was not found.', Comment = 'is-IS=Lína birgðatalningar fannst ekki.';
        LineNotFoundExpectedTxt: Label 'The line number of an existing line in the journal batch.', Comment = 'is-IS=Línunúmer línu sem er til í bókarkeyrslunni.';
        LineNotFoundNextStepTxt: Label 'Check journalTemplateName, journalBatchName and lineNo, or run Inventory.PhysInventory.Calculate first.', Comment = 'is-IS=Athugaðu journalTemplateName, journalBatchName og lineNo, eða keyrðu fyrst Inventory.PhysInventory.Calculate.';
    begin
        if Argument.Type <> "Message Type ori"::"Inventory.PhysInventory.Record" then
            exit(true);
        Request := Argument.GetRequestJson();
        if not Request.Get('journalTemplateName', TemplateToken) then
            if not Request.Get('templateName', TemplateToken) then
                exit(true);
        if not Request.Get('journalBatchName', BatchToken) then
            if not Request.Get('batchName', BatchToken) then
                exit(true);
        if not Request.Get('lineNo', LineToken) then
            exit(true);
        if not (TemplateToken.IsValue() and BatchToken.IsValue() and LineToken.IsValue()) then
            exit(true);
        if not TryGetLineNo(LineToken, LineNo) then
            exit(true);
        ItemJournalLine.SetLoadFields("Line No.");
        if ItemJournalLine.Get(CopyStr(TemplateToken.AsValue().AsText(), 1, 10), CopyStr(BatchToken.AsValue().AsText(), 1, 10), LineNo) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, LineNotFoundErr, 'lineNo', Format(LineNo, 0, 9), LineNotFoundExpectedTxt, LineNotFoundNextStepTxt);
        exit(false);
    end;

    [TryFunction]
    local procedure TryGetLineNo(LineToken: JsonToken; var LineNo: Integer)
    begin
        LineNo := LineToken.AsValue().AsInteger();
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
        Children: JsonArray;
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Name of an existing Phys. Inventory journal template that is not recurring, at most 10 characters. Send it with batchName unless subject identifies the batch.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Name of an existing journal batch of that template, at most 10 characters. Every selector that is sent must name the same batch.'));
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'Alias of templateName. A value that differs from templateName, ignoring case, is refused.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'Alias of batchName. A value that differs from batchName, ignoring case, is refused.'));
        Parameter := ContractMgt.Parameter('counts', 'array', false, 'Nonempty array of counted lines. Each entry names one line of the batch and optionally the counted quantity. The lines must be distinct. Required by Inventory.PhysInventory.RecordCount; Inventory.PhysInventory.Record may send lineNo and quantity instead.');
        Clear(Children);
        Children.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Positive line number in the batch. Send lineNo or systemId; when both are sent they must name the same line.'));
        Children.Add(ContractMgt.Parameter('systemId', 'string', false, 'SystemId of the journal line, which must belong to the batch.'));
        Children.Add(ContractMgt.Parameter('qtyCounted', 'number', false, 'Counted quantity, zero or more. Zero is written as a counted zero. Omit it to leave the line unchanged.'));
        Parameter.Add('children', Children);
        Parameters.Add(Parameter);
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Inventory.PhysInventory.Record only, when counts is absent: positive line number of the line to count. Refused by Inventory.PhysInventory.RecordCount.'));
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', false, 'Inventory.PhysInventory.Record only, when counts is absent: counted quantity, zero or more. Omit it to leave the line unchanged. Refused by Inventory.PhysInventory.RecordCount.'));
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when every count was applied.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The journal template of the selected batch.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The selected journal batch.'));
        Field := ContractMgt.ResponseField('result', 'array', 'One entry per counted line, in the order of counts.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('systemId', 'string', 'SystemId of the journal line.'));
        Children.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number in the batch.'));
        Children.Add(ContractMgt.ResponseField('counted', 'boolean', 'True when qtyCounted was sent for the line; false when the line was left unchanged.'));
        Children.Add(ContractMgt.ResponseField('before', 'decimal', 'Counted quantity before the call.'));
        Children.Add(ContractMgt.ResponseField('after', 'decimal', 'Counted quantity after the call.'));
        Children.Add(ContractMgt.ResponseField('quantityCalculated', 'decimal', 'Calculated (expected) quantity of the line.'));
        Children.Add(ContractMgt.ResponseField('adjustmentQuantity', 'decimal', 'Adjustment quantity of the line after the count.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Fields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Inventory.PhysInventory.Record only: line number of the last counted line.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Inventory.PhysInventory.Record only: counted quantity of the last counted line.'));
        Fields.Add(ContractMgt.ResponseField('quantityCalculated', 'decimal', 'Inventory.PhysInventory.Record only: calculated quantity of the last counted line.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors chapter of the contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, 'A counts entry names a missing line or a line outside the selected batch.', 'Use a lineNo or systemId from the selected physical inventory batch; nothing is changed.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected journal batch does not exist.', 'Check templateName and batchName or send the SystemId of an existing physical inventory batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Inventory.PhysInventory.Record only: journalTemplateName (or templateName), journalBatchName (or batchName) and lineNo are sent in data and name a journal line that does not exist.', 'Check the batch and lineNo, or run Inventory.PhysInventory.Calculate first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Physical Inventory domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on the Item Journal Line table.', 'Ask an administrator for a permission set that grants it, for example BIFROST Full ori.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'counts must contain distinct journal lines identified by lineNo or systemId; qtyCounted must be a nonnegative number when present.', 'counts is absent, not an array or empty, an entry is not an object, a line is repeated, lineNo and systemId name different lines, or qtyCounted is negative or not a number. Nothing is changed.', 'Send a nonempty counts array of distinct lines of the batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Unsupported journal parameter %1.', 'A key is sent that this type does not read, including a key inside a counts entry, or lineNo and quantity at the top level of Inventory.PhysInventory.RecordCount.', 'Remove the key; Inventory.PhysInventory.RecordCount takes counts only.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Identify one existing journal batch using templateName and batchName or subject TEMPLATE|BATCH or SystemId.', 'No batch is identified, the selectors name different batches, the subject is neither TEMPLATE|BATCH nor a SystemId, its template is not a Phys. Inventory template or is recurring.', 'Identify one existing batch of a non-recurring Phys. Inventory template with consistent selectors.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central validation error text', 'A line is not a valid physical inventory line, or Business Central refuses the counted quantity. Every count of the call is rolled back.', 'Correct the line or the quantity named in the text and retry.'));
        exit(true);
    end;

    /// <summary>Returns the effect chapter of the contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Sets the counted quantity, Qty. (Phys. Inventory), on each line named in counts that has a qtyCounted, through the standard validation; Business Central then recalculates the adjustment quantity and entry type of the line. Lines without qtyCounted are left unchanged. Nothing is posted. The changes are committed with the answer; under Omit Commit the caller''s transaction commits instead.');
        Effect.Add('idempotent', true);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Calculate', 'Use it to create the lines of an empty batch before counting.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Check', 'Use it to find line problems after the counts are entered.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.PreviewPost', 'Use it to see the entries a posting would create.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Post', 'Use it to post the counted lines.'));
        exit(true);
    end;

    /// <summary>Returns the workflow chapter of the contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PhysInventory.Calculate', 'Create the lines of an empty batch from the expected stock.'));
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
            'Record a counted quantity of zero on line 10000',
            '{"type":"Inventory.PhysInventory.RecordCount","subject":"PHYS. INV.|DEFAULT","data":{"counts":[{"lineNo":10000,"qtyCounted":0}]}}',
            '{"status":"Success","templateName":"PHYS. INV.","batchName":"DEFAULT","result":[{"systemId":"6f1c1d2e-0000-0000-0000-000000000001","lineNo":10000,"counted":true,"before":10,"after":0,"quantityCalculated":10,"adjustmentQuantity":10}]}'));
        Examples.Add(ContractMgt.Example(
            'Legacy single-line count with Inventory.PhysInventory.Record',
            '{"type":"Inventory.PhysInventory.Record","subject":"PHYS. INV.|DEFAULT","data":{"lineNo":10000,"quantity":0}}',
            '{"status":"Success","templateName":"PHYS. INV.","batchName":"DEFAULT","result":[{"systemId":"6f1c1d2e-0000-0000-0000-000000000001","lineNo":10000,"counted":true,"before":10,"after":0,"quantityCalculated":10,"adjustmentQuantity":10}],"lineNo":10000,"quantity":0,"quantityCalculated":10}'));
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
        Notes := 'This help describes two types that share one implementation: Inventory.PhysInventory.RecordCount takes counts; the legacy type Inventory.PhysInventory.Record takes the same counts or, when counts is absent, one line as lineNo plus quantity. The two differ only where this text says so. ' +
            'Only counted quantities are written; nothing is posted. Every counts entry is validated before any line changes and the call is atomic: if one entry fails, no line is changed. An entry without qtyCounted leaves its line unchanged, and zero is written as a counted zero. The lines must be distinct lines of the batch, and each must be a valid physical inventory line. ' +
            'After the count is set Business Central recalculates the adjustment quantity (adjustmentQuantity) and the entry type of the line; result reports before, after, quantityCalculated and adjustmentQuantity per line. ' +
            'Inventory.PhysInventory.RecordCount refuses lineNo and quantity at the top level as unsupported keys. Inventory.PhysInventory.Record adds lineNo, quantity and quantityCalculated of the last counted line to the answer, and answers InvalidParameter for lineNo when data names a template, a batch and a lineNo that do not exist. Any other key is refused. ' +
            'The counts are committed with the answer; under Omit Commit the caller''s transaction commits instead. Under Omit Commit an error is raised to the caller instead of being answered with the error text. ' +
            'The Physical Inventory domain must be turned on in Inventory Setup (a missing setup row counts as on) and the caller needs write permission on the Item Journal Line table. Use Inventory.PhysInventory.Calculate first to create the lines and Inventory.PhysInventory.Check afterwards.';
        exit(true);
    end;
}
