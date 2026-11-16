namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 10076894 "Reservation Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads reservation entries for an item, a source line or one entry number.', Comment = 'is-IS=Les frátekningarfærslur fyrir vöru, upprunalínu eða eitt færslunúmer.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reservation, reserved quantity', Comment = 'is-IS=frátekning, frátekið magn';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads reservation entries by item (subject or itemNo), by source line (sourceType, sourceNo and optionally sourceSubtype and sourceLineNo) or by entryNo. Cancel is a separate type.', Comment = 'is-IS=Les frátekningarfærslur eftir vöru (subject eða itemNo), eftir upprunalínu (sourceType, sourceNo og valfrjálst sourceSubtype og sourceLineNo) eða eftir entryNo. Afturköllun er aðskilin tegund.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Forms.Add('item no.');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The No. of the Item whose reservation entries are read; data.itemNo is used when subject is blank, and with neither every reservation entry is read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item; it takes precedence over data.itemNo. A subject and a data.itemNo that name different items are refused.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item, used when subject is blank. Leave both out to read the reservation entries of every item.'));
        Target.Add(ContractMgt.TargetEntry('data.sourceType + data.sourceSubtype + data.sourceNo + data.sourceLineNo', 'table no., subtype, document no. and line no.', 'The source line whose reservation entries are read, for any source the Reserve action supports (for example 37 Sales Line, 39 Purchase Line, 5741 Transfer Line, 901 Assembly Line, 5902 Service Line, 5406 Prod. Order Line, 5407 Prod. Order Component, 83 Item Journal Line, 32 Item Ledger Entry). sourceType and sourceNo go together; sourceSubtype and sourceLineNo narrow the read when sent.'));
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'reservation entry no.', 'One reservation entry number; both entries that share it are returned. An entry number that does not exist is refused as RecordNotFound.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoDescriptionTxt: Label 'Item number. The message subject is the same item number when this key is omitted. Without either, every reservation entry is returned.', Comment = 'is-IS=Vörunúmer. Subject er sama vörunúmer þegar lykillinn er ekki sendur. Án beggja eru allar frátekningarfærslur skilaðar.';
        EntryNoDescriptionTxt: Label 'Optional reservation entry number. Returns the entries with that number; an unknown number is refused as RecordNotFound.', Comment = 'is-IS=Valfrjálst númer frátekningarfærslu. Skilar færslunum með því númeri; óþekktu númeri er hafnað sem RecordNotFound.';
        SourceTypeDescriptionTxt: Label 'Optional source table number, for example 37 Sales Line, 39 Purchase Line, 5741 Transfer Line or 901 Assembly Line. Send it together with sourceNo.', Comment = 'is-IS=Valfrjálst númer upprunatöflu, til dæmis 37 sölulína, 39 innkaupalína, 5741 millifærslulína eða 901 samsetningarlína. Sendu það ásamt sourceNo.';
        SourceSubtypeDescriptionTxt: Label 'Optional source subtype: the document type ordinal (1 = Order), or the transfer direction (0 outbound, 1 inbound). Every subtype is read when it is left out.', Comment = 'is-IS=Valfrjáls undirtegund uppruna: raðtala skjalategundar (1 = pöntun), eða stefna millifærslu (0 út, 1 inn). Allar undirtegundir eru lesnar ef hún er ekki send.';
        SourceNoDescriptionTxt: Label 'Optional source document number (Source ID). Send it together with sourceType.', Comment = 'is-IS=Valfrjálst númer upprunaskjals (Source ID). Sendu það ásamt sourceType.';
        SourceLineNoDescriptionTxt: Label 'Optional source line number (Source Ref. No.). Every line of the document is read when it is left out.', Comment = 'is-IS=Valfrjálst línunúmer uppruna (Source Ref. No.). Allar línur skjalsins eru lesnar ef það er ekki sent.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoDescriptionTxt));
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', false, EntryNoDescriptionTxt));
        Parameters.Add(ContractMgt.Parameter('sourceType', 'integer', false, SourceTypeDescriptionTxt));
        Parameters.Add(ContractMgt.Parameter('sourceSubtype', 'integer', false, SourceSubtypeDescriptionTxt));
        Parameters.Add(ContractMgt.Parameter('sourceNo', 'string', false, SourceNoDescriptionTxt));
        Parameters.Add(ContractMgt.Parameter('sourceLineNo', 'integer', false, SourceLineNoDescriptionTxt));
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the reservation entries were read.'));
        EntryFields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number of the reservation entry.'));
        EntryFields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the entry.'));
        EntryFields.Add(ContractMgt.ResponseField('locationCode', 'string', 'The location code of the entry.'));
        EntryFields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The signed quantity of the entry in the unit of the line; positive on the supply side, negative on the demand side.'));
        EntryFields.Add(ContractMgt.ResponseField('reservationStatus', 'string', 'Reservation, Tracking, Surplus or Prospect.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceId', 'string', 'The document number of the source the entry belongs to.'));
        EntryFields.Add(ContractMgt.ResponseField('variantCode', 'string', 'The variant code of the entry.'));
        EntryFields.Add(ContractMgt.ResponseField('quantityBase', 'decimal', 'The signed quantity of the entry in the base unit of measure.'));
        EntryFields.Add(ContractMgt.ResponseField('positive', 'boolean', 'True on the supply side of the pair, false on the demand side.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceType', 'integer', 'The source table number of the entry, for example 37 for a sales line or 32 for an item ledger entry.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceSubtype', 'integer', 'The source subtype ordinal: the document type, or the transfer direction.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceBatchName', 'string', 'The journal batch name when the source is a journal line; blank otherwise.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceProdOrderLine', 'integer', 'The production order line number when the source is a production order component; 0 otherwise.'));
        EntryFields.Add(ContractMgt.ResponseField('sourceRefNo', 'integer', 'The source line number (Source Ref. No.), or the item ledger entry number when the source is inventory.'));
        EntryFields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number on the entry; blank when none.'));
        EntryFields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number on the entry; blank when none.'));
        EntryFields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number on the entry; blank when none.'));
        EntryFields.Add(ContractMgt.ResponseField('expectedReceiptDate', 'date', 'The expected receipt date of the supply side; blank when none.'));
        EntryFields.Add(ContractMgt.ResponseField('shipmentDate', 'date', 'The shipment date of the demand side; blank when none.'));
        EntryFields.Add(ContractMgt.ResponseField('creationDate', 'date', 'The date the entry was created.'));
        EntriesField := ContractMgt.ResponseField('entries', 'array', 'The reservation entries that match every filter that was sent (item, source line, entry number), or every entry when none was sent, in entry number order. The array is empty when nothing matches.');
        EntriesField.Add('children', EntryFields);
        Fields.Add(EntriesField);
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        ContractParts.AddItemNoSubjectErrors(Errors, false);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'entryNo, sourceType, sourceSubtype or sourceLineNo is not a whole number of 0 or more (entryNo above 0), or sourceNo is not text of at most 20 characters.', 'Send the integers as JSON numbers and sourceNo as a JSON string.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Only one of sourceType and sourceNo was sent, or sourceSubtype or sourceLineNo was sent without them.', 'Send sourceType and sourceNo together to read a source line.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No reservation entry has the entryNo that was sent.', 'Read the entries by item or source line, or use the entryNo that Inventory.Reservation.Create returned.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Reservations domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read the Reservation Entry table.');
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing. The reservation entries are read as they are; nothing is reserved, cancelled or posted.');
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
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a reservation instead of reading it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Create', 'Create a reservation instead of reading reservations.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(
            'Read the reservation entries of item 1000',
            '{"type":"Inventory.Reservation.Get","subject":"1000"}',
            '{"status":"Success","entries":[{"entryNo":101,"itemNo":"1000","locationCode":"BLUE","quantity":-5,"reservationStatus":"Reservation","sourceId":"101005"}]}'));
        Examples.Add(ContractMgt.Example(
            'Read the reservation entries of sales order line 10000. Replace the identifiers with your own.',
            '{"type":"Inventory.Reservation.Get","data":{"sourceType":37,"sourceSubtype":1,"sourceNo":"101005","sourceLineNo":10000}}',
            '{"status":"Success","entries":[{"entryNo":101,"itemNo":"1000","locationCode":"BLUE","quantity":-5,"reservationStatus":"Reservation","sourceId":"101005","variantCode":"","quantityBase":-5,"positive":false,"sourceType":37,"sourceSubtype":1,"sourceBatchName":"","sourceProdOrderLine":0,"sourceRefNo":10000,"lotNo":"","serialNo":"","packageNo":"","expectedReceiptDate":"","shipmentDate":"2026-11-20","creationDate":"2026-11-16"}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewTxt: Label 'Reads reservation entries for the item named by data.itemNo or subject, for one source line, or for one entry number, or every entry when nothing is sent.', Comment = 'is-IS=Les frátekningarfærslur fyrir vöruna sem data.itemNo eða subject nefnir, fyrir eina upprunalínu eða eitt færslunúmer, eða allar færslur þegar ekkert er sent.';
    begin
        Overview := OverviewTxt;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesTxt: Label 'Read only. Cancel is a separate message type. data.itemNo or subject limits the entries to that item; sourceType with sourceNo (and optionally sourceSubtype and sourceLineNo) limits them to one source document or line; entryNo limits them to one reservation pair. Filters that are sent together all apply. Quantities keep the sign Business Central stores: negative on the demand side, positive on the supply side. Dates are ISO dates, blank when not set.', Comment = 'is-IS=Aðeins lestur. Afturköllun er sérstök skilaboðategund. data.itemNo eða subject takmarkar færslurnar við þá vöru; sourceType með sourceNo (og valfrjálst sourceSubtype og sourceLineNo) takmarkar þær við eitt upprunaskjal eða línu; entryNo takmarkar þær við eitt frátekningarpar. Allar síur sem eru sendar saman gilda. Magn heldur formerkinu sem Business Central geymir: neikvætt á eftirspurnarhlið, jákvætt á framboðshlið. Dagsetningar eru ISO-dagsetningar, auðar ef þær eru ekki skráðar.';
    begin
        Notes := NotesTxt;
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ContractParts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        ItemNo: Code[20];
        SourceNo: Text;
        EntryNo: Integer;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceLineNo: Integer;
        HasEntryNo: Boolean;
        HasSourceType: Boolean;
        HasSourceSubtype: Boolean;
        HasSourceNo: Boolean;
        HasSourceLineNo: Boolean;
        EntryNotFoundErr: Label 'Reservation entry %1 was not found.', Comment = '%1 = entry number; is-IS=Frátekningarfærsla %1 fannst ekki.';
        EntryExpectedTok: Label 'an existing reservation entry number', Comment = 'is-IS=númer frátekningarfærslu sem er til';
        EntryNextStepLbl: Label 'Read the entries by item or source line, or use the entryNo that Inventory.Reservation.Create returned.', Comment = 'is-IS=Lestu færslurnar eftir vöru eða upprunalínu, eða notaðu entryNo sem Inventory.Reservation.Create skilaði.';
        SourcePairErr: Label 'sourceType and sourceNo must be sent together to read a source line.', Comment = 'is-IS=sourceType og sourceNo verður að senda saman til að lesa upprunalínu.';
        SourcePairExpectedTok: Label 'sourceType and sourceNo', Comment = 'is-IS=sourceType og sourceNo';
        SourcePairNextStepLbl: Label 'Send both sourceType and sourceNo, or leave every source key out.', Comment = 'is-IS=Sendu bæði sourceType og sourceNo, eða slepptu öllum upprunalyklum.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ContractParts.TryResolveItemNo(Argument, RequestJson, false, ItemNo) then
            exit;
        if not ReadInteger(Argument, RequestJson, 'entryNo', 1, EntryNo, HasEntryNo) then
            exit;
        if not ReadInteger(Argument, RequestJson, 'sourceType', 0, SourceType, HasSourceType) then
            exit;
        if not ReadInteger(Argument, RequestJson, 'sourceSubtype', 0, SourceSubtype, HasSourceSubtype) then
            exit;
        if not ReadInteger(Argument, RequestJson, 'sourceLineNo', 0, SourceLineNo, HasSourceLineNo) then
            exit;
        if not ReadSourceNo(Argument, RequestJson, SourceNo, HasSourceNo) then
            exit;
        if (HasSourceType <> HasSourceNo) or ((HasSourceSubtype or HasSourceLineNo) and not HasSourceType) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, SourcePairErr, 'sourceNo', '<missing>', SourcePairExpectedTok, SourcePairNextStepLbl);
            exit;
        end;
        if HasEntryNo then begin
            ReservationEntry.SetRange("Entry No.", EntryNo);
            if ReservationEntry.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), EntryExpectedTok, EntryNextStepLbl);
                exit;
            end;
        end;
        if ItemNo <> '' then
            ReservationEntry.SetRange("Item No.", ItemNo);
        if HasSourceType then begin
            ReservationEntry.SetRange("Source Type", SourceType);
            ReservationEntry.SetRange("Source ID", CopyStr(SourceNo, 1, MaxStrLen(ReservationEntry."Source ID")));
            if HasSourceSubtype then
                ReservationEntry.SetRange("Source Subtype", SourceSubtype);
            if HasSourceLineNo then
                ReservationEntry.SetRange("Source Ref. No.", SourceLineNo);
        end;
        ReservationEntry.SetLoadFields("Entry No.", Positive, "Item No.", "Variant Code", "Location Code", Quantity, "Quantity (Base)", "Reservation Status", "Source Type", "Source Subtype", "Source ID", "Source Batch Name", "Source Prod. Order Line", "Source Ref. No.", "Lot No.", "Serial No.", "Package No.", "Expected Receipt Date", "Shipment Date", "Creation Date");
        if ReservationEntry.FindSet() then
            repeat
                Clear(EntryJson);
                EntryJson.Add('entryNo', ReservationEntry."Entry No.");
                EntryJson.Add('itemNo', ReservationEntry."Item No.");
                EntryJson.Add('locationCode', ReservationEntry."Location Code");
                EntryJson.Add('quantity', ReservationEntry.Quantity);
                EntryJson.Add('reservationStatus', ReservationEntry."Reservation Status".Names().Get(ReservationEntry."Reservation Status".Ordinals().IndexOf(ReservationEntry."Reservation Status".AsInteger())));
                EntryJson.Add('sourceId', ReservationEntry."Source ID");
                EntryJson.Add('variantCode', ReservationEntry."Variant Code");
                EntryJson.Add('quantityBase', ReservationEntry."Quantity (Base)");
                EntryJson.Add('positive', ReservationEntry.Positive);
                EntryJson.Add('sourceType', ReservationEntry."Source Type");
                EntryJson.Add('sourceSubtype', ReservationEntry."Source Subtype");
                EntryJson.Add('sourceBatchName', ReservationEntry."Source Batch Name");
                EntryJson.Add('sourceProdOrderLine', ReservationEntry."Source Prod. Order Line");
                EntryJson.Add('sourceRefNo', ReservationEntry."Source Ref. No.");
                EntryJson.Add('lotNo', ReservationEntry."Lot No.");
                EntryJson.Add('serialNo', ReservationEntry."Serial No.");
                EntryJson.Add('packageNo', ReservationEntry."Package No.");
                EntryJson.Add('expectedReceiptDate', DateText(ReservationEntry."Expected Receipt Date"));
                EntryJson.Add('shipmentDate', DateText(ReservationEntry."Shipment Date"));
                EntryJson.Add('creationDate', DateText(ReservationEntry."Creation Date"));
                Entries.Add(EntryJson);
            until ReservationEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure DateText(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MinValue: Integer; var Value: Integer; var Sent: Boolean): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Number: Decimal;
        FormatErr: Label '%1 must be a whole number of at least %2.', Comment = '%1 = parameter name; %2 = lowest allowed value; is-IS=%1 verður að vera heiltala, að minnsta kosti %2.';
        IntegerExpectedTok: Label 'a JSON integer', Comment = 'is-IS=JSON-heiltala';
        IntegerNextStepLbl: Label 'Send the value as a JSON number without quotes.', Comment = 'is-IS=Sendu gildið sem JSON-tölu án gæsalappa.';
    begin
        Sent := RequestJson.Get(KeyName, Token);
        if not Sent then
            exit(true);
        Token.WriteTo(Serialized);
        if not Token.IsValue() or Serialized.StartsWith('"') or not Evaluate(Number, Serialized, 9) then
            Number := -1;
        if (Number <> Round(Number, 1)) or (Number < MinValue) or (Number > 2147483647) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName, MinValue), KeyName, Serialized, IntegerExpectedTok, IntegerNextStepLbl);
            exit(false);
        end;
        Value := Number;
        exit(true);
    end;

    local procedure ReadSourceNo(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Value: Text; var Sent: Boolean): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        FormatErr: Label 'sourceNo must be text of 1 to 20 characters.', Comment = 'is-IS=sourceNo verður að vera texti, 1 til 20 stafir.';
        StringExpectedTok: Label 'a JSON string', Comment = 'is-IS=JSON-strengur';
        StringNextStepLbl: Label 'Send sourceNo as the document number in quotes.', Comment = 'is-IS=Sendu sourceNo sem skjalanúmerið innan gæsalappa.';
    begin
        Sent := RequestJson.Get('sourceNo', Token);
        if not Sent then
            exit(true);
        Token.WriteTo(Serialized);
        if Token.IsValue() and Serialized.StartsWith('"') then
            Value := Token.AsValue().AsText();
        if not Token.IsValue() or not Serialized.StartsWith('"') or (Value = '') or (StrLen(Value) > 20) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, 'sourceNo', Serialized, StringExpectedTok, StringNextStepLbl);
            exit(false);
        end;
        Value := UpperCase(Value);
        exit(true);
    end;
}
