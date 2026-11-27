namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Bilingual contracts shared by the two standard cost worksheet operations.</summary>
codeunit 10076936 "Std. Cost Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";

    /// <summary>Describes the actual writes made by the operation.</summary>
    procedure Description(Implement: Boolean): Text
    var
        SuggestLbl: Label 'Suggests standard costs for filtered items in a standard cost worksheet.', Comment = 'is-IS=Leggur til staðalkostnað fyrir síaðar vörur í staðalkostnaðarvinnublaði. (staðalkostnaður, leiðréttingarstuðull, endurmat).';
        ImplementLbl: Label 'Updates item and SKU standard costs and creates unposted revaluation journal lines from a worksheet.', Comment = 'is-IS=Uppfærir staðalkostnað vara og birgðahaldseininga og stofnar óbókaðar endurmatsbókarlínur úr vinnublaði. (staðalkostnaður, leiðréttingarstuðull).';
    begin
        if Implement then
            exit(ImplementLbl);
        exit(SuggestLbl);
    end;

    /// <summary>Localized discovery terms.</summary>
    procedure Keywords(): Text
    var
        KeywordsLbl: Label 'standard cost, worksheet, adjustment factor, revaluation', Comment = 'is-IS=staðalkostnaður, vinnublað, leiðréttingarstuðull, endurmat';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Envelope with no subject; all selectors are in data.</summary>
    procedure GetEnvelope(var Envelope: JsonObject; Implement: Boolean): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
        SubjectLbl: Label 'Subject is not used. Select the worksheet with data.worksheetName.', Comment = 'is-IS=Subject er ekki notað. Veldu vinnublaðið með data.worksheetName.';
    begin
        Clear(Envelope);
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', SubjectLbl);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Worksheet selector.</summary>
    procedure GetTarget(var Target: JsonArray; Implement: Boolean): Boolean
    var
        TargetLbl: Label 'An existing standard cost worksheet name.', Comment = 'is-IS=Heiti staðalkostnaðarvinnublaðs sem er til.';
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.worksheetName', 'string', TargetLbl));
        exit(true);
    end;

    /// <summary>All accepted parameters; unknown parameters are refused.</summary>
    procedure GetParameters(var Parameters: JsonArray; Implement: Boolean): Boolean
    var
        WorksheetLbl: Label 'Existing worksheet name, at most 10 characters.', Comment = 'is-IS=Heiti vinnublaðs sem er til, mest 10 stafir.';
        FilterLbl: Label 'Required Business Central filter on Item No., at most 2048 characters. Only Inventory items with Standard costing are selected. Blocked selected items are refused.', Comment = 'is-IS=Áskilin Business Central sía á vörunúmer, mest 2048 stafir. Aðeins birgðavörur með staðalkostnað eru valdar. Völdum lokuðum vörum er hafnað.';
        FactorLbl: Label 'Positive JSON number multiplying the current item standard cost, rounded to five decimal places. Indirect cost and overhead rate retain factor 1.', Comment = 'is-IS=Jákvæð JSON-tala sem margfaldar núverandi staðalkostnað vöru, námunduð að fimm aukastöfum. Óbeinn kostnaður og kostnaðarauki halda stuðlinum 1.';
        TemplateLbl: Label 'Existing Revaluation journal template, at most 10 characters.', Comment = 'is-IS=Sniðmát endurmatsbókar sem er til, mest 10 stafir.';
        BatchLbl: Label 'Existing empty batch under the selected template, at most 10 characters. Any existing line causes refusal.', Comment = 'is-IS=Tóm keyrsla sem er til undir völdu sniðmáti, mest 10 stafir. Fyrirliggjandi lína veldur höfnun.';
        DateLbl: Label 'Required revaluation posting date as yyyy-mm-dd. It does not post the journal.', Comment = 'is-IS=Áskilin bókunardagsetning endurmats sem yyyy-mm-dd. Bókin er ekki bókuð.';
        DocumentLbl: Label 'Document number for new journal lines, at most 20 characters.', Comment = 'is-IS=Fylgiskjalsnúmer fyrir nýjar bókarlínur, mest 20 stafir.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('worksheetName', 'string', true, WorksheetLbl));
        if Implement then begin
            Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, TemplateLbl));
            Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, BatchLbl));
            Parameters.Add(ContractMgt.Parameter('postingDate', 'string', true, DateLbl));
            Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, DocumentLbl));
        end else begin
            Parameters.Add(ContractMgt.Parameter('itemFilter', 'string', true, FilterLbl));
            Parameters.Add(ContractMgt.Parameter('adjustmentFactor', 'decimal', true, FactorLbl));
        end;
        exit(true);
    end;

    /// <summary>Response fields and nested line fields.</summary>
    procedure GetResponse(var Response: JsonObject; Implement: Boolean): Boolean
    var
        Fields: JsonArray;
        Children: JsonArray;
        Lines: JsonObject;
        StatusLbl: Label 'Success for a completed operation; refusals use the standard error envelope.', Comment = 'is-IS=Success fyrir lokna aðgerð; höfnun notar staðlað villuumslag.';
        WorksheetLbl: Label 'Selected worksheet name.', Comment = 'is-IS=Heiti valins vinnublaðs.';
        CountLbl: Label 'Number of returned lines.', Comment = 'is-IS=Fjöldi lína í svari.';
        LinesLbl: Label 'Only the suggested worksheet lines or newly created journal lines.', Comment = 'is-IS=Aðeins tillögulínur vinnublaðs eða nýstofnaðar bókarlínur.';
        PostedLbl: Label 'Always false. Posting remains a separate Inventory.Revaluation.Post call.', Comment = 'is-IS=Alltaf false. Bókun fer fram í sérstöku Inventory.Revaluation.Post kalli.';
        ItemLbl: Label 'Item number.', Comment = 'is-IS=Vörunúmer.';
        CostLbl: Label 'Current item standard cost before suggestion.', Comment = 'is-IS=Núverandi staðalkostnaður vöru fyrir tillögu.';
        NewCostLbl: Label 'Suggested standard cost.', Comment = 'is-IS=Tillaga að staðalkostnaði.';
        ImplementedLbl: Label 'Whether the worksheet line has been implemented.', Comment = 'is-IS=Hvort lína vinnublaðs hefur verið framkvæmd.';
        TemplateLbl: Label 'Revaluation journal template.', Comment = 'is-IS=Sniðmát endurmatsbókar.';
        BatchLbl: Label 'Revaluation journal batch.', Comment = 'is-IS=Keyrsla endurmatsbókar.';
        LineNoLbl: Label 'Actual journal line number.', Comment = 'is-IS=Raunverulegt línunúmer bókar.';
        DateLbl: Label 'Posting date as yyyy-mm-dd.', Comment = 'is-IS=Bókunardagsetning sem yyyy-mm-dd.';
        DocumentLbl: Label 'Document number.', Comment = 'is-IS=Fylgiskjalsnúmer.';
        QuantityLbl: Label 'Native revaluation quantity.', Comment = 'is-IS=Magn endurmats samkvæmt Business Central.';
        UnitLbl: Label 'Proposed revalued unit cost.', Comment = 'is-IS=Tillaga að endurmetnum einingarkostnaði.';
        ValueLbl: Label 'Proposed revalued inventory value.', Comment = 'is-IS=Tillaga að endurmetnu birgðavirði.';
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('worksheetName', 'string', WorksheetLbl));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', CountLbl));
        Fields.Add(ContractMgt.ResponseField('posted', 'boolean', PostedLbl));
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', ItemLbl));
        if Implement then begin
            Children.Add(ContractMgt.ResponseField('journalTemplateName', 'string', TemplateLbl));
            Children.Add(ContractMgt.ResponseField('journalBatchName', 'string', BatchLbl));
            Children.Add(ContractMgt.ResponseField('lineNo', 'integer', LineNoLbl));
            Children.Add(ContractMgt.ResponseField('postingDate', 'string', DateLbl));
            Children.Add(ContractMgt.ResponseField('documentNo', 'string', DocumentLbl));
            Children.Add(ContractMgt.ResponseField('quantity', 'decimal', QuantityLbl));
            Children.Add(ContractMgt.ResponseField('unitCostRevalued', 'decimal', UnitLbl));
            Children.Add(ContractMgt.ResponseField('inventoryValueRevalued', 'decimal', ValueLbl));
        end else begin
            Children.Add(ContractMgt.ResponseField('standardCost', 'decimal', CostLbl));
            Children.Add(ContractMgt.ResponseField('newStandardCost', 'decimal', NewCostLbl));
            Children.Add(ContractMgt.ResponseField('implemented', 'boolean', ImplementedLbl));
        end;
        Lines := ContractMgt.ResponseField('lines', 'array', LinesLbl);
        Lines.Add('children', Children);
        Fields.Add(Lines);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Refusal codes and recovery guidance.</summary>
    procedure GetErrors(var Errors: JsonArray; Implement: Boolean): Boolean
    var
        MissingLbl: Label 'A required text parameter is missing or empty.', Comment = 'is-IS=Áskilin textafæribreyta vantar eða er tóm.';
        FormatLbl: Label 'A parameter has the wrong JSON type, an invalid filter or a non-ISO date.', Comment = 'is-IS=Færibreyta hefur ranga JSON-gerð, ógilda síu eða dagsetningu sem er ekki á ISO-formi.';
        InvalidLbl: Label 'A value is too long, the factor is not positive, the journal type is wrong, or Costing is disabled.', Comment = 'is-IS=Gildi er of langt, stuðull er ekki jákvæður, gerð bókar er röng eða kostnaðarsviðið er óvirkt.';
        UnknownLbl: Label 'The request includes an unknown parameter.', Comment = 'is-IS=Beiðnin inniheldur óþekkta færibreytu.';
        MissingRecordLbl: Label 'A worksheet, matching item, journal template or batch does not exist.', Comment = 'is-IS=Vinnublað, samsvarandi vara, bókarsniðmát eða keyrsla er ekki til.';
        PreconditionLbl: Label 'The batch is not empty, the worksheet is empty or already implemented, or a selected line is not an unblocked Standard-cost inventory item.', Comment = 'is-IS=Keyrslan er ekki tóm, vinnublaðið er tómt eða þegar framkvæmt, eða valin lína er ekki ólokuð birgðavara með staðalkostnað.';
        PermissionLbl: Label 'Native read or write permissions are missing.', Comment = 'is-IS=Les- eða skrifheimildir Business Central vantar.';
        NativeLbl: Label 'Business Central rejected the operation. No writes from the failed call are saved.', Comment = 'is-IS=Business Central hafnaði aðgerðinni. Engar breytingar úr misheppnuðu kalli eru vistaðar.';
        RequestNextLbl: Label 'Correct the parameter using this help and retry.', Comment = 'is-IS=Leiðréttu færibreytuna samkvæmt þessari hjálp og reyndu aftur.';
        RecordNextLbl: Label 'Choose existing records or create the missing setup in Business Central.', Comment = 'is-IS=Veldu færslur sem eru til eða stofnaðu uppsetninguna sem vantar í Business Central.';
        PreconditionsNextLbl: Label 'Review the worksheet and use an empty Revaluation batch with unimplemented item lines.', Comment = 'is-IS=Yfirfarðu vinnublaðið og notaðu tóma endurmatskeyrslu með óframkvæmdum vörulínum.';
        PermissionNextLbl: Label 'Ask an administrator for the required Bifrost and native table permissions.', Comment = 'is-IS=Biddu kerfisstjóra um nauðsynlegar Bifrost-heimildir og töfluheimildir Business Central.';
        NativeNextLbl: Label 'Correct the reported Business Central error and retry.', Comment = 'is-IS=Leiðréttu tilgreinda Business Central villu og reyndu aftur.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingLbl, RequestNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatLbl, RequestNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidLbl, RequestNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownLbl, RequestNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, MissingRecordLbl, RecordNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionLbl, PreconditionsNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionLbl, PermissionNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeLbl, NativeNextLbl));
        exit(true);
    end;

    /// <summary>These are unposted writes, including item and SKU updates during implementation.</summary>
    procedure GetEffect(var Effect: JsonObject; Implement: Boolean): Boolean
    var
        Preconditions: JsonArray;
        PreconditionsLbl: Label 'Costing is enabled and the caller has native read/write permissions on all affected records.', Comment = 'is-IS=Kostnaðarsviðið er virkt og kallandi hefur les- og skrifheimildir á allar færslur sem verða fyrir áhrifum.';
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', Description(Implement));
        Effect.Add('idempotent', not Implement);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add(PreconditionsLbl);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Related review and posting operations.</summary>
    procedure GetRelated(var Related: JsonArray; Implement: Boolean): Boolean
    var
        SuggestLbl: Label 'Suggest worksheet lines before implementation.', Comment = 'is-IS=Leggðu til línur vinnublaðs fyrir framkvæmd.';
        ImplementLbl: Label 'Implement reviewed worksheet lines into an empty revaluation batch.', Comment = 'is-IS=Framkvæmdu yfirfarnar línur vinnublaðs í tómri endurmatskeyrslu.';
        PreviewLbl: Label 'Preview the generated journal before posting it.', Comment = 'is-IS=Forskoðaðu myndaða bók áður en hún er bókuð.';
        PostLbl: Label 'Post the generated revaluation journal as a separate guarded operation.', Comment = 'is-IS=Bókaðu myndaða endurmatsbók sem sérstaka varða aðgerð.';
    begin
        Clear(Related);
        if Implement then
            Related.Add(ContractMgt.RelatedEntry('Inventory.StandardCost.Suggest', SuggestLbl))
        else
            Related.Add(ContractMgt.RelatedEntry('Inventory.StandardCost.Implement', ImplementLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.PreviewPost', PreviewLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Post', PostLbl));
        exit(true);
    end;

    /// <summary>Explicit suggestion, implementation and review/post workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject; Implement: Boolean): Boolean
    var
        Steps: JsonArray;
        SuggestLbl: Label 'Suggest and review standard cost worksheet lines.', Comment = 'is-IS=Leggðu til og yfirfarðu línur staðalkostnaðarvinnublaðs.';
        ImplementLbl: Label 'Update item costs and generate unposted revaluation journal lines.', Comment = 'is-IS=Uppfærðu vörukostnað og myndaðu óbókaðar endurmatsbókarlínur.';
        PreviewLbl: Label 'Preview the generated journal before posting.', Comment = 'is-IS=Forskoðaðu myndaða bók fyrir bókun.';
        PostLbl: Label 'Post the reviewed revaluation journal in a separate call.', Comment = 'is-IS=Bókaðu yfirfarna endurmatsbók í sérstöku kalli.';
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.StandardCost.Suggest', SuggestLbl));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.StandardCost.Implement', ImplementLbl));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Revaluation.PreviewPost', PreviewLbl));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Revaluation.Post', PostLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples use separately prepared worksheet and journal names.</summary>
    procedure GetExamples(var Examples: JsonArray; Implement: Boolean): Boolean
    var
        ExampleLbl: Label 'Use an existing TEST worksheet and your own item or empty revaluation journal batch.', Comment = 'is-IS=Notaðu TEST vinnublað sem er til og eigin vöru eða tóma endurmatsbókarkeyrslu.';
    begin
        Clear(Examples);
        if Implement then
            Examples.Add(ContractMgt.Example(ExampleLbl,
                '{"type":"Inventory.StandardCost.Implement","data":{"worksheetName":"TEST","journalTemplateName":"REVAL","journalBatchName":"TEST","postingDate":"2026-11-16","documentNo":"STD-001"}}',
                '{"status":"Success","worksheetName":"TEST","lineCount":0,"lines":[],"posted":false}'))
        else
            Examples.Add(ContractMgt.Example(ExampleLbl,
                '{"type":"Inventory.StandardCost.Suggest","data":{"worksheetName":"TEST","itemFilter":"1000","adjustmentFactor":1.1}}',
                '{"status":"Success","worksheetName":"TEST","lineCount":1,"lines":[{"itemNo":"1000","standardCost":10,"newStandardCost":11,"implemented":false}],"posted":false}'));
        exit(true);
    end;

    /// <summary>Localized overview.</summary>
    procedure GetOverview(var Overview: Text; Implement: Boolean): Boolean
    begin
        Overview := Description(Implement);
        exit(true);
    end;

    /// <summary>Documents native side effects, selection limits and the zero-stock edge case.</summary>
    procedure GetNotes(var Notes: Text; Implement: Boolean): Boolean
    var
        SuggestLbl: Label 'Runs Suggest Item Standard Cost for the selected Standard-cost inventory items. Existing selected worksheet lines are refreshed from item card costs; other lines stay unchanged. The factor affects standard cost only. It writes worksheet lines but does not change item costs or post.', Comment = 'is-IS=Keyrir tillögu að staðalkostnaði fyrir valdar birgðavörur með staðalkostnað. Völdum fyrirliggjandi línum vinnublaðs er endurnýjað úr kostnaði vöruspjalds; aðrar línur haldast óbreyttar. Stuðullinn hefur aðeins áhrif á staðalkostnað. Skrifar línur vinnublaðs en breytir ekki vörukostnaði og bókar ekki.';
        ImplementLbl: Label 'Runs Implement Standard Cost Change for all item lines in the worksheet. It updates item costs and cost shares, updates SKU standard costs according to Manufacturing Setup, marks lines implemented, and calculates native revaluation journal lines. Zero-stock items can update costs without generating a journal line. Already implemented or non-item lines are refused. No ledger entries are posted. Review the resulting journal and use Inventory.Revaluation.PreviewPost or Inventory.Revaluation.Post separately.', Comment = 'is-IS=Keyrir framkvæmd staðalkostnaðarbreytinga fyrir allar vörulínur vinnublaðsins. Uppfærir vörukostnað og kostnaðarhluta, uppfærir staðalkostnað birgðahaldseininga samkvæmt framleiðsluuppsetningu, merkir línur framkvæmdar og reiknar endurmatsbókarlínur. Vörur án birgða geta fengið uppfærðan kostnað án nýrrar bókarlínu. Þegar framkvæmdum línum og línum sem eru ekki vörur er hafnað. Engar fjárhagsfærslur eru bókaðar. Yfirfarðu bókina og notaðu Inventory.Revaluation.PreviewPost eða Inventory.Revaluation.Post sérstaklega.';
    begin
        if Implement then
            Notes := ImplementLbl
        else
            Notes := SuggestLbl;
        exit(true);
    end;
}
