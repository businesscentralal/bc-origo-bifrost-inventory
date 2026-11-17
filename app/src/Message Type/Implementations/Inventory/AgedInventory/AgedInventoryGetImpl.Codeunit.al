namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.AgedInventory.Get. Reads the remaining quantity and value of open positive item ledger entries
/// per age bucket and item, the way the Item Age Composition - Qty. and - Value reports do. Does not write.
/// </summary>
codeunit 10076948 "Aged Inventory Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads stock quantity and value per age bucket for each item, like the Item Age Composition reports.', Comment = 'is-IS=Les birgðamagn og birgðavirði í aldursflokkum fyrir hverja vöru, eins og skýrslurnar Aldurssamsetning vöru.';
        SelectionLbl: Label 'Returns one row per item with stock: remaining quantity and value in five age buckets, counted back from the ending date.', Comment = 'is-IS=Skilar einni línu fyrir hverja vöru með birgðir: eftirstandandi magn og virði í fimm aldursflokkum, talið aftur frá lokadagsetningu.';
        KeywordsLbl: Label 'aged inventory, stock age, item age composition', Comment = 'is-IS=aldursgreining birgða,aldur birgða,aldurssamsetning vöru';
        OverviewLbl: Label 'Reads the age of stock: remaining quantity and value per age bucket and item, paged and read only.', Comment = 'is-IS=Les aldur birgða: eftirstandandi magn og virði í aldursflokki og vöru, síðuskipt og aðeins til lestrar.';
        NotesLbl: Label 'Age is counted from the posting date of each open positive item ledger entry. Bucket 1 holds the newest stock, from endingDate minus periodLengthDays plus one up to endingDate; buckets 2 to 4 each go one period further back; bucket 5 holds everything older, with no start date. Entries posted after endingDate are not counted. Quantity is the remaining quantity of the entry now: the remaining quantity is not reconstructed for the ending date, as in the Item Age Composition reports. Value is the remaining quantity times the entry cost per unit (actual plus expected cost divided by quantity). Select items with itemNo, a SystemId key or tableView; with none of them every item is read. Only items with stock are listed. skip and take page the items; totalNoOfLines is the number of items with stock. Defaults: endingDate is the work date, periodLengthDays is 30, skip 0, take 100 (at most 1000). An empty variantCode is the blank variant; an empty locationFilter does not restrict the location. Nothing is changed.', Comment = 'is-IS=Aldur er talinn frá bókunardagsetningu hverrar opinnar jákvæðrar vörufærslu. Flokkur 1 geymir nýjustu birgðirnar, frá endingDate að frádregnum periodLengthDays plús einum og til endingDate; flokkar 2 til 4 ná hver einu tímabili lengra aftur; flokkur 5 geymir allt eldra, án upphafsdagsetningar. Færslur sem bókaðar eru eftir endingDate eru ekki taldar. Magn er eftirstandandi magn færslunnar núna: eftirstandandi magn er ekki endurreiknað miðað við lokadagsetningu, eins og í skýrslunum Aldurssamsetning vöru. Virði er eftirstandandi magn margfaldað með kostnaði færslunnar á einingu (raunkostnaður plús áætlaður kostnaður deilt með magni). Veldu vörur með itemNo, SystemId-lykli eða tableView; án þeirra eru allar vörur lesnar. Aðeins vörur með birgðir eru birtar. skip og take síðuskipta vörunum; totalNoOfLines er fjöldi vara með birgðir. Sjálfgildi: endingDate er vinnudagsetning, periodLengthDays er 30, skip 0, take 100 (mest 1000). Tómt variantCode er afbrigðislausa afbrigðið; tómt locationFilter takmarkar ekki staðsetningu. Engu er breytt.';
        PermissionSetTok: Label 'BIFROST Read ori', Locked = true;
        FilterFixLbl: Label 'Correct the Business Central filter syntax.', Comment = 'is-IS=Leiðréttu málskipan Business Central síunnar.';

    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Item.ReadPermission() then
            exit(false);
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::"Item Ledger Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["itemNo","systemId"],"description":"Subject wins over data identifiers and tableView."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item; used when subject is empty.'));
        Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the Item; any one of the four keys.'));
        Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view that selects the items to read.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoDescriptionLbl: Label 'Item number; the message subject is the same number when this key is omitted. Optional: with no item selection every item is read.', Comment = 'is-IS=Vörunúmer; subject er sama númer þegar lykillinn er ekki sendur. Valfrjálst: án vöruvals eru allar vörur lesnar.';
        EndingDateLbl: Label 'Last posting date counted, as YYYY-MM-DD. The newest bucket ends on this date. Default: the work date.', Comment = 'is-IS=Síðasta bókunardagsetning sem er talin, á forminu YYYY-MM-DD. Nýjasti flokkurinn endar á þessari dagsetningu. Sjálfgefið: vinnudagsetning.';
        PeriodLengthLbl: Label 'Length of each age bucket in days, a whole number from 1 to 3660. Default 30.', Comment = 'is-IS=Lengd hvers aldursflokks í dögum, heil tala frá 1 til 3660. Sjálfgefið 30.';
        LocationFilterLbl: Label 'Business Central filter on the location code of the item ledger entries.', Comment = 'is-IS=Business Central sía á staðsetningarkóða vörufærslna.';
        VariantCodeLbl: Label 'Exact variant code; an empty value selects the blank variant.', Comment = 'is-IS=Nákvæmur afbrigðiskóði; tómt gildi velur afbrigðislausa afbrigðið.';
        CategoryLbl: Label 'Business Central filter on the item category code of the items.', Comment = 'is-IS=Business Central sía á vöruflokkskóða vara.';
        SkipLbl: Label 'Number of items to skip, a whole number of 0 or more. Default 0.', Comment = 'is-IS=Fjöldi vara sem sleppt er, heil tala 0 eða hærri. Sjálfgefið 0.';
        TakeLbl: Label 'Number of items to return, a whole number from 1 to 1000. Default 100.', Comment = 'is-IS=Fjöldi vara sem skilað er, heil tala frá 1 til 1000. Sjálfgefið 100.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoDescriptionLbl));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'The SystemId of the Item; used after the subject and itemNo.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Alias for the Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'An Item table view; it can select several items.'));
        Parameters.Add(ContractMgt.Parameter('endingDate', 'string', false, EndingDateLbl));
        Parameters.Add(ContractMgt.Parameter('periodLengthDays', 'integer', false, PeriodLengthLbl));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, LocationFilterLbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, VariantCodeLbl));
        Parameters.Add(ContractMgt.Parameter('itemCategoryFilter', 'string', false, CategoryLbl));
        Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, SkipLbl));
        Parameters.Add(ContractMgt.Parameter('take', 'integer', false, TakeLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"contentType":"text/json","fields":[{"name":"status","type":"string","description":"Success."},{"name":"endingDate","type":"string","description":"The ending date used, as YYYY-MM-DD."},{"name":"periodLengthDays","type":"integer","description":"The bucket length in days."},{"name":"noOfLines","type":"integer","description":"Items in this page."},{"name":"totalNoOfLines","type":"integer","description":"Items with stock, over all pages."},{"name":"buckets","type":"array","description":"The five age buckets.","children":[{"name":"bucket","type":"integer","description":"Bucket number 1 to 5; 1 is the newest."},{"name":"fromDate","type":"string","description":"First posting date of the bucket; absent for bucket 5."},{"name":"toDate","type":"string","description":"Last posting date of the bucket."}]},{"name":"items","type":"array","description":"One row per item with stock.","children":[{"name":"itemNo","type":"string","description":"Item number."},{"name":"description","type":"string","description":"Item description."},{"name":"totalQuantity","type":"decimal","description":"Remaining quantity over all buckets."},{"name":"totalValue","type":"decimal","description":"Value over all buckets."},{"name":"ages","type":"array","description":"Five entries, one per bucket.","children":[{"name":"bucket","type":"integer","description":"Bucket number 1 to 5."},{"name":"quantity","type":"decimal","description":"Remaining quantity in the bucket."},{"name":"value","type":"decimal","description":"Value of that quantity."}]}]}]}');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ContractParts: Codeunit "Inventory Contract Parts ori";
        NotFoundErr: Label 'Item {itemNo} was not found.', Comment = 'is-IS=Vara {itemNo} fannst ekki.';
        NotFoundWhenLbl: Label 'The item number, SystemId or tableView matches no item.', Comment = 'is-IS=Vörunúmerið, SystemId eða tableView passar ekki við neina vöru.';
        NotFoundFixLbl: Label 'Check the item number or the selection.', Comment = 'is-IS=Athugaðu vörunúmerið eða valið.';
        InvalidParameterErr: Label 'A text parameter is not text, or the Costing domain is turned off in Inventory Setup.', Comment = 'is-IS=Textafæribreyta er ekki texti, eða kostnaðarsviðið er slökkt í uppsetningu birgða.';
        InvalidParameterFixLbl: Label 'Send locationFilter, variantCode and itemCategoryFilter as JSON text, or turn on the Costing domain in Inventory Setup.', Comment = 'is-IS=Sendu locationFilter, variantCode og itemCategoryFilter sem JSON-texta, eða kveiktu á kostnaðarsviðinu í uppsetningu birgða.';
        FormatErr: Label 'endingDate is not YYYY-MM-DD, or periodLengthDays, skip or take is outside its range.', Comment = 'is-IS=endingDate er ekki YYYY-MM-DD, eða periodLengthDays, skip eða take er utan marka.';
        FormatFixLbl: Label 'Send endingDate as YYYY-MM-DD, periodLengthDays as a whole number from 1 to 3660, skip as 0 or more and take from 1 to 1000.', Comment = 'is-IS=Sendu endingDate á forminu YYYY-MM-DD, periodLengthDays sem heila tölu frá 1 til 3660, skip sem 0 eða hærra og take frá 1 til 1000.';
        PermissionErr: Label 'Native Item or Item Ledger Entry read permission is absent.', Comment = 'is-IS=Heimild til að lesa vörur eða vörufærslur vantar.';
        PermissionFixLbl: Label 'Assign a role that can read items and item ledger entries.', Comment = 'is-IS=Úthlutaðu hlutverki sem getur lesið vörur og vörufærslur.';
        FilterErr: Label 'A location or item category filter cannot be applied.', Comment = 'is-IS=Ekki er hægt að beita staðsetningar- eða vöruflokkssíu.';
    begin
        Clear(Errors);
        ContractParts.AddItemNoSubjectErrors(Errors, false);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidParameterErr, InvalidParameterErr, InvalidParameterFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, FormatErr, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErr, PermissionErr, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, FilterErr, FilterErr, FilterFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ChangesLbl: Label 'None. Reads open item ledger entries and their cost.', Comment = 'is-IS=Engin. Les opnar vörufærslur og kostnað þeirra.';
        CostingPreconditionLbl: Label 'The Costing domain is turned on in Inventory Setup.', Comment = 'is-IS=Kveikt er á kostnaðarsviðinu í uppsetningu birgða.';
        ReadPreconditionLbl: Label 'The caller can read items and item ledger entries.', Comment = 'is-IS=Notandinn getur lesið vörur og vörufærslur.';
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', PermissionSetTok);
        Preconditions.Add(CostingPreconditionLbl);
        Preconditions.Add(ReadPreconditionLbl);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CostGetLbl: Label 'Use it to read the current card costs and the inventory of an item; this type reads stock by age.', Comment = 'is-IS=Notaðu hana til að lesa núverandi spjaldkostnað og birgðir vöru; þessi tegund les birgðir eftir aldri.';
        RevaluationLbl: Label 'Use it to read the remaining quantity and value of one item without age buckets.', Comment = 'is-IS=Notaðu hana til að lesa eftirstandandi magn og virði einnar vöru án aldursflokka.';
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.Cost.Get', CostGetLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Calculate', RevaluationLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ExampleLbl: Label 'Read the stock age of item 1000 in 30 day buckets', Comment = 'is-IS=Lesa aldur birgða vöru 1000 í 30 daga flokkum';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            ExampleLbl,
            '{"type":"Inventory.AgedInventory.Get","data":{"itemNo":"1000","endingDate":"2026-10-31","periodLengthDays":30}}',
            '{"status":"Success","endingDate":"2026-10-31","periodLengthDays":30,"noOfLines":1,"totalNoOfLines":1,"buckets":[{"bucket":1,"fromDate":"2026-10-02","toDate":"2026-10-31"},{"bucket":2,"fromDate":"2026-09-02","toDate":"2026-10-01"},{"bucket":3,"fromDate":"2026-08-03","toDate":"2026-09-01"},{"bucket":4,"fromDate":"2026-07-04","toDate":"2026-08-02"},{"bucket":5,"toDate":"2026-07-03"}],"items":[{"itemNo":"1000","description":"Bicycle","totalQuantity":15,"totalValue":1500,"ages":[{"bucket":1,"quantity":10,"value":1000},{"bucket":2,"quantity":0,"value":0},{"bucket":3,"quantity":0,"value":0},{"bucket":4,"quantity":0,"value":0},{"bucket":5,"quantity":5,"value":500}]}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Request: JsonObject;
        LocationFilter: Text;
        VariantCode: Text;
        CategoryFilter: Text;
        EndingDate: Date;
        PeriodLength: Integer;
        Skip: Integer;
        Take: Integer;
        HasVariant: Boolean;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not CanRead(Argument) then
            exit;
        Request := Argument.GetRequestJson();
        if not ReadParameters(Argument, Request, LocationFilter, VariantCode, CategoryFilter, EndingDate, PeriodLength, Skip, Take) then
            exit;
        HasVariant := Request.Contains('variantCode');
        if not SelectItems(Argument, Request, Item) then
            exit;
        RespondAges(Argument, Item, LocationFilter, VariantCode, HasVariant, CategoryFilter, EndingDate, PeriodLength, Skip, Take);
    end;

    local procedure CanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        ReadDeniedErr: Label 'Permission denied for item or item ledger entry data.', Comment = 'is-IS=Heimild hafnað fyrir vöru- eða vörufærslugögn.';
        ReadDeniedNextStepLbl: Label 'Assign a role that can read items and item ledger entries, then send the call again.', Comment = 'is-IS=Úthlutaðu hlutverki sem getur lesið vörur og vörufærslur og sendu kallið aftur.';
    begin
        if Item.ReadPermission() and Ledger.ReadPermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, ReadDeniedErr, '', '', '', ReadDeniedNextStepLbl);
        exit(false);
    end;

    local procedure ReadParameters(var Argument: Record "Message Argument ori"; Request: JsonObject; var LocationFilter: Text; var VariantCode: Text; var CategoryFilter: Text; var EndingDate: Date; var PeriodLength: Integer; var Skip: Integer; var Take: Integer): Boolean
    var
        Reader: Codeunit "Request Value Reader ori";
        Number: Decimal;
    begin
        PeriodLength := 30;
        Skip := 0;
        Take := 100;
        if not TryReadText(Argument, Request, 'locationFilter', LocationFilter) or
           not TryReadText(Argument, Request, 'variantCode', VariantCode) or
           not TryReadText(Argument, Request, 'itemCategoryFilter', CategoryFilter)
        then
            exit(false);
        if not Reader.TryReadDate(Argument, Request, 'endingDate', false, EndingDate) then
            exit(false);
        if EndingDate = 0D then
            EndingDate := WorkDate();
        if Request.Contains('periodLengthDays') then
            if not Reader.TryReadDecimal(Argument, Request, 'periodLengthDays', true, Number) or
               not CheckWholeNumber(Argument, 'periodLengthDays', Number, 1, 3660, PeriodLength)
            then
                exit(false);
        if Request.Contains('skip') then
            if not Reader.TryReadDecimal(Argument, Request, 'skip', true, Number) or
               not CheckWholeNumber(Argument, 'skip', Number, 0, 2147483647, Skip)
            then
                exit(false);
        if Request.Contains('take') then
            if not Reader.TryReadDecimal(Argument, Request, 'take', true, Number) or
               not CheckWholeNumber(Argument, 'take', Number, 1, 1000, Take)
            then
                exit(false);
        exit(true);
    end;

    local procedure SelectItems(var Argument: Record "Message Argument ori"; Request: JsonObject; var Item: Record Item): Boolean
    var
        Lookup: Codeunit "Document Lookup ori";
        ContractParts: Codeunit "Inventory Contract Parts ori";
        ItemNo: Code[20];
        NotFoundErr: Label 'Item %1 was not found.', Comment = '%1 = item no.; is-IS=Vara %1 fannst ekki.';
        NotFoundExpectedLbl: Label 'The number of an existing item.', Comment = 'is-IS=Númer vöru sem er til.';
        NotFoundNextStepLbl: Label 'Check the item number, then send it as data.itemNo or subject, or leave it out to read every item.', Comment = 'is-IS=Athugaðu vörunúmerið og sendu það sem data.itemNo eða subject, eða slepptu því til að lesa allar vörur.';
    begin
        if UsesFoundationSelection(Argument, Request) then
            exit(Lookup.FindItemRange(Argument, Item));
        if not ContractParts.TryResolveItemNo(Argument, Request, false, ItemNo) then
            exit(false);
        if ItemNo = '' then
            exit(true);
        Item.SetRange("No.", ItemNo);
        if Item.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ItemNo), 'itemNo', ItemNo, NotFoundExpectedLbl, NotFoundNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure UsesFoundationSelection(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        SubjectId: Guid;
    begin
        if Argument.Subject <> '' then
            if Evaluate(SubjectId, Argument.Subject) then
                exit(true);
        exit(Request.Contains('itemId') or Request.Contains('id') or Request.Contains('systemId') or Request.Contains('recordSystemId') or Request.Contains('tableView'));
    end;

    local procedure RespondAges(var Argument: Record "Message Argument ori"; var Item: Record Item; LocationFilter: Text; VariantCode: Text; HasVariant: Boolean; CategoryFilter: Text; EndingDate: Date; PeriodLength: Integer; Skip: Integer; Take: Integer)
    var
        Response: JsonObject;
        Rows: JsonArray;
        Total: Integer;
    begin
        if not TryCollect(Item, LocationFilter, VariantCode, HasVariant, CategoryFilter, EndingDate, PeriodLength, Skip, Take, Rows, Total) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', FilterFixLbl);
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('endingDate', Format(EndingDate, 0, 9));
        Response.Add('periodLengthDays', PeriodLength);
        Response.Add('noOfLines', Rows.Count());
        Response.Add('totalNoOfLines', Total);
        Response.Add('buckets', BucketDefinitions(EndingDate, PeriodLength));
        Response.Add('items', Rows);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryCollect(var Item: Record Item; LocationFilter: Text; VariantCode: Text; HasVariant: Boolean; CategoryFilter: Text; EndingDate: Date; PeriodLength: Integer; Skip: Integer; Take: Integer; var Rows: JsonArray; var Total: Integer)
    var
        Ledger: Record "Item Ledger Entry";
    begin
        if CategoryFilter <> '' then
            Item.SetFilter("Item Category Code", CategoryFilter);
        Item.SetLoadFields("No.", Description);
        if not Item.FindSet() then
            exit;
        repeat
            FilterLedger(Ledger, Item."No.", LocationFilter, VariantCode, HasVariant, EndingDate);
            if not Ledger.IsEmpty() then begin
                if (Total >= Skip) and (Rows.Count() < Take) then
                    Rows.Add(ItemRow(Item, Ledger, EndingDate, PeriodLength));
                Total += 1;
            end;
        until Item.Next() = 0;
    end;

    local procedure FilterLedger(var Ledger: Record "Item Ledger Entry"; ItemNo: Code[20]; LocationFilter: Text; VariantCode: Text; HasVariant: Boolean; EndingDate: Date)
    begin
        Ledger.Reset();
        Ledger.SetCurrentKey("Item No.", Open);
        Ledger.SetRange("Item No.", ItemNo);
        Ledger.SetRange(Open, true);
        Ledger.SetRange(Positive, true);
        Ledger.SetFilter("Remaining Quantity", '<>0');
        Ledger.SetRange("Posting Date", 0D, EndingDate);
        if LocationFilter <> '' then
            Ledger.SetFilter("Location Code", LocationFilter);
        if HasVariant then
            Ledger.SetRange("Variant Code", VariantCode);
    end;

    local procedure ItemRow(var Item: Record Item; var Ledger: Record "Item Ledger Entry"; EndingDate: Date; PeriodLength: Integer) Row: JsonObject
    var
        Ages: JsonArray;
        Age: JsonObject;
        Quantity: array[5] of Decimal;
        Value: array[5] of Decimal;
        TotalQuantity: Decimal;
        TotalValue: Decimal;
        Bucket: Integer;
    begin
        Ledger.SetLoadFields("Item No.", "Posting Date", "Remaining Quantity", Quantity);
        Ledger.FindSet();
        repeat
            Bucket := BucketOf(Ledger."Posting Date", EndingDate, PeriodLength);
            Quantity[Bucket] += Ledger."Remaining Quantity";
            Value[Bucket] += RemainingValue(Ledger);
        until Ledger.Next() = 0;
        for Bucket := 1 to 5 do begin
            Clear(Age);
            Age.Add('bucket', Bucket);
            Age.Add('quantity', Quantity[Bucket]);
            Age.Add('value', Round(Value[Bucket], 0.01));
            Ages.Add(Age);
            TotalQuantity += Quantity[Bucket];
            TotalValue += Value[Bucket];
        end;
        Row.Add('itemNo', Item."No.");
        Row.Add('description', Item.Description);
        Row.Add('totalQuantity', TotalQuantity);
        Row.Add('totalValue', Round(TotalValue, 0.01));
        Row.Add('ages', Ages);
    end;

    /// <summary>Bucket 1 is the newest period ending on EndingDate; bucket 5 holds everything older than four periods.</summary>
    local procedure BucketOf(PostingDate: Date; EndingDate: Date; PeriodLength: Integer): Integer
    var
        Bucket: Integer;
    begin
        Bucket := (EndingDate - PostingDate) div PeriodLength + 1;
        if Bucket > 5 then
            Bucket := 5;
        exit(Bucket);
    end;

    local procedure BucketDefinitions(EndingDate: Date; PeriodLength: Integer) Buckets: JsonArray
    var
        Definition: JsonObject;
        Bucket: Integer;
    begin
        for Bucket := 1 to 5 do begin
            Clear(Definition);
            Definition.Add('bucket', Bucket);
            if Bucket < 5 then
                Definition.Add('fromDate', Format(EndingDate - Bucket * PeriodLength + 1, 0, 9));
            Definition.Add('toDate', Format(EndingDate - (Bucket - 1) * PeriodLength, 0, 9));
            Buckets.Add(Definition);
        end;
    end;

    local procedure RemainingValue(var Ledger: Record "Item Ledger Entry"): Decimal
    begin
        if Ledger.Quantity = 0 then
            exit(0);
        Ledger.CalcFields("Cost Amount (Actual)", "Cost Amount (Expected)");
        exit(Ledger."Remaining Quantity" * (Ledger."Cost Amount (Actual)" + Ledger."Cost Amount (Expected)") / Ledger.Quantity);
    end;

    local procedure CheckWholeNumber(var Argument: Record "Message Argument ori"; KeyName: Text; Number: Decimal; Minimum: Integer; Maximum: Integer; var Value: Integer): Boolean
    var
        RangeFormatErr: Label '%1 must be a whole number from %2 to %3.', Comment = '%1 = parameter, %2 = minimum, %3 = maximum; is-IS=%1 verður að vera heil tala frá %2 til %3.';
        RangeExpectedLbl: Label 'a whole number in range', Comment = 'is-IS=heil tala innan marka';
        RangeNextStepLbl: Label 'Send the value as a JSON whole number within the documented range.', Comment = 'is-IS=Sendu gildið sem JSON-heiltölu innan skjalfestra marka.';
    begin
        if (Number < Minimum) or (Number > Maximum) or (Number <> Round(Number, 1)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(RangeFormatErr, KeyName, Minimum, Maximum), KeyName, Format(Number, 0, 9), RangeExpectedLbl, RangeNextStepLbl);
            exit(false);
        end;
        Value := Number;
        exit(true);
    end;

    local procedure TryReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        InvalidTextErr: Label 'Parameter %1 must be text.', Comment = '%1 = parameter; is-IS=Færibreytan %1 verður að vera texti.';
        TextNextStepLbl: Label 'Send the value as JSON text.', Comment = 'is-IS=Sendu gildið sem JSON-texta.';
    begin
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidTextErr, Name), Name, Serialized, 'text', TextNextStepLbl);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        exit(true);
    end;
}
