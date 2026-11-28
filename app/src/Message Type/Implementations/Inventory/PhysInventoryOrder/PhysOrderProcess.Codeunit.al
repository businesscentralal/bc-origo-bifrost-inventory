namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Counting.Document;
using Microsoft.Inventory.Counting.History;
using Microsoft.Inventory.Counting.Recording;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Runs the native physical inventory order lifecycle in a rollback boundary.</summary>
codeunit 10076963 "Phys Order Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        NativeJournal: Codeunit "Inventory Native Journal ori";
        Reader: Codeunit "Request Value Reader ori";
        Operation: Text;
        DocumentNo: Code[20];
        ItemFilter: Text;
        LocationCode: Code[10];
        DescriptionText: Text[100];
        PostingDate: Date;
        IncludeZero: Boolean;
        IncludeUntransacted: Boolean;
        Counts: JsonArray;
        InvalidInputLbl: Label 'The physical inventory order request contains an invalid value.', Comment = 'is-IS=Beiðnin um birgðatalningarpöntun inniheldur ógilt gildi.';
        InputNextStepLbl: Label 'Use the documented JSON types and lengths. Create needs itemNoFilter; Finish and Post need documentNo. Each count needs recordingNo, lineNo and a nonnegative quantity.', Comment = 'is-IS=Notaðu skjalfestar JSON-gerðir og lengdir. Create þarf itemNoFilter; Finish og Post þurfa documentNo. Hver talning þarf recordingNo, lineNo og magn sem er ekki neikvætt.';
        StateNextStepLbl: Label 'Read the order and its recordings in Business Central. Finish every recording and the order before posting; do not repeat a completed operation.', Comment = 'is-IS=Skoðaðu pöntunina og skráningar hennar í Business Central. Ljúktu öllum skráningum og pöntuninni fyrir bókun; ekki endurtaka aðgerð sem er lokið.';
        StateErr: Label 'The physical inventory order or recording is not in the required state.', Comment = 'is-IS=Birgðatalningarpöntunin eða skráningin er ekki í réttri stöðu.';
        EmptyErr: Label 'The selection contains no physical inventory order lines.', Comment = 'is-IS=Valið inniheldur engar línur birgðatalningarpöntunar.';
        MissingOrderErr: Label 'Physical inventory order %1 was not found.', Comment = '%1 = order number; is-IS=Birgðatalningarpöntun %1 fannst ekki.';
        MissingLineErr: Label 'A count names an unknown, finished or duplicate recording line.', Comment = 'is-IS=Talning vísar í óþekkta eða lokna skráningarlínu eða sömu línu oftar en einu sinni.';
        NativeStateErr: Label 'The physical inventory order or recording changed. Nothing was changed by this request.', Comment = 'is-IS=Birgðatalningarpöntunin eða skráningin hefur breyst. Þessi beiðni breytti engu.';
        RestrictedErr: Label 'A physical inventory field required by this operation is restricted for writing.', Comment = 'is-IS=Skrif í birgðatalningarreit sem aðgerðin krefst eru takmörkuð.';

    trigger OnRun()
    var
        Header: Record "Phys. Invt. Order Header";
        Response: JsonObject;
    begin
        case Operation of
            'Create':
                CreateOrder(Header);
            'Finish', 'Post':
                begin
                    Header.LockTable();
                    Header.Get(DocumentNo);
                    if Operation = 'Finish' then
                        FinishOrder(Header)
                    else
                        PostOrder(Header, Response);
                end;
        end;
        if Operation <> 'Post' then
            BuildResponse(Header, Response);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    /// <summary>Checks all native table permissions used by the lifecycle; posting additionally needs the native posting permission.</summary>
    procedure HasPermission(NewOperation: Text): Boolean
    var
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Order Line";
        Recording: Record "Phys. Invt. Record Header";
        RecordingLine: Record "Phys. Invt. Record Line";
    begin
        if not (Header.ReadPermission() and Header.WritePermission() and Line.ReadPermission() and Line.WritePermission() and
            Recording.ReadPermission() and Recording.WritePermission() and RecordingLine.ReadPermission() and RecordingLine.WritePermission()) then
            exit(false);
        if NewOperation = 'Post' then
            exit(NativeJournal.HasItemPostingPermission());
        exit(true);
    end;

    /// <summary>Returns an actionable refusal when the caller lacks native lifecycle permissions.</summary>
    procedure AssertPermission(var Argument: Record "Message Argument ori"; NewOperation: Text): Boolean
    var
        PermissionErr: Label 'Native physical inventory permissions are required.', Comment = 'is-IS=Staðlaðar heimildir fyrir birgðatalningu eru nauðsynlegar.';
        PermissionNextStepLbl: Label 'Ask an administrator for native physical inventory order and recording permissions, and item posting permission for Post.', Comment = 'is-IS=Biðjið kerfisstjóra um staðlaðar heimildir fyrir birgðatalningarpantanir og skráningar og vörubókunarheimild fyrir Post.';
    begin
        if not HasPermission(NewOperation) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', PermissionNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Checks the create schema without changing inventory.</summary>
    procedure PrepareCreate(var Argument: Record "Message Argument ori"): Boolean
    var
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Order Line";
        Request: JsonObject;
        Value: Text;
    begin
        Operation := 'Create';
        Request := Argument.GetRequestJson();
        if not ReadText(Argument, Request, 'itemNoFilter', 250, true, ItemFilter) then
            exit(false);
        if not ReadText(Argument, Request, 'locationCode', 10, false, Value) then
            exit(false);
        LocationCode := CopyStr(Value, 1, MaxStrLen(LocationCode));
        if not ReadText(Argument, Request, 'description', 100, false, Value) then
            exit(false);
        DescriptionText := CopyStr(Value, 1, MaxStrLen(DescriptionText));
        if not Reader.TryReadDate(Argument, Request, 'postingDate', false, PostingDate) then
            exit(false);
        if PostingDate = 0D then
            PostingDate := WorkDate();
        if not Reader.TryReadBoolean(Argument, Request, 'includeZero', false, IncludeZero) then
            exit(false);
        if not Reader.TryReadBoolean(Argument, Request, 'includeUntransacted', false, IncludeUntransacted) then
            exit(false);
        if IncludeUntransacted and not IncludeZero then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, 'includeUntransacted', InputNextStepLbl));
        if Reader.IsFieldWriteRestricted(Database::"Phys. Invt. Order Header", Header.FieldNo("Posting Date")) or
           Reader.IsFieldWriteRestricted(Database::"Phys. Invt. Order Line", Line.FieldNo("Item No.")) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::BlockedByWriteGuard, RestrictedErr, '', InputNextStepLbl));
        exit(true);
    end;

    /// <summary>Checks the recording identifiers and every count before native finishing.</summary>
    procedure PrepareFinish(var Argument: Record "Message Argument ori"): Boolean
    var
        RecordingLine: Record "Phys. Invt. Record Line";
        Request: JsonObject;
        Token: JsonToken;
    begin
        if not PrepareDocument(Argument, 'Finish') then
            exit(false);
        if Reader.IsFieldWriteRestricted(Database::"Phys. Invt. Record Line", RecordingLine.FieldNo(Quantity)) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::BlockedByWriteGuard, RestrictedErr, 'counts', InputNextStepLbl));
        Request := Argument.GetRequestJson();
        if Request.Get('counts', Token) then begin
            if not Token.IsArray() then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidInputLbl, 'counts', InputNextStepLbl));
            Counts := Token.AsArray();
            if Counts.Count() > 1000 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::LimitExceeded, InvalidInputLbl, 'counts', InputNextStepLbl));
            if not ValidateCounts(Argument) then
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>Validates the order for posting without the expectedCount equality check.</summary>
    procedure ValidatePostForConfirm(var Argument: Record "Message Argument ori"): Boolean
    begin
        exit(PrepareDocument(Argument, 'Post'));
    end;

    /// <summary>Validates the one-order posting selector and any explicit confirmation count.</summary>
    procedure PreparePost(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
        ExpectedCount: Decimal;
    begin
        if not PrepareDocument(Argument, 'Post') then
            exit(false);
        Request := Argument.GetRequestJson();
        if Request.Contains('expectedCount') then begin
            if not Reader.TryReadDecimal(Argument, Request, 'expectedCount', true, ExpectedCount) then
                exit(false);
            if ExpectedCount <> 1 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, InvalidInputLbl, 'expectedCount', StateNextStepLbl));
        end;
        exit(true);
    end;

    local procedure PrepareDocument(var Argument: Record "Message Argument ori"; NewOperation: Text): Boolean
    var
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Order Line";
        Request: JsonObject;
        Value: Text;
    begin
        Operation := NewOperation;
        Request := Argument.GetRequestJson();
        if not ReadText(Argument, Request, 'documentNo', 20, Argument.Subject = '', Value) then
            exit(false);
        if Value = '' then
            Value := Argument.Subject;
        if (StrLen(Value) > MaxStrLen(DocumentNo)) or ((Argument.Subject <> '') and (UpperCase(Argument.Subject) <> UpperCase(Value))) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, InvalidInputLbl, 'documentNo', InputNextStepLbl));
        DocumentNo := CopyStr(Value, 1, MaxStrLen(DocumentNo));
        Header.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Header.Get(DocumentNo) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingOrderErr, DocumentNo), 'documentNo', StateNextStepLbl));
        if ((NewOperation = 'Finish') and (Header.Status <> Header.Status::Open)) or
           ((NewOperation = 'Post') and (Header.Status <> Header.Status::Finished)) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateErr, 'documentNo', StateNextStepLbl));
        Line.ReadIsolation := IsolationLevel::ReadCommitted;
        Line.SetRange("Document No.", Header."No.");
        if Line.IsEmpty() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, EmptyErr, 'documentNo', StateNextStepLbl));
        exit(true);
    end;

    local procedure ValidateCounts(var Argument: Record "Message Argument ori"): Boolean
    var
        Recording: Record "Phys. Invt. Record Header";
        Line: Record "Phys. Invt. Record Line";
        Entry: JsonToken;
        Count: JsonObject;
        Seen: List of [Text];
        RecordingNo: Integer;
        LineNo: Integer;
        Quantity: Decimal;
        KeyText: Text;
        Tracking: Text;
    begin
        foreach Entry in Counts do begin
            if not Entry.IsObject() then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidInputLbl, 'counts', InputNextStepLbl));
            Count := Entry.AsObject();
            if not ReadPositiveInteger(Argument, Count, 'recordingNo', RecordingNo) then
                exit(false);
            if not ReadPositiveInteger(Argument, Count, 'lineNo', LineNo) then
                exit(false);
            if not ReadNumber(Argument, Count, 'quantity', Quantity) then
                exit(false);
            if Quantity < 0 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, 'counts.quantity', InputNextStepLbl));
            KeyText := Format(RecordingNo, 0, 9) + '|' + Format(LineNo, 0, 9);
            if Seen.Contains(KeyText) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, MissingLineErr, 'counts', InputNextStepLbl));
            Seen.Add(KeyText);
            if not Recording.Get(DocumentNo, RecordingNo) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, MissingLineErr, 'counts.recordingNo', InputNextStepLbl));
            if (Recording.Status <> Recording.Status::Open) or not Line.Get(DocumentNo, RecordingNo, LineNo) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, MissingLineErr, 'counts.lineNo', InputNextStepLbl));
            if not ReadText(Argument, Count, 'serialNo', 50, false, Tracking) then
                exit(false);
            if not ReadText(Argument, Count, 'lotNo', 50, false, Tracking) then
                exit(false);
            if not ReadText(Argument, Count, 'packageNo', 50, false, Tracking) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure CreateOrder(var Header: Record "Phys. Invt. Order Header")
    var
        Item: Record Item;
        Line: Record "Phys. Invt. Order Line";
        CalculateLines: Report "Calc. Phys. Invt. Order Lines";
        MakeRecording: Report "Make Phys. Invt. Recording";
    begin
        Header.Init();
        Header.Validate("Posting Date", PostingDate);
        Header.Insert(true);
        if LocationCode <> '' then
            Header.Validate("Location Code", LocationCode);
        if DescriptionText <> '' then
            Header.Validate(Description, DescriptionText);
        Header.Modify(true);
        Item.SetFilter("No.", ItemFilter);
        CalculateLines.SetPhysInvtOrderHeader(Header);
        CalculateLines.InitializeRequest(IncludeZero, true, IncludeUntransacted);
        CalculateLines.SetHideValidationDialog(true);
        CalculateLines.SetTableView(Item);
        CalculateLines.UseRequestPage(false);
        CalculateLines.Run();
        Line.SetRange("Document No.", Header."No.");
        if Line.IsEmpty() then
            Error(ErrorInfo.Create(EmptyErr));
        Header.SetRecFilter();
        MakeRecording.SetTableView(Header);
        MakeRecording.UseRequestPage(false);
        MakeRecording.Run();
    end;

    local procedure FinishOrder(var Header: Record "Phys. Invt. Order Header")
    var
        Recording: Record "Phys. Invt. Record Header";
        Line: Record "Phys. Invt. Record Line";
        FinishRecording: Codeunit "Phys. Invt. Rec.-Finish";
        Finish: Codeunit "Phys. Invt. Order-Finish";
        Entry: JsonToken;
        Count: JsonObject;
        Token: JsonToken;
        RecordingNo: Integer;
        LineNo: Integer;
    begin
        Header.TestField(Status, Header.Status::Open);
        Recording.LockTable();
        Line.LockTable();
        foreach Entry in Counts do begin
            Count := Entry.AsObject();
            Count.Get('recordingNo', Token);
            RecordingNo := Token.AsValue().AsDecimal();
            Count.Get('lineNo', Token);
            LineNo := Token.AsValue().AsDecimal();
            Recording.Get(Header."No.", RecordingNo);
            if Recording.Status <> Recording.Status::Open then
                Error(ErrorInfo.Create(NativeStateErr));
            Line.Get(Header."No.", RecordingNo, LineNo);
            if Count.Get('serialNo', Token) then
                Line.Validate("Serial No.", CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(Line."Serial No.")));
            if Count.Get('lotNo', Token) then
                Line.Validate("Lot No.", CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(Line."Lot No.")));
            if Count.Get('packageNo', Token) then
                Line.Validate("Package No.", CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(Line."Package No.")));
            Count.Get('quantity', Token);
            Line.Validate(Quantity, Token.AsValue().AsDecimal());
            Line.Modify(true);
        end;
        Recording.SetRange("Order No.", Header."No.");
        Recording.SetRange(Status, Recording.Status::Open);
        if Recording.FindSet(true) then
            repeat
                Clear(FinishRecording);
                FinishRecording.SetHideProgressWindow(true);
                FinishRecording.Run(Recording);
            until Recording.Next() = 0;
        Finish.SetHideProgressWindow(true);
        Finish.Run(Header);
    end;

    local procedure PostOrder(var Header: Record "Phys. Invt. Order Header"; var Response: JsonObject)
    var
        PostedHeader: Record "Pstd. Phys. Invt. Order Hdr";
        Post: Codeunit "Phys. Invt. Order-Post";
    begin
        Header.TestField(Status, Header.Status::Finished);
        Post.SetSuppressCommit(true);
        Post.SetHideProgressWindow(true);
        Post.Run(Header);
        Response.Add('status', 'Success');
        Response.Add('documentNo', DocumentNo);
        if Header."Posting No." <> '' then
            PostedHeader.Get(Header."Posting No.")
        else
            PostedHeader.Get(DocumentNo);
        Response.Add('postedDocumentNo', PostedHeader."No.");
        Response.Add('posted', true);
    end;

    local procedure BuildResponse(Header: Record "Phys. Invt. Order Header"; var Response: JsonObject)
    var
        OrderLine: Record "Phys. Invt. Order Line";
        Recording: Record "Phys. Invt. Record Header";
        Line: Record "Phys. Invt. Record Line";
        Lines: JsonArray;
        Recordings: JsonArray;
        Row: JsonObject;
        RecordingRow: JsonObject;
    begin
        OrderLine.SetRange("Document No.", Header."No.");
        Recording.SetRange("Order No.", Header."No.");
        if Recording.FindSet() then
            repeat
                Clear(RecordingRow);
                Clear(Lines);
                Line.SetRange("Order No.", Header."No.");
                Line.SetRange("Recording No.", Recording."Recording No.");
                if Line.FindSet() then
                    repeat
                        Clear(Row);
                        Row.Add('lineNo', Line."Line No.");
                        Row.Add('itemNo', Line."Item No.");
                        Row.Add('variantCode', Line."Variant Code");
                        Row.Add('locationCode', Line."Location Code");
                        Row.Add('binCode', Line."Bin Code");
                        Row.Add('quantity', Line.Quantity);
                        Row.Add('recorded', Line.Recorded);
                        Lines.Add(Row);
                    until Line.Next() = 0;
                RecordingRow.Add('recordingNo', Recording."Recording No.");
                RecordingRow.Add('lines', Lines);
                Recordings.Add(RecordingRow);
            until Recording.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('documentNo', Header."No.");
        Response.Add('systemId', Format(Header.SystemId, 0, 4));
        Response.Add('finished', Header.Status = Header.Status::Finished);
        Response.Add('lineCount', OrderLine.Count());
        Response.Add('recordings', Recordings);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; Maximum: Integer; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Value := '';
        if not Request.Get(Name, Token) then begin
            if Required then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, InvalidInputLbl, Name, InputNextStepLbl));
            exit(true);
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or (CopyStr(Serialized, 1, 1) <> '"') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidInputLbl, Name, InputNextStepLbl));
        Value := Token.AsValue().AsText();
        if (StrLen(Value) > Maximum) or (Required and (Value.Trim() = '')) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, Name, InputNextStepLbl));
        exit(true);
    end;

    local procedure ReadNumber(var Argument: Record "Message Argument ori"; Count: JsonObject; Name: Text; var Value: Decimal): Boolean
    var
        Token: JsonToken;
    begin
        if not Count.Get(Name, Token) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, InvalidInputLbl, 'counts.' + Name, InputNextStepLbl));
        if not Token.IsValue() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidInputLbl, 'counts.' + Name, InputNextStepLbl));
        if Token.AsValue().IsNull() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, InvalidInputLbl, 'counts.' + Name, InputNextStepLbl));
        if not Evaluate(Value, Token.AsValue().AsText(), 9) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidInputLbl, 'counts.' + Name, InputNextStepLbl));
        exit(true);
    end;

    local procedure ReadPositiveInteger(var Argument: Record "Message Argument ori"; Count: JsonObject; Name: Text; var Value: Integer): Boolean
    var
        Number: Decimal;
    begin
        if not ReadNumber(Argument, Count, Name, Number) then
            exit(false);
        if (Number < 1) or (Number > 2147483647) or (Round(Number, 1) <> Number) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, InvalidInputLbl, 'counts.' + Name, InputNextStepLbl));
        Value := Round(Number, 1);
        exit(true);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; Code: Enum "Bifrost Error Code ori"; Message: Text; Parameter: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(Code, Message, Parameter, '', '', NextStep);
        exit(false);
    end;
}
