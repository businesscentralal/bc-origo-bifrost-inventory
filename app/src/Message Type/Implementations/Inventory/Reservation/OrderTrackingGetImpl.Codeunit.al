namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.OrderTracking.Get reads the supply and demand tracked against one source line or item ledger entry,
/// as the Order Tracking page shows it. It only reads: the chain is built in temporary records.
/// </summary>
codeunit 10076890 "Order Tracking Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;
        AllowedKeysTok: Label 'sourceKind, documentType, documentNo, lineNo, systemId, entryNo, direction', Locked = true;
        SourceKindsTok: Label 'Sales, Purchase, Transfer, Assembly, ItemLedgerEntry', Locked = true;
        SalesDocumentTypesTok: Label 'Quote, Order, Invoice, Credit Memo, Blanket Order, Return Order', Locked = true;
        AssemblyDocumentTypesTok: Label 'Quote, Order, Blanket Order', Locked = true;
        DirectionsTok: Label 'Outbound, Inbound', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        ReservationEntry: Record "Reservation Entry";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations) then
            exit(false);
        exit(ReservationEntry.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads the order tracking chain for a line or an item ledger entry.', Comment = 'is-IS=Les pöntunarrakningarkeðju fyrir línu eða birgðafærslu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'order tracking, supply, demand, reservation chain', Comment = 'is-IS=pöntunarrakning, framboð, eftirspurn, frátekningarkeðja';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads which supply is tracked against a demand line, or which demand a supply line or item ledger entry covers.', Comment = 'is-IS=Les hvaða framboð er rakið á móti eftirspurnarlínu, eða hvaða eftirspurn framboðslína eða birgðafærsla dekkar.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The line or entry is named in data (sourceKind and its identifiers); subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        LineTargetLbl: Label 'A sales, purchase, transfer or assembly line, by document number and line number.', Comment = 'is-IS=Sölu-, innkaupa-, millifærslu- eða samsetningarlína, eftir númeri fylgiskjals og línunúmeri.';
        EntryTargetLbl: Label 'An item ledger entry, by its entry number.', Comment = 'is-IS=Birgðafærsla, eftir færslunúmeri hennar.';
        SystemIdTargetLbl: Label 'The line or item ledger entry, by its SystemId.', Comment = 'is-IS=Línan eða birgðafærslan, eftir SystemId hennar.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.sourceKind + data.documentNo + data.lineNo', 'source kind, document no. and line no.', LineTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.sourceKind + data.entryNo', 'item ledger entry no.', EntryTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.sourceKind + data.systemId', 'guid', SystemIdTargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SourceKindLbl: Label 'Sales, Purchase, Transfer, Assembly or ItemLedgerEntry. Required.', Comment = 'is-IS=Sales, Purchase, Transfer, Assembly eða ItemLedgerEntry. Nauðsynlegt.';
        DocumentTypeLbl: Label 'Sales and Purchase: Quote, Order, Invoice, Credit Memo, Blanket Order or Return Order. Assembly: Quote, Order or Blanket Order. Defaults to Order. Not used for Transfer and ItemLedgerEntry.', Comment = 'is-IS=Sales og Purchase: Quote, Order, Invoice, Credit Memo, Blanket Order eða Return Order. Assembly: Quote, Order eða Blanket Order. Sjálfgefið er Order. Ekki notað fyrir Transfer og ItemLedgerEntry.';
        DocumentNoLbl: Label 'The document number of the line. Required for a line unless systemId is sent.', Comment = 'is-IS=Númer fylgiskjals línunnar. Nauðsynlegt fyrir línu nema systemId sé sent.';
        LineNoLbl: Label 'The line number. Required for a line unless systemId is sent.', Comment = 'is-IS=Línunúmerið. Nauðsynlegt fyrir línu nema systemId sé sent.';
        SystemIdLbl: Label 'The SystemId of the line or item ledger entry. Do not send the other identifiers with it.', Comment = 'is-IS=SystemId línunnar eða birgðafærslunnar. Ekki senda hin auðkennin með því.';
        EntryNoLbl: Label 'The item ledger entry number. ItemLedgerEntry only. Required unless systemId is sent.', Comment = 'is-IS=Færslunúmer birgðafærslunnar. Aðeins fyrir ItemLedgerEntry. Nauðsynlegt nema systemId sé sent.';
        DirectionLbl: Label 'Transfer only: Outbound (the shipment side, default) or Inbound (the receipt side).', Comment = 'is-IS=Aðeins fyrir Transfer: Outbound (afhendingarhliðin, sjálfgefið) eða Inbound (móttökuhliðin).';
    begin
        Parameters.Add(ContractMgt.Parameter('sourceKind', 'string', true, SourceKindLbl));
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, LineNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', false, EntryNoLbl));
        Parameters.Add(ContractMgt.Parameter('direction', 'string', false, DirectionLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        EntryFields: JsonArray;
        EntriesField: JsonObject;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the chain was read; the list is empty when the line has no chain.'));
        Fields.Add(ContractMgt.ResponseField('sourceKind', 'string', 'The source kind in its canonical spelling: Sales, Purchase, Transfer, Assembly or ItemLedgerEntry.'));
        EntryFields.Add(ContractMgt.ResponseField('level', 'integer', 'The level of the link in the chain; 1 is the line or entry you asked about.'));
        EntryFields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the link.'));
        EntryFields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The tracked quantity of the link, in the base unit of measure.'));
        EntryFields.Add(ContractMgt.ResponseField('suppliedBy', 'string', 'The supply, in words.'));
        EntryFields.Add(ContractMgt.ResponseField('demandedBy', 'string', 'The demand, in words; CURRENT LINE marks the line you asked about.'));
        EntryFields.Add(ContractMgt.ResponseField('fromType', 'integer', 'The table number of the line or entry this link comes from.'));
        EntryFields.Add(ContractMgt.ResponseField('fromTypeName', 'string', 'The name of that table.'));
        EntryFields.Add(ContractMgt.ResponseField('fromSubtype', 'integer', 'The subtype of the from line, for example the document type.'));
        EntryFields.Add(ContractMgt.ResponseField('fromNo', 'string', 'The document or batch of the from line.'));
        EntryFields.Add(ContractMgt.ResponseField('fromLineNo', 'integer', 'The line or entry number of the from line.'));
        EntryFields.Add(ContractMgt.ResponseField('forType', 'integer', 'The table number of the line or entry on this level.'));
        EntryFields.Add(ContractMgt.ResponseField('forTypeName', 'string', 'The name of that table.'));
        EntryFields.Add(ContractMgt.ResponseField('forSubtype', 'integer', 'The subtype of the for line, for example the document type.'));
        EntryFields.Add(ContractMgt.ResponseField('forNo', 'string', 'The document or batch of the for line.'));
        EntryFields.Add(ContractMgt.ResponseField('forLineNo', 'integer', 'The line or entry number of the for line.'));
        EntryFields.Add(ContractMgt.ResponseField('shipmentDate', 'string', 'The shipment date in YYYY-MM-DD form; blank when there is none.'));
        EntryFields.Add(ContractMgt.ResponseField('expectedReceiptDate', 'string', 'The expected receipt date in YYYY-MM-DD form; blank when there is none.'));
        EntryFields.Add(ContractMgt.ResponseField('startingDate', 'string', 'The starting date in YYYY-MM-DD form; blank when there is none.'));
        EntryFields.Add(ContractMgt.ResponseField('endingDate', 'string', 'The ending date in YYYY-MM-DD form; blank when there is none.'));
        EntryFields.Add(ContractMgt.ResponseField('warning', 'boolean', 'True when Business Central flags the link with a warning.'));
        EntriesField := ContractMgt.ResponseField('entries', 'array', 'One row per link in the chain.');
        EntriesField.Add('children', EntryFields);
        Fields.Add(EntriesField);
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'sourceKind is missing, or the line or entry is not identified.', Comment = 'is-IS=sourceKind vantar, eða línan eða færslan er ekki tilgreind.';
        MissingFixLbl: Label 'Send sourceKind, and documentNo and lineNo, entryNo or systemId.', Comment = 'is-IS=Sendu sourceKind, og documentNo og lineNo, entryNo eða systemId.';
        InvalidWhenLbl: Label 'sourceKind, documentType or direction has a value this type does not support, a key does not apply to the sourceKind, or the Reservations domain is turned off.', Comment = 'is-IS=sourceKind, documentType eða direction hefur gildi sem þessi tegund styður ekki, lykill á ekki við sourceKind, eða slökkt er á frátekningasviðinu.';
        InvalidFixLbl: Label 'Send a value from the parameters chapter and only the keys of that sourceKind, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu gildi úr kaflanum um færibreytur og aðeins lykla þess sourceKind, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send lineNo and entryNo as integers and systemId as a GUID.', Comment = 'is-IS=Sendu lineNo og entryNo sem heiltölur og systemId sem GUID.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are sourceKind, documentType, documentNo, lineNo, systemId, entryNo and direction.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru sourceKind, documentType, documentNo, lineNo, systemId, entryNo og direction.';
        ConflictWhenLbl: Label 'systemId was sent together with documentType, documentNo, lineNo or entryNo.', Comment = 'is-IS=systemId var sent ásamt documentType, documentNo, lineNo eða entryNo.';
        ConflictFixLbl: Label 'Send systemId or the other identifiers, not both.', Comment = 'is-IS=Sendu systemId eða hin auðkennin, ekki hvort tveggja.';
        NotFoundWhenLbl: Label 'No line or item ledger entry matches the identifiers.', Comment = 'is-IS=Engin lína eða birgðafærsla passar við auðkennin.';
        NotFoundFixLbl: Label 'Check the document and line no.', Comment = 'is-IS=Athugaðu fylgiskjalið og línunúmerið.';
        PermissionWhenLbl: Label 'The caller cannot read reservation entries or the source table.', Comment = 'is-IS=Kallandinn getur ekki lesið frátekningarfærslur eða upprunatöfluna.';
        PermissionFixLbl: Label 'Assign BIFROST Read ori (extended by BIFROST InvRead ori) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori (með viðbótinni BIFROST InvRead ori) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native order tracking error text.', 'Business Central fails while it reads the chain; the answer carries its text.', 'Read the error text and check the line it names.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Reservations domain is turned on in Inventory Setup.');
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is changed. The order tracking chain is worked out for the call and returned; no reservation is created or changed.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Effect.Add('preconditions', Preconditions);
        Effect.Add('writes', false);
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
        AutoReserveLbl: Label 'Reserve a sales order line first, then read its tracking chain.', Comment = 'is-IS=Taktu sölupöntunarlínu frá fyrst og lestu svo rakningarkeðju hennar.';
        ReservationGetLbl: Label 'Read the reservation entries themselves.', Comment = 'is-IS=Lestu frátekningarfærslurnar sjálfar.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.AutoReserve', AutoReserveLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', ReservationGetLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Read the tracking chain of a reserved sales order line', Comment = 'is-IS=Lesa rakningarkeðju frátekinnar sölupöntunarlínu';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl,
            '{"type":"Inventory.OrderTracking.Get","data":{"sourceKind":"Sales","documentType":"Order","documentNo":"101005","lineNo":10000}}',
            '{"status":"Success","sourceKind":"Sales","entries":[{"level":1,"itemNo":"1000","quantity":2,"suppliedBy":"Item Ledger Entry 345","demandedBy":"CURRENT LINE","fromType":32,"fromTypeName":"Item Ledger Entry","fromSubtype":0,"fromNo":"","fromLineNo":345,"forType":37,"forTypeName":"Sales Line","forSubtype":1,"forNo":"101005","forLineNo":10000,"shipmentDate":"2026-10-20","expectedReceiptDate":"","startingDate":"2026-10-20","endingDate":"2026-10-20","warning":false}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads the order tracking chain for a sales, purchase, transfer or assembly line, or for one item ledger entry, as the Order Tracking page shows it. Each entry names the supply, the demand, the quantity and the dates. This call does not create or change reservations.', Comment = 'is-IS=Les pöntunarrakningarkeðju fyrir sölu-, innkaupa-, millifærslu- eða samsetningarlínu, eða fyrir eina birgðafærslu, eins og síðan Pöntunarrakning sýnir hana. Hver færsla tilgreinir framboðið, eftirspurnina, magnið og dagsetningarnar. Þetta kall stofnar hvorki né breytir frátekningum.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Each entry is one link of the chain. for is the line or entry on that level, at level 1 the one you asked about, and from is the line or entry it is linked to. suppliedBy and demandedBy name the supply and the demand in words; CURRENT LINE marks the line you asked about. fromType and forType are table numbers, fromTypeName and forTypeName their names, fromNo and forNo the document or batch, fromLineNo and forLineNo the line or entry number, and quantity is in the base unit of measure. A line without reservations or order tracking answers an empty entries list, and so does a sales or purchase line that is not an item line. For Transfer, direction picks the shipment side (Outbound) or the receipt side (Inbound). Send only the keys that fit the sourceKind: documentType, documentNo and lineNo for Sales, Purchase and Assembly (documentType defaults to Order), documentNo, lineNo and direction for Transfer, entryNo for ItemLedgerEntry. systemId replaces the other identifiers. A key that does not fit the sourceKind is refused as InvalidParameter. The call only reads; the Reservations domain must be turned on in Inventory Setup.', Comment = 'is-IS=Hver færsla er einn hlekkur í keðjunni. for er línan eða færslan á því stigi, á stigi 1 sú sem spurt var um, og from er línan eða færslan sem hún tengist. suppliedBy og demandedBy lýsa framboðinu og eftirspurninni í orðum; CURRENT LINE merkir línuna sem spurt var um. fromType og forType eru töflunúmer, fromTypeName og forTypeName heiti þeirra, fromNo og forNo fylgiskjalið eða bunkinn, fromLineNo og forLineNo línu- eða færslunúmerið, og quantity er í grunnmælieiningu. Lína án frátekninga eða pöntunarrakningar svarar tómum entries-lista, og það gerir einnig sölu- eða innkaupalína sem er ekki vörulína. Fyrir Transfer velur direction afhendingarhliðina (Outbound) eða móttökuhliðina (Inbound). Sendu aðeins lyklana sem eiga við sourceKind: documentType, documentNo og lineNo fyrir Sales, Purchase og Assembly (documentType er sjálfgefið Order), documentNo, lineNo og direction fyrir Transfer, entryNo fyrir ItemLedgerEntry. systemId kemur í stað hinna auðkennanna. Lykli sem á ekki við sourceKind er hafnað sem InvalidParameter. Kallið les aðeins; frátekningasviðið þarf að vera kveikt í birgðauppsetningu.';
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        SourceRecord: Variant;
        SourceKind: Text;
        HasSource: Boolean;
    begin
        if not AssertCanRead(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        SourceKind := UpperCase(ReadText(RequestJson, 'sourceKind'));
        if not BindSource(Argument, RequestJson, SourceKind, SourceRecord, HasSource) then
            exit;
        if HasSource then
            if not TryCollectTracking(SourceRecord, IsInbound(RequestJson), Entries) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('sourceKind', CanonicalSourceKind(SourceKind));
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        ReservationEntry: Record "Reservation Entry";
        DomainDisabledErr: Label 'The Reservations domain is turned off for this company.', Comment = 'is-IS=Slökkt er á frátekningasviðinu fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á sviðinu á síðunni Uppsetning birgða.';
    begin
        if not InventorySetup.ReadPermission() then begin
            RespondPermissionDenied(Argument);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
            exit(false);
        end;
        if ReservationEntry.ReadPermission() then
            exit(true);
        RespondPermissionDenied(Argument);
        exit(false);
    end;

    local procedure RespondPermissionDenied(var Argument: Record "Message Argument ori")
    var
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign BIFROST Read ori (extended by BIFROST InvRead ori) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori (með viðbótinni BIFROST InvRead ori) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        SourceKind: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are sourceKind, documentType, documentNo, lineNo, systemId, entryNo and direction.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru sourceKind, documentType, documentNo, lineNo, systemId, entryNo og direction.';
        SourceKindMissingErr: Label 'sourceKind is required.', Comment = 'is-IS=sourceKind er nauðsynlegt.';
        SourceKindNextStepLbl: Label 'Send sourceKind: Sales, Purchase, Transfer, Assembly or ItemLedgerEntry.', Comment = 'is-IS=Sendu sourceKind: Sales, Purchase, Transfer, Assembly eða ItemLedgerEntry.';
        SourceKindErr: Label 'sourceKind is not supported.', Comment = 'is-IS=sourceKind er ekki stutt.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['sourceKind', 'documentType', 'documentNo', 'lineNo', 'systemId', 'entryNo', 'direction']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        if ReadText(RequestJson, 'sourceKind') = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, SourceKindMissingErr, 'sourceKind', '', SourceKindsTok, SourceKindNextStepLbl);
            exit(false);
        end;
        SourceKind := UpperCase(ReadText(RequestJson, 'sourceKind'));
        if not (SourceKind in ['SALES', 'PURCHASE', 'TRANSFER', 'ASSEMBLY', 'ITEMLEDGERENTRY']) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SourceKindErr, 'sourceKind', ReadText(RequestJson, 'sourceKind'), SourceKindsTok, SourceKindNextStepLbl);
            exit(false);
        end;
        if not RejectKeysOfOtherKinds(Argument, RequestJson, SourceKind) then
            exit(false);
        if not ValidateIdentifiers(Argument, RequestJson, SourceKind) then
            exit(false);
        exit(ValidateValues(Argument, RequestJson, SourceKind));
    end;

    local procedure RejectKeysOfOtherKinds(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; SourceKind: Text): Boolean
    var
        KeyNotForKindErr: Label '%1 does not apply to sourceKind %2.', Comment = '%1 = key name, %2 = source kind, is-IS=%1 á ekki við sourceKind %2.';
        KeyNotForKindNextStepLbl: Label 'Remove %1, or change sourceKind.', Comment = '%1 = key name, is-IS=Fjarlægðu %1, eða breyttu sourceKind.';
        KeyName: Text;
    begin
        case SourceKind of
            'TRANSFER':
                if RequestJson.Contains('documentType') then
                    KeyName := 'documentType'
                else
                    if RequestJson.Contains('entryNo') then
                        KeyName := 'entryNo';
            'ITEMLEDGERENTRY':
                if RequestJson.Contains('documentType') then
                    KeyName := 'documentType'
                else
                    if RequestJson.Contains('documentNo') then
                        KeyName := 'documentNo'
                    else
                        if RequestJson.Contains('lineNo') then
                            KeyName := 'lineNo'
                        else
                            if RequestJson.Contains('direction') then
                                KeyName := 'direction';
            else
                if RequestJson.Contains('entryNo') then
                    KeyName := 'entryNo'
                else
                    if RequestJson.Contains('direction') then
                        KeyName := 'direction';
        end;
        if KeyName = '' then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(KeyNotForKindErr, KeyName, CanonicalSourceKind(SourceKind)), KeyName, ReadText(RequestJson, KeyName), '', StrSubstNo(KeyNotForKindNextStepLbl, KeyName));
        exit(false);
    end;

    local procedure ValidateIdentifiers(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; SourceKind: Text): Boolean
    var
        HasSystemId: Boolean;
        ConflictErr: Label 'systemId was sent together with other identifiers.', Comment = 'is-IS=systemId var sent ásamt öðrum auðkennum.';
        ConflictNextStepLbl: Label 'Send systemId or the other identifiers, not both.', Comment = 'is-IS=Sendu systemId eða hin auðkennin, ekki hvort tveggja.';
        KeyMissingErr: Label '%1 is required.', Comment = '%1 = key name, is-IS=%1 er nauðsynlegt.';
        EntryNextStepLbl: Label 'Send entryNo or systemId.', Comment = 'is-IS=Sendu entryNo eða systemId.';
        LineNextStepLbl: Label 'Send documentNo and lineNo, or systemId.', Comment = 'is-IS=Sendu documentNo og lineNo, eða systemId.';
    begin
        HasSystemId := RequestJson.Contains('systemId');
        if HasSystemId and (RequestJson.Contains('documentType') or RequestJson.Contains('documentNo') or RequestJson.Contains('lineNo') or RequestJson.Contains('entryNo')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, 'systemId', ReadText(RequestJson, 'systemId'), '', ConflictNextStepLbl);
            exit(false);
        end;
        if HasSystemId then
            exit(true);
        if SourceKind = 'ITEMLEDGERENTRY' then begin
            if RequestJson.Contains('entryNo') then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(KeyMissingErr, 'entryNo'), 'entryNo', '', '', EntryNextStepLbl);
            exit(false);
        end;
        if not RequestJson.Contains('documentNo') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(KeyMissingErr, 'documentNo'), 'documentNo', '', '', LineNextStepLbl);
            exit(false);
        end;
        if not RequestJson.Contains('lineNo') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(KeyMissingErr, 'lineNo'), 'lineNo', '', '', LineNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateValues(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; SourceKind: Text): Boolean
    var
        SalesDocumentType: Enum "Sales Document Type";
        PurchaseDocumentType: Enum "Purchase Document Type";
        AssemblyDocumentType: Enum "Assembly Document Type";
        DocumentTypeErr: Label 'documentType is not supported for this sourceKind.', Comment = 'is-IS=documentType er ekki stutt fyrir þetta sourceKind.';
        DocumentTypeNextStepLbl: Label 'Send one of the document types in expected, or leave documentType out for Order.', Comment = 'is-IS=Sendu eina af gerðum fylgiskjala í expected, eða slepptu documentType fyrir Order.';
        DirectionErr: Label 'direction is not supported.', Comment = 'is-IS=direction er ekki stutt.';
        DirectionNextStepLbl: Label 'Send direction Outbound or Inbound, or leave it out for Outbound.', Comment = 'is-IS=Sendu direction Outbound eða Inbound, eða slepptu því fyrir Outbound.';
    begin
        if RequestJson.Contains('lineNo') and not IsInteger(RequestJson, 'lineNo') then begin
            RespondFormat(Argument, 'lineNo', ReadText(RequestJson, 'lineNo'));
            exit(false);
        end;
        if RequestJson.Contains('entryNo') and not IsInteger(RequestJson, 'entryNo') then begin
            RespondFormat(Argument, 'entryNo', ReadText(RequestJson, 'entryNo'));
            exit(false);
        end;
        if RequestJson.Contains('systemId') and not IsGuid(RequestJson, 'systemId') then begin
            RespondFormat(Argument, 'systemId', ReadText(RequestJson, 'systemId'));
            exit(false);
        end;
        if RequestJson.Contains('documentType') then
            case SourceKind of
                'SALES':
                    if not ReadSalesDocumentType(ReadText(RequestJson, 'documentType'), SalesDocumentType) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentTypeErr, 'documentType', ReadText(RequestJson, 'documentType'), SalesDocumentTypesTok, DocumentTypeNextStepLbl);
                        exit(false);
                    end;
                'PURCHASE':
                    if not ReadPurchaseDocumentType(ReadText(RequestJson, 'documentType'), PurchaseDocumentType) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentTypeErr, 'documentType', ReadText(RequestJson, 'documentType'), SalesDocumentTypesTok, DocumentTypeNextStepLbl);
                        exit(false);
                    end;
                'ASSEMBLY':
                    if not ReadAssemblyDocumentType(ReadText(RequestJson, 'documentType'), AssemblyDocumentType) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentTypeErr, 'documentType', ReadText(RequestJson, 'documentType'), AssemblyDocumentTypesTok, DocumentTypeNextStepLbl);
                        exit(false);
                    end;
            end;
        if RequestJson.Contains('direction') then
            if not (UpperCase(ReadText(RequestJson, 'direction')) in ['OUTBOUND', 'INBOUND']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DirectionErr, 'direction', ReadText(RequestJson, 'direction'), DirectionsTok, DirectionNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text)
    var
        FormatErr: Label '%1 has the wrong type.', Comment = '%1 = key name, is-IS=%1 er af rangri gerð.';
        IntegerExpectedLbl: Label 'an integer', Comment = 'is-IS=heiltala';
        GuidExpectedLbl: Label 'a GUID', Comment = 'is-IS=GUID-auðkenni';
        IntegerNextStepLbl: Label 'Send %1 as an integer.', Comment = '%1 = key name, is-IS=Sendu %1 sem heiltölu.';
        GuidNextStepLbl: Label 'Send systemId as a GUID.', Comment = 'is-IS=Sendu systemId sem GUID.';
    begin
        if KeyName = 'systemId' then
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Received, GuidExpectedLbl, GuidNextStepLbl)
        else
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Received, IntegerExpectedLbl, StrSubstNo(IntegerNextStepLbl, KeyName));
    end;

    local procedure BindSource(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; SourceKind: Text; var SourceRecord: Variant; var HasSource: Boolean): Boolean
    begin
        HasSource := true;
        case SourceKind of
            'SALES':
                exit(BindSales(Argument, RequestJson, SourceRecord, HasSource));
            'PURCHASE':
                exit(BindPurchase(Argument, RequestJson, SourceRecord, HasSource));
            'TRANSFER':
                exit(BindTransfer(Argument, RequestJson, SourceRecord));
            'ASSEMBLY':
                exit(BindAssembly(Argument, RequestJson, SourceRecord));
            'ITEMLEDGERENTRY':
                exit(BindLedger(Argument, RequestJson, SourceRecord));
        end;
        exit(false);
    end;

    local procedure BindSales(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant; var HasSource: Boolean): Boolean
    var
        SalesLine: Record "Sales Line";
        LineId: Guid;
        DocumentType: Enum "Sales Document Type";
        Found: Boolean;
    begin
        if not SalesLine.ReadPermission() then begin
            RespondPermissionDenied(Argument);
            exit(false);
        end;
        if ReadGuid(RequestJson, 'systemId', LineId) then
            Found := SalesLine.GetBySystemId(LineId)
        else begin
            DocumentType := DocumentType::Order;
            if RequestJson.Contains('documentType') then
                ReadSalesDocumentType(ReadText(RequestJson, 'documentType'), DocumentType);
            Found := SalesLine.Get(DocumentType, ReadDocumentNo(RequestJson), ReadInteger(RequestJson, 'lineNo'));
        end;
        if not Found then begin
            RespondNotFound(Argument, RequestJson);
            exit(false);
        end;
        // The base application refuses order tracking for a line that is not an item line; it has no chain.
        HasSource := SalesLine.Type = SalesLine.Type::Item;
        SourceRecord := SalesLine;
        exit(true);
    end;

    local procedure BindPurchase(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant; var HasSource: Boolean): Boolean
    var
        PurchaseLine: Record "Purchase Line";
        LineId: Guid;
        DocumentType: Enum "Purchase Document Type";
        Found: Boolean;
    begin
        if not PurchaseLine.ReadPermission() then begin
            RespondPermissionDenied(Argument);
            exit(false);
        end;
        if ReadGuid(RequestJson, 'systemId', LineId) then
            Found := PurchaseLine.GetBySystemId(LineId)
        else begin
            DocumentType := DocumentType::Order;
            if RequestJson.Contains('documentType') then
                ReadPurchaseDocumentType(ReadText(RequestJson, 'documentType'), DocumentType);
            Found := PurchaseLine.Get(DocumentType, ReadDocumentNo(RequestJson), ReadInteger(RequestJson, 'lineNo'));
        end;
        if not Found then begin
            RespondNotFound(Argument, RequestJson);
            exit(false);
        end;
        // The base application refuses order tracking for a line that is not an item line; it has no chain.
        HasSource := PurchaseLine.Type = PurchaseLine.Type::Item;
        SourceRecord := PurchaseLine;
        exit(true);
    end;

    local procedure BindTransfer(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        TransferLine: Record "Transfer Line";
        LineId: Guid;
        Found: Boolean;
    begin
        if not TransferLine.ReadPermission() then begin
            RespondPermissionDenied(Argument);
            exit(false);
        end;
        if ReadGuid(RequestJson, 'systemId', LineId) then
            Found := TransferLine.GetBySystemId(LineId)
        else
            Found := TransferLine.Get(ReadDocumentNo(RequestJson), ReadInteger(RequestJson, 'lineNo'));
        if not Found then begin
            RespondNotFound(Argument, RequestJson);
            exit(false);
        end;
        SourceRecord := TransferLine;
        exit(true);
    end;

    local procedure BindAssembly(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        AssemblyLine: Record "Assembly Line";
        LineId: Guid;
        DocumentType: Enum "Assembly Document Type";
        Found: Boolean;
    begin
        if not AssemblyLine.ReadPermission() then begin
            RespondPermissionDenied(Argument);
            exit(false);
        end;
        if ReadGuid(RequestJson, 'systemId', LineId) then
            Found := AssemblyLine.GetBySystemId(LineId)
        else begin
            DocumentType := DocumentType::Order;
            if RequestJson.Contains('documentType') then
                ReadAssemblyDocumentType(ReadText(RequestJson, 'documentType'), DocumentType);
            Found := AssemblyLine.Get(DocumentType, ReadDocumentNo(RequestJson), ReadInteger(RequestJson, 'lineNo'));
        end;
        if not Found then begin
            RespondNotFound(Argument, RequestJson);
            exit(false);
        end;
        SourceRecord := AssemblyLine;
        exit(true);
    end;

    local procedure BindLedger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        LineId: Guid;
        Found: Boolean;
    begin
        if not ItemLedgerEntry.ReadPermission() then begin
            RespondPermissionDenied(Argument);
            exit(false);
        end;
        if ReadGuid(RequestJson, 'systemId', LineId) then
            Found := ItemLedgerEntry.GetBySystemId(LineId)
        else
            Found := ItemLedgerEntry.Get(ReadInteger(RequestJson, 'entryNo'));
        if not Found then begin
            RespondNotFound(Argument, RequestJson);
            exit(false);
        end;
        SourceRecord := ItemLedgerEntry;
        exit(true);
    end;

    [TryFunction]
    local procedure TryCollectTracking(var SourceRecord: Variant; Inbound: Boolean; var Entries: JsonArray)
    var
        OrderTrackingEntry: Record "Order Tracking Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        OrderTrackingTransfer: Codeunit "Order Tracking Transfer ori";
        OrderTrackingManagement: Codeunit OrderTrackingManagement;
        SourceRef: RecordRef;
    begin
        SourceRef.GetTable(SourceRecord);
        case SourceRef.Number of
            Database::"Item Ledger Entry":
                begin
                    ItemLedgerEntry := SourceRecord;
                    OrderTrackingManagement.SetItemLedgEntry(ItemLedgerEntry);
                end;
            Database::"Transfer Line":
                begin
                    // The base application has no order tracking source for transfer lines; a bound subscriber supplies the filter.
                    OrderTrackingTransfer.SetInbound(Inbound);
                    BindSubscription(OrderTrackingTransfer);
                    OrderTrackingManagement.SetSourceRecord(SourceRecord);
                    UnbindSubscription(OrderTrackingTransfer);
                end;
            else
                OrderTrackingManagement.SetSourceRecord(SourceRecord);
        end;
        if not OrderTrackingManagement.FindRecordsWithoutMessage() then
            exit;
        if not OrderTrackingManagement.FindRecord('-', OrderTrackingEntry) then
            exit;
        repeat
            Entries.Add(EntryToJson(OrderTrackingEntry));
        until OrderTrackingManagement.GetNextRecord(1, OrderTrackingEntry) = 0;
    end;

    local procedure EntryToJson(OrderTrackingEntry: Record "Order Tracking Entry") EntryJson: JsonObject
    begin
        EntryJson.Add('level', OrderTrackingEntry.Level);
        EntryJson.Add('itemNo', OrderTrackingEntry."Item No.");
        EntryJson.Add('quantity', OrderTrackingEntry.Quantity);
        EntryJson.Add('suppliedBy', OrderTrackingEntry."Supplied by");
        EntryJson.Add('demandedBy', OrderTrackingEntry."Demanded by");
        EntryJson.Add('fromType', OrderTrackingEntry."From Type");
        EntryJson.Add('fromTypeName', TableName(OrderTrackingEntry."From Type"));
        EntryJson.Add('fromSubtype', OrderTrackingEntry."From Subtype");
        EntryJson.Add('fromNo', OrderTrackingEntry."From ID");
        EntryJson.Add('fromLineNo', OrderTrackingEntry."From Ref. No.");
        EntryJson.Add('forType', OrderTrackingEntry."For Type");
        EntryJson.Add('forTypeName', TableName(OrderTrackingEntry."For Type"));
        EntryJson.Add('forSubtype', OrderTrackingEntry."For Subtype");
        EntryJson.Add('forNo', OrderTrackingEntry."For ID");
        EntryJson.Add('forLineNo', OrderTrackingEntry."For Ref. No.");
        EntryJson.Add('shipmentDate', Format(OrderTrackingEntry."Shipment Date", 0, 9));
        EntryJson.Add('expectedReceiptDate', Format(OrderTrackingEntry."Expected Receipt Date", 0, 9));
        EntryJson.Add('startingDate', Format(OrderTrackingEntry."Starting Date", 0, 9));
        EntryJson.Add('endingDate', Format(OrderTrackingEntry."Ending Date", 0, 9));
        EntryJson.Add('warning', OrderTrackingEntry.Warning);
    end;

    local procedure TableName(TableNo: Integer): Text
    var
        RecRef: RecordRef;
        Name: Text;
    begin
        if TableNo = 0 then
            exit('');
        RecRef.Open(TableNo);
        Name := RecRef.Name();
        RecRef.Close();
        exit(Name);
    end;

    local procedure RespondNotFound(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        NotFoundErr: Label 'The source line or entry was not found.', Comment = 'is-IS=Upprunalínan eða færslan fannst ekki.';
        NotFoundNextStepLbl: Label 'Check the document and line no.', Comment = 'is-IS=Athugaðu fylgiskjalið og línunúmerið.';
    begin
        if RequestJson.Contains('systemId') then
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'systemId', ReadText(RequestJson, 'systemId'), '', NotFoundNextStepLbl)
        else
            if RequestJson.Contains('entryNo') then
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'entryNo', ReadText(RequestJson, 'entryNo'), '', NotFoundNextStepLbl)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'documentNo', ReadText(RequestJson, 'documentNo'), '', NotFoundNextStepLbl);
    end;

    local procedure CanonicalSourceKind(SourceKind: Text): Text
    begin
        case SourceKind of
            'SALES':
                exit('Sales');
            'PURCHASE':
                exit('Purchase');
            'TRANSFER':
                exit('Transfer');
            'ASSEMBLY':
                exit('Assembly');
            'ITEMLEDGERENTRY':
                exit('ItemLedgerEntry');
        end;
        exit(SourceKind);
    end;

    local procedure IsInbound(RequestJson: JsonObject): Boolean
    begin
        exit(UpperCase(ReadText(RequestJson, 'direction')) = 'INBOUND');
    end;

    local procedure ReadSalesDocumentType(DocumentTypeText: Text; var DocumentType: Enum "Sales Document Type"): Boolean
    begin
        case UpperCase(DocumentTypeText) of
            'QUOTE':
                DocumentType := DocumentType::Quote;
            'ORDER':
                DocumentType := DocumentType::Order;
            'INVOICE':
                DocumentType := DocumentType::Invoice;
            'CREDIT MEMO':
                DocumentType := DocumentType::"Credit Memo";
            'BLANKET ORDER':
                DocumentType := DocumentType::"Blanket Order";
            'RETURN ORDER':
                DocumentType := DocumentType::"Return Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure ReadPurchaseDocumentType(DocumentTypeText: Text; var DocumentType: Enum "Purchase Document Type"): Boolean
    begin
        case UpperCase(DocumentTypeText) of
            'QUOTE':
                DocumentType := DocumentType::Quote;
            'ORDER':
                DocumentType := DocumentType::Order;
            'INVOICE':
                DocumentType := DocumentType::Invoice;
            'CREDIT MEMO':
                DocumentType := DocumentType::"Credit Memo";
            'BLANKET ORDER':
                DocumentType := DocumentType::"Blanket Order";
            'RETURN ORDER':
                DocumentType := DocumentType::"Return Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure ReadAssemblyDocumentType(DocumentTypeText: Text; var DocumentType: Enum "Assembly Document Type"): Boolean
    begin
        case UpperCase(DocumentTypeText) of
            'QUOTE':
                DocumentType := DocumentType::Quote;
            'ORDER':
                DocumentType := DocumentType::Order;
            'BLANKET ORDER':
                DocumentType := DocumentType::"Blanket Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDocumentNo(RequestJson: JsonObject): Code[20]
    begin
        exit(CopyStr(ReadText(RequestJson, 'documentNo'), 1, 20));
    end;

    local procedure IsInteger(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Result: Integer;
    begin
        if not HasValue(RequestJson, KeyName) then
            exit(false);
        exit(Evaluate(Result, ReadText(RequestJson, KeyName), 9));
    end;

    local procedure IsGuid(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Result: Guid;
    begin
        if not HasValue(RequestJson, KeyName) then
            exit(false);
        exit(Evaluate(Result, ReadText(RequestJson, KeyName)));
    end;

    local procedure ReadGuid(RequestJson: JsonObject; KeyName: Text; var Result: Guid): Boolean
    begin
        if not HasValue(RequestJson, KeyName) then
            exit(false);
        exit(Evaluate(Result, ReadText(RequestJson, KeyName)));
    end;

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Result: Integer;
    begin
        if not Evaluate(Result, ReadText(RequestJson, KeyName), 9) then
            exit(0);
        exit(Result);
    end;

    local procedure HasValue(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        exit(not Token.AsValue().IsNull());
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not HasValue(RequestJson, KeyName) then
            exit('');
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
