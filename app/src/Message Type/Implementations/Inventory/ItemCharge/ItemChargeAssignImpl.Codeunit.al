namespace Origo.Bifrost.Inventory;

using Microsoft.Finance.Currency;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCharge.Assign. Spreads a charge line over item lines the way the Item Charge Assignment page does:
/// by a suggest method over the document's own item lines, or over explicit target lines.
/// The write runs in Item Charge Assign Proc ori so a failure rolls back and answers a clean error.
/// </summary>
codeunit 10036919 "Item Charge Assign Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        GetImpl: Codeunit "Item Charge Get Impl ori";
        DocumentTypeKeyTok: Label 'documentType', Locked = true;
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        LineNoKeyTok: Label 'lineNo', Locked = true;
        MethodKeyTok: Label 'method', Locked = true;
        TargetsKeyTok: Label 'targets', Locked = true;
        AppliesToKeyTok: Label 'appliesToDocType', Locked = true;
        QtyToAssignKeyTok: Label 'qtyToAssign', Locked = true;
        PurchaseTok: Label 'purchase', Locked = true;
        EquallyTok: Label 'equally', Locked = true;
        ByAmountTok: Label 'byamount', Locked = true;
        ByWeightTok: Label 'byweight', Locked = true;
        ByVolumeTok: Label 'byvolume', Locked = true;
        MethodExpectedTok: Label 'equally|byAmount|byWeight|byVolume', Locked = true;
        MeasureExpectedTok: Label 'equally|byAmount', Locked = true;
        PurchaseAppliesToExpectedTok: Label 'order|invoice|returnOrder|creditMemo|receipt|transferReceipt|returnShipment|salesShipment|returnReceipt', Locked = true;
        SalesAppliesToExpectedTok: Label 'order|invoice|returnOrder|creditMemo|shipment|returnReceipt', Locked = true;
        AllowedKeysTok: Label 'documentType, documentNo, systemId, lineNo, method, targets', Locked = true;
        AllowedTargetKeysTok: Label 'appliesToDocType, documentNo, lineNo, qtyToAssign', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        ObjectExpectedTok: Label 'object', Locked = true;
        PositiveExpectedTok: Label '> 0', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PurchAssignment: Record "Item Charge Assignment (Purch)";
        SalesAssignment: Record "Item Charge Assignment (Sales)";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCharge) then
            exit(false);
        exit(PurchAssignment.WritePermission() and SalesAssignment.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Charge Assignment (Purch)");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Assigns a purchase or sales item charge to item lines, receipts or shipments.', Comment = 'is-IS=Úthlutar kostnaðarauka í innkaupum eða sölu á vörulínur, móttökur eða afhendingar.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item charge, assign, freight, customs, landed cost', Comment = 'is-IS=kostnaðarauki, úthluta, flutningskostnaður, tollur, kostnaðarverð';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Spreads freight, customs or another item charge over item lines equally, by amount, by weight or by volume, so the cost lands on the items.', Comment = 'is-IS=Dreifir flutningskostnaði, tolli eða öðrum kostnaðarauka á vörulínur jafnt, eftir upphæð, þyngd eða rúmmáli, svo kostnaðurinn leggist á vörurnar.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemCharge.Assign');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The charge line, named by its document and line number.', Comment = 'is-IS=Kostnaðaraukalínan, tilgreind með skjali sínu og línunúmeri.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo + data.lineNo', 'text', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentTypeLbl: Label 'purchase or sales. Says which kind of document holds the charge line.', Comment = 'is-IS=purchase eða sales. Segir hvers konar skjal geymir kostnaðaraukalínuna.';
        DocumentNoLbl: Label 'Number of the open purchase or sales document (order, invoice, return order or credit memo). Send this or systemId.', Comment = 'is-IS=Númer opins innkaupa- eða söluskjals (pöntun, reikningur, vöruskilapöntun eða kreditreikningur). Sendu þetta eða systemId.';
        SystemIdLbl: Label 'systemId of the document. Send this or documentNo.', Comment = 'is-IS=systemId skjalsins. Sendu þetta eða documentNo.';
        LineNoLbl: Label 'Line number of the Charge (Item) line.', Comment = 'is-IS=Línunúmer línunnar af gerðinni Kostnaðarauki (vara).';
        MethodLbl: Label 'equally, byAmount, byWeight or byVolume. Spreads the charge over the item lines of the same document, as Suggest Item Charge Assignment does. Send this or targets.', Comment = 'is-IS=equally, byAmount, byWeight eða byVolume. Dreifir kostnaðaraukanum á vörulínur sama skjals, eins og Leggja til úthlutun kostnaðarauka gerir. Sendu þetta eða targets.';
        TargetsLbl: Label 'Explicit lines to assign to. Each entry has appliesToDocType, documentNo, lineNo and qtyToAssign. appliesToDocType is order, invoice, returnOrder or creditMemo for an open document line, or receipt, transferReceipt, returnShipment, salesShipment or returnReceipt (purchase) and shipment or returnReceipt (sales) for a posted line. Send this or method.', Comment = 'is-IS=Tilteknar línur til að úthluta á. Hver færsla hefur appliesToDocType, documentNo, lineNo og qtyToAssign. appliesToDocType er order, invoice, returnOrder eða creditMemo fyrir línu á opnu skjali, eða receipt, transferReceipt, returnShipment, salesShipment eða returnReceipt (innkaup) og shipment eða returnReceipt (sala) fyrir bókaða línu. Sendu þetta eða method.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', true, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', true, LineNoLbl));
        Parameters.Add(ContractMgt.Parameter('method', 'string', false, MethodLbl));
        Parameters.Add(ContractMgt.Parameter('targets', 'array', false, TargetsLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Rows: JsonArray;
        Row: JsonObject;
    begin
        Response.Add('status', 'Success');
        Response.Add('documentType', 'purchase');
        Response.Add('documentNo', '106001');
        Response.Add('lineNo', 30000);
        Response.Add('replacedCount', 0);
        Row.Add('lineNo', 10000);
        Row.Add('appliesToDocType', 'order');
        Row.Add('appliesToDocNo', '106001');
        Row.Add('appliesToDocLineNo', 10000);
        Row.Add('itemNo', '1896-S');
        Row.Add('description', 'ATHENS Desk');
        Row.Add('qtyToAssign', 1);
        Row.Add('amountToAssign', 100);
        Row.Add('qtyAssigned', 0);
        Rows.Add(Row);
        Response.Add('assignments', Rows);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'documentType or lineNo is missing, neither documentNo nor systemId was sent, neither method nor targets was sent, or a target lacks a key.', Comment = 'is-IS=documentType eða lineNo vantar, hvorki documentNo né systemId var sent, hvorki method né targets var sent, eða lykil vantar á mark.';
        MissingFixLbl: Label 'Send documentType, lineNo, documentNo or systemId, and method or targets.', Comment = 'is-IS=Sendu documentType, lineNo, documentNo eða systemId, og method eða targets.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, systemId is not a GUID, or a target is not an object.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, systemId er ekki GUID, eða mark er ekki hlutur.';
        FormatFixLbl: Label 'Send documentType, documentNo, systemId and method as text, lineNo as a whole number, and targets as an array of objects.', Comment = 'is-IS=Sendu documentType, documentNo, systemId og method sem texta, lineNo sem heiltölu og targets sem fylki af hlutum.';
        UnknownWhenLbl: Label 'The request or a target contains a key this type does not read.', Comment = 'is-IS=Beiðnin eða mark inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId, lineNo, method and targets; a target allows appliesToDocType, documentNo, lineNo and qtyToAssign.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, systemId, lineNo, method og targets; mark leyfir appliesToDocType, documentNo, lineNo og qtyToAssign.';
        NotFoundWhenLbl: Label 'No open document, no charge line or no target line matched.', Comment = 'is-IS=Ekkert opið skjal, engin kostnaðaraukalína eða engin marklína fannst.';
        NotFoundFixLbl: Label 'Check documentNo or systemId, documentType and lineNo, and the documentNo and lineNo of each target.', Comment = 'is-IS=Athugaðu documentNo eða systemId, documentType og lineNo, og documentNo og lineNo hvers marks.';
        AmbiguousWhenLbl: Label 'Several documents of different types have this number.', Comment = 'is-IS=Nokkur skjöl af ólíkum gerðum hafa þetta númer.';
        AmbiguousFixLbl: Label 'Send the systemId of the document instead of documentNo.', Comment = 'is-IS=Sendu systemId skjalsins í stað documentNo.';
        ConflictWhenLbl: Label 'documentNo and systemId were both sent, or method and targets were both sent.', Comment = 'is-IS=documentNo og systemId voru bæði send, eða method og targets voru bæði send.';
        ConflictFixLbl: Label 'Send one of documentNo or systemId, and one of method or targets.', Comment = 'is-IS=Sendu annaðhvort documentNo eða systemId, og annaðhvort method eða targets.';
        NotChargeWhenLbl: Label 'The line is not an item charge line.', Comment = 'is-IS=Línan er ekki kostnaðaraukalína.';
        NotChargeFixLbl: Label 'Pass the line no. of a Charge (Item) line.', Comment = 'is-IS=Sendu línunúmer línu af gerðinni Kostnaðarauki (vara).';
        NothingWhenLbl: Label 'The charge line has no quantity to invoice, or the document has no item line to spread the charge over.', Comment = 'is-IS=Kostnaðaraukalínan hefur ekkert magn til reikningsfærslu, eða skjalið hefur enga vörulínu til að dreifa kostnaðaraukanum á.';
        NothingFixLbl: Label 'Set a quantity to invoice on the charge line, add an item line, or send targets with posted lines.', Comment = 'is-IS=Fylltu út magn til reikningsfærslu á kostnaðaraukalínunni, bættu við vörulínu, eða sendu targets með bókuðum línum.';
        InvalidLineWhenLbl: Label 'A target line is not an item line or belongs to another vendor or customer.', Comment = 'is-IS=Marklína er ekki vörulína eða tilheyrir öðrum lánardrottni eða viðskiptamanni.';
        InvalidLineFixLbl: Label 'Use lines from the same vendor/customer.', Comment = 'is-IS=Notaðu línur frá sama lánardrottni/viðskiptamanni.';
        MeasureWhenLbl: Label 'byWeight or byVolume was requested and the item lines have no weight or volume.', Comment = 'is-IS=Beðið var um byWeight eða byVolume en vörulínurnar hafa hvorki þyngd né rúmmál.';
        MeasureFixLbl: Label 'Use equally or byAmount, or fill the item''s weight/volume.', Comment = 'is-IS=Notaðu equally eða byAmount, eða fylltu út þyngd/rúmmál vörunnar.';
        ValueWhenLbl: Label 'documentType, method or appliesToDocType has a value this type does not know, or qtyToAssign is not greater than zero.', Comment = 'is-IS=documentType, method eða appliesToDocType hefur gildi sem þessi tegund þekkir ekki, eða qtyToAssign er ekki stærra en núll.';
        ValueFixLbl: Label 'Send purchase or sales, one of the listed methods and target types, and a positive qtyToAssign.', Comment = 'is-IS=Sendu purchase eða sales, eina af aðferðunum og gerðum marka sem eru taldar upp, og jákvætt qtyToAssign.';
        PermissionWhenLbl: Label 'The caller cannot change item charge assignments or read the document.', Comment = 'is-IS=Kallandinn getur ekki breytt úthlutunum kostnaðarauka eða lesið skjalið.';
        PermissionFixLbl: Label 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Full ori (með viðbótinni BIFROST InvWrite ori) og Business Central heimildasafni sem getur breytt þessum töflum.';
        BusinessCentralWhenLbl: Label 'Business Central refused the assignment, for example because the charge line is already fully invoiced.', Comment = 'is-IS=Business Central hafnaði úthlutuninni, til dæmis af því að kostnaðaraukalínan er þegar fullreikningsfærð.';
        BusinessCentralFixLbl: Label 'Read the error text, correct the document in Business Central, and send the request again.', Comment = 'is-IS=Lestu villutextann, lagaðu skjalið í Business Central og sendu beiðnina aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousWhenLbl, AmbiguousFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotChargeWhenLbl, NotChargeFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NothingWhenLbl, NothingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, InvalidLineWhenLbl, InvalidLineFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, MeasureWhenLbl, MeasureFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ValueWhenLbl, ValueFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, BusinessCentralWhenLbl, BusinessCentralFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RelatedLbl: Label 'Read the current assignment and the unassigned quantity without changing anything.', Comment = 'is-IS=Lesa núverandi úthlutun og óúthlutað magn án þess að breyta neinu.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemCharge.Get', RelatedLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MethodTitleLbl: Label 'Spread a freight charge equally over the item lines of a purchase order', Comment = 'is-IS=Dreifa flutningskostnaði jafnt á vörulínur innkaupapöntunar';
        TargetsTitleLbl: Label 'Assign a freight charge on a purchase invoice to a posted receipt line', Comment = 'is-IS=Úthluta flutningskostnaði á innkaupareikningi á bókaða móttökulínu';
    begin
        Examples.Add(ContractMgt.Example(MethodTitleLbl, '{"documentType":"purchase","documentNo":"106001","lineNo":30000,"method":"equally"}', '{"status":"Success","documentType":"purchase","documentNo":"106001","lineNo":30000,"replacedCount":0,"assignments":[{"lineNo":10000,"appliesToDocType":"order","appliesToDocNo":"106001","appliesToDocLineNo":10000,"itemNo":"1896-S","description":"ATHENS Desk","qtyToAssign":0.5,"amountToAssign":50,"qtyAssigned":0},{"lineNo":20000,"appliesToDocType":"order","appliesToDocNo":"106001","appliesToDocLineNo":20000,"itemNo":"1900-S","description":"PARIS Guest Chair, black","qtyToAssign":0.5,"amountToAssign":50,"qtyAssigned":0}]}'));
        Examples.Add(ContractMgt.Example(TargetsTitleLbl, '{"documentType":"purchase","documentNo":"108001","lineNo":10000,"targets":[{"appliesToDocType":"receipt","documentNo":"107001","lineNo":10000,"qtyToAssign":1}]}', '{"status":"Success","documentType":"purchase","documentNo":"108001","lineNo":10000,"replacedCount":0,"assignments":[{"lineNo":10000,"appliesToDocType":"receipt","appliesToDocNo":"107001","appliesToDocLineNo":10000,"itemNo":"1896-S","description":"ATHENS Desk","qtyToAssign":1,"amountToAssign":100,"qtyAssigned":0}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Assigns a freight, customs or other item charge line on an open purchase or sales document to item lines, so the cost lands on the items, as the Item Charge Assignment page does. Send method to spread the charge over the item lines of the same document (equally, byAmount, byWeight or byVolume), or targets to name the lines yourself, including posted receipt, shipment, transfer receipt and return lines. The answer lists the assignment rows with qtyToAssign and amountToAssign.', Comment = 'is-IS=Úthlutar línu með flutningskostnaði, tolli eða öðrum kostnaðarauka á opnu innkaupa- eða söluskjali á vörulínur, svo kostnaðurinn leggist á vörurnar, eins og síðan Úthlutun kostnaðarauka gerir. Sendu method til að dreifa kostnaðaraukanum á vörulínur sama skjals (equally, byAmount, byWeight eða byVolume), eða targets til að tilgreina línurnar sjálf, þar á meðal bókaðar móttöku-, afhendingar-, flutningsmóttöku- og skilalínur. Svarið telur upp úthlutunarlínurnar með qtyToAssign og amountToAssign.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'The charge is spread over the quantity to invoice on the charge line. Assigning again replaces the earlier assignment rows of that charge line, and replacedCount says how many rows were replaced; rows that are already partly invoiced keep their invoiced quantity. A refusal writes nothing. A successful call saves the assignment but does not post the document; post it with the purchase or sales posting message type. Generic record writes to the assignment tables are refused, so use this type to change them.', Comment = 'is-IS=Kostnaðaraukanum er dreift á magnið til reikningsfærslu á kostnaðaraukalínunni. Ef úthlutað er aftur koma nýjar úthlutunarlínur í stað fyrri lína þeirrar kostnaðaraukalínu, og replacedCount segir hve mörgum línum var skipt út; línur sem eru þegar reikningsfærðar að hluta halda reikningsfærðu magni sínu. Höfnun skrifar ekkert. Vel heppnað kall vistar úthlutunina en bókar ekki skjalið; bókaðu það með bókunarskilaboðategund innkaupa eða sölu. Almennar skráaskrif í úthlutunartöflurnar eru ekki leyfð, svo notaðu þessa tegund til að breyta þeim.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TouchDeclaredKeys(RequestJson);
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if not Codeunit.Run(Codeunit::"Item Charge Assign Proc ori", Argument) then
            Argument.RespondWithLastError();
    end;

    /// <summary>
    /// Writes the assignment the request describes and sets the response. Runs inside Item Charge Assign Proc ori,
    /// after ValidateRequest has refused bad requests, so an error rolls the whole write back.
    /// </summary>
    /// <param name="Argument">The message argument with the validated request.</param>
    procedure RunAssign(var Argument: Record "Message Argument ori")
    var
        PurchHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Targets: JsonArray;
        DocumentType: Text;
        Method: Text;
        LineNo: Integer;
        ReplacedCount: Integer;
        HasTargets: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        DocumentType := LowerCase(GetImpl.ReadText(RequestJson, 'documentType'));
        LineNo := GetImpl.ReadInteger(RequestJson, 'lineNo');
        Method := LowerCase(GetImpl.ReadText(RequestJson, 'method'));
        HasTargets := ReadArray(RequestJson, 'targets', Targets);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', DocumentType);
        if DocumentType = PurchaseTok then begin
            GetImpl.LocatePurchaseHeader(RequestJson, PurchHeader);
            ReplacedCount := AssignPurchase(PurchHeader, LineNo, Method, HasTargets, Targets);
            ResponseJson.Add('documentNo', PurchHeader."No.");
            ResponseJson.Add('lineNo', LineNo);
            ResponseJson.Add('replacedCount', ReplacedCount);
            ResponseJson.Add('assignments', GetImpl.PurchaseRows(PurchHeader, LineNo));
        end else begin
            GetImpl.LocateSalesHeader(RequestJson, SalesHeader);
            ReplacedCount := AssignSales(SalesHeader, LineNo, Method, HasTargets, Targets);
            ResponseJson.Add('documentNo', SalesHeader."No.");
            ResponseJson.Add('lineNo', LineNo);
            ResponseJson.Add('replacedCount', ReplacedCount);
            ResponseJson.Add('assignments', GetImpl.SalesRows(SalesHeader, LineNo));
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PurchAssignment: Record "Item Charge Assignment (Purch)";
        SalesAssignment: Record "Item Charge Assignment (Sales)";
    begin
        if (not InventorySetup.ReadPermission()) or (not PurchAssignment.WritePermission()) or (not SalesAssignment.WritePermission()) then begin
            GetImpl.RespondPermissionDenied(Argument, true);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCharge) then begin
            GetImpl.RespondDomainDisabled(Argument);
            exit(false);
        end;
        exit(true);
    end;

    local procedure TouchDeclaredKeys(RequestJson: JsonObject)
    begin
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentType') then;
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('lineNo') then;
        if RequestJson.Contains('method') then;
        if RequestJson.Contains('targets') then;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId, lineNo, method and targets.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, systemId, lineNo, method og targets.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentTypeKeyTok, DocumentNoKeyTok, SystemIdKeyTok, LineNoKeyTok, MethodKeyTok, TargetsKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        PurchHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        Targets: JsonArray;
        DocumentType: Text;
        Method: Text;
        LineNo: Integer;
        HasTargets: Boolean;
    begin
        if not GetImpl.ValidateCommon(Argument, RequestJson, DocumentType, LineNo) then
            exit(false);
        if not ValidateMethodOrTargets(Argument, RequestJson, Method, HasTargets, Targets) then
            exit(false);
        if not GetImpl.AssertDocumentReadable(Argument, DocumentType, true) then
            exit(false);
        if DocumentType = PurchaseTok then begin
            if not GetImpl.ResolvePurchaseHeader(Argument, RequestJson, PurchHeader) then
                exit(false);
            exit(ValidatePurchase(Argument, PurchHeader, LineNo, Method, HasTargets, Targets));
        end;
        if not GetImpl.ResolveSalesHeader(Argument, RequestJson, SalesHeader) then
            exit(false);
        exit(ValidateSales(Argument, SalesHeader, LineNo, Method, HasTargets, Targets));
    end;

    local procedure ValidateMethodOrTargets(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Method: Text; var HasTargets: Boolean; var Targets: JsonArray): Boolean
    var
        Token: JsonToken;
        HasMethod: Boolean;
        ConflictErr: Label 'method and targets were both sent.', Comment = 'is-IS=method og targets voru bæði send.';
        ConflictNextStepLbl: Label 'Send method or targets, not both.', Comment = 'is-IS=Sendu method eða targets, ekki bæði.';
        MissingErr: Label 'method or targets is required.', Comment = 'is-IS=method eða targets er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send method (equally, byAmount, byWeight or byVolume) or targets.', Comment = 'is-IS=Sendu method (equally, byAmount, byWeight eða byVolume) eða targets.';
        MethodErr: Label 'This method is not supported.', Comment = 'is-IS=Þessi aðferð er ekki studd.';
        MethodNextStepLbl: Label 'Use equally, byAmount, byWeight or byVolume.', Comment = 'is-IS=Notaðu equally, byAmount, byWeight eða byVolume.';
        ArrayErr: Label 'targets must be an array.', Comment = 'is-IS=targets verður að vera fylki.';
        ArrayNextStepLbl: Label 'Send targets as an array of objects.', Comment = 'is-IS=Sendu targets sem fylki af hlutum.';
    begin
        HasMethod := RequestJson.Contains(MethodKeyTok);
        HasTargets := RequestJson.Contains(TargetsKeyTok);
        if HasMethod and HasTargets then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, MethodKeyTok, '', TargetsKeyTok, ConflictNextStepLbl);
            exit(false);
        end;
        if (not HasMethod) and (not HasTargets) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, MethodKeyTok, '', MethodExpectedTok, MissingNextStepLbl);
            exit(false);
        end;
        if HasMethod then begin
            if not GetImpl.RequireText(Argument, RequestJson, MethodKeyTok) then
                exit(false);
            Method := LowerCase(GetImpl.ReadText(RequestJson, MethodKeyTok));
            if not (Method in [EquallyTok, ByAmountTok, ByWeightTok, ByVolumeTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, MethodErr, MethodKeyTok, CopyStr(GetImpl.ReadText(RequestJson, MethodKeyTok), 1, 250), MethodExpectedTok, MethodNextStepLbl);
                exit(false);
            end;
            exit(true);
        end;
        RequestJson.Get(TargetsKeyTok, Token);
        if not Token.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, ArrayErr, TargetsKeyTok, '', ArrayExpectedTok, ArrayNextStepLbl);
            exit(false);
        end;
        Targets := Token.AsArray();
        exit(ValidateTargetShape(Argument, Targets));
    end;

    local procedure ValidateTargetShape(var Argument: Record "Message Argument ori"; Targets: JsonArray): Boolean
    var
        TargetToken: JsonToken;
        Target: JsonObject;
        KeyName: Text;
        EmptyErr: Label 'targets must hold at least one line.', Comment = 'is-IS=targets verður að innihalda að minnsta kosti eina línu.';
        EmptyNextStepLbl: Label 'Send at least one target line.', Comment = 'is-IS=Sendu að minnsta kosti eina marklínu.';
        ObjectErr: Label 'Each target must be a JSON object.', Comment = 'is-IS=Hvert mark verður að vera JSON-hlutur.';
        ObjectNextStepLbl: Label 'Send each target as an object with appliesToDocType, documentNo, lineNo and qtyToAssign.', Comment = 'is-IS=Sendu hvert mark sem hlut með appliesToDocType, documentNo, lineNo og qtyToAssign.';
        UnknownErr: Label 'A target contains an unknown key.', Comment = 'is-IS=Mark inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. A target allows appliesToDocType, documentNo, lineNo and qtyToAssign.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Mark leyfir appliesToDocType, documentNo, lineNo og qtyToAssign.';
        QtyErr: Label 'qtyToAssign must be greater than zero.', Comment = 'is-IS=qtyToAssign verður að vera stærra en núll.';
        QtyNextStepLbl: Label 'Send a positive qtyToAssign on each target.', Comment = 'is-IS=Sendu jákvætt qtyToAssign á hverju marki.';
    begin
        if Targets.Count() = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, EmptyErr, TargetsKeyTok, '', TargetsKeyTok, EmptyNextStepLbl);
            exit(false);
        end;
        foreach TargetToken in Targets do begin
            if not TargetToken.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, ObjectErr, TargetsKeyTok, '', ObjectExpectedTok, ObjectNextStepLbl);
                exit(false);
            end;
            Target := TargetToken.AsObject();
            foreach KeyName in Target.Keys() do
                if not (KeyName in [AppliesToKeyTok, DocumentNoKeyTok, LineNoKeyTok, QtyToAssignKeyTok]) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedTargetKeysTok, UnknownNextStepLbl);
                    exit(false);
                end;
            if not GetImpl.RequireText(Argument, Target, AppliesToKeyTok) then
                exit(false);
            if not GetImpl.RequireText(Argument, Target, DocumentNoKeyTok) then
                exit(false);
            if not GetImpl.RequireInteger(Argument, Target, LineNoKeyTok) then
                exit(false);
            if not GetImpl.RequireDecimal(Argument, Target, QtyToAssignKeyTok) then
                exit(false);
            if GetImpl.ReadDecimal(Target, QtyToAssignKeyTok) <= 0 then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, QtyErr, QtyToAssignKeyTok, Format(GetImpl.ReadDecimal(Target, QtyToAssignKeyTok), 0, 9), PositiveExpectedTok, QtyNextStepLbl);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ValidatePurchase(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; LineNo: Integer; Method: Text; HasTargets: Boolean; Targets: JsonArray): Boolean
    var
        PurchLine: Record "Purchase Line";
        TargetToken: JsonToken;
    begin
        if not GetImpl.ResolvePurchaseChargeLine(Argument, PurchHeader, LineNo, PurchLine) then
            exit(false);
        if PurchLine."Qty. to Invoice" = 0 then begin
            RespondNothingToInvoice(Argument, LineNo);
            exit(false);
        end;
        if HasTargets then begin
            foreach TargetToken in Targets do
                if not PurchaseTargetOk(Argument, PurchHeader, TargetToken.AsObject()) then
                    exit(false);
            exit(true);
        end;
        exit(ValidatePurchaseItemLines(Argument, PurchHeader, PurchLine, Method));
    end;

    local procedure ValidateSales(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; LineNo: Integer; Method: Text; HasTargets: Boolean; Targets: JsonArray): Boolean
    var
        SalesLine: Record "Sales Line";
        TargetToken: JsonToken;
    begin
        if not GetImpl.ResolveSalesChargeLine(Argument, SalesHeader, LineNo, SalesLine) then
            exit(false);
        if SalesLine."Qty. to Invoice" = 0 then begin
            RespondNothingToInvoice(Argument, LineNo);
            exit(false);
        end;
        if HasTargets then begin
            foreach TargetToken in Targets do
                if not SalesTargetOk(Argument, SalesHeader, TargetToken.AsObject()) then
                    exit(false);
            exit(true);
        end;
        exit(ValidateSalesItemLines(Argument, SalesHeader, SalesLine, Method));
    end;

    local procedure ValidatePurchaseItemLines(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; ChargeLine: Record "Purchase Line"; Method: Text): Boolean
    var
        ItemLine: Record "Purchase Line";
        TotalWeight: Decimal;
        TotalVolume: Decimal;
    begin
        ItemLine.SetLoadFields(Quantity, "Quantity Invoiced", "Gross Weight", "Unit Volume");
        ItemLine.SetRange("Document Type", PurchHeader."Document Type");
        ItemLine.SetRange("Document No.", PurchHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        ItemLine.SetFilter(Quantity, '<>0');
        if PurchHeader."Document Type" in [PurchHeader."Document Type"::"Return Order", PurchHeader."Document Type"::"Credit Memo"] then begin
            ChargeLine.SetLoadFields("Return Shipment No.");
            ChargeLine.Get(ChargeLine."Document Type", ChargeLine."Document No.", ChargeLine."Line No.");
            if ChargeLine."Return Shipment No." <> '' then
                ItemLine.SetRange("Return Shipment No.", ChargeLine."Return Shipment No.");
        end else begin
            ChargeLine.SetLoadFields("Receipt No.");
            ChargeLine.Get(ChargeLine."Document Type", ChargeLine."Document No.", ChargeLine."Line No.");
            if ChargeLine."Receipt No." <> '' then
                ItemLine.SetRange("Receipt No.", ChargeLine."Receipt No.");
        end;
        if not ItemLine.FindSet() then begin
            RespondNoItemLines(Argument, PurchHeader."No.");
            exit(false);
        end;
        repeat
            TotalWeight += ItemLine."Gross Weight" * ItemLine.Quantity;
            TotalVolume += ItemLine."Unit Volume" * ItemLine.Quantity;
        until ItemLine.Next() = 0;
        exit(MeasureOk(Argument, Method, TotalWeight, TotalVolume));
    end;

    local procedure ValidateSalesItemLines(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; ChargeLine: Record "Sales Line"; Method: Text): Boolean
    var
        ItemLine: Record "Sales Line";
        TotalWeight: Decimal;
        TotalVolume: Decimal;
    begin
        ItemLine.SetLoadFields(Quantity, "Quantity Invoiced", "Gross Weight", "Unit Volume");
        ItemLine.SetRange("Document Type", SalesHeader."Document Type");
        ItemLine.SetRange("Document No.", SalesHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        ItemLine.SetFilter(Quantity, '<>0');
        if SalesHeader."Document Type" in [SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo"] then begin
            ChargeLine.SetLoadFields("Return Receipt No.");
            ChargeLine.Get(ChargeLine."Document Type", ChargeLine."Document No.", ChargeLine."Line No.");
            if ChargeLine."Return Receipt No." <> '' then
                ItemLine.SetRange("Return Receipt No.", ChargeLine."Return Receipt No.");
        end else begin
            ChargeLine.SetLoadFields("Shipment No.");
            ChargeLine.Get(ChargeLine."Document Type", ChargeLine."Document No.", ChargeLine."Line No.");
            if ChargeLine."Shipment No." <> '' then
                ItemLine.SetRange("Shipment No.", ChargeLine."Shipment No.");
        end;
        if not ItemLine.FindSet() then begin
            RespondNoItemLines(Argument, SalesHeader."No.");
            exit(false);
        end;
        repeat
            TotalWeight += ItemLine."Gross Weight" * ItemLine.Quantity;
            TotalVolume += ItemLine."Unit Volume" * ItemLine.Quantity;
        until ItemLine.Next() = 0;
        exit(MeasureOk(Argument, Method, TotalWeight, TotalVolume));
    end;

    local procedure MeasureOk(var Argument: Record "Message Argument ori"; Method: Text; TotalWeight: Decimal; TotalVolume: Decimal): Boolean
    var
        MeasureErr: Label 'The item lines have no weight or volume to assign by.', Comment = 'is-IS=Vörulínurnar hafa hvorki þyngd né rúmmál til að úthluta eftir.';
        MeasureNextStepLbl: Label 'Use equally or byAmount, or fill the item''s weight/volume.', Comment = 'is-IS=Notaðu equally eða byAmount, eða fylltu út þyngd/rúmmál vörunnar.';
    begin
        if ((Method = ByWeightTok) and (TotalWeight = 0)) or ((Method = ByVolumeTok) and (TotalVolume = 0)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, MeasureErr, MethodKeyTok, CopyStr(Method, 1, 250), MeasureExpectedTok, MeasureNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure PurchaseTargetOk(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; Target: JsonObject): Boolean
    var
        PurchLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TransferRcptLine: Record "Transfer Receipt Line";
        ReturnShptLine: Record "Return Shipment Line";
        SalesShptLine: Record "Sales Shipment Line";
        ReturnRcptLine: Record "Return Receipt Line";
        AppliesTo: Text;
        TargetNo: Code[20];
        TargetLineNo: Integer;
        DocumentType: Enum "Purchase Document Type";
    begin
        AppliesTo := LowerCase(GetImpl.ReadText(Target, AppliesToKeyTok));
        TargetNo := CopyStr(GetImpl.ReadText(Target, DocumentNoKeyTok), 1, MaxStrLen(TargetNo));
        TargetLineNo := GetImpl.ReadInteger(Target, LineNoKeyTok);
        if PurchaseOpenDocumentType(AppliesTo, DocumentType) then begin
            PurchLine.SetLoadFields(Type, "Buy-from Vendor No.");
            if not PurchLine.Get(DocumentType, TargetNo, TargetLineNo) then
                exit(RespondTargetNotFound(Argument, TargetNo));
            exit(CheckTargetLine(Argument, PurchLine.Type = PurchLine.Type::Item, PurchLine."Buy-from Vendor No." = PurchHeader."Buy-from Vendor No.", TargetNo));
        end;
        case AppliesTo of
            'receipt':
                begin
                    if not PurchRcptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    PurchRcptLine.SetLoadFields(Type, "Buy-from Vendor No.");
                    if not PurchRcptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, PurchRcptLine.Type = PurchRcptLine.Type::Item, PurchRcptLine."Buy-from Vendor No." = PurchHeader."Buy-from Vendor No.", TargetNo));
                end;
            'transferreceipt':
                begin
                    if not TransferRcptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    TransferRcptLine.SetLoadFields("Item No.");
                    if not TransferRcptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, TransferRcptLine."Item No." <> '', true, TargetNo));
                end;
            'returnshipment':
                begin
                    if not ReturnShptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    ReturnShptLine.SetLoadFields(Type, "Buy-from Vendor No.");
                    if not ReturnShptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, ReturnShptLine.Type = ReturnShptLine.Type::Item, ReturnShptLine."Buy-from Vendor No." = PurchHeader."Buy-from Vendor No.", TargetNo));
                end;
            'salesshipment':
                begin
                    if not SalesShptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    SalesShptLine.SetLoadFields(Type);
                    if not SalesShptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, SalesShptLine.Type = SalesShptLine.Type::Item, true, TargetNo));
                end;
            'returnreceipt':
                begin
                    if not ReturnRcptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    ReturnRcptLine.SetLoadFields(Type);
                    if not ReturnRcptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, ReturnRcptLine.Type = ReturnRcptLine.Type::Item, true, TargetNo));
                end;
        end;
        exit(RespondAppliesToNotSupported(Argument, AppliesTo, PurchaseAppliesToExpectedTok));
    end;

    local procedure SalesTargetOk(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; Target: JsonObject): Boolean
    var
        SalesLine: Record "Sales Line";
        SalesShptLine: Record "Sales Shipment Line";
        ReturnRcptLine: Record "Return Receipt Line";
        AppliesTo: Text;
        TargetNo: Code[20];
        TargetLineNo: Integer;
        DocumentType: Enum "Sales Document Type";
    begin
        AppliesTo := LowerCase(GetImpl.ReadText(Target, AppliesToKeyTok));
        TargetNo := CopyStr(GetImpl.ReadText(Target, DocumentNoKeyTok), 1, MaxStrLen(TargetNo));
        TargetLineNo := GetImpl.ReadInteger(Target, LineNoKeyTok);
        if SalesOpenDocumentType(AppliesTo, DocumentType) then begin
            SalesLine.SetLoadFields(Type, "Sell-to Customer No.");
            if not SalesLine.Get(DocumentType, TargetNo, TargetLineNo) then
                exit(RespondTargetNotFound(Argument, TargetNo));
            exit(CheckTargetLine(Argument, SalesLine.Type = SalesLine.Type::Item, SalesLine."Sell-to Customer No." = SalesHeader."Sell-to Customer No.", TargetNo));
        end;
        case AppliesTo of
            'shipment':
                begin
                    if not SalesShptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    SalesShptLine.SetLoadFields(Type, "Sell-to Customer No.");
                    if not SalesShptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, SalesShptLine.Type = SalesShptLine.Type::Item, SalesShptLine."Sell-to Customer No." = SalesHeader."Sell-to Customer No.", TargetNo));
                end;
            'returnreceipt':
                begin
                    if not ReturnRcptLine.ReadPermission() then
                        exit(DenyTargetRead(Argument));
                    ReturnRcptLine.SetLoadFields(Type, "Sell-to Customer No.");
                    if not ReturnRcptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondTargetNotFound(Argument, TargetNo));
                    exit(CheckTargetLine(Argument, ReturnRcptLine.Type = ReturnRcptLine.Type::Item, ReturnRcptLine."Sell-to Customer No." = SalesHeader."Sell-to Customer No.", TargetNo));
                end;
        end;
        exit(RespondAppliesToNotSupported(Argument, AppliesTo, SalesAppliesToExpectedTok));
    end;

    local procedure DenyTargetRead(var Argument: Record "Message Argument ori"): Boolean
    begin
        GetImpl.RespondPermissionDenied(Argument, true);
        exit(false);
    end;

    local procedure CheckTargetLine(var Argument: Record "Message Argument ori"; IsItemLine: Boolean; SameParty: Boolean; TargetNo: Code[20]): Boolean
    var
        InvalidLineErr: Label 'The target line is not an item line or belongs to another vendor or customer.', Comment = 'is-IS=Marklínan er ekki vörulína eða tilheyrir öðrum lánardrottni eða viðskiptamanni.';
        InvalidLineNextStepLbl: Label 'Use lines from the same vendor/customer.', Comment = 'is-IS=Notaðu línur frá sama lánardrottni/viðskiptamanni.';
    begin
        if IsItemLine and SameParty then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, InvalidLineErr, TargetsKeyTok, TargetNo, '', InvalidLineNextStepLbl);
        exit(false);
    end;

    local procedure RespondTargetNotFound(var Argument: Record "Message Argument ori"; TargetNo: Code[20]): Boolean
    var
        NotFoundErr: Label 'No line matched the target.', Comment = 'is-IS=Engin lína fannst sem passar við markið.';
        NotFoundNextStepLbl: Label 'Check appliesToDocType, documentNo and lineNo of the target.', Comment = 'is-IS=Athugaðu appliesToDocType, documentNo og lineNo marksins.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, TargetsKeyTok, TargetNo, '', NotFoundNextStepLbl);
        exit(false);
    end;

    local procedure RespondAppliesToNotSupported(var Argument: Record "Message Argument ori"; AppliesTo: Text; Expected: Text): Boolean
    var
        AppliesToErr: Label 'This appliesToDocType is not supported for this charge.', Comment = 'is-IS=Þetta appliesToDocType er ekki stutt fyrir þennan kostnaðarauka.';
        AppliesToNextStepLbl: Label 'Use one of the target types listed under expected.', Comment = 'is-IS=Notaðu eina af gerðum marka sem eru taldar upp undir expected.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, AppliesToErr, AppliesToKeyTok, CopyStr(AppliesTo, 1, 250), Expected, AppliesToNextStepLbl);
        exit(false);
    end;

    local procedure RespondNothingToInvoice(var Argument: Record "Message Argument ori"; LineNo: Integer)
    var
        NothingErr: Label 'The charge line has no quantity to invoice, so there is nothing to assign.', Comment = 'is-IS=Kostnaðaraukalínan hefur ekkert magn til reikningsfærslu og því er engu að úthluta.';
        NothingNextStepLbl: Label 'Set a quantity to invoice on the charge line first.', Comment = 'is-IS=Fylltu fyrst út magn til reikningsfærslu á kostnaðaraukalínunni.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NothingErr, LineNoKeyTok, Format(LineNo, 0, 9), '', NothingNextStepLbl);
    end;

    local procedure RespondNoItemLines(var Argument: Record "Message Argument ori"; DocumentNo: Code[20])
    var
        NoItemLinesErr: Label 'The document has no item line to spread the charge over.', Comment = 'is-IS=Skjalið hefur enga vörulínu til að dreifa kostnaðaraukanum á.';
        NoItemLinesNextStepLbl: Label 'Add an item line to the document, or send targets with posted lines.', Comment = 'is-IS=Bættu vörulínu við skjalið, eða sendu targets með bókuðum línum.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoItemLinesErr, DocumentNoKeyTok, DocumentNo, '', NoItemLinesNextStepLbl);
    end;

    local procedure AssignPurchase(PurchHeader: Record "Purchase Header"; LineNo: Integer; Method: Text; HasTargets: Boolean; Targets: JsonArray) ReplacedCount: Integer
    var
        // The base codeunits read many fields of the charge line, so it is loaded in full.
        PurchLine: Record "Purchase Line";
        ChargeAssgnt: Record "Item Charge Assignment (Purch)";
        Currency: Record Currency;
        AssignPurch: Codeunit "Item Charge Assgnt. (Purch.)";
        LastLineNo: Integer;
        AssignableQty: Decimal;
        AssignableAmount: Decimal;
    begin
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", LineNo);
        ReplacedCount := ClearPurchaseRows(PurchLine, LastLineNo);
        Currency.Initialize(PurchHeader."Currency Code");
        ChargeAssgnt.Init();
        ChargeAssgnt."Document Type" := PurchLine."Document Type";
        ChargeAssgnt."Document No." := PurchLine."Document No.";
        ChargeAssgnt."Document Line No." := PurchLine."Line No.";
        ChargeAssgnt."Line No." := LastLineNo;
        ChargeAssgnt."Item Charge No." := PurchLine."No.";
        ChargeAssgnt."Unit Cost" := ChargeUnitCost(PurchLine."Line Amount" - PurchLine."Inv. Discount Amount", PurchLine.Quantity, PurchLine."VAT %", PurchHeader."Prices Including VAT", Currency);
        if HasTargets then begin
            InsertPurchaseTargets(ChargeAssgnt, Targets, Currency, LastLineNo);
            exit(ReplacedCount);
        end;
        if PurchLine."Document Type" in [PurchLine."Document Type"::"Return Order", PurchLine."Document Type"::"Credit Memo"] then
            AssignPurch.CreateDocChargeAssgnt(ChargeAssgnt, PurchLine."Return Shipment No.")
        else
            AssignPurch.CreateDocChargeAssgnt(ChargeAssgnt, PurchLine."Receipt No.");
        PurchLine.CalcFields("Qty. Assigned");
        AssignableQty := PurchLine."Qty. to Invoice" + PurchLine."Quantity Invoiced" - PurchLine."Qty. Assigned";
        AssignableAmount := Round(AssignableQty * ChargeAssgnt."Unit Cost", Currency."Amount Rounding Precision");
        AssignPurch.AssignItemCharges(PurchLine, AssignableQty, AssignableAmount, AssignableQty, AssignableAmount, PurchaseSelection(Method));
    end;

    local procedure AssignSales(SalesHeader: Record "Sales Header"; LineNo: Integer; Method: Text; HasTargets: Boolean; Targets: JsonArray) ReplacedCount: Integer
    var
        // The base codeunits read many fields of the charge line, so it is loaded in full.
        SalesLine: Record "Sales Line";
        ChargeAssgnt: Record "Item Charge Assignment (Sales)";
        Currency: Record Currency;
        AssignSalesCu: Codeunit "Item Charge Assgnt. (Sales)";
        LastLineNo: Integer;
        AssignableQty: Decimal;
        AssignableAmount: Decimal;
    begin
        SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo);
        ReplacedCount := ClearSalesRows(SalesLine, LastLineNo);
        Currency.Initialize(SalesHeader."Currency Code");
        ChargeAssgnt.Init();
        ChargeAssgnt."Document Type" := SalesLine."Document Type";
        ChargeAssgnt."Document No." := SalesLine."Document No.";
        ChargeAssgnt."Document Line No." := SalesLine."Line No.";
        ChargeAssgnt."Line No." := LastLineNo;
        ChargeAssgnt."Item Charge No." := SalesLine."No.";
        ChargeAssgnt."Unit Cost" := ChargeUnitCost(SalesLine."Line Amount" - SalesLine."Inv. Discount Amount", SalesLine.Quantity, SalesLine."VAT %", SalesHeader."Prices Including VAT", Currency);
        if HasTargets then begin
            InsertSalesTargets(ChargeAssgnt, Targets, Currency, LastLineNo);
            exit(ReplacedCount);
        end;
        if SalesLine."Document Type" in [SalesLine."Document Type"::"Return Order", SalesLine."Document Type"::"Credit Memo"] then
            AssignSalesCu.CreateDocChargeAssgn(ChargeAssgnt, SalesLine."Return Receipt No.")
        else
            AssignSalesCu.CreateDocChargeAssgn(ChargeAssgnt, SalesLine."Shipment No.");
        SalesLine.CalcFields("Qty. Assigned");
        AssignableQty := SalesLine."Qty. to Invoice" + SalesLine."Quantity Invoiced" - SalesLine."Qty. Assigned";
        AssignableAmount := Round(AssignableQty * ChargeAssgnt."Unit Cost", Currency."Amount Rounding Precision");
        AssignSalesCu.AssignItemCharges(SalesLine, AssignableQty, AssignableAmount, AssignableQty, AssignableAmount, SalesSelection(Method));
    end;

    local procedure ClearPurchaseRows(PurchLine: Record "Purchase Line"; var LastLineNo: Integer) ReplacedCount: Integer
    var
        Existing: Record "Item Charge Assignment (Purch)";
    begin
        Existing.SetRange("Document Type", PurchLine."Document Type");
        Existing.SetRange("Document No.", PurchLine."Document No.");
        Existing.SetRange("Document Line No.", PurchLine."Line No.");
        ReplacedCount := Existing.Count();
        Existing.SetRange("Qty. Assigned", 0);
        Existing.DeleteAll(true);
        Existing.SetRange("Qty. Assigned");
        if Existing.FindSet(true) then
            repeat
                Existing.Validate("Qty. to Assign", 0);
                Existing.Modify(true);
            until Existing.Next() = 0;
        LastLineNo := 0;
        if Existing.FindLast() then
            LastLineNo := Existing."Line No.";
    end;

    local procedure ClearSalesRows(SalesLine: Record "Sales Line"; var LastLineNo: Integer) ReplacedCount: Integer
    var
        Existing: Record "Item Charge Assignment (Sales)";
    begin
        Existing.SetRange("Document Type", SalesLine."Document Type");
        Existing.SetRange("Document No.", SalesLine."Document No.");
        Existing.SetRange("Document Line No.", SalesLine."Line No.");
        ReplacedCount := Existing.Count();
        Existing.SetRange("Qty. Assigned", 0);
        Existing.DeleteAll(true);
        Existing.SetRange("Qty. Assigned");
        if Existing.FindSet(true) then
            repeat
                Existing.Validate("Qty. to Assign", 0);
                Existing.Modify(true);
            until Existing.Next() = 0;
        LastLineNo := 0;
        if Existing.FindLast() then
            LastLineNo := Existing."Line No.";
    end;

    local procedure ChargeUnitCost(LineAmount: Decimal; Quantity: Decimal; VatPercent: Decimal; PricesIncludingVat: Boolean; Currency: Record Currency): Decimal
    begin
        if Quantity = 0 then
            exit(0);
        if PricesIncludingVat then
            LineAmount := Round(LineAmount / (1 + VatPercent / 100), Currency."Amount Rounding Precision");
        exit(Round(LineAmount / Quantity, Currency."Unit-Amount Rounding Precision"));
    end;

    local procedure InsertPurchaseTargets(ChargeAssgnt: Record "Item Charge Assignment (Purch)"; Targets: JsonArray; Currency: Record Currency; var NextLineNo: Integer)
    var
        AssignPurch: Codeunit "Item Charge Assgnt. (Purch.)";
        TargetToken: JsonToken;
        Target: JsonObject;
        AppliesToType: Enum "Purchase Applies-to Document Type";
        TargetNo: Code[20];
        TargetLineNo: Integer;
        ItemNo: Code[20];
        Description: Text[100];
        Qty: Decimal;
    begin
        foreach TargetToken in Targets do begin
            Target := TargetToken.AsObject();
            TargetNo := CopyStr(GetImpl.ReadText(Target, DocumentNoKeyTok), 1, MaxStrLen(TargetNo));
            TargetLineNo := GetImpl.ReadInteger(Target, LineNoKeyTok);
            Qty := GetImpl.ReadDecimal(Target, QtyToAssignKeyTok);
            ReadPurchaseTarget(LowerCase(GetImpl.ReadText(Target, AppliesToKeyTok)), TargetNo, TargetLineNo, AppliesToType, ItemNo, Description);
            AssignPurch.InsertItemChargeAssignmentWithValues(ChargeAssgnt, AppliesToType, TargetNo, TargetLineNo, ItemNo, Description, Qty, Round(Qty * ChargeAssgnt."Unit Cost", Currency."Amount Rounding Precision"), NextLineNo);
        end;
    end;

    local procedure InsertSalesTargets(ChargeAssgnt: Record "Item Charge Assignment (Sales)"; Targets: JsonArray; Currency: Record Currency; var NextLineNo: Integer)
    var
        AssignSalesCu: Codeunit "Item Charge Assgnt. (Sales)";
        TargetToken: JsonToken;
        Target: JsonObject;
        AppliesToType: Enum "Sales Applies-to Document Type";
        TargetNo: Code[20];
        TargetLineNo: Integer;
        ItemNo: Code[20];
        Description: Text[100];
        Qty: Decimal;
    begin
        foreach TargetToken in Targets do begin
            Target := TargetToken.AsObject();
            TargetNo := CopyStr(GetImpl.ReadText(Target, DocumentNoKeyTok), 1, MaxStrLen(TargetNo));
            TargetLineNo := GetImpl.ReadInteger(Target, LineNoKeyTok);
            Qty := GetImpl.ReadDecimal(Target, QtyToAssignKeyTok);
            ReadSalesTarget(LowerCase(GetImpl.ReadText(Target, AppliesToKeyTok)), TargetNo, TargetLineNo, AppliesToType, ItemNo, Description);
            AssignSalesCu.InsertItemChargeAssignmentWithValues(ChargeAssgnt, AppliesToType, TargetNo, TargetLineNo, ItemNo, Description, Qty, Round(Qty * ChargeAssgnt."Unit Cost", Currency."Amount Rounding Precision"), NextLineNo);
        end;
    end;

    local procedure ReadPurchaseTarget(AppliesTo: Text; TargetNo: Code[20]; TargetLineNo: Integer; var AppliesToType: Enum "Purchase Applies-to Document Type"; var ItemNo: Code[20]; var Description: Text[100])
    var
        PurchLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TransferRcptLine: Record "Transfer Receipt Line";
        ReturnShptLine: Record "Return Shipment Line";
        SalesShptLine: Record "Sales Shipment Line";
        ReturnRcptLine: Record "Return Receipt Line";
        DocumentType: Enum "Purchase Document Type";
    begin
        if PurchaseOpenDocumentType(AppliesTo, DocumentType) then begin
            PurchLine.SetLoadFields("No.", Description);
            PurchLine.Get(DocumentType, TargetNo, TargetLineNo);
            AppliesToType := PurchaseAppliesToFromDocument(DocumentType);
            ItemNo := PurchLine."No.";
            Description := PurchLine.Description;
            exit;
        end;
        case AppliesTo of
            'receipt':
                begin
                    PurchRcptLine.SetLoadFields("No.", Description);
                    PurchRcptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::Receipt;
                    ItemNo := PurchRcptLine."No.";
                    Description := PurchRcptLine.Description;
                end;
            'transferreceipt':
                begin
                    TransferRcptLine.SetLoadFields("Item No.", Description);
                    TransferRcptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::"Transfer Receipt";
                    ItemNo := TransferRcptLine."Item No.";
                    Description := TransferRcptLine.Description;
                end;
            'returnshipment':
                begin
                    ReturnShptLine.SetLoadFields("No.", Description);
                    ReturnShptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::"Return Shipment";
                    ItemNo := ReturnShptLine."No.";
                    Description := ReturnShptLine.Description;
                end;
            'salesshipment':
                begin
                    SalesShptLine.SetLoadFields("No.", Description);
                    SalesShptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::"Sales Shipment";
                    ItemNo := SalesShptLine."No.";
                    Description := SalesShptLine.Description;
                end;
            'returnreceipt':
                begin
                    ReturnRcptLine.SetLoadFields("No.", Description);
                    ReturnRcptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::"Return Receipt";
                    ItemNo := ReturnRcptLine."No.";
                    Description := ReturnRcptLine.Description;
                end;
        end;
    end;

    local procedure ReadSalesTarget(AppliesTo: Text; TargetNo: Code[20]; TargetLineNo: Integer; var AppliesToType: Enum "Sales Applies-to Document Type"; var ItemNo: Code[20]; var Description: Text[100])
    var
        SalesLine: Record "Sales Line";
        SalesShptLine: Record "Sales Shipment Line";
        ReturnRcptLine: Record "Return Receipt Line";
        DocumentType: Enum "Sales Document Type";
    begin
        if SalesOpenDocumentType(AppliesTo, DocumentType) then begin
            SalesLine.SetLoadFields("No.", Description);
            SalesLine.Get(DocumentType, TargetNo, TargetLineNo);
            AppliesToType := SalesAppliesToFromDocument(DocumentType);
            ItemNo := SalesLine."No.";
            Description := SalesLine.Description;
            exit;
        end;
        case AppliesTo of
            'shipment':
                begin
                    SalesShptLine.SetLoadFields("No.", Description);
                    SalesShptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::Shipment;
                    ItemNo := SalesShptLine."No.";
                    Description := SalesShptLine.Description;
                end;
            'returnreceipt':
                begin
                    ReturnRcptLine.SetLoadFields("No.", Description);
                    ReturnRcptLine.Get(TargetNo, TargetLineNo);
                    AppliesToType := AppliesToType::"Return Receipt";
                    ItemNo := ReturnRcptLine."No.";
                    Description := ReturnRcptLine.Description;
                end;
        end;
    end;

    local procedure PurchaseOpenDocumentType(AppliesTo: Text; var DocumentType: Enum "Purchase Document Type"): Boolean
    begin
        case AppliesTo of
            'order':
                DocumentType := DocumentType::Order;
            'invoice':
                DocumentType := DocumentType::Invoice;
            'returnorder':
                DocumentType := DocumentType::"Return Order";
            'creditmemo':
                DocumentType := DocumentType::"Credit Memo";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure SalesOpenDocumentType(AppliesTo: Text; var DocumentType: Enum "Sales Document Type"): Boolean
    begin
        case AppliesTo of
            'order':
                DocumentType := DocumentType::Order;
            'invoice':
                DocumentType := DocumentType::Invoice;
            'returnorder':
                DocumentType := DocumentType::"Return Order";
            'creditmemo':
                DocumentType := DocumentType::"Credit Memo";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure PurchaseAppliesToFromDocument(DocumentType: Enum "Purchase Document Type"): Enum "Purchase Applies-to Document Type"
    begin
        case DocumentType of
            DocumentType::Invoice:
                exit(Enum::"Purchase Applies-to Document Type"::Invoice);
            DocumentType::"Return Order":
                exit(Enum::"Purchase Applies-to Document Type"::"Return Order");
            DocumentType::"Credit Memo":
                exit(Enum::"Purchase Applies-to Document Type"::"Credit Memo");
        end;
        exit(Enum::"Purchase Applies-to Document Type"::Order);
    end;

    local procedure SalesAppliesToFromDocument(DocumentType: Enum "Sales Document Type"): Enum "Sales Applies-to Document Type"
    begin
        case DocumentType of
            DocumentType::Invoice:
                exit(Enum::"Sales Applies-to Document Type"::Invoice);
            DocumentType::"Return Order":
                exit(Enum::"Sales Applies-to Document Type"::"Return Order");
            DocumentType::"Credit Memo":
                exit(Enum::"Sales Applies-to Document Type"::"Credit Memo");
        end;
        exit(Enum::"Sales Applies-to Document Type"::Order);
    end;

    local procedure PurchaseSelection(Method: Text): Text
    var
        AssignPurch: Codeunit "Item Charge Assgnt. (Purch.)";
    begin
        case Method of
            ByAmountTok:
                exit(AssignPurch.AssignByAmountMenuText());
            ByWeightTok:
                exit(AssignPurch.AssignByWeightMenuText());
            ByVolumeTok:
                exit(AssignPurch.AssignByVolumeMenuText());
        end;
        exit(AssignPurch.AssignEquallyMenuText());
    end;

    local procedure SalesSelection(Method: Text): Text
    var
        AssignSalesCu: Codeunit "Item Charge Assgnt. (Sales)";
    begin
        case Method of
            ByAmountTok:
                exit(AssignSalesCu.AssignByAmountMenuText());
            ByWeightTok:
                exit(AssignSalesCu.AssignByWeightMenuText());
            ByVolumeTok:
                exit(AssignSalesCu.AssignByVolumeMenuText());
        end;
        exit(AssignSalesCu.AssignEquallyMenuText());
    end;

    local procedure ReadArray(RequestJson: JsonObject; KeyName: Text; var Result: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Result := Token.AsArray();
        exit(true);
    end;
}
