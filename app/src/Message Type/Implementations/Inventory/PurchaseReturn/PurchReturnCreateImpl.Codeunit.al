namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Vendor;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// Purchase.ReturnOrder.CreateFromPosted. Creates an open purchase return order or credit memo
/// and copies posted receipt or invoice item lines onto it. Nothing is posted.
/// Refusals are answered before the write, so a refusal leaves every document unchanged.
/// </summary>
codeunit 10076930 "Purch. Return Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        AppliedHeader: Record "Purchase Header";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        DocumentTypeKeyTok: Label 'documentType', Locked = true;
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        VendorNoKeyTok: Label 'vendorNo', Locked = true;
        LinesKeyTok: Label 'lines', Locked = true;
        SourceTypeKeyTok: Label 'sourceType', Locked = true;
        LineNoKeyTok: Label 'lineNo', Locked = true;
        QuantityKeyTok: Label 'quantity', Locked = true;
        ReturnOrderTok: Label 'ReturnOrder', Locked = true;
        CreditMemoTok: Label 'CreditMemo', Locked = true;
        ReceiptTok: Label 'Receipt', Locked = true;
        InvoiceTok: Label 'Invoice', Locked = true;
        AllowedKeysTok: Label 'documentType, documentNo, vendorNo, lines', Locked = true;
        AllowedLineKeysTok: Label 'sourceType, documentNo, lineNo, quantity', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        NumberExpectedTok: Label 'number', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        ObjectExpectedTok: Label 'object', Locked = true;
        OpenTok: Label 'Open', Locked = true;
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;
        AppliedLines: JsonArray;
        PendingRequest: JsonObject;
        ApplyReady: Boolean;
        MaxLines: Integer;

    /// <summary>True when Purchase Returns is on and the caller can create purchase documents and read posted lines.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::PurchaseReturns) then
            exit(false);
        exit(CanWriteDocuments());
    end;

    /// <summary>The table this type writes.</summary>
    /// <returns>The Purchase Header table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Purchase Header");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a purchase return order or credit memo from posted receipt or invoice lines.', Comment = 'is-IS=Býr til innkaupaskilapöntun eða kreditreikning úr bókuðum vörumóttökum eða reikningslínum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'purchase return, vendor return, credit memo, reverse receipt, reverse invoice', Comment = 'is-IS=innkaupaskil, skil til lánardrottins, kreditreikningur, bakfæra vörumóttöku, bakfæra reikning';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates an open purchase return order or credit memo and copies the selected posted lines onto it with the remaining quantity applied back to the original item entries. Nothing is posted.', Comment = 'is-IS=Býr til opna innkaupaskilapöntun eða kreditreikning og afritar valdar bókaðar línur á hann með magni sem eftir er tengt aftur við upphaflegu vörufærslurnar. Ekkert er bókað.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Envelope chapter.</summary>
    /// <param name="Envelope">Receives the envelope.</param>
    /// <returns>True.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The vendor and the posted lines are named under data. Subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Target chapter.</summary>
    /// <param name="Target">Receives the target entries.</param>
    /// <returns>True.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        VendorLbl: Label 'Vendor of a new return order or credit memo. Required when documentNo is omitted.', Comment = 'is-IS=Lánardrottinn á nýrri skilapöntun eða kreditreikningi. Áskilið þegar documentNo er sleppt.';
        DocumentLbl: Label 'Number of an existing open purchase return order or credit memo. Omit it to create a new document.', Comment = 'is-IS=Númer opinna innkaupaskilapöntunar eða kreditreiknings sem er til. Slepptu því til að stofna nýtt skjal.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.vendorNo', 'text', VendorLbl));
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'text', DocumentLbl));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        DocumentTypeLbl: Label 'ReturnOrder creates a purchase return order. CreditMemo creates a purchase credit memo. The same value selects an existing document when documentNo is sent.', Comment = 'is-IS=ReturnOrder stofnar innkaupaskilapöntun. CreditMemo stofnar kreditreikning innkaupa. Sama gildi velur skjal sem er til þegar documentNo er sent.';
        DocumentNoLbl: Label 'Number of an existing open purchase return order or credit memo. Omit it to create a new document for vendorNo.', Comment = 'is-IS=Númer opinna innkaupaskilapöntunar eða kreditreiknings sem er til. Slepptu því til að stofna nýtt skjal fyrir vendorNo.';
        VendorNoLbl: Label 'Buy-from vendor number. Required when documentNo is omitted. When documentNo is sent it must match that document, or be omitted.', Comment = 'is-IS=Númer lánardrottins sem keypt er frá. Áskilið þegar documentNo er sleppt. Þegar documentNo er sent verður það að passa við skjalið, eða vera sleppt.';
        LineChildren: JsonArray;
        LinesParameter: JsonObject;
        LinesLbl: Label 'Posted item lines to copy. At most 200. Each entry names a receipt or invoice line and the quantity to reverse, in the unit of measure of that posted line.', Comment = 'is-IS=Bókaðar vörulínur sem á að afrita. Mest 200. Hver færsla nefnir vörumóttöku- eða reikningslínu og magnið sem á að bakfæra, í mælieiningu þeirrar bókuðu línu.';
        SourceTypeLbl: Label 'Receipt or Invoice.', Comment = 'is-IS=Receipt eða Invoice.';
        SourceDocumentLbl: Label 'Posted receipt number or posted invoice number.', Comment = 'is-IS=Númer bókaðrar vörumóttöku eða bókaðs reiknings.';
        SourceLineLbl: Label 'Line number on that posted document.', Comment = 'is-IS=Línunúmer á því bókaða skjali.';
        QuantityLbl: Label 'Quantity to reverse, greater than zero and at most the quantity still left on the posted item line. A partial quantity is accepted when the line applies to one item entry. Send the full remaining quantity when the line is split across several item entries.', Comment = 'is-IS=Magn sem á að bakfæra, stærra en núll og mest það magn sem enn er eftir á bókuðu vörulínunni. Hlutamagn er leyft þegar línan tengist einni vörufærslu. Sendu allt magnið sem eftir er þegar línan skiptist á fleiri en eina vörufærslu.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', true, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('vendorNo', 'string', false, VendorNoLbl));
        LineChildren.Add(ContractMgt.Parameter('sourceType', 'string', true, SourceTypeLbl));
        LineChildren.Add(ContractMgt.Parameter('documentNo', 'string', true, SourceDocumentLbl));
        LineChildren.Add(ContractMgt.Parameter('lineNo', 'integer', true, SourceLineLbl));
        LineChildren.Add(ContractMgt.Parameter('quantity', 'number', true, QuantityLbl));
        LinesParameter := ContractMgt.Parameter('lines', 'array', true, LinesLbl);
        LinesParameter.Add('children', LineChildren);
        Parameters.Add(LinesParameter);
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        LineField: JsonObject;
        LineChildren: JsonArray;
    begin
        LineChildren.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number on the return order or credit memo.'));
        LineChildren.Add(ContractMgt.ResponseField('sourceType', 'string', 'Receipt or Invoice.'));
        LineChildren.Add(ContractMgt.ResponseField('sourceDocumentNo', 'string', 'Posted receipt or invoice number the line was copied from.'));
        LineChildren.Add(ContractMgt.ResponseField('sourceLineNo', 'integer', 'Line number on that posted document.'));
        LineChildren.Add(ContractMgt.ResponseField('quantity', 'number', 'Quantity on the new line, in the unit of measure of the posted line.'));
        LineChildren.Add(ContractMgt.ResponseField('applToItemEntry', 'integer', 'Item entry the new line applies to. One posted line can produce several lines when it is split across item entries.'));
        LineField := ContractMgt.ResponseField('lines', 'array', 'Item lines copied onto the document. Comment lines inserted by the copy are not included.');
        LineField.Add('children', LineChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call. Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'ReturnOrder or CreditMemo.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'Number of the purchase return order or credit memo.'));
        Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'System id of that document.'));
        Fields.Add(ContractMgt.ResponseField('vendorNo', 'string', 'Buy-from vendor of that document.'));
        Fields.Add(LineField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'documentType or lines is missing, a line has no sourceType, documentNo, lineNo or quantity, or a new document has no vendorNo.', Comment = 'is-IS=documentType eða lines vantar, línu vantar sourceType, documentNo, lineNo eða quantity, eða nýju skjali vantar vendorNo.';
        MissingFixLbl: Label 'Send documentType, lines, and vendorNo when you are creating a document. Each line needs sourceType, documentNo, lineNo and quantity.', Comment = 'is-IS=Sendu documentType, lines og vendorNo þegar þú stofnar skjal. Hver lína þarf sourceType, documentNo, lineNo og quantity.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send documentType, documentNo, vendorNo and sourceType as text, lineNo as a whole number, quantity as a number, and lines as an array of objects.', Comment = 'is-IS=Sendu documentType, documentNo, vendorNo og sourceType sem texta, lineNo sem heiltölu, quantity sem tölu og lines sem fylki af hlutum.';
        UnknownWhenLbl: Label 'The request or a line contains a key this type does not read.', Comment = 'is-IS=Beiðnin eða lína inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, vendorNo and lines. Each line allows sourceType, documentNo, lineNo and quantity.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, vendorNo og lines. Hver lína leyfir sourceType, documentNo, lineNo og quantity.';
        NotFoundWhenLbl: Label 'The vendor, the purchase document, or the posted receipt or invoice line does not exist.', Comment = 'is-IS=Lánardrottinn, innkaupaskjalið eða bókaða vörumóttöku- eða reikningslínan er ekki til.';
        NotFoundFixLbl: Label 'Check the vendor number, the document number, and the posted document number and line number.', Comment = 'is-IS=Athugaðu númer lánardrottins, númer skjalsins og númer og línunúmer bókaða skjalsins.';
        ConflictWhenLbl: Label 'vendorNo was sent with documentNo and it is not the buy-from vendor of that document.', Comment = 'is-IS=vendorNo var sent með documentNo og er ekki lánardrottinn sem keypt er frá á því skjali.';
        ConflictFixLbl: Label 'Omit vendorNo, or send the buy-from vendor of that document.', Comment = 'is-IS=Slepptu vendorNo, eða sendu lánardrottin sem keypt er frá á því skjali.';
        InvalidWhenLbl: Label 'documentType is not ReturnOrder or CreditMemo, sourceType is not Receipt or Invoice, lineNo is not a positive whole number, or the Purchase Returns domain is turned off.', Comment = 'is-IS=documentType er ekki ReturnOrder eða CreditMemo, sourceType er ekki Receipt eða Invoice, lineNo er ekki jákvæð heiltala, eða innkaupaskilasviðið er óvirkt.';
        InvalidFixLbl: Label 'Send ReturnOrder or CreditMemo, Receipt or Invoice, and a positive line number, or turn Purchase Returns on from the Inventory Setup page.', Comment = 'is-IS=Sendu ReturnOrder eða CreditMemo, Receipt eða Invoice og jákvætt línunúmer, eða kveiktu á innkaupaskilum á síðunni Uppsetning birgða.';
        LineWhenLbl: Label 'The quantity is not greater than zero, is above the quantity left to reverse, the posted line is not an item line, it belongs to another vendor, the same posted line is sent twice, or a partial quantity was asked for a line that is split across several item entries.', Comment = 'is-IS=Magnið er ekki stærra en núll, er yfir magninu sem eftir er að bakfæra, bókaða línan er ekki vörulína, hún tilheyrir öðrum lánardrottni, sama bókaða línan er send tvisvar, eða beðið var um hlutamagn af línu sem skiptist á fleiri en eina vörufærslu.';
        LineFixLbl: Label 'Send a quantity greater than zero and at most the quantity still left to reverse, from an item line of the same vendor. Send the full remaining quantity when the line is split across several item entries.', Comment = 'is-IS=Sendu magn sem er stærra en núll og mest það magn sem enn er eftir að bakfæra, af vörulínu sama lánardrottins. Sendu allt magnið sem eftir er þegar línan skiptist á fleiri en eina vörufærslu.';
        OpenWhenLbl: Label 'The purchase document named by documentNo is not open.', Comment = 'is-IS=Innkaupaskjalið sem documentNo nefnir er ekki opið.';
        OpenFixLbl: Label 'Reopen the purchase document, or omit documentNo to create a new one.', Comment = 'is-IS=Opnaðu innkaupaskjalið aftur, eða slepptu documentNo til að stofna nýtt.';
        LimitWhenLbl: Label 'lines contains more than 200 entries.', Comment = 'is-IS=lines inniheldur fleiri en 200 færslur.';
        LimitFixLbl: Label 'Send at most 200 posted lines in one call.', Comment = 'is-IS=Sendu mest 200 bókaðar línur í einu kalli.';
        PermissionWhenLbl: Label 'The caller cannot create purchase documents or read posted purchase lines.', Comment = 'is-IS=Kallandinn getur ekki stofnað innkaupaskjöl eða lesið bókaðar innkaupalínur.';
        NativeWhenLbl: Label 'Business Central refuses the copy itself, after the request was checked. Nothing is saved.', Comment = 'is-IS=Business Central hafnar afrituninni sjálfri eftir að beiðnin var könnuð. Ekkert er vistað.';
        NativeFixLbl: Label 'Read the error text, correct the purchase document or the posted line, and send the call again.', Comment = 'is-IS=Lestu villutextann, leiðréttu innkaupaskjalið eða bókuðu línuna og sendu kallið aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, LineWhenLbl, LineFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, OpenWhenLbl, OpenFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, LimitWhenLbl, LimitFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeWhenLbl, NativeFixLbl));
        exit(true);
    end;

    /// <summary>Effect chapter: writes an unposted document and does not post.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ChangesLbl: Label 'Creates an open purchase return order or credit memo, or adds lines to an existing open one, and copies the selected posted item lines onto it. Each new item line applies back to the original item entry. A smaller quantity is stored when the posted line applies to one item entry. Nothing is posted, and a refusal saves nothing.', Comment = 'is-IS=Stofnar opna innkaupaskilapöntun eða kreditreikning, eða bætir línum á opið skjal sem er til, og afritar valdar bókaðar vörulínur á það. Hver ný vörulína tengist aftur við upphaflegu vörufærsluna. Minna magn er vistað þegar bókaða línan tengist einni vörufærslu. Ekkert er bókað og höfnun vistar ekkert.';
    begin
        Preconditions.Add('The Purchase Returns domain is on.');
        Preconditions.Add('Each posted line is an item line of the same vendor, and the quantity is still left to reverse.');
        Preconditions.Add('An existing document is open and has the same document type.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Metering chapter: not metered.</summary>
    /// <param name="Metering">Unused.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Related chapter.</summary>
    /// <param name="Related">Receives the related types.</param>
    /// <returns>True.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ApplicationLbl: Label 'Read how the received quantity is applied before choosing the quantity to reverse.', Comment = 'is-IS=Lesa hvernig móttekið magn er jafnað áður en magnið sem á að bakfæra er valið.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', ApplicationLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    /// <param name="Workflow">Receives the workflow.</param>
    /// <returns>True.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        ReadLbl: Label 'Read the item application of the received entry when you need to see what is still left.', Comment = 'is-IS=Lesa vörujöfnun mótteknu færslunnar þegar sjá þarf hvað er enn eftir.';
        CreateLbl: Label 'Create the open return order or credit memo and copy the posted lines onto it. Nothing is posted.', Comment = 'is-IS=Stofna opnu skilapöntunina eða kreditreikninginn og afrita bókuðu línurnar á hann. Ekkert er bókað.';
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Get', ReadLbl));
        Steps.Add(ContractMgt.WorkflowStep('Purchase.ReturnOrder.CreateFromPosted', CreateLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create a return order from a posted receipt line', Comment = 'is-IS=Stofna skilapöntun úr bókaðri vörumóttökulínu';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Purchase.ReturnOrder.CreateFromPosted","data":{"documentType":"ReturnOrder","vendorNo":"10000","lines":[{"sourceType":"Receipt","documentNo":"107000","lineNo":10000,"quantity":2}]}}', '{"status":"Success","documentType":"ReturnOrder","documentNo":"1001","systemId":"00000000-0000-0000-0000-000000000001","vendorNo":"10000","lines":[{"lineNo":10000,"sourceType":"Receipt","sourceDocumentNo":"107000","sourceLineNo":10000,"quantity":2,"applToItemEntry":100}]}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates an open purchase return order or credit memo, or adds lines to an existing open one, from posted purchase receipt or invoice item lines. The quantity has to be greater than zero and no higher than the quantity still left to reverse. The new lines apply back to the original item entries. A partial quantity is stored when the posted line applies to one item entry. Nothing is posted. The answer is the document number and the copied item lines.', Comment = 'is-IS=Stofnar opna innkaupaskilapöntun eða kreditreikning, eða bætir línum á opið skjal sem er til, úr bókuðum vörulínum vörumóttöku eða reiknings. Magnið verður að vera stærra en núll og ekki hærra en magnið sem enn er eftir að bakfæra. Nýju línurnar tengjast aftur við upphaflegu vörufærslurnar. Hlutamagn er vistað þegar bókaða línan tengist einni vörufærslu. Ekkert er bókað. Svarið er númer skjalsins og afrituðu vörulínurnar.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A successful call saves an open purchase return order or credit memo and the copied item lines. A refusal leaves every purchase document unchanged. The call does not post, does not delete a posted document and does not undo the receipt or the invoice. Calling it again for the same posted line can create another open document, because an unposted return does not reduce the quantity left to reverse. Post the return later from the purchase document. The caller needs permission to create purchase documents and to read posted purchase receipts, invoices and item entries.', Comment = 'is-IS=Kall sem tekst vistar opna innkaupaskilapöntun eða kreditreikning og afrituðu vörulínurnar. Höfnun skilur öll innkaupaskjöl eftir óbreytt. Kallið bókar ekki, eyðir ekki bókuðu skjali og bakfærir ekki vörumóttökuna eða reikninginn. Að kalla aftur fyrir sömu bókuðu línu getur stofnað annað opið skjal, því óbókað skil minnkar ekki magnið sem eftir er að bakfæra. Bókaðu skilið síðar af innkaupaskjalinu. Kallandinn þarf heimild til að stofna innkaupaskjöl og til að lesa bókaðar vörumóttökur, reikninga og vörufærslur.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Message direction.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs Purchase.ReturnOrder.CreateFromPosted. Validates the whole request, then writes in one try so a failure saves nothing.</summary>
    /// <param name="Argument">The message argument with the request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Header: Record "Purchase Header";
        Worker: Codeunit "Purch. Return Create Impl ori";
        ResultLines: JsonArray;
        RequestJson: JsonObject;
    begin
        MaxLines := 200;
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentType') then;
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('vendorNo') then;
        if RequestJson.Contains('lines') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        // Codeunit.Run starts a write transaction. A nested TryFunction cannot insert while the dispatcher is already a TryFunction.
        Worker.PrepareApply(RequestJson);
        if not Worker.Run() then begin
            Parts.RespondWithNativeContext(Argument, LinesKeyTok, '', OpenDocumentExpected(), NativeNextStep());
            exit;
        end;
        Worker.TakeResult(Header, ResultLines);
        WriteSuccess(Argument, Header, ResultLines);
    end;

    /// <summary>Stores the validated request on this instance so OnRun can write it.</summary>
    /// <param name="RequestJson">The validated request.</param>
    procedure PrepareApply(RequestJson: JsonObject)
    begin
        PendingRequest := RequestJson;
        ApplyReady := true;
    end;

    /// <summary>Returns the document and lines written by OnRun.</summary>
    /// <param name="Header">Receives the purchase header.</param>
    /// <param name="ResultLines">Receives the response lines.</param>
    procedure TakeResult(var Header: Record "Purchase Header"; var ResultLines: JsonArray)
    begin
        Header := AppliedHeader;
        ResultLines := AppliedLines;
    end;

    trigger OnRun()
    begin
        if not ApplyReady then
            exit;
        Apply(PendingRequest, AppliedHeader, AppliedLines);
    end;

    local procedure CanWriteDocuments(): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Vendor: Record Vendor;
    begin
        exit(PurchaseHeader.WritePermission() and PurchaseLine.WritePermission() and PurchRcptHeader.ReadPermission() and PurchRcptLine.ReadPermission() and PurchInvHeader.ReadPermission() and PurchInvLine.ReadPermission() and ItemLedgerEntry.ReadPermission() and Vendor.ReadPermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
    begin
        if (not InventorySetup.ReadPermission()) or (not CanWriteDocuments()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, vendorNo and lines.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, vendorNo og lines.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentTypeKeyTok, DocumentNoKeyTok, VendorNoKeyTok, LinesKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record Vendor;
        Lines: JsonArray;
        DocumentType: Enum "Purchase Document Type";
        VendorNo: Code[20];
        DocumentNo: Code[20];
        TargetVendor: Code[20];
        Creating: Boolean;
        MissingTypeErr: Label 'documentType is required.', Comment = 'is-IS=documentType er áskilið.';
        MissingTypeNextStepLbl: Label 'Send ReturnOrder or CreditMemo.', Comment = 'is-IS=Sendu ReturnOrder eða CreditMemo.';
        TypeErr: Label 'documentType must be ReturnOrder or CreditMemo.', Comment = 'is-IS=documentType verður að vera ReturnOrder eða CreditMemo.';
        TypeExpectedLbl: Label 'ReturnOrder or CreditMemo', Comment = 'is-IS=ReturnOrder eða CreditMemo';
        MissingVendorErr: Label 'vendorNo is required when documentNo is omitted.', Comment = 'is-IS=vendorNo er áskilið þegar documentNo er sleppt.';
        MissingVendorNextStepLbl: Label 'Send the buy-from vendor number, or send documentNo of an existing open document.', Comment = 'is-IS=Sendu númer lánardrottins sem keypt er frá, eða sendu documentNo á opnu skjali sem er til.';
        VendorMissingErr: Label 'The vendor does not exist.', Comment = 'is-IS=Lánardrottinn er ekki til.';
        DocumentMissingErr: Label 'The purchase document does not exist.', Comment = 'is-IS=Innkaupaskjalið er ekki til.';
        NotOpenErr: Label 'The purchase document is not open.', Comment = 'is-IS=Innkaupaskjalið er ekki opið.';
        ConflictErr: Label 'vendorNo does not match the buy-from vendor of the document.', Comment = 'is-IS=vendorNo passar ekki við lánardrottin sem keypt er frá á skjalinu.';
        MissingLinesErr: Label 'lines is required.', Comment = 'is-IS=lines er áskilið.';
        MissingLinesNextStepLbl: Label 'Send lines as an array with at least one posted line.', Comment = 'is-IS=Sendu lines sem fylki með að minnsta kosti einni bókaðri línu.';
        LimitErr: Label 'lines contains more than 200 entries.', Comment = 'is-IS=lines inniheldur fleiri en 200 færslur.';
        LimitNextStepLbl: Label 'Send at most 200 posted lines in one call.', Comment = 'is-IS=Sendu mest 200 bókaðar línur í einu kalli.';
    begin
        if not ValidateShapes(Argument, RequestJson) then
            exit(false);
        if not RequestJson.Contains(DocumentTypeKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingTypeErr, DocumentTypeKeyTok, '', ReturnOrderTok, MissingTypeNextStepLbl);
            exit(false);
        end;
        if not ReadDocumentType(ReadText(RequestJson, DocumentTypeKeyTok), DocumentType) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, TypeErr, DocumentTypeKeyTok, CopyStr(ReadText(RequestJson, DocumentTypeKeyTok), 1, 250), TypeExpectedLbl, MissingTypeNextStepLbl);
            exit(false);
        end;
        DocumentNo := CopyStr(ReadText(RequestJson, DocumentNoKeyTok), 1, MaxStrLen(PurchaseHeader."No."));
        VendorNo := CopyStr(ReadText(RequestJson, VendorNoKeyTok), 1, MaxStrLen(Vendor."No."));
        Creating := DocumentNo = '';
        if Creating and (VendorNo = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingVendorErr, VendorNoKeyTok, '', VendorNoKeyTok, MissingVendorNextStepLbl);
            exit(false);
        end;
        if Creating then begin
            Vendor.SetLoadFields("No.");
            if not Vendor.Get(VendorNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, VendorMissingErr, VendorNoKeyTok, VendorNo, VendorNoKeyTok, VendorNextStep());
                exit(false);
            end;
            TargetVendor := Vendor."No.";
        end else begin
            PurchaseHeader.SetLoadFields("Document Type", "No.", Status, "Buy-from Vendor No.");
            if not PurchaseHeader.Get(DocumentType, DocumentNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, DocumentMissingErr, DocumentNoKeyTok, DocumentNo, DocumentNoKeyTok, DocumentNextStep());
                exit(false);
            end;
            if PurchaseHeader.Status <> PurchaseHeader.Status::Open then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NotOpenErr, DocumentNoKeyTok, Format(PurchaseHeader.Status), OpenTok, OpenNextStep());
                exit(false);
            end;
            if RequestJson.Contains(VendorNoKeyTok) and (VendorNo <> PurchaseHeader."Buy-from Vendor No.") then begin
                Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, VendorNoKeyTok, VendorNo, PurchaseHeader."Buy-from Vendor No.", ConflictNextStep());
                exit(false);
            end;
            TargetVendor := PurchaseHeader."Buy-from Vendor No.";
        end;
        if not ReadArray(RequestJson, LinesKeyTok, Lines) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLinesErr, LinesKeyTok, '', LinesKeyTok, MissingLinesNextStepLbl);
            exit(false);
        end;
        if Lines.Count() = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLinesErr, LinesKeyTok, '0', LinesKeyTok, MissingLinesNextStepLbl);
            exit(false);
        end;
        if Lines.Count() > MaxLines then begin
            Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, LimitErr, LinesKeyTok, Format(Lines.Count(), 0, 9), Format(MaxLines, 0, 9), LimitNextStepLbl);
            exit(false);
        end;
        exit(ValidateLines(Argument, Lines, TargetVendor));
    end;

    local procedure ValidateShapes(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record Vendor;
        DocumentText: Text;
        VendorText: Text;
    begin
        if RequestJson.Contains(DocumentTypeKeyTok) then
            if not RequireText(Argument, RequestJson, DocumentTypeKeyTok) then
                exit(false);
        if RequestJson.Contains(DocumentNoKeyTok) then begin
            if not RequireText(Argument, RequestJson, DocumentNoKeyTok) then
                exit(false);
            DocumentText := ReadText(RequestJson, DocumentNoKeyTok);
            if not CheckLength(Argument, DocumentNoKeyTok, DocumentText, MaxStrLen(PurchaseHeader."No.")) then
                exit(false);
        end;
        if RequestJson.Contains(VendorNoKeyTok) then begin
            if not RequireText(Argument, RequestJson, VendorNoKeyTok) then
                exit(false);
            VendorText := ReadText(RequestJson, VendorNoKeyTok);
            if not CheckLength(Argument, VendorNoKeyTok, VendorText, MaxStrLen(Vendor."No.")) then
                exit(false);
        end;
        if RequestJson.Contains(LinesKeyTok) then
            if not RequireArray(Argument, RequestJson, LinesKeyTok) then
                exit(false);
        exit(true);
    end;

    local procedure ValidateLines(var Argument: Record "Message Argument ori"; Lines: JsonArray; TargetVendor: Code[20]): Boolean
    var
        LineToken: JsonToken;
        LineJson: JsonObject;
        Seen: List of [Text];
        Index: Integer;
        NotObjectErr: Label 'Each lines entry must be an object.', Comment = 'is-IS=Hver færsla í lines verður að vera hlutur.';
        NotObjectNextStepLbl: Label 'Send each lines entry as an object with sourceType, documentNo, lineNo and quantity.', Comment = 'is-IS=Sendu hverja færslu í lines sem hlut með sourceType, documentNo, lineNo og quantity.';
    begin
        for Index := 0 to Lines.Count() - 1 do begin
            Lines.Get(Index, LineToken);
            if not LineToken.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, NotObjectErr, LinesKeyTok, Format(Index, 0, 9), ObjectExpectedTok, NotObjectNextStepLbl);
                exit(false);
            end;
            LineJson := LineToken.AsObject();
            if not ValidateOneLine(Argument, LineJson, TargetVendor, Seen) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateOneLine(var Argument: Record "Message Argument ori"; LineJson: JsonObject; TargetVendor: Code[20]; var Seen: List of [Text]): Boolean
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        KeyName: Text;
        SourceType: Text;
        SourceDocumentNo: Code[20];
        SeenKey: Text;
        SourceLineNo: Integer;
        Quantity: Decimal;
        Remaining: Decimal;
        OpenEntries: Integer;
        SourceVendor: Code[20];
        ItemLine: Boolean;
        UnknownKeyErr: Label 'The lines entry contains an unknown key.', Comment = 'is-IS=Færslan í lines inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Each line allows sourceType, documentNo, lineNo and quantity.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Hver lína leyfir sourceType, documentNo, lineNo og quantity.';
        MissingErr: Label '%1 is required on a line.', Comment = '%1 = key, is-IS=%1 er áskilið á línu.';
        MissingNextStepLbl: Label 'Send sourceType, documentNo, lineNo and quantity on every line.', Comment = 'is-IS=Sendu sourceType, documentNo, lineNo og quantity á hverri línu.';
        SourceTypeErr: Label 'sourceType must be Receipt or Invoice.', Comment = 'is-IS=sourceType verður að vera Receipt eða Invoice.';
        SourceTypeExpectedLbl: Label 'Receipt or Invoice', Comment = 'is-IS=Receipt eða Invoice';
        LineNoErr: Label 'lineNo must be a positive whole number.', Comment = 'is-IS=lineNo verður að vera jákvæð heiltala.';
        QuantityErr: Label 'quantity must be greater than zero.', Comment = 'is-IS=quantity verður að vera stærra en núll.';
        NotItemErr: Label 'Only an item line can be reversed by this call.', Comment = 'is-IS=Aðeins vörulínu er hægt að bakfæra með þessu kalli.';
        VendorErr: Label 'The posted line belongs to another vendor.', Comment = 'is-IS=Bókaða línan tilheyrir öðrum lánardrottni.';
        AboveErr: Label 'The quantity is above the quantity left to reverse.', Comment = 'is-IS=Magnið er yfir magninu sem eftir er að bakfæra.';
        DuplicateErr: Label 'The same posted line was sent more than once.', Comment = 'is-IS=Sama bókaða línan var send oftar en einu sinni.';
        SplitErr: Label 'This posted line is split across more than one item entry. Send the full remaining quantity.', Comment = 'is-IS=Þessi bókaða lína skiptist á fleiri en eina vörufærslu. Sendu allt magnið sem eftir er.';
        NotFoundErr: Label 'The posted line does not exist.', Comment = 'is-IS=Bókaða línan er ekki til.';
    begin
        // String literals are the element keys of lines; the contract describes them on lines.
        if LineJson.Contains('sourceType') then;
        if LineJson.Contains('documentNo') then;
        if LineJson.Contains('lineNo') then;
        if LineJson.Contains('quantity') then;
        foreach KeyName in LineJson.Keys() do
            if not (KeyName in [SourceTypeKeyTok, DocumentNoKeyTok, LineNoKeyTok, QuantityKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedLineKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        if not LineJson.Contains(SourceTypeKeyTok) or not LineJson.Contains(DocumentNoKeyTok) or not LineJson.Contains(LineNoKeyTok) or not LineJson.Contains(QuantityKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, LinesKeyTok), LinesKeyTok, '', AllowedLineKeysTok, MissingNextStepLbl);
            exit(false);
        end;
        if not RequireText(Argument, LineJson, SourceTypeKeyTok) then
            exit(false);
        if not RequireText(Argument, LineJson, DocumentNoKeyTok) then
            exit(false);
        if not RequireInteger(Argument, LineJson, LineNoKeyTok) then
            exit(false);
        if not RequireDecimal(Argument, LineJson, QuantityKeyTok) then
            exit(false);
        SourceType := ReadText(LineJson, SourceTypeKeyTok);
        if not (SourceType in [ReceiptTok, InvoiceTok]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SourceTypeErr, SourceTypeKeyTok, CopyStr(SourceType, 1, 250), SourceTypeExpectedLbl, SourceTypeNextStep());
            exit(false);
        end;
        SourceDocumentNo := CopyStr(ReadText(LineJson, DocumentNoKeyTok), 1, MaxStrLen(PurchRcptLine."Document No."));
        if SourceDocumentNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, DocumentNoKeyTok), DocumentNoKeyTok, '', DocumentNoKeyTok, MissingNextStepLbl);
            exit(false);
        end;
        if not CheckLength(Argument, DocumentNoKeyTok, ReadText(LineJson, DocumentNoKeyTok), MaxStrLen(PurchRcptLine."Document No.")) then
            exit(false);
        SourceLineNo := ReadInteger(LineJson, LineNoKeyTok);
        if SourceLineNo <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, LineNoErr, LineNoKeyTok, Format(SourceLineNo, 0, 9), LineNoKeyTok, LineNoNextStep());
            exit(false);
        end;
        Quantity := ReadDecimal(LineJson, QuantityKeyTok);
        if Quantity <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, QuantityErr, QuantityKeyTok, Format(Quantity, 0, 9), QuantityKeyTok, QuantityNextStep());
            exit(false);
        end;
        SeenKey := SourceType + '|' + SourceDocumentNo + '|' + Format(SourceLineNo, 0, 9);
        if Seen.Contains(SeenKey) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, DuplicateErr, DocumentNoKeyTok, SourceDocumentNo, '', QuantityNextStep());
            exit(false);
        end;
        Seen.Add(SeenKey);
        if not ReadPostedLine(SourceType, SourceDocumentNo, SourceLineNo, Remaining, OpenEntries, SourceVendor, ItemLine) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, DocumentNoKeyTok, SourceDocumentNo, DocumentNoKeyTok, PostedLineNextStep());
            exit(false);
        end;
        if not ItemLine then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, NotItemErr, SourceTypeKeyTok, SourceType, ReceiptTok, QuantityNextStep());
            exit(false);
        end;
        if SourceVendor <> TargetVendor then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, VendorErr, VendorNoKeyTok, SourceVendor, TargetVendor, VendorLineNextStep());
            exit(false);
        end;
        if Quantity > Remaining then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, AboveErr, QuantityKeyTok, Format(Quantity, 0, 9), Format(Remaining, 0, 9), QuantityNextStep());
            exit(false);
        end;
        if (OpenEntries > 1) and (Quantity < Remaining) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, SplitErr, QuantityKeyTok, Format(Quantity, 0, 9), Format(Remaining, 0, 9), QuantityNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadPostedLine(SourceType: Text; DocumentNo: Code[20]; LineNo: Integer; var Remaining: Decimal; var OpenEntries: Integer; var SourceVendor: Code[20]; var ItemLine: Boolean): Boolean
    var
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        TempItemLedgerEntry: Record "Item Ledger Entry" temporary;
        RevUnitCostLCY: Decimal;
    begin
        Remaining := 0;
        OpenEntries := 0;
        SourceVendor := '';
        ItemLine := false;
        if SourceType = ReceiptTok then begin
            PurchRcptLine.SetLoadFields("Document No.", "Line No.", Type, Quantity, "Unit Cost (LCY)", "Qty. per Unit of Measure");
            if not PurchRcptLine.Get(DocumentNo, LineNo) then
                exit(false);
            PurchRcptHeader.SetLoadFields("No.", "Buy-from Vendor No.");
            PurchRcptHeader.Get(DocumentNo);
            SourceVendor := PurchRcptHeader."Buy-from Vendor No.";
            ItemLine := PurchRcptLine.Type = PurchRcptLine.Type::Item;
            if not ItemLine then
                exit(true);
            PurchRcptLine.CalcReceivedPurchNotReturned(Remaining, RevUnitCostLCY, true);
            PurchRcptLine.FilterPstdDocLnItemLedgEntries(ItemLedgerEntry);
            OpenEntries := CountOpenEntries(ItemLedgerEntry);
            exit(true);
        end;
        PurchInvLine.SetLoadFields("Document No.", "Line No.", Type, Quantity, "Unit Cost (LCY)", "Qty. per Unit of Measure");
        if not PurchInvLine.Get(DocumentNo, LineNo) then
            exit(false);
        PurchInvHeader.SetLoadFields("No.", "Buy-from Vendor No.");
        PurchInvHeader.Get(DocumentNo);
        SourceVendor := PurchInvHeader."Buy-from Vendor No.";
        ItemLine := PurchInvLine.Type = PurchInvLine.Type::Item;
        if not ItemLine then
            exit(true);
        PurchInvLine.CalcReceivedPurchNotReturned(Remaining, RevUnitCostLCY, true);
        PurchInvLine.GetItemLedgEntries(TempItemLedgerEntry, false);
        OpenEntries := CountOpenEntries(TempItemLedgerEntry);
        exit(true);
    end;

    local procedure CountOpenEntries(var ItemLedgerEntry: Record "Item Ledger Entry"): Integer
    var
        OpenEntries: Integer;
    begin
        if ItemLedgerEntry.FindSet() then
            repeat
                if ItemLedgerEntry."Remaining Quantity" > 0 then
                    OpenEntries += 1;
            until ItemLedgerEntry.Next() = 0;
        exit(OpenEntries);
    end;

    local procedure Apply(RequestJson: JsonObject; var Header: Record "Purchase Header"; var ResultLines: JsonArray)
    var
        Lines: JsonArray;
        LineToken: JsonToken;
        LineJson: JsonObject;
        DocumentType: Enum "Purchase Document Type";
        VendorNo: Code[20];
        DocumentNo: Code[20];
        Index: Integer;
    begin
        ReadDocumentType(ReadText(RequestJson, DocumentTypeKeyTok), DocumentType);
        DocumentNo := CopyStr(ReadText(RequestJson, DocumentNoKeyTok), 1, MaxStrLen(Header."No."));
        VendorNo := CopyStr(ReadText(RequestJson, VendorNoKeyTok), 1, 20);
        if DocumentNo = '' then
            CreateHeader(Header, DocumentType, VendorNo)
        else
            Header.Get(DocumentType, DocumentNo);
        ReadArray(RequestJson, LinesKeyTok, Lines);
        for Index := 0 to Lines.Count() - 1 do begin
            Lines.Get(Index, LineToken);
            LineJson := LineToken.AsObject();
            CopyOneLine(Header, ReadText(LineJson, SourceTypeKeyTok), CopyStr(ReadText(LineJson, DocumentNoKeyTok), 1, 20), ReadInteger(LineJson, LineNoKeyTok), ReadDecimal(LineJson, QuantityKeyTok), ResultLines);
        end;
    end;

    local procedure CreateHeader(var Header: Record "Purchase Header"; DocumentType: Enum "Purchase Document Type"; VendorNo: Code[20])
    begin
        Header.Init();
        Header.Validate("Document Type", DocumentType);
        Header.Insert(true);
        Header.Validate("Buy-from Vendor No.", VendorNo);
        Header.Modify(true);
    end;

    local procedure CopyOneLine(var Header: Record "Purchase Header"; SourceType: Text; SourceDocumentNo: Code[20]; SourceLineNo: Integer; Quantity: Decimal; var ResultLines: JsonArray)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        PurchInvLine: Record "Purch. Inv. Line";
        CopyDocumentMgt: Codeunit "Copy Document Mgt.";
        MissingLink: Boolean;
        LastLineNo: Integer;
        LinesNotCopied: Integer;
        CopyFailedErr: Label 'The posted line could not be copied onto the purchase document.', Comment = 'is-IS=Ekki tókst að afrita bókuðu línuna á innkaupaskjalið.';
    begin
        LastLineNo := LastPurchLineNo(Header);
        Clear(CopyDocumentMgt);
        CopyDocumentMgt.SetHideProcessWindow(true);
        CopyDocumentMgt.SetProperties(false, false, false, false, true, true, false);
        if SourceType = ReceiptTok then begin
            PurchRcptLine.SetRange("Document No.", SourceDocumentNo);
            PurchRcptLine.SetRange("Line No.", SourceLineNo);
            CopyDocumentMgt.CopyPurchRcptLinesToDoc(Header, PurchRcptLine, LinesNotCopied, MissingLink);
        end else begin
            PurchInvLine.SetRange("Document No.", SourceDocumentNo);
            PurchInvLine.SetRange("Line No.", SourceLineNo);
            CopyDocumentMgt.CopyPurchInvLinesToDoc(Header, PurchInvLine, LinesNotCopied, MissingLink);
        end;
        if (LinesNotCopied <> 0) or MissingLink then
            Error(CopyFailedErr);
        CollectCopiedLines(Header, LastLineNo, SourceType, SourceDocumentNo, SourceLineNo, Quantity, ResultLines);
    end;

    local procedure CollectCopiedLines(var Header: Record "Purchase Header"; LastLineNo: Integer; SourceType: Text; SourceDocumentNo: Code[20]; SourceLineNo: Integer; Quantity: Decimal; var ResultLines: JsonArray)
    var
        PurchaseLine: Record "Purchase Line";
        LineJson: JsonObject;
        ApplToItemEntry: Integer;
        CopiedQuantity: Decimal;
        LineCount: Integer;
        NothingCopiedErr: Label 'The posted line was not copied onto the purchase document.', Comment = 'is-IS=Bókaða línan var ekki afrituð á innkaupaskjalið.';
        SplitErr: Label 'The posted line was copied as several item lines, so a partial quantity cannot be stored.', Comment = 'is-IS=Bókaða línan var afrituð sem nokkrar vörulínur, svo ekki er hægt að vista hlutamagn.';
    begin
        FilterNewItemLines(PurchaseLine, Header, LastLineNo);
        if not PurchaseLine.FindSet() then
            Error(NothingCopiedErr);
        LineCount := PurchaseLine.Count();
        CopiedQuantity := 0;
        repeat
            CopiedQuantity += PurchaseLine.Quantity;
        until PurchaseLine.Next() = 0;
        if (LineCount > 1) and (Quantity < CopiedQuantity) then
            Error(SplitErr);
        if LineCount = 1 then begin
            PurchaseLine.FindFirst();
            if PurchaseLine.Quantity > Quantity then begin
                ApplToItemEntry := PurchaseLine."Appl.-to Item Entry";
                PurchaseLine.Validate(Quantity, Quantity);
                if (ApplToItemEntry <> 0) and (PurchaseLine."Appl.-to Item Entry" <> ApplToItemEntry) then
                    PurchaseLine.Validate("Appl.-to Item Entry", ApplToItemEntry);
                PurchaseLine.Modify(true);
            end;
        end;
        FilterNewItemLines(PurchaseLine, Header, LastLineNo);
        if PurchaseLine.FindSet() then
            repeat
                Clear(LineJson);
                LineJson.Add('lineNo', PurchaseLine."Line No.");
                LineJson.Add('sourceType', SourceType);
                LineJson.Add('sourceDocumentNo', SourceDocumentNo);
                LineJson.Add('sourceLineNo', SourceLineNo);
                LineJson.Add('quantity', PurchaseLine.Quantity);
                LineJson.Add('applToItemEntry', PurchaseLine."Appl.-to Item Entry");
                ResultLines.Add(LineJson);
            until PurchaseLine.Next() = 0;
    end;

    local procedure FilterNewItemLines(var PurchaseLine: Record "Purchase Line"; Header: Record "Purchase Header"; LastLineNo: Integer)
    begin
        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", Header."Document Type");
        PurchaseLine.SetRange("Document No.", Header."No.");
        PurchaseLine.SetFilter("Line No.", '>%1', LastLineNo);
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
    end;

    local procedure LastPurchLineNo(Header: Record "Purchase Header"): Integer
    var
        PurchaseLine: Record "Purchase Line";
    begin
        PurchaseLine.SetRange("Document Type", Header."Document Type");
        PurchaseLine.SetRange("Document No.", Header."No.");
        if PurchaseLine.FindLast() then
            exit(PurchaseLine."Line No.");
        exit(0);
    end;

    local procedure WriteSuccess(var Argument: Record "Message Argument ori"; Header: Record "Purchase Header"; ResultLines: JsonArray)
    var
        ResponseJson: JsonObject;
    begin
        Header.SetLoadFields("Document Type", "No.", SystemId, "Buy-from Vendor No.");
        Header.Get(Header."Document Type", Header."No.");
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', DocumentTypeName(Header."Document Type"));
        ResponseJson.Add('documentNo', Header."No.");
        ResponseJson.Add('systemId', Format(Header.SystemId, 0, 4));
        ResponseJson.Add('vendorNo', Header."Buy-from Vendor No.");
        ResponseJson.Add('lines', ResultLines);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadDocumentType(DocumentTypeText: Text; var DocumentType: Enum "Purchase Document Type"): Boolean
    begin
        if DocumentTypeText = ReturnOrderTok then begin
            DocumentType := DocumentType::"Return Order";
            exit(true);
        end;
        if DocumentTypeText = CreditMemoTok then begin
            DocumentType := DocumentType::"Credit Memo";
            exit(true);
        end;
        exit(false);
    end;

    local procedure DocumentTypeName(DocumentType: Enum "Purchase Document Type"): Text
    begin
        if DocumentType = DocumentType::"Return Order" then
            exit(ReturnOrderTok);
        exit(CreditMemoTok);
    end;

    local procedure CheckLength(var Argument: Record "Message Argument ori"; KeyName: Text; Value: Text; MaxLength: Integer): Boolean
    var
        TooLongErr: Label '%1 is longer than %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=%1 er lengra en %2 stafir.';
        TooLongNextStepLbl: Label 'Send %1 with at most %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=Sendu %1 með mest %2 stöfum.';
    begin
        if StrLen(Value) <= MaxLength then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, KeyName, MaxLength), CopyStr(KeyName, 1, 250), CopyStr(Value, 1, 250), Format(MaxLength, 0, 9), StrSubstNo(TooLongNextStepLbl, KeyName, MaxLength));
        exit(false);
    end;

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
        FormatNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = key, is-IS=Sendu %1 sem texta.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Integer;
        FormatErr: Label '%1 must be a whole number.', Comment = '%1 = key, is-IS=%1 verður að vera heiltala.';
        FormatNextStepLbl: Label 'Send %1 as a whole number.', Comment = '%1 = key, is-IS=Sendu %1 sem heiltölu.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or Raw.Contains('.') or (not Evaluate(Probe, Raw, 9)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Decimal;
        FormatErr: Label '%1 must be a number.', Comment = '%1 = key, is-IS=%1 verður að vera tala.';
        FormatNextStepLbl: Label 'Send %1 as a number.', Comment = '%1 = key, is-IS=Sendu %1 sem tölu.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (DelChr(Raw, '=', '0123456789.-') <> '') or (not Evaluate(Probe, Raw, 9)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireArray(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        FormatErr: Label '%1 must be an array.', Comment = '%1 = key, is-IS=%1 verður að vera fylki.';
        FormatNextStepLbl: Label 'Send %1 as an array of objects.', Comment = '%1 = key, is-IS=Sendu %1 sem fylki af hlutum.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', ArrayExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure IsNullToken(Token: JsonToken): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().IsNull());
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(0);
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(0);
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit(0);
        exit(Token.AsValue().AsDecimal());
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

    local procedure QuantityNextStep(): Text
    var
        QuantityNextStepLbl: Label 'Send a quantity greater than zero and at most the quantity that is still left to reverse on that posted line.', Comment = 'is-IS=Sendu magn sem er stærra en núll og mest það magn sem enn er eftir að bakfæra á þeirri bókuðu línu.';
    begin
        exit(QuantityNextStepLbl);
    end;

    local procedure VendorLineNextStep(): Text
    var
        VendorLineNextStepLbl: Label 'Send a posted line that belongs to the same vendor as the return document.', Comment = 'is-IS=Sendu bókaða línu sem tilheyrir sama lánardrottni og skilaskjalið.';
    begin
        exit(VendorLineNextStepLbl);
    end;

    local procedure VendorNextStep(): Text
    var
        VendorNextStepLbl: Label 'Check the vendor number.', Comment = 'is-IS=Athugaðu númer lánardrottins.';
    begin
        exit(VendorNextStepLbl);
    end;

    local procedure DocumentNextStep(): Text
    var
        DocumentNextStepLbl: Label 'Check the document type and number, or omit documentNo to create a new document.', Comment = 'is-IS=Athugaðu tegund og númer skjalsins, eða slepptu documentNo til að stofna nýtt skjal.';
    begin
        exit(DocumentNextStepLbl);
    end;

    local procedure OpenNextStep(): Text
    var
        OpenNextStepLbl: Label 'Reopen the purchase document, or omit documentNo to create a new one.', Comment = 'is-IS=Opnaðu innkaupaskjalið aftur, eða slepptu documentNo til að stofna nýtt.';
    begin
        exit(OpenNextStepLbl);
    end;

    local procedure ConflictNextStep(): Text
    var
        ConflictNextStepLbl: Label 'Omit vendorNo, or send the buy-from vendor of that document.', Comment = 'is-IS=Slepptu vendorNo, eða sendu lánardrottin sem keypt er frá á því skjali.';
    begin
        exit(ConflictNextStepLbl);
    end;

    local procedure SourceTypeNextStep(): Text
    var
        SourceTypeNextStepLbl: Label 'Send Receipt or Invoice.', Comment = 'is-IS=Sendu Receipt eða Invoice.';
    begin
        exit(SourceTypeNextStepLbl);
    end;

    local procedure LineNoNextStep(): Text
    var
        LineNoNextStepLbl: Label 'Send the posted line number as a positive whole number.', Comment = 'is-IS=Sendu línunúmer bókaða skjalsins sem jákvæða heiltölu.';
    begin
        exit(LineNoNextStepLbl);
    end;

    local procedure PostedLineNextStep(): Text
    var
        PostedLineNextStepLbl: Label 'Check the posted document number and line number.', Comment = 'is-IS=Athugaðu númer og línunúmer bókaða skjalsins.';
    begin
        exit(PostedLineNextStepLbl);
    end;

    local procedure OpenDocumentExpected(): Text
    var
        ExpectedLbl: Label 'an open purchase return document with the posted lines copied onto it', Comment = 'is-IS=opið innkaupaskilaskjal með bókuðu línunum afrituðum á það';
    begin
        exit(ExpectedLbl);
    end;

    local procedure NativeNextStep(): Text
    var
        NativeNextStepLbl: Label 'Read the error text, correct the purchase document or the posted line, and send the call again. Nothing was saved.', Comment = 'is-IS=Lestu villutextann, leiðréttu innkaupaskjalið eða bókuðu línuna og sendu kallið aftur. Ekkert var vistað.';
    begin
        exit(NativeNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign Bifrost full access and a Business Central permission set that can create purchase documents and read posted purchase receipts and invoices.', Comment = 'is-IS=Úthlutaðu fullum aðgangi Bifröst og Business Central heimildasafni sem getur stofnað innkaupaskjöl og lesið bókaðar vörumóttökur og reikninga.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
