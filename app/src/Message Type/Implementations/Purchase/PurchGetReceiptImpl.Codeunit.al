namespace Origo.Bifrost.Inventory;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Origo.Bifrost;

/// <summary>
/// Purchase.PurchaseInvoice.GetReceiptLines. Pulls posted, not invoiced purchase receipt lines into an open purchase invoice,
/// the way the Get Receipt Lines action on the purchase invoice subform does (codeunit 74 Purch.-Get Receipt).
/// The write runs in Purch Get Receipt Proc ori so a failure rolls back and answers a clean error.
/// </summary>
codeunit 10077030 "Purch Get Receipt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        ReceiptNosKeyTok: Label 'receiptNos', Locked = true;
        AllReceiptsKeyTok: Label 'allReceipts', Locked = true;
        AllowedKeysTok: Label 'documentNo, systemId, receiptNos, allReceipts', Locked = true;
        WritePermissionSetTok: Label 'BIFROST Full ori', Locked = true;
        InvoicedReasonTok: Label 'invoiced', Locked = true;
        OnOpenInvoiceReasonTok: Label 'onOpenInvoice', Locked = true;
        TextExpectedLbl: Label 'non-empty text (maximum 20 characters)', Comment = 'is-IS=texti sem er ekki auður (mest 20 stafir)';
        GuidExpectedTok: Label 'guid', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        OpenInvoiceExpectedTok: Label 'openPurchaseInvoice', Locked = true;
        TrueExpectedTok: Label 'true', Locked = true;
        FalseTok: Label 'false', Locked = true;
        StatusKeyTok: Label 'status', Locked = true;
        PostedReceiptExpectedTok: Label 'postedPurchaseReceipt', Locked = true;

    /// <summary>Implements IsEnabled for purchase receipt invoice lines.</summary>
    procedure IsEnabled(): Boolean
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        exit(PurchHeader.WritePermission() and PurchLine.WritePermission() and PurchRcptHeader.ReadPermission() and PurchRcptLine.ReadPermission());
    end;

    /// <summary>Implements GetFilterTableNo for purchase receipt invoice lines.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Purch. Rcpt. Line");
    end;

    /// <summary>Implements GetDescription for purchase receipt invoice lines.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Pulls posted, not invoiced purchase receipt lines into an open purchase invoice.', Comment = 'is-IS=Sækir bókaðar, óreikningsfærðar móttökulínur innkaupa inn á opinn innkaupareikning.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Implements GetKeywords for purchase receipt invoice lines.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'get receipt lines, combined invoice, receipt, purchase invoice, not invoiced', Comment = 'is-IS=sækja móttökulínur, samsettur reikningur, móttaka, innkaupareikningur, óreikningsfært';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Implements GetSelectionDescription for purchase receipt invoice lines.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Invoices several posted receipts of one vendor on one purchase invoice, as the Get Receipt Lines action does, and lists the lines it added and the lines it skipped.', Comment = 'is-IS=Reikningsfærir nokkrar bókaðar móttökur eins lánardrottins á einum innkaupareikningi, eins og aðgerðin Sækja móttökulínur gerir, og telur upp línurnar sem bættust við og línurnar sem var sleppt.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Implements GetEnvelope for purchase receipt invoice lines.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The purchase invoice is named under data.documentNo or data.systemId; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Implements GetTarget for purchase receipt invoice lines.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentNoLbl: Label 'The No. of the open purchase invoice that receives the lines.', Comment = 'is-IS=Númer opna innkaupareikningsins sem fær línurnar.';
        SystemIdLbl: Label 'The system id of that purchase invoice, as an alternative to data.documentNo. Send one of them, not both.', Comment = 'is-IS=Kerfiskenni innkaupareikningsins, í stað data.documentNo. Sendu annað þeirra, ekki bæði.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', DocumentNoLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', SystemIdLbl));
        exit(true);
    end;

    /// <summary>Implements GetParameters for purchase receipt invoice lines.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentNoLbl: Label 'No. of the open purchase invoice. Send this or systemId.', Comment = 'is-IS=Númer opins innkaupareiknings. Sendu þetta eða systemId.';
        SystemIdLbl: Label 'systemId of the open purchase invoice. Send this or documentNo.', Comment = 'is-IS=systemId opins innkaupareiknings. Sendu þetta eða documentNo.';
        ReceiptNosLbl: Label 'No. of each posted purchase receipt to take lines from. Every receipt must belong to the pay-to vendor and currency of the invoice. Send this or allReceipts.', Comment = 'is-IS=Númer hverrar bókaðrar innkaupamóttöku sem línur eru teknar úr. Hver móttaka verður að tilheyra greiðslulánardrottni og gjaldmiðli reikningsins. Sendu þetta eða allReceipts.';
        AllReceiptsLbl: Label 'true to take every posted, not invoiced receipt line of the pay-to vendor of the invoice in its currency. Send this or receiptNos.', Comment = 'is-IS=true til að taka allar bókaðar, óreikningsfærðar móttökulínur greiðslulánardrottins reikningsins í gjaldmiðli hans. Sendu þetta eða receiptNos.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('receiptNos', 'array', false, ReceiptNosLbl));
        Parameters.Add(ContractMgt.Parameter('allReceipts', 'boolean', false, AllReceiptsLbl));
        exit(true);
    end;

    /// <summary>Implements GetResponse for purchase receipt invoice lines.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        AddedField: JsonObject;
        AddedChildren: JsonArray;
        SkippedField: JsonObject;
        SkippedChildren: JsonArray;
    begin
        AddedChildren.Add(ContractMgt.ResponseField('lineNo', 'integer', 'The line number of the new invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('type', 'string', 'The line type, for example Item, Resource, G/L Account or blank for the receipt heading text line.'));
        AddedChildren.Add(ContractMgt.ResponseField('no', 'string', 'The No. on the invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('description', 'string', 'The description of the invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity on the invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('receiptNo', 'string', 'The posted receipt the line came from.'));
        AddedChildren.Add(ContractMgt.ResponseField('receiptLineNo', 'integer', 'The line number on that receipt, 0 for the heading text line.'));
        AddedField := ContractMgt.ResponseField('addedLines', 'array', 'The invoice lines this call added, in line order.');
        AddedField.Add('children', AddedChildren);
        SkippedChildren.Add(ContractMgt.ResponseField('receiptNo', 'string', 'The posted receipt.'));
        SkippedChildren.Add(ContractMgt.ResponseField('receiptLineNo', 'integer', 'The line number on that receipt.'));
        SkippedChildren.Add(ContractMgt.ResponseField('reason', 'string', 'invoiced when the line has no quantity left to invoice; onOpenInvoice when it is already on an open purchase invoice.'));
        SkippedChildren.Add(ContractMgt.ResponseField('invoiceNo', 'string', 'For onOpenInvoice, the open purchase invoice that already holds the line.'));
        SkippedField := ContractMgt.ResponseField('skippedLines', 'array', 'The receipt lines that were not added.');
        SkippedField.Add('children', SkippedChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the purchase invoice.'));
        Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The system id of the purchase invoice.'));
        Fields.Add(ContractMgt.ResponseField('addedCount', 'integer', 'The number of invoice lines added, heading text lines included.'));
        Fields.Add(AddedField);
        Fields.Add(ContractMgt.ResponseField('skippedCount', 'integer', 'The number of receipt lines skipped.'));
        Fields.Add(SkippedField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Implements GetErrors for purchase receipt invoice lines.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'Neither documentNo nor systemId was sent, or neither receiptNos nor allReceipts was sent.', Comment = 'is-IS=Hvorki documentNo né systemId var sent, eða hvorki receiptNos né allReceipts var sent.';
        MissingFixLbl: Label 'Send documentNo or systemId, and receiptNos or allReceipts.', Comment = 'is-IS=Sendu documentNo eða systemId, og receiptNos eða allReceipts.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, systemId is not a GUID, receiptNos is empty, or a document number is blank or exceeds 20 characters.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, systemId er ekki GUID, receiptNos er tómt eða skjalnúmer er autt eða lengra en 20 stafir.';
        FormatFixLbl: Label 'Send non-empty document numbers of at most 20 characters, systemId as a GUID, receiptNos as a non-empty array of document numbers and allReceipts as true.', Comment = 'is-IS=Sendu skjalnúmer sem eru ekki auð og eru mest 20 stafir, systemId sem GUID, receiptNos sem fylki skjalnúmera sem er ekki tómt og allReceipts sem true.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentNo, systemId, receiptNos and allReceipts.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentNo, systemId, receiptNos og allReceipts.';
        NotFoundWhenLbl: Label 'No purchase invoice has this No. or systemId, or a receipt in receiptNos does not exist.', Comment = 'is-IS=Enginn innkaupareikningur hefur þetta númer eða systemId, eða móttaka í receiptNos er ekki til.';
        NotFoundFixLbl: Label 'Check documentNo or systemId, and each No. in receiptNos.', Comment = 'is-IS=Athugaðu documentNo eða systemId, og hvert númer í receiptNos.';
        ConflictWhenLbl: Label 'documentNo and systemId were both sent, or receiptNos and allReceipts were both sent.', Comment = 'is-IS=documentNo og systemId voru bæði send, eða receiptNos og allReceipts voru bæði send.';
        ConflictFixLbl: Label 'Send one of documentNo or systemId, and one of receiptNos or allReceipts.', Comment = 'is-IS=Sendu annaðhvort documentNo eða systemId, og annaðhvort receiptNos eða allReceipts.';
        NotOpenWhenLbl: Label 'The purchase invoice is released or pending approval.', Comment = 'is-IS=Innkaupareikningurinn er útgefinn eða bíður samþykkis.';
        NotOpenFixLbl: Label 'Reopen the invoice with Purchase.Document.Reopen, then send the request again.', Comment = 'is-IS=Opnaðu reikninginn aftur með Purchase.Document.Reopen og sendu beiðnina síðan aftur.';
        InvalidLineWhenLbl: Label 'A receipt in receiptNos belongs to another pay-to vendor or another currency than the invoice.', Comment = 'is-IS=Móttaka í receiptNos tilheyrir öðrum greiðslulánardrottni eða öðrum gjaldmiðli en reikningurinn.';
        InvalidLineFixLbl: Label 'Send only receipts of the pay-to vendor and currency of the invoice, or create a separate invoice for the other vendor.', Comment = 'is-IS=Sendu aðeins móttökur greiðslulánardrottins og gjaldmiðils reikningsins, eða stofnaðu sérstakan reikning fyrir hinn lánardrottininn.';
        ValueWhenLbl: Label 'allReceipts is false.', Comment = 'is-IS=allReceipts er false.';
        ValueFixLbl: Label 'Send allReceipts as true, or send receiptNos instead.', Comment = 'is-IS=Sendu allReceipts sem true, eða sendu receiptNos í staðinn.';
        PermissionWhenLbl: Label 'The caller cannot change purchase lines or read posted purchase receipts.', Comment = 'is-IS=Kallandinn getur ekki breytt innkaupalínum eða lesið bókaðar innkaupamóttöku.';
        PermissionFixLbl: Label 'Assign the Bifrost "Full Access" permission set and a Business Central permission set that can change purchase invoices and read posted receipts.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst og Business Central heimildasafni sem getur breytt innkaupareikningum og lesið bókaðar móttökur.';
        BusinessCentralWhenLbl: Label 'Business Central refused to add a line, for example because the VAT business posting group of the receipt differs from the invoice.', Comment = 'is-IS=Business Central hafnaði því að bæta línu við, til dæmis af því að VSK-viðskiptabókunarflokkur móttökunnar er annar en reikningsins.';
        BusinessCentralFixLbl: Label 'Read the error text, correct the invoice or the receipt in Business Central, and send the request again. Nothing was added.', Comment = 'is-IS=Lestu villutextann, lagaðu reikninginn eða móttökuna í Business Central og sendu beiðnina aftur. Engu var bætt við.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotOpenWhenLbl, NotOpenFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, InvalidLineWhenLbl, InvalidLineFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ValueWhenLbl, ValueFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, BusinessCentralWhenLbl, BusinessCentralFixLbl));
        exit(true);
    end;

    /// <summary>Implements GetEffect for purchase receipt invoice lines.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ChangesLbl: Label 'Adds invoice lines to the open purchase invoice from posted, not invoiced receipt lines, with a heading text line per receipt, as the Get Receipt Lines action does. Nothing is posted; the added lines can be deleted from the open invoice. Lines already on an open purchase invoice are skipped, so sending the same request again adds nothing. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.', Comment = 'is-IS=Bætir reikningslínum við opna innkaupareikninginn úr bókuðum, óreikningsfærðum móttökulínum, með fyrirsagnarlínu fyrir hverja móttöku, eins og aðgerðin Sækja móttökulínur gerir. Ekkert er bókað; hægt er að eyða línunum sem bættust við af opna reikningnum. Línum sem eru þegar á opnum innkaupareikningi er sleppt, svo sama beiðni send aftur bætir engu við. Höfnun vistar ekkert. Keðjuð Omit Commit köll haldast í færslu kallandans; stök köll nota einangraða skrift.';
    begin
        Preconditions.Add('The document is an open purchase invoice (status Open).');
        Preconditions.Add('Every receipt in receiptNos has the pay-to vendor and currency of the invoice.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', WritePermissionSetTok);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Implements GetMetering for purchase receipt invoice lines.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Implements GetRelated for purchase receipt invoice lines.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CreateLbl: Label 'Create the empty purchase invoice for the pay-to vendor first.', Comment = 'is-IS=Stofnaðu fyrst tóman innkaupareikning fyrir greiðslulánardrottninn.';
        PostLbl: Label 'Post the invoice once the lines are in; this type does not post.', Comment = 'is-IS=Bókaðu reikninginn þegar línurnar eru komnar inn; þessi tegund bókar ekki.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Purchase.Document.Create', CreateLbl));
        Related.Add(ContractMgt.RelatedEntry('Purchase.Document.Post', PostLbl));
        exit(true);
    end;

    /// <summary>Implements GetWorkflow for purchase receipt invoice lines.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Purchase.Document.Create', 'Create an empty purchase invoice for the pay-to vendor.'));
        Steps.Add(ContractMgt.WorkflowStep('Purchase.PurchaseInvoice.GetReceiptLines', 'Pull the posted, not invoiced receipt lines into the invoice.'));
        Steps.Add(ContractMgt.WorkflowStep('Purchase.Document.Post', 'Post the invoice so the receipts are invoiced.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Implements GetExamples for purchase receipt invoice lines.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ReceiptsTitleLbl: Label 'Invoice two posted receipts on one purchase invoice', Comment = 'is-IS=Reikningsfæra tvær bókaðar móttökur á einum innkaupareikningi';
        AllTitleLbl: Label 'Invoice every not invoiced receipt of the vendor', Comment = 'is-IS=Reikningsfæra allar óreikningsfærðar móttökur lánardrottinsins';
    begin
        Examples.Add(ContractMgt.Example(ReceiptsTitleLbl, '{"type":"Purchase.PurchaseInvoice.GetReceiptLines","data":{"documentNo":"103001","receiptNos":["102043","102044"]}}', '{"status":"Success","documentNo":"103001","systemId":"6c1a7a6e-0000-0000-0000-000000000001","addedCount":4,"addedLines":[{"lineNo":10000,"type":"","no":"","description":"Receipt No. 102043:","quantity":0,"receiptNo":"","receiptLineNo":0},{"lineNo":20000,"type":"Item","no":"1896-S","description":"ATHENS Desk","quantity":2,"receiptNo":"102043","receiptLineNo":10000},{"lineNo":30000,"type":"","no":"","description":"Receipt No. 102044:","quantity":0,"receiptNo":"","receiptLineNo":0},{"lineNo":40000,"type":"Item","no":"1900-S","description":"PARIS Guest Chair, black","quantity":1,"receiptNo":"102044","receiptLineNo":10000}],"skippedCount":1,"skippedLines":[{"receiptNo":"102044","receiptLineNo":20000,"reason":"invoiced","invoiceNo":""}]}'));
        Examples.Add(ContractMgt.Example(AllTitleLbl, '{"type":"Purchase.PurchaseInvoice.GetReceiptLines","data":{"documentNo":"103002","allReceipts":true}}', '{"status":"Success","documentNo":"103002","systemId":"6c1a7a6e-0000-0000-0000-000000000002","addedCount":0,"addedLines":[],"skippedCount":0,"skippedLines":[]}'));
        exit(true);
    end;

    /// <summary>Implements GetOverview for purchase receipt invoice lines.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Pulls posted, not invoiced purchase receipt lines into an open purchase invoice, as the Get Receipt Lines action on the purchase invoice does, so several receipts of one vendor are invoiced together. Send receiptNos to name the receipts, or allReceipts to take every not invoiced receipt line of the pay-to vendor of the invoice in its currency. The answer lists the invoice lines added and the receipt lines skipped because they are already invoiced or already on an open purchase invoice.', Comment = 'is-IS=Sækir bókaðar, óreikningsfærðar móttökulínur innkaupa inn á opinn innkaupareikning, eins og aðgerðin Sækja móttökulínur á innkaupareikningnum gerir, svo nokkrar móttökur eins lánardrottins séu reikningsfærðar saman. Sendu receiptNos til að tilgreina móttökurnar, eða allReceipts til að taka allar óreikningsfærðar móttökulínur greiðslulánardrottins reikningsins í gjaldmiðli hans. Svarið telur upp reikningslínurnar sem bættust við og móttökulínurnar sem var sleppt af því að þær eru þegar reikningsfærðar eða þegar á opnum innkaupareikningi.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Implements GetNotes for purchase receipt invoice lines.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A receipt of another pay-to vendor or another currency is refused with InvalidLine and nothing is added. With allReceipts, only receipt lines of the pay-to vendor and currency of the invoice are read, and skippedLines lists only lines that are already on an open purchase invoice. Business Central adds a heading text line for each receipt and copies item charge assignments, prices and discounts from the order, exactly as the native action does. A native refusal, such as a VAT business posting group that differs from the invoice, rolls the whole call back. The invoice is not posted; post it with Purchase.Document.Post.', Comment = 'is-IS=Móttöku annars greiðslulánardrottins eða annars gjaldmiðils er hafnað með InvalidLine og engu er bætt við. Með allReceipts eru aðeins lesnar móttökulínur greiðslulánardrottins og gjaldmiðils reikningsins, og skippedLines telur aðeins upp línur sem eru þegar á opnum innkaupareikningi. Business Central bætir við fyrirsagnarlínu fyrir hverja móttöku og afritar úthlutanir kostnaðarauka, verð og afslætti úr pöntuninni, nákvæmlega eins og innbyggða aðgerðin gerir. Innbyggð höfnun, til dæmis VSK-viðskiptabókunarflokkur sem er annar en reikningsins, afturkallar allt kallið. Reikningurinn er ekki bókaður; bókaðu hann með Purchase.Document.Post.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Implements GetMessageDirection for purchase receipt invoice lines.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Implements ExecuteBifrostTask for purchase receipt invoice lines.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateShape(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Purch Get Receipt Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Purch Get Receipt Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    /// <summary>
    /// Adds the receipt lines the request names to the invoice and sets the response. Runs inside
    /// Purch Get Receipt Proc ori after ExecuteBifrostTask has refused bad requests, so an error rolls the whole write back.
    /// </summary>
    /// <param name="Argument">The message argument with the validated request.</param>
    /// <summary>Implements RunGetReceiptLines for purchase receipt invoice lines.</summary>
    procedure RunGetReceiptLines(var Argument: Record "Message Argument ori")
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TempRcptHeader: Record "Purch. Rcpt. Header" temporary;
        PurchGetReceipt: Codeunit "Purch.-Get Receipt";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AddedLines: JsonArray;
        SkippedLines: JsonArray;
        LastLineNo: Integer;
        CandidateCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        // Serialize calls for this invoice and validate again within the write transaction.
        PurchHeader.LockTable();
        if not ResolveInvoice(Argument, RequestJson, PurchHeader) then
            exit;
        if RequestJson.Contains(ReceiptNosKeyTok) then
            if not ResolveReceipts(Argument, RequestJson, PurchHeader, TempRcptHeader) then
                exit;
        PurchLine.ReadIsolation := IsolationLevel::ReadCommitted;
        PurchLine.SetRange("Document Type", PurchHeader."Document Type");
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        if PurchLine.FindLast() then
            LastLineNo := PurchLine."Line No.";
        CandidateCount := MarkCandidates(PurchHeader, TempRcptHeader, RequestJson.Contains(ReceiptNosKeyTok), PurchRcptLine, SkippedLines);
        if CandidateCount > 0 then begin
            PurchRcptLine.MarkedOnly(true);
            PurchGetReceipt.SetPurchHeader(PurchHeader);
            PurchGetReceipt.CreateInvLines(PurchRcptLine);
        end;
        PurchLine.SetFilter("Line No.", '>%1', LastLineNo);
        if PurchLine.FindSet() then
            repeat
                AddedLines.Add(AddedLineJson(PurchLine));
            until PurchLine.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', PurchHeader."No.");
        ResponseJson.Add('systemId', Format(PurchHeader.SystemId, 0, 4).ToLower());
        ResponseJson.Add('addedCount', AddedLines.Count());
        ResponseJson.Add('addedLines', AddedLines);
        ResponseJson.Add('skippedCount', SkippedLines.Count());
        ResponseJson.Add('skippedLines', SkippedLines);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure MarkCandidates(
        PurchHeader: Record "Purchase Header";
        var TempRcptHeader: Record "Purch. Rcpt. Header" temporary;
        ByReceipt: Boolean;
        var PurchRcptLine: Record "Purch. Rcpt. Line";
        var SkippedLines: JsonArray) CandidateCount: Integer
    begin
        PurchRcptLine.Reset();
        PurchRcptLine.ReadIsolation := IsolationLevel::ReadCommitted;
        if ByReceipt then begin
            if not TempRcptHeader.FindSet() then
                exit(0);
            repeat
                PurchRcptLine.SetRange("Document No.", TempRcptHeader."No.");
                PurchRcptLine.SetFilter(Type, '<>%1', PurchRcptLine.Type::" ");
                if PurchRcptLine.FindSet() then
                    repeat
                        CandidateCount += MarkOne(PurchRcptLine, SkippedLines, true);
                    until PurchRcptLine.Next() = 0;
            until TempRcptHeader.Next() = 0;
            // Clear the filters one by one: Reset would also drop the marks CreateInvLines reads.
            PurchRcptLine.SetRange("Document No.");
            PurchRcptLine.SetRange(Type);
            exit(CandidateCount);
        end;
        PurchRcptLine.SetCurrentKey("Pay-to Vendor No.");
        PurchRcptLine.SetRange("Pay-to Vendor No.", PurchHeader."Pay-to Vendor No.");
        PurchRcptLine.SetRange("Currency Code", PurchHeader."Currency Code");
        PurchRcptLine.SetFilter("Qty. Rcd. Not Invoiced", '<>0');
        if PurchRcptLine.FindSet() then
            repeat
                CandidateCount += MarkOne(PurchRcptLine, SkippedLines, false);
            until PurchRcptLine.Next() = 0;
        PurchRcptLine.SetRange("Pay-to Vendor No.");
        PurchRcptLine.SetRange("Currency Code");
        PurchRcptLine.SetRange("Qty. Rcd. Not Invoiced");
    end;

    local procedure MarkOne(
        var PurchRcptLine: Record "Purch. Rcpt. Line";
        var SkippedLines: JsonArray;
        ListInvoiced: Boolean): Integer
    var
        InvoiceNo: Code[20];
    begin
        if PurchRcptLine."Qty. Rcd. Not Invoiced" = 0 then begin
            if ListInvoiced then
                SkippedLines.Add(SkippedLineJson(PurchRcptLine, InvoicedReasonTok, ''));
            exit(0);
        end;
        InvoiceNo := OpenInvoiceHoldingLine(PurchRcptLine);
        if InvoiceNo <> '' then begin
            SkippedLines.Add(SkippedLineJson(PurchRcptLine, OnOpenInvoiceReasonTok, InvoiceNo));
            exit(0);
        end;
        PurchRcptLine.Mark(true);
        exit(1);
    end;

    local procedure OpenInvoiceHoldingLine(PurchRcptLine: Record "Purch. Rcpt. Line"): Code[20]
    var
        PurchLine: Record "Purchase Line";
    begin
        PurchLine.ReadIsolation := IsolationLevel::ReadCommitted;
        PurchLine.SetRange("Document Type", PurchLine."Document Type"::Invoice);
        PurchLine.SetRange("Receipt No.", PurchRcptLine."Document No.");
        PurchLine.SetRange("Receipt Line No.", PurchRcptLine."Line No.");
        if PurchLine.FindFirst() then
            exit(PurchLine."Document No.");
        exit('');
    end;

    local procedure AddedLineJson(PurchLine: Record "Purchase Line") Line: JsonObject
    begin
        Line.Add('lineNo', PurchLine."Line No.");
        Line.Add('type', PurchLine.Type.Names().Get(PurchLine.Type.Ordinals().IndexOf(PurchLine.Type.AsInteger())));
        Line.Add('no', PurchLine."No.");
        Line.Add('description', PurchLine.Description);
        Line.Add('quantity', PurchLine.Quantity);
        Line.Add('receiptNo', PurchLine."Receipt No.");
        Line.Add('receiptLineNo', PurchLine."Receipt Line No.");
    end;

    local procedure SkippedLineJson(
        PurchRcptLine: Record "Purch. Rcpt. Line";
        Reason: Text;
        InvoiceNo: Code[20]) Line: JsonObject
    begin
        Line.Add('receiptNo', PurchRcptLine."Document No.");
        Line.Add('receiptLineNo', PurchRcptLine."Line No.");
        Line.Add('reason', Reason);
        Line.Add('invoiceNo', InvoiceNo);
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        PermissionDeniedErr: Label 'Permission denied for Purchase.PurchaseInvoice.GetReceiptLines.', Comment = 'is-IS=Heimild hafnað fyrir Purchase.PurchaseInvoice.GetReceiptLines.';
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set and a Business Central permission set that can change purchase invoices and read posted receipts.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst og Business Central heimildasafni sem getur breytt innkaupareikningum og lesið bókaðar móttökur.';
    begin
        if IsEnabled() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', WritePermissionSetTok, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure RejectUnknownKeys(
        var Argument: Record "Message Argument ori";
        RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentNo, systemId, receiptNos and allReceipts.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentNo, systemId, receiptNos og allReceipts.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentNoKeyTok, SystemIdKeyTok, ReceiptNosKeyTok, AllReceiptsKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateShape(
        var Argument: Record "Message Argument ori";
        RequestJson: JsonObject): Boolean
    var
        Token: JsonToken;
        ItemToken: JsonToken;
        SystemId: Guid;
        MissingInvoiceErr: Label 'documentNo or systemId is required.', Comment = 'is-IS=documentNo eða systemId er nauðsynlegt.';
        MissingInvoiceNextLbl: Label 'Send the No. or the systemId of the open purchase invoice.', Comment = 'is-IS=Sendu númer eða systemId opna innkaupareikningsins.';
        MissingSourceErr: Label 'receiptNos or allReceipts is required.', Comment = 'is-IS=receiptNos eða allReceipts er nauðsynlegt.';
        MissingSourceNextLbl: Label 'Send receiptNos with the posted receipts to invoice, or allReceipts as true.', Comment = 'is-IS=Sendu receiptNos með bókuðu móttökunum sem á að reikningsfæra, eða allReceipts sem true.';
        BothInvoiceErr: Label 'Send documentNo or systemId, not both.', Comment = 'is-IS=Sendu documentNo eða systemId, ekki bæði.';
        BothSourceErr: Label 'Send receiptNos or allReceipts, not both.', Comment = 'is-IS=Sendu receiptNos eða allReceipts, ekki bæði.';
        BothNextLbl: Label 'Remove one of the two keys and send the request again.', Comment = 'is-IS=Fjarlægðu annan lykilinn og sendu beiðnina aftur.';
        FormatErr: Label '%1 has the wrong format.', Comment = '%1 = request key, is-IS=%1 er á röngu sniði.';
        FormatNextLbl: Label 'Send %1 as %2.', Comment = '%1 = request key, %2 = expected format, is-IS=Sendu %1 sem %2.';
        FalseErr: Label 'allReceipts must be true when it is sent.', Comment = 'is-IS=allReceipts verður að vera true þegar það er sent.';
        FalseNextLbl: Label 'Send allReceipts as true, or send receiptNos instead.', Comment = 'is-IS=Sendu allReceipts sem true, eða sendu receiptNos í staðinn.';
    begin
        if not (RequestJson.Contains(DocumentNoKeyTok) or RequestJson.Contains(SystemIdKeyTok)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingInvoiceErr, DocumentNoKeyTok, '', DocumentNoKeyTok, MissingInvoiceNextLbl);
            exit(false);
        end;
        if RequestJson.Contains(DocumentNoKeyTok) and RequestJson.Contains(SystemIdKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, BothInvoiceErr, SystemIdKeyTok, '', DocumentNoKeyTok, BothNextLbl);
            exit(false);
        end;
        if not (RequestJson.Contains(ReceiptNosKeyTok) or RequestJson.Contains(AllReceiptsKeyTok)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingSourceErr, ReceiptNosKeyTok, '', ReceiptNosKeyTok, MissingSourceNextLbl);
            exit(false);
        end;
        if RequestJson.Contains(ReceiptNosKeyTok) and RequestJson.Contains(AllReceiptsKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, BothSourceErr, AllReceiptsKeyTok, '', ReceiptNosKeyTok, BothNextLbl);
            exit(false);
        end;
        if RequestJson.Get('documentNo', Token) then
            if not IsDocumentNoToken(Token) then
                exit(RespondFormat(Argument, DocumentNoKeyTok, TextExpectedLbl, FormatErr, FormatNextLbl));
        if RequestJson.Get('systemId', Token) then begin
            if not IsTextToken(Token) then
                exit(RespondFormat(Argument, SystemIdKeyTok, GuidExpectedTok, FormatErr, FormatNextLbl));
            if not Evaluate(SystemId, Token.AsValue().AsText()) then
                exit(RespondFormat(Argument, SystemIdKeyTok, GuidExpectedTok, FormatErr, FormatNextLbl));
        end;
        if RequestJson.Get('receiptNos', Token) then begin
            if not Token.IsArray() then
                exit(RespondFormat(Argument, ReceiptNosKeyTok, ArrayExpectedTok, FormatErr, FormatNextLbl));
            if Token.AsArray().Count() = 0 then
                exit(RespondFormat(Argument, ReceiptNosKeyTok, ArrayExpectedTok, FormatErr, FormatNextLbl));
            foreach ItemToken in Token.AsArray() do
                if not IsDocumentNoToken(ItemToken) then
                    exit(RespondFormat(Argument, ReceiptNosKeyTok, TextExpectedLbl, FormatErr, FormatNextLbl));
        end;
        if RequestJson.Get('allReceipts', Token) then begin
            if not Token.IsValue() then
                exit(RespondFormat(Argument, AllReceiptsKeyTok, BooleanExpectedTok, FormatErr, FormatNextLbl));
            if Token.AsValue().IsNull() then
                exit(RespondFormat(Argument, AllReceiptsKeyTok, BooleanExpectedTok, FormatErr, FormatNextLbl));
            if not IsBooleanToken(Token) then
                exit(RespondFormat(Argument, AllReceiptsKeyTok, BooleanExpectedTok, FormatErr, FormatNextLbl));
            if not Token.AsValue().AsBoolean() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, FalseErr, AllReceiptsKeyTok, FalseTok, TrueExpectedTok, FalseNextLbl);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure RespondFormat(
        var Argument: Record "Message Argument ori";
        KeyName: Text;
        Expected: Text;
        FormatErr: Text;
        FormatNextLbl: Text): Boolean
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

    local procedure IsDocumentNoToken(Token: JsonToken): Boolean
    begin
        if not IsTextToken(Token) then
            exit(false);
        exit((Token.AsValue().AsText().Trim() <> '') and (StrLen(Token.AsValue().AsText()) <= 20));
    end;

    local procedure IsBooleanToken(Token: JsonToken): Boolean
    var
        TextValue: Text;
    begin
        Token.WriteTo(TextValue);
        exit(TextValue in ['true', 'false']);
    end;

    local procedure ResolveInvoice(
        var Argument: Record "Message Argument ori";
        RequestJson: JsonObject;
        var PurchHeader: Record "Purchase Header"): Boolean
    var
        NotFoundErr: Label 'No purchase invoice %1 was found.', Comment = '%1 = document no. or system id, is-IS=Innkaupareikningur %1 fannst ekki.';
        NotFoundNextLbl: Label 'Check documentNo or systemId; this type takes an open purchase invoice, not an order or a posted invoice.', Comment = 'is-IS=Athugaðu documentNo eða systemId; þessi tegund tekur opinn innkaupareikning, ekki pöntun eða bókaðan reikning.';
        NotOpenErr: Label 'Purchase invoice %1 is not open; its status is %2.', Comment = '%1 = invoice no., %2 = status, is-IS=Innkaupareikningur %1 er ekki opinn; staða hans er %2.';
        NotOpenNextLbl: Label 'Reopen the invoice with Purchase.Document.Reopen, then send the request again.', Comment = 'is-IS=Opnaðu reikninginn aftur með Purchase.Document.Reopen og sendu beiðnina síðan aftur.';
        Identifier: Text;
        KeyName: Text;
    begin
        if not LocateInvoice(RequestJson, PurchHeader) then begin
            KeyName := DocumentNoKeyTok;
            if RequestJson.Contains(SystemIdKeyTok) then
                KeyName := SystemIdKeyTok;
            Identifier := ReadText(RequestJson, KeyName);
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, Identifier), CopyStr(KeyName, 1, 250), CopyStr(Identifier, 1, 250), OpenInvoiceExpectedTok, NotFoundNextLbl);
            exit(false);
        end;
        if PurchHeader.Status <> PurchHeader.Status::Open then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotOpenErr, PurchHeader."No.", PurchHeader.Status.Names().Get(PurchHeader.Status.Ordinals().IndexOf(PurchHeader.Status.AsInteger()))), StatusKeyTok, CopyStr(PurchHeader.Status.Names().Get(PurchHeader.Status.Ordinals().IndexOf(PurchHeader.Status.AsInteger())), 1, 250), 'Open', NotOpenNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure LocateInvoice(
        RequestJson: JsonObject;
        var PurchHeader: Record "Purchase Header"): Boolean
    var
        SystemId: Guid;
    begin
        if RequestJson.Contains(SystemIdKeyTok) then begin
            if not Evaluate(SystemId, ReadText(RequestJson, SystemIdKeyTok)) then
                exit(false);
            if not PurchHeader.GetBySystemId(SystemId) then
                exit(false);
            exit(PurchHeader."Document Type" = PurchHeader."Document Type"::Invoice);
        end;
        exit(PurchHeader.Get(PurchHeader."Document Type"::Invoice, CopyStr(ReadText(RequestJson, DocumentNoKeyTok), 1, MaxStrLen(PurchHeader."No."))));
    end;

    local procedure ResolveReceipts(
        var Argument: Record "Message Argument ori";
        RequestJson: JsonObject;
        PurchHeader: Record "Purchase Header";
        var TempRcptHeader: Record "Purch. Rcpt. Header" temporary): Boolean
    var
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        NotFoundErr: Label 'Posted purchase receipt %1 was not found.', Comment = '%1 = receipt no., is-IS=Bókuð innkaupamóttaka %1 fannst ekki.';
        NotFoundNextLbl: Label 'Check the No. in receiptNos, or send allReceipts as true to take every not invoiced receipt of the vendor.', Comment = 'is-IS=Athugaðu númerið í receiptNos, eða sendu allReceipts sem true til að taka allar óreikningsfærðar móttökur lánardrottinsins.';
        OtherVendorErr: Label 'Receipt %1 belongs to pay-to vendor %2, not to %3 on invoice %4.', Comment = '%1 = receipt no., %2 = receipt pay-to vendor, %3 = invoice pay-to vendor, %4 = invoice no., is-IS=Móttaka %1 tilheyrir greiðslulánardrottni %2, ekki %3 á reikningi %4.';
        OtherCurrencyErr: Label 'Receipt %1 is in currency "%2", not "%3" like invoice %4.', Comment = '%1 = receipt no., %2 = receipt currency, %3 = invoice currency, %4 = invoice no., is-IS=Móttaka %1 er í gjaldmiðlinum "%2", ekki "%3" eins og reikningur %4.';
        InvalidLineNextLbl: Label 'Send only receipts of the pay-to vendor and currency of the invoice, or create a separate invoice for the other receipts. Nothing was added.', Comment = 'is-IS=Sendu aðeins móttökur greiðslulánardrottins og gjaldmiðils reikningsins, eða stofnaðu sérstakan reikning fyrir hinar móttökurnar. Engu var bætt við.';
    begin
        PurchRcptHeader.ReadIsolation := IsolationLevel::ReadCommitted;
        CollectReceipts(RequestJson, TempRcptHeader);
        if TempRcptHeader.FindSet() then
            repeat
                if not PurchRcptHeader.Get(TempRcptHeader."No.") then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, TempRcptHeader."No."), ReceiptNosKeyTok, TempRcptHeader."No.", PostedReceiptExpectedTok, NotFoundNextLbl);
                    exit(false);
                end;
                if PurchRcptHeader."Pay-to Vendor No." <> PurchHeader."Pay-to Vendor No." then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OtherVendorErr, PurchRcptHeader."No.", PurchRcptHeader."Pay-to Vendor No.", PurchHeader."Pay-to Vendor No.", PurchHeader."No."), ReceiptNosKeyTok, PurchRcptHeader."Pay-to Vendor No.", PurchHeader."Pay-to Vendor No.", InvalidLineNextLbl);
                    exit(false);
                end;
                if PurchRcptHeader."Currency Code" <> PurchHeader."Currency Code" then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OtherCurrencyErr, PurchRcptHeader."No.", PurchRcptHeader."Currency Code", PurchHeader."Currency Code", PurchHeader."No."), ReceiptNosKeyTok, PurchRcptHeader."Currency Code", PurchHeader."Currency Code", InvalidLineNextLbl);
                    exit(false);
                end;
            until TempRcptHeader.Next() = 0;
        exit(true);
    end;

    local procedure CollectReceipts(
        RequestJson: JsonObject;
        var TempRcptHeader: Record "Purch. Rcpt. Header" temporary)
    var
        Token: JsonToken;
        ItemToken: JsonToken;
        ReceiptNo: Code[20];
    begin
        TempRcptHeader.Reset();
        TempRcptHeader.DeleteAll();
        if not RequestJson.Get('receiptNos', Token) then
            exit;
        foreach ItemToken in Token.AsArray() do begin
            ReceiptNo := CopyStr(ItemToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
            if not TempRcptHeader.Get(ReceiptNo) then begin
                TempRcptHeader.Init();
                TempRcptHeader."No." := ReceiptNo;
                TempRcptHeader.Insert();
            end;
        end;
    end;

    local procedure ReadText(
        RequestJson: JsonObject;
        KeyName: Text): Text
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
