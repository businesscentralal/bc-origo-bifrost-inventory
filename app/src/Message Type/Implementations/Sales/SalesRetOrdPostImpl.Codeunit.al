namespace Origo.Bifrost.Inventory;

using Microsoft.Utilities;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>
/// Sales.ReturnOrder.CreateFromPosted. Creates a sales return order or credit memo, or fills an open one, from posted
/// sales invoice or shipment lines with quantities, the way the Get Posted Document Lines to Reverse action does
/// (codeunit 6620 Copy Document Mgt. with exact cost reversal), so Appl.-from Item Entry is set on the new lines.
/// The write runs in Sales Ret. Ord. Post. Proc ori so a failure rolls back and answers a clean error.
/// </summary>
codeunit 10077032 "Sales Ret. Ord. Post. Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DocumentTypeKeyTok: Label 'documentType', Locked = true;
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        CustomerNoKeyTok: Label 'customerNo', Locked = true;
        LinesKeyTok: Label 'lines', Locked = true;
        SourceKeyTok: Label 'source', Locked = true;
        LineNoKeyTok: Label 'lineNo', Locked = true;
        QuantityKeyTok: Label 'quantity', Locked = true;
        StatusKeyTok: Label 'status', Locked = true;
        AllowedKeysTok: Label 'documentType, documentNo, systemId, customerNo, lines', Locked = true;
        AllowedLineKeysTok: Label 'source, documentNo, lineNo, quantity', Locked = true;
        WritePermissionSetTok: Label 'BIFROST Full ori', Locked = true;
        ReturnOrderTok: Label 'ReturnOrder', Locked = true;
        CreditMemoTok: Label 'CreditMemo', Locked = true;
        InvoiceTok: Label 'Invoice', Locked = true;
        ShipmentTok: Label 'Shipment', Locked = true;
        DocumentTypeValuesTok: Label 'ReturnOrder|CreditMemo', Locked = true;
        SourceValuesTok: Label 'Invoice|Shipment', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        GuidExpectedTok: Label 'guid', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        ObjectExpectedTok: Label 'object', Locked = true;
        IntegerExpectedTok: Label 'a positive JSON integer', Comment = 'is-IS=jákvæð JSON-heiltala';
        NumberExpectedTok: Label 'a positive JSON number', Comment = 'is-IS=jákvæð JSON-tala';
        OpenDocumentExpectedTok: Label 'openReturnOrderOrCreditMemo', Locked = true;
        CustomerExpectedTok: Label 'customer', Locked = true;
        LineIndexPathTok: Label 'lines[%1]', Locked = true;
        LineKeyPathTok: Label 'lines[%1].%2', Locked = true;
        LineSourcePathTok: Label 'lines[%1].source', Locked = true;
        LineDocumentNoPathTok: Label 'lines[%1].documentNo', Locked = true;
        LineNoPathTok: Label 'lines[%1].lineNo', Locked = true;
        LineQuantityPathTok: Label 'lines[%1].quantity', Locked = true;

    procedure IsEnabled(): Boolean
    var
        SalesLine: Record "Sales Line";
        SalesInvLine: Record "Sales Invoice Line";
        SalesShptLine: Record "Sales Shipment Line";
    begin
        exit(SalesLine.WritePermission() and SalesInvLine.ReadPermission() and SalesShptLine.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Sales Header");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a sales return order or credit memo from posted sales invoice or shipment lines.', Comment = 'is-IS=Stofnar sölutilbakaskilapöntun eða sölukreditreikning úr bókuðum sölureiknings- eða afhendingarlínum.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'return order, credit memo, get posted document lines to reverse, customer return, copy document', Comment = 'is-IS=tilbakaskilapöntun, kreditreikningur, sækja bókaðar skjalalínur til að bakfæra, skil viðskiptamanns, afrita skjal';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates or fills a sales return order or credit memo from posted invoice or shipment lines with quantities, as Get Posted Document Lines to Reverse does, and answers the document and the lines with Appl.-from Item Entry set.', Comment = 'is-IS=Stofnar eða fyllir út sölutilbakaskilapöntun eða sölukreditreikning úr bókuðum reiknings- eða afhendingarlínum með magni, eins og Sækja bókaðar skjalalínur til að bakfæra gerir, og svarar skjalinu og línunum með Jafna við vörufærslu útfyllt.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The target is named under data (documentType and, for an existing document, documentNo or systemId); subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentNoLbl: Label 'The No. of an existing open return order or credit memo that receives the lines. Leave out documentNo and systemId to create a new document.', Comment = 'is-IS=Númer opinnar tilbakaskilapöntunar eða kreditreiknings sem fær línurnar. Slepptu documentNo og systemId til að stofna nýtt skjal.';
        SystemIdLbl: Label 'The system id of that document, as an alternative to data.documentNo. Send one of them, not both.', Comment = 'is-IS=Kerfiskenni þess skjals, í stað data.documentNo. Sendu annað þeirra, ekki bæði.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', DocumentNoLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', SystemIdLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        LinesParameter: JsonObject;
        Children: JsonArray;
        DocumentTypeLbl: Label 'ReturnOrder or CreditMemo: the kind of document to create, or the kind of the existing document named by documentNo or systemId.', Comment = 'is-IS=ReturnOrder eða CreditMemo: tegund skjalsins sem á að stofna, eða tegund skjalsins sem documentNo eða systemId vísar á.';
        DocumentNoLbl: Label 'No. of an existing open return order or credit memo. Leave out documentNo and systemId to create a new document. Send this or systemId, not both.', Comment = 'is-IS=Númer opinnar tilbakaskilapöntunar eða kreditreiknings sem er til. Slepptu documentNo og systemId til að stofna nýtt skjal. Sendu þetta eða systemId, ekki bæði.';
        SystemIdLbl: Label 'systemId of an existing open return order or credit memo. Send this or documentNo, not both.', Comment = 'is-IS=systemId opinnar tilbakaskilapöntunar eða kreditreiknings sem er til. Sendu þetta eða documentNo, ekki bæði.';
        CustomerNoLbl: Label 'No. of the customer. Required for a new document; for an existing document it must be the customer of that document when it is sent. Every posted line must belong to this customer.', Comment = 'is-IS=Númer viðskiptamanns. Nauðsynlegt fyrir nýtt skjal; fyrir skjal sem er til verður það að vera viðskiptamaður þess skjals þegar það er sent. Allar bókaðar línur verða að tilheyra þessum viðskiptamanni.';
        LinesLbl: Label 'The posted lines to reverse, with the quantity of each. At least one line.', Comment = 'is-IS=Bókuðu línurnar sem á að bakfæra, með magni hverrar. Minnst ein lína.';
        SourceLbl: Label 'Invoice for a line of a posted sales invoice, Shipment for a line of a posted sales shipment.', Comment = 'is-IS=Invoice fyrir línu á bókuðum sölureikningi, Shipment fyrir línu á bókaðri söluafhendingu.';
        LineDocumentNoLbl: Label 'No. of the posted sales invoice or posted sales shipment.', Comment = 'is-IS=Númer bókaða sölureikningsins eða bókuðu söluafhendingarinnar.';
        LineNoLbl: Label 'Line number on that posted document.', Comment = 'is-IS=Línunúmer á því bókaða skjali.';
        QuantityLbl: Label 'Quantity to reverse in the unit of measure of the posted line, greater than 0 and not above what is left to reverse (for item lines the shipped quantity not yet returned). The same line sent twice is added up.', Comment = 'is-IS=Magn sem á að bakfæra í mælieiningu bókuðu línunnar, stærra en 0 og ekki umfram það sem er eftir að bakfæra (fyrir vörulínur afhent magn sem hefur ekki verið skilað). Sama lína send tvisvar leggst saman.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', true, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('customerNo', 'string', false, CustomerNoLbl));
        LinesParameter := ContractMgt.Parameter('lines', 'array', true, LinesLbl);
        Children.Add(ContractMgt.Parameter('source', 'string', true, SourceLbl));
        Children.Add(ContractMgt.Parameter('documentNo', 'string', true, LineDocumentNoLbl));
        Children.Add(ContractMgt.Parameter('lineNo', 'integer', true, LineNoLbl));
        Children.Add(ContractMgt.Parameter('quantity', 'number', true, QuantityLbl));
        LinesParameter.Add('children', Children);
        Parameters.Add(LinesParameter);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        LinesField: JsonObject;
        LineChildren: JsonArray;
    begin
        LineChildren.Add(ContractMgt.ResponseField('lineNo', 'integer', 'The line number of the new line on the return order or credit memo.'));
        LineChildren.Add(ContractMgt.ResponseField('type', 'string', 'The line type, for example Item.'));
        LineChildren.Add(ContractMgt.ResponseField('no', 'string', 'The No. on the line.'));
        LineChildren.Add(ContractMgt.ResponseField('description', 'string', 'The description of the line.'));
        LineChildren.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity on the line.'));
        LineChildren.Add(ContractMgt.ResponseField('applFromItemEntryNo', 'integer', 'The Appl.-from Item Entry number set on the line, 0 when the line has no item entry link (lines that are not items).'));
        LinesField := ContractMgt.ResponseField('lines', 'array', 'The lines this call added, in line order. One posted line can give several lines when it was sold from several item entries.');
        LinesField.Add('children', LineChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'ReturnOrder or CreditMemo.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the return order or credit memo.'));
        Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The system id of the document.'));
        Fields.Add(ContractMgt.ResponseField('created', 'boolean', 'true when this call created the document, false when it filled an existing one.'));
        Fields.Add(ContractMgt.ResponseField('customerNo', 'string', 'The sell-to customer of the document.'));
        Fields.Add(ContractMgt.ResponseField('addedCount', 'integer', 'The number of lines added.'));
        Fields.Add(LinesField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'documentType, lines, customerNo for a new document, or a field of a line (source, documentNo, lineNo, quantity) was not sent.', Comment = 'is-IS=documentType, lines, customerNo fyrir nýtt skjal, eða reitur línu (source, documentNo, lineNo, quantity) var ekki sendur.';
        MissingFixLbl: Label 'Send documentType and a non-empty lines array of {source, documentNo, lineNo, quantity}, and customerNo when no existing document is named.', Comment = 'is-IS=Sendu documentType og lines sem er ekki tómt fylki af {source, documentNo, lineNo, quantity}, og customerNo þegar ekkert skjal sem er til er tilgreint.';
        FormatWhenLbl: Label 'A key has the wrong JSON type or value form, systemId is not a GUID, lines is empty or holds something that is not an object, lineNo is not a positive whole number or quantity is not a positive number.', Comment = 'is-IS=Lykill er á rangri JSON-gerð eða gildissniði, systemId er ekki GUID, lines er tómt eða inniheldur eitthvað sem er ekki hlutur, lineNo er ekki jákvæð heiltala eða quantity er ekki jákvæð tala.';
        FormatFixLbl: Label 'Send text for the text keys, lines as a non-empty array of objects, lineNo as a positive integer and quantity as a number above 0.', Comment = 'is-IS=Sendu texta fyrir textalyklana, lines sem fylki af hlutum sem er ekki tómt, lineNo sem jákvæða heiltölu og quantity sem tölu yfir 0.';
        UnknownWhenLbl: Label 'The request or a line contains a key this type does not read.', Comment = 'is-IS=Beiðnin eða lína inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId, customerNo and lines; a line takes source, documentNo, lineNo and quantity.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, systemId, customerNo og lines; lína tekur source, documentNo, lineNo og quantity.';
        ConflictWhenLbl: Label 'documentNo and systemId were both sent, or documentType does not match the existing document.', Comment = 'is-IS=documentNo og systemId voru bæði send, eða documentType passar ekki við skjalið sem er til.';
        ConflictFixLbl: Label 'Send one of documentNo or systemId, and the documentType of that document.', Comment = 'is-IS=Sendu annaðhvort documentNo eða systemId, og documentType þess skjals.';
        ValueWhenLbl: Label 'documentType is not ReturnOrder or CreditMemo, source is not Invoice or Shipment, or the customer does not exist.', Comment = 'is-IS=documentType er hvorki ReturnOrder né CreditMemo, source er hvorki Invoice né Shipment, eða viðskiptamaðurinn er ekki til.';
        ValueFixLbl: Label 'Send documentType as ReturnOrder or CreditMemo, source as Invoice or Shipment, and an existing customer.', Comment = 'is-IS=Sendu documentType sem ReturnOrder eða CreditMemo, source sem Invoice eða Shipment, og viðskiptamann sem er til.';
        NotFoundWhenLbl: Label 'The named return order or credit memo, posted invoice, posted shipment or posted line does not exist.', Comment = 'is-IS=Tilbakaskilapöntunin eða kreditreikningurinn, bókaði reikningurinn, bókaða afhendingin eða bókaða línan sem er nefnd er ekki til.';
        NotFoundFixLbl: Label 'Check documentNo or systemId and the documentNo and lineNo of each line. Posted lines that were corrected or deleted are not available.', Comment = 'is-IS=Athugaðu documentNo eða systemId og documentNo og lineNo hverrar línu. Bókaðar línur sem voru leiðréttar eða eytt eru ekki tiltækar.';
        NotOpenWhenLbl: Label 'The existing return order or credit memo is released or pending approval.', Comment = 'is-IS=Tilbakaskilapöntunin eða kreditreikningurinn sem er til er útgefinn eða bíður samþykkis.';
        NotOpenFixLbl: Label 'Reopen the document with Sales.Document.Reopen, then send the request again.', Comment = 'is-IS=Opnaðu skjalið aftur með Sales.Document.Reopen og sendu beiðnina síðan aftur.';
        InvalidLineWhenLbl: Label 'A posted line belongs to another customer than the document, is a blank text line, or the quantity is above what is left to reverse.', Comment = 'is-IS=Bókuð lína tilheyrir öðrum viðskiptamanni en skjalið, er auð textalína, eða magnið er umfram það sem er eftir að bakfæra.';
        InvalidLineFixLbl: Label 'Send only lines of the customer of the document, and a quantity up to the remaining quantity named in the answer. Nothing was created.', Comment = 'is-IS=Sendu aðeins línur viðskiptamanns skjalsins, og magn upp að afgangsmagninu sem kemur fram í svarinu. Ekkert var stofnað.';
        PermissionWhenLbl: Label 'The caller cannot change sales lines or read posted sales invoices and shipments.', Comment = 'is-IS=Kallandinn getur ekki breytt sölulínum eða lesið bókaða sölureikninga og afhendingar.';
        PermissionFixLbl: Label 'Assign the Bifrost "Full Access" permission set and a Business Central permission set that can change sales return orders and credit memos and read posted sales documents.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst og Business Central heimildasafni sem getur breytt sölutilbakaskilapöntunum og sölukreditreikningum og lesið bókuð söluskjöl.';
        BusinessCentralWhenLbl: Label 'Business Central refused the copy, for example because the exact cost reversing link of an item line is missing or the currency differs from the document.', Comment = 'is-IS=Business Central hafnaði afrituninni, til dæmis af því að nákvæma kostnaðarbakfærslutengingu vantar á vörulínu eða gjaldmiðillinn er annar en á skjalinu.';
        BusinessCentralFixLbl: Label 'Read the error text, correct the posted line selection or the document in Business Central, and send the request again. Nothing was created.', Comment = 'is-IS=Lestu villutextann, lagaðu val bókuðu línanna eða skjalið í Business Central og sendu beiðnina aftur. Ekkert var stofnað.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ValueWhenLbl, ValueFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotOpenWhenLbl, NotOpenFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, InvalidLineWhenLbl, InvalidLineFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, BusinessCentralWhenLbl, BusinessCentralFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ChangesLbl: Label 'Creates a sales return order or credit memo, or adds lines to an open one, from posted invoice or shipment lines, copying them with exact cost reversal so Appl.-from Item Entry is set on item lines. Nothing is posted; the document and its lines can be deleted while it is open. Sending the request again adds the lines a second time. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.', Comment = 'is-IS=Stofnar sölutilbakaskilapöntun eða sölukreditreikning, eða bætir línum við opið skjal, úr bókuðum reiknings- eða afhendingarlínum og afritar þær með nákvæmri kostnaðarbakfærslu svo Jafna við vörufærslu er útfyllt á vörulínum. Ekkert er bókað; hægt er að eyða skjalinu og línum þess meðan það er opið. Ef beiðnin er send aftur bætast línurnar við í annað sinn. Höfnun vistar ekkert. Keðjuð Omit Commit köll haldast í færslu kallandans; stök köll nota einangraða skrift.';
    begin
        Preconditions.Add('The existing document, if one is named, is an open sales return order or credit memo (status Open).');
        Preconditions.Add('Every posted line belongs to the customer of the document and has a quantity left to reverse.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', WritePermissionSetTok);
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
        PostLbl: Label 'Post the return order or credit memo once the lines are checked; this type does not post.', Comment = 'is-IS=Bókaðu tilbakaskilapöntunina eða kreditreikninginn þegar línurnar hafa verið yfirfarnar; þessi tegund bókar ekki.';
        ReopenLbl: Label 'Reopen a released return order or credit memo before filling it.', Comment = 'is-IS=Opnaðu útgefna tilbakaskilapöntun eða kreditreikning aftur áður en hann er fylltur út.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Sales.Document.Post', PostLbl));
        Related.Add(ContractMgt.RelatedEntry('Sales.Document.Reopen', ReopenLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Sales.ReturnOrder.CreateFromPosted', 'Create the return order or credit memo from the posted lines to reverse.'));
        Steps.Add(ContractMgt.WorkflowStep('Sales.Document.Post', 'Post it so the goods return to stock and the customer is credited.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        NewTitleLbl: Label 'Create a return order for part of a posted invoice line', Comment = 'is-IS=Stofna tilbakaskilapöntun fyrir hluta af bókaðri reikningslínu';
        ExistingTitleLbl: Label 'Add a shipment line to an open credit memo', Comment = 'is-IS=Bæta afhendingarlínu við opinn kreditreikning';
    begin
        Examples.Add(ContractMgt.Example(NewTitleLbl, '{"type":"Sales.ReturnOrder.CreateFromPosted","data":{"documentType":"ReturnOrder","customerNo":"10000","lines":[{"source":"Invoice","documentNo":"103001","lineNo":10000,"quantity":2}]}}', '{"status":"Success","documentType":"ReturnOrder","documentNo":"1001","systemId":"6c1a7a6e-0000-0000-0000-000000000001","created":true,"customerNo":"10000","addedCount":1,"lines":[{"lineNo":10000,"type":"Item","no":"1896-S","description":"ATHENS Desk","quantity":2,"applFromItemEntryNo":812}]}'));
        Examples.Add(ContractMgt.Example(ExistingTitleLbl, '{"type":"Sales.ReturnOrder.CreateFromPosted","data":{"documentType":"CreditMemo","documentNo":"1002","lines":[{"source":"Shipment","documentNo":"102043","lineNo":10000,"quantity":1}]}}', '{"status":"Success","documentType":"CreditMemo","documentNo":"1002","systemId":"6c1a7a6e-0000-0000-0000-000000000002","created":false,"customerNo":"10000","addedCount":1,"lines":[{"lineNo":20000,"type":"Item","no":"1896-S","description":"ATHENS Desk","quantity":1,"applFromItemEntryNo":812}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates a sales return order or credit memo, or fills an open one, from posted sales invoice or shipment lines with quantities, as the Get Posted Document Lines to Reverse action does. Item lines are linked to the original item entries (Appl.-from Item Entry), so the return restores the original cost. Send documentType and the lines, and customerNo for a new document or documentNo or systemId for an existing one.', Comment = 'is-IS=Stofnar sölutilbakaskilapöntun eða sölukreditreikning, eða fyllir út opið skjal, úr bókuðum sölureiknings- eða afhendingarlínum með magni, eins og aðgerðin Sækja bókaðar skjalalínur til að bakfæra gerir. Vörulínur eru tengdar upphaflegu vörufærslunum (Jafna við vörufærslu) svo skilin færa upphaflegan kostnað til baka. Sendu documentType og lines, og customerNo fyrir nýtt skjal eða documentNo eða systemId fyrir skjal sem er til.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A line of another customer, a blank text line, or a quantity above what is left to reverse is refused with InvalidLine and nothing is created. What is left to reverse is the shipped quantity not yet returned for item lines, and the posted quantity for other lines. Quantities are in the unit of measure of the posted line. The same posted line sent twice in one request is added up. The call does not count lines already on open documents, so sending the same request again adds the lines again. The document is not posted; post it with Sales.Document.Post.', Comment = 'is-IS=Línu annars viðskiptamanns, auðri textalínu eða magni umfram það sem er eftir að bakfæra er hafnað með InvalidLine og ekkert er stofnað. Það sem er eftir að bakfæra er afhent magn sem hefur ekki verið skilað fyrir vörulínur, og bókað magn fyrir aðrar línur. Magn er í mælieiningu bókuðu línunnar. Sama bókaða línan send tvisvar í einni beiðni leggst saman. Kallið telur ekki línur sem eru þegar á opnum skjölum, svo sama beiðni send aftur bætir línunum við aftur. Skjalið er ekki bókað; bókaðu það með Sales.Document.Post.';
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
        SalesHeader: Record "Sales Header";
        TempInvLine: Record "Sales Invoice Line" temporary;
        TempShptLine: Record "Sales Shipment Line" temporary;
        RequestJson: JsonObject;
        CustomerNo: Code[20];
        CreateNew: Boolean;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TouchDeclaredKeys(RequestJson);
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateShape(Argument, RequestJson) then
            exit;
        CreateNew := not (RequestJson.Contains(DocumentNoKeyTok) or RequestJson.Contains(SystemIdKeyTok));
        if CreateNew then begin
            if not ResolveNewCustomer(Argument, RequestJson, CustomerNo) then
                exit;
        end else begin
            if not ResolveExisting(Argument, RequestJson, SalesHeader) then
                exit;
            CustomerNo := SalesHeader."Sell-to Customer No.";
            if not CheckCustomerMatches(Argument, RequestJson, CustomerNo) then
                exit;
        end;
        if not CollectLines(Argument, RequestJson, CustomerNo, TempInvLine, TempShptLine) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Sales Ret. Ord. Post. Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Sales Ret. Ord. Post. Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    /// <summary>
    /// Creates or locates the document, copies the validated posted lines into it and sets the response. Runs inside
    /// Sales Ret. Ord. Post. Proc ori after ExecuteBifrostTask has refused bad requests, so an error rolls the whole write back.
    /// </summary>
    /// <param name="Argument">The message argument with the validated request.</param>
    procedure RunCreateFromPosted(var Argument: Record "Message Argument ori")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TempInvLine: Record "Sales Invoice Line" temporary;
        TempShptLine: Record "Sales Shipment Line" temporary;
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AddedLines: JsonArray;
        CustomerNo: Code[20];
        LastLineNo: Integer;
        LinesNotCopied: Integer;
        MissingExCostRevLink: Boolean;
        Created: Boolean;
        NotCopiedErr: Label 'Business Central could not copy %1 of the posted lines to the document.', Comment = '%1 = number of lines, is-IS=Business Central gat ekki afritað %1 af bókuðu línunum á skjalið.';
        CostLinkErr: Label 'A posted item line has no exact cost reversing link, so it cannot be reversed with Appl.-from Item Entry.', Comment = 'is-IS=Bókuð vörulína hefur enga nákvæma kostnaðarbakfærslutengingu og því er ekki hægt að bakfæra hana með Jafna við vörufærslu.';
    begin
        RequestJson := Argument.GetRequestJson();
        // Re-check the lines before any write. A refusal here already answered the caller; creating the
        // header first would keep that document and the copy below would still answer Success.
        if RequestJson.Contains(DocumentNoKeyTok) or RequestJson.Contains(SystemIdKeyTok) then begin
            LocateDocument(RequestJson, SalesHeader);
            CustomerNo := SalesHeader."Sell-to Customer No.";
        end else
            if not ResolveNewCustomer(Argument, RequestJson, CustomerNo) then
                exit;
        if not CollectLines(Argument, RequestJson, CustomerNo, TempInvLine, TempShptLine) then
            exit;
        if not (RequestJson.Contains(DocumentNoKeyTok) or RequestJson.Contains(SystemIdKeyTok)) then begin
            CreateHeader(RequestJson, CustomerNo, SalesHeader);
            Created := true;
        end;
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            LastLineNo := SalesLine."Line No.";
        CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
        if TempInvLine.FindSet() then begin
            CopyDocMgt.CopySalesInvLinesToDoc(SalesHeader, TempInvLine, LinesNotCopied, MissingExCostRevLink);
            if LinesNotCopied > 0 then
                Error(NotCopiedErr, LinesNotCopied);
            if MissingExCostRevLink then
                Error(CostLinkErr);
        end;
        if TempShptLine.FindSet() then begin
            CopyDocMgt.CopySalesShptLinesToDoc(SalesHeader, TempShptLine, LinesNotCopied, MissingExCostRevLink);
            if LinesNotCopied > 0 then
                Error(NotCopiedErr, LinesNotCopied);
            if MissingExCostRevLink then
                Error(CostLinkErr);
        end;
        SalesLine.SetFilter("Line No.", '>%1', LastLineNo);
        if SalesLine.FindSet() then
            repeat
                AddedLines.Add(AddedLineJson(SalesLine));
            until SalesLine.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', DocumentTypeText(SalesHeader."Document Type"));
        ResponseJson.Add('documentNo', SalesHeader."No.");
        ResponseJson.Add('systemId', Format(SalesHeader.SystemId, 0, 4).ToLower());
        ResponseJson.Add('created', Created);
        ResponseJson.Add('customerNo', SalesHeader."Sell-to Customer No.");
        ResponseJson.Add('addedCount', AddedLines.Count());
        ResponseJson.Add('lines', AddedLines);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CreateHeader(RequestJson: JsonObject; CustomerNo: Code[20]; var SalesHeader: Record "Sales Header")
    begin
        SalesHeader.Init();
        SalesHeader."Document Type" := RequestedDocumentType(RequestJson);
        SalesHeader."No." := '';
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Modify(true);
    end;

    local procedure AddedLineJson(SalesLine: Record "Sales Line") Line: JsonObject
    begin
        Line.Add('lineNo', SalesLine."Line No.");
        Line.Add('type', Format(SalesLine.Type));
        Line.Add('no', SalesLine."No.");
        Line.Add('description', SalesLine.Description);
        Line.Add('quantity', SalesLine.Quantity);
        Line.Add('applFromItemEntryNo', SalesLine."Appl.-from Item Entry");
    end;

    local procedure DocumentTypeText(DocumentType: Enum "Sales Document Type"): Text
    begin
        if DocumentType = DocumentType::"Credit Memo" then
            exit(CreditMemoTok);
        exit(ReturnOrderTok);
    end;

    local procedure RequestedDocumentType(RequestJson: JsonObject): Enum "Sales Document Type"
    var
        SalesHeader: Record "Sales Header";
    begin
        if LowerCase(ReadText(RequestJson, DocumentTypeKeyTok)) = LowerCase(CreditMemoTok) then
            exit(SalesHeader."Document Type"::"Credit Memo");
        exit(SalesHeader."Document Type"::"Return Order");
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        PermissionDeniedErr: Label 'Permission denied for Sales.ReturnOrder.CreateFromPosted.', Comment = 'is-IS=Heimild hafnað fyrir Sales.ReturnOrder.CreateFromPosted.';
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set and a Business Central permission set that can change sales return orders and credit memos and read posted sales documents.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst og Business Central heimildasafni sem getur breytt sölutilbakaskilapöntunum og sölukreditreikningum og lesið bókuð söluskjöl.';
    begin
        if IsEnabled() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', WritePermissionSetTok, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure TouchDeclaredKeys(RequestJson: JsonObject)
    begin
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentType') then;
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('customerNo') then;
        if RequestJson.Contains('lines') then;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId, customerNo and lines.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, systemId, customerNo og lines.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentTypeKeyTok, DocumentNoKeyTok, SystemIdKeyTok, CustomerNoKeyTok, LinesKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateShape(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Token: JsonToken;
        SystemId: Guid;
        MissingTypeErr: Label 'documentType is required.', Comment = 'is-IS=documentType er nauðsynlegt.';
        MissingTypeNextLbl: Label 'Send documentType as ReturnOrder or CreditMemo.', Comment = 'is-IS=Sendu documentType sem ReturnOrder eða CreditMemo.';
        MissingLinesErr: Label 'lines is required.', Comment = 'is-IS=lines er nauðsynlegt.';
        MissingLinesNextLbl: Label 'Send lines as a non-empty array of {source, documentNo, lineNo, quantity}.', Comment = 'is-IS=Sendu lines sem fylki af {source, documentNo, lineNo, quantity} sem er ekki tómt.';
        BothErr: Label 'Send documentNo or systemId, not both.', Comment = 'is-IS=Sendu documentNo eða systemId, ekki bæði.';
        BothNextLbl: Label 'Remove one of the two keys and send the request again.', Comment = 'is-IS=Fjarlægðu annan lykilinn og sendu beiðnina aftur.';
        FormatErr: Label '%1 has the wrong format.', Comment = '%1 = request key, is-IS=%1 er á röngu sniði.';
        FormatNextLbl: Label 'Send %1 as %2.', Comment = '%1 = request key, %2 = expected format, is-IS=Sendu %1 sem %2.';
        TypeValueErr: Label 'documentType must be ReturnOrder or CreditMemo.', Comment = 'is-IS=documentType verður að vera ReturnOrder eða CreditMemo.';
        TypeValueNextLbl: Label 'Send documentType as ReturnOrder or CreditMemo.', Comment = 'is-IS=Sendu documentType sem ReturnOrder eða CreditMemo.';
    begin
        if not RequestJson.Get(DocumentTypeKeyTok, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingTypeErr, DocumentTypeKeyTok, '', DocumentTypeValuesTok, MissingTypeNextLbl);
            exit(false);
        end;
        if not IsTextToken(Token) then
            exit(RespondFormat(Argument, DocumentTypeKeyTok, TextExpectedTok, FormatErr, FormatNextLbl));
        if not (LowerCase(Token.AsValue().AsText()) in [LowerCase(ReturnOrderTok), LowerCase(CreditMemoTok)]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, TypeValueErr, DocumentTypeKeyTok, CopyStr(Token.AsValue().AsText(), 1, 250), DocumentTypeValuesTok, TypeValueNextLbl);
            exit(false);
        end;
        if RequestJson.Contains(DocumentNoKeyTok) and RequestJson.Contains(SystemIdKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, BothErr, SystemIdKeyTok, '', DocumentNoKeyTok, BothNextLbl);
            exit(false);
        end;
        if RequestJson.Get(DocumentNoKeyTok, Token) then
            if not IsTextToken(Token) then
                exit(RespondFormat(Argument, DocumentNoKeyTok, TextExpectedTok, FormatErr, FormatNextLbl));
        if RequestJson.Get(CustomerNoKeyTok, Token) then
            if not IsTextToken(Token) then
                exit(RespondFormat(Argument, CustomerNoKeyTok, TextExpectedTok, FormatErr, FormatNextLbl));
        if RequestJson.Get(SystemIdKeyTok, Token) then begin
            if not IsTextToken(Token) then
                exit(RespondFormat(Argument, SystemIdKeyTok, GuidExpectedTok, FormatErr, FormatNextLbl));
            if not Evaluate(SystemId, Token.AsValue().AsText()) then
                exit(RespondFormat(Argument, SystemIdKeyTok, GuidExpectedTok, FormatErr, FormatNextLbl));
        end;
        if not RequestJson.Get(LinesKeyTok, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLinesErr, LinesKeyTok, '', LinesKeyTok, MissingLinesNextLbl);
            exit(false);
        end;
        if not Token.IsArray() then
            exit(RespondFormat(Argument, LinesKeyTok, ArrayExpectedTok, FormatErr, FormatNextLbl));
        if Token.AsArray().Count() = 0 then
            exit(RespondFormat(Argument, LinesKeyTok, ArrayExpectedTok, FormatErr, FormatNextLbl));
        exit(true);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Expected: Text; FormatErr: Text; FormatNextLbl: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', CopyStr(Expected, 1, 250), StrSubstNo(FormatNextLbl, KeyName, Expected));
        exit(false);
    end;

    local procedure IsTextToken(Token: JsonToken): Boolean
    var
        TextValue: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(TextValue);
        exit(TextValue.StartsWith('"'));
    end;

    local procedure TryReadNumber(Token: JsonToken; var Number: Decimal): Boolean
    var
        TextValue: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(TextValue);
        if TextValue.StartsWith('"') or (TextValue in ['true', 'false']) then
            exit(false);
        exit(Evaluate(Number, TextValue, 9));
    end;

    local procedure ResolveNewCustomer(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var CustomerNo: Code[20]): Boolean
    var
        Customer: Record Customer;
        MissingErr: Label 'customerNo is required when no existing document is named.', Comment = 'is-IS=customerNo er nauðsynlegt þegar ekkert skjal sem er til er tilgreint.';
        MissingNextLbl: Label 'Send customerNo, or send documentNo or systemId of an existing open return order or credit memo.', Comment = 'is-IS=Sendu customerNo, eða sendu documentNo eða systemId opinnar tilbakaskilapöntunar eða kreditreiknings sem er til.';
        UnknownCustomerErr: Label 'Customer %1 does not exist.', Comment = '%1 = customer no., is-IS=Viðskiptamaður %1 er ekki til.';
        UnknownCustomerNextLbl: Label 'Send the No. of an existing customer.', Comment = 'is-IS=Sendu númer viðskiptamanns sem er til.';
        Value: Text;
    begin
        Value := ReadText(RequestJson, CustomerNoKeyTok);
        if Value = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, CustomerNoKeyTok, '', CustomerExpectedTok, MissingNextLbl);
            exit(false);
        end;
        if not Customer.Get(CopyStr(Value, 1, MaxStrLen(Customer."No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownCustomerErr, Value), CustomerNoKeyTok, CopyStr(Value, 1, 250), CustomerExpectedTok, UnknownCustomerNextLbl);
            exit(false);
        end;
        CustomerNo := Customer."No.";
        exit(true);
    end;

    local procedure ResolveExisting(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SalesHeader: Record "Sales Header"): Boolean
    var
        NotFoundErr: Label 'No open return order or credit memo %1 was found.', Comment = '%1 = document no. or system id, is-IS=Engin opin tilbakaskilapöntun eða kreditreikningur %1 fannst.';
        NotFoundNextLbl: Label 'Check documentNo or systemId; this type takes a sales return order or credit memo, not an order, an invoice or a posted document.', Comment = 'is-IS=Athugaðu documentNo eða systemId; þessi tegund tekur sölutilbakaskilapöntun eða sölukreditreikning, ekki pöntun, reikning eða bókað skjal.';
        TypeMismatchErr: Label 'Document %1 is a %2, not a %3.', Comment = '%1 = document no., %2 = actual document type, %3 = requested document type, is-IS=Skjal %1 er %2, ekki %3.';
        TypeMismatchNextLbl: Label 'Send the documentType of the document named by documentNo or systemId.', Comment = 'is-IS=Sendu documentType skjalsins sem documentNo eða systemId vísar á.';
        NotOpenErr: Label 'Document %1 is not open; its status is %2.', Comment = '%1 = document no., %2 = status, is-IS=Skjal %1 er ekki opið; staða þess er %2.';
        NotOpenNextLbl: Label 'Reopen the document with Sales.Document.Reopen, then send the request again.', Comment = 'is-IS=Opnaðu skjalið aftur með Sales.Document.Reopen og sendu beiðnina síðan aftur.';
        Identifier: Text;
        KeyName: Text;
    begin
        if not LocateDocument(RequestJson, SalesHeader) then begin
            KeyName := DocumentNoKeyTok;
            if RequestJson.Contains(SystemIdKeyTok) then
                KeyName := SystemIdKeyTok;
            Identifier := ReadText(RequestJson, KeyName);
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, Identifier), CopyStr(KeyName, 1, 250), CopyStr(Identifier, 1, 250), OpenDocumentExpectedTok, NotFoundNextLbl);
            exit(false);
        end;
        if SalesHeader."Document Type" <> RequestedDocumentType(RequestJson) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(TypeMismatchErr, SalesHeader."No.", DocumentTypeText(SalesHeader."Document Type"), ReadText(RequestJson, DocumentTypeKeyTok)), DocumentTypeKeyTok, CopyStr(ReadText(RequestJson, DocumentTypeKeyTok), 1, 250), DocumentTypeText(SalesHeader."Document Type"), TypeMismatchNextLbl);
            exit(false);
        end;
        if SalesHeader.Status <> SalesHeader.Status::Open then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotOpenErr, SalesHeader."No.", SalesHeader.Status), StatusKeyTok, CopyStr(Format(SalesHeader.Status), 1, 250), Format(SalesHeader.Status::Open), NotOpenNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure LocateDocument(RequestJson: JsonObject; var SalesHeader: Record "Sales Header"): Boolean
    var
        SystemId: Guid;
    begin
        if RequestJson.Contains(SystemIdKeyTok) then begin
            if not Evaluate(SystemId, ReadText(RequestJson, SystemIdKeyTok)) then
                exit(false);
            if not SalesHeader.GetBySystemId(SystemId) then
                exit(false);
            exit(SalesHeader."Document Type" in [SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo"]);
        end;
        exit(SalesHeader.Get(RequestedDocumentType(RequestJson), CopyStr(ReadText(RequestJson, DocumentNoKeyTok), 1, MaxStrLen(SalesHeader."No."))));
    end;

    local procedure CheckCustomerMatches(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; CustomerNo: Code[20]): Boolean
    var
        CustomerMismatchErr: Label 'customerNo %1 is not the customer %2 of the document.', Comment = '%1 = sent customer, %2 = document customer, is-IS=customerNo %1 er ekki viðskiptamaður %2 á skjalinu.';
        CustomerMismatchNextLbl: Label 'Leave customerNo out, or send the customer of the existing document.', Comment = 'is-IS=Slepptu customerNo, eða sendu viðskiptamann skjalsins sem er til.';
        Value: Text;
    begin
        Value := ReadText(RequestJson, CustomerNoKeyTok);
        if (Value = '') or (UpperCase(Value) = UpperCase(CustomerNo)) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(CustomerMismatchErr, Value, CustomerNo), CustomerNoKeyTok, CopyStr(Value, 1, 250), CustomerNo, CustomerMismatchNextLbl);
        exit(false);
    end;

    local procedure CollectLines(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; CustomerNo: Code[20]; var TempInvLine: Record "Sales Invoice Line" temporary; var TempShptLine: Record "Sales Shipment Line" temporary): Boolean
    var
        Token: JsonToken;
        LineToken: JsonToken;
        LineJson: JsonObject;
        Index: Integer;
    begin
        TempInvLine.Reset();
        TempInvLine.DeleteAll();
        TempShptLine.Reset();
        TempShptLine.DeleteAll();
        RequestJson.Get(LinesKeyTok, Token);
        foreach LineToken in Token.AsArray() do begin
            Index += 1;
            if not LineToken.IsObject() then
                exit(RespondLineFormat(Argument, StrSubstNo(LineIndexPathTok, Index), ObjectExpectedTok));
            LineJson := LineToken.AsObject();
            if not CollectLine(Argument, LineJson, Index, CustomerNo, TempInvLine, TempShptLine) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure CollectLine(var Argument: Record "Message Argument ori"; LineJson: JsonObject; Index: Integer; CustomerNo: Code[20]; var TempInvLine: Record "Sales Invoice Line" temporary; var TempShptLine: Record "Sales Shipment Line" temporary): Boolean
    var
        SalesInvLine: Record "Sales Invoice Line";
        SalesShptLine: Record "Sales Shipment Line";
        Token: JsonToken;
        KeyName: Text;
        Source: Text;
        DocumentNo: Text;
        Where: Text;
        LineNoValue: Decimal;
        LineNo: Integer;
        Quantity: Decimal;
        Remaining: Decimal;
        Total: Decimal;
        UnknownLineKeyErr: Label 'The line contains an unknown key.', Comment = 'is-IS=Línan inniheldur óþekktan lykil.';
        UnknownLineKeyNextLbl: Label 'Remove the unknown key. A line takes source, documentNo, lineNo and quantity.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Lína tekur source, documentNo, lineNo og quantity.';
        MissingLineKeyErr: Label '%1 is required on every line.', Comment = '%1 = line key, is-IS=%1 er nauðsynlegt á hverri línu.';
        MissingLineKeyNextLbl: Label 'Send source, documentNo, lineNo and quantity on every line.', Comment = 'is-IS=Sendu source, documentNo, lineNo og quantity á hverri línu.';
        SourceValueErr: Label 'source must be Invoice or Shipment.', Comment = 'is-IS=source verður að vera Invoice eða Shipment.';
        SourceValueNextLbl: Label 'Send source as Invoice for a posted sales invoice line or Shipment for a posted sales shipment line.', Comment = 'is-IS=Sendu source sem Invoice fyrir bókaða sölureikningslínu eða Shipment fyrir bókaða söluafhendingarlínu.';
        LineNotFoundErr: Label 'Posted %1 %2 line %3 was not found.', Comment = '%1 = source, %2 = document no., %3 = line no., is-IS=Bókuð %1 %2 lína %3 fannst ekki.';
        LineNotFoundNextLbl: Label 'Check documentNo and lineNo of the posted document.', Comment = 'is-IS=Athugaðu documentNo og lineNo bókaða skjalsins.';
        OtherCustomerErr: Label 'Posted %1 %2 line %3 belongs to customer %4, not to %5 of the document.', Comment = '%1 = source, %2 = document no., %3 = line no., %4 = line customer, %5 = document customer, is-IS=Bókuð %1 %2 lína %3 tilheyrir viðskiptamanni %4, ekki %5 á skjalinu.';
        OtherCustomerNextLbl: Label 'Send only lines of the customer of the document, or create a separate document for the other customer. Nothing was created.', Comment = 'is-IS=Sendu aðeins línur viðskiptamanns skjalsins, eða stofnaðu sérstakt skjal fyrir hinn viðskiptamanninn. Ekkert var stofnað.';
        BlankLineErr: Label 'Posted %1 %2 line %3 is a text line without a type and cannot be reversed.', Comment = '%1 = source, %2 = document no., %3 = line no., is-IS=Bókuð %1 %2 lína %3 er textalína án tegundar og ekki hægt að bakfæra hana.';
        BlankLineNextLbl: Label 'Send only lines that have a type and a quantity. Nothing was created.', Comment = 'is-IS=Sendu aðeins línur sem hafa tegund og magn. Ekkert var stofnað.';
        TooMuchErr: Label 'Posted %1 %2 line %3 has %4 left to reverse, but %5 was requested.', Comment = '%1 = source, %2 = document no., %3 = line no., %4 = remaining quantity, %5 = requested quantity, is-IS=Bókuð %1 %2 lína %3 á %4 eftir að bakfæra en beðið var um %5.';
        TooMuchNextLbl: Label 'Send a quantity up to the remaining quantity. Nothing was created.', Comment = 'is-IS=Sendu magn upp að afgangsmagninu. Ekkert var stofnað.';
    begin
        TouchLineKeys(LineJson);
        foreach KeyName in LineJson.Keys() do
            if not (KeyName in [SourceKeyTok, DocumentNoKeyTok, LineNoKeyTok, QuantityKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownLineKeyErr, CopyStr(StrSubstNo(LineKeyPathTok, Index, KeyName), 1, 250), CopyStr(KeyName, 1, 250), AllowedLineKeysTok, UnknownLineKeyNextLbl);
                exit(false);
            end;
        foreach KeyName in AllowedLineKeysTok.Split(', ') do
            if not LineJson.Contains(KeyName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingLineKeyErr, KeyName), CopyStr(StrSubstNo(LineKeyPathTok, Index, KeyName), 1, 250), '', CopyStr(KeyName, 1, 250), MissingLineKeyNextLbl);
                exit(false);
            end;
        LineJson.Get(SourceKeyTok, Token);
        if not IsTextToken(Token) then
            exit(RespondLineFormat(Argument, StrSubstNo(LineSourcePathTok, Index), TextExpectedTok));
        Source := Token.AsValue().AsText();
        LineJson.Get(DocumentNoKeyTok, Token);
        if not IsTextToken(Token) then
            exit(RespondLineFormat(Argument, StrSubstNo(LineDocumentNoPathTok, Index), TextExpectedTok));
        DocumentNo := Token.AsValue().AsText();
        LineJson.Get(LineNoKeyTok, Token);
        if not TryReadNumber(Token, LineNoValue) or (LineNoValue < 1) or (LineNoValue > 2147483647) or (LineNoValue <> Round(LineNoValue, 1)) then
            exit(RespondLineFormat(Argument, StrSubstNo(LineNoPathTok, Index), IntegerExpectedTok));
        LineNo := LineNoValue;
        LineJson.Get(QuantityKeyTok, Token);
        if not TryReadNumber(Token, Quantity) or (Quantity <= 0) then
            exit(RespondLineFormat(Argument, StrSubstNo(LineQuantityPathTok, Index), NumberExpectedTok));
        if not (LowerCase(Source) in [LowerCase(InvoiceTok), LowerCase(ShipmentTok)]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SourceValueErr, CopyStr(StrSubstNo(LineSourcePathTok, Index), 1, 250), CopyStr(Source, 1, 250), SourceValuesTok, SourceValueNextLbl);
            exit(false);
        end;
        Where := StrSubstNo(LineIndexPathTok, Index);

        if LowerCase(Source) = LowerCase(InvoiceTok) then begin
            if not SalesInvLine.Get(CopyStr(DocumentNo, 1, MaxStrLen(SalesInvLine."Document No.")), LineNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundErr, InvoiceTok, DocumentNo, LineNo), CopyStr(Where + '.documentNo', 1, 250), CopyStr(DocumentNo, 1, 250), InvoiceTok, LineNotFoundNextLbl);
                exit(false);
            end;
            if SalesInvLine.Type = SalesInvLine.Type::" " then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(BlankLineErr, InvoiceTok, DocumentNo, LineNo), CopyStr(Where + '.lineNo', 1, 250), Format(LineNo, 0, 9), '', BlankLineNextLbl);
                exit(false);
            end;
            if SalesInvLine."Sell-to Customer No." <> CustomerNo then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OtherCustomerErr, InvoiceTok, DocumentNo, LineNo, SalesInvLine."Sell-to Customer No.", CustomerNo), CopyStr(Where + '.documentNo', 1, 250), SalesInvLine."Sell-to Customer No.", CustomerNo, OtherCustomerNextLbl);
                exit(false);
            end;
            Total := Quantity;
            if TempInvLine.Get(SalesInvLine."Document No.", SalesInvLine."Line No.") then
                Total += TempInvLine.Quantity;
            Remaining := RemainingInvoiceQuantity(SalesInvLine);
            if Total > Remaining then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(TooMuchErr, InvoiceTok, DocumentNo, LineNo, Remaining, Total), CopyStr(Where + '.quantity', 1, 250), Format(Total, 0, 9), Format(Remaining, 0, 9), TooMuchNextLbl);
                exit(false);
            end;
            if TempInvLine.Get(SalesInvLine."Document No.", SalesInvLine."Line No.") then begin
                TempInvLine.Quantity := Total;
                TempInvLine.Modify();
            end else begin
                TempInvLine := SalesInvLine;
                TempInvLine.Quantity := Quantity;
                TempInvLine.Insert();
            end;
            exit(true);
        end;

        if not SalesShptLine.Get(CopyStr(DocumentNo, 1, MaxStrLen(SalesShptLine."Document No.")), LineNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineNotFoundErr, ShipmentTok, DocumentNo, LineNo), CopyStr(Where + '.documentNo', 1, 250), CopyStr(DocumentNo, 1, 250), ShipmentTok, LineNotFoundNextLbl);
            exit(false);
        end;
        if SalesShptLine.Type = SalesShptLine.Type::" " then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(BlankLineErr, ShipmentTok, DocumentNo, LineNo), CopyStr(Where + '.lineNo', 1, 250), Format(LineNo, 0, 9), '', BlankLineNextLbl);
            exit(false);
        end;
        if SalesShptLine."Sell-to Customer No." <> CustomerNo then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OtherCustomerErr, ShipmentTok, DocumentNo, LineNo, SalesShptLine."Sell-to Customer No.", CustomerNo), CopyStr(Where + '.documentNo', 1, 250), SalesShptLine."Sell-to Customer No.", CustomerNo, OtherCustomerNextLbl);
            exit(false);
        end;
        Total := Quantity;
        if TempShptLine.Get(SalesShptLine."Document No.", SalesShptLine."Line No.") then
            Total += TempShptLine.Quantity;
        Remaining := RemainingShipmentQuantity(SalesShptLine);
        if Total > Remaining then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(TooMuchErr, ShipmentTok, DocumentNo, LineNo, Remaining, Total), CopyStr(Where + '.quantity', 1, 250), Format(Total, 0, 9), Format(Remaining, 0, 9), TooMuchNextLbl);
            exit(false);
        end;
        if TempShptLine.Get(SalesShptLine."Document No.", SalesShptLine."Line No.") then begin
            TempShptLine.Quantity := Total;
            TempShptLine.Modify();
        end else begin
            TempShptLine := SalesShptLine;
            TempShptLine.Quantity := Quantity;
            TempShptLine.Insert();
        end;
        exit(true);
    end;

    local procedure TouchLineKeys(LineJson: JsonObject)
    begin
        // String literals are the keys the contract guard counts as reads.
        if LineJson.Contains('source') then;
        if LineJson.Contains('documentNo') then;
        if LineJson.Contains('lineNo') then;
        if LineJson.Contains('quantity') then;
    end;

    local procedure RemainingInvoiceQuantity(SalesInvLine: Record "Sales Invoice Line"): Decimal
    var
        ShippedQtyNotReturned: Decimal;
        RevUnitCostLCY: Decimal;
    begin
        if SalesInvLine.Type <> SalesInvLine.Type::Item then
            exit(SalesInvLine.Quantity);
        SalesInvLine.CalcShippedSaleNotReturned(ShippedQtyNotReturned, RevUnitCostLCY, true);
        exit(ShippedQtyNotReturned);
    end;

    local procedure RemainingShipmentQuantity(SalesShptLine: Record "Sales Shipment Line"): Decimal
    var
        ShippedQtyNotReturned: Decimal;
        RevUnitCostLCY: Decimal;
    begin
        if SalesShptLine.Type <> SalesShptLine.Type::Item then
            exit(SalesShptLine.Quantity);
        SalesShptLine.CalcShippedSaleNotReturned(ShippedQtyNotReturned, RevUnitCostLCY, true);
        exit(ShippedQtyNotReturned);
    end;

    local procedure RespondLineFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Expected: Text): Boolean
    var
        FormatErr: Label '%1 has the wrong format.', Comment = '%1 = request key, is-IS=%1 er á röngu sniði.';
        FormatNextLbl: Label 'Send %1 as %2.', Comment = '%1 = request key, %2 = expected format, is-IS=Sendu %1 sem %2.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', CopyStr(Expected, 1, 250), StrSubstNo(FormatNextLbl, KeyName, Expected));
        exit(false);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
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
}
