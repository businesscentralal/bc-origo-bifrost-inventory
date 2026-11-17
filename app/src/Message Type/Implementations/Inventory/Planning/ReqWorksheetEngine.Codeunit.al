namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Planning;
using Microsoft.Purchases.Document;
using Origo.Bifrost;

/// <summary>
/// Shared planning-worksheet calculation and carry-out. Calculate limits the native item delete to one worksheet.
/// Carry-out refuses any accepted line that would change or delete an existing document before the native run starts.
/// </summary>
codeunit 10076932 "Req. Worksheet Engine ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
        DeleteScopeActive: Boolean;
        CarryInProgress: Boolean;
        CreatedTransfers: List of [Code[20]];
        CreatedAssemblies: List of [Code[20]];
        ModeMissingErr: Label 'mode is required.', Comment = 'is-IS=mode er nauðsynlegt.';
        ModeExpectedLbl: Label 'regenerative or netChange', Comment = 'is-IS=regenerative eða netChange';
        ModeNextLbl: Label 'Send mode as regenerative or netChange.', Comment = 'is-IS=Sendu mode sem regenerative eða netChange.';
        ModeErr: Label 'mode must be regenerative or netChange.', Comment = 'is-IS=mode verður að vera regenerative eða netChange.';
        DateMissingErr: Label '%1 is required.', Comment = '%1 = parameter name; is-IS=%1 er nauðsynlegt.';
        DateFormatErr: Label '%1 must be a date in YYYY-MM-DD form.', Comment = '%1 = parameter name; is-IS=%1 verður að vera dagsetning á forminu ÁÁÁÁ-MM-DD.';
        DateExpectedLbl: Label 'a date in YYYY-MM-DD form', Comment = 'is-IS=dagsetning á forminu ÁÁÁÁ-MM-DD';
        DateNextLbl: Label 'Send %1 as YYYY-MM-DD.', Comment = '%1 = parameter name; is-IS=Sendu %1 sem ÁÁÁÁ-MM-DD.';
        DateOrderErr: Label 'endingDate must not be before startingDate.', Comment = 'is-IS=endingDate má ekki vera á undan startingDate.';
        DateOrderNextLbl: Label 'Send an endingDate on or after startingDate.', Comment = 'is-IS=Sendu endingDate á eða eftir startingDate.';
        FilterErr: Label 'itemNo, locationCode or variantCode is not a valid filter.', Comment = 'is-IS=itemNo, locationCode eða variantCode er ekki gild sía.';
        FilterExpectedLbl: Label 'a filter expression of at most 2048 characters', Comment = 'is-IS=síu sem er mest 2048 stafir';
        FilterNextLbl: Label 'Correct the filter named in the answer, or omit it to include every item.', Comment = 'is-IS=Leiðréttu síuna sem svarið nefnir, eða slepptu henni til að taka allar vörur með.';
        CalcNativeNextLbl: Label 'Lines for items already calculated on this worksheet may remain. Other worksheets were not changed. Correct the cause and calculate this worksheet again.', Comment = 'is-IS=Línur vara sem þegar voru reiknaðar á þessari keyrslu geta staðið eftir. Aðrar keyrslur breyttust ekki. Leiðréttu orsökina og reiknaðu þessa keyrslu aftur.';
        CalcNativeExpectedLbl: Label 'a completed calculation for the selected items', Comment = 'is-IS=lokinn útreikningur fyrir valdar vörur';
        CarryNativeNextLbl: Label 'Orders created before the failure remain. Suggestion lines that were already consumed are gone. Check the created orders before you try again.', Comment = 'is-IS=Pantanir sem urðu til fyrir bilunina standa. Tillögulínur sem þegar voru uppurnar eru farnar. Athugaðu pantanirnar sem urðu til áður en þú reynir aftur.';
        CarryNativeExpectedLbl: Label 'new purchase, transfer or assembly orders for the accepted New lines', Comment = 'is-IS=nýjar innkaupa-, flutnings- eða samsetningarpantanir fyrir samþykktu New-línurnar';
        CarryNothingErr: Label 'The planning worksheet did not return a created order.', Comment = 'is-IS=Áætlunarkeyrslan skilaði ekki nýrri pöntun.';
        CarryNothingNextLbl: Label 'Check whether an order was still created, and whether the suggestion lines are still on the worksheet, before you try again.', Comment = 'is-IS=Athugaðu hvort pöntun hafi samt orðið til og hvort tillögulínurnar séu enn á keyrslunni áður en þú reynir aftur.';
        CarryNothingExpectedLbl: Label 'at least one new order', Comment = 'is-IS=að minnsta kosti ein ný pöntun';
        NotFoundErr: Label 'No planning worksheet matches the template and name.', Comment = 'is-IS=Engin áætlunarkeyrsla passar við sniðið og heitið.';
        NotFoundNextLbl: Label 'Send the template and name of an existing planning worksheet.', Comment = 'is-IS=Sendu snið og heiti áætlunarkeyrslu sem er til.';
        WrongTypeErr: Label 'The worksheet template is not a planning worksheet.', Comment = 'is-IS=Snið keyrslunnar er ekki áætlunarkeyrsla.';
        WrongTypeNextLbl: Label 'Choose a planning worksheet. This call does not change a requisition worksheet.', Comment = 'is-IS=Veldu áætlunarkeyrslu. Þetta kall breytir ekki innkaupakeyrslu.';
        MissingWorksheetErr: Label 'The worksheet name does not exist on that template.', Comment = 'is-IS=Heiti keyrslunnar er ekki til á því sniði.';
        RecurringErr: Label 'The planning worksheet template is recurring.', Comment = 'is-IS=Snið áætlunarkeyrslunnar er ítrekunarsnið.';
        RecurringNextLbl: Label 'Choose a planning worksheet that is not recurring.', Comment = 'is-IS=Veldu áætlunarkeyrslu sem er ekki ítrekunarsnið.';
        RecurringExpectedLbl: Label 'a planning worksheet that is not recurring', Comment = 'is-IS=áætlunarkeyrsla sem er ekki ítrekunarsnið';
        ExistingExpectedLbl: Label 'an existing planning worksheet', Comment = 'is-IS=áætlunarkeyrsla sem er til';
        SubjectErr: Label 'subject must be TEMPLATE|NAME.', Comment = 'is-IS=subject verður að vera SNIÐ|HEITI.';
        SubjectExpectedLbl: Label 'TEMPLATE|NAME with each part at most 10 characters', Comment = 'is-IS=SNIÐ|HEITI þar sem hvort um sig er mest 10 stafir';
        SubjectNextLbl: Label 'Send subject as the template name, a vertical bar and the worksheet name, or send templateName and worksheetName.', Comment = 'is-IS=Sendu subject sem heiti sniðs, lóðrétt strik og heiti keyrslu, eða sendu templateName og worksheetName.';
        ConflictErr: Label 'The subject and the data keys name different worksheets.', Comment = 'is-IS=subject og data-lyklarnir nefna ólíkar keyrslur.';
        ConflictNextLbl: Label 'Send one worksheet. The subject and templateName and worksheetName must agree.', Comment = 'is-IS=Sendu eina keyrslu. subject og templateName og worksheetName verða að stemma.';
        ResolveMissingErr: Label '%1 is required when subject does not identify the worksheet.', Comment = '%1 = parameter name; is-IS=%1 er nauðsynlegt þegar subject auðkennir ekki keyrsluna.';
        NameExpectedLbl: Label 'a worksheet name of at most 10 characters', Comment = 'is-IS=heiti keyrslu sem er mest 10 stafir';
        RefuseNothingErr: Label 'There is nothing to carry out on this planning worksheet.', Comment = 'is-IS=Ekkert er hægt að framkvæma á þessari áætlunarkeyrslu.';
        RefuseNothingNextLbl: Label 'Accept at least one New line, or calculate the worksheet first.', Comment = 'is-IS=Samþykktu að minnsta kosti eina New-línu, eða reiknaðu keyrsluna fyrst.';
        RefuseNothingExpectedLbl: Label 'an accepted New line', Comment = 'is-IS=samþykkt New-lína';
        RefuseMissingErr: Label 'The line number is not on this planning worksheet.', Comment = 'is-IS=Línunúmerið er ekki á þessari áætlunarkeyrslu.';
        LineExpectedLbl: Label 'a line number on the worksheet', Comment = 'is-IS=línunúmer á keyrslunni';
        MissingNextLbl: Label 'Send a line number that is on the worksheet, or omit lineNos.', Comment = 'is-IS=Sendu línunúmer sem er á keyrslunni, eða slepptu lineNos.';
        NotAcceptedErr: Label 'The line is not an accepted New suggestion.', Comment = 'is-IS=Línan er ekki samþykkt New-tillaga.';
        NotAcceptedNextLbl: Label 'Accept the New line, or omit it from lineNos. Unaccepted lines are left unchanged.', Comment = 'is-IS=Samþykktu New-línuna, eða slepptu henni úr lineNos. Ósamþykktar línur standa óbreyttar.';
        ActionErr: Label 'The line would change or delete an existing document.', Comment = 'is-IS=Línan myndi breyta eða eyða fyrirliggjandi skjali.';
        ActionNextLbl: Label 'Remove that line from the selection. Only an accepted New line can be carried out.', Comment = 'is-IS=Taktu línuna úr valinu. Aðeins samþykkta New-línu er hægt að framkvæma.';
        ActionExpectedLbl: Label 'New', Comment = 'is-IS=New';
        DocumentErr: Label 'The line names an existing document.', Comment = 'is-IS=Línan nefnir fyrirliggjandi skjal.';
        DocumentNextLbl: Label 'Carry out only a new supply line. Existing documents are left unchanged.', Comment = 'is-IS=Framkvæmdu aðeins nýja birgðalínu. Fyrirliggjandi skjöl standa óbreytt.';
        DocumentExpectedLbl: Label 'a New line that does not name an existing document', Comment = 'is-IS=New-lína sem nefnir ekki fyrirliggjandi skjal';
        ProdErr: Label 'Production orders are not created by this call.', Comment = 'is-IS=Þetta kall býr ekki til framleiðslupantanir.';
        ProdNextLbl: Label 'Remove the production line from the selection. Only a new purchase, transfer or assembly order can be created.', Comment = 'is-IS=Taktu framleiðslulínuna úr valinu. Aðeins ný innkaupa-, flutnings- eða samsetningarpöntun getur orðið til.';
        ReplenishmentErr: Label 'The line is not a new purchase, transfer or assembly suggestion.', Comment = 'is-IS=Línan er ekki ný innkaupa-, flutnings- eða samsetningartillaga.';
        PurchaseOnlyErr: Label 'The line is not a new purchase suggestion.', Comment = 'is-IS=Línan er ekki ný innkaupatillaga.';
        ReplenishmentNextLbl: Label 'Keep only accepted New lines for a new purchase, transfer or assembly order.', Comment = 'is-IS=Haltu aðeins samþykktum New-línum fyrir nýja innkaupa-, flutnings- eða samsetningarpöntun.';
        PurchaseOnlyNextLbl: Label 'Keep only accepted New lines for a new purchase order.', Comment = 'is-IS=Haltu aðeins samþykktum New-línum fyrir nýja innkaupapöntun.';
        SupplyExpectedLbl: Label 'Purchase, Transfer or Assembly', Comment = 'is-IS=Purchase, Transfer eða Assembly';
        PurchaseExpectedLbl: Label 'Purchase', Comment = 'is-IS=Purchase';
        UnknownKeyErr: Label 'The request contains a key this message type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi skilaboðategund les ekki.';
        UnknownNextLbl: Label 'Remove the key named in the answer and send only the keys the help lists.', Comment = 'is-IS=Fjarlægðu lykilinn sem svarið nefnir og sendu aðeins lykla sem hjálpin telur upp.';
        CalculateExpectedLbl: Label 'templateName, worksheetName, mode, startingDate, endingDate, itemNo, locationCode or variantCode', Comment = 'is-IS=templateName, worksheetName, mode, startingDate, endingDate, itemNo, locationCode eða variantCode';
        CarryExpectedLbl: Label 'templateName, worksheetName, lineNos or expectedCount', Comment = 'is-IS=templateName, worksheetName, lineNos eða expectedCount';
        ExpectFormatErr: Label 'expectedCount must be a whole number.', Comment = 'is-IS=expectedCount verður að vera heiltala.';
        ExpectExpectedLbl: Label 'a whole number', Comment = 'is-IS=heiltala';
        ExpectNextLbl: Label 'Send expectedCount as the whole number from the confirmation answer, or omit it when confirmation does not require it.', Comment = 'is-IS=Sendu expectedCount sem heiltöluna úr staðfestingarsvarinu, eða slepptu henni þegar staðfesting krefst hennar ekki.';
        EmptyErr: Label 'lineNos must list at least one line number.', Comment = 'is-IS=lineNos verður að telja upp að minnsta kosti eitt línunúmer.';
        LinesFormatErr: Label 'lineNos must be a list of JSON integers.', Comment = 'is-IS=lineNos verður að vera listi af JSON-heiltölum.';
        PositiveErr: Label 'Each line number must be a positive JSON integer.', Comment = 'is-IS=Hvert línunúmer verður að vera jákvæð JSON-heiltala.';
        LinesExpectedLbl: Label 'a non-empty list of positive JSON integers', Comment = 'is-IS=listi sem er ekki tómur af jákvæðum JSON-heiltölum';
        LinesNextLbl: Label 'Send lineNos as a list of line numbers from the worksheet, or omit it to carry out every accepted New line.', Comment = 'is-IS=Sendu lineNos sem lista af línunúmerum af keyrslunni, eða slepptu því til að framkvæma hverja samþykkta New-línu.';
        OptFormatErr: Label '%1 must be text.', Comment = '%1 = parameter name; is-IS=%1 verður að vera texti.';
        LengthErr: Label '%1 is longer than %2 characters.', Comment = '%1 = parameter name, %2 = maximum length; is-IS=%1 er lengra en %2 stafir.';
        TextExpectedLbl: Label 'text', Comment = 'is-IS=texti';
        OptNextLbl: Label 'Send %1 as text of at most %2 characters, or omit it.', Comment = '%1 = parameter name, %2 = maximum length; is-IS=Sendu %1 sem texta sem er mest %2 stafir, eða slepptu því.';

    /// <summary>Calculates one planning worksheet and answers the suggestion lines.</summary>
    internal procedure CalculateWorksheet(var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        TemplateName: Code[10];
        WorksheetName: Code[10];
        ItemNoFilter: Text;
        LocationFilter: Text;
        VariantFilter: Text;
        Mode: Text;
        StartingText: Text;
        EndingText: Text;
        NormalizedMode: Text;
        Regenerative: Boolean;
        StartingDate: Date;
        EndingDate: Date;
        LineCount: Integer;
    begin
        Request := Argument.GetRequestJson();
        if not KeysAreKnown('templateName,worksheetName,mode,startingDate,endingDate,itemNo,locationCode,variantCode', Request, Argument) then
            exit;
        if not ResolvePlanningWorksheet(Argument, Request, TemplateName, WorksheetName) then
            exit;
        if not ReadRequiredText(Request, 'mode', 20, Argument, Mode) then
            exit;
        if Mode = '' then begin
            Answer(Argument, "Bifrost Error Code ori"::MissingParameter, ModeMissingErr, 'mode', '', ModeExpectedLbl, ModeNextLbl);
            exit;
        end;
        case LowerCase(Mode) of
            'regenerative':
                begin
                    Regenerative := true;
                    NormalizedMode := 'regenerative';
                end;
            'netchange':
                begin
                    Regenerative := false;
                    NormalizedMode := 'netChange';
                end;
            else begin
                Answer(Argument, "Bifrost Error Code ori"::InvalidParameter, ModeErr, 'mode', Mode, ModeExpectedLbl, ModeNextLbl);
                exit;
            end;
        end;
        if not ReadRequiredText(Request, 'startingDate', 10, Argument, StartingText) then
            exit;
        if StartingText = '' then begin
            Answer(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(DateMissingErr, 'startingDate'), 'startingDate', '', DateExpectedLbl, StrSubstNo(DateNextLbl, 'startingDate'));
            exit;
        end;
        if not ReadDate(StartingText, StartingDate) then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateFormatErr, 'startingDate'), 'startingDate', StartingText, DateExpectedLbl, StrSubstNo(DateNextLbl, 'startingDate'));
            exit;
        end;
        if not ReadRequiredText(Request, 'endingDate', 10, Argument, EndingText) then
            exit;
        if EndingText = '' then begin
            Answer(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(DateMissingErr, 'endingDate'), 'endingDate', '', DateExpectedLbl, StrSubstNo(DateNextLbl, 'endingDate'));
            exit;
        end;
        if not ReadDate(EndingText, EndingDate) then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(DateFormatErr, 'endingDate'), 'endingDate', EndingText, DateExpectedLbl, StrSubstNo(DateNextLbl, 'endingDate'));
            exit;
        end;
        if EndingDate < StartingDate then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameter, DateOrderErr, 'endingDate', EndingText, StartingText, DateOrderNextLbl);
            exit;
        end;
        if not ReadOptionalText(Request, 'itemNo', 2048, Argument, ItemNoFilter) then
            exit;
        if not ReadOptionalText(Request, 'locationCode', 2048, Argument, LocationFilter) then
            exit;
        if not ReadOptionalText(Request, 'variantCode', 2048, Argument, VariantFilter) then
            exit;
        if not FiltersAreValid(ItemNoFilter, LocationFilter, VariantFilter) then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, FilterErr, 'itemNo', ItemNoFilter, FilterExpectedLbl, FilterNextLbl);
            exit;
        end;

        DeleteScopeActive := true;
        if not TryCalculateReport(TemplateName, WorksheetName, Regenerative, StartingDate, EndingDate, ItemNoFilter, LocationFilter, VariantFilter) then begin
            DeleteScopeActive := false;
            ContractParts.RespondWithNativeContext(Argument, 'worksheet', TemplateName + '|' + WorksheetName, CalcNativeExpectedLbl, CalcNativeNextLbl);
            exit;
        end;
        DeleteScopeActive := false;

        LineCount := AppendSuggestionLines(TemplateName, WorksheetName, ItemNoFilter, LocationFilter, VariantFilter, Lines);
        Response.Add('status', 'Success');
        Response.Add('templateName', TemplateName);
        Response.Add('worksheetName', WorksheetName);
        Response.Add('mode', NormalizedMode);
        Response.Add('startingDate', Format(StartingDate, 0, 9));
        Response.Add('endingDate', Format(EndingDate, 0, 9));
        Response.Add('lineCount', LineCount);
        Response.Add('lines', Lines);
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Creates new purchase, transfer and assembly orders from accepted New lines. Mutating lines are refused first.</summary>
    /// <param name="Argument">The inbound message argument. expectedCount is accepted and ignored here; Foundation checks it.</param>
    internal procedure CarryOutWorksheet(var Argument: Record "Message Argument ori")
    begin
        CarryOutSelection(Argument, false);
    end;

    /// <summary>
    /// Carries out a planning or, when PurchaseOnly is true, purchase-only selection.
    /// PurchaseOnly lets the requisition facade reuse the same refusal and order creation.
    /// </summary>
    /// <param name="Argument">The inbound message argument.</param>
    /// <param name="PurchaseOnly">When true, only new purchase lines are allowed.</param>
    internal procedure CarryOutSelection(var Argument: Record "Message Argument ori"; PurchaseOnly: Boolean)
    var
        TempDocumentEntry: Record "Document Entry" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Orders: JsonArray;
        RequestedLineNos: List of [Integer];
        TemplateName: Code[10];
        WorksheetName: Code[10];
        Failure: Text;
        FailureDetail: Text;
        LineNoFilter: Text;
        HasLineFilter: Boolean;
        BeforeCount: Integer;
        AfterCount: Integer;
        FailureLineNo: Integer;
        LinesConsumed: Integer;
    begin
        Request := Argument.GetRequestJson();
        if not KeysAreKnown('templateName,worksheetName,lineNos,expectedCount', Request, Argument) then
            exit;
        if not AcceptExpectedCount(Request, Argument) then
            exit;
        if not ResolvePlanningWorksheet(Argument, Request, TemplateName, WorksheetName) then
            exit;
        if not ReadLineNumbers(Request, Argument, HasLineFilter, RequestedLineNos) then
            exit;
        if not CollectSafeLines(TemplateName, WorksheetName, HasLineFilter, RequestedLineNos, PurchaseOnly, Failure, FailureLineNo, FailureDetail) then begin
            AnswerCarryFailure(Argument, Failure, FailureLineNo, FailureDetail, PurchaseOnly);
            exit;
        end;
        if HasLineFilter then
            LineNoFilter := LineNoListFilter(RequestedLineNos);
        BeforeCount := CountAcceptedLines(TemplateName, WorksheetName, LineNoFilter);

        Clear(CreatedTransfers);
        Clear(CreatedAssemblies);
        CarryInProgress := true;
        if not TryCarryOutReport(TemplateName, WorksheetName, LineNoFilter, TempDocumentEntry) then begin
            CarryInProgress := false;
            Clear(CreatedTransfers);
            Clear(CreatedAssemblies);
            ContractParts.RespondWithNativeContext(Argument, 'worksheet', TemplateName + '|' + WorksheetName, CarryNativeExpectedLbl, CarryNativeNextLbl);
            exit;
        end;
        CarryInProgress := false;

        CollectCreatedNativeOrders(TempDocumentEntry);
        AppendCreatedOrders(TempDocumentEntry, Orders);
        if Orders.Count() = 0 then begin
            Answer(Argument, "Bifrost Error Code ori"::BusinessCentralError, CarryNothingErr, 'worksheet', TemplateName + '|' + WorksheetName, CarryNothingExpectedLbl, CarryNothingNextLbl);
            exit;
        end;
        AfterCount := CountAcceptedLines(TemplateName, WorksheetName, LineNoFilter);
        LinesConsumed := 0;
        if BeforeCount > AfterCount then
            LinesConsumed := BeforeCount - AfterCount;
        Response.Add('status', 'Success');
        Response.Add('templateName', TemplateName);
        Response.Add('worksheetName', WorksheetName);
        Response.Add('linesConsumed', LinesConsumed);
        Response.Add('orders', Orders);
        Argument.SetResponseJson(Response);
    end;

    /// <summary>Looks up one worksheet of the required template type. Failure is NotFound, WrongType, Recurring or MissingWorksheet.</summary>
    internal procedure LookupWorksheet(TemplateName: Code[10]; WorksheetName: Code[10]; RequiredType: Enum "Req. Worksheet Template Type"; var Failure: Text): Boolean
    var
        ReqWkshTemplate: Record "Req. Wksh. Template";
        ReqWkshName: Record "Requisition Wksh. Name";
    begin
        Failure := '';
        if not ReqWkshTemplate.Get(TemplateName) then begin
            Failure := 'NotFound';
            exit(false);
        end;
        if ReqWkshTemplate.Type <> RequiredType then begin
            Failure := 'WrongType';
            exit(false);
        end;
        if ReqWkshTemplate.Recurring then begin
            Failure := 'Recurring';
            exit(false);
        end;
        if not ReqWkshName.Get(TemplateName, WorksheetName) then begin
            Failure := 'MissingWorksheet';
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Refuses the whole selection when any line that would be carried out is not a new purchase, transfer or assembly order.</summary>
    internal procedure CollectSafeLines(TemplateName: Code[10]; WorksheetName: Code[10]; HasLineFilter: Boolean; RequestedLineNos: List of [Integer]; PurchaseOnly: Boolean; var Failure: Text; var FailureLineNo: Integer; var FailureDetail: Text): Boolean
    var
        ReqLine: Record "Requisition Line";
        RequestedLineNo: Integer;
        Index: Integer;
    begin
        Failure := '';
        FailureLineNo := 0;
        FailureDetail := '';
        if HasLineFilter then begin
            for Index := 1 to RequestedLineNos.Count() do begin
                RequestedLineNo := RequestedLineNos.Get(Index);
                ReqLine.SetRange("Worksheet Template Name", TemplateName);
                ReqLine.SetRange("Journal Batch Name", WorksheetName);
                ReqLine.SetRange("Line No.", RequestedLineNo);
                if not ReqLine.FindFirst() then begin
                    Failure := 'MissingLine';
                    FailureLineNo := RequestedLineNo;
                    exit(false);
                end;
                if not LineIsSafe(ReqLine, PurchaseOnly, true, Failure, FailureDetail) then begin
                    FailureLineNo := ReqLine."Line No.";
                    exit(false);
                end;
            end;
            exit(true);
        end;

        ReqLine.SetRange("Worksheet Template Name", TemplateName);
        ReqLine.SetRange("Journal Batch Name", WorksheetName);
        ReqLine.SetRange(Type, ReqLine.Type::Item);
        ReqLine.SetRange("Accept Action Message", true);
        ReqLine.SetFilter("Action Message", '<>%1', ReqLine."Action Message"::" ");
        if not ReqLine.FindSet() then begin
            Failure := 'Nothing';
            exit(false);
        end;
        repeat
            if not LineIsSafe(ReqLine, PurchaseOnly, false, Failure, FailureDetail) then begin
                FailureLineNo := ReqLine."Line No.";
                exit(false);
            end;
        until ReqLine.Next() = 0;
        exit(true);
    end;

    /// <summary>Counts accepted item lines with an action message, optionally limited to a line-number filter.</summary>
    internal procedure CountAcceptedLines(TemplateName: Code[10]; WorksheetName: Code[10]; LineNoFilter: Text): Integer
    var
        ReqLine: Record "Requisition Line";
    begin
        ReqLine.SetRange("Worksheet Template Name", TemplateName);
        ReqLine.SetRange("Journal Batch Name", WorksheetName);
        ReqLine.SetRange(Type, ReqLine.Type::Item);
        ReqLine.SetRange("Accept Action Message", true);
        ReqLine.SetFilter("Action Message", '<>%1', ReqLine."Action Message"::" ");
        if LineNoFilter <> '' then
            ReqLine.SetFilter("Line No.", LineNoFilter);
        exit(ReqLine.Count());
    end;

    /// <summary>Appends the suggestion lines left on the worksheet for the same item filters.</summary>
    internal procedure AppendSuggestionLines(TemplateName: Code[10]; WorksheetName: Code[10]; ItemNoFilter: Text; LocationFilter: Text; VariantFilter: Text; var Lines: JsonArray): Integer
    var
        ReqLine: Record "Requisition Line";
        LineJson: JsonObject;
    begin
        Clear(Lines);
        ReqLine.SetRange("Worksheet Template Name", TemplateName);
        ReqLine.SetRange("Journal Batch Name", WorksheetName);
        if ItemNoFilter <> '' then
            ReqLine.SetFilter("No.", ItemNoFilter);
        if LocationFilter <> '' then
            ReqLine.SetFilter("Location Code", LocationFilter);
        if VariantFilter <> '' then
            ReqLine.SetFilter("Variant Code", VariantFilter);
        if ReqLine.FindSet() then
            repeat
                Clear(LineJson);
                LineJson.Add('lineNo', ReqLine."Line No.");
                LineJson.Add('itemNo', ReqLine."No.");
                LineJson.Add('variantCode', ReqLine."Variant Code");
                LineJson.Add('locationCode', ReqLine."Location Code");
                LineJson.Add('quantity', ReqLine.Quantity);
                if ReqLine."Due Date" = 0D then
                    LineJson.Add('dueDate', '')
                else
                    LineJson.Add('dueDate', Format(ReqLine."Due Date", 0, 9));
                LineJson.Add('actionMessage', ActionToken(ReqLine."Action Message"));
                LineJson.Add('replenishmentSystem', ReplenishmentToken(ReqLine."Replenishment System"));
                LineJson.Add('description', ReqLine.Description);
                LineJson.Add('acceptActionMessage', ReqLine."Accept Action Message");
                Lines.Add(LineJson);
            until ReqLine.Next() = 0;
        exit(Lines.Count());
    end;

    /// <summary>Appends created documents from the shared buffer. An unexpected table is returned as Other.</summary>
    internal procedure AppendCreatedOrders(var TempDocumentEntry: Record "Document Entry" temporary; var Orders: JsonArray)
    var
        OrderJson: JsonObject;
    begin
        Clear(Orders);
        TempDocumentEntry.Reset();
        if TempDocumentEntry.FindSet() then
            repeat
                Clear(OrderJson);
                OrderJson.Add('documentType', DocumentTypeToken(TempDocumentEntry."Table ID"));
                OrderJson.Add('documentNo', TempDocumentEntry."Document No.");
                Orders.Add(OrderJson);
            until TempDocumentEntry.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Calc. Item Plan - Plan Wksh.", OnCodeOnAfterSetReqLineFilters, '', false, false)]
    local procedure ScopeWorksheetLineDelete(var ReqLineExtern: Record "Requisition Line"; CurrTemplateName: Code[10]; CurrWorksheetName: Code[10]; var FromDate: Date; var ToDate: Date)
    begin
        // Native planning deletes every suggestion line for the item, on every worksheet, and then commits.
        // While this call is active, keep only the worksheet the caller named.
        if not DeleteScopeActive then
            exit;
        if CurrTemplateName = '' then
            exit;
        ReqLineExtern.SetRange("Worksheet Template Name", CurrTemplateName);
        ReqLineExtern.SetRange("Journal Batch Name", CurrWorksheetName);
        if (FromDate = 0D) and (ToDate = 0D) and (CurrWorksheetName = '') then
            exit;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Calculate Plan - Plan. Wksh.", OnOnPreDataItemOnAfterCalcShouldSetAtStartPosition, '', false, false)]
    local procedure SuppressPlanningConfirm(Item: Record Item; PlanningErrorLog: Record "Planning Error Log"; RequisitionLine: Record "Requisition Line"; var SetAtStartPosition: Boolean; var ShouldSetAtStartPosition: Boolean)
    begin
        if not DeleteScopeActive then
            exit;
        ShouldSetAtStartPosition := false;
        if Item."No." = 'PW-UNUSED' then
            ShouldSetAtStartPosition := PlanningErrorLog.IsEmpty() or RequisitionLine.IsEmpty() or (not SetAtStartPosition);
    end;

    [EventSubscriber(ObjectType::Report, Report::"Carry Out Action Msg. - Plan.", OnBeforeShowResult, '', false, false)]
    local procedure SuppressCarryOutDialog(var IsHandled: Boolean)
    begin
        if not CarryInProgress then
            exit;
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnAfterInsertTransLine, '', false, false)]
    local procedure TrackCreatedTransfer(var TransHeader: Record "Transfer Header"; var ReqLine: Record "Requisition Line"; var TransLine: Record "Transfer Line"; var NextLineNo: Integer)
    begin
        if not CarryInProgress then
            exit;
        if ReqLine."Action Message" <> ReqLine."Action Message"::New then
            exit;
        if not CreatedTransfers.Contains(TransHeader."No.") then
            CreatedTransfers.Add(TransHeader."No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Asm. Carry Out Action", OnAfterInsertAsmHeader, '', false, false)]
    local procedure TrackCreatedAssembly(var ReqLine: Record "Requisition Line"; var AsmHeader: Record "Assembly Header")
    begin
        if not CarryInProgress then
            exit;
        if ReqLine."Action Message" <> ReqLine."Action Message"::New then
            exit;
        if not CreatedAssemblies.Contains(AsmHeader."No.") then
            CreatedAssemblies.Add(AsmHeader."No.");
    end;

    local procedure CollectCreatedNativeOrders(var TempDocumentEntry: Record "Document Entry" temporary)
    var
        TransferHeader: Record "Transfer Header";
        AssemblyHeader: Record "Assembly Header";
        DocumentNo: Code[20];
    begin
        // The resilient native runner creates transfer/assembly orders in a nested codeunit whose
        // temporary document buffer is not shared with the report. Keep only committed headers:
        // an event can fire before the native transaction subsequently rolls back.
        TransferHeader.ReadIsolation := IsolationLevel::ReadCommitted;
        AssemblyHeader.ReadIsolation := IsolationLevel::ReadCommitted;
        foreach DocumentNo in CreatedTransfers do
            if TransferHeader.Get(DocumentNo) then
                AddCreatedOrder(TempDocumentEntry, Database::"Transfer Header", DocumentNo);
        foreach DocumentNo in CreatedAssemblies do
            if AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, DocumentNo) then
                AddCreatedOrder(TempDocumentEntry, Database::"Assembly Header", DocumentNo);
        Clear(CreatedTransfers);
        Clear(CreatedAssemblies);
    end;

    local procedure AddCreatedOrder(var TempDocumentEntry: Record "Document Entry" temporary; TableId: Integer; DocumentNo: Code[20])
    var
        EntryNo: Integer;
    begin
        TempDocumentEntry.Reset();
        TempDocumentEntry.SetRange("Table ID", TableId);
        TempDocumentEntry.SetRange("Document No.", DocumentNo);
        if not TempDocumentEntry.IsEmpty() then begin
            TempDocumentEntry.Reset();
            exit;
        end;
        TempDocumentEntry.Reset();
        if TempDocumentEntry.FindLast() then
            EntryNo := TempDocumentEntry."Entry No.";
        TempDocumentEntry.Init();
        TempDocumentEntry."Entry No." := EntryNo + 1;
        TempDocumentEntry."Table ID" := TableId;
        TempDocumentEntry."Document No." := DocumentNo;
        TempDocumentEntry.Insert();
    end;

    local procedure ResolvePlanningWorksheet(var Argument: Record "Message Argument ori"; Request: JsonObject; var TemplateName: Code[10]; var WorksheetName: Code[10]): Boolean
    var
        TemplateText: Text;
        WorksheetText: Text;
        SubjectTemplate: Text;
        SubjectWorksheet: Text;
        Failure: Text;
        Parts: List of [Text];
    begin
        if Argument.Subject <> '' then begin
            Parts := Argument.Subject.Split('|');
            if Parts.Count() <> 2 then begin
                Answer(Argument, "Bifrost Error Code ori"::InvalidParameter, SubjectErr, 'subject', Argument.Subject, SubjectExpectedLbl, SubjectNextLbl);
                exit(false);
            end;
            SubjectTemplate := Parts.Get(1);
            SubjectWorksheet := Parts.Get(2);
            if (SubjectTemplate = '') or (SubjectWorksheet = '') or (StrLen(SubjectTemplate) > 10) or (StrLen(SubjectWorksheet) > 10) then begin
                Answer(Argument, "Bifrost Error Code ori"::InvalidParameter, SubjectErr, 'subject', Argument.Subject, SubjectExpectedLbl, SubjectNextLbl);
                exit(false);
            end;
        end;
        if not ReadOptionalText(Request, 'templateName', 10, Argument, TemplateText) then
            exit(false);
        if not ReadOptionalText(Request, 'worksheetName', 10, Argument, WorksheetText) then
            exit(false);
        if (SubjectTemplate <> '') and (TemplateText <> '') and (UpperCase(SubjectTemplate) <> UpperCase(TemplateText)) then begin
            Answer(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, 'templateName', TemplateText, SubjectTemplate, ConflictNextLbl);
            exit(false);
        end;
        if (SubjectWorksheet <> '') and (WorksheetText <> '') and (UpperCase(SubjectWorksheet) <> UpperCase(WorksheetText)) then begin
            Answer(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, 'worksheetName', WorksheetText, SubjectWorksheet, ConflictNextLbl);
            exit(false);
        end;
        if TemplateText <> '' then
            TemplateName := CopyStr(TemplateText, 1, MaxStrLen(TemplateName))
        else
            TemplateName := CopyStr(SubjectTemplate, 1, MaxStrLen(TemplateName));
        if WorksheetText <> '' then
            WorksheetName := CopyStr(WorksheetText, 1, MaxStrLen(WorksheetName))
        else
            WorksheetName := CopyStr(SubjectWorksheet, 1, MaxStrLen(WorksheetName));
        if TemplateName = '' then begin
            Answer(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(ResolveMissingErr, 'templateName'), 'templateName', '', NameExpectedLbl, SubjectNextLbl);
            exit(false);
        end;
        if WorksheetName = '' then begin
            Answer(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(ResolveMissingErr, 'worksheetName'), 'worksheetName', '', NameExpectedLbl, SubjectNextLbl);
            exit(false);
        end;
        if LookupWorksheet(TemplateName, WorksheetName, Enum::"Req. Worksheet Template Type"::Planning, Failure) then
            exit(true);
        case Failure of
            'WrongType':
                Answer(Argument, "Bifrost Error Code ori"::RecordNotFound, WrongTypeErr, 'templateName', TemplateName, 'Planning', WrongTypeNextLbl);
            'Recurring':
                Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, RecurringErr, 'templateName', TemplateName, RecurringExpectedLbl, RecurringNextLbl);
            'MissingWorksheet':
                Answer(Argument, "Bifrost Error Code ori"::RecordNotFound, MissingWorksheetErr, 'worksheetName', WorksheetName, TemplateName, NotFoundNextLbl);
            else
                Answer(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'templateName', TemplateName + '|' + WorksheetName, ExistingExpectedLbl, NotFoundNextLbl);
        end;
        exit(false);
    end;

    local procedure AnswerCarryFailure(var Argument: Record "Message Argument ori"; Failure: Text; FailureLineNo: Integer; FailureDetail: Text; PurchaseOnly: Boolean)
    var
        LineText: Text;
    begin
        LineText := Format(FailureLineNo, 0, 9);
        case Failure of
            'Nothing':
                Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, RefuseNothingErr, 'worksheet', '', RefuseNothingExpectedLbl, RefuseNothingNextLbl);
            'MissingLine':
                Answer(Argument, "Bifrost Error Code ori"::RecordNotFound, RefuseMissingErr, 'lineNos', LineText, LineExpectedLbl, MissingNextLbl);
            'NotAccepted':
                Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, NotAcceptedErr, 'lineNos', LineText, ActionExpectedLbl, NotAcceptedNextLbl);
            'UnsafeAction':
                Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, ActionErr, 'actionMessage', FailureDetail, ActionExpectedLbl, ActionNextLbl);
            'UnsafeDocument':
                Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, DocumentErr, 'lineNo', LineText, DocumentExpectedLbl, DocumentNextLbl);
            'UnsafeProd':
                Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, ProdErr, 'replenishmentSystem', FailureDetail, SupplyExpectedLbl, ProdNextLbl);
            else
                if PurchaseOnly then
                    Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, PurchaseOnlyErr, 'replenishmentSystem', FailureDetail, PurchaseExpectedLbl, PurchaseOnlyNextLbl)
                else
                    Answer(Argument, "Bifrost Error Code ori"::PreconditionFailed, ReplenishmentErr, 'replenishmentSystem', FailureDetail, SupplyExpectedLbl, ReplenishmentNextLbl);
        end;
    end;

    local procedure LineIsSafe(ReqLine: Record "Requisition Line"; PurchaseOnly: Boolean; ExplicitLine: Boolean; var Failure: Text; var FailureDetail: Text): Boolean
    begin
        if ExplicitLine then
            if (not ReqLine."Accept Action Message") or (ReqLine."Action Message" = ReqLine."Action Message"::" ") then begin
                Failure := 'NotAccepted';
                exit(false);
            end;
        if ReqLine."Action Message" <> ReqLine."Action Message"::New then begin
            Failure := 'UnsafeAction';
            FailureDetail := ActionToken(ReqLine."Action Message");
            exit(false);
        end;
        if ReqLine."Ref. Order No." <> '' then begin
            Failure := 'UnsafeDocument';
            FailureDetail := ReqLine."Ref. Order No.";
            exit(false);
        end;
        if (ReqLine."Replenishment System" = ReqLine."Replenishment System"::"Prod. Order") or (ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::"Prod. Order") then begin
            Failure := 'UnsafeProd';
            FailureDetail := ReplenishmentToken(ReqLine."Replenishment System");
            exit(false);
        end;
        if PurchaseOnly then begin
            if (ReqLine."Replenishment System" <> ReqLine."Replenishment System"::Purchase) or (ReqLine."Ref. Order Type" <> ReqLine."Ref. Order Type"::Purchase) then begin
                Failure := 'UnsafeReplenishment';
                FailureDetail := ReplenishmentToken(ReqLine."Replenishment System");
                exit(false);
            end;
            exit(true);
        end;
        if not ReplenishmentMatches(ReqLine) then begin
            Failure := 'UnsafeReplenishment';
            FailureDetail := ReplenishmentToken(ReqLine."Replenishment System");
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReplenishmentMatches(ReqLine: Record "Requisition Line"): Boolean
    begin
        case ReqLine."Replenishment System" of
            ReqLine."Replenishment System"::Purchase:
                exit(ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::Purchase);
            ReqLine."Replenishment System"::Transfer:
                exit(ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::Transfer);
            ReqLine."Replenishment System"::Assembly:
                exit(ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::Assembly);
        end;
        exit(false);
    end;

    local procedure KeysAreKnown(AllowedCsv: Text; Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        Allowed: List of [Text];
        KeyName: Text;
        ExpectedText: Text;
    begin
        if AllowedCsv.Contains('mode') then
            ExpectedText := CalculateExpectedLbl
        else
            ExpectedText := CarryExpectedLbl;
        Allowed := AllowedCsv.Split(',');
        foreach KeyName in Request.Keys() do
            if not Allowed.Contains(KeyName) then begin
                Answer(Argument, "Bifrost Error Code ori"::InvalidParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), ExpectedText, UnknownNextLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure AcceptExpectedCount(Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        CountValue: Decimal;
    begin
        if not Request.Get('expectedCount', Token) then
            exit(true);
        if Token.IsValue() and Token.AsValue().IsNull() then
            exit(true);
        if not Token.IsValue() then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ExpectFormatErr, 'expectedCount', '', ExpectExpectedLbl, ExpectNextLbl);
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if not Evaluate(CountValue, Serialized, 9) or (CountValue <> Round(CountValue, 1)) then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ExpectFormatErr, 'expectedCount', Serialized, ExpectExpectedLbl, ExpectNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadLineNumbers(Request: JsonObject; var Argument: Record "Message Argument ori"; var HasLineFilter: Boolean; var LineNos: List of [Integer]): Boolean
    var
        Token: JsonToken;
        Element: JsonToken;
        Serialized: Text;
        LineNo: Integer;
    begin
        Clear(LineNos);
        HasLineFilter := false;
        if not Request.Get('lineNos', Token) then
            exit(true);
        if Token.IsValue() and Token.AsValue().IsNull() then
            exit(true);
        if not Token.IsArray() then begin
            Token.WriteTo(Serialized);
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, LinesFormatErr, 'lineNos', Serialized, LinesExpectedLbl, LinesNextLbl);
            exit(false);
        end;
        if Token.AsArray().Count() = 0 then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameter, EmptyErr, 'lineNos', '[]', LinesExpectedLbl, LinesNextLbl);
            exit(false);
        end;
        foreach Element in Token.AsArray() do begin
            if not Element.IsValue() then begin
                Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, LinesFormatErr, 'lineNos', '', LinesExpectedLbl, LinesNextLbl);
                exit(false);
            end;
            Element.WriteTo(Serialized);
            if (DelChr(Serialized, '=', '-0123456789') <> '') or not Evaluate(LineNo, Serialized, 9) or (LineNo <= 0) then begin
                Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, PositiveErr, 'lineNos', Serialized, LinesExpectedLbl, LinesNextLbl);
                exit(false);
            end;
            LineNos.Add(LineNo);
        end;
        HasLineFilter := true;
        exit(true);
    end;

    local procedure ReadOptionalText(Request: JsonObject; Name: Text; MaxLength: Integer; var Argument: Record "Message Argument ori"; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Value := '';
        if not Request.Get(Name, Token) then
            exit(true);
        if Token.IsValue() and Token.AsValue().IsNull() then
            exit(true);
        if not Token.IsValue() then begin
            Token.WriteTo(Serialized);
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(OptFormatErr, Name), Name, Serialized, TextExpectedLbl, StrSubstNo(OptNextLbl, Name, MaxLength));
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if not Serialized.StartsWith('"') then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(OptFormatErr, Name), Name, Serialized, TextExpectedLbl, StrSubstNo(OptNextLbl, Name, MaxLength));
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if StrLen(Value) > MaxLength then begin
            Answer(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(LengthErr, Name, MaxLength), Name, Value, StrSubstNo(OptNextLbl, Name, MaxLength), StrSubstNo(OptNextLbl, Name, MaxLength));
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadRequiredText(Request: JsonObject; Name: Text; MaxLength: Integer; var Argument: Record "Message Argument ori"; var Value: Text): Boolean
    begin
        exit(ReadOptionalText(Request, Name, MaxLength, Argument, Value));
    end;

    local procedure ReadDate(DateText: Text; var ParsedDate: Date): Boolean
    begin
        ParsedDate := 0D;
        if StrLen(DateText) <> 10 then
            exit(false);
        if CopyStr(DateText, 5, 1) <> '-' then
            exit(false);
        if CopyStr(DateText, 8, 1) <> '-' then
            exit(false);
        exit(Evaluate(ParsedDate, DateText, 9) and (ParsedDate <> 0D));
    end;

    local procedure FiltersAreValid(ItemNoFilter: Text; LocationFilter: Text; VariantFilter: Text): Boolean
    begin
        exit(TryApplyFilters(ItemNoFilter, LocationFilter, VariantFilter));
    end;

    [TryFunction]
    local procedure TryApplyFilters(ItemNoFilter: Text; LocationFilter: Text; VariantFilter: Text)
    var
        Item: Record Item;
        ReqLine: Record "Requisition Line";
    begin
        if ItemNoFilter <> '' then begin
            Item.SetFilter("No.", ItemNoFilter);
            ReqLine.SetFilter("No.", ItemNoFilter);
        end;
        if LocationFilter <> '' then begin
            Item.SetFilter("Location Filter", LocationFilter);
            ReqLine.SetFilter("Location Code", LocationFilter);
        end;
        if VariantFilter <> '' then begin
            Item.SetFilter("Variant Filter", VariantFilter);
            ReqLine.SetFilter("Variant Code", VariantFilter);
        end;
    end;

    [TryFunction]
    local procedure TryCalculateReport(TemplateName: Code[10]; WorksheetName: Code[10]; Regenerative: Boolean; FromDate: Date; ToDate: Date; ItemNoFilter: Text; LocationFilter: Text; VariantFilter: Text)
    var
        Item: Record Item;
        CalculatePlan: Report "Calculate Plan - Plan. Wksh.";
    begin
        Item.SetRange(Type, Item.Type::Inventory);
        if ItemNoFilter <> '' then
            Item.SetFilter("No.", ItemNoFilter);
        if LocationFilter <> '' then
            Item.SetFilter("Location Filter", LocationFilter);
        if VariantFilter <> '' then
            Item.SetFilter("Variant Filter", VariantFilter);
        CalculatePlan.SetTableView(Item);
        CalculatePlan.UseRequestPage(false);
        CalculatePlan.SetTemplAndWorksheet(TemplateName, WorksheetName, Regenerative);
        CalculatePlan.InitializeRequest(FromDate, ToDate, true, true, true, '', 0D, true);
        CalculatePlan.Run();
    end;

    [TryFunction]
    local procedure TryCarryOutReport(TemplateName: Code[10]; WorksheetName: Code[10]; LineNoFilter: Text; var TempDocumentEntry: Record "Document Entry" temporary)
    var
        ReqLine: Record "Requisition Line";
        CarryOut: Report "Carry Out Action Msg. - Plan.";
    begin
        TempDocumentEntry.Reset();
        TempDocumentEntry.DeleteAll();
        ReqLine."Worksheet Template Name" := TemplateName;
        ReqLine."Journal Batch Name" := WorksheetName;
        ReqLine.SetRange("Worksheet Template Name", TemplateName);
        ReqLine.SetRange("Journal Batch Name", WorksheetName);
        if LineNoFilter <> '' then
            ReqLine.SetFilter("Line No.", LineNoFilter);
        CarryOut.SetHideDialog(true);
        CarryOut.InitializeRequest(0, 1, 1, 1);
        CarryOut.SetReqWkshLine(ReqLine);
        CarryOut.SetCreatedDocumentBuffer(TempDocumentEntry);
        CarryOut.UseRequestPage(false);
        CarryOut.Run();
    end;

    local procedure LineNoListFilter(LineNos: List of [Integer]) Result: Text
    var
        Index: Integer;
    begin
        for Index := 1 to LineNos.Count() do begin
            if Result <> '' then
                Result += '|';
            Result += Format(LineNos.Get(Index), 0, 9);
        end;
    end;

    local procedure ActionToken(ActionMessage: Enum "Action Message Type"): Text
    begin
        case ActionMessage of
            ActionMessage::New:
                exit('New');
            ActionMessage::"Change Qty.":
                exit('ChangeQty');
            ActionMessage::Reschedule:
                exit('Reschedule');
            ActionMessage::"Resched. & Chg. Qty.":
                exit('RescheduleAndChangeQty');
            ActionMessage::Cancel:
                exit('Cancel');
        end;
        exit('None');
    end;

    local procedure ReplenishmentToken(ReplenishmentSystem: Enum "Replenishment System"): Text
    begin
        case ReplenishmentSystem of
            ReplenishmentSystem::Purchase:
                exit('Purchase');
            ReplenishmentSystem::Transfer:
                exit('Transfer');
            ReplenishmentSystem::Assembly:
                exit('Assembly');
            ReplenishmentSystem::"Prod. Order":
                exit('ProdOrder');
        end;
        exit('Other');
    end;

    local procedure DocumentTypeToken(TableId: Integer): Text
    begin
        case TableId of
            Database::"Purchase Header":
                exit('Purchase');
            Database::"Transfer Header":
                exit('Transfer');
            Database::"Assembly Header":
                exit('Assembly');
        end;
        exit('Other');
    end;

    local procedure Answer(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ErrorMessage: Text; ParameterName: Text; ReceivedValue: Text; ExpectedValue: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, ErrorMessage, CopyStr(ParameterName, 1, 250), CopyStr(ReceivedValue, 1, 250), CopyStr(ExpectedValue, 1, 250), NextStep);
    end;
}
