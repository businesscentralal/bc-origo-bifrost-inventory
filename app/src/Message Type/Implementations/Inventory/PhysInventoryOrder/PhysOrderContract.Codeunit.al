namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Provides bilingual lifecycle contracts for native physical inventory orders.</summary>
codeunit 10076964 "Phys Order Contract ori"
{
    Access = Internal;

    var
        CreateDescriptionLbl: Label 'Creates a physical inventory order, calculates expected inventory with native Business Central logic and creates a recording.', Comment = 'is-IS=Stofnar birgðatalningarpöntun, reiknar væntar birgðir með staðlaðri Business Central virkni og stofnar skráningu.';
        FinishDescriptionLbl: Label 'Writes recorded quantities, finishes open recordings and finishes the physical inventory order to calculate differences.', Comment = 'is-IS=Skrifar taldar birgðir, lýkur opnum skráningum og lýkur birgðatalningarpöntun til að reikna mismun.';
        PostDescriptionLbl: Label 'Posts one finished physical inventory order and returns its posted order number. expectedCount counts orders, always one, not lines or quantity.', Comment = 'is-IS=Bókar eina lokna birgðatalningarpöntun og skilar númeri bókaðrar pöntunar. expectedCount telur pantanir, alltaf eina, en ekki línur eða magn.';
        CreateOverviewLbl: Label 'Select items explicitly with itemNoFilter. The standard calculation groups inventory by item, variant, location and bin. One recording contains the calculated lines. No inventory is posted. An empty selection refuses atomically.', Comment = 'is-IS=Veldu vörur sérstaklega með itemNoFilter. Staðlaður útreikningur flokkar birgðir eftir vöru, afbrigði, birgðageymslu og hólfi. Ein skráning inniheldur útreiknaðar línur. Engar birgðir eru bókaðar. Tómu vali er hafnað án breytinga.';
        FinishOverviewLbl: Label 'Send counts for the recordingNo and lineNo returned by Create. Quantities use the recording line unit of measure. Zero is a recorded count. All recording lines must be recorded, either in this request or earlier in Business Central. Native finishing computes differences and tracking. Nothing is posted.', Comment = 'is-IS=Sendu talningar fyrir recordingNo og lineNo sem Create skilar. Magn er í mælieiningu skráningarlínunnar. Núll telst skráð talning. Allar skráningarlínur verða að vera taldar, annaðhvort í þessari beiðni eða áður í Business Central. Stöðluð lokun reiknar mismun og rakningu. Ekkert er bókað.';
        PostOverviewLbl: Label 'Posts exactly one finished physical inventory order through native posting. expectedCount counts physical inventory order headers: one order, not its lines, recordings or units. Inventory and financial entries are permanent.', Comment = 'is-IS=Bókar nákvæmlega eina lokna birgðatalningarpöntun með staðlaðri bókun. expectedCount telur hausa birgðatalningarpantana: eina pöntun, ekki línur hennar, skráningar eða einingar. Birgða- og fjárhagsfærslur eru varanlegar.';
        NotesLbl: Label 'Requires the Physical Inventory domain and native order/recording write permissions. Post additionally requires native item posting permission. Each call is atomic, including recording updates and native posting. A native refusal rolls back that call. A finished or posted operation cannot be repeated. Use the Business Central client to prepare additional or split tracked recording lines.', Comment = 'is-IS=Krefst sviðsins Birgðatalning og staðlaðra skrifheimilda fyrir pantanir og skráningar. Post krefst einnig staðlaðrar vörubókunarheimildar. Hvert kall er óskipt, þar með taldar skráningarbreytingar og stöðluð bókun. Stöðluð höfnun afturkallar breytingar kallsins. Ekki er hægt að endurtaka aðgerð sem er lokið eða bókuð. Notaðu Business Central biðlarann til að undirbúa viðbótarlínur eða skipta skráningarlínum með rakningu.';
        ItemFilterLbl: Label 'Required Business Central Item No. filter, at most 250 characters. Only matching items are calculated.', Comment = 'is-IS=Nauðsynleg Business Central sía á vörunúmer, að hámarki 250 stafir. Aðeins vörur sem passa við síuna eru reiknaðar.';
        LocationLbl: Label 'Optional exact location code, at most 10 characters. Omitted: native calculation includes all locations.', Comment = 'is-IS=Valfrjáls nákvæmur birgðageymslukóði, að hámarki 10 stafir. Ef honum er sleppt nær staðlaður útreikningur yfir allar birgðageymslur.';
        DescriptionLbl: Label 'Optional order description, at most 100 characters.', Comment = 'is-IS=Valfrjáls lýsing pöntunar, að hámarki 100 stafir.';
        DateLbl: Label 'Posting date in YYYY-MM-DD format. Defaults to WorkDate.', Comment = 'is-IS=Bókunardagsetning á sniðinu YYYY-MM-DD. Sjálfgefið er vinnudagsetning.';
        ZeroLbl: Label 'Include zero expected quantities. Default false.', Comment = 'is-IS=Taka með núll í væntu magni. Sjálfgefið false.';
        UntransactedLbl: Label 'Include items without ledger transactions. Requires includeZero=true. Default false.', Comment = 'is-IS=Taka með vörur án bókaðra færslna. Krefst includeZero=true. Sjálfgefið false.';
        DocumentLbl: Label 'One existing physical inventory order number, at most 20 characters. Subject may supply it; both selectors must agree.', Comment = 'is-IS=Eitt fyrirliggjandi númer birgðatalningarpöntunar, að hámarki 20 stafir. Subject má tilgreina það; bæði auðkenni verða að vísa í sömu pöntun.';
        CountsLbl: Label 'Optional array of at most 1000 distinct recording lines. Omitted or empty: finish already recorded quantities. Unrecorded lines refuse the whole operation.', Comment = 'is-IS=Valfrjálst fylki með að hámarki 1000 aðgreindum skráningarlínum. Ef því er sleppt eða það er tómt er lokið með þegar skráðu magni. Ótaldar línur valda höfnun allrar aðgerðar.';
        RecordingLbl: Label 'Positive recording number belonging to the selected order.', Comment = 'is-IS=Jákvætt skráningarnúmer sem tilheyrir valinni pöntun.';
        LineLbl: Label 'Positive native recording line number belonging to recordingNo.', Comment = 'is-IS=Jákvætt staðlað skráningarlínunúmer sem tilheyrir recordingNo.';
        QuantityLbl: Label 'Required nonnegative counted quantity in the recording line unit of measure. Zero is valid.', Comment = 'is-IS=Nauðsynlegt talið magn, ekki neikvætt, í mælieiningu skráningarlínunnar. Núll er gilt.';
        SerialLbl: Label 'Optional serial number, at most 50 characters; native tracking validation applies.', Comment = 'is-IS=Valfrjálst raðnúmer, að hámarki 50 stafir; stöðluð rakningarprófun gildir.';
        LotLbl: Label 'Optional lot number, at most 50 characters; native tracking validation applies.', Comment = 'is-IS=Valfrjálst lotunúmer, að hámarki 50 stafir; stöðluð rakningarprófun gildir.';
        PackageLbl: Label 'Optional package number, at most 50 characters; native tracking validation applies.', Comment = 'is-IS=Valfrjálst pakkanúmer, að hámarki 50 stafir; stöðluð rakningarprófun gildir.';
        ExpectedCountLbl: Label 'expectedCount counts physical inventory order headers. This operation posts one order, so send 1; it does not count lines, recordings or units. Foundation confirmation policy applies.', Comment = 'is-IS=expectedCount telur hausa birgðatalningarpantana. Aðgerðin bókar eina pöntun, sendu því 1; hún telur ekki línur, skráningar eða einingar. Staðfestingarreglur Foundation gilda.';
        ChangesCreateLbl: Label 'Creates one order with calculated lines and a recording; no posting.', Comment = 'is-IS=Stofnar eina pöntun með útreiknuðum línum og skráningu; engin bókun.';
        ChangesFinishLbl: Label 'Writes recording quantities and finishes recordings and the order, calculating differences without posting.', Comment = 'is-IS=Skrifar talið magn og lýkur skráningum og pöntun og reiknar mismun án bókunar.';
        ChangesPostLbl: Label 'Permanently posts one physical inventory order with native inventory adjustments. expectedCount counts order headers: exactly one order, not lines, recordings or units.', Comment = 'is-IS=Bókar varanlega eina birgðatalningarpöntun með stöðluðum birgðaleiðréttingum. expectedCount telur pöntunarhausa: nákvæmlega eina pöntun, ekki línur, skráningar eða einingar.';
        ResponseLbl: Label 'Success returns documentNo, systemId, finished, lineCount and recordings with recordingNo and lines (lineNo, itemNo, variantCode, locationCode, binCode, quantity, recorded). Post returns documentNo, postedDocumentNo and posted=true.', Comment = 'is-IS=Við árangur er skilað documentNo, systemId, finished, lineCount og recordings með recordingNo og lines (lineNo, itemNo, variantCode, locationCode, binCode, quantity, recorded). Post skilar documentNo, postedDocumentNo og posted=true.';
        ErrorWhenLbl: Label 'Invalid input, missing order, wrong status, restricted fields, missing permissions or native calculation, tracking, recording or posting validation.', Comment = 'is-IS=Ógilt inntak, pöntun vantar, röng staða, takmarkaðir reitir, heimildir vantar eða stöðluð prófun útreiknings, rakningar, skráningar eða bókunar.';
        ErrorFixLbl: Label 'Correct the request or native order, recording and inventory setup. Read nextStep in the refusal. No partial changes are kept.', Comment = 'is-IS=Leiðréttu beiðnina eða staðlaða pöntun, skráningu og birgðauppsetningu. Lestu nextStep í höfnuninni. Engar hlutabreytingar eru vistaðar.';
        TargetLbl: Label 'The native physical inventory order number.', Comment = 'is-IS=Staðlað númer birgðatalningarpöntunar.';
        ExampleLbl: Label 'Select one item, finish its recording with the counted quantity and post one order.', Comment = 'is-IS=Veldu eina vöru, ljúktu skráningu hennar með töldu magni og bókaðu eina pöntun.';

    /// <summary>Returns a localized operation description.</summary>
    procedure Description(Operation: Text): Text[250]
    begin
        case Operation of
            'Create':
                exit(CreateDescriptionLbl);
            'Finish':
                exit(FinishDescriptionLbl);
        end;
        exit(PostDescriptionLbl);
    end;

    /// <summary>Describes the optional order subject.</summary>
    procedure Envelope(Operation: Text) Result: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        if Operation = 'Create' then
            Subject.Add('use', 'notUsed')
        else begin
            Subject.Add('use', 'optional');
            Forms.Add('document no.');
        end;
        Subject.Add('forms', Forms);
        Subject.Add('description', TargetLbl);
        Result.Add('subject', Subject);
        Result.Add('dataRequired', true);
        Result.Add('version', '1.0');
        Result.Add('contentType', 'text/json');
    end;

    /// <summary>Names the native order selectors.</summary>
    procedure Target(Operation: Text) Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Operation <> 'Create' then begin
            Result.Add(Contract.TargetEntry('subject', 'document no.', TargetLbl));
            Result.Add(Contract.TargetEntry('data.documentNo', 'document no.', TargetLbl));
        end;
    end;

    /// <summary>Declares all request keys and the one-order posting count.</summary>
    procedure Parameters(Operation: Text) Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
        Children: JsonArray;
    begin
        case Operation of
            'Create':
                begin
                    Result.Add(Contract.Parameter('itemNoFilter', 'string', true, ItemFilterLbl));
                    Result.Add(Contract.Parameter('locationCode', 'string', false, LocationLbl));
                    Result.Add(Contract.Parameter('description', 'string', false, DescriptionLbl));
                    Result.Add(Contract.Parameter('postingDate', 'string', false, DateLbl));
                    Result.Add(Contract.Parameter('includeZero', 'boolean', false, ZeroLbl));
                    Result.Add(Contract.Parameter('includeUntransacted', 'boolean', false, UntransactedLbl));
                end;
            'Finish':
                begin
                    Result.Add(Contract.Parameter('documentNo', 'string', false, DocumentLbl));
                    Children.Add(Contract.Parameter('recordingNo', 'integer', true, RecordingLbl));
                    Children.Add(Contract.Parameter('lineNo', 'integer', true, LineLbl));
                    Children.Add(Contract.Parameter('quantity', 'number', true, QuantityLbl));
                    Children.Add(Contract.Parameter('serialNo', 'string', false, SerialLbl));
                    Children.Add(Contract.Parameter('lotNo', 'string', false, LotLbl));
                    Children.Add(Contract.Parameter('packageNo', 'string', false, PackageLbl));
                    Parameter := Contract.Parameter('counts', 'array', false, CountsLbl);
                    Parameter.Add('children', Children);
                    Result.Add(Parameter);
                end;
            'Post':
                begin
                    Result.Add(Contract.Parameter('documentNo', 'string', false, DocumentLbl));
                    Result.Add(Contract.Parameter('expectedCount', 'integer', false, ExpectedCountLbl));
                end;
        end;
    end;

    /// <summary>Describes the returned native document identifiers and recordings.</summary>
    procedure Response(Operation: Text) Result: JsonObject
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', ResponseLbl));
        Fields.Add(Contract.ResponseField('documentNo', 'string', DocumentLbl));
        if Operation = 'Post' then begin
            Fields.Add(Contract.ResponseField('postedDocumentNo', 'string', ResponseLbl));
            Fields.Add(Contract.ResponseField('posted', 'boolean', ResponseLbl));
        end else begin
            Fields.Add(Contract.ResponseField('systemId', 'string', ResponseLbl));
            Fields.Add(Contract.ResponseField('finished', 'boolean', ResponseLbl));
            Fields.Add(Contract.ResponseField('lineCount', 'integer', ResponseLbl));
            Fields.Add(Contract.ResponseField('recordings', 'array', ResponseLbl));
        end;
        Result.Add('fields', Fields);
    end;

    /// <summary>Lists typed refusals and the native rollback refusal.</summary>
    procedure Errors(Operation: Text) Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidLine, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BlockedByWriteGuard, ErrorWhenLbl, ErrorFixLbl));
        Result.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ErrorWhenLbl, ErrorFixLbl));
    end;

    /// <summary>Distinguishes reversible document preparation from permanent posting.</summary>
    procedure Effect(Operation: Text) Result: JsonObject
    begin
        if Operation = 'Post' then begin
            Result.Add('effect', 'irreversible');
            Result.Add('changes', ChangesPostLbl);
        end else begin
            Result.Add('effect', 'write');
            if Operation = 'Create' then
                Result.Add('changes', ChangesCreateLbl)
            else
                Result.Add('changes', ChangesFinishLbl);
        end;
        Result.Add('writes', true);
        Result.Add('posts', Operation = 'Post');
        Result.Add('idempotent', false);
        Result.Add('permissionSet', 'BIFROST Full ori');
    end;

    /// <summary>Links the three lifecycle stages.</summary>
    procedure Related(Operation: Text) Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Result.Add(Contract.RelatedEntry('Inventory.PhysInventoryOrder.Create', CreateDescriptionLbl));
        Result.Add(Contract.RelatedEntry('Inventory.PhysInventoryOrder.Finish', FinishDescriptionLbl));
        Result.Add(Contract.RelatedEntry('Inventory.PhysInventoryOrder.Post', PostDescriptionLbl));
    end;

    /// <summary>Provides a request example for each lifecycle stage.</summary>
    procedure Examples(Operation: Text) Result: JsonArray
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        case Operation of
            'Create':
                Result.Add(Contract.Example(ExampleLbl, '{"type":"Inventory.PhysInventoryOrder.Create","data":{"itemNoFilter":"1000"}}', '{"status":"Success","documentNo":"PI0001","finished":false,"lineCount":1,"recordings":[{"recordingNo":1,"lines":[{"lineNo":10000,"itemNo":"1000","quantity":0,"recorded":false}]}]}'));
            'Finish':
                Result.Add(Contract.Example(ExampleLbl, '{"type":"Inventory.PhysInventoryOrder.Finish","data":{"documentNo":"PI0001","counts":[{"recordingNo":1,"lineNo":10000,"quantity":8}]}}', '{"status":"Success","documentNo":"PI0001","finished":true}'));
            'Post':
                Result.Add(Contract.Example(ExampleLbl, '{"type":"Inventory.PhysInventoryOrder.Post","data":{"documentNo":"PI0001","expectedCount":1}}', '{"status":"Success","documentNo":"PI0001","postedDocumentNo":"PPI0001","posted":true}'));
        end;
    end;

    /// <summary>Explains the lifecycle sequence.</summary>
    procedure Workflow(Operation: Text) Result: JsonObject
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Inventory.PhysInventoryOrder.Create', CreateDescriptionLbl));
        Steps.Add(Contract.WorkflowStep('Inventory.PhysInventoryOrder.Finish', FinishDescriptionLbl));
        Steps.Add(Contract.WorkflowStep('Inventory.PhysInventoryOrder.Post', PostDescriptionLbl));
        Result.Add('steps', Steps);
    end;

    /// <summary>Explains native calculation, recording and posting behavior.</summary>
    procedure Overview(Operation: Text): Text
    begin
        case Operation of
            'Create':
                exit(CreateOverviewLbl);
            'Finish':
                exit(FinishOverviewLbl);
        end;
        exit(PostOverviewLbl);
    end;

    /// <summary>Explains permission, rollback and tracking boundaries.</summary>
    procedure Notes(Operation: Text): Text
    begin
        exit(NotesLbl);
    end;
}
