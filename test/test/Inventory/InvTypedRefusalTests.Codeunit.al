namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Setup;
using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue151 typed input and localized refusal regressions; invalid requests cannot reach writes or reports.</summary>
codeunit 96975 "Inv. Typed Refusal Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    /// <summary>Missing cancellation selectors return actionable English context without changing reservations.</summary>
    [Test]
    procedure ReservationCancel_NotFound_EN()
    begin
        CheckCancelNotFound(1033);
    end;

    /// <summary>Missing cancellation selectors return actionable Icelandic context without changing reservations.</summary>
    [Test]
    procedure ReservationCancel_NotFound_IS()
    begin
        CheckCancelNotFound(1039);
    end;

    local procedure CheckCancelNotFound(LanguageId: Integer)
    var
        ReservationEntry: Record "Reservation Entry";
        Helper: Codeunit "Transfer Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
        EntryNo: Integer;
        BeforeCount: Integer;
        OldLanguage: Integer;
    begin
        EnableDomains();
        BeforeCount := ReservationEntry.Count();
        EntryNo := 2147483000;
        ReservationEntry.SetRange("Entry No.", EntryNo);
        while not ReservationEntry.IsEmpty() do begin
            EntryNo -= 1;
            ReservationEntry.SetRange("Entry No.", EntryNo);
        end;
        Request.Add('entryNo', EntryNo);
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", Request, Response);
        GlobalLanguage(OldLanguage);

        AssertRefusal(Response, 'RecordNotFound', 'entryNo');
        Assert.AreEqual(Format(EntryNo, 0, 9), TextValue(Response, 'received'), 'Preserve the absent selector as an invariant integer.');
        if LanguageId = 1039 then begin
            Assert.AreEqual('númer frátekningarfærslu sem er til', TextValue(Response, 'expected'), 'Icelandic expected selector.');
            Assert.AreEqual('Lestu núverandi frátekningar með Inventory.Reservation.Get og reyndu aftur með entryNo færslu sem er til.', TextValue(Response, 'nextStep'), 'Icelandic recovery identifies the reservation read operation.');
        end else begin
            Assert.AreEqual('an existing reservation entry number', TextValue(Response, 'expected'), 'English expected selector.');
            Assert.AreEqual('Read current reservations with Inventory.Reservation.Get and retry with an existing entryNo.', TextValue(Response, 'nextStep'), 'English recovery identifies the reservation read operation.');
        end;
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'The missing selector remains absent.');
        ReservationEntry.Reset();
        Assert.AreEqual(BeforeCount, ReservationEntry.Count(), 'Refusing an absent selector does not create or cancel reservations.');
    end;

    [Test]
    procedure PeriodClose_InvalidDates_EN()
    begin
        CheckPeriodFormats(1033, "Message Type ori"::"Inventory.Period.Close");
    end;

    [Test]
    procedure PeriodClose_InvalidDates_IS()
    begin
        CheckPeriodFormats(1039, "Message Type ori"::"Inventory.Period.Close");
    end;

    [Test]
    procedure PeriodReopen_InvalidDates_EN()
    begin
        CheckPeriodFormats(1033, "Message Type ori"::"Inventory.Period.Reopen");
    end;

    [Test]
    procedure PeriodReopen_InvalidDates_IS()
    begin
        CheckPeriodFormats(1039, "Message Type ori"::"Inventory.Period.Reopen");
    end;

    [Test]
    procedure AdjustCost_InvalidBoolean_EN()
    begin
        CheckBoolean(1033);
    end;

    [Test]
    procedure AdjustCost_InvalidBoolean_IS()
    begin
        CheckBoolean(1039);
    end;

    [Test]
    procedure AdjustCost_CollectsAllInvalidValues_EN()
    begin
        CheckAdjustmentCollection(1033);
    end;

    [Test]
    procedure AdjustCost_CollectsAllInvalidValues_IS()
    begin
        CheckAdjustmentCollection(1039);
    end;

    [Test]
    procedure PeriodReopen_UsesIsoNotFoundDate_EN()
    begin
        CheckPeriodNotFound(1033);
    end;

    [Test]
    procedure PeriodReopen_UsesIsoNotFoundDate_IS()
    begin
        CheckPeriodNotFound(1039);
    end;

    [Test]
    procedure AssemblyCreate_CollectsBeforeInsert_EN()
    begin
        CheckCreateCollection(1033, false);
    end;

    [Test]
    procedure AssemblyCreate_CollectsBeforeInsert_IS()
    begin
        CheckCreateCollection(1039, false);
    end;

    [Test]
    procedure TransferCreate_CollectsBeforeInsert_EN()
    begin
        CheckCreateCollection(1033, true);
    end;

    [Test]
    procedure TransferCreate_CollectsBeforeInsert_IS()
    begin
        CheckCreateCollection(1039, true);
    end;

    local procedure CheckCreateCollection(LanguageId: Integer; Transfer: Boolean)
    var
        AssemblyHeader: Record "Assembly Header";
        TransferHeader: Record "Transfer Header";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Errors: JsonArray;
        OldLanguage: Integer;
        BeforeCount: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        if Transfer then begin
            BeforeCount := TransferHeader.Count();
            Request.ReadFrom('{"transferFromCode":"W8-NO-FROM","transferToCode":"W8-NO-TO","inTransitCode":"W8-NO-VIA","postingDate":"bad-date","receiptDate":true}');
            Response := Library.ExecuteType("Message Type ori"::"Inventory.TransferOrder.Create", '', Request, true);
            Assert.AreEqual(BeforeCount, TransferHeader.Count(), 'Invalid headers are not inserted.');
        end else begin
            BeforeCount := AssemblyHeader.Count();
            Request.ReadFrom('{"itemNo":"W8-NO-ITEM","locationCode":"W8-NO-LOC","quantity":-1,"postingDate":"bad-date"}');
            Response := Library.ExecuteType("Message Type ori"::"Inventory.AssemblyOrder.Create", '', Request, true);
            Assert.AreEqual(BeforeCount, AssemblyHeader.Count(), 'Invalid headers are not inserted.');
        end;
        Assert.AreEqual('MultipleErrors', TextValue(Response, 'code'), 'Collect format, range and lookup validation together before writes.');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected errors returned.');
        Errors := Token.AsArray();
        if Transfer then
            Assert.AreEqual(5, Errors.Count(), 'Both bad dates and all three missing locations are reported.')
        else
            Assert.AreEqual(4, Errors.Count(), 'Bad quantity/date and missing item/location are all reported.');
        foreach Token in Errors do
            AssertRefusalFields(Token.AsObject());
        GlobalLanguage(OldLanguage);
    end;

    [Test]
    procedure AttributeDefinitionEmpty_Collects_EN()
    begin
        CheckEmptyCollection(1033, "Message Type ori"::"Inventory.AttributeDefinition.Create", 2);
    end;

    [Test]
    procedure AttributeDefinitionEmpty_Collects_IS()
    begin
        CheckEmptyCollection(1039, "Message Type ori"::"Inventory.AttributeDefinition.Create", 2);
    end;

    [Test]
    procedure ReservationEmpty_Collects_EN()
    begin
        CheckEmptyCollection(1033, "Message Type ori"::"Inventory.Reservation.Create", 4);
    end;

    [Test]
    procedure ReservationEmpty_Collects_IS()
    begin
        CheckEmptyCollection(1039, "Message Type ori"::"Inventory.Reservation.Create", 4);
    end;

    [Test]
    procedure CostEmpty_Collects_EN()
    begin
        CheckEmptyCollection(1033, "Message Type ori"::"Inventory.Cost.Update", 2);
    end;

    [Test]
    procedure CostEmpty_Collects_IS()
    begin
        CheckEmptyCollection(1039, "Message Type ori"::"Inventory.Cost.Update", 2);
    end;

    [Test]
    procedure AttributeDuplicate_CodedAndUnchanged_EN()
    begin
        CheckDuplicateAttribute(1033);
    end;

    [Test]
    procedure CostUnknownItemAndValues_Collects_EN()
    begin
        CheckCostUnknown(1033);
    end;

    [Test]
    procedure AssemblyUndoMissing_Coded_EN()
    begin
        CheckMissingUndo(1033);
    end;

    [Test]
    procedure ReservationGet_UsesInvariantStatus_EN()
    begin
        CheckReservationName(1033);
    end;

    [Test]
    procedure AttributeDuplicate_CodedAndUnchanged_IS()
    begin
        CheckDuplicateAttribute(1039);
    end;

    [Test]
    procedure CostUnknownItemAndValues_Collects_IS()
    begin
        CheckCostUnknown(1039);
    end;

    [Test]
    procedure AssemblyUndoMissing_Coded_IS()
    begin
        CheckMissingUndo(1039);
    end;

    [Test]
    procedure ReservationGet_UsesInvariantStatus_IS()
    begin
        CheckReservationName(1039);
    end;

    local procedure CheckEmptyCollection(LanguageId: Integer; MessageType: Enum "Message Type ori"; ExpectedCount: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Errors: JsonArray;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType(MessageType, '', Request, false);
        Assert.AreEqual('MultipleErrors', TextValue(Response, 'code'), 'Missing independent values are collected.');
        Assert.IsTrue(Response.Get('errors', Token), 'All missing inputs are returned.');
        Errors := Token.AsArray();
        Assert.AreEqual(ExpectedCount, Errors.Count(), 'All independently required inputs are reported.');
        foreach Token in Errors do
            AssertRefusalFields(Token.AsObject());
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckDuplicateAttribute(LanguageId: Integer)
    var
        Attribute: Record "Item Attribute";
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
        BeforeCount: Integer;
    begin
        EnableDomains();
        Attribute.Init();
        Attribute.Name := CopyStr('W8-' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Attribute.Name));
        Attribute.Type := Attribute.Type::Text;
        Attribute.Insert(true);
        BeforeCount := Attribute.Count();
        Request.Add('name', Attribute.Name);
        Request.Add('type', 'Text');
        Commit();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.AttributeDefinition.Create", '', Request, false);
        AssertRefusal(Response, 'PreconditionFailed', 'name');
        Assert.AreEqual(BeforeCount, Attribute.Count(), 'Duplicate definition is never inserted.');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckCostUnknown(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Errors: JsonArray;
        OldLanguage: Integer;
    begin
        EnableDomains();
        Request.ReadFrom('{"itemNo":"W8-MISSING-COST","unitCost":"bad-cost","lastDirectCost":{}}');
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Cost.Update", '', Request, false);
        Assert.AreEqual('MultipleErrors', TextValue(Response, 'code'), 'Unknown item cannot hide invalid cost values.');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected cost errors returned.');
        Errors := Token.AsArray();
        Assert.AreEqual(3, Errors.Count(), 'Unknown item plus both invalid cost values.');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckMissingUndo(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Assembly.UndoPost", '', Request, false);
        AssertRefusal(Response, 'MissingParameter', 'documentNo');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckReservationName(LanguageId: Integer)
    var
        Item: Record Item;
        Entry: Record "Reservation Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Entries: JsonArray;
        OldLanguage: Integer;
        EntryNo: Integer;
    begin
        EnableDomains();
        LibraryInventory.CreateItem(Item);
        if Entry.FindLast() then
            EntryNo := Entry."Entry No.";
        Entry.Init();
        Entry."Entry No." := EntryNo + 1;
        Entry.Positive := true;
        Entry."Item No." := Item."No.";
        Entry."Reservation Status" := Entry."Reservation Status"::Reservation;
        Entry.Quantity := 1;
        Entry.Insert(false);
        Request.Add('itemNo', Item."No.");
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Reservation.Get", '', Request, true);
        Assert.AreEqual('Success', TextValue(Response, 'status'), 'Owned reservation projection succeeds.');
        Response.Get('entries', Token);
        Entries := Token.AsArray();
        Assert.AreEqual(1, Entries.Count(), 'Only the own seeded entry is projected.');
        Entries.Get(0, Token);
        Assert.AreEqual('Reservation', TextValue(Token.AsObject(), 'reservationStatus'), 'Option names are language-invariant.');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckPeriodFormats(LanguageId: Integer; MessageType: Enum "Message Type ori")
    var
        Period: Record "Inventory Period";
        Request: JsonObject;
        Response: JsonObject;
        BadValues: JsonArray;
        Token: JsonToken;
        BeforeCount: Integer;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        BeforeCount := Period.Count();
        BadValues.ReadFrom('["31.12.2026",true,42,{},[],"2026-02-30"]');
        foreach Token in BadValues do begin
            Clear(Request);
            Request.Add('endingDate', Token);
            Response := Library.ExecuteType(MessageType, '', Request, true);
            AssertRefusal(Response, 'InvalidParameterFormat', 'endingDate');
        end;
        Assert.AreEqual(BeforeCount, Period.Count(), 'Invalid dates do not create or remove periods.');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckBoolean(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        BadValues: JsonArray;
        Token: JsonToken;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        BadValues.ReadFrom('["maybe","true",1,{},[]]');
        foreach Token in BadValues do begin
            Clear(Request);
            Request.Add('postToGL', Token);
            Response := Library.ExecuteType("Message Type ori"::"Inventory.AdjustCost.Run", '', Request, true);
            AssertRefusal(Response, 'InvalidParameterFormat', 'postToGL');
        end;
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckAdjustmentCollection(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Errors: JsonArray;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.ReadFrom('{"itemNoFilter":{},"itemCategoryFilter":[],"postToGL":"maybe"}');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.AdjustCost.Run", '', Request, true);
        Assert.AreEqual('MultipleErrors', TextValue(Response, 'code'), 'All invalid request values are collected.');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected errors are present.');
        Errors := Token.AsArray();
        Assert.AreEqual(3, Errors.Count(), 'Every independent bad value is returned before the report can run.');
        foreach Token in Errors do
            AssertRefusalFields(Token.AsObject());
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckPeriodNotFound(LanguageId: Integer)
    var
        Period: Record "Inventory Period";
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
    begin
        EnableDomains();
        Assert.IsFalse(Period.Get(20990131D), 'Owned missing date must actually be absent.');
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('endingDate', '2099-01-31');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Period.Reopen", '', Request, true);
        AssertRefusal(Response, 'RecordNotFound', 'endingDate');
        Assert.AreEqual('2099-01-31', TextValue(Response, 'received'), 'Dates use an invariant ISO representation.');
        Assert.IsTrue(TextValue(Response, 'error').Contains('2099-01-31'), 'Localized message preserves ISO date.');
        GlobalLanguage(OldLanguage);
    end;

    [Test]
    procedure Calculate_UnknownParameterCoded_EN()
    begin
        CheckJournalUnknown(1033, "Message Type ori"::"Inventory.PhysInventory.Calculate");
    end;

    [Test]
    procedure RecordCount_UnknownParameterCoded_EN()
    begin
        CheckJournalUnknown(1033, "Message Type ori"::"Inventory.PhysInventory.RecordCount");
    end;

    [Test]
    procedure Check_UnknownParameterCoded_EN()
    begin
        CheckJournalUnknown(1033, "Message Type ori"::"Inventory.PhysInventory.Check");
    end;

    [Test]
    procedure PhysicalPost_UnknownParameterCoded_EN()
    begin
        CheckJournalUnknown(1033, "Message Type ori"::"Inventory.PhysInventory.Post");
    end;

    [Test]
    procedure RevaluationPost_UnknownParameterCoded_EN()
    begin
        CheckJournalUnknown(1033, "Message Type ori"::"Inventory.Revaluation.Post");
    end;

    [Test]
    procedure RevaluationPreview_UnknownParameterCoded_EN()
    begin
        CheckJournalUnknown(1033, "Message Type ori"::"Inventory.Revaluation.PreviewPost");
    end;

    [Test]
    procedure TrackingMalformedSource_Coded_EN()
    begin
        CheckTrackingSource(1033);
    end;

    [Test]
    procedure Calculate_UnknownParameterCoded_IS()
    begin
        CheckJournalUnknown(1039, "Message Type ori"::"Inventory.PhysInventory.Calculate");
    end;

    [Test]
    procedure RecordCount_UnknownParameterCoded_IS()
    begin
        CheckJournalUnknown(1039, "Message Type ori"::"Inventory.PhysInventory.RecordCount");
    end;

    [Test]
    procedure Check_UnknownParameterCoded_IS()
    begin
        CheckJournalUnknown(1039, "Message Type ori"::"Inventory.PhysInventory.Check");
    end;

    [Test]
    procedure PhysicalPost_UnknownParameterCoded_IS()
    begin
        CheckJournalUnknown(1039, "Message Type ori"::"Inventory.PhysInventory.Post");
    end;

    [Test]
    procedure RevaluationPost_UnknownParameterCoded_IS()
    begin
        CheckJournalUnknown(1039, "Message Type ori"::"Inventory.Revaluation.Post");
    end;

    [Test]
    procedure RevaluationPreview_UnknownParameterCoded_IS()
    begin
        CheckJournalUnknown(1039, "Message Type ori"::"Inventory.Revaluation.PreviewPost");
    end;

    [Test]
    procedure TrackingMalformedSource_Coded_IS()
    begin
        CheckTrackingSource(1039);
    end;

    local procedure CheckJournalUnknown(LanguageId: Integer; MessageType: Enum "Message Type ori")
    var
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
    begin
        EnableDomains();
        Request.Add('unknownJournalKey', true);
        Commit();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType(MessageType, '', Request, false);
        AssertRefusal(Response, 'InvalidParameter', 'unknownJournalKey');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckTrackingSource(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
    begin
        EnableDomains();
        Request.Add('source', true);
        Commit();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Tracking.Assign", '', Request, false);
        AssertRefusal(Response, 'InvalidParameterFormat', 'source');
        Assert.AreEqual('true', TextValue(Response, 'received'), 'The malformed source value is preserved.');
        GlobalLanguage(OldLanguage);
    end;

    [Test]
    procedure NativeJournalFailure_Context_EN()
    begin
        CheckNativeJournalContext(1033);
    end;

    [Test]
    procedure NativeJournalFailure_Context_IS()
    begin
        CheckNativeJournalContext(1039);
    end;

    local procedure CheckNativeJournalContext(LanguageId: Integer)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Entries: Record "Item Ledger Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        Types: List of [Enum "Message Type ori"];
        MessageType: Enum "Message Type ori";
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
        BeforeCount: Integer;
    begin
        EnableDomains();
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalTemplate.Type::Item);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        BeforeCount := Entries.Count();
        Commit();
        Types.Add("Message Type ori"::"Inventory.PhysInventory.Check");
        Types.Add("Message Type ori"::"Inventory.PhysInventory.Post");
        Types.Add("Message Type ori"::"Inventory.Revaluation.Post");
        Types.Add("Message Type ori"::"Inventory.Revaluation.PreviewPost");
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        foreach MessageType in Types do begin
            Response := Library.ExecuteType(MessageType, Batch."Journal Template Name" + '|' + Batch.Name, Request, false);
            AssertRefusal(Response, 'BusinessCentralError', 'journalBatch');
            Assert.AreEqual(Batch."Journal Template Name" + '|' + Batch.Name, TextValue(Response, 'received'), 'Actual selected batch context.');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'Native refusal posts nothing.');
        end;
        GlobalLanguage(OldLanguage);
    end;

    local procedure EnableDomains()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup."Inventory Period" := true;
        Setup.Costing := true;
        Setup.Assembly := true;
        Setup.Attributes := true;
        Setup."Phys. Inventory" := true;
        Setup."Item Tracking" := true;
        Setup.Reservations := true;
        Setup."Transfer Orders" := true;
        Setup.Modify();
    end;

    local procedure AssertRefusal(Response: JsonObject; Code: Text; Parameter: Text)
    begin
        Assert.AreEqual('Error', TextValue(Response, 'status'), 'Structured error status.');
        Assert.AreEqual(Code, TextValue(Response, 'code'), 'Stable shared error code.');
        Assert.AreEqual(Parameter, TextValue(Response, 'parameter'), 'Failing request value is named.');
        AssertRefusalFields(Response);
    end;

    local procedure AssertRefusalFields(Response: JsonObject)
    begin
        Assert.IsTrue(TextValue(Response, 'received') <> '', 'Received value is present.');
        Assert.IsTrue(TextValue(Response, 'expected') <> '', 'Expected value is present.');
        Assert.IsTrue(TextValue(Response, 'nextStep') <> '', 'Caller gets an actionable next step.');
        Assert.IsFalse(TextValue(Response, 'error').Contains('NavJsonValue'), 'No raw runtime conversion text.');
    end;

    local procedure TextValue(Value: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Value.Get(Name, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;
}
