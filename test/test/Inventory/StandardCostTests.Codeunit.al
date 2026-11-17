namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Setup;
using Microsoft.Manufacturing.StandardCost;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 121: native worksheet suggestions, unposted implementation, typed refusals and bilingual contracts.</summary>
codeunit 96982 "Standard Cost Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        Library: Codeunit "Inventory Test Library ori";

    [Test]
    procedure Scenario_AC01_Factor_SuggestsWithoutChangingItem()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Worksheet: Record "Standard Cost Worksheet";
        Name: Code[10];
        Response: JsonObject;
        Row: JsonObject;
    begin
        // Story 121, AC01 | Time: none | Risk: native suggestion report.
        Initialize();
        // [GIVEN] Two owned Standard-cost items and an empty worksheet.
        CreateItem(Item);
        CreateItem(OtherItem);
        Name := CreateWorksheet();
        // [WHEN] Only the first item is suggested.
        Response := Suggest(Name, Item."No.", 1.25);
        // [THEN] The native worksheet contains the adjusted cost and the card stays unchanged.
        AssertSuccess(Response);
        Assert.AreEqual(1, IntegerValue(Response, 'lineCount'), 'Only one selected line.');
        Row := FirstLine(Response);
        Assert.AreEqual(15, DecimalValue(Row, 'newStandardCost'), '12 multiplied by 1.25.');
        Worksheet.Get(Name, Worksheet.Type::Item, Item."No.");
        Assert.AreEqual(15, Worksheet."New Standard Cost", 'Native worksheet value.');
        Assert.IsFalse(Worksheet.Get(Name, Worksheet.Type::Item, OtherItem."No."), 'Other item was not selected.');
        Item.Get(Item."No.");
        Assert.AreEqual(12, Item."Standard Cost", 'Suggestion never updates card cost.');
    end;

    [Test]
    procedure Scenario_AC01_RepeatedSuggestion_DoesNotCompoundFactor()
    var
        Item: Record Item;
        Name: Code[10];
        Response: JsonObject;
    begin
        // Story 121, AC01 | Time: none | Risk: native report refreshes existing lines.
        Initialize();
        CreateItem(Item);
        Name := CreateWorksheet();
        AssertSuccess(Suggest(Name, Item."No.", 1.25));
        Response := Suggest(Name, Item."No.", 1.25);
        AssertSuccess(Response);
        Assert.AreEqual(15, DecimalValue(FirstLine(Response), 'newStandardCost'), 'Factor is applied to card cost, not the prior suggestion.');
    end;

    [Test]
    procedure Scenario_AC02_AC03_Stock_CreatesJournalWithoutPosting()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Worksheet: Record "Standard Cost Worksheet";
        Line: Record "Item Journal Line";
        ValueEntry: Record "Value Entry";
        Ledger: Record "Item Ledger Entry";
        Name: Code[10];
        Request: JsonObject;
        Response: JsonObject;
        ValuesBefore: Integer;
        LedgersBefore: Integer;
    begin
        // Story 121, AC02/AC03 | Time: first open date on or after WorkDate is the revaluation date | Risk: native report.
        Initialize();
        // [GIVEN] Two units with cost 12, a proposed cost 15 and an empty revaluation batch.
        CreateItem(Item);
        CreateStock(Item);
        Name := CreateWorksheet();
        AssertSuccess(Suggest(Name, Item."No.", 1.25));
        CreateBatch(Batch);
        ValuesBefore := ValueEntry.Count();
        LedgersBefore := Ledger.Count();
        Request := ImplementRequest(Name, Batch);
        // [WHEN] The worksheet is implemented through the public dispatcher.
        Response := Implement(Request);
        // [THEN] Item cost and proposal change, but neither quantity nor value ledgers change.
        AssertSuccess(Response);
        Assert.IsTrue(IntegerValue(Response, 'lineCount') > 0, 'Stock produces a native revaluation proposal.');
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
        Line.FindFirst();
        Assert.AreEqual(15, Line."Unit Cost (Revalued)", 'Actual native journal line value.');
        Assert.AreEqual(Line."Line No.", IntegerValue(FirstLine(Response), 'lineNo'), 'Response uses actual journal line number.');
        Item.Get(Item."No.");
        Assert.AreEqual(15, Item."Standard Cost", 'Native implementation updates item cost.');
        Worksheet.Get(Name, Worksheet.Type::Item, Item."No.");
        Assert.IsTrue(Worksheet.Implemented, 'Native implementation marks worksheet line.');
        Assert.AreEqual(ValuesBefore, ValueEntry.Count(), 'No revaluation is posted.');
        Assert.AreEqual(LedgersBefore, Ledger.Count(), 'No inventory quantity is posted.');
    end;

    [Test]
    procedure Scenario_AC02_ZeroStock_UpdatesCostWithEmptyJournal()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Name: Code[10];
        Response: JsonObject;
    begin
        // Story 121, AC02 | Time: first open date on or after WorkDate | Risk: zero-stock report behavior.
        Initialize();
        CreateItem(Item);
        Name := CreateWorksheet();
        AssertSuccess(Suggest(Name, Item."No.", 1.25));
        CreateBatch(Batch);
        Response := Implement(ImplementRequest(Name, Batch));
        AssertSuccess(Response);
        Assert.AreEqual(0, IntegerValue(Response, 'lineCount'), 'Zero stock creates no valuation line.');
        Item.Get(Item."No.");
        Assert.AreEqual(15, Item."Standard Cost", 'Cost still changes.');
    end;

    [Test]
    procedure Scenario_AC04_MissingWorksheet_ReturnsCodeAndNextStep()
    var
        Request: JsonObject;
    begin
        // Story 121, AC04 | Time: none | Risk: none.
        Initialize();
        AssertRefusal(CallSuggest(Request), 'MissingParameter');
        Request.Add('worksheetName', 'MISSING121');
        AssertRefusal(CallSuggest(Request), 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC04_InvalidFactors_LeaveWorksheetEmpty()
    var
        Item: Record Item;
        Worksheet: Record "Standard Cost Worksheet";
        Name: Code[10];
        Request: JsonObject;
    begin
        // Story 121, AC04 | Time: none | Risk: JSON number coercion.
        Initialize();
        CreateItem(Item);
        Name := CreateWorksheet();
        Request.Add('worksheetName', Name);
        Request.Add('itemFilter', Item."No.");
        Request.Add('adjustmentFactor', '1.1');
        AssertRefusal(CallSuggest(Request), 'InvalidParameter');
        Request.Replace('adjustmentFactor', 0);
        AssertRefusal(CallSuggest(Request), 'InvalidParameter');
        Request.Replace('adjustmentFactor', -1);
        AssertRefusal(CallSuggest(Request), 'InvalidParameter');
        Request.Replace('adjustmentFactor', true);
        AssertRefusal(CallSuggest(Request), 'InvalidParameter');
        Worksheet.SetRange("Standard Cost Worksheet Name", Name);
        Assert.IsTrue(Worksheet.IsEmpty(), 'Invalid requests have no writes.');
    end;

    [Test]
    procedure Scenario_AC04_UnknownParameter_IsRefused()
    var
        Request: JsonObject;
    begin
        // Story 121, AC04 | Time: none | Risk: unknown keys must never be silently ignored.
        Initialize();
        Request.Add('post', true);
        AssertRefusal(CallSuggest(Request), 'UnknownParameter');
        AssertRefusal(Implement(Request), 'UnknownParameter');
    end;

    [Test]
    procedure Scenario_AC04_InvalidFilter_ReturnsTypedError()
    var
        Name: Code[10];
    begin
        // Story 121, AC04 | Time: none | Risk: platform filter parsing.
        Initialize();
        Name := CreateWorksheet();
        AssertRefusal(Suggest(Name, '(', 1), 'InvalidParameterFormat');
        AssertRefusal(Suggest(Name, 'NO-SUCH-ITEM-121', 1), 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC04_BlockedSelection_IsAtomic()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Worksheet: Record "Standard Cost Worksheet";
        Name: Code[10];
    begin
        // Story 121, AC04 | Time: none | Risk: selection preflight must precede writes.
        Initialize();
        CreateItem(Item);
        CreateItem(OtherItem);
        OtherItem.Validate(Blocked, true);
        OtherItem.Modify(true);
        Name := CreateWorksheet();
        AssertRefusal(Suggest(Name, Item."No." + '|' + OtherItem."No.", 1.1), 'PreconditionFailed');
        Worksheet.SetRange("Standard Cost Worksheet Name", Name);
        Assert.IsTrue(Worksheet.IsEmpty(), 'No first-item write before blocked second item refusal.');
    end;

    [Test]
    procedure Scenario_AC04_NonemptyJournal_PreservesCostsAndLines()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Name: Code[10];
    begin
        // Story 121, AC04 | Time: first open date on or after WorkDate | Risk: existing journal rows are never overwritten.
        Initialize();
        CreateItem(Item);
        Name := CreateWorksheet();
        AssertSuccess(Suggest(Name, Item."No.", 1.25));
        CreateBatch(Batch);
        Line.Init();
        Line."Journal Template Name" := Batch."Journal Template Name";
        Line."Journal Batch Name" := Batch.Name;
        Line."Line No." := 10000;
        Line.Insert(true);
        AssertRefusal(Implement(ImplementRequest(Name, Batch)), 'PreconditionFailed');
        Assert.IsTrue(Line.Get(Batch."Journal Template Name", Batch.Name, 10000), 'Existing line preserved.');
        Item.Get(Item."No.");
        Assert.AreEqual(12, Item."Standard Cost", 'Item remains unchanged.');
    end;

    [Test]
    procedure Scenario_AC04_AlreadyImplemented_IsRefused()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Name: Code[10];
        Request: JsonObject;
    begin
        // Story 121, AC04 | Time: first open date on or after WorkDate | Risk: replay of native implementation.
        Initialize();
        CreateItem(Item);
        Name := CreateWorksheet();
        AssertSuccess(Suggest(Name, Item."No.", 1.25));
        CreateBatch(Batch);
        Request := ImplementRequest(Name, Batch);
        AssertSuccess(Implement(Request));
        AssertRefusal(Implement(Request), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC04_InvalidDate_DoesNotImplement()
    var
        Batch: Record "Item Journal Batch";
        Request: JsonObject;
    begin
        // Story 121, AC04 | Time: invalid input, WorkDate is unused by the rejected call | Risk: date parsing.
        Initialize();
        CreateBatch(Batch);
        Request := ImplementRequest(CreateWorksheet(), Batch);
        Request.Replace('postingDate', '16.11.2026');
        AssertRefusal(Implement(Request), 'InvalidParameterFormat');
    end;

    [Test]
    procedure Scenario_AC04_DisabledDomain_HasNextStep()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Management: Codeunit "Std. Cost Management ori";
    begin
        // Story 121, AC04 | Time: none | Risk: domain gate is evaluated before native writes.
        Initialize();
        Setup.Get();
        Setup.Costing := false;
        Setup.Modify(true);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument."Content Type" := TempArgument.GetContentTypeJson();
        Assert.IsFalse(Management.ValidateSuggest(TempArgument), 'Domain must refuse.');
        AssertRefusal(TempArgument.GetResponseJson(), 'InvalidParameter');
    end;

    [Test]
    procedure Scenario_AC04_AC05_Contracts_AreBilingualAndDeclareWrites()
    var
        SuggestImpl: Codeunit "Std. Cost Suggest Impl ori";
        ImplementImpl: Codeunit "Std. Cost Implement Impl ori";
        Contract: Codeunit "Std. Cost Contract ori";
        Effect: JsonObject;
        Params: JsonArray;
        English: Text;
        Icelandic: Text;
        OriginalLanguage: Integer;
    begin
        // Story 121, AC04/AC05 | Time: none | Risk: locale-sensitive help.
        Initialize();
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        English := SuggestImpl.GetDescription();
        GlobalLanguage(1039);
        Icelandic := SuggestImpl.GetDescription();
        Assert.AreNotEqual(English, Icelandic, 'Suggestion discovery is localized.');
        GlobalLanguage(1033);
        English := ImplementImpl.GetDescription();
        GlobalLanguage(1039);
        Icelandic := ImplementImpl.GetDescription();
        Assert.AreNotEqual(English, Icelandic, 'Implementation discovery is localized.');
        GlobalLanguage(OriginalLanguage);
        Contract.GetEffect(Effect, false);
        Assert.AreEqual('write', TextValue(Effect, 'effect'), 'Suggestion declares a write.');
        Contract.GetEffect(Effect, true);
        Assert.AreEqual('write', TextValue(Effect, 'effect'), 'Implementation declares unposted writes.');
        Contract.GetParameters(Params, false);
        Assert.AreEqual(3, Params.Count(), 'Three suggestion parameters.');
        Contract.GetParameters(Params, true);
        Assert.AreEqual(5, Params.Count(), 'Five implementation parameters.');
        Assert.AreEqual(3, TypeNameParts('Inventory.StandardCost.Suggest'), 'Exactly three name parts.');
        Assert.AreEqual(3, TypeNameParts('Inventory.StandardCost.Implement'), 'Exactly three name parts.');
    end;

    [Test]
    procedure Scenario_AC04_NativeSecondItemFailure_RollsBackFirstItem()
    var
        FirstItem: Record Item;
        SecondItem: Record Item;
        Worksheet: Record "Standard Cost Worksheet";
        Batch: Record "Item Journal Batch";
        Failure: Codeunit "Std. Cost Failure Test ori";
        Name: Code[10];
        Response: JsonObject;
    begin
        // Story 121, AC04 | Time: first open date on or after WorkDate | Risk: report callbacks must not commit partial changes.
        Initialize();
        // [GIVEN] Two ordered worksheet items, with a failure injected before updating the second.
        CreateItem(FirstItem);
        CreateItem(SecondItem);
        Assert.IsTrue(FirstItem."No." < SecondItem."No.", 'Fixture numbers must be ordered.');
        Name := CreateWorksheet();
        AssertSuccess(Suggest(Name, FirstItem."No." + '|' + SecondItem."No.", 1.25));
        CreateBatch(Batch);
        Failure.SetFailItem(SecondItem."No.");
        BindSubscription(Failure);
        // [WHEN] The native report updates the first item and fails on the second.
        Response := Implement(ImplementRequest(Name, Batch));
        UnbindSubscription(Failure);
        // [THEN] The isolated process rolls back both cost and worksheet state.
        AssertRefusal(Response, 'BusinessCentralError');
        FirstItem.Get(FirstItem."No.");
        SecondItem.Get(SecondItem."No.");
        Assert.AreEqual(12, FirstItem."Standard Cost", 'First item update must roll back.');
        Assert.AreEqual(12, SecondItem."Standard Cost", 'Second item stays unchanged.');
        Worksheet.Get(Name, Worksheet.Type::Item, FirstItem."No.");
        Assert.IsFalse(Worksheet.Implemented, 'First worksheet implementation flag must roll back.');
    end;

    local procedure TypeNameParts(TypeName: Text): Integer
    begin
        exit(TypeName.Split('.').Count());
    end;

    local procedure Initialize()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Library.Initialize();
        Setup.InsertIfNotExists();
        Setup.Costing := true;
        Setup.Modify(true);
    end;

    local procedure CreateItem(var Item: Record Item)
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate("Costing Method", Item."Costing Method"::Standard);
        Item.Validate("Standard Cost", 12);
        Item.Modify(true);
    end;

    local procedure CreateWorksheet(): Code[10]
    var
        Name: Record "Standard Cost Worksheet Name";
    begin
        Name.Name := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10);
        Name.Insert(true);
        exit(Name.Name);
    end;

    local procedure CreateBatch(var Batch: Record "Item Journal Batch")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalTemplate.Type::Revaluation);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;

    local procedure OpenPostingDate() PostingDate: Date
    var
        Period: Record "Inventory Period";
    begin
        PostingDate := WorkDate();
        Period.SetRange(Closed, true);
        if Period.FindLast() then
            if Period."Ending Date" >= PostingDate then
                PostingDate := Period."Ending Date" + 1;
    end;

    local procedure CreateStock(Item: Record Item)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", 2);
        Line.Validate("Posting Date", OpenPostingDate());
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
    end;

    local procedure Suggest(Name: Code[10]; ItemFilter: Text; Factor: Decimal): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('worksheetName', Name);
        Request.Add('itemFilter', ItemFilter);
        Request.Add('adjustmentFactor', Factor);
        exit(CallSuggest(Request));
    end;

    local procedure CallSuggest(Request: JsonObject): JsonObject
    begin
        Commit();
        exit(Library.ExecuteType("Message Type ori"::"Inventory.StandardCost.Suggest", '', Request, false));
    end;

    local procedure Implement(Request: JsonObject): JsonObject
    begin
        Commit();
        exit(Library.ExecuteType("Message Type ori"::"Inventory.StandardCost.Implement", '', Request, false));
    end;

    local procedure ImplementRequest(Name: Code[10]; Batch: Record "Item Journal Batch") Request: JsonObject
    begin
        Request.Add('worksheetName', Name);
        Request.Add('journalTemplateName', Batch."Journal Template Name");
        Request.Add('journalBatchName', Batch.Name);
        Request.Add('postingDate', Format(OpenPostingDate(), 0, 9));
        Request.Add('documentNo', 'STD121');
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        Assert.AreEqual('Success', TextValue(Response, 'status'), Format(Response));
    end;

    local procedure AssertRefusal(Response: JsonObject; CodeName: Text)
    var
        Token: JsonToken;
    begin
        Response.Get('code', Token);
        if Token.IsObject() then
            Token.AsObject().Get('name', Token);
        Assert.AreEqual(CodeName, Token.AsValue().AsText(), Format(Response));
        Assert.AreNotEqual('', TextValue(Response, 'nextStep'), 'Actionable refusal.');
    end;

    local procedure TextValue(Response: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsText());
    end;

    local procedure IntegerValue(Response: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure DecimalValue(Response: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        Response.Get(KeyName, Token);
        exit(Token.AsValue().AsDecimal());
    end;

    local procedure FirstLine(Response: JsonObject): JsonObject
    var
        Token: JsonToken;
        Row: JsonToken;
    begin
        Response.Get('lines', Token);
        Token.AsArray().Get(0, Row);
        exit(Row.AsObject());
    end;
}
