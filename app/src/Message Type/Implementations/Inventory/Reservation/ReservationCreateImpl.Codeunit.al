namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reservation.Create: reserves supply for one source document line through Reservation Management
/// AutoReserve, bound to that line, and returns the created reservation entry numbers.
/// </summary>
codeunit 10076893 "Reservation Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        SourceExpectedLbl: Label 'An existing eligible item source line and valid reservation values.', Comment = 'is-IS=Fyrirliggjandi gjaldgeng upprunalína vöru og gild frátektargildi.';
        SourceNextStepLbl: Label 'Correct the source identifiers and quantity; read the source line before retrying.', Comment = 'is-IS=Leiðréttu upprunaauðkenni og magn; lestu upprunalínuna áður en þú reynir aftur.';


    /// <summary>Checks the Reservations domain and the native reservation permissions.</summary>
    /// <returns>True when the type can run for the current user and company.</returns>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false));
    end;

    /// <summary>Returns the reservation entry table.</summary>
    /// <returns>The table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    /// <summary>Describes the message type.</summary>
    /// <returns>The description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reserves supply for a source document line through Reservation Management.', Comment = 'is-IS=Tekur frá framboð fyrir línu upprunaskjals með Reservation Management.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns the search keywords.</summary>
    /// <returns>The keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create reservation, auto reserve, reserve item, source line', Comment = 'is-IS=búa til frátekningu, taka sjálfvirkt frá, taka vöru frá, upprunalína';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes how the source line is selected.</summary>
    /// <returns>The selection description.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Name the source line with sourceType, sourceSubtype, sourceNo and sourceLineNo (sales, purchase, transfer or assembly line).', Comment = 'is-IS=Tilgreindu upprunalínuna með sourceType, sourceSubtype, sourceNo og sourceLineNo (sölu-, innkaupa-, millifærslu- eða samsetningarlína).';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Returns the envelope contract.</summary>
    /// <param name="Envelope">The envelope.</param>
    /// <returns>True.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The source line is named in data (sourceType, sourceNo and sourceLineNo); subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Returns the target contract.</summary>
    /// <param name="Target">The target.</param>
    /// <returns>True.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.sourceType + data.sourceSubtype + data.sourceNo + data.sourceLineNo', 'table no., subtype, document no. and line no.', 'The source line to reserve for: a Sales Line (sourceType 37), Purchase Line (39), Transfer Line (5741) or Assembly Line (901). sourceSubtype is the document type ordinal, or the transfer direction (0 outbound, 1 inbound), and defaults to 1 for sales, purchase and assembly lines and to 0 for a transfer line.'));
        exit(true);
    end;

    /// <summary>Returns the request parameters.</summary>
    /// <param name="Parameters">The parameters.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SourceTypeLbl: Label 'Source table number: 37 Sales Line, 39 Purchase Line, 5741 Transfer Line, 901 Assembly Line.', Comment = 'is-IS=Númer upprunatöflu: 37 sölulína, 39 innkaupalína, 5741 millifærslulína, 901 samsetningarlína.';
        SourceSubtypeLbl: Label 'Source subtype: the sales, purchase or assembly document type ordinal (1 = Order), or the transfer direction (0 outbound, 1 inbound). Defaults to 1 for sales, purchase and assembly and 0 for transfer lines.', Comment = 'is-IS=Undirtegund uppruna: raðtala skjalategundar sölu, innkaupa eða samsetningar (1 = pöntun), eða stefna millifærslu (0 út, 1 inn). Sjálfgefið 1 fyrir sölu, innkaup og samsetningu og 0 fyrir millifærslulínur.';
        SourceNoLbl: Label 'Source document number.', Comment = 'is-IS=Númer upprunaskjals.';
        SourceLineNoLbl: Label 'Source document line number.', Comment = 'is-IS=Línunúmer upprunaskjals.';
        QuantityLbl: Label 'Quantity to reserve, in the source line unit of measure. Greater than 0.', Comment = 'is-IS=Magn til frátekningar, í mælieiningu upprunalínunnar. Stærra en 0.';
        ItemNoLbl: Label 'Optional item number; must match the source line when sent.', Comment = 'is-IS=Valfrjálst vörunúmer; verður að passa við upprunalínuna ef það er sent.';
        LocationCodeLbl: Label 'Optional location code; must match the source line location when sent.', Comment = 'is-IS=Valfrjáls staðsetningarkóði; verður að passa við staðsetningu upprunalínunnar ef hann er sendur.';
    begin
        Parameters.Add(ContractMgt.Parameter('sourceType', 'integer', true, SourceTypeLbl));
        Parameters.Add(ContractMgt.Parameter('sourceSubtype', 'integer', false, SourceSubtypeLbl));
        Parameters.Add(ContractMgt.Parameter('sourceNo', 'string', true, SourceNoLbl));
        Parameters.Add(ContractMgt.Parameter('sourceLineNo', 'integer', true, SourceLineNoLbl));
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', true, QuantityLbl));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, LocationCodeLbl));
        exit(true);
    end;

    /// <summary>Returns the response contract.</summary>
    /// <param name="Response">The response.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success when at least one reservation entry was created.', Comment = 'is-IS=Success þegar a.m.k. ein frátekningarfærsla var búin til.';
        EntryNoLbl: Label 'First created reservation entry number. Pass it to Inventory.Reservation.Cancel.', Comment = 'is-IS=Númer fyrstu frátekningarfærslunnar sem var búin til. Sendu það í Inventory.Reservation.Cancel.';
        EntryNosLbl: Label 'All created reservation entry numbers (one per reserved supply).', Comment = 'is-IS=Öll númer frátekningarfærslna sem voru búnar til (eitt fyrir hvert frátekið framboð).';
        QuantityLbl: Label 'Quantity reserved by this call, in the source line unit of measure.', Comment = 'is-IS=Magn sem þetta kall tók frá, í mælieiningu upprunalínunnar.';
        FullLbl: Label 'True when the full requested quantity was reserved.', Comment = 'is-IS=True þegar allt umbeðið magn var tekið frá.';
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', EntryNoLbl));
        Fields.Add(ContractMgt.ResponseField('entryNos', 'array', EntryNosLbl));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number of the source line.'));
        Fields.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code of the source line; blank when the line has none.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', QuantityLbl));
        Fields.Add(ContractMgt.ResponseField('requestedQuantity', 'decimal', 'The quantity that was asked for, as sent.'));
        Fields.Add(ContractMgt.ResponseField('fullAutoReservation', 'boolean', FullLbl));
        Fields.Add(ContractMgt.ResponseField('sourceType', 'integer', 'The source table number, as sent.'));
        Fields.Add(ContractMgt.ResponseField('sourceSubtype', 'integer', 'The source subtype that was used, including the default.'));
        Fields.Add(ContractMgt.ResponseField('sourceNo', 'string', 'The source document number, in upper case.'));
        Fields.Add(ContractMgt.ResponseField('sourceLineNo', 'integer', 'The source line number, as sent.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the error contract.</summary>
    /// <param name="Errors">The errors.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'sourceType, sourceNo, sourceLineNo or quantity is missing.', Comment = 'is-IS=sourceType, sourceNo, sourceLineNo eða quantity vantar.';
        MissingFixLbl: Label 'Name the source table, document, line and the quantity to reserve.', Comment = 'is-IS=Tilgreindu upprunatöflu, skjal, línu og magn til frátekningar.';
        NotFoundWhenLbl: Label 'The source line does not exist.', Comment = 'is-IS=Upprunalínan er ekki til.';
        NotFoundFixLbl: Label 'Check sourceType, sourceSubtype, sourceNo and sourceLineNo.', Comment = 'is-IS=Athugaðu sourceType, sourceSubtype, sourceNo og sourceLineNo.';
        InvalidWhenLbl: Label 'Unsupported sourceType or sourceSubtype, quantity not above 0, or itemNo/locationCode differ from the source line.', Comment = 'is-IS=Óstudd sourceType eða sourceSubtype, quantity ekki yfir 0, eða itemNo/locationCode stemma ekki við upprunalínuna.';
        InvalidFixLbl: Label 'Correct the indicated parameter.', Comment = 'is-IS=Leiðréttu viðkomandi færibreytu.';
        NothingWhenLbl: Label 'No supply is available, so nothing was reserved.', Comment = 'is-IS=Ekkert framboð er tiltækt svo ekkert var tekið frá.';
        NothingFixLbl: Label 'Check inventory or incoming supply at the source location, then retry.', Comment = 'is-IS=Athugaðu birgðir eða væntanlegt framboð á staðsetningunni og reyndu aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several source identifiers or values are missing or invalid.', 'Correct every errors[] entry before retrying; nothing is reserved.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'sourceType, sourceSubtype or sourceLineNo is not a whole number of 0 or more, quantity is not a number, or sourceNo, itemNo or locationCode is not text within 20, 20 and 10 characters (sourceNo must not be blank).', 'Send the integers as JSON numbers and the codes as JSON strings within their length.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source line is not an item line, or the Reservations domain is turned off for the company.', 'Reserve for an item line, or turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NothingWhenLbl, NothingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change reservation entries.', 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change reservation entries.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native reservation error text.', 'Business Central refuses the reservation while it runs; the answer carries its text.', 'Read the error text and correct the source line or the supply it names.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The sales source item or line cannot be reserved: non-inventory item, Reserve Never, drop shipment, special order or missing shipment date.', 'Correct the source line reservation settings and retry.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract.</summary>
    /// <param name="Effect">The effect.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Reservations domain is turned on in Inventory Setup.');
        Preconditions.Add('The source line exists and is an item line that has supply to reserve from.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates reservation entries that tie the source line to available supply, and commits them when the call finishes. Nothing is posted; the source documents and the ledger entries stay as they are.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    /// <summary>No metering override.</summary>
    /// <param name="Metering">The metering.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the related message types.</summary>
    /// <param name="Related">The related types.</param>
    /// <returns>True.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read reservations before creating one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a reservation instead of creating one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.AutoReserve', 'Reserve the whole outstanding quantity of a sales order line without naming a quantity; it reserves all or nothing.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.OrderTracking.Get', 'Read which supply is tracked against the source line after reserving.'));
        exit(true);
    end;

    /// <summary>No workflow.</summary>
    /// <param name="Workflow">The workflow.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reservation.Get', 'Read the reservations that already exist before reserving.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reservation.Create', 'Reserve supply for the source line and keep entryNo from the answer.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.OrderTracking.Get', 'Read which supply is now tracked against the line.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reservation.Cancel', 'Cancel a reservation by its entryNo when it is no longer wanted.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Returns a request example.</summary>
    /// <param name="Examples">The examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(
            'Reserve 5 units for sales order line 10000. Replace the identifiers with your own.',
            '{"type":"Inventory.Reservation.Create","data":{"sourceType":37,"sourceSubtype":1,"sourceNo":"S-ORD101001","sourceLineNo":10000,"quantity":5}}',
            '{"status":"Success","entryNo":120,"entryNos":[120],"itemNo":"1000","locationCode":"BLUE","quantity":5,"requestedQuantity":5,"fullAutoReservation":true,"sourceType":37,"sourceSubtype":1,"sourceNo":"S-ORD101001","sourceLineNo":10000}'));
        exit(true);
    end;

    /// <summary>Returns the overview.</summary>
    /// <param name="Overview">The overview.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reserves supply for one real source line with the same automatic reservation as the Auto Reserve action and returns the reservation entry numbers.', Comment = 'is-IS=Tekur frá framboð fyrir eina raunverulega upprunalínu með sömu sjálfvirku frátekningu og aðgerðin Taka sjálfvirkt frá og skilar númerum frátekningarfærslnanna.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Returns the notes.</summary>
    /// <param name="Notes">The notes.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Sales source lines use the same item/line eligibility as AutoReserve: inventory items only, neither item nor line Reserve set to Never, no drop shipment or special order, and a shipment date is required. Auto Reserve picks the supply, as the Auto Reserve action does, and reserves at most the requested quantity. A partial reservation still answers Success with fullAutoReservation false; when nothing is available the answer is PreconditionFailed and nothing is written. quantity is in the unit of measure of the source line. sourceNo, itemNo and locationCode are converted to upper case; itemNo and locationCode only check the source line. sourceSubtype defaults to 1 (Order) for sales, purchase and assembly lines and to 0 (outbound) for a transfer line. Bifrost commits the reservation when the call finishes; under Omit Commit the caller''s transaction commits instead. Read reservations with Inventory.Reservation.Get and cancel an entry with Inventory.Reservation.Cancel.', Comment = 'is-IS=Söluupprunalínur fylgja sömu reglum um frátekningu og AutoReserve: aðeins birgðavörur, hvorki vara né lína með frátekningu Aldrei, engin bein afhending eða sérpöntun og afhendingardagur er nauðsynlegur. Sjálfvirk frátekning velur framboðið, eins og aðgerðin Taka sjálfvirkt frá, og tekur að hámarki frá umbeðið magn. Hlutafrátekning svarar samt Success með fullAutoReservation false; þegar ekkert framboð er tiltækt er svarið PreconditionFailed og ekkert er skrifað. quantity er í mælieiningu upprunalínunnar. sourceNo, itemNo og locationCode eru umbreytt í hástafi; itemNo og locationCode athuga aðeins upprunalínuna. sourceSubtype er sjálfgefið 1 (pöntun) fyrir sölu-, innkaupa- og samsetningarlínur og 0 (út) fyrir millifærslulínu. Bifrost vistar frátekninguna þegar kallinu lýkur; með Omit Commit vistar kallandinn færsluna í staðinn. Lestu frátekningar með Inventory.Reservation.Get og afturkallaðu færslu með Inventory.Reservation.Cancel.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Reservation requests use inbound dispatch.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the source line and reserves through the isolated write process.</summary>
    /// <param name="Argument">The message argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Reader: Codeunit "Request Value Reader ori";
        Process: Codeunit "Inventory Write Process ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        EntryNos: JsonArray;
        EntryNoToken: JsonToken;
        ItemNo: Text;
        LocationCode: Text;
        SourceNoText: Text;
        Description: Text[100];
        ReadOk: Boolean;
        Quantity: Decimal;
        QtyPerUOM: Decimal;
        ReservedQuantity: Decimal;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceLineNo: Integer;
        LastEntryNo: Integer;
        AvailabilityDate: Date;
        QuantityPositiveErr: Label 'quantity must be greater than zero.', Comment = 'is-IS=quantity verður að vera stærra en núll.';
        QuantityExpectedTok: Label 'a quantity greater than 0', Comment = 'is-IS=magn stærra en 0';
        NothingReservedErr: Label 'No reservation entry was created for the source line. No supply is available to reserve.', Comment = 'is-IS=Engin frátekningarfærsla var búin til fyrir upprunalínuna. Ekkert framboð er tiltækt til frátekningar.';
        NothingReservedExpectedTok: Label 'available supply for the source line', Comment = 'is-IS=tiltækt framboð fyrir upprunalínuna';
        NothingReservedNextStepTok: Label 'Check inventory at the source location, then retry Inventory.Reservation.Create.', Comment = 'is-IS=Athugaðu birgðir á staðsetningu upprunalínunnar og reyndu svo Inventory.Reservation.Create aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        ReadOk := ReadInteger(Argument, RequestJson, 'sourceType', true, SourceType);
        SourceSubtype := DefaultSourceSubtype(SourceType);
        if not ReadInteger(Argument, RequestJson, 'sourceSubtype', false, SourceSubtype) then
            ReadOk := false;
        if not ReadCode(Argument, RequestJson, 'sourceNo', true, 20, SourceNoText) then
            ReadOk := false;
        if not ReadInteger(Argument, RequestJson, 'sourceLineNo', true, SourceLineNo) then
            ReadOk := false;
        if not RequestJson.Contains('quantity') then begin
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, QuantityPositiveErr, 'quantity', '<missing>', QuantityExpectedTok, SourceNextStepLbl);
            ReadOk := false;
        end else
        if not Reader.TryReadDecimal(Argument, RequestJson, 'quantity', true, Quantity) then
            ReadOk := false
        else
            if Quantity <= 0 then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, QuantityPositiveErr, 'quantity', Format(Quantity, 0, 9), QuantityExpectedTok, SourceNextStepLbl);
        if not ReadCode(Argument, RequestJson, 'itemNo', false, 20, ItemNo) then
            ReadOk := false;
        if not ReadCode(Argument, RequestJson, 'locationCode', false, 10, LocationCode) then
            ReadOk := false;
        if Parts.RespondToProblems(Argument) or not ReadOk then
            exit;
        if not ReadSourceLine(Argument, SourceType, SourceSubtype, CopyStr(SourceNoText, 1, 20), SourceLineNo, ItemNo, LocationCode, AvailabilityDate, QtyPerUOM, Description) then
            exit;
        if AvailabilityDate = 0D then
            AvailabilityDate := WorkDate();

        ReservationEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        ReservationEntry.SetLoadFields("Entry No.");
        if ReservationEntry.FindLast() then
            LastEntryNo := ReservationEntry."Entry No.";
        Process.SetOperation('ReservationCreate');
        Process.SetReservation(SourceType, SourceSubtype, CopyStr(SourceNoText, 1, 20), SourceLineNo, Quantity, Round(Quantity * QtyPerUOM, 0.00001), AvailabilityDate, Description);
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'sourceNo', SourceNoText, SourceExpectedLbl, SourceNextStepLbl);
                exit;
            end;

        ReservationEntry.Reset();
        ReservationEntry.SetFilter("Entry No.", '>%1', LastEntryNo);
        ReservationEntry.SetRange("Source Type", SourceType);
        ReservationEntry.SetRange("Source Subtype", SourceSubtype);
        ReservationEntry.SetRange("Source ID", CopyStr(SourceNoText, 1, 20));
        ReservationEntry.SetRange("Source Ref. No.", SourceLineNo);
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        ReservationEntry.SetLoadFields("Entry No.", Quantity);
        if ReservationEntry.FindSet() then
            repeat
                EntryNos.Add(ReservationEntry."Entry No.");
                ReservedQuantity += Abs(ReservationEntry.Quantity);
            until ReservationEntry.Next() = 0;
        if EntryNos.Count() = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NothingReservedErr, 'quantity', Format(Quantity, 0, 9), NothingReservedExpectedTok, NothingReservedNextStepTok);
            exit;
        end;

        EntryNos.Get(0, EntryNoToken);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNoToken.AsValue().AsInteger());
        ResponseJson.Add('entryNos', EntryNos);
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('locationCode', LocationCode);
        ResponseJson.Add('quantity', ReservedQuantity);
        ResponseJson.Add('requestedQuantity', Quantity);
        ResponseJson.Add('fullAutoReservation', Process.GetFullAutoReservation());
        ResponseJson.Add('sourceType', SourceType);
        ResponseJson.Add('sourceSubtype', SourceSubtype);
        ResponseJson.Add('sourceNo', SourceNoText);
        ResponseJson.Add('sourceLineNo', SourceLineNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure DefaultSourceSubtype(SourceType: Integer): Integer
    begin
        // Sales, purchase and assembly default to Order; a transfer line defaults to the outbound side.
        if SourceType in [Database::"Sales Line", Database::"Purchase Line", Database::"Assembly Line"] then
            exit(1);
        exit(0);
    end;

    local procedure ReadSourceLine(var Argument: Record "Message Argument ori"; SourceType: Integer; SourceSubtype: Integer; SourceNo: Code[20]; SourceLineNo: Integer; var ItemNo: Text; var LocationCode: Text; var AvailabilityDate: Date; var QtyPerUOM: Decimal; var Description: Text[100]): Boolean
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        AssemblyLine: Record "Assembly Line";
        ReservationPolicy: Codeunit "Reserv. AutoReserve Proc ori";
        SourceItemNo: Code[20];
        SourceLocationCode: Code[10];
        Found: Boolean;
        UnsupportedSourceErr: Label 'sourceType %1 is not a supported reservation source. Use 37 (Sales Line), 39 (Purchase Line), 5741 (Transfer Line) or 901 (Assembly Line).', Comment = '%1 = source table number; is-IS=sourceType %1 er ekki studdur frátekningaruppruni. Notaðu 37 (sölulína), 39 (innkaupalína), 5741 (millifærslulína) eða 901 (samsetningarlína).';
        UnsupportedSourceExpectedTok: Label '37, 39, 5741 or 901', Locked = true;
        SubtypeErr: Label 'sourceSubtype %1 is not valid for sourceType %2.', Comment = '%1 = subtype; %2 = source table number; is-IS=sourceSubtype %1 á ekki við sourceType %2.';
        SourceNotFoundErr: Label 'Source line %1 %2 %3 was not found.', Comment = '%1 = source table number; %2 = document number; %3 = line number; is-IS=Upprunalína %1 %2 %3 fannst ekki.';
        NotItemErr: Label 'Source line %1 %2 %3 is not an item line.', Comment = '%1 = source table number; %2 = document number; %3 = line number; is-IS=Upprunalína %1 %2 %3 er ekki vörulína.';
        ItemMismatchErr: Label 'itemNo %1 does not match the source line item %2.', Comment = '%1 = requested item; %2 = source item; is-IS=itemNo %1 passar ekki við vöru upprunalínunnar %2.';
        LocationMismatchErr: Label 'locationCode %1 does not match the source line location %2.', Comment = '%1 = requested location; %2 = source location; is-IS=locationCode %1 passar ekki við staðsetningu upprunalínunnar %2.';
    begin
        QtyPerUOM := 1;
        case SourceType of
            Database::"Sales Line":
                begin
                    if not Enum::"Sales Document Type".Ordinals().Contains(SourceSubtype) then
                        exit(RespondSubtype(Argument, SubtypeErr, SourceSubtype, SourceType));
                    SalesLine.SetLoadFields(Type, "No.", "Location Code", "Qty. per Unit of Measure", "Shipment Date", Description, Reserve, "Drop Shipment", "Special Order");
                    Found := SalesLine.Get(Enum::"Sales Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    if Found then begin
                        if SalesLine.Type <> SalesLine.Type::Item then
                            exit(RespondNotItem(Argument, NotItemErr, SourceType, SourceNo, SourceLineNo));
                        if not ReservationPolicy.CheckSalesLinePolicy(Argument, SalesLine) then
                            exit(false);
                        SourceItemNo := SalesLine."No.";
                        SourceLocationCode := SalesLine."Location Code";
                        QtyPerUOM := SalesLine."Qty. per Unit of Measure";
                        AvailabilityDate := SalesLine."Shipment Date";
                        Description := SalesLine.Description;
                    end;
                end;
            Database::"Purchase Line":
                begin
                    if not Enum::"Purchase Document Type".Ordinals().Contains(SourceSubtype) then
                        exit(RespondSubtype(Argument, SubtypeErr, SourceSubtype, SourceType));
                    PurchaseLine.SetLoadFields(Type, "No.", "Location Code", "Qty. per Unit of Measure", "Expected Receipt Date", Description);
                    Found := PurchaseLine.Get(Enum::"Purchase Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    if Found then begin
                        if PurchaseLine.Type <> PurchaseLine.Type::Item then
                            exit(RespondNotItem(Argument, NotItemErr, SourceType, SourceNo, SourceLineNo));
                        SourceItemNo := PurchaseLine."No.";
                        SourceLocationCode := PurchaseLine."Location Code";
                        QtyPerUOM := PurchaseLine."Qty. per Unit of Measure";
                        AvailabilityDate := PurchaseLine."Expected Receipt Date";
                        Description := PurchaseLine.Description;
                    end;
                end;
            Database::"Transfer Line":
                begin
                    if not (SourceSubtype in [0, 1]) then
                        exit(RespondSubtype(Argument, SubtypeErr, SourceSubtype, SourceType));
                    TransferLine.SetLoadFields("Item No.", "Transfer-from Code", "Transfer-to Code", "Qty. per Unit of Measure", "Shipment Date", "Receipt Date", Description);
                    Found := TransferLine.Get(SourceNo, SourceLineNo);
                    if Found then begin
                        SourceItemNo := TransferLine."Item No.";
                        QtyPerUOM := TransferLine."Qty. per Unit of Measure";
                        Description := TransferLine.Description;
                        if SourceSubtype = 1 then begin
                            SourceLocationCode := TransferLine."Transfer-to Code";
                            AvailabilityDate := TransferLine."Receipt Date";
                        end else begin
                            SourceLocationCode := TransferLine."Transfer-from Code";
                            AvailabilityDate := TransferLine."Shipment Date";
                        end;
                    end;
                end;
            Database::"Assembly Line":
                begin
                    if not Enum::"Assembly Document Type".Ordinals().Contains(SourceSubtype) then
                        exit(RespondSubtype(Argument, SubtypeErr, SourceSubtype, SourceType));
                    AssemblyLine.SetLoadFields(Type, "No.", "Location Code", "Qty. per Unit of Measure", "Due Date", Description);
                    Found := AssemblyLine.Get(Enum::"Assembly Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    if Found then begin
                        if AssemblyLine.Type <> AssemblyLine.Type::Item then
                            exit(RespondNotItem(Argument, NotItemErr, SourceType, SourceNo, SourceLineNo));
                        SourceItemNo := AssemblyLine."No.";
                        SourceLocationCode := AssemblyLine."Location Code";
                        QtyPerUOM := AssemblyLine."Qty. per Unit of Measure";
                        AvailabilityDate := AssemblyLine."Due Date";
                        Description := AssemblyLine.Description;
                    end;
                end;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnsupportedSourceErr, SourceType), 'sourceType', Format(SourceType, 0, 9), UnsupportedSourceExpectedTok, SourceNextStepLbl);
                exit(false);
            end;
        end;
        if not Found then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SourceNotFoundErr, SourceType, SourceNo, SourceLineNo), 'sourceLineNo', Format(SourceLineNo, 0, 9), SourceExpectedLbl, SourceNextStepLbl);
            exit(false);
        end;
        if (ItemNo <> '') and (ItemNo <> SourceItemNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ItemMismatchErr, ItemNo, SourceItemNo), 'itemNo', ItemNo, SourceItemNo, SourceNextStepLbl);
            exit(false);
        end;
        if (LocationCode <> '') and (LocationCode <> SourceLocationCode) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(LocationMismatchErr, LocationCode, SourceLocationCode), 'locationCode', LocationCode, SourceLocationCode, SourceNextStepLbl);
            exit(false);
        end;
        ItemNo := SourceItemNo;
        LocationCode := SourceLocationCode;
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;
        exit(true);
    end;

    local procedure RespondSubtype(var Argument: Record "Message Argument ori"; SubtypeErr: Text; SourceSubtype: Integer; SourceType: Integer): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(SubtypeErr, SourceSubtype, SourceType), 'sourceSubtype', Format(SourceSubtype, 0, 9), SourceExpectedLbl, SourceNextStepLbl);
        exit(false);
    end;

    local procedure RespondNotItem(var Argument: Record "Message Argument ori"; NotItemErr: Text; SourceType: Integer; SourceNo: Code[20]; SourceLineNo: Integer): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NotItemErr, SourceType, SourceNo, SourceLineNo), 'sourceLineNo', Format(SourceLineNo, 0, 9), SourceExpectedLbl, SourceNextStepLbl);
        exit(false);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; var Value: Integer): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Number: Decimal;
        MissingErr: Label '%1 is required.', Comment = '%1 = parameter name; is-IS=%1 er nauðsynlegt.';
        FormatErr: Label '%1 must be a whole number of 0 or more.', Comment = '%1 = parameter name; is-IS=%1 verður að vera heiltala, 0 eða stærri.';
        IntegerExpectedTok: Label 'a JSON integer', Comment = 'is-IS=JSON-heiltala';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), KeyName, '<missing>', IntegerExpectedTok, SourceNextStepLbl);
            exit(not Required);
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or Serialized.StartsWith('"') or not Evaluate(Number, Serialized, 9) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Serialized, IntegerExpectedTok, SourceNextStepLbl);
            exit(false);
        end;
        if (Number <> Round(Number, 1)) or (Number < 0) or (Number > 2147483647) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Serialized, IntegerExpectedTok, SourceNextStepLbl);
            exit(false);
        end;
        Value := Number;
        exit(true);
    end;

    local procedure ReadCode(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; MaxLength: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Raw: Text;
        MissingErr: Label '%1 is required.', Comment = '%1 = parameter name; is-IS=%1 er nauðsynlegt.';
        FormatErr: Label '%1 must be text of at most %2 characters.', Comment = '%1 = parameter name; %2 = maximum length; is-IS=%1 verður að vera texti að hámarki %2 stafir.';
        StringExpectedTok: Label 'a JSON string', Comment = 'is-IS=JSON-strengur';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), KeyName, '<missing>', StringExpectedTok, SourceNextStepLbl);
            exit(not Required);
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName, MaxLength), KeyName, Serialized, StringExpectedTok, SourceNextStepLbl);
            exit(false);
        end;
        Raw := Token.AsValue().AsText();
        if (StrLen(Raw) > MaxLength) or (Required and (Raw = '')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName, MaxLength), KeyName, Raw, StringExpectedTok, SourceNextStepLbl);
            exit(false);
        end;
        Value := UpperCase(Raw);
        exit(true);
    end;
}
