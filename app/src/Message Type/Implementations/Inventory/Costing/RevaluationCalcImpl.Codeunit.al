namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Populates an empty revaluation journal using native Calculate Inventory Value report 5899.</summary>
codeunit 70013488 "Revaluation Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Populates an empty revaluation journal using native Calculate Inventory Value report 5899.', Comment = 'is-IS=Fyllir tóma endurmatsbók með innbyggðri keyrslu 5899 til útreiknings birgðavirðis.';
        SelectionLbl: Label 'Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        KeywordsLbl: Label 'inventory,revaluation,inventory value,calculate,preview,post', Comment = 'is-IS=birgðir,endurmat,birgðavirði,reikna,forskoða,bóka';
        OverviewLbl: Label 'Populates an empty revaluation journal using native Calculate Inventory Value report 5899. Identify an existing nonrecurring Revaluation batch. Subject TEMPLATE|BATCH or SystemId takes precedence; otherwise use one SystemId alias or templateName/batchName. A SystemId alias precedes the name pair.', Comment = 'is-IS=Fyllir tóma endurmatsbók með innbyggðri keyrslu 5899 til útreiknings birgðavirðis. Auðkenndu fyrirliggjandi endurmatskeyrslu sem er ekki ítrekunarbók. subject TEMPLATE|BATCH eða SystemId hefur forgang; annars skal nota eitt SystemId auðkenni eða templateName/batchName. SystemId auðkenni hefur forgang yfir nafnaparið.';
        NotesLbl: Label 'Calculate requires postingDate and documentNo and refuses a nonempty batch. calculatePer defaults to Item Ledger Entry; byLocation/byVariant require Item. Calculation never updates Standard Cost or posts entries. Normal licensing and company domain gates apply.', Comment = 'is-IS=Útreikningur krefst postingDate og documentNo og hafnar keyrslu sem er ekki tóm. calculatePer er sjálfgefið Item Ledger Entry; byLocation/byVariant krefjast Item. Útreikningur uppfærir aldrei staðlað kostnaðarverð og bókar engar færslur. Venjulegar leyfis- og fyrirtækisheimildir gilda.';

    /// <summary>Requires company Costing, native journal writes.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::Costing, Database::"Item Journal Line", true, false));
    end;

    /// <summary>Returns the batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Revaluation requests use inbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Journal Line", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv Reval Calc Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv Reval Calc Process ori", Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;

    /// <summary>Returns the native revaluation envelope contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|BATCH","systemId"]},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the native revaluation target contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[{"table":"Item Journal Batch","selection":"An explicitly identified Revaluation template batch."}]');
        exit(true);
    end;

    /// <summary>Returns the native revaluation parameters contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Existing Revaluation template, at most 10 characters; supply with batchName if no subject or SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Existing batch, at most 10 characters. Subject or SystemId selection takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('batchId', 'string', false, 'Batch SystemId; only one SystemId alias may be supplied when subject is absent.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias of batchId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias of batchId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias of batchId.'));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Native item-number filter, at most 2048 characters; omit for all eligible items.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Native Location Filter, at most 2048 characters.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Native Variant Filter, at most 2048 characters.'));
        Parameters.Add(ContractMgt.Parameter('postingDate', 'date', true, 'Required nonzero ISO accounting date for the calculated lines.'));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'Required nonempty document number, at most 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('calculatePer', 'string', false, 'Item Ledger Entry (default) or Item; case-insensitive.'));
        Parameters.Add(ContractMgt.Parameter('byLocation', 'boolean', false, 'Group by location only with calculatePer=Item; default false.'));
        Parameters.Add(ContractMgt.Parameter('byVariant', 'boolean', false, 'Group by variant only with calculatePer=Item; default false.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success for a completed native operation.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The resolved native journal template.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The resolved native journal batch.'));
        Fields.Add(ContractMgt.ResponseField('linesCreated', 'integer', 'Number of journal lines created by the native calculation.'));
        Fields.Add(ContractMgt.ResponseField('totalQuantity', 'decimal', 'Total native journal quantity.'));
        Fields.Add(ContractMgt.ResponseField('calculatedValue', 'decimal', 'Calculated inventory value from the native proposal.'));
        Fields.Add(ContractMgt.ResponseField('revaluedValue', 'decimal', 'Revalued inventory value from the native proposal.'));
        Fields.Add(ContractMgt.ResponseField('posted', 'boolean', 'False: calculation does not post the journal.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the native revaluation errors contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.TextErrorEntry('Native selection, validation or report error.','Wrong journal type, recurring or invalid batch, or native calculation/posting failure. The direct native call may raise; the process wrapper returns text without a typed code.','Correct the selected batch, input or native validation error before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Company/native permission or posting gate refuses caller.', 'Request the required native permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Company Costing is disabled or a typed request value is invalid.', 'Enable the company domain or correct the request value.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'postingDate is missing.', 'Supply a nonzero ISO accounting date.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A date, decimal or Boolean request value has the wrong format.', 'Use ISO dates, invariant decimals and JSON Booleans.'));
        exit(true);
    end;

    /// <summary>Returns the native revaluation effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"writes":true,"posts":false,"rollback":false,"changes":"Populates an empty revaluation journal using native Calculate Inventory Value report 5899."}');
        exit(true);
    end;

    /// <summary>Returns the native revaluation related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.Revaluation.Post","useInsteadWhen":"Post the journal."},{"name":"Inventory.Revaluation.PreviewPost","useInsteadWhen":"PreviewPost the journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native revaluation examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Populates an empty revaluation journal using native Calculate Inventory Value report 5899.","request":{"type":"Inventory.Revaluation.Calculate","subject":"REVAL|OWNED","data":{"itemNo":"OWNED-ITEM","postingDate":"2026-10-14","documentNo":"OWNED-REVAL"}}}]');
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

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes native revaluation behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains native revaluation constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := NotesLbl;
        exit(true);
    end;
}
