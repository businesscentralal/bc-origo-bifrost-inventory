namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reservation.AutoReserve lets a caller reserve a sales line. Supply is chosen by Reservation Management.
/// </summary>
codeunit 70013430 "Reserv. AutoReserve Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not ReservationEntry.WritePermission() then
            exit(false);
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reserves a sales line from available supply.', Comment = 'is-IS=Tekur sölulínu frá úr tiltæku magni.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'auto reserve, sales line, reservation', Comment = 'is-IS=sjálfvirk frátekning, sölulína, frátekning';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reserves the outstanding quantity of one sales line.', Comment = 'is-IS=Tekur útistandandi magn einnar sölulínu frá.';
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
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Reservation Management');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'documentType');
        ParameterJson.Add('type', 'text');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lineNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'systemId');
        ParameterJson.Add('type', 'guid');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'quantity');
        ParameterJson.Add('type', 'decimal');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('reserved', 0);
        Response.Add('fullyReserved', true);
        Response.Add('entries', 'array');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required key is missing.', 'Send documentType, documentNo and lineNo, or systemId.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong type.', 'Send lineNo as an integer, quantity as a number, and systemId as a GUID.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'systemId was sent with document keys.', 'Send systemId or the document keys, not both.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The sales line was not found.', 'Check the document and line no.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The item reserve setting is Never, or the line cannot be reserved.', 'Change the item''s Reserve setting or reserve manually.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LinesSkipped, 'Only part of the quantity could be reserved.', 'Read Inventory.Reservation.Get for what was reserved.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot write reservation entries.', 'Use the BIFROST InvWrite ori permission set.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Reservation Entry');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read the reservations on the line.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Create', 'Reserve a quantity for an item without a sales line.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a reservation entry.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.OrderTracking.Get', 'Read which supply is tracked against the line.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Data: JsonObject;
    begin
        Data.Add('documentType', 'Order');
        Data.Add('documentNo', '101005');
        Data.Add('lineNo', 10000);
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reserves a sales line from available supply. Send documentType, documentNo and lineNo, or systemId. quantity is optional and defaults to the quantity that is still unreserved. A line that is already fully reserved returns reserved 0 and fullyReserved true. A partial reserve is refused and nothing is kept.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        InventorySetup: Record "Inventory Setup ori";
        RequestJson: JsonObject;
    begin
        if not ReservationEntry.WritePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, 'Permission denied for this inventory message type.', '', '', '', 'Use the BIFROST InvWrite ori permission set.');
            exit;
        end;
        if not InventorySetup.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, 'Permission denied for this inventory message type.', '', '', '', 'Use the BIFROST InvWrite ori permission set.');
            exit;
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'The Reservations domain is turned off for this company.', 'domain', 'Reservations', 'on', 'Turn the domain on from the Inventory Setup page.');
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if not Codeunit.Run(Codeunit::"Reserv. AutoReserve Proc ori", Argument) then
            if StrPos(GetLastErrorText(), PartialMarkerTok) > 0 then
                Argument.RespondWithError("Bifrost Error Code ori"::LinesSkipped, 'Only part of the quantity could be reserved.', 'quantity', '', '', 'Read Inventory.Reservation.Get for what was reserved.')
            else
                Argument.RespondWithLastError();
    end;

    var
        PartialMarkerTok: Label 'Only part of the quantity could be reserved.', Locked = true;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        HasSystemId: Boolean;
        HasDocumentKeys: Boolean;
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['documentType', 'documentNo', 'lineNo', 'systemId', 'quantity']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key.');
                exit(false);
            end;
        HasSystemId := RequestJson.Contains('systemId');
        HasDocumentKeys := RequestJson.Contains('documentType') or RequestJson.Contains('documentNo') or RequestJson.Contains('lineNo');
        if HasSystemId and HasDocumentKeys then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send systemId or the document keys, not both.', 'systemId', '', 'documentNo', 'Send systemId or the document keys, not both.');
            exit(false);
        end;
        if not HasSystemId and not HasDocumentKeys then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'documentType, documentNo and lineNo, or systemId, are required.', 'documentNo', '', 'a sales line', 'Send documentType, documentNo and lineNo, or systemId.');
            exit(false);
        end;
        if HasDocumentKeys then begin
            if not RequestJson.Contains('documentType') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'documentType is required.', 'documentType', '', 'Order', 'Send documentType, documentNo and lineNo, or systemId.');
                exit(false);
            end;
            if not RequestJson.Contains('documentNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'documentNo is required.', 'documentNo', '', 'a document number', 'Send documentType, documentNo and lineNo, or systemId.');
                exit(false);
            end;
            if not RequestJson.Contains('lineNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'lineNo is required.', 'lineNo', '', 'an integer', 'Send documentType, documentNo and lineNo, or systemId.');
                exit(false);
            end;
            if not IsInteger(RequestJson, 'lineNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'lineNo must be an integer.', 'lineNo', ReadText(RequestJson, 'lineNo'), 'an integer', 'Send lineNo as an integer.');
                exit(false);
            end;
        end;
        if HasSystemId and not IsGuid(RequestJson, 'systemId') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'systemId must be a GUID.', 'systemId', ReadText(RequestJson, 'systemId'), 'a GUID', 'Send systemId as a GUID.');
            exit(false);
        end;
        if RequestJson.Contains('quantity') and not IsDecimal(RequestJson, 'quantity') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'quantity must be a number.', 'quantity', ReadText(RequestJson, 'quantity'), 'a number', 'Send quantity as a number.');
            exit(false);
        end;
        if RequestJson.Contains('quantity') and (ReadDecimal(RequestJson, 'quantity') <= 0) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'quantity must be greater than zero.', 'quantity', ReadText(RequestJson, 'quantity'), 'greater than zero', 'Send a quantity greater than zero, or omit quantity.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure IsInteger(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Result: Integer;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
    end;

    local procedure IsDecimal(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Result: Decimal;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
    end;

    local procedure IsGuid(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Result: Guid;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
        Result: Decimal;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() and Evaluate(Result, Token.AsValue().AsText()) then
            exit(Result);
        exit(0);
    end;
}
