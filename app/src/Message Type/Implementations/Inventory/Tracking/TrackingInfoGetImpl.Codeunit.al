namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Reads the lot, serial or package information card of an item: card fields, comments and inventory (#106).</summary>
codeunit 10077010 "Tracking Info Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads the lot, serial or package information card of an item, with its comments and inventory.', Comment = 'is-IS=Les upplýsingaspjald lotu, raðnúmers eða pakka fyrir vöru, með athugasemdum og birgðum.';
        SelectionLbl: Label 'Select an item using subject or item identifiers, then exactly one of lotNo, serialNo or packageNo, and the variantCode of the card.', Comment = 'is-IS=Veldu vöru með subject eða vöruauðkennum, síðan nákvæmlega eitt af lotNo, serialNo eða packageNo, og variantCode spjaldsins.';
        KeywordsLbl: Label 'lot information,serial information,package information,lot card,serial card,package card,test quality,certificate number,blocked lot', Comment = 'is-IS=lotuupplýsingar,raðnúmeraupplýsingar,pakkaupplýsingar,lotuspjald,raðnúmeraspjald,pakkaspjald,gæðaprófun,vottorðsnúmer,lokuð lota';
        OverviewLbl: Label 'Reads one lot, serial or package information card of an item: description, test quality, certificate number, blocked, comments, inventory and expired inventory.', Comment = 'is-IS=Les eitt upplýsingaspjald lotu, raðnúmers eða pakka fyrir vöru: lýsingu, gæðaprófun, vottorðsnúmer, lokun, athugasemdir, birgðir og útrunnar birgðir.';
        NotesLbl: Label 'Read only. Send exactly one of lotNo, serialNo or packageNo; variantCode selects the card of that variant and is blank when not sent. A tracking number that has stock but no information card is refused with RecordNotFound. testQuality is answered for lot cards only and certificateNumber for lot and package cards; countryRegionCode for package cards only; the other card types answer them blank. inventory is the remaining quantity of the item ledger entries of the card in the base unit of measure; expiredInventory is the part of it whose expiration date is before the work date. comments lists the item tracking comments of the card in line order.', Comment = 'is-IS=Aðeins lestur. Sendu nákvæmlega eitt af lotNo, serialNo eða packageNo; variantCode velur spjald þess afbrigðis og er autt ef það er ekki sent. Rakningarnúmeri sem á birgðir en ekkert upplýsingaspjald er hafnað með RecordNotFound. testQuality er aðeins skilað fyrir lotuspjöld og certificateNumber fyrir lotu- og pakkaspjöld; countryRegionCode aðeins fyrir pakkaspjöld; aðrar spjaldtegundir skila þeim auðum. inventory er eftirstandandi magn vörufærslna spjaldsins í grunnmælieiningu; expiredInventory er sá hluti þess sem rennur út fyrir vinnudagsetningu. comments telur upp rakningarathugasemdir spjaldsins í línuröð.';
        MissingItemErr: Label 'itemNo must be specified.', Comment = 'is-IS=itemNo verður að vera tilgreint.';
        ItemNoExpectedTxt: Label 'A non-empty item number in data.itemNo.', Comment = 'is-IS=Ótómt vörunúmer í data.itemNo.';
        ItemNoNextStepTxt: Label 'Send the item number in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið í data.itemNo.';
        MissingTrackingErr: Label 'Send lotNo, serialNo or packageNo.', Comment = 'is-IS=Sendu lotNo, serialNo eða packageNo.';
        ManyTrackingErr: Label 'Send only one of lotNo, serialNo or packageNo.', Comment = 'is-IS=Sendu aðeins eitt af lotNo, serialNo eða packageNo.';
        TrackingExpectedTxt: Label 'Exactly one non-blank tracking number: lotNo, serialNo or packageNo.', Comment = 'is-IS=Nákvæmlega eitt rakningarnúmer sem er ekki autt: lotNo, serialNo eða packageNo.';
        TrackingNextStepTxt: Label 'Send the lot, serial or package number of the card in one of lotNo, serialNo or packageNo.', Comment = 'is-IS=Sendu lotu-, raðnúmer eða pakkanúmer spjaldsins í einu af lotNo, serialNo eða packageNo.';
        TooLongErr: Label 'A tracking number or variant code is too long.', Comment = 'is-IS=Rakningarnúmer eða afbrigðiskóði er of langur.';
        TooLongExpectedTxt: Label 'variantCode: at most 10 characters; lotNo, serialNo and packageNo: at most 50 characters.', Comment = 'is-IS=variantCode: að hámarki 10 stafir; lotNo, serialNo og packageNo: að hámarki 50 stafir.';
        TooLongNextStepTxt: Label 'Shorten the value to the length of the Business Central field.', Comment = 'is-IS=Styttu gildið að lengd Business Central reitsins.';
        NoCardErr: Label 'The tracking number has no information card.', Comment = 'is-IS=Rakningarnúmerið hefur ekkert upplýsingaspjald.';
        NoCardExpectedTxt: Label 'An existing %1 for item %2, variant ''%3'' and number %4.', Comment = '%1 = card table caption, %2 = item no., %3 = variant code, %4 = tracking no. is-IS=Fyrirliggjandi %1 fyrir vöru %2, afbrigði ''%3'' og númer %4.';
        NoCardNextStepTxt: Label 'The tracking number has no information card. Check the item, variantCode and number, or create the card in Business Central first.', Comment = 'is-IS=Rakningarnúmerið hefur ekkert upplýsingaspjald. Athugaðu vöru, variantCode og númer, eða stofnaðu spjaldið fyrst í Business Central.';
        PermissionErr: Label 'Permission denied for the requested tracking information.', Comment = 'is-IS=Heimild hafnað fyrir umbeðnar rakningarupplýsingar.';
        PermissionExpectedTxt: Label 'Read permission on the information card, item tracking comment and item ledger entry tables.', Comment = 'is-IS=Lesheimild á töflum upplýsingaspjalds, rakningarathugasemda og vörufærslna.';
        PermissionNextStepTxt: Label 'Ask an administrator for read permission on the named table.', Comment = 'is-IS=Biddu kerfisstjóra um lesheimild á tilgreindri töflu.';

    /// <summary>Provides IsEnabled for Inventory.TrackingInfo.Get.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false));
    end;

    /// <summary>Provides GetFilterTableNo for Inventory.TrackingInfo.Get.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Provides GetDescription for Inventory.TrackingInfo.Get.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides GetKeywords for Inventory.TrackingInfo.Get.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides GetSelectionDescription for Inventory.TrackingInfo.Get.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Provides GetEnvelope for Inventory.TrackingInfo.Get.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Forms.Add('guid');
        Forms.Add('item no.');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The subject is the SystemId or No. of the Item; data selects the same item when subject is blank.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.TrackingInfo.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item; it takes precedence over the item identifiers in data.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item, used when subject is blank.'));
        Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the Item, tried in this order after itemNo.'));
        Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view; the first matching item is read, so filter to one item for an exact selection.'));
        Target.Add(ContractMgt.TargetEntry('data.variantCode + data.lotNo', 'lot no.', 'The Lot No. Information card (table 6505) of the item, variant and lot.'));
        Target.Add(ContractMgt.TargetEntry('data.variantCode + data.serialNo', 'serial no.', 'The Serial No. Information card (table 6504) of the item, variant and serial number.'));
        Target.Add(ContractMgt.TargetEntry('data.variantCode + data.packageNo', 'package no.', 'The Package No. Information card (table 6515) of the item, variant and package.'));
        exit(true);
    end;

    /// <summary>Provides GetParameters for Inventory.TrackingInfo.Get.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Item number; subject takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'Business Central Item table view in SetView syntax. Used after subject and item identifiers; reads the card of the first matching item. Filter to one item for an exact selection.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Variant code of the card, at most 10 characters; blank when not sent.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'Lot number of a Lot No. Information card, at most 50 characters. Send exactly one of lotNo, serialNo or packageNo.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'Serial number of a Serial No. Information card, at most 50 characters. Send exactly one of lotNo, serialNo or packageNo.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'Package number of a Package No. Information card, at most 50 characters. Send exactly one of lotNo, serialNo or packageNo.'));
        exit(true);
    end;

    /// <summary>Provides GetResponse for Inventory.TrackingInfo.Get.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        CommentFields: JsonArray;
        CommentsField: JsonObject;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the card is read.'));
        Fields.Add(ContractMgt.ResponseField('trackingType', 'string', 'Lot, Serial or Package: the card that was read.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number of the card.'));
        Fields.Add(ContractMgt.ResponseField('variantCode', 'string', 'Variant code of the card; blank for the item without a variant.'));
        Fields.Add(ContractMgt.ResponseField('lotNo', 'string', 'Lot number of a lot card; blank for the other card types.'));
        Fields.Add(ContractMgt.ResponseField('serialNo', 'string', 'Serial number of a serial card; blank for the other card types.'));
        Fields.Add(ContractMgt.ResponseField('packageNo', 'string', 'Package number of a package card; blank for the other card types.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'Description of the card.'));
        Fields.Add(ContractMgt.ResponseField('testQuality', 'string', 'Test quality of a lot card: blank, Good, Average or Bad. Blank for serial and package cards, which have no test quality.'));
        Fields.Add(ContractMgt.ResponseField('certificateNumber', 'string', 'Certificate number of a lot or package card; blank for serial cards, which have none.'));
        Fields.Add(ContractMgt.ResponseField('countryRegionCode', 'string', 'Country/region code of a package card; blank for lot and serial cards.'));
        Fields.Add(ContractMgt.ResponseField('blocked', 'boolean', 'True when the card is blocked, so the tracking number cannot be used in transactions.'));
        Fields.Add(ContractMgt.ResponseField('hasComments', 'boolean', 'The Comment flag of the card: true when it has item tracking comments.'));
        Fields.Add(ContractMgt.ResponseField('inventory', 'decimal', 'Remaining quantity of the item ledger entries of the card, in the base unit of measure.'));
        Fields.Add(ContractMgt.ResponseField('expiredInventory', 'decimal', 'The part of inventory whose expiration date is before the work date.'));
        CommentFields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number of the comment.'));
        CommentFields.Add(ContractMgt.ResponseField('date', 'string', 'Date of the comment in YYYY-MM-DD form; blank when it has none.'));
        CommentFields.Add(ContractMgt.ResponseField('comment', 'string', 'Text of the comment.'));
        CommentsField := ContractMgt.ResponseField('comments', 'array', 'The item tracking comments of the card in line order; empty when it has none.');
        CommentsField.Add('children', CommentFields);
        Fields.Add(CommentsField);
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides GetErrors for Inventory.TrackingInfo.Get.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenTxt: Label 'data.itemNo is not sent or blank and no other item selection is sent, or none of lotNo, serialNo and packageNo is sent.', Comment = 'is-IS=data.itemNo er ekki sent eða autt og ekkert annað vöruval er sent, eða ekkert af lotNo, serialNo og packageNo er sent.';
        MissingNextStepTxt: Label 'Send the item number in data.itemNo and one of lotNo, serialNo or packageNo.', Comment = 'is-IS=Sendu vörunúmerið í data.itemNo og eitt af lotNo, serialNo eða packageNo.';
        FormatMsgTxt: Label 'A tracking number, variant code or item identifier has the wrong JSON type or is too long.', Comment = 'is-IS=Rakningarnúmer, afbrigðiskóði eða vöruauðkenni hefur rangt JSON-tag eða er of langt.';
        FormatNextStepTxt: Label 'Send JSON strings: variantCode at most 10 characters, lotNo, serialNo and packageNo at most 50.', Comment = 'is-IS=Sendu JSON-strengi: variantCode að hámarki 10 stafir, lotNo, serialNo og packageNo að hámarki 50.';
        InvalidMsgTxt: Label 'More than one of lotNo, serialNo and packageNo is sent, or the Item Tracking domain is turned off.', Comment = 'is-IS=Fleiri en eitt af lotNo, serialNo og packageNo er sent, eða slökkt er á vörurakningarsviðinu.';
        InvalidNextStepTxt: Label 'Send only one tracking number; turn the domain on from Inventory Setup.', Comment = 'is-IS=Sendu aðeins eitt rakningarnúmer; kveiktu á sviðinu í uppsetningu birgða.';
        NotFoundMsgTxt: Label 'The item cannot be found, or the tracking number has no information card for the item and variant.', Comment = 'is-IS=Varan finnst ekki, eða rakningarnúmerið hefur ekkert upplýsingaspjald fyrir vöruna og afbrigðið.';
        PermissionMsgTxt: Label 'The caller cannot read the item, the information card, item tracking comments or item ledger entries.', Comment = 'is-IS=Kallandi getur ekki lesið vöruna, upplýsingaspjaldið, rakningarathugasemdir eða vörufærslur.';
        NativeMsgTxt: Label 'Native item selection or table view error.', Comment = 'is-IS=Villa í vöruvali eða töflusýn Business Central.';
        NativeWhenTxt: Label 'Foundation rejects the item selector or the table view cannot be evaluated.', Comment = 'is-IS=Foundation hafnar vöruvalinu eða ekki er hægt að meta töflusýnina.';
        NativeNextStepTxt: Label 'Correct the item selection and the Business Central table view syntax.', Comment = 'is-IS=Leiðréttu vöruvalið og setningafræði töflusýnar Business Central.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenTxt, MissingNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatMsgTxt, FormatNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidMsgTxt, InvalidNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundMsgTxt, NoCardNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionMsgTxt, PermissionNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeMsgTxt, NativeWhenTxt, NativeNextStepTxt));
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.TrackingInfo.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is changed. Reads one lot, serial or package information card, its item tracking comments and the remaining quantity of its item ledger entries.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Effect.Add('writes', false);
        exit(true);
    end;

    /// <summary>Provides GetMetering for Inventory.TrackingInfo.Get.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetRelated for Inventory.TrackingInfo.Get.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read the remaining, reserved and available quantity of every lot, serial and package of an item by location instead of one card.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', 'Read the tracking rows of an item or a document line instead of the information card.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.TrackingInfo.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.TrackingInfo.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Example: JsonObject;
    begin
        Clear(Examples);
        Example := ContractMgt.Example(
            'Read an owned lot information card',
            '{"type":"Inventory.TrackingInfo.Get","data":{"itemNo":"OWNED-ITEM","lotNo":"OWNED-LOT"}}',
            '{"status":"Success","trackingType":"Lot","itemNo":"OWNED-ITEM","variantCode":"","lotNo":"OWNED-LOT","serialNo":"","packageNo":"","description":"Batch from supplier","testQuality":"Good","certificateNumber":"CERT-1","countryRegionCode":"","blocked":false,"hasComments":true,"inventory":2,"expiredInventory":0,"comments":[{"lineNo":10000,"date":"2027-01-15","comment":"Checked on receipt"}]}');
        Example.Add('description', 'Create your own tracked item, lot information card and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.');
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Provides GetOverview for Inventory.TrackingInfo.Get.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Provides GetNotes for Inventory.TrackingInfo.Get.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Provides GetMessageDirection for Inventory.TrackingInfo.Get.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Provides ExecuteBifrostTask for Inventory.TrackingInfo.Get.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        ItemResolve: Codeunit "Item Attribute Resolve ori";
        Request: JsonObject;
        VariantCode: Text;
        LotNo: Text;
        SerialNo: Text;
        PackageNo: Text;
        Sent: Integer;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not TrackingRead.HasItemSelection(Argument) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingItemErr, 'itemNo', '', ItemNoExpectedTxt, ItemNoNextStepTxt);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not TrackingRead.ReadText(Argument, Request, 'variantCode', false, VariantCode) or
           not TrackingRead.ReadText(Argument, Request, 'lotNo', false, LotNo) or
           not TrackingRead.ReadText(Argument, Request, 'serialNo', false, SerialNo) or
           not TrackingRead.ReadText(Argument, Request, 'packageNo', false, PackageNo)
        then
            exit;
        if LotNo <> '' then
            Sent += 1;
        if SerialNo <> '' then
            Sent += 1;
        if PackageNo <> '' then
            Sent += 1;
        if Sent = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingTrackingErr, 'lotNo|serialNo|packageNo', '', TrackingExpectedTxt, TrackingNextStepTxt);
            exit;
        end;
        if Sent > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, ManyTrackingErr, 'lotNo|serialNo|packageNo', LotNo + '|' + SerialNo + '|' + PackageNo, TrackingExpectedTxt, TrackingNextStepTxt);
            exit;
        end;
        if (StrLen(VariantCode) > 10) or (StrLen(LotNo) > 50) or (StrLen(SerialNo) > 50) or (StrLen(PackageNo) > 50) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, TooLongErr, 'variantCode|lotNo|serialNo|packageNo', VariantCode + '|' + LotNo + '|' + SerialNo + '|' + PackageNo, TooLongExpectedTxt, TooLongNextStepTxt);
            exit;
        end;
        if not CheckRead(Argument, Database::Item) then
            exit;
        if not ItemResolve.ResolveSingleItem(Argument, Item) then
            exit;
        if not CheckRead(Argument, Database::"Item Tracking Comment") or not CheckRead(Argument, Database::"Item Ledger Entry") then
            exit;
        case true of
            LotNo <> '':
                ReadLotCard(Argument, Item."No.", CopyStr(VariantCode, 1, 10), CopyStr(LotNo, 1, 50));
            SerialNo <> '':
                ReadSerialCard(Argument, Item."No.", CopyStr(VariantCode, 1, 10), CopyStr(SerialNo, 1, 50));
            else
                ReadPackageCard(Argument, Item."No.", CopyStr(VariantCode, 1, 10), CopyStr(PackageNo, 1, 50));
        end;
    end;

    local procedure ReadLotCard(var Argument: Record "Message Argument ori"; ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50])
    var
        LotInfo: Record "Lot No. Information";
        Ledger: Record "Item Ledger Entry";
        Response: JsonObject;
    begin
        if not CheckRead(Argument, Database::"Lot No. Information") then
            exit;
        LotInfo.ReadIsolation(IsolationLevel::ReadCommitted);
        if not LotInfo.Get(ItemNo, VariantCode, LotNo) then begin
            RespondNoCard(Argument, LotInfo.TableCaption(), 'lotNo', ItemNo, VariantCode, LotNo);
            exit;
        end;
        Ledger.SetRange("Lot No.", LotNo);
        StartResponse(Response, 'Lot', ItemNo, VariantCode, LotNo, '', '');
        AddCardFields(Response, LotInfo.Description, TestQualityName(LotInfo), LotInfo."Certificate Number", '', LotInfo.Blocked, LotInfo.Comment);
        Respond(Argument, Response, Ledger, ItemNo, VariantCode, "Item Tracking Comment Type"::"Lot No.", LotNo);
    end;

    local procedure ReadSerialCard(var Argument: Record "Message Argument ori"; ItemNo: Code[20]; VariantCode: Code[10]; SerialNo: Code[50])
    var
        SerialInfo: Record "Serial No. Information";
        Ledger: Record "Item Ledger Entry";
        Response: JsonObject;
    begin
        if not CheckRead(Argument, Database::"Serial No. Information") then
            exit;
        SerialInfo.ReadIsolation(IsolationLevel::ReadCommitted);
        if not SerialInfo.Get(ItemNo, VariantCode, SerialNo) then begin
            RespondNoCard(Argument, SerialInfo.TableCaption(), 'serialNo', ItemNo, VariantCode, SerialNo);
            exit;
        end;
        Ledger.SetRange("Serial No.", SerialNo);
        StartResponse(Response, 'Serial', ItemNo, VariantCode, '', SerialNo, '');
        AddCardFields(Response, SerialInfo.Description, '', '', '', SerialInfo.Blocked, SerialInfo.Comment);
        Respond(Argument, Response, Ledger, ItemNo, VariantCode, "Item Tracking Comment Type"::"Serial No.", SerialNo);
    end;

    local procedure ReadPackageCard(var Argument: Record "Message Argument ori"; ItemNo: Code[20]; VariantCode: Code[10]; PackageNo: Code[50])
    var
        PackageInfo: Record "Package No. Information";
        Ledger: Record "Item Ledger Entry";
        Response: JsonObject;
    begin
        if not CheckRead(Argument, Database::"Package No. Information") then
            exit;
        PackageInfo.ReadIsolation(IsolationLevel::ReadCommitted);
        if not PackageInfo.Get(ItemNo, VariantCode, PackageNo) then begin
            RespondNoCard(Argument, PackageInfo.TableCaption(), 'packageNo', ItemNo, VariantCode, PackageNo);
            exit;
        end;
        Ledger.SetRange("Package No.", PackageNo);
        StartResponse(Response, 'Package', ItemNo, VariantCode, '', '', PackageNo);
        AddCardFields(Response, PackageInfo.Description, '', PackageInfo."Certificate Number", PackageInfo."Country/Region Code", PackageInfo.Blocked, PackageInfo.Comment);
        Respond(Argument, Response, Ledger, ItemNo, VariantCode, "Item Tracking Comment Type"::"Package No.", PackageNo);
    end;

    local procedure StartResponse(var Response: JsonObject; TrackingType: Text; ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50])
    begin
        Response.Add('status', 'Success');
        Response.Add('trackingType', TrackingType);
        Response.Add('itemNo', ItemNo);
        Response.Add('variantCode', VariantCode);
        Response.Add('lotNo', LotNo);
        Response.Add('serialNo', SerialNo);
        Response.Add('packageNo', PackageNo);
    end;

    local procedure AddCardFields(var Response: JsonObject; Description: Text; TestQuality: Text; CertificateNumber: Text; CountryRegionCode: Text; Blocked: Boolean; HasComments: Boolean)
    begin
        Response.Add('description', Description);
        Response.Add('testQuality', TestQuality);
        Response.Add('certificateNumber', CertificateNumber);
        Response.Add('countryRegionCode', CountryRegionCode);
        Response.Add('blocked', Blocked);
        Response.Add('hasComments', HasComments);
    end;

    local procedure Respond(var Argument: Record "Message Argument ori"; var Response: JsonObject; var Ledger: Record "Item Ledger Entry"; ItemNo: Code[20]; VariantCode: Code[10]; CommentType: Enum "Item Tracking Comment Type"; TrackingNo: Code[50])
    begin
        // The tracking filter is set by the caller; item and variant pin the ledger entries to this card.
        Ledger.SetRange("Item No.", ItemNo);
        Ledger.SetRange("Variant Code", VariantCode);
        Ledger.ReadIsolation(IsolationLevel::ReadCommitted);
        Ledger.CalcSums("Remaining Quantity");
        Response.Add('inventory', Ledger."Remaining Quantity");
        Ledger.SetFilter("Expiration Date", '<>%1&<%2', 0D, WorkDate());
        Ledger.CalcSums("Remaining Quantity");
        Response.Add('expiredInventory', Ledger."Remaining Quantity");
        Response.Add('comments', Comments(CommentType, ItemNo, VariantCode, TrackingNo));
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure Comments(CommentType: Enum "Item Tracking Comment Type"; ItemNo: Code[20]; VariantCode: Code[10]; TrackingNo: Code[50]) Rows: JsonArray
    var
        TrackingComment: Record "Item Tracking Comment";
        Row: JsonObject;
    begin
        TrackingComment.SetRange(Type, CommentType);
        TrackingComment.SetRange("Item No.", ItemNo);
        TrackingComment.SetRange("Variant Code", VariantCode);
        TrackingComment.SetRange("Serial/Lot No.", TrackingNo);
        TrackingComment.SetLoadFields("Line No.", Date, Comment);
        TrackingComment.ReadIsolation(IsolationLevel::ReadCommitted);
        if TrackingComment.FindSet() then
            repeat
                Clear(Row);
                Row.Add('lineNo', TrackingComment."Line No.");
                if TrackingComment.Date = 0D then
                    Row.Add('date', '')
                else
                    Row.Add('date', Format(TrackingComment.Date, 0, 9));
                Row.Add('comment', TrackingComment.Comment);
                Rows.Add(Row);
            until TrackingComment.Next() = 0;
    end;

    local procedure TestQualityName(LotInfo: Record "Lot No. Information"): Text
    begin
        // Invariant option names, not captions, so the answer is the same in every language.
        case LotInfo."Test Quality" of
            LotInfo."Test Quality"::Good:
                exit('Good');
            LotInfo."Test Quality"::Average:
                exit('Average');
            LotInfo."Test Quality"::Bad:
                exit('Bad');
        end;
        exit('');
    end;

    local procedure RespondNoCard(var Argument: Record "Message Argument ori"; CardCaption: Text; KeyName: Text; ItemNo: Code[20]; VariantCode: Code[10]; TrackingNo: Code[50])
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NoCardErr, KeyName, TrackingNo, StrSubstNo(NoCardExpectedTxt, CardCaption, ItemNo, VariantCode, TrackingNo), NoCardNextStepTxt);
    end;

    local procedure CheckRead(var Argument: Record "Message Argument ori"; TableNo: Integer): Boolean
    var
        SourceRef: RecordRef;
    begin
        SourceRef.Open(TableNo);
        if SourceRef.ReadPermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, 'tableNo', Format(TableNo, 0, 9), PermissionExpectedTxt, PermissionNextStepTxt);
        exit(false);
    end;
}
