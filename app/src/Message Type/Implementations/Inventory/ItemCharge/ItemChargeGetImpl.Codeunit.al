namespace Origo.Bifrost.Inventory;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCharge.Get. Returns the assignment rows for one charge line and the quantity still unassigned.
/// Also holds the request checks and row builders that Inventory.ItemCharge.Assign shares.
/// </summary>
codeunit 10076875 "Item Charge Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DocumentTypeKeyTok: Label 'documentType', Locked = true;
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        LineNoKeyTok: Label 'lineNo', Locked = true;
        PurchaseTok: Label 'purchase', Locked = true;
        SalesTok: Label 'sales', Locked = true;
        DocumentTypeExpectedTok: Label 'purchase|sales', Locked = true;
        AllowedKeysTok: Label 'documentType, documentNo, systemId, lineNo', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        IntegerExpectedTok: Label 'integer', Locked = true;
        NumberExpectedTok: Label 'number', Locked = true;
        GuidExpectedTok: Label 'GUID', Locked = true;
        ChargeItemExpectedTok: Label 'Charge (Item)', Locked = true;
        ReadPermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;
        WritePermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;

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
        exit(PurchAssignment.ReadPermission() and SalesAssignment.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Charge Assignment (Purch)");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads the item charge assignment of one purchase or sales charge line.', Comment = 'is-IS=Les úthlutun kostnaðarauka á einni kostnaðaraukalínu í innkaupum eða sölu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item charge, assignment, unassigned, freight, customs', Comment = 'is-IS=kostnaðarauki, úthlutun, óúthlutað, flutningskostnaður, tollur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Shows how a freight, customs or other item charge is spread over item lines and how much is still unassigned.', Comment = 'is-IS=Sýnir hvernig flutningskostnaði, tolli eða öðrum kostnaðarauka er dreift á vörulínur og hve mikið er enn óúthlutað.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The charge line is named under data.documentType, data.documentNo or data.systemId, and data.lineNo; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The charge line, named by its document and line number.', Comment = 'is-IS=Kostnaðaraukalínan, tilgreind með skjali sínu og línunúmeri.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', 'The No. of the open purchase or sales document that holds the charge line. data.documentType says which kind of document it is.'));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', 'The system id of that document, as an alternative to data.documentNo. Send one of them, not both.'));
        Target.Add(ContractMgt.TargetEntry('data.lineNo', 'integer', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentTypeLbl: Label 'purchase or sales. Says which kind of document holds the charge line.', Comment = 'is-IS=purchase eða sales. Segir hvers konar skjal geymir kostnaðaraukalínuna.';
        DocumentNoLbl: Label 'Number of the open purchase or sales document (order, invoice, return order or credit memo). Send this or systemId.', Comment = 'is-IS=Númer opins innkaupa- eða söluskjals (pöntun, reikningur, vöruskilapöntun eða kreditreikningur). Sendu þetta eða systemId.';
        SystemIdLbl: Label 'systemId of the document. Send this or documentNo.', Comment = 'is-IS=systemId skjalsins. Sendu þetta eða documentNo.';
        LineNoLbl: Label 'Line number of the Charge (Item) line.', Comment = 'is-IS=Línunúmer línunnar af gerðinni Kostnaðarauki (vara).';
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', true, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', true, LineNoLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        RowsField: JsonObject;
        RowChildren: JsonArray;
    begin
        RowChildren.Add(ContractMgt.ResponseField('lineNo', 'integer', 'The line number of the assignment row.'));
        RowChildren.Add(ContractMgt.ResponseField('appliesToDocType', 'string', 'What the charge lands on: order, invoice, returnOrder, creditMemo, receipt, transferReceipt, returnShipment, salesShipment, shipment, returnReceipt, quote or blanketOrder.'));
        RowChildren.Add(ContractMgt.ResponseField('appliesToDocNo', 'string', 'The No. of the document the charge lands on.'));
        RowChildren.Add(ContractMgt.ResponseField('appliesToDocLineNo', 'integer', 'The line number on that document.'));
        RowChildren.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item the charge lands on.'));
        RowChildren.Add(ContractMgt.ResponseField('description', 'string', 'The description of the assignment row.'));
        RowChildren.Add(ContractMgt.ResponseField('qtyToAssign', 'decimal', 'The quantity of the charge assigned to that line and not yet invoiced.'));
        RowChildren.Add(ContractMgt.ResponseField('amountToAssign', 'decimal', 'The amount of the charge assigned to that line and not yet invoiced.'));
        RowChildren.Add(ContractMgt.ResponseField('qtyAssigned', 'decimal', 'The quantity of the charge that is already invoiced.'));
        RowsField := ContractMgt.ResponseField('assignments', 'array', 'The assignment rows of the charge line, in row order.');
        RowsField.Add('children', RowChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'purchase or sales, in lower case.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the document that holds the charge line.'));
        Fields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'The line number of the charge line.'));
        Fields.Add(ContractMgt.ResponseField('itemChargeNo', 'string', 'The No. of the item charge on the charge line.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity of the charge line.'));
        Fields.Add(ContractMgt.ResponseField('qtyToAssign', 'decimal', 'The quantity of the charge that is assigned and not yet invoiced.'));
        Fields.Add(ContractMgt.ResponseField('qtyAssigned', 'decimal', 'The quantity of the charge that is already invoiced.'));
        Fields.Add(ContractMgt.ResponseField('unassignedQuantity', 'decimal', 'The quantity of the charge line minus qtyToAssign and qtyAssigned.'));
        Fields.Add(RowsField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'documentType or lineNo is missing, or neither documentNo nor systemId was sent.', Comment = 'is-IS=documentType eða lineNo vantar, eða hvorki documentNo né systemId var sent.';
        MissingFixLbl: Label 'Send documentType, lineNo, and documentNo or systemId.', Comment = 'is-IS=Sendu documentType, lineNo, og documentNo eða systemId.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, or systemId is not a GUID.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, eða systemId er ekki GUID.';
        FormatFixLbl: Label 'Send documentType, documentNo and systemId as text and lineNo as a whole number.', Comment = 'is-IS=Sendu documentType, documentNo og systemId sem texta og lineNo sem heiltölu.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId and lineNo.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, systemId og lineNo.';
        InvalidWhenLbl: Label 'documentType is not purchase or sales.', Comment = 'is-IS=documentType er hvorki purchase né sales.';
        InvalidFixLbl: Label 'Send purchase or sales.', Comment = 'is-IS=Sendu purchase eða sales.';
        NotFoundWhenLbl: Label 'No open document or no line matched.', Comment = 'is-IS=Ekkert opið skjal eða engin lína fannst.';
        NotFoundFixLbl: Label 'Check documentNo or systemId, documentType and lineNo.', Comment = 'is-IS=Athugaðu documentNo eða systemId, documentType og lineNo.';
        AmbiguousWhenLbl: Label 'Several documents of different types have this number.', Comment = 'is-IS=Nokkur skjöl af ólíkum gerðum hafa þetta númer.';
        AmbiguousFixLbl: Label 'Send the systemId of the document instead of documentNo.', Comment = 'is-IS=Sendu systemId skjalsins í stað documentNo.';
        ConflictWhenLbl: Label 'documentNo and systemId were both sent.', Comment = 'is-IS=documentNo og systemId voru bæði send.';
        ConflictFixLbl: Label 'Send documentNo or systemId, not both.', Comment = 'is-IS=Sendu documentNo eða systemId, ekki bæði.';
        PreconditionWhenLbl: Label 'The line is not an item charge line.', Comment = 'is-IS=Línan er ekki kostnaðaraukalína.';
        PreconditionFixLbl: Label 'Pass the line no. of a Charge (Item) line.', Comment = 'is-IS=Sendu línunúmer línu af gerðinni Kostnaðarauki (vara).';
        PermissionWhenLbl: Label 'The caller cannot read item charge assignments or the document.', Comment = 'is-IS=Kallandinn getur ekki lesið úthlutanir kostnaðarauka eða skjalið.';
        PermissionFixLbl: Label 'Assign Bifrost Read-Only (extended by Inventory read permissions) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu Bifröst Lesaðgangur (með viðbótinni lesheimildir birgða) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousWhenLbl, AmbiguousFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionWhenLbl, PreconditionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Item Charge domain is turned off for this company.', 'Turn the domain on from the Inventory Setup page, then send the call again.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Nothing. The call only reads the assignment rows of one charge line and the quantity that is still unassigned.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'Bifrost Read-Only');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RelatedLbl: Label 'Spread the charge over item lines, or replace the current assignment.', Comment = 'is-IS=Dreifa kostnaðaraukanum á vörulínur, eða skipta út núverandi úthlutun.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemCharge.Assign', RelatedLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Read the assignment of a freight charge on a purchase order', Comment = 'is-IS=Lesa úthlutun flutningskostnaðar á innkaupapöntun';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemCharge.Get","data":{"documentType":"purchase","documentNo":"106001","lineNo":30000}}', '{"status":"Success","documentType":"purchase","documentNo":"106001","lineNo":30000,"itemChargeNo":"FREIGHT","quantity":1,"qtyToAssign":1,"qtyAssigned":0,"unassignedQuantity":0,"assignments":[{"lineNo":10000,"appliesToDocType":"order","appliesToDocNo":"106001","appliesToDocLineNo":10000,"itemNo":"1896-S","description":"ATHENS Desk","qtyToAssign":0.5,"amountToAssign":50,"qtyAssigned":0},{"lineNo":20000,"appliesToDocType":"order","appliesToDocNo":"106001","appliesToDocLineNo":20000,"itemNo":"1900-S","description":"PARIS Guest Chair, black","qtyToAssign":0.5,"amountToAssign":50,"qtyAssigned":0}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads how one item charge line on an open purchase or sales document is spread over item lines, the same rows the Item Charge Assignment page shows, and the quantity that is still unassigned.', Comment = 'is-IS=Les hvernig einni kostnaðaraukalínu á opnu innkaupa- eða söluskjali er dreift á vörulínur, sömu línur og síðan Úthlutun kostnaðarauka sýnir, og það magn sem er enn óúthlutað.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Each row in assignments names the line the charge lands on: appliesToDocType (order, invoice, returnOrder, creditMemo, receipt, transferReceipt, returnShipment, salesShipment, shipment or returnReceipt), appliesToDocNo and appliesToDocLineNo, with qtyToAssign, amountToAssign and qtyAssigned (already invoiced). unassignedQuantity is the charge quantity minus qtyToAssign and qtyAssigned. This call changes nothing and does not post the document; use Inventory.ItemCharge.Assign to change the assignment.', Comment = 'is-IS=Hver lína í assignments tilgreinir línuna sem kostnaðaraukinn lendir á: appliesToDocType (order, invoice, returnOrder, creditMemo, receipt, transferReceipt, returnShipment, salesShipment, shipment eða returnReceipt), appliesToDocNo og appliesToDocLineNo, ásamt qtyToAssign, amountToAssign og qtyAssigned (þegar reikningsfært). unassignedQuantity er magn kostnaðaraukans að frádregnu qtyToAssign og qtyAssigned. Þetta kall breytir engu og bókar ekki skjalið; notaðu Inventory.ItemCharge.Assign til að breyta úthlutuninni.';
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
        PurchHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        PurchLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        DocumentType: Text;
        LineNo: Integer;
    begin
        if not AssertCanRead(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentType') then;
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('lineNo') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateCommon(Argument, RequestJson, DocumentType, LineNo) then
            exit;
        if not AssertDocumentReadable(Argument, DocumentType, false) then
            exit;
        if DocumentType = PurchaseTok then begin
            if not ResolvePurchaseHeader(Argument, RequestJson, PurchHeader) then
                exit;
            if not ResolvePurchaseChargeLine(Argument, PurchHeader, LineNo, PurchLine) then
                exit;
            WritePurchaseResponse(Argument, PurchHeader, PurchLine);
            exit;
        end;
        if not ResolveSalesHeader(Argument, RequestJson, SalesHeader) then
            exit;
        if not ResolveSalesChargeLine(Argument, SalesHeader, LineNo, SalesLine) then
            exit;
        WriteSalesResponse(Argument, SalesHeader, SalesLine);
    end;

    /// <summary>
    /// Checks the keys both item charge types share: documentType, lineNo and one of documentNo or systemId.
    /// Answers the refusal itself.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="RequestJson">The request data.</param>
    /// <param name="DocumentType">Returns purchase or sales, lower case.</param>
    /// <param name="LineNo">Returns the charge line number.</param>
    /// <returns>True when the shared keys are valid.</returns>
    procedure ValidateCommon(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var DocumentType: Text; var LineNo: Integer): Boolean
    var
        DocumentTypeErr: Label 'documentType must be purchase or sales.', Comment = 'is-IS=documentType verður að vera purchase eða sales.';
        DocumentTypeNextStepLbl: Label 'Send purchase or sales.', Comment = 'is-IS=Sendu purchase eða sales.';
    begin
        if not RequireText(Argument, RequestJson, DocumentTypeKeyTok) then
            exit(false);
        if not RequireInteger(Argument, RequestJson, LineNoKeyTok) then
            exit(false);
        if not RequireIdentifier(Argument, RequestJson) then
            exit(false);
        DocumentType := LowerCase(ReadText(RequestJson, DocumentTypeKeyTok));
        if not (DocumentType in [PurchaseTok, SalesTok]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentTypeErr, DocumentTypeKeyTok, CopyStr(DocumentType, 1, 250), DocumentTypeExpectedTok, DocumentTypeNextStepLbl);
            exit(false);
        end;
        LineNo := ReadInteger(RequestJson, LineNoKeyTok);
        exit(true);
    end;

    /// <summary>
    /// Refuses a caller that cannot read the purchase or sales document tables the type reads.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="DocumentType">purchase or sales.</param>
    /// <param name="ForWrite">True names the write permission set in the next step.</param>
    /// <returns>True when the caller can read the document and its lines.</returns>
    procedure AssertDocumentReadable(var Argument: Record "Message Argument ori"; DocumentType: Text; ForWrite: Boolean): Boolean
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Readable: Boolean;
    begin
        if DocumentType = PurchaseTok then
            Readable := PurchHeader.ReadPermission() and PurchLine.ReadPermission()
        else
            Readable := SalesHeader.ReadPermission() and SalesLine.ReadPermission();
        if Readable then
            exit(true);
        RespondPermissionDenied(Argument, ForWrite);
        exit(false);
    end;

    /// <summary>
    /// Answers PermissionDenied with the permission set the caller needs.
    /// </summary>
    /// <param name="Argument">The message argument that receives the refusal.</param>
    /// <param name="ForWrite">True names BIFROST InvWrite ori, false names BIFROST InvRead ori.</param>
    procedure RespondPermissionDenied(var Argument: Record "Message Argument ori"; ForWrite: Boolean)
    var
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        ReadNextStepLbl: Label 'Assign BIFROST Read ori (extended by BIFROST InvRead ori) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori (með viðbótinni BIFROST InvRead ori) og Business Central heimildasafni sem getur lesið þessar töflur.';
        WriteNextStepLbl: Label 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Full ori (með viðbótinni BIFROST InvWrite ori) og Business Central heimildasafni sem getur breytt þessum töflum.';
    begin
        if ForWrite then
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', WritePermissionSetTok, WriteNextStepLbl)
        else
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', ReadPermissionSetTok, ReadNextStepLbl);
    end;

    /// <summary>
    /// Answers that the Item Charge domain is turned off.
    /// </summary>
    /// <param name="Argument">The message argument that receives the refusal.</param>
    procedure RespondDomainDisabled(var Argument: Record "Message Argument ori")
    var
        DomainDisabledErr: Label 'The Item Charge domain is turned off for this company.', Comment = 'is-IS=Kostnaðaraukasviðið er óvirkt fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Ask an administrator with the Inv. Posting Gate permission set to turn the domain on from the Inventory Setup page. Data.Records.Set cannot change this setup.', Comment = 'is-IS=Biðjið kerfisstjóra með heimildasafnið Bókunarhlið birgða að kveikja á sviðinu á síðunni Uppsetning birgða. Data.Records.Set getur ekki breytt þessari uppsetningu.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
    end;

    /// <summary>
    /// Finds the purchase document the request names and answers RecordNotFound or AmbiguousRecord.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="RequestJson">The request data with documentNo or systemId.</param>
    /// <param name="PurchHeader">Returns the purchase document.</param>
    /// <returns>True when exactly one document matched.</returns>
    procedure ResolvePurchaseHeader(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var PurchHeader: Record "Purchase Header"): Boolean
    begin
        if not CheckSystemIdFormat(Argument, RequestJson) then
            exit(false);
        exit(AnswerDocumentMatches(Argument, RequestJson, LocatePurchaseHeader(RequestJson, PurchHeader)));
    end;

    /// <summary>
    /// Finds the sales document the request names and answers RecordNotFound or AmbiguousRecord.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="RequestJson">The request data with documentNo or systemId.</param>
    /// <param name="SalesHeader">Returns the sales document.</param>
    /// <returns>True when exactly one document matched.</returns>
    procedure ResolveSalesHeader(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SalesHeader: Record "Sales Header"): Boolean
    begin
        if not CheckSystemIdFormat(Argument, RequestJson) then
            exit(false);
        exit(AnswerDocumentMatches(Argument, RequestJson, LocateSalesHeader(RequestJson, SalesHeader)));
    end;

    /// <summary>
    /// Finds the purchase document by documentNo or systemId without answering.
    /// </summary>
    /// <param name="RequestJson">The request data with documentNo or systemId.</param>
    /// <param name="PurchHeader">Returns the first matching document.</param>
    /// <returns>The number of matching documents.</returns>
    procedure LocatePurchaseHeader(RequestJson: JsonObject; var PurchHeader: Record "Purchase Header"): Integer
    var
        SystemId: Guid;
    begin
        PurchHeader.Reset();
        if RequestJson.Contains('systemId') then begin
            if not Evaluate(SystemId, ReadText(RequestJson, SystemIdKeyTok)) then
                exit(0);
            if PurchHeader.GetBySystemId(SystemId) then
                exit(1);
            exit(0);
        end;
        PurchHeader.SetRange("No.", CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(PurchHeader."No.")));
        PurchHeader.SetFilter("Document Type", '%1|%2|%3|%4', PurchHeader."Document Type"::Order, PurchHeader."Document Type"::Invoice, PurchHeader."Document Type"::"Return Order", PurchHeader."Document Type"::"Credit Memo");
        if not PurchHeader.FindFirst() then
            exit(0);
        exit(PurchHeader.Count());
    end;

    /// <summary>
    /// Finds the sales document by documentNo or systemId without answering.
    /// </summary>
    /// <param name="RequestJson">The request data with documentNo or systemId.</param>
    /// <param name="SalesHeader">Returns the first matching document.</param>
    /// <returns>The number of matching documents.</returns>
    procedure LocateSalesHeader(RequestJson: JsonObject; var SalesHeader: Record "Sales Header"): Integer
    var
        SystemId: Guid;
    begin
        SalesHeader.Reset();
        if RequestJson.Contains('systemId') then begin
            if not Evaluate(SystemId, ReadText(RequestJson, SystemIdKeyTok)) then
                exit(0);
            if SalesHeader.GetBySystemId(SystemId) then
                exit(1);
            exit(0);
        end;
        SalesHeader.SetRange("No.", CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(SalesHeader."No.")));
        SalesHeader.SetFilter("Document Type", '%1|%2|%3|%4', SalesHeader."Document Type"::Order, SalesHeader."Document Type"::Invoice, SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo");
        if not SalesHeader.FindFirst() then
            exit(0);
        exit(SalesHeader.Count());
    end;

    /// <summary>
    /// Reads the charge line of a purchase document and answers RecordNotFound or PreconditionFailed.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="PurchHeader">The purchase document.</param>
    /// <param name="LineNo">The line number from the request.</param>
    /// <param name="PurchLine">Returns the charge line.</param>
    /// <returns>True when the line exists and is a Charge (Item) line.</returns>
    procedure ResolvePurchaseChargeLine(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; LineNo: Integer; var PurchLine: Record "Purchase Line"): Boolean
    begin
        PurchLine.SetLoadFields(Type, "No.", Quantity, "Qty. to Invoice", "Quantity Invoiced");
        if not PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", LineNo) then begin
            RespondLineNotFound(Argument, LineNo);
            exit(false);
        end;
        if PurchLine.Type <> PurchLine.Type::"Charge (Item)" then begin
            RespondNotChargeLine(Argument, LineNo);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Reads the charge line of a sales document and answers RecordNotFound or PreconditionFailed.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="SalesHeader">The sales document.</param>
    /// <param name="LineNo">The line number from the request.</param>
    /// <param name="SalesLine">Returns the charge line.</param>
    /// <returns>True when the line exists and is a Charge (Item) line.</returns>
    procedure ResolveSalesChargeLine(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; LineNo: Integer; var SalesLine: Record "Sales Line"): Boolean
    begin
        SalesLine.SetLoadFields(Type, "No.", Quantity, "Qty. to Invoice", "Quantity Invoiced");
        if not SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo) then begin
            RespondLineNotFound(Argument, LineNo);
            exit(false);
        end;
        if SalesLine.Type <> SalesLine.Type::"Charge (Item)" then begin
            RespondNotChargeLine(Argument, LineNo);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Builds the assignment rows of one purchase charge line.
    /// </summary>
    /// <param name="PurchHeader">The purchase document.</param>
    /// <param name="LineNo">The charge line number.</param>
    /// <returns>One JSON object per assignment row.</returns>
    procedure PurchaseRows(PurchHeader: Record "Purchase Header"; LineNo: Integer) Rows: JsonArray
    var
        Row: Record "Item Charge Assignment (Purch)";
    begin
        Row.SetLoadFields("Line No.", "Applies-to Doc. Type", "Applies-to Doc. No.", "Applies-to Doc. Line No.", "Item No.", Description, "Qty. to Assign", "Amount to Assign", "Qty. Assigned");
        Row.SetRange("Document Type", PurchHeader."Document Type");
        Row.SetRange("Document No.", PurchHeader."No.");
        Row.SetRange("Document Line No.", LineNo);
        if Row.FindSet() then
            repeat
                Rows.Add(RowJson(Row."Line No.", PurchaseAppliesToName(Row."Applies-to Doc. Type"), Row."Applies-to Doc. No.", Row."Applies-to Doc. Line No.", Row."Item No.", Row.Description, Row."Qty. to Assign", Row."Amount to Assign", Row."Qty. Assigned"));
            until Row.Next() = 0;
    end;

    /// <summary>
    /// Builds the assignment rows of one sales charge line.
    /// </summary>
    /// <param name="SalesHeader">The sales document.</param>
    /// <param name="LineNo">The charge line number.</param>
    /// <returns>One JSON object per assignment row.</returns>
    procedure SalesRows(SalesHeader: Record "Sales Header"; LineNo: Integer) Rows: JsonArray
    var
        Row: Record "Item Charge Assignment (Sales)";
    begin
        Row.SetLoadFields("Line No.", "Applies-to Doc. Type", "Applies-to Doc. No.", "Applies-to Doc. Line No.", "Item No.", Description, "Qty. to Assign", "Amount to Assign", "Qty. Assigned");
        Row.SetRange("Document Type", SalesHeader."Document Type");
        Row.SetRange("Document No.", SalesHeader."No.");
        Row.SetRange("Document Line No.", LineNo);
        if Row.FindSet() then
            repeat
                Rows.Add(RowJson(Row."Line No.", SalesAppliesToName(Row."Applies-to Doc. Type"), Row."Applies-to Doc. No.", Row."Applies-to Doc. Line No.", Row."Item No.", Row.Description, Row."Qty. to Assign", Row."Amount to Assign", Row."Qty. Assigned"));
            until Row.Next() = 0;
    end;

    /// <summary>
    /// Returns the wire name of a purchase applies-to document type.
    /// </summary>
    /// <param name="AppliesTo">The applies-to document type.</param>
    /// <returns>order, invoice, returnOrder, creditMemo, receipt, transferReceipt, returnShipment, salesShipment, returnReceipt, quote or blanketOrder.</returns>
    procedure PurchaseAppliesToName(AppliesTo: Enum "Purchase Applies-to Document Type"): Text
    begin
        case AppliesTo of
            AppliesTo::Order:
                exit('order');
            AppliesTo::Invoice:
                exit('invoice');
            AppliesTo::"Return Order":
                exit('returnOrder');
            AppliesTo::"Credit Memo":
                exit('creditMemo');
            AppliesTo::Receipt:
                exit('receipt');
            AppliesTo::"Transfer Receipt":
                exit('transferReceipt');
            AppliesTo::"Return Shipment":
                exit('returnShipment');
            AppliesTo::"Sales Shipment":
                exit('salesShipment');
            AppliesTo::"Return Receipt":
                exit('returnReceipt');
            AppliesTo::"Blanket Order":
                exit('blanketOrder');
        end;
        exit('quote');
    end;

    /// <summary>
    /// Returns the wire name of a sales applies-to document type.
    /// </summary>
    /// <param name="AppliesTo">The applies-to document type.</param>
    /// <returns>order, invoice, returnOrder, creditMemo, shipment, returnReceipt, quote or blanketOrder.</returns>
    procedure SalesAppliesToName(AppliesTo: Enum "Sales Applies-to Document Type"): Text
    begin
        case AppliesTo of
            AppliesTo::Order:
                exit('order');
            AppliesTo::Invoice:
                exit('invoice');
            AppliesTo::"Return Order":
                exit('returnOrder');
            AppliesTo::"Credit Memo":
                exit('creditMemo');
            AppliesTo::Shipment:
                exit('shipment');
            AppliesTo::"Return Receipt":
                exit('returnReceipt');
            AppliesTo::"Blanket Order":
                exit('blanketOrder');
        end;
        exit('quote');
    end;

    /// <summary>
    /// Refuses a missing or non-text value.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="RequestJson">The JSON object that should hold the key.</param>
    /// <param name="KeyName">The key.</param>
    /// <returns>True when the key holds a non-empty text.</returns>
    procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        TextErr: Label '%1 must be text.', Comment = '%1 = request key, is-IS=%1 verður að vera texti.';
        TextNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = request key, is-IS=Sendu %1 sem texta.';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if IsNullToken(Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if Token.IsValue() then
            Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TextErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), TextExpectedTok, StrSubstNo(TextNextStepLbl, KeyName));
            exit(false);
        end;
        if Token.AsValue().AsText() = '' then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Refuses a missing value or a value that is not a whole number.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="RequestJson">The JSON object that should hold the key.</param>
    /// <param name="KeyName">The key.</param>
    /// <returns>True when the key holds a whole number.</returns>
    procedure RequireInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Integer;
        IntegerErr: Label '%1 must be a whole number.', Comment = '%1 = request key, is-IS=%1 verður að vera heiltala.';
        IntegerNextStepLbl: Label 'Send %1 as a whole number, for example 10000.', Comment = '%1 = request key, is-IS=Sendu %1 sem heiltölu, til dæmis 10000.';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if IsNullToken(Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if Token.IsValue() then
            Token.WriteTo(Raw);
        if (Raw = '') or Raw.StartsWith('"') or (not Evaluate(Probe, Raw, 9)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(IntegerErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), IntegerExpectedTok, StrSubstNo(IntegerNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Refuses a missing value or a value that is not a number.
    /// </summary>
    /// <param name="Argument">The message argument that receives a refusal.</param>
    /// <param name="RequestJson">The JSON object that should hold the key.</param>
    /// <param name="KeyName">The key.</param>
    /// <returns>True when the key holds a number.</returns>
    procedure RequireDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Decimal;
        NumberErr: Label '%1 must be a number.', Comment = '%1 = request key, is-IS=%1 verður að vera tala.';
        NumberNextStepLbl: Label 'Send %1 as a number.', Comment = '%1 = request key, is-IS=Sendu %1 sem tölu.';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if IsNullToken(Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if Token.IsValue() then
            Token.WriteTo(Raw);
        if (Raw = '') or Raw.StartsWith('"') or (not Evaluate(Probe, Raw, 9)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NumberErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), NumberExpectedTok, StrSubstNo(NumberNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Answers MissingParameter for a key.
    /// </summary>
    /// <param name="Argument">The message argument that receives the refusal.</param>
    /// <param name="KeyName">The missing key.</param>
    procedure RespondMissing(var Argument: Record "Message Argument ori"; KeyName: Text)
    var
        MissingErr: Label '%1 is required.', Comment = '%1 = request key, is-IS=%1 er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send %1.', Comment = '%1 = request key, is-IS=Sendu %1.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), CopyStr(KeyName, 1, 250), '', CopyStr(KeyName, 1, 250), StrSubstNo(MissingNextStepLbl, KeyName));
    end;

    /// <summary>
    /// Reads a text value, or '' when the key is missing or not a value.
    /// </summary>
    /// <param name="RequestJson">The JSON object.</param>
    /// <param name="KeyName">The key.</param>
    /// <returns>The text value.</returns>
    procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>
    /// Reads a whole number, or 0 when the key is missing or not a value.
    /// </summary>
    /// <param name="RequestJson">The JSON object.</param>
    /// <param name="KeyName">The key.</param>
    /// <returns>The whole number.</returns>
    procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(0);
        if not Token.IsValue() then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>
    /// Reads a number, or 0 when the key is missing or not a value.
    /// </summary>
    /// <param name="RequestJson">The JSON object.</param>
    /// <param name="KeyName">The key.</param>
    /// <returns>The number.</returns>
    procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(0);
        if not Token.IsValue() then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsDecimal());
    end;

    /// <summary>
    /// True when the token is a JSON null.
    /// </summary>
    /// <param name="Token">The token.</param>
    /// <returns>True for null.</returns>
    procedure IsNullToken(Token: JsonToken): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().IsNull());
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PurchAssignment: Record "Item Charge Assignment (Purch)";
        SalesAssignment: Record "Item Charge Assignment (Sales)";
    begin
        if (not InventorySetup.ReadPermission()) or (not PurchAssignment.ReadPermission()) or (not SalesAssignment.ReadPermission()) then begin
            RespondPermissionDenied(Argument, false);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCharge) then begin
            RespondDomainDisabled(Argument);
            exit(false);
        end;
        exit(true);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId and lineNo.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, systemId og lineNo.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentTypeKeyTok, DocumentNoKeyTok, SystemIdKeyTok, LineNoKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure RequireIdentifier(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        HasDocumentNo: Boolean;
        HasSystemId: Boolean;
        ConflictErr: Label 'documentNo and systemId were both sent.', Comment = 'is-IS=documentNo og systemId voru bæði send.';
        ConflictNextStepLbl: Label 'Send documentNo or systemId, not both.', Comment = 'is-IS=Sendu documentNo eða systemId, ekki bæði.';
        MissingErr: Label 'documentNo or systemId is required.', Comment = 'is-IS=documentNo eða systemId er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send documentNo or systemId.', Comment = 'is-IS=Sendu documentNo eða systemId.';
    begin
        HasDocumentNo := RequestJson.Contains(DocumentNoKeyTok);
        HasSystemId := RequestJson.Contains(SystemIdKeyTok);
        if HasDocumentNo and HasSystemId then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, DocumentNoKeyTok, '', SystemIdKeyTok, ConflictNextStepLbl);
            exit(false);
        end;
        if (not HasDocumentNo) and (not HasSystemId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, DocumentNoKeyTok, '', DocumentNoKeyTok, MissingNextStepLbl);
            exit(false);
        end;
        if HasDocumentNo then
            exit(RequireText(Argument, RequestJson, DocumentNoKeyTok));
        exit(RequireText(Argument, RequestJson, SystemIdKeyTok));
    end;

    local procedure CheckSystemIdFormat(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        SystemId: Guid;
        SystemIdText: Text;
        GuidErr: Label 'systemId must be a GUID.', Comment = 'is-IS=systemId verður að vera GUID.';
        GuidNextStepLbl: Label 'Send the systemId of the purchase or sales document.', Comment = 'is-IS=Sendu systemId innkaupa- eða söluskjalsins.';
    begin
        if not RequestJson.Contains(SystemIdKeyTok) then
            exit(true);
        SystemIdText := ReadText(RequestJson, SystemIdKeyTok);
        if Evaluate(SystemId, SystemIdText) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, GuidErr, SystemIdKeyTok, CopyStr(SystemIdText, 1, 250), GuidExpectedTok, GuidNextStepLbl);
        exit(false);
    end;

    local procedure AnswerDocumentMatches(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; Matches: Integer): Boolean
    var
        Identifier: Text;
        IdentifierKey: Text;
        NotFoundErr: Label 'No open purchase or sales document matched the request.', Comment = 'is-IS=Ekkert opið innkaupa- eða söluskjal fannst sem passar við beiðnina.';
        NotFoundNextStepLbl: Label 'Check documentNo or systemId and documentType. The document must be an open order, invoice, return order or credit memo.', Comment = 'is-IS=Athugaðu documentNo eða systemId og documentType. Skjalið verður að vera opin pöntun, reikningur, vöruskilapöntun eða kreditreikningur.';
        AmbiguousErr: Label 'Several documents of different types have this number.', Comment = 'is-IS=Nokkur skjöl af ólíkum gerðum hafa þetta númer.';
        AmbiguousNextStepLbl: Label 'Send the systemId of the document instead of documentNo.', Comment = 'is-IS=Sendu systemId skjalsins í stað documentNo.';
    begin
        if Matches = 1 then
            exit(true);
        IdentifierKey := DocumentNoKeyTok;
        if RequestJson.Contains(SystemIdKeyTok) then
            IdentifierKey := SystemIdKeyTok;
        Identifier := ReadText(RequestJson, IdentifierKey);
        if Matches = 0 then
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, CopyStr(IdentifierKey, 1, 250), CopyStr(Identifier, 1, 250), '', NotFoundNextStepLbl)
        else
            Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousErr, CopyStr(IdentifierKey, 1, 250), CopyStr(Identifier, 1, 250), SystemIdKeyTok, AmbiguousNextStepLbl);
        exit(false);
    end;

    local procedure RespondLineNotFound(var Argument: Record "Message Argument ori"; LineNo: Integer)
    var
        LineNotFoundErr: Label 'The document has no line with this line number.', Comment = 'is-IS=Skjalið hefur enga línu með þessu línunúmeri.';
        LineNotFoundNextStepLbl: Label 'Check lineNo against the lines of the document.', Comment = 'is-IS=Berðu lineNo saman við línur skjalsins.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, LineNotFoundErr, LineNoKeyTok, Format(LineNo, 0, 9), '', LineNotFoundNextStepLbl);
    end;

    local procedure RespondNotChargeLine(var Argument: Record "Message Argument ori"; LineNo: Integer)
    var
        NotChargeErr: Label 'The line is not an item charge line.', Comment = 'is-IS=Línan er ekki kostnaðaraukalína.';
        NotChargeNextStepLbl: Label 'Pass the line no. of a Charge (Item) line.', Comment = 'is-IS=Sendu línunúmer línu af gerðinni Kostnaðarauki (vara).';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NotChargeErr, LineNoKeyTok, Format(LineNo, 0, 9), ChargeItemExpectedTok, NotChargeNextStepLbl);
    end;

    local procedure WritePurchaseResponse(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; PurchLine: Record "Purchase Line")
    var
        ResponseJson: JsonObject;
    begin
        PurchLine.CalcFields("Qty. to Assign", "Qty. Assigned");
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', PurchaseTok);
        ResponseJson.Add('documentNo', PurchHeader."No.");
        ResponseJson.Add('lineNo', PurchLine."Line No.");
        ResponseJson.Add('itemChargeNo', PurchLine."No.");
        ResponseJson.Add('quantity', PurchLine.Quantity);
        ResponseJson.Add('qtyToAssign', PurchLine."Qty. to Assign");
        ResponseJson.Add('qtyAssigned', PurchLine."Qty. Assigned");
        ResponseJson.Add('unassignedQuantity', PurchLine.Quantity - PurchLine."Qty. to Assign" - PurchLine."Qty. Assigned");
        ResponseJson.Add('assignments', PurchaseRows(PurchHeader, PurchLine."Line No."));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure WriteSalesResponse(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line")
    var
        ResponseJson: JsonObject;
    begin
        SalesLine.CalcFields("Qty. to Assign", "Qty. Assigned");
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', SalesTok);
        ResponseJson.Add('documentNo', SalesHeader."No.");
        ResponseJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson.Add('itemChargeNo', SalesLine."No.");
        ResponseJson.Add('quantity', SalesLine.Quantity);
        ResponseJson.Add('qtyToAssign', SalesLine."Qty. to Assign");
        ResponseJson.Add('qtyAssigned', SalesLine."Qty. Assigned");
        ResponseJson.Add('unassignedQuantity', SalesLine.Quantity - SalesLine."Qty. to Assign" - SalesLine."Qty. Assigned");
        ResponseJson.Add('assignments', SalesRows(SalesHeader, SalesLine."Line No."));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RowJson(RowLineNo: Integer; AppliesToName: Text; AppliesToDocNo: Code[20]; AppliesToLineNo: Integer; ItemNo: Code[20]; Description: Text; QtyToAssign: Decimal; AmountToAssign: Decimal; QtyAssigned: Decimal) Row: JsonObject
    begin
        Row.Add('lineNo', RowLineNo);
        Row.Add('appliesToDocType', AppliesToName);
        Row.Add('appliesToDocNo', AppliesToDocNo);
        Row.Add('appliesToDocLineNo', AppliesToLineNo);
        Row.Add('itemNo', ItemNo);
        Row.Add('description', Description);
        Row.Add('qtyToAssign', QtyToAssign);
        Row.Add('amountToAssign', AmountToAssign);
        Row.Add('qtyAssigned', QtyAssigned);
    end;
}
