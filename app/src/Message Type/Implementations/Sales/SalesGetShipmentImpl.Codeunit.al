namespace Origo.Bifrost.Inventory;

using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>
/// Sales.SalesInvoice.GetShipmentLines. Pulls posted, not invoiced sales shipment lines into an open sales invoice,
/// the way the Get Shipment Lines action on the sales invoice subform does (codeunit 64 Sales-Get Shipment).
/// The write runs in Sales Get Shipment Proc ori so a failure rolls back and answers a clean error.
/// </summary>
codeunit 10077020 "Sales Get Shipment Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        ShipmentNosKeyTok: Label 'shipmentNos', Locked = true;
        AllShipmentsKeyTok: Label 'allShipments', Locked = true;
        AllowedKeysTok: Label 'documentNo, systemId, shipmentNos, allShipments', Locked = true;
        WritePermissionSetTok: Label 'BIFROST Full ori', Locked = true;
        InvoicedReasonTok: Label 'invoiced', Locked = true;
        OnOpenInvoiceReasonTok: Label 'onOpenInvoice', Locked = true;
        DocumentNoExpectedTok: Label 'text (1..20)', Locked = true;
        GuidExpectedTok: Label 'guid', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        OpenInvoiceExpectedTok: Label 'openSalesInvoice', Locked = true;
        TrueExpectedTok: Label 'true', Locked = true;
        FalseTok: Label 'false', Locked = true;
        StatusKeyTok: Label 'status', Locked = true;
        PostedShipmentExpectedTok: Label 'postedSalesShipment', Locked = true;

    /// <summary>Checks sales line write and posted shipment read permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        SalesLine: Record "Sales Line";
        SalesShptLine: Record "Sales Shipment Line";
    begin
        exit(SalesLine.WritePermission() and SalesShptLine.ReadPermission());
    end;

    /// <summary>Returns the posted sales shipment line table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Sales Shipment Line");
    end;

    /// <summary>Returns the localized catalogue description.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Pulls posted, not invoiced sales shipment lines into an open sales invoice.', Comment = 'is-IS=Sækir bókaðar, óreikningsfærðar afhendingarlínur sölu inn á opinn sölureikning.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'get shipment lines, combined invoice, shipment, sales invoice, not invoiced', Comment = 'is-IS=sækja afhendingarlínur, samsettur reikningur, afhending, sölureikningur, óreikningsfært';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized guidance for choosing this operation.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Invoices several posted shipments of one customer on one sales invoice, as the Get Shipment Lines action does, and lists the lines it added and the lines it skipped.', Comment = 'is-IS=Reikningsfærir nokkrar bókaðar afhendingar eins viðskiptamanns á einum sölureikningi, eins og aðgerðin Sækja afhendingarlínur gerir, og telur upp línurnar sem bættust við og línurnar sem var sleppt.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope and invoice identifier location.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The sales invoice is named under data.documentNo or data.systemId; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the supported invoice identifiers.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentNoLbl: Label 'The No. of the open sales invoice that receives the lines.', Comment = 'is-IS=Númer opna sölureikningsins sem fær línurnar.';
        SystemIdLbl: Label 'The system id of that sales invoice, as an alternative to data.documentNo. Send one of them, not both.', Comment = 'is-IS=Kerfiskenni sölureikningsins, í stað data.documentNo. Sendu annað þeirra, ekki bæði.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', DocumentNoLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', SystemIdLbl));
        exit(true);
    end;

    /// <summary>Declares invoice selection and shipment filter parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentNoLbl: Label 'No. of the open sales invoice. Send this or systemId.', Comment = 'is-IS=Númer opins sölureiknings. Sendu þetta eða systemId.';
        SystemIdLbl: Label 'systemId of the open sales invoice. Send this or documentNo.', Comment = 'is-IS=systemId opins sölureiknings. Sendu þetta eða documentNo.';
        ShipmentNosLbl: Label 'No. of each posted sales shipment to take lines from. Every shipment must belong to the bill-to customer and currency of the invoice. Send this or allShipments.', Comment = 'is-IS=Númer hverrar bókaðrar söluafhendingar sem línur eru teknar úr. Hver afhending verður að tilheyra reikningsviðskiptamanni og gjaldmiðli reikningsins. Sendu þetta eða allShipments.';
        AllShipmentsLbl: Label 'true to take every posted, not invoiced shipment line of the bill-to customer of the invoice in its currency. Send this or shipmentNos.', Comment = 'is-IS=true til að taka allar bókaðar, óreikningsfærðar afhendingarlínur reikningsviðskiptamanns reikningsins í gjaldmiðli hans. Sendu þetta eða shipmentNos.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('shipmentNos', 'array', false, ShipmentNosLbl));
        Parameters.Add(ContractMgt.Parameter('allShipments', 'boolean', false, AllShipmentsLbl));
        exit(true);
    end;

    /// <summary>Describes added invoice lines and skipped shipment lines.</summary>
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
        AddedChildren.Add(ContractMgt.ResponseField('type', 'string', 'The line type, for example Item, Resource, G/L Account or blank for the shipment heading text line.'));
        AddedChildren.Add(ContractMgt.ResponseField('no', 'string', 'The No. on the invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('description', 'string', 'The description of the invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity on the invoice line.'));
        AddedChildren.Add(ContractMgt.ResponseField('shipmentNo', 'string', 'The posted shipment the line came from.'));
        AddedChildren.Add(ContractMgt.ResponseField('shipmentLineNo', 'integer', 'The line number on that shipment, 0 for the heading text line.'));
        AddedField := ContractMgt.ResponseField('addedLines', 'array', 'The invoice lines this call added, in line order.');
        AddedField.Add('children', AddedChildren);
        SkippedChildren.Add(ContractMgt.ResponseField('shipmentNo', 'string', 'The posted shipment.'));
        SkippedChildren.Add(ContractMgt.ResponseField('shipmentLineNo', 'integer', 'The line number on that shipment.'));
        SkippedChildren.Add(ContractMgt.ResponseField('reason', 'string', 'invoiced when the line has no quantity left to invoice; onOpenInvoice when it is already on an open sales invoice.'));
        SkippedChildren.Add(ContractMgt.ResponseField('invoiceNo', 'string', 'For onOpenInvoice, the open sales invoice that already holds the line.'));
        SkippedField := ContractMgt.ResponseField('skippedLines', 'array', 'The shipment lines that were not added.');
        SkippedField.Add('children', SkippedChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The No. of the sales invoice.'));
        Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The system id of the sales invoice.'));
        Fields.Add(ContractMgt.ResponseField('addedCount', 'integer', 'The number of invoice lines added, heading text lines included.'));
        Fields.Add(AddedField);
        Fields.Add(ContractMgt.ResponseField('skippedCount', 'integer', 'The number of shipment lines skipped.'));
        Fields.Add(SkippedField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares coded refusals and localized recovery guidance.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'Neither documentNo nor systemId was sent, or neither shipmentNos nor allShipments was sent.', Comment = 'is-IS=Hvorki documentNo né systemId var sent, eða hvorki shipmentNos né allShipments var sent.';
        MissingFixLbl: Label 'Send documentNo or systemId, and shipmentNos or allShipments.', Comment = 'is-IS=Sendu documentNo eða systemId, og shipmentNos eða allShipments.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, systemId is not a GUID, or a document/shipment number is blank, longer than 20 characters or not text.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, systemId er ekki GUID, eða skjals- eða afhendingarnúmer er tómt, lengra en 20 stafir eða ekki texti.';
        FormatFixLbl: Label 'Send documentNo and each shipmentNos entry as non-blank text of at most 20 characters, systemId as a GUID and allShipments as true.', Comment = 'is-IS=Sendu documentNo og hvert gildi í shipmentNos sem texta sem er ekki tómur og er að hámarki 20 stafir, systemId sem GUID og allShipments sem true.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentNo, systemId, shipmentNos and allShipments.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentNo, systemId, shipmentNos og allShipments.';
        NotFoundWhenLbl: Label 'No sales invoice has this No. or systemId, or a shipment in shipmentNos does not exist.', Comment = 'is-IS=Enginn sölureikningur hefur þetta númer eða systemId, eða afhending í shipmentNos er ekki til.';
        NotFoundFixLbl: Label 'Check documentNo or systemId, and each No. in shipmentNos.', Comment = 'is-IS=Athugaðu documentNo eða systemId, og hvert númer í shipmentNos.';
        ConflictWhenLbl: Label 'documentNo and systemId were both sent, or shipmentNos and allShipments were both sent.', Comment = 'is-IS=documentNo og systemId voru bæði send, eða shipmentNos og allShipments voru bæði send.';
        ConflictFixLbl: Label 'Send one of documentNo or systemId, and one of shipmentNos or allShipments.', Comment = 'is-IS=Sendu annaðhvort documentNo eða systemId, og annaðhvort shipmentNos eða allShipments.';
        NotOpenWhenLbl: Label 'The sales invoice is released or pending approval.', Comment = 'is-IS=Sölureikningurinn er útgefinn eða bíður samþykkis.';
        NotOpenFixLbl: Label 'Reopen the invoice with Sales.Document.Reopen, then send the request again.', Comment = 'is-IS=Opnaðu reikninginn aftur með Sales.Document.Reopen og sendu beiðnina síðan aftur.';
        InvalidLineWhenLbl: Label 'A shipment in shipmentNos belongs to another bill-to customer or another currency than the invoice.', Comment = 'is-IS=Afhending í shipmentNos tilheyrir öðrum reikningsviðskiptamanni eða öðrum gjaldmiðli en reikningurinn.';
        InvalidLineFixLbl: Label 'Send only shipments of the bill-to customer and currency of the invoice, or create a separate invoice for the other customer.', Comment = 'is-IS=Sendu aðeins afhendingar reikningsviðskiptamanns og gjaldmiðils reikningsins, eða stofnaðu sérstakan reikning fyrir hinn viðskiptamanninn.';
        ValueWhenLbl: Label 'allShipments is false.', Comment = 'is-IS=allShipments er false.';
        ValueFixLbl: Label 'Send allShipments as true, or send shipmentNos instead.', Comment = 'is-IS=Sendu allShipments sem true, eða sendu shipmentNos í staðinn.';
        PermissionWhenLbl: Label 'The caller cannot change sales lines or read posted sales shipments.', Comment = 'is-IS=Kallandinn getur ekki breytt sölulínum eða lesið bókaðar söluafhendingar.';
        PermissionFixLbl: Label 'Assign the Bifrost "Full Access" permission set and a Business Central permission set that can change sales invoices and read posted shipments.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst og Business Central heimildasafni sem getur breytt sölureikningum og lesið bókaðar afhendingar.';
        BusinessCentralWhenLbl: Label 'Business Central refused to add a line, for example because the VAT business posting group of the shipment differs from the invoice.', Comment = 'is-IS=Business Central hafnaði því að bæta línu við, til dæmis af því að VSK-viðskiptabókunarflokkur afhendingarinnar er annar en reikningsins.';
        BusinessCentralFixLbl: Label 'Read the error text, correct the invoice or the shipment in Business Central, and send the request again. Nothing was added.', Comment = 'is-IS=Lestu villutextann, lagaðu reikninginn eða afhendinguna í Business Central og sendu beiðnina aftur. Engu var bætt við.';
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

    /// <summary>Declares the reversible invoice write and repeat-call behavior.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ChangesLbl: Label 'Adds invoice lines to the open sales invoice from posted, not invoiced shipment lines, with a heading text line per shipment, as the Get Shipment Lines action does. Nothing is posted; the added lines can be deleted from the open invoice. Lines already on an open sales invoice are skipped, so sending the same request again adds nothing. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.', Comment = 'is-IS=Bætir reikningslínum við opna sölureikninginn úr bókuðum, óreikningsfærðum afhendingarlínum, með fyrirsagnarlínu fyrir hverja afhendingu, eins og aðgerðin Sækja afhendingarlínur gerir. Ekkert er bókað; hægt er að eyða línunum sem bættust við af opna reikningnum. Línum sem eru þegar á opnum sölureikningi er sleppt, svo sama beiðni send aftur bætir engu við. Höfnun vistar ekkert. Keðjuð Omit Commit köll haldast í færslu kallandans; stök köll nota einangraða skrift.';
    begin
        Preconditions.Add('The document is an open sales invoice (status Open).');
        Preconditions.Add('Every shipment in shipmentNos has the bill-to customer and currency of the invoice.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', WritePermissionSetTok);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Uses Foundation metering defaults.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Lists related sales document operations.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CreateLbl: Label 'Create the empty sales invoice for the bill-to customer first.', Comment = 'is-IS=Stofnaðu fyrst tóman sölureikning fyrir reikningsviðskiptamanninn.';
        PostLbl: Label 'Post the invoice once the lines are in; this type does not post.', Comment = 'is-IS=Bókaðu reikninginn þegar línurnar eru komnar inn; þessi tegund bókar ekki.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Sales.Document.Create', CreateLbl));
        Related.Add(ContractMgt.RelatedEntry('Sales.Document.Post', PostLbl));
        exit(true);
    end;

    /// <summary>Describes the create, import and invoice workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Sales.Document.Create', 'Create an empty sales invoice for the bill-to customer.'));
        Steps.Add(ContractMgt.WorkflowStep('Sales.SalesInvoice.GetShipmentLines', 'Pull the posted, not invoiced shipment lines into the invoice.'));
        Steps.Add(ContractMgt.WorkflowStep('Sales.Document.Post', 'Post the invoice so the shipments are invoiced.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Returns sample requests for named or all customer shipments.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShipmentsTitleLbl: Label 'Invoice two posted shipments on one sales invoice', Comment = 'is-IS=Reikningsfæra tvær bókaðar afhendingar á einum sölureikningi';
        AllTitleLbl: Label 'Invoice every not invoiced shipment of the customer', Comment = 'is-IS=Reikningsfæra allar óreikningsfærðar afhendingar viðskiptamannsins';
    begin
        Examples.Add(ContractMgt.Example(ShipmentsTitleLbl, '{"type":"Sales.SalesInvoice.GetShipmentLines","data":{"documentNo":"103001","shipmentNos":["102043","102044"]}}', '{"status":"Success","documentNo":"103001","systemId":"6c1a7a6e-0000-0000-0000-000000000001","addedCount":3,"addedLines":[{"lineNo":10000,"type":"","no":"","description":"Shipment No. 102043:","quantity":0,"shipmentNo":"102043","shipmentLineNo":0},{"lineNo":20000,"type":"Item","no":"1896-S","description":"ATHENS Desk","quantity":2,"shipmentNo":"102043","shipmentLineNo":10000},{"lineNo":30000,"type":"Item","no":"1900-S","description":"PARIS Guest Chair, black","quantity":1,"shipmentNo":"102044","shipmentLineNo":10000}],"skippedCount":1,"skippedLines":[{"shipmentNo":"102044","shipmentLineNo":20000,"reason":"invoiced","invoiceNo":""}]}'));
        Examples.Add(ContractMgt.Example(AllTitleLbl, '{"type":"Sales.SalesInvoice.GetShipmentLines","data":{"documentNo":"103002","allShipments":true}}', '{"status":"Success","documentNo":"103002","systemId":"6c1a7a6e-0000-0000-0000-000000000002","addedCount":0,"addedLines":[],"skippedCount":0,"skippedLines":[]}'));
        exit(true);
    end;

    /// <summary>Returns the localized operation overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Pulls posted, not invoiced sales shipment lines into an open sales invoice, as the Get Shipment Lines action on the sales invoice does, so several shipments of one customer are invoiced together. Send shipmentNos to name the shipments, or allShipments to take every not invoiced shipment line of the bill-to customer of the invoice in its currency. The answer lists the invoice lines added and the shipment lines skipped because they are already invoiced or already on an open sales invoice.', Comment = 'is-IS=Sækir bókaðar, óreikningsfærðar afhendingarlínur sölu inn á opinn sölureikning, eins og aðgerðin Sækja afhendingarlínur á sölureikningnum gerir, svo nokkrar afhendingar eins viðskiptamanns séu reikningsfærðar saman. Sendu shipmentNos til að tilgreina afhendingarnar, eða allShipments til að taka allar óreikningsfærðar afhendingarlínur reikningsviðskiptamanns reikningsins í gjaldmiðli hans. Svarið telur upp reikningslínurnar sem bættust við og afhendingarlínurnar sem var sleppt af því að þær eru þegar reikningsfærðar eða þegar á opnum sölureikningi.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Returns operation-specific usage notes.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A shipment of another bill-to customer or another currency is refused with InvalidLine and nothing is added. With allShipments, only shipment lines of the bill-to customer and currency of the invoice are read, and skippedLines lists only lines that are already on an open sales invoice. Business Central adds a heading text line for each shipment and copies item charge assignments, prices and discounts from the order, exactly as the native action does. A native refusal, such as a VAT business posting group that differs from the invoice, rolls the whole call back. The invoice is not posted; post it with Sales.Document.Post.', Comment = 'is-IS=Afhendingu annars reikningsviðskiptamanns eða annars gjaldmiðils er hafnað með InvalidLine og engu er bætt við. Með allShipments eru aðeins lesnar afhendingarlínur reikningsviðskiptamanns og gjaldmiðils reikningsins, og skippedLines telur aðeins upp línur sem eru þegar á opnum sölureikningi. Business Central bætir við fyrirsagnarlínu fyrir hverja afhendingu og afritar úthlutanir kostnaðarauka, verð og afslætti úr pöntuninni, nákvæmlega eins og innbyggða aðgerðin gerir. Innbyggð höfnun, til dæmis VSK-viðskiptabókunarflokkur sem er annar en reikningsins, afturkallar allt kallið. Reikningurinn er ekki bókaður; bókaðu hann með Sales.Document.Post.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Classifies shipment import as an inbound write.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request before importing shipment lines in the write transaction.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        SalesHeader: Record "Sales Header";
        TempShptHeader: Record "Sales Shipment Header" temporary;
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
        if not ValidateShape(Argument, RequestJson) then
            exit;
        if not ResolveInvoice(Argument, RequestJson, SalesHeader) then
            exit;
        if RequestJson.Contains(ShipmentNosKeyTok) then
            if not ResolveShipments(Argument, RequestJson, SalesHeader, TempShptHeader) then
                exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Sales Get Shipment Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Sales Get Shipment Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    /// <summary>
    /// Adds the shipment lines the request names to the invoice and sets the response. Runs inside
    /// Sales Get Shipment Proc ori after ExecuteBifrostTask has refused bad requests, so an error rolls the whole write back.
    /// </summary>
    /// <param name="Argument">The message argument with the validated request.</param>
    procedure RunGetShipmentLines(var Argument: Record "Message Argument ori")
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesShptLine: Record "Sales Shipment Line";
        TempShptHeader: Record "Sales Shipment Header" temporary;
        SalesGetShipment: Codeunit "Sales-Get Shipment";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AddedLines: JsonArray;
        SkippedLines: JsonArray;
        LastLineNo: Integer;
        CandidateCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        LocateInvoice(RequestJson, SalesHeader);
        if RequestJson.Contains(ShipmentNosKeyTok) then
            CollectShipments(RequestJson, TempShptHeader);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            LastLineNo := SalesLine."Line No.";
        CandidateCount := MarkCandidates(SalesHeader, TempShptHeader, RequestJson.Contains(ShipmentNosKeyTok), SalesShptLine, SkippedLines);
        if CandidateCount > 0 then begin
            SalesShptLine.MarkedOnly(true);
            SalesGetShipment.SetSalesHeader(SalesHeader);
            SalesGetShipment.CreateInvLines(SalesShptLine);
        end;
        SalesLine.SetFilter("Line No.", '>%1', LastLineNo);
        if SalesLine.FindSet() then
            repeat
                AddedLines.Add(AddedLineJson(SalesLine));
            until SalesLine.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', SalesHeader."No.");
        ResponseJson.Add('systemId', Format(SalesHeader.SystemId, 0, 4).ToLower());
        ResponseJson.Add('addedCount', AddedLines.Count());
        ResponseJson.Add('addedLines', AddedLines);
        ResponseJson.Add('skippedCount', SkippedLines.Count());
        ResponseJson.Add('skippedLines', SkippedLines);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure MarkCandidates(SalesHeader: Record "Sales Header"; var TempShptHeader: Record "Sales Shipment Header" temporary; ByShipment: Boolean; var SalesShptLine: Record "Sales Shipment Line"; var SkippedLines: JsonArray) CandidateCount: Integer
    begin
        SalesShptLine.Reset();
        if ByShipment then begin
            if not TempShptHeader.FindSet() then
                exit(0);
            repeat
                SalesShptLine.SetRange("Document No.", TempShptHeader."No.");
                SalesShptLine.SetFilter(Type, '<>%1', SalesShptLine.Type::" ");
                if SalesShptLine.FindSet() then
                    repeat
                        CandidateCount += MarkOne(SalesShptLine, SkippedLines, true);
                    until SalesShptLine.Next() = 0;
            until TempShptHeader.Next() = 0;
            // Clear the filters one by one: Reset would also drop the marks CreateInvLines reads.
            SalesShptLine.SetRange("Document No.");
            SalesShptLine.SetRange(Type);
            exit(CandidateCount);
        end;
        SalesShptLine.SetCurrentKey("Bill-to Customer No.");
        SalesShptLine.SetRange("Bill-to Customer No.", SalesHeader."Bill-to Customer No.");
        SalesShptLine.SetRange("Currency Code", SalesHeader."Currency Code");
        SalesShptLine.SetFilter("Qty. Shipped Not Invoiced", '<>0');
        if SalesShptLine.FindSet() then
            repeat
                CandidateCount += MarkOne(SalesShptLine, SkippedLines, false);
            until SalesShptLine.Next() = 0;
        SalesShptLine.SetRange("Bill-to Customer No.");
        SalesShptLine.SetRange("Currency Code");
        SalesShptLine.SetRange("Qty. Shipped Not Invoiced");
    end;

    local procedure MarkOne(var SalesShptLine: Record "Sales Shipment Line"; var SkippedLines: JsonArray; ListInvoiced: Boolean): Integer
    var
        InvoiceNo: Code[20];
    begin
        if SalesShptLine."Qty. Shipped Not Invoiced" = 0 then begin
            if ListInvoiced then
                SkippedLines.Add(SkippedLineJson(SalesShptLine, InvoicedReasonTok, ''));
            exit(0);
        end;
        InvoiceNo := OpenInvoiceHoldingLine(SalesShptLine);
        if InvoiceNo <> '' then begin
            SkippedLines.Add(SkippedLineJson(SalesShptLine, OnOpenInvoiceReasonTok, InvoiceNo));
            exit(0);
        end;
        SalesShptLine.Mark(true);
        exit(1);
    end;

    local procedure OpenInvoiceHoldingLine(SalesShptLine: Record "Sales Shipment Line"): Code[20]
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Invoice);
        SalesLine.SetRange("Shipment No.", SalesShptLine."Document No.");
        SalesLine.SetRange("Shipment Line No.", SalesShptLine."Line No.");
        if SalesLine.FindFirst() then
            exit(SalesLine."Document No.");
        exit('');
    end;

    local procedure AddedLineJson(SalesLine: Record "Sales Line") Line: JsonObject
    begin
        Line.Add('lineNo', SalesLine."Line No.");
        Line.Add('type', SalesLine.Type.Names().Get(SalesLine.Type.Ordinals().IndexOf(SalesLine.Type.AsInteger())));
        Line.Add('no', SalesLine."No.");
        Line.Add('description', SalesLine.Description);
        Line.Add('quantity', SalesLine.Quantity);
        Line.Add('shipmentNo', SalesLine."Shipment No.");
        Line.Add('shipmentLineNo', SalesLine."Shipment Line No.");
    end;

    local procedure SkippedLineJson(SalesShptLine: Record "Sales Shipment Line"; Reason: Text; InvoiceNo: Code[20]) Line: JsonObject
    begin
        Line.Add('shipmentNo', SalesShptLine."Document No.");
        Line.Add('shipmentLineNo', SalesShptLine."Line No.");
        Line.Add('reason', Reason);
        Line.Add('invoiceNo', InvoiceNo);
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        PermissionDeniedErr: Label 'Permission denied for Sales.SalesInvoice.GetShipmentLines.', Comment = 'is-IS=Heimild hafnað fyrir Sales.SalesInvoice.GetShipmentLines.';
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set and a Business Central permission set that can change sales invoices and read posted shipments.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst og Business Central heimildasafni sem getur breytt sölureikningum og lesið bókaðar afhendingar.';
    begin
        if IsEnabled() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', WritePermissionSetTok, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure TouchDeclaredKeys(RequestJson: JsonObject)
    begin
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('shipmentNos') then;
        if RequestJson.Contains('allShipments') then;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentNo, systemId, shipmentNos and allShipments.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentNo, systemId, shipmentNos og allShipments.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentNoKeyTok, SystemIdKeyTok, ShipmentNosKeyTok, AllShipmentsKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateShape(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Token: JsonToken;
        ItemToken: JsonToken;
        SystemId: Guid;
        MissingInvoiceErr: Label 'documentNo or systemId is required.', Comment = 'is-IS=documentNo eða systemId er nauðsynlegt.';
        MissingInvoiceNextLbl: Label 'Send the No. or the systemId of the open sales invoice.', Comment = 'is-IS=Sendu númer eða systemId opna sölureikningsins.';
        MissingSourceErr: Label 'shipmentNos or allShipments is required.', Comment = 'is-IS=shipmentNos eða allShipments er nauðsynlegt.';
        MissingSourceNextLbl: Label 'Send shipmentNos with the posted shipments to invoice, or allShipments as true.', Comment = 'is-IS=Sendu shipmentNos með bókuðu afhendingunum sem á að reikningsfæra, eða allShipments sem true.';
        BothInvoiceErr: Label 'Send documentNo or systemId, not both.', Comment = 'is-IS=Sendu documentNo eða systemId, ekki bæði.';
        BothSourceErr: Label 'Send shipmentNos or allShipments, not both.', Comment = 'is-IS=Sendu shipmentNos eða allShipments, ekki bæði.';
        BothNextLbl: Label 'Remove one of the two keys and send the request again.', Comment = 'is-IS=Fjarlægðu annan lykilinn og sendu beiðnina aftur.';
        FormatErr: Label '%1 has the wrong format.', Comment = '%1 = request key, is-IS=%1 er á röngu sniði.';
        FormatNextLbl: Label 'Send %1 as %2.', Comment = '%1 = request key, %2 = expected format, is-IS=Sendu %1 sem %2.';
        FalseErr: Label 'allShipments must be true when it is sent.', Comment = 'is-IS=allShipments verður að vera true þegar það er sent.';
        FalseNextLbl: Label 'Send allShipments as true, or send shipmentNos instead.', Comment = 'is-IS=Sendu allShipments sem true, eða sendu shipmentNos í staðinn.';
    begin
        if not (RequestJson.Contains(DocumentNoKeyTok) or RequestJson.Contains(SystemIdKeyTok)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingInvoiceErr, DocumentNoKeyTok, '', DocumentNoKeyTok, MissingInvoiceNextLbl);
            exit(false);
        end;
        if RequestJson.Contains(DocumentNoKeyTok) and RequestJson.Contains(SystemIdKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, BothInvoiceErr, SystemIdKeyTok, '', DocumentNoKeyTok, BothNextLbl);
            exit(false);
        end;
        if not (RequestJson.Contains(ShipmentNosKeyTok) or RequestJson.Contains(AllShipmentsKeyTok)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingSourceErr, ShipmentNosKeyTok, '', ShipmentNosKeyTok, MissingSourceNextLbl);
            exit(false);
        end;
        if RequestJson.Contains(ShipmentNosKeyTok) and RequestJson.Contains(AllShipmentsKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, BothSourceErr, AllShipmentsKeyTok, '', ShipmentNosKeyTok, BothNextLbl);
            exit(false);
        end;
        if RequestJson.Get(DocumentNoKeyTok, Token) then
            if not IsDocumentNoToken(Token) then
                exit(RespondFormat(Argument, DocumentNoKeyTok, DocumentNoExpectedTok, FormatErr, FormatNextLbl));
        if RequestJson.Get(SystemIdKeyTok, Token) then begin
            if not IsTextToken(Token) then
                exit(RespondFormat(Argument, SystemIdKeyTok, GuidExpectedTok, FormatErr, FormatNextLbl));
            if not Evaluate(SystemId, Token.AsValue().AsText()) then
                exit(RespondFormat(Argument, SystemIdKeyTok, GuidExpectedTok, FormatErr, FormatNextLbl));
        end;
        if RequestJson.Get(ShipmentNosKeyTok, Token) then begin
            if not Token.IsArray() then
                exit(RespondFormat(Argument, ShipmentNosKeyTok, ArrayExpectedTok, FormatErr, FormatNextLbl));
            if Token.AsArray().Count() = 0 then
                exit(RespondFormat(Argument, ShipmentNosKeyTok, ArrayExpectedTok, FormatErr, FormatNextLbl));
            foreach ItemToken in Token.AsArray() do
                if not IsDocumentNoToken(ItemToken) then
                    exit(RespondFormat(Argument, ShipmentNosKeyTok, DocumentNoExpectedTok, FormatErr, FormatNextLbl));
        end;
        if RequestJson.Get(AllShipmentsKeyTok, Token) then begin
            if not Token.IsValue() then
                exit(RespondFormat(Argument, AllShipmentsKeyTok, BooleanExpectedTok, FormatErr, FormatNextLbl));
            if Token.AsValue().IsNull() then
                exit(RespondFormat(Argument, AllShipmentsKeyTok, BooleanExpectedTok, FormatErr, FormatNextLbl));
            if not IsBooleanToken(Token) then
                exit(RespondFormat(Argument, AllShipmentsKeyTok, BooleanExpectedTok, FormatErr, FormatNextLbl));
            if not Token.AsValue().AsBoolean() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, FalseErr, AllShipmentsKeyTok, FalseTok, TrueExpectedTok, FalseNextLbl);
                exit(false);
            end;
        end;
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

    local procedure IsDocumentNoToken(Token: JsonToken): Boolean
    var
        DocumentNo: Code[20];
        Value: Text;
    begin
        if not IsTextToken(Token) then
            exit(false);
        Value := Token.AsValue().AsText();
        exit((StrLen(Value) <= MaxStrLen(DocumentNo)) and (DelChr(Value, '<>', ' ') <> ''));
    end;

    local procedure IsBooleanToken(Token: JsonToken): Boolean
    var
        TextValue: Text;
    begin
        Token.WriteTo(TextValue);
        exit(TextValue in ['true', 'false']);
    end;

    local procedure ResolveInvoice(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SalesHeader: Record "Sales Header"): Boolean
    var
        NotFoundErr: Label 'No sales invoice %1 was found.', Comment = '%1 = document no. or system id, is-IS=Sölureikningur %1 fannst ekki.';
        NotFoundNextLbl: Label 'Check documentNo or systemId; this type takes an open sales invoice, not an order or a posted invoice.', Comment = 'is-IS=Athugaðu documentNo eða systemId; þessi tegund tekur opinn sölureikning, ekki pöntun eða bókaðan reikning.';
        NotOpenErr: Label 'Sales invoice %1 is not open; its status is %2.', Comment = '%1 = invoice no., %2 = status, is-IS=Sölureikningur %1 er ekki opinn; staða hans er %2.';
        NotOpenNextLbl: Label 'Reopen the invoice with Sales.Document.Reopen, then send the request again.', Comment = 'is-IS=Opnaðu reikninginn aftur með Sales.Document.Reopen og sendu beiðnina síðan aftur.';
        Identifier: Text;
        KeyName: Text;
    begin
        if not LocateInvoice(RequestJson, SalesHeader) then begin
            KeyName := DocumentNoKeyTok;
            if RequestJson.Contains(SystemIdKeyTok) then
                KeyName := SystemIdKeyTok;
            Identifier := ReadText(RequestJson, KeyName);
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, Identifier), CopyStr(KeyName, 1, 250), CopyStr(Identifier, 1, 250), OpenInvoiceExpectedTok, NotFoundNextLbl);
            exit(false);
        end;
        if SalesHeader.Status <> SalesHeader.Status::Open then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotOpenErr, SalesHeader."No.", SalesHeader.Status), StatusKeyTok, CopyStr(SalesHeader.Status.Names().Get(SalesHeader.Status.Ordinals().IndexOf(SalesHeader.Status.AsInteger())), 1, 250), 'Open', NotOpenNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure LocateInvoice(RequestJson: JsonObject; var SalesHeader: Record "Sales Header"): Boolean
    var
        SystemId: Guid;
    begin
        if RequestJson.Contains(SystemIdKeyTok) then begin
            if not Evaluate(SystemId, ReadText(RequestJson, SystemIdKeyTok)) then
                exit(false);
            if not SalesHeader.GetBySystemId(SystemId) then
                exit(false);
            exit(SalesHeader."Document Type" = SalesHeader."Document Type"::Invoice);
        end;
        exit(SalesHeader.Get(SalesHeader."Document Type"::Invoice, CopyStr(ReadText(RequestJson, DocumentNoKeyTok), 1, MaxStrLen(SalesHeader."No."))));
    end;

    local procedure ResolveShipments(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; SalesHeader: Record "Sales Header"; var TempShptHeader: Record "Sales Shipment Header" temporary): Boolean
    var
        SalesShptHeader: Record "Sales Shipment Header";
        NotFoundErr: Label 'Posted sales shipment %1 was not found.', Comment = '%1 = shipment no., is-IS=Bókuð söluafhending %1 fannst ekki.';
        NotFoundNextLbl: Label 'Check the No. in shipmentNos, or send allShipments as true to take every not invoiced shipment of the customer.', Comment = 'is-IS=Athugaðu númerið í shipmentNos, eða sendu allShipments sem true til að taka allar óreikningsfærðar afhendingar viðskiptamannsins.';
        OtherCustomerErr: Label 'Shipment %1 belongs to bill-to customer %2, not to %3 on invoice %4.', Comment = '%1 = shipment no., %2 = shipment bill-to customer, %3 = invoice bill-to customer, %4 = invoice no., is-IS=Afhending %1 tilheyrir reikningsviðskiptamanni %2, ekki %3 á reikningi %4.';
        OtherCurrencyErr: Label 'Shipment %1 is in currency "%2", not "%3" like invoice %4.', Comment = '%1 = shipment no., %2 = shipment currency, %3 = invoice currency, %4 = invoice no., is-IS=Afhending %1 er í gjaldmiðlinum "%2", ekki "%3" eins og reikningur %4.';
        InvalidLineNextLbl: Label 'Send only shipments of the bill-to customer and currency of the invoice, or create a separate invoice for the other shipments. Nothing was added.', Comment = 'is-IS=Sendu aðeins afhendingar reikningsviðskiptamanns og gjaldmiðils reikningsins, eða stofnaðu sérstakan reikning fyrir hinar afhendingarnar. Engu var bætt við.';
    begin
        CollectShipments(RequestJson, TempShptHeader);
        if TempShptHeader.FindSet() then
            repeat
                if not SalesShptHeader.Get(TempShptHeader."No.") then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, TempShptHeader."No."), ShipmentNosKeyTok, TempShptHeader."No.", PostedShipmentExpectedTok, NotFoundNextLbl);
                    exit(false);
                end;
                if SalesShptHeader."Bill-to Customer No." <> SalesHeader."Bill-to Customer No." then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OtherCustomerErr, SalesShptHeader."No.", SalesShptHeader."Bill-to Customer No.", SalesHeader."Bill-to Customer No.", SalesHeader."No."), ShipmentNosKeyTok, SalesShptHeader."Bill-to Customer No.", SalesHeader."Bill-to Customer No.", InvalidLineNextLbl);
                    exit(false);
                end;
                if SalesShptHeader."Currency Code" <> SalesHeader."Currency Code" then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OtherCurrencyErr, SalesShptHeader."No.", SalesShptHeader."Currency Code", SalesHeader."Currency Code", SalesHeader."No."), ShipmentNosKeyTok, SalesShptHeader."Currency Code", SalesHeader."Currency Code", InvalidLineNextLbl);
                    exit(false);
                end;
            until TempShptHeader.Next() = 0;
        exit(true);
    end;

    local procedure CollectShipments(RequestJson: JsonObject; var TempShptHeader: Record "Sales Shipment Header" temporary)
    var
        Token: JsonToken;
        ItemToken: JsonToken;
        ShipmentNo: Code[20];
    begin
        TempShptHeader.Reset();
        TempShptHeader.DeleteAll();
        if not RequestJson.Get(ShipmentNosKeyTok, Token) then
            exit;
        foreach ItemToken in Token.AsArray() do begin
            ShipmentNo := CopyStr(ItemToken.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
            if not TempShptHeader.Get(ShipmentNo) then begin
                TempShptHeader.Init();
                TempShptHeader."No." := ShipmentNo;
                TempShptHeader.Insert();
            end;
        end;
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
