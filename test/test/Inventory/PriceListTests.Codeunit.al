namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Pricing.PriceList;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 135: native sales/purchase prices, verified activation, guardrails and bilingual contracts.</summary>
codeunit 96987 "Price List Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        Inventory: Codeunit "Library - Inventory";

    [Test]
    procedure Scenario_AC01_SalesPriceAndDates_AreStoredNatively()
    var
        Item: Record Item;
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        Request: JsonObject;
        Response: JsonObject;
        LineJson: JsonObject;
        Lines: JsonArray;
        ListCode: Code[20];
    begin
        // Story #135 AC01 | Time: fixed validity dates, WorkDate ignored | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        LineJson := LineRequest(Item."No.", 10000, 25.5);
        LineJson.Add('unitOfMeasureCode', Item."Base Unit of Measure");
        LineJson.Add('minimumQuantity', 2);
        LineJson.Add('lineDiscountPercent', 7.5);
        LineJson.Add('startingDate', '2026-01-01');
        LineJson.Add('endingDate', '2026-12-31');
        Lines.Add(LineJson);
        Request := SetRequest(ListCode, 'Sales', Lines);
        Request.Add('description', 'Bifrost price-list test');
        Response := CallSet(Request);
        AssertSuccess(Response, "Message Type ori"::"Price.List.Set");
        Header.Get(ListCode);
        Line.Get(ListCode, 10000);
        Assert.AreEqual(Header.Status::Draft, Header.Status, 'Set leaves list Draft.');
        Assert.AreEqual('Bifrost price-list test', Header.Description, 'Native description.');
        Assert.AreEqual(Item."No.", Line."Asset No.", 'Native product.');
        Assert.AreEqual(Item."Base Unit of Measure", Line."Unit of Measure Code", 'Native unit.');
        Assert.AreEqual(2, Line."Minimum Quantity", 'Native quantity break.');
        Assert.AreEqual(25.5, Line."Unit Price", 'Native sales price.');
        Assert.AreEqual(7.5, Line."Line Discount %", 'Native line discount.');
        Assert.AreEqual(20260101D, Line."Starting Date", 'Native start date.');
        Assert.AreEqual(20261231D, Line."Ending Date", 'Native end date.');
    end;

    [Test]
    procedure Scenario_AC01_PurchasePrice_MapsToDirectUnitCost()
    var
        Item: Record Item;
        Line: Record "Price List Line";
        Lines: JsonArray;
        ListCode: Code[20];
    begin
        // Story #135 AC01 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 19.25));
        AssertSuccess(CallSet(SetRequest(ListCode, 'Purchase', Lines)), "Message Type ori"::"Price.List.Set");
        Line.Get(ListCode, 10000);
        Assert.AreEqual(Line."Price Type"::Purchase, Line."Price Type", 'Purchase list.');
        Assert.AreEqual(19.25, Line."Direct Unit Cost", 'Purchase uses Direct Unit Cost.');
    end;

    [Test]
    procedure Scenario_AC01_Upsert_PreservesOtherLinesAndOmittedPrice()
    var
        Item: Record Item;
        Line: Record "Price List Line";
        LineJson: JsonObject;
        Lines: JsonArray;
        ListCode: Code[20];
    begin
        // Story #135 AC01 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 20));
        Lines.Add(LineRequest(Item."No.", 20000, 30));
        AssertSuccess(CallSet(SetRequest(ListCode, 'Sales', Lines)), "Message Type ori"::"Price.List.Set");
        Clear(Lines);
        LineJson.Add('lineNo', 10000);
        LineJson.Add('productNo', Item."No.");
        LineJson.Add('lineDiscountPercent', 5);
        Lines.Add(LineJson);
        AssertSuccess(CallSet(SetRequest(ListCode, 'Sales', Lines)), "Message Type ori"::"Price.List.Set");
        Line.Get(ListCode, 10000);
        Assert.AreEqual(20, Line."Unit Price", 'Omitted price preserved.');
        Assert.AreEqual(5, Line."Line Discount %", 'Discount updated.');
        Line.Get(ListCode, 20000);
        Assert.AreEqual(30, Line."Unit Price", 'Omitted line preserved.');
    end;

    [Test]
    [HandlerFunctions('ConfirmActivation')]
    procedure Scenario_AC02_ValidSalesList_ActivatesHeaderAndLines()
    begin
        // Story #135 AC02 | Time: independent | Risk: None.
        VerifyActivation('Sales');
    end;

    [Test]
    [HandlerFunctions('ConfirmActivation')]
    procedure Scenario_AC02_ValidPurchaseList_ActivatesHeaderAndLines()
    begin
        // Story #135 AC02 | Time: independent | Risk: None.
        VerifyActivation('Purchase');
    end;

    [Test]
    procedure Scenario_AC02_DuplicateLines_RefusesAndNamesBothLines()
    var
        Item: Record Item;
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        Lines: JsonArray;
        Response: JsonObject;
        Token: JsonToken;
        ListCode: Code[20];
    begin
        // Story #135 AC02 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 20));
        Lines.Add(LineRequest(Item."No.", 20000, 30));
        AssertSuccess(CallSet(SetRequest(ListCode, 'Sales', Lines)), "Message Type ori"::"Price.List.Set");
        Response := CallActivate(ListCode);
        AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Response.Get('conflicts', Token), 'Conflict lines returned.');
        Assert.AreEqual(2, Token.AsArray().Count(), 'Both conflicting lines named.');
        Header.Get(ListCode);
        Line.Get(ListCode, 10000);
        Assert.AreEqual(Header.Status::Draft, Header.Status, 'Refusal leaves header Draft.');
        Assert.AreEqual(Line.Status::Draft, Line.Status, 'Refusal leaves lines Draft.');
    end;

    [Test]
    [HandlerFunctions('ConfirmActivation')]
    procedure Scenario_AC02_ConflictWithActiveList_NamesForeignList()
    var
        Item: Record Item;
        Lines: JsonArray;
        FirstCode: Code[20];
        SecondCode: Code[20];
        Response: JsonObject;
        Token: JsonToken;
        Conflict: JsonToken;
        FoundFirst: Boolean;
    begin
        // Story #135 AC02 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        FirstCode := NewCode();
        SecondCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 20));
        AssertSuccess(CallSet(SetRequest(FirstCode, 'Sales', Lines)), "Message Type ori"::"Price.List.Set");
        AssertSuccess(CallActivate(FirstCode), "Message Type ori"::"Price.List.Activate");
        AssertSuccess(CallSet(SetRequest(SecondCode, 'Sales', Lines)), "Message Type ori"::"Price.List.Set");
        Response := CallActivate(SecondCode);
        AssertRefusal(Response, 'PreconditionFailed');
        Response.Get('conflicts', Token);
        foreach Conflict in Token.AsArray() do begin
            Conflict.AsObject().Get('code', Token);
            FoundFirst := FoundFirst or (Token.AsValue().AsText() = FirstCode);
        end;
        Assert.IsTrue(FoundFirst, 'Response names the foreign active price list.');
    end;

    [Test]
    [HandlerFunctions('ConfirmActivation')]
    procedure Scenario_AC02_ActiveList_RefusesSetAndRepeatedActivation()
    var
        Item: Record Item;
        Lines: JsonArray;
        Request: JsonObject;
        ListCode: Code[20];
    begin
        // Story #135 AC02 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 20));
        Request := SetRequest(ListCode, 'Sales', Lines);
        AssertSuccess(CallSet(Request), "Message Type ori"::"Price.List.Set");
        AssertSuccess(CallActivate(ListCode), "Message Type ori"::"Price.List.Activate");
        AssertRefusal(CallSet(Request), 'PreconditionFailed');
        AssertRefusal(CallActivate(ListCode), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC02_MissingOrEmptyList_RefusesWithNextStep()
    var
        Header: Record "Price List Header";
    begin
        // Story #135 AC02 | Time: independent | Risk: None.
        Initialize();
        AssertRefusal(CallActivate(NewCode()), 'RecordNotFound');
        Header.Init();
        Header.Code := NewCode();
        Header.Insert(false);
        AssertRefusal(CallActivate(Header.Code), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC03_GenericWritesBlocked_ReadsRemainAllowed()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // Story #135 AC03 | Time: independent | Risk: None.
        Initialize();
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Price List Header", false), 'Header write restricted.');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Price List Line", false), 'Line write restricted.');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Price List Header", true), 'Force cannot reopen the header.');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Price List Line", true), 'Force cannot reopen the lines.');
        Assert.AreEqual('Price.List.Set / Price.List.Activate', TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Price List Line"), 'Dedicated maintenance hint.');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Price List Header"), 'Header reads allowed.');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Price List Line"), 'Line reads allowed.');
    end;

    [Test]
    procedure Scenario_AC04_MalformedAndUnknownKeys_RefuseWithoutWrites()
    var
        Item: Record Item;
        Header: Record "Price List Header";
        Lines: JsonArray;
        Request: JsonObject;
        ListCode: Code[20];
    begin
        // Story #135 AC04 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 20));
        Request := SetRequest(ListCode, 'Sales', Lines);
        Request.Add('deleteLines', true);
        AssertRefusal(CallSet(Request), 'UnknownParameter');
        Assert.IsFalse(Header.Get(ListCode), 'Unknown key changes nothing.');
        Request.Remove('deleteLines');
        Request.Replace('code', true);
        AssertRefusal(CallSet(Request), 'InvalidParameter');
        Request.Replace('code', '123456789012345678901');
        AssertRefusal(CallSet(Request), 'InvalidParameter');
        Request.Replace('code', ListCode);
        Request.Replace('lines', 'not an array');
        AssertRefusal(CallSet(Request), 'InvalidParameter');
        Assert.IsFalse(Header.Get(ListCode), 'Malformed scalar changes nothing.');
    end;

    [Test]
    procedure Scenario_AC04_DuplicateLineNumbersAndInvalidNumbers_Refuse()
    var
        Item: Record Item;
        Lines: JsonArray;
        Line: JsonObject;
        Request: JsonObject;
        ListCode: Code[20];
    begin
        // Story #135 AC04 | Time: independent | Risk: None.
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 20));
        Lines.Add(LineRequest(Item."No.", 10000, 30));
        AssertRefusal(CallSet(SetRequest(ListCode, 'Sales', Lines)), 'InvalidParameter');
        Clear(Lines);
        Line := LineRequest(Item."No.", 10000, 20);
        Line.Replace('unitPrice', '20');
        Lines.Add(Line);
        AssertRefusal(CallSet(SetRequest(ListCode, 'Sales', Lines)), 'InvalidParameter');
        Clear(Lines);
        Line.Replace('unitPrice', -1);
        Lines.Add(Line);
        AssertRefusal(CallSet(SetRequest(ListCode, 'Sales', Lines)), 'InvalidParameter');
        Clear(Lines);
        Line.Replace('unitPrice', 0);
        Line.Add('lineDiscountPercent', 101);
        Lines.Add(Line);
        Request := SetRequest(ListCode, 'Sales', Lines);
        AssertRefusal(CallSet(Request), 'InvalidParameter');
    end;

    [Test]
    procedure Scenario_AC04_EnglishAndIcelandic_HelpAndErrorsLocalize()
    var
        SetImpl: Codeunit "Price List Set Impl ori";
        ActivateImpl: Codeunit "Price List Activate Impl ori";
        EnglishDescription: Text;
        EnglishNotes: Text;
        IcelandicNotes: Text;
        SavedLanguage: Integer;
        ResponseEn: JsonObject;
        ResponseIs: JsonObject;
        MissingCode: Code[20];
    begin
        // Story #135 AC04 | Time: independent | Risk: GlobalLanguage restored before assertions.
        Initialize();
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        EnglishDescription := SetImpl.GetDescription();
        ActivateImpl.GetNotes(EnglishNotes);
        MissingCode := NewCode();
        ResponseEn := CallActivateInLanguage(MissingCode, 1033);
        GlobalLanguage(1039);
        ActivateImpl.GetNotes(IcelandicNotes);
        ResponseIs := CallActivateInLanguage(MissingCode, 1039);
        GlobalLanguage(SavedLanguage);
        Assert.AreNotEqual(EnglishDescription, LocalizedSetDescription(1039), 'Set discovery translated.');
        Assert.AreNotEqual(EnglishNotes, IcelandicNotes, 'Activation guidance translated.');
        AssertRefusal(ResponseEn, 'RecordNotFound');
        AssertRefusal(ResponseIs, 'RecordNotFound');
        Assert.AreNotEqual(TextField(ResponseEn, 'error'), TextField(ResponseIs, 'error'), 'Refusal translated.');
        Assert.AreNotEqual(TextField(ResponseEn, 'nextStep'), TextField(ResponseIs, 'nextStep'), 'Recovery translated.');
    end;

    [Test]
    procedure Scenario_AC05_Contracts_DeclareThreePartNamesAndWriteEffect()
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        SetType: Enum "Message Type ori";
        Help: JsonObject;
        Token: JsonToken;
        Effect: JsonToken;
        Name: Text;
        Names: List of [Text];
        MessageNames: List of [Text];
    begin
        // Story #135 AC05 | Time: independent | Risk: None.
        Initialize();
        MessageNames.Add('Price.List.Set');
        MessageNames.Add('Price.List.Activate');
        foreach Name in MessageNames do begin
            Names := Name.Split('.');
            Assert.AreEqual(3, Names.Count(), 'Exactly three name segments.');
            if Name = 'Price.List.Set' then
                SetType := SetType::"Price.List.Set"
            else
                SetType := SetType::"Price.List.Activate";
            Contract.GetContract(SetType, Help);
            Help.Get('effect', Effect);
            Effect.AsObject().Get('effect', Token);
            Assert.AreEqual('write', Token.AsValue().AsText(), 'Real native maintenance effect.');
        end;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure Scenario_AC04_LaterNativeFailure_RollsBackHeaderAndEarlierLine()
    var
        Item: Record Item;
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        Setup: Record "Inventory Setup ori";
        Lines: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        ListCode: Code[20];
        HeaderRemains: Boolean;
        LineRemains: Boolean;
        OriginalDomain: Boolean;
    begin
        // Story #135 AC04 | Time: independent | Risk: explicit commits; owned fixture removed before assertions.
        Setup.InsertIfNotExists();
        OriginalDomain := Setup."Item Price";
        Initialize();
        Item.Init();
        Item."No." := NewCode();
        Item.Description := 'Price-list rollback fixture';
        Item.Insert(true);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 10));
        Lines.Add(LineRequest(NewCode(), 20000, 20));
        Request := SetRequest(ListCode, 'Sales', Lines);
        Commit();
        Response := Library.ExecuteType("Message Type ori"::"Price.List.Set", '', Request, false);
        HeaderRemains := Header.Get(ListCode);
        Line.SetRange("Price List Code", ListCode);
        LineRemains := not Line.IsEmpty();
        // Cleanup precedes assertions, including the unexpected-success case.
        Line.DeleteAll(true);
        if HeaderRemains then
            Header.Delete(true);
        Item.Delete(true);
        Setup.Get('');
        Setup."Item Price" := OriginalDomain;
        Setup.Modify(true);
        Commit();
        AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsFalse(HeaderRemains, 'Failed native second line rolls back the new header.');
        Assert.IsFalse(LineRemains, 'Failed native second line rolls back the valid first line.');
    end;

    local procedure VerifyActivation(PriceType: Text)
    var
        Item: Record Item;
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        Lines: JsonArray;
        ListCode: Code[20];
    begin
        Initialize();
        Inventory.CreateItem(Item);
        ListCode := NewCode();
        Lines.Add(LineRequest(Item."No.", 10000, 0));
        AssertSuccess(CallSet(SetRequest(ListCode, PriceType, Lines)), "Message Type ori"::"Price.List.Set");
        AssertSuccess(CallActivate(ListCode), "Message Type ori"::"Price.List.Activate");
        Header.Get(ListCode);
        Line.Get(ListCode, 10000);
        Assert.AreEqual(Header.Status::Active, Header.Status, 'Header activated natively.');
        Assert.AreEqual(Line.Status::Active, Line.Status, 'Line activated natively.');
    end;

    /// <summary>Accepts native status-change confirmation only in activation tests.</summary>
    [ConfirmHandler]
    procedure ConfirmActivation(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    local procedure Initialize()
    begin
        Library.Initialize();
        Library.EnableItemPrice();
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr('PL' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
    end;

    local procedure LineRequest(ProductNo: Code[20]; LineNo: Integer; Price: Decimal) Request: JsonObject
    begin
        Request.Add('lineNo', LineNo);
        Request.Add('productNo', ProductNo);
        Request.Add('unitPrice', Price);
    end;

    local procedure SetRequest(ListCode: Code[20]; PriceType: Text; Lines: JsonArray) Request: JsonObject
    begin
        Request.Add('code', ListCode);
        Request.Add('priceType', PriceType);
        Request.Add('lines', Lines);
    end;

    local procedure CallSet(Request: JsonObject): JsonObject
    begin
        exit(Library.ExecuteType("Message Type ori"::"Price.List.Set", '', Request, true));
    end;

    local procedure CallActivate(ListCode: Code[20]): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('code', ListCode);
        exit(Library.ExecuteType("Message Type ori"::"Price.List.Activate", '', Request, true));
    end;

    local procedure CallActivateInLanguage(ListCode: Code[20]; LanguageId: Integer) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        ResponseBlob: Codeunit "Temp Blob";
        RequestContent: BigText;
        ResponseContent: BigText;
        Request: JsonObject;
        ResponseStream: InStream;
        RequestText: Text;
        ResponseText: Text;
        EmptyTaskId: Guid;
        MessageId: Guid;
        ResponseType: Text[100];
        ResponseTime: Duration;
    begin
        Request.Add('code', ListCode);
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Price.List.Activate", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, EmptyTaskId, LanguageId, MessageId, ResponseBlob, ResponseType, ResponseTime, true);
        ResponseBlob.CreateInStream(ResponseStream, TextEncoding::UTF8);
        ResponseContent.Read(ResponseStream);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure AssertSuccess(Response: JsonObject; MessageType: Enum "Message Type ori")
    begin
        Assert.AreEqual('Success', TextField(Response, 'status'), 'Native operation succeeds.');
        Library.AssertResponseContract(MessageType, Response);
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', TextField(Response, 'status'), 'Expected coded refusal.');
        Assert.AreEqual(ExpectedCode, TextField(Response, 'code'), 'Expected Bifrost error code.');
        Assert.AreNotEqual('', TextField(Response, 'nextStep'), 'Every refusal has recovery guidance.');
    end;

    local procedure TextField(Response: JsonObject; ParameterName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(ParameterName, Token), 'Response must include ' + ParameterName);
        exit(Token.AsValue().AsText());
    end;

    local procedure LocalizedSetDescription(LanguageId: Integer) Description: Text
    var
        Impl: Codeunit "Price List Set Impl ori";
        SavedLanguage: Integer;
    begin
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Description := Impl.GetDescription();
        GlobalLanguage(SavedLanguage);
    end;
}
