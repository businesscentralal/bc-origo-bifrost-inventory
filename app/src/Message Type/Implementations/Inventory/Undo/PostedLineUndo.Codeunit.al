namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory;
using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.History;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>Shares validation and help while retaining the distinct native undo routines and their transaction boundary.</summary>
codeunit 10077014 "Posted Line Undo ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SelectNextLbl: Label 'Send documentNo and a nonempty lineNos array of unique positive line numbers from that posted document (maximum 200).', Comment = 'is-IS=Sendu documentNo og lineNos fylki með einstökum jákvæðum línunúmerum úr sama bókaða skjali (að hámarki 200).';
        CreditNextLbl: Label 'Use a credit memo instead for invoiced or applied entries. Read the posted document and correct the native restriction before retrying.', Comment = 'is-IS=Notaðu kreditreikning í staðinn fyrir reikningsfærðar eða jafnaðar færslur. Lestu bókaða skjalið og leiðréttu innbyggðu takmörkunina áður en reynt er aftur.';
        DocumentLbl: Label 'Number of the posted document, at most 20 characters. Subject is not used.', Comment = 'is-IS=Númer bókaða skjalsins, að hámarki 20 stafir. Subject er ekki notað.';
        LinesLbl: Label 'Unique positive posted line numbers to undo, 1 to 200 entries. Only these lines are selected; omitted lines are unchanged.', Comment = 'is-IS=Einstök jákvæð númer bókaðra lína sem á að afturkalla, 1 til 200 færslur. Aðeins þessar línur eru valdar; öðrum línum er ekki breytt.';
        CountLbl: Label 'expectedCount counts the one posted document, always 1, not its selected lines or ledger entries. Always checked when sent; required when irreversible confirmation is enabled in Bifrost Setup. When enabled, omit it to preview without posting.', Comment = 'is-IS=expectedCount telur eina bókaða skjalið, alltaf 1, ekki valdar línur þess eða fjárhagsfærslur. Alltaf athugað þegar sent; nauðsynlegt þegar staðfesting óafturkræfra aðgerða er virk í Bifröst uppsetningu. Þegar hún er virk má sleppa því til að forskoða án bókunar.';
        EffectLbl: Label 'Irreversible: posts corrective entries for the selected lines, without deleting the posted document. expectedCount counts one posted document, always 1, not the selected lines or ledger entries. Standalone undo commits its native transaction. Omit Commit keeps the operation in the caller transaction and propagates native errors.', Comment = 'is-IS=Óafturkræft: bókar leiðréttingarfærslur fyrir valdar línur án þess að eyða bókaða skjalinu. expectedCount telur eitt bókað skjal, alltaf 1, ekki valdar línur eða fjárhagsfærslur. Sjálfstæð afturköllun staðfestir innbyggðu færsluna. Omit Commit heldur aðgerðinni í færslu kallandans og lætur innbyggðar villur berast áfram.';
        NotesLbl: Label 'Use the native Undo Shipment or Undo Receipt restrictions. All selected lines are checked before reversal. Invoiced, already corrected, zero quantity or invalid lines are refused; native application and warehouse checks remain in force. A refusal leaves the whole selected set unchanged. expectedCount counts the one posted document (1), not its lines. Missing confirmation previews without posting when Foundation confirmation is enabled. Bifrost Full Access, Inv. Posting Gate and native posted document permissions are required. Return shipment and return receipt undo are separate operations.', Comment = 'is-IS=Innbyggðar takmarkanir Afturkalla afhendingu eða Afturkalla móttöku gilda. Allar valdar línur eru athugaðar fyrir afturköllun. Reikningsfærðum, þegar leiðréttum, ógildum línum eða línum án magns er hafnað; innbyggðar jafningar- og vöruhúsaathuganir gilda áfram. Höfnun skilur allar valdar línur óbreyttar. expectedCount telur eina bókaða skjalið (1), ekki línur þess. Vanti staðfestingu fæst forskoðun án bókunar þegar staðfesting Foundation er virk. Fullur Bifröst aðgangur, Bókunarhlið birgða og innbyggðar heimildir á bókaða skjalið eru nauðsynlegar. Afturköllun skilaafhendingar og skilamóttöku eru aðrar aðgerðir.';

    /// <summary>Checks native table permissions and the independent Inventory posting gate.</summary>
    procedure IsEnabled(HeaderTableNo: Integer): Boolean
    var
        PostingGate: Codeunit "Inv. Posting Gate ori";
        HeaderRef: RecordRef;
        LineRef: RecordRef;
        Allowed: Boolean;
    begin
        HeaderRef.Open(HeaderTableNo);
        if HeaderTableNo = Database::"Sales Shipment Header" then
            LineRef.Open(Database::"Sales Shipment Line")
        else
            LineRef.Open(Database::"Purch. Rcpt. Line");
        Allowed := HeaderRef.ReadPermission() and HeaderRef.WritePermission() and LineRef.ReadPermission() and LineRef.WritePermission() and PostingGate.HasPostingPermission();
        HeaderRef.Close();
        LineRef.Close();
        exit(Allowed);
    end;

    /// <summary>Declares the data-only request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', DocumentLbl);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Names the posted document for default one-document confirmation.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', DocumentLbl));
        exit(true);
    end;

    /// <summary>Declares the document and explicit line selection. Foundation adds its confirmation parameter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, DocumentLbl));
        Parameters.Add(ContractMgt.Parameter('lineNos', 'array', true, LinesLbl));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', false, CountLbl));
        exit(true);
    end;

    /// <summary>Describes only the original lines actually reversed by this call.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', DocumentLbl));
        Fields.Add(ContractMgt.ResponseField('reversedLineNos', 'array', LinesLbl));
        Fields.Add(ContractMgt.ResponseField('reversedCount', 'integer', LinesLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Documents coded refusals and their recovery steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, SelectNextLbl, SelectNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, SelectNextLbl, SelectNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, SelectNextLbl, SelectNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, DocumentLbl, SelectNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, NotesLbl, SelectNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotesLbl, CreditNextLbl));
        exit(true);
    end;

    /// <summary>Declares corrective posting, commit semantics and the confirmation count unit in both supported languages.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('posts', true);
        Effect.Add('idempotent', false);
        Effect.Add('changes', EffectLbl);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        exit(true);
    end;

    /// <summary>Supplies bilingual native restriction and confirmation guidance.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Validates the complete request before passing the filtered selection to the matching native routine.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Sales: Boolean)
    var
        LineNos: List of [Integer];
        DocumentNo: Code[20];
        HeaderTableNo: Integer;
        PermissionLbl: Label 'Undo requires native posted document write permission and Inv. Posting Gate.', Comment = 'is-IS=Afturköllun krefst innbyggðrar skrifheimildar á bókaða skjalið og Bókunarhlið birgða.';
        PermissionNextLbl: Label 'Ask an administrator to assign Bifrost Full Access, Inv. Posting Gate and the native posted document permissions.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta fullum Bifröst aðgangi, Bókunarhlið birgða og innbyggðum heimildum á bókaða skjalið.';
    begin
        if Sales then
            HeaderTableNo := Database::"Sales Shipment Header"
        else
            HeaderTableNo := Database::"Purch. Rcpt. Header";
        if not IsEnabled(HeaderTableNo) then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', '', PermissionNextLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not ReadSelection(Argument, DocumentNo, LineNos, false) then
            exit;
        if Sales then
            UndoSales(Argument, DocumentNo, LineNos, false)
        else
            UndoPurchase(Argument, DocumentNo, LineNos, false);
    end;

    /// <summary>Checks the posted document and lines before confirmation. Does not undo.</summary>
    procedure ValidateForConfirm(var Argument: Record "Message Argument ori"; Sales: Boolean): Boolean
    var
        LineNos: List of [Integer];
        DocumentNo: Code[20];
        HeaderTableNo: Integer;
        PermissionLbl: Label 'Undo requires native posted document write permission and Inv. Posting Gate.', Comment = 'is-IS=Afturköllun krefst innbyggðrar skrifheimildar á bókaða skjalið og Bókunarhlið birgða.';
        PermissionNextLbl: Label 'Ask an administrator to assign Bifrost Full Access, Inv. Posting Gate and the native posted document permissions.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta fullum Bifröst aðgangi, Bókunarhlið birgða og innbyggðum heimildum á bókaða skjalið.';
    begin
        if Sales then
            HeaderTableNo := Database::"Sales Shipment Header"
        else
            HeaderTableNo := Database::"Purch. Rcpt. Header";
        if not IsEnabled(HeaderTableNo) then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', '', PermissionNextLbl);
            exit(false);
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not ReadSelection(Argument, DocumentNo, LineNos, true) then
            exit(false);
        if Sales then
            UndoSales(Argument, DocumentNo, LineNos, true)
        else
            UndoPurchase(Argument, DocumentNo, LineNos, true);
        exit(not Argument.HasCollectedErrors());
    end;

    local procedure ReadSelection(
        var Argument: Record "Message Argument ori";
        var DocumentNo: Code[20];
        var LineNos: List of [Integer];
        IgnoreExpectedCount: Boolean): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        LineToken: JsonToken;
        KeyName: Text;
        RawValue: Text;
        Number: Integer;
        MissingLbl: Label 'A required undo parameter is missing.', Comment = 'is-IS=Nauðsynlega færibreytu afturköllunar vantar.';
        InvalidLbl: Label 'The undo selection is invalid.', Comment = 'is-IS=Val fyrir afturköllun er ógilt.';
        UnknownLbl: Label 'The undo request contains an unknown parameter.', Comment = 'is-IS=Beiðni um afturköllun inniheldur óþekkta færibreytu.';
    begin
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not (KeyName in ['documentNo', 'lineNos', 'expectedCount']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownLbl, KeyName, '', SelectNextLbl);
                exit(false);
            end;
        if not Request.Get('documentNo', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'documentNo', '', SelectNextLbl);
            exit(false);
        end;
        Token.WriteTo(RawValue);
        if not RawValue.StartsWith('"') then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'documentNo', RawValue, SelectNextLbl);
            exit(false);
        end;
        RawValue := Token.AsValue().AsText();
        if (RawValue.Trim() = '') or (StrLen(RawValue) > MaxStrLen(DocumentNo)) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'documentNo', RawValue, SelectNextLbl);
            exit(false);
        end;
        DocumentNo := CopyStr(RawValue, 1, MaxStrLen(DocumentNo));
        if not Request.Get('lineNos', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'lineNos', '', SelectNextLbl);
            exit(false);
        end;
        if not Token.IsArray() then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'lineNos', '', SelectNextLbl);
            exit(false);
        end;
        if (Token.AsArray().Count() = 0) or (Token.AsArray().Count() > 200) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'lineNos', '', SelectNextLbl);
            exit(false);
        end;
        if not IgnoreExpectedCount then
            if Request.Get('expectedCount', LineToken) then begin
                LineToken.WriteTo(RawValue);
                if not Evaluate(Number, RawValue, 9) then begin
                    Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'expectedCount', RawValue, CountLbl);
                    exit(false);
                end;
                if Number <> 1 then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, InvalidLbl, 'expectedCount', RawValue, CountLbl);
                    exit(false);
                end;
            end;
        foreach LineToken in Token.AsArray() do begin
            LineToken.WriteTo(RawValue);
            if not Evaluate(Number, RawValue, 9) then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'lineNos', RawValue, SelectNextLbl);
                exit(false);
            end;
            if (Number <= 0) or LineNos.Contains(Number) then begin
                Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidLbl, 'lineNos', RawValue, SelectNextLbl);
                exit(false);
            end;
            LineNos.Add(Number);
        end;
        exit(true);
    end;

    local procedure UndoSales(
        var Argument: Record "Message Argument ori";
        DocumentNo: Code[20];
        LineNos: List of [Integer];
        ConfirmOnly: Boolean)
    var
        Header: Record "Sales Shipment Header";
        Line: Record "Sales Shipment Line";
        Undo: Codeunit "Undo Sales Shipment Line";
        LineNo: Integer;
    begin
        if not Header.Get(DocumentNo) then begin
            NotFound(Argument, 'documentNo', DocumentNo);
            exit;
        end;
        foreach LineNo in LineNos do begin
            if not Line.Get(DocumentNo, LineNo) then begin
                NotFound(Argument, 'lineNos', Format(LineNo, 0, 9));
                exit;
            end;
            if Line.Correction or (Line.Quantity = 0) or (Line."Quantity Invoiced" <> 0) then begin
                InvalidLine(Argument, LineNo);
                exit;
            end;
            // Read-only native application checks make refusals coded even in an Omit Commit chain.
            if Line.Type = Line.Type::Item then
                if not CheckEntries(Database::"Sales Shipment Line", DocumentNo, LineNo, Line."Quantity (Base)", Line."Item Shpt. Entry No.") then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'lineNos', Format(LineNo, 0, 9), CreditNextLbl);
                    exit;
                end;
            if not ConfirmOnly then
                Line.Mark(true);
        end;
        if ConfirmOnly then
            exit;
        Line.SetRange("Document No.", DocumentNo);
        Line.MarkedOnly(true);
        // Preserve the native routine's default locking semantics.
        Line.ReadIsolation := IsolationLevel::Default;
        Line.FindFirst();
        Undo.SetHideDialog(true);
        if Argument."Omit Commit" then
            Undo.Run(Line)
        else
            if not Undo.Run(Line) then begin
                Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'lineNos', '', CreditNextLbl);
                exit;
            end;
        Respond(Argument, DocumentNo, LineNos);
    end;

    local procedure UndoPurchase(
        var Argument: Record "Message Argument ori";
        DocumentNo: Code[20];
        LineNos: List of [Integer];
        ConfirmOnly: Boolean)
    var
        Header: Record "Purch. Rcpt. Header";
        Line: Record "Purch. Rcpt. Line";
        Undo: Codeunit "Undo Purchase Receipt Line";
        LineNo: Integer;
    begin
        if not Header.Get(DocumentNo) then begin
            NotFound(Argument, 'documentNo', DocumentNo);
            exit;
        end;
        foreach LineNo in LineNos do begin
            if not Line.Get(DocumentNo, LineNo) then begin
                NotFound(Argument, 'lineNos', Format(LineNo, 0, 9));
                exit;
            end;
            if Line.Correction or (Line.Quantity = 0) or (Line."Quantity Invoiced" <> 0) then begin
                InvalidLine(Argument, LineNo);
                exit;
            end;
            // Read-only native application checks make refusals coded even in an Omit Commit chain.
            if Line.Type = Line.Type::Item then
                if not CheckEntries(Database::"Purch. Rcpt. Line", DocumentNo, LineNo, Line."Quantity (Base)", Line."Item Rcpt. Entry No.") then begin
                    Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'lineNos', Format(LineNo, 0, 9), CreditNextLbl);
                    exit;
                end;
            if not ConfirmOnly then
                Line.Mark(true);
        end;
        if ConfirmOnly then
            exit;
        Line.SetRange("Document No.", DocumentNo);
        Line.MarkedOnly(true);
        // Preserve the native routine's default locking semantics.
        Line.ReadIsolation := IsolationLevel::Default;
        Line.FindFirst();
        Undo.SetHideDialog(true);
        if Argument."Omit Commit" then
            Undo.Run(Line)
        else
            if not Undo.Run(Line) then begin
                Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'lineNos', '', CreditNextLbl);
                exit;
            end;
        Respond(Argument, DocumentNo, LineNos);
    end;

    // Only the temporary entry buffer is written; native posting still performs its own checks again.
    [TryFunction]
    local procedure CheckEntries(
        SourceTableNo: Integer;
        DocumentNo: Code[20];
        LineNo: Integer;
        QuantityBase: Decimal;
        EntryNo: Integer)
    var
        TempEntry: Record "Item Ledger Entry" temporary;
        UndoManagement: Codeunit "Undo Posting Management";
    begin
        UndoManagement.CollectItemLedgEntries(TempEntry, SourceTableNo, DocumentNo, LineNo, QuantityBase, EntryNo);
        UndoManagement.CheckItemLedgEntries(TempEntry, LineNo);
    end;

    local procedure InvalidLine(
        var Argument: Record "Message Argument ori";
        LineNo: Integer)
    var
        InvalidLbl: Label 'Posted line %1 is invoiced, already corrected or has no quantity to undo.', Comment = '%1 = line number, is-IS=Bókuð lína %1 er reikningsfærð, þegar leiðrétt eða hefur ekkert magn til afturköllunar.';
    begin
        Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(InvalidLbl, LineNo), 'lineNos', Format(LineNo, 0, 9), CreditNextLbl);
    end;

    local procedure NotFound(
        var Argument: Record "Message Argument ori";
        ParameterName: Text;
        Received: Text)
    var
        NotFoundLbl: Label 'The posted document or selected line was not found.', Comment = 'is-IS=Bókaða skjalið eða valin lína fannst ekki.';
    begin
        Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, ParameterName, Received, SelectNextLbl);
    end;

    local procedure Refuse(
        var Argument: Record "Message Argument ori";
        ErrorCode: Enum "Bifrost Error Code ori";
        MessageText: Text;
        ParameterName: Text;
        Received: Text;
        NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, MessageText, ParameterName, Received, '', NextStep);
    end;

    local procedure Respond(
        var Argument: Record "Message Argument ori";
        DocumentNo: Code[20];
        LineNos: List of [Integer])
    var
        Response: JsonObject;
        Reversed: JsonArray;
        LineNo: Integer;
    begin
        foreach LineNo in LineNos do
            Reversed.Add(LineNo);
        Response.Add('status', 'Success');
        Response.Add('documentNo', DocumentNo);
        Response.Add('reversedLineNos', Reversed);
        Response.Add('reversedCount', LineNos.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
