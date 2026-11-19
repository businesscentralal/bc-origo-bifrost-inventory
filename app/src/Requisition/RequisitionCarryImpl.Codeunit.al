namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Requisition;
using Origo.Bifrost;

/// <summary>Creates new orders from selected requisition worksheet lines.</summary>
codeunit 10076942 "Requisition Carry Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Creates new orders from selected requisition worksheet lines.', Comment = 'is-IS=Stofnar nýjar pantanir úr völdum línum innkaupavinnublaðs.';
        SelectionLbl: Label 'Use templateName and batchName to select one non-recurring requisition worksheet.', Comment = 'is-IS=Notaðu templateName og batchName til að velja eitt innkaupavinnublað sem er ekki ítrekunarblað.';
        KeywordsLbl: Label 'purchase,requisition,worksheet,planning,orders', Comment = 'is-IS=innkaup,innkaupabeiðni,vinnublað,áætlanagerð,pantanir';
        NotesLbl: Label 'Consumes selected new purchase or transfer suggestions to create new orders. Rejects Cancel, change, reschedule and existing-document links before any write. expectedCount counts worksheet selections: always 1, not the number of lines or orders. No printing or posting.', Comment = 'is-IS=Notar valdar nýjar innkaupa- eða millifærslutillögur til að stofna nýjar pantanir. Afturköllun, breytingum, endurtímasetningu og tengingum við fyrirliggjandi skjöl er hafnað áður en skrif hefjast. expectedCount telur val á vinnublaði: alltaf 1, ekki fjölda lína eða pantana. Hvorki prentar né bókar.';
        ExpectedCountLbl: Label 'expectedCount counts worksheet selections: always 1, not the number of lines or orders. Send 1 before carry-out when confirmation is enabled.', Comment = 'is-IS=expectedCount telur val á vinnublaði: alltaf 1, ekki fjölda lína eða pantana. Sendu 1 áður en aðgerðin er framkvæmd þegar staðfesting er virk.';
        NativeNextLbl: Label 'Correct the native worksheet or item setup described by the error and retry; the failed call saved no changes.', Comment = 'is-IS=Leiðréttu uppsetningu vinnublaðs eða vöru samkvæmt villunni og reyndu aftur; engar breytingar voru vistaðar úr misheppnaða kallinu.';

    /// <summary>Checks native worksheet and order permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        Worksheet: Codeunit "Requisition Worksheet ori";
    begin
        exit(Worksheet.IsEnabled(true));
    end;

    /// <summary>Returns the native worksheet selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Requisition Wksh. Name");
    end;

    /// <summary>Declares inbound dispatch for the worksheet write.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs native processing atomically and returns actionable native failures.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Process: Codeunit "Requisition Process ori";
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Process.SetOperation('CarryOut');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NativeNextLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[]},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Names the worksheet target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.templateName, data.batchName', 'worksheet', SelectionLbl));
        exit(true);
    end;

    /// <summary>Lists supported request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        LineNumbers: JsonObject;
        LineNumber: JsonObject;
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', true, 'Existing non-recurring Requisition template; at most 10 characters.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', true, 'Existing worksheet name in that template; at most 10 characters.'));
        LineNumbers := ContractMgt.Parameter('lineNos', 'array', false, 'Optional nonempty array of up to 500 distinct existing positive line numbers. Omit to select every worksheet line.');
        LineNumber.Add('type', 'integer');
        LineNumber.Add('description', 'An existing positive worksheet line number; each number may appear only once.');
        LineNumbers.Add('items', LineNumber);
        Parameters.Add(LineNumbers);
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', false, ExpectedCountLbl));
        exit(true);
    end;

    /// <summary>Lists response fields.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'Resolved worksheet template.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'Resolved worksheet name.'));
        Fields.Add(ContractMgt.ResponseField('linesCarriedOut', 'integer', 'Number of selected lines consumed.'));
        Fields.Add(ContractMgt.ResponseField('purchaseOrders', 'array', 'New purchase orders as objects with orderNo.'));
        Fields.Add(ContractMgt.ResponseField('transferOrders', 'array', 'New transfer orders as objects with orderNo.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Documents coded refusals and their recovery.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required worksheet selector or date is absent.', 'Supply the named parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A parameter, date range, line selection or template is invalid.', 'Use a non-recurring Requisition template without automatic batch renaming and correct the named parameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The worksheet or a selected line does not exist.', 'Select an existing worksheet and line numbers.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selection is empty or contains an unsafe action or existing-document link.', 'Select only new purchase or transfer suggestions without existing-document links.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Native worksheet or order permissions are missing.', 'Ask an administrator for native worksheet and order permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native calculation or order creation failed.', NativeNextLbl));
        exit(true);
    end;

    /// <summary>Declares the actual write and confirmation unit in both languages.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'irreversible');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('idempotent', false);
        Effect.Add('changes', NotesLbl);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add(SelectionLbl);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Returns the companion operation.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Purchase.Requisition.Calculate', 'Use the companion worksheet operation.'));
        exit(true);
    end;

    /// <summary>Shows a worksheet request.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ParameterExample1Lbl: Label 'Select existing line numbers from your own document or worksheet', Comment = 'is-IS=Velja fyrirliggjandi línunúmer úr eigin skjali eða vinnublaði';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example('Process one requisition worksheet', '{"type":"Purchase.Requisition.CarryOut","data":{"expectedCount":1,"templateName":"REQ","batchName":"DEFAULT"}}', '{"status":"Success"}'));
        Examples.Add(ContractMgt.Example(ParameterExample1Lbl, '{"type":"Purchase.Requisition.CarryOut","data":{"expectedCount":1,"templateName":"REQ","batchName":"DEFAULT","lineNos":[10000]}}', '{"status":"Success"}'));
        exit(true);
    end;

    /// <summary>Uses Foundation defaults.</summary>
    procedure GetMetering(var Value: JsonObject): Boolean
    begin
        Clear(Value);
        exit(false);
    end;

    /// <summary>Explains how to calculate suggestions and create new orders from them.</summary>
    procedure GetWorkflow(var Value: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Value);
        Steps.Add(ContractMgt.WorkflowStep('Purchase.Requisition.Calculate', 'Calculate suggestions in the selected worksheet and inspect the returned lines.'));
        Steps.Add(ContractMgt.WorkflowStep('Purchase.Requisition.CarryOut', 'Create new purchase or transfer orders from the reviewed suggestions with expectedCount 1.'));
        Value.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains native scope and safety boundaries.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := NotesLbl;
        exit(true);
    end;

    /// <summary>Explains native scope and safety boundaries.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := NotesLbl;
        exit(true);
    end;
}
