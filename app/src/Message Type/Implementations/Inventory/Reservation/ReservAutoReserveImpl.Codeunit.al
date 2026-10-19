namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reservation.AutoReserve reserves the outstanding quantity of one sales order line.
/// Business Central chooses the supply, as the Auto Reserve action on the Reservation page does.
/// The write runs in its own transaction: a partial reservation is rolled back.
/// </summary>
codeunit 10036925 "Reserv. AutoReserve Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;
        AllowedKeysTok: Label 'documentType, documentNo, lineNo, systemId, quantity', Locked = true;
        OrderTok: Label 'Order', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations) then
            exit(false);
        exit(HasTablePermissions());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reserves a sales order line from available supply.', Comment = 'is-IS=Tekur sölupöntunarlínu frá úr tiltæku framboði.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'auto reserve, sales line, reservation, reserve', Comment = 'is-IS=sjálfvirk frátekning, sölulína, frátekning, taka frá';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reserves the outstanding quantity of one sales order line. Business Central chooses the supply.', Comment = 'is-IS=Tekur frá útistandandi magn einnar sölupöntunarlínu. Business Central velur framboðið.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.AutoReserve');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentTargetLbl: Label 'The sales order line, by order number and line number.', Comment = 'is-IS=Sölupöntunarlínan, eftir pöntunarnúmeri og línunúmeri.';
        SystemIdTargetLbl: Label 'The sales order line, by its SystemId.', Comment = 'is-IS=Sölupöntunarlínan, eftir SystemId hennar.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentType + data.documentNo + data.lineNo', 'document type, document no. and line no.', DocumentTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', SystemIdTargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentTypeLbl: Label 'Order. Only sales order lines can be auto-reserved. Send it with documentNo and lineNo, or send systemId instead.', Comment = 'is-IS=Order. Aðeins er hægt að taka sölupöntunarlínur sjálfvirkt frá. Sendu það með documentNo og lineNo, eða sendu systemId í staðinn.';
        DocumentNoLbl: Label 'The sales order number.', Comment = 'is-IS=Númer sölupöntunarinnar.';
        LineNoLbl: Label 'The line number on the sales order.', Comment = 'is-IS=Línunúmerið á sölupöntuninni.';
        SystemIdLbl: Label 'The SystemId of the sales line. Do not send the document keys with it.', Comment = 'is-IS=SystemId sölulínunnar. Ekki senda lykla fylgiskjalsins með því.';
        QuantityLbl: Label 'The quantity to reserve, in the unit of measure of the line. Optional. Defaults to the outstanding quantity that is not yet reserved, and is capped at it.', Comment = 'is-IS=Magnið sem á að taka frá, í mælieiningu línunnar. Valkvætt. Sjálfgefið er útistandandi magn sem er ekki þegar frátekið, og það er jafnframt hámarkið.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, LineNoLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', false, QuantityLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('documentType', 'Order');
        Response.Add('documentNo', '');
        Response.Add('lineNo', 0);
        Response.Add('systemId', '');
        Response.Add('itemNo', '');
        Response.Add('reserved', 0);
        Response.Add('reservedQuantity', 0);
        Response.Add('outstandingQuantity', 0);
        Response.Add('fullyReserved', true);
        Response.Add('entries', 'one row per reservation made by this call: entryNo, itemNo, quantity, quantityBase, shipmentDate, supplyType, supplyTypeName, supplySubtype, supplyNo, supplyLineNo');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegan lykil vantar.';
        MissingFixLbl: Label 'Send documentType, documentNo and lineNo, or systemId.', Comment = 'is-IS=Sendu documentType, documentNo og lineNo, eða systemId.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send lineNo as an integer, quantity as a number and systemId as a GUID.', Comment = 'is-IS=Sendu lineNo sem heiltölu, quantity sem tölu og systemId sem GUID.';
        InvalidWhenLbl: Label 'documentType is not Order, quantity is zero or less, or the Reservations domain is turned off.', Comment = 'is-IS=documentType er ekki Order, quantity er núll eða minna, eða slökkt er á frátekningasviðinu.';
        InvalidFixLbl: Label 'Send documentType Order and a quantity greater than zero, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu documentType Order og quantity stærra en núll, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, lineNo, systemId and quantity.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, lineNo, systemId og quantity.';
        ConflictWhenLbl: Label 'systemId was sent together with document keys.', Comment = 'is-IS=systemId var sent ásamt lyklum fylgiskjals.';
        ConflictFixLbl: Label 'Send systemId or the document keys, not both.', Comment = 'is-IS=Sendu systemId eða lykla fylgiskjalsins, ekki hvort tveggja.';
        NotFoundWhenLbl: Label 'No sales line matches the identifiers.', Comment = 'is-IS=Engin sölulína passar við auðkennin.';
        NotFoundFixLbl: Label 'Check the document and line no.', Comment = 'is-IS=Athugaðu fylgiskjalið og línunúmerið.';
        PreconditionWhenLbl: Label 'The item or the line has Reserve set to Never, or the line cannot be reserved: it is not an item line on a sales order, the item is not an inventory item, it is a drop shipment or special order, it has no shipment date, or nothing is outstanding.', Comment = 'is-IS=Frátekning er stillt á Aldrei á vörunni eða línunni, eða ekki er hægt að taka línuna frá: hún er ekki vörulína á sölupöntun, varan er ekki birgðavara, hún er bein afhending eða sérpöntun, hún hefur engan afhendingardag, eða ekkert er útistandandi.';
        PreconditionFixLbl: Label 'Change the item''s Reserve setting or reserve manually.', Comment = 'is-IS=Breyttu stillingunni Frátekning á vörunni eða taktu frá handvirkt.';
        PartialWhenLbl: Label 'Only part of the quantity could be reserved. The partial reservation is rolled back. Nothing is written.', Comment = 'is-IS=Aðeins var hægt að taka hluta magnsins frá. Hlutafrátekningin er afturkölluð. Ekkert er skrifað.';
        PartialFixLbl: Label 'Read Inventory.Reservation.Get for what was reserved.', Comment = 'is-IS=Lestu Inventory.Reservation.Get til að sjá hvað er tekið frá.';
        PermissionWhenLbl: Label 'The caller cannot change reservation entries or read sales lines and items.', Comment = 'is-IS=Kallandinn getur ekki breytt frátekningarfærslum eða lesið sölulínur og vörur.';
        PermissionFixLbl: Label 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Full ori (með viðbótinni BIFROST InvWrite ori) og Business Central heimildasafni sem getur breytt þessum töflum.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionWhenLbl, PreconditionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LinesSkipped, PartialWhenLbl, PartialFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
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
        ReservationGetLbl: Label 'Read the reservations that exist on the line.', Comment = 'is-IS=Lestu frátekningarnar sem eru til á línunni.';
        ReservationCancelLbl: Label 'Cancel a reservation entry.', Comment = 'is-IS=Hættu við frátekningarfærslu.';
        OrderTrackingLbl: Label 'Read which supply is tracked against the line.', Comment = 'is-IS=Lestu hvaða framboð er rakið á móti línunni.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', ReservationGetLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', ReservationCancelLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.OrderTracking.Get', OrderTrackingLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Reserve a sales order line from inventory', Comment = 'is-IS=Taka sölupöntunarlínu frá úr birgðum';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl,
            '{"messageType":"Inventory.Reservation.AutoReserve","version":1,"data":{"documentType":"Order","documentNo":"101005","lineNo":10000}}',
            '{"status":"Success","documentType":"Order","documentNo":"101005","lineNo":10000,"systemId":"00000000-0000-0000-0000-000000000000","itemNo":"1896-S","reserved":2,"reservedQuantity":2,"outstandingQuantity":2,"fullyReserved":true,"entries":[{"entryNo":120,"itemNo":"1896-S","quantity":-2,"quantityBase":-2,"shipmentDate":"2026-10-20","supplyType":32,"supplyTypeName":"Item Ledger Entry","supplySubtype":0,"supplyNo":"","supplyLineNo":345}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reserves one sales order line from available supply. Business Central chooses the supply, as the Auto Reserve action on the Reservation page does. Identify the line with documentType, documentNo and lineNo, or with systemId.', Comment = 'is-IS=Tekur eina sölupöntunarlínu frá úr tiltæku framboði. Business Central velur framboðið, eins og aðgerðin Taka sjálfvirkt frá á síðunni Frátekning. Tilgreindu línuna með documentType, documentNo og lineNo, eða með systemId.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'quantity is optional. Without it the call reserves the outstanding quantity that is not reserved yet. reserved is the quantity this call reserved. fullyReserved is true when the whole outstanding quantity of the line is reserved. A line that is already fully reserved answers Success with reserved 0, fullyReserved true and no entries. When only part of the requested quantity can be reserved, the call answers LinesSkipped and keeps nothing: all or nothing. The call runs in its own transaction and does not post.', Comment = 'is-IS=quantity er valkvætt. Án þess tekur kallið frá útistandandi magn sem er ekki enn frátekið. reserved er magnið sem þetta kall tók frá. fullyReserved er true þegar allt útistandandi magn línunnar er frátekið. Lína sem er þegar að fullu frátekin svarar Success með reserved 0, fullyReserved true og engum færslum. Þegar aðeins er hægt að taka hluta umbeðins magns frá svarar kallið LinesSkipped og heldur engu: allt eða ekkert. Kallið keyrir í eigin færslu og bókar ekki.';
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
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Reserv. AutoReserve Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Reserv. AutoReserve Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    local procedure HasTablePermissions(): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
        SalesLine: Record "Sales Line";
        Item: Record Item;
    begin
        if not ReservationEntry.WritePermission() then
            exit(false);
        if not SalesLine.ReadPermission() then
            exit(false);
        exit(Item.ReadPermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Full ori (með viðbótinni BIFROST InvWrite ori) og Business Central heimildasafni sem getur breytt þessum töflum.';
        DomainDisabledErr: Label 'The Reservations domain is turned off for this company.', Comment = 'is-IS=Slökkt er á frátekningasviðinu fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á sviðinu á síðunni Uppsetning birgða.';
    begin
        if not InventorySetup.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
            exit(false);
        end;
        if HasTablePermissions() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        HasSystemId: Boolean;
        HasDocumentKeys: Boolean;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo, lineNo, systemId and quantity.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo, lineNo, systemId og quantity.';
        ConflictErr: Label 'systemId was sent together with document keys.', Comment = 'is-IS=systemId var sent ásamt lyklum fylgiskjals.';
        ConflictNextStepLbl: Label 'Send systemId or the document keys, not both.', Comment = 'is-IS=Sendu systemId eða lykla fylgiskjalsins, ekki hvort tveggja.';
        IdentifierMissingErr: Label 'The sales line is not identified.', Comment = 'is-IS=Sölulínan er ekki tilgreind.';
        KeyMissingErr: Label '%1 is required.', Comment = '%1 = key name, is-IS=%1 er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send documentType, documentNo and lineNo, or systemId.', Comment = 'is-IS=Sendu documentType, documentNo og lineNo, eða systemId.';
        SalesLineExpectedLbl: Label 'a sales order line', Comment = 'is-IS=sölupöntunarlína';
        DocumentNoExpectedLbl: Label 'a sales order number', Comment = 'is-IS=númer sölupöntunar';
        DocumentTypeErr: Label 'Only sales order lines can be auto-reserved.', Comment = 'is-IS=Aðeins er hægt að taka sölupöntunarlínur sjálfvirkt frá.';
        DocumentTypeNextStepLbl: Label 'Send documentType Order.', Comment = 'is-IS=Sendu documentType Order.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['documentType', 'documentNo', 'lineNo', 'systemId', 'quantity']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        HasSystemId := RequestJson.Contains('systemId');
        HasDocumentKeys := RequestJson.Contains('documentType') or RequestJson.Contains('documentNo') or RequestJson.Contains('lineNo');
        if HasSystemId and HasDocumentKeys then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, 'systemId', ReadText(RequestJson, 'systemId'), '', ConflictNextStepLbl);
            exit(false);
        end;
        if not HasSystemId and not HasDocumentKeys then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, IdentifierMissingErr, 'documentNo', '', SalesLineExpectedLbl, MissingNextStepLbl);
            exit(false);
        end;
        if HasDocumentKeys then begin
            if not RequestJson.Contains('documentType') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(KeyMissingErr, 'documentType'), 'documentType', '', OrderTok, MissingNextStepLbl);
                exit(false);
            end;
            if not RequestJson.Contains('documentNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(KeyMissingErr, 'documentNo'), 'documentNo', '', DocumentNoExpectedLbl, MissingNextStepLbl);
                exit(false);
            end;
            if not RequestJson.Contains('lineNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(KeyMissingErr, 'lineNo'), 'lineNo', '', '', MissingNextStepLbl);
                exit(false);
            end;
            if not IsInteger(RequestJson, 'lineNo') then begin
                RespondFormat(Argument, 'lineNo', ReadText(RequestJson, 'lineNo'));
                exit(false);
            end;
            if UpperCase(ReadText(RequestJson, 'documentType')) <> UpperCase(OrderTok) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentTypeErr, 'documentType', ReadText(RequestJson, 'documentType'), OrderTok, DocumentTypeNextStepLbl);
                exit(false);
            end;
        end;
        if HasSystemId and not IsGuid(RequestJson, 'systemId') then begin
            RespondFormat(Argument, 'systemId', ReadText(RequestJson, 'systemId'));
            exit(false);
        end;
        exit(ValidateQuantity(Argument, RequestJson));
    end;

    local procedure ValidateQuantity(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        QuantityErr: Label 'quantity must be greater than zero.', Comment = 'is-IS=quantity verður að vera stærra en núll.';
        QuantityExpectedLbl: Label 'greater than zero', Comment = 'is-IS=stærra en núll';
        QuantityNextStepLbl: Label 'Send a quantity greater than zero, or leave quantity out.', Comment = 'is-IS=Sendu quantity sem er stærra en núll, eða slepptu quantity.';
    begin
        if not RequestJson.Contains('quantity') then
            exit(true);
        if not IsDecimal(RequestJson, 'quantity') then begin
            RespondFormat(Argument, 'quantity', ReadText(RequestJson, 'quantity'));
            exit(false);
        end;
        if ReadDecimal(RequestJson, 'quantity') <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, QuantityErr, 'quantity', ReadText(RequestJson, 'quantity'), QuantityExpectedLbl, QuantityNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text)
    var
        FormatErr: Label '%1 has the wrong type.', Comment = '%1 = key name, is-IS=%1 er af rangri gerð.';
        IntegerExpectedLbl: Label 'an integer', Comment = 'is-IS=heiltala';
        NumberExpectedLbl: Label 'a number', Comment = 'is-IS=tala';
        GuidExpectedLbl: Label 'a GUID', Comment = 'is-IS=GUID-auðkenni';
        IntegerNextStepLbl: Label 'Send lineNo as an integer.', Comment = 'is-IS=Sendu lineNo sem heiltölu.';
        NumberNextStepLbl: Label 'Send quantity as a number.', Comment = 'is-IS=Sendu quantity sem tölu.';
        GuidNextStepLbl: Label 'Send systemId as a GUID.', Comment = 'is-IS=Sendu systemId sem GUID.';
    begin
        case KeyName of
            'lineNo':
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Received, IntegerExpectedLbl, IntegerNextStepLbl);
            'quantity':
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Received, NumberExpectedLbl, NumberNextStepLbl);
            else
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Received, GuidExpectedLbl, GuidNextStepLbl);
        end;
    end;

    local procedure IsInteger(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Result: Integer;
    begin
        if not HasValue(RequestJson, KeyName) then
            exit(false);
        exit(Evaluate(Result, ReadText(RequestJson, KeyName), 9));
    end;

    local procedure IsDecimal(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Result: Decimal;
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

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Result: Decimal;
    begin
        if not Evaluate(Result, ReadText(RequestJson, KeyName), 9) then
            exit(0);
        exit(Result);
    end;
}
