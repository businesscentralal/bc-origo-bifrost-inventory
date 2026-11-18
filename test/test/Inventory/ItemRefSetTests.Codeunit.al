namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Item;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Inventory;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Dispatcher regressions for Inventory.ItemReference.Set, issue 102.</summary>
codeunit 96928 "Item Ref. Set Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    [Test]
    procedure Scenario_AC01_NewAndExisting_SaveDescriptionAndDates()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC01 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] An item and a new reference.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Add('description', 'Original');
        Request.Add('startingDate', '2026-01-01');
        Request.Add('endingDate', '2026-12-31');
        // [WHEN] The request is dispatched twice with changed optional fields.
        Response := CallSet(Request);
        Library.AssertStatus(Response, 'Success');
        AssertBoolean(Response, 'created', true);
        Request.Replace('description', 'Changed');
        Request.Replace('startingDate', '2027-01-01');
        Request.Replace('endingDate', '2027-12-31');
        Response := CallSet(Request);
        // [THEN] The same reference is updated with the entire moved interval.
        Library.AssertStatus(Response, 'Success');
        AssertBoolean(Response, 'created', false);
        Assert.IsTrue(Reference.Get(Item."No.", '', '', "Item Reference Type"::"Bar Code", '', Item."No."), 'Saved reference');
        Assert.AreEqual('Changed', Reference.Description, 'Description');
        Assert.AreEqual(20270101D, Reference."Starting Date", 'Starting date');
        Assert.AreEqual(20271231D, Reference."Ending Date", 'Ending date');
    end;

    [Test]
    procedure Scenario_AC01_OmittedFields_PreserveAndEmptyDatesClear()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC01 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A reference with optional data.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Add('description', 'Keep');
        Request.Add('startingDate', '2026-01-01');
        Response := CallSet(Request);
        Library.AssertStatus(Response, 'Success');
        // [WHEN] Optional fields are omitted, then a date is explicitly cleared.
        Request := NewRequest(Item."No.");
        Response := CallSet(Request);
        Library.AssertStatus(Response, 'Success');
        AssertText(Response, 'description', 'Keep');
        AssertText(Response, 'startingDate', '2026-01-01');
        Request.Add('startingDate', '');
        Response := CallSet(Request);
        // [THEN] The description remains and the date clears.
        Library.AssertStatus(Response, 'Success');
        AssertText(Response, 'description', 'Keep');
        AssertText(Response, 'startingDate', '');
    end;

    [Test]
    procedure Scenario_AC02_OtherItemConflict_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        OtherItem: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC02 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A reference already assigned to one item.
        CreateItem(Item);
        CreateItem(OtherItem);
        Request := NewRequest(Item."No.");
        Response := CallSet(Request);
        Library.AssertStatus(Response, 'Success');
        // [WHEN] Another item claims the same reference in the same scope.
        Request.Replace('itemNo', OtherItem."No.");
        Response := CallSet(Request);
        // [THEN] The conflict is coded and the original remains alone.
        AssertRefusal(Response, 'ConflictingIdentifiers');
        Reference.SetRange("Reference No.", Item."No.");
        Assert.AreEqual(1, Reference.Count(), 'Only original reference');
        Reference.FindFirst();
        Assert.AreEqual(Item."No.", Reference."Item No.", 'Original owner');
    end;

    [Test]
    procedure Scenario_AC04_MissingItem_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('itemNo');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'MissingParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_UnknownField_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('unsupported');
        Request.Add('unsupported', 'x');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'UnknownParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_WrongType_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('referenceNo');
        Request.Add('referenceNo', true);
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'InvalidParameterFormat');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_NullValue_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
        NullValue: JsonValue;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('description');
        Request.Add('description', NullValue);
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'InvalidParameterFormat');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_OverlongReference_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('referenceNo');
        Request.Add('referenceNo', PadStr('', 51, 'x'));
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'InvalidParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_UnknownType_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('referenceType');
        Request.Add('referenceType', 'other');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'InvalidParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_InvalidDate_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('startingDate');
        Request.Add('startingDate', '2026-02-30');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'InvalidParameterFormat');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_UnknownVariant_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('variantCode');
        Request.Add('variantCode', 'UNKNOWN');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'RecordNotFound');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_UnknownUnit_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('unitOfMeasure');
        Request.Add('unitOfMeasure', 'UNKNOWN');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'RecordNotFound');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_MissingCustomer_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('referenceType');
        Request.Add('referenceType', 'customer');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'MissingParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_BarcodeTypeNo_RefusesWithoutWrites()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] A valid item and an invalid request.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Remove('referenceTypeNo');
        Request.Add('referenceTypeNo', 'CUSTOMER');
        // [WHEN] Dispatching the request.
        Response := CallSet(Request);
        // [THEN] Refusal contains a recovery step and saves no reference.
        AssertRefusal(Response, 'InvalidParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No write on refusal');
    end;

    [Test]
    procedure Scenario_AC04_InvertedDates_Refuse()
    var
        Item: Record Item;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] An interval ending before it starts.
        CreateItem(Item);
        Request := NewRequest(Item."No.");
        Request.Add('startingDate', '2026-12-31');
        Request.Add('endingDate', '2026-01-01');
        // [WHEN] The request is dispatched.
        Response := CallSet(Request);
        // [THEN] Dates are rejected before a write.
        AssertRefusal(Response, 'InvalidParameter');
        Reference.SetRange("Item No.", Item."No.");
        Assert.IsTrue(Reference.IsEmpty(), 'No reference');
    end;

    [Test]
    procedure Scenario_AC03_GenericWrites_RestrictedAndReadsAllowed()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // Story #102, AC03 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] Foundation restriction events are subscribed.
        // [WHEN] The real Foundation policy API raises its subscriber events.
        // [THEN] Generic writes are refused and reads remain available.
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Reference", false), 'Write guard');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Item Reference"), 'Read allowed');
        Assert.AreEqual('Inventory.ItemReference.Set', TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Item Reference"), 'Recovery hint');
    end;

    [Test]
    procedure Scenario_AC04_BothLanguages_DeclareWriteAndRecovery()
    var
        Impl: Codeunit "Item Ref. Set Impl ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        OverviewEnglish: Text;
        OverviewIcelandic: Text;
        OriginalLanguage: Integer;
        MessageType: Enum "Message Type ori";
        RegisteredName: Text;
    begin
        // Story #102, AC04 | Time: fixed ISO dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] English and Icelandic caller sessions.
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Impl.GetOverview(OverviewEnglish);
        Response := CallSet(Request);
        AssertRefusal(Response, 'MissingParameter');
        // [WHEN] Help and invalid input are requested in Icelandic.
        GlobalLanguage(1039);
        Impl.GetOverview(OverviewIcelandic);
        Response := CallSet(Request);
        AssertRefusal(Response, 'MissingParameter');
        ContractMgt.GetContract("Message Type ori"::"Inventory.ItemReference.Set", Contract);
        Impl.GetEffect(Effect);
        GlobalLanguage(OriginalLanguage);
        // [THEN] Help is translated and the effect is a write.
        Assert.AreNotEqual(OverviewEnglish, OverviewIcelandic, 'Translated overview');
        AssertText(Effect, 'effect', 'write');
        AssertBoolean(Effect, 'writes', true);
        RegisteredName := 'Inventory.ItemReference.Set';
        Assert.IsTrue(MessageType.Names().Contains(RegisteredName), 'Registered name');
        Assert.AreEqual(3, RegisteredName.Split('.').Count(), 'Three-part name');
    end;

    [Test]
    procedure Scenario_AC01_BaseUnitVariantAndCustomer_SaveAllFields()
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Unit: Record "Unit of Measure";
        ItemUnit: Record "Item Unit of Measure";
        Customer: Record Customer;
        Reference: Record "Item Reference";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC01 | Time: fixed dates; Today and WorkDate ignored | Risk: None
        Library.Initialize();
        // [GIVEN] An item with its own unit and variant plus an existing customer.
        CreateItem(Item);
        Unit.Init();
        Unit.Code := CopyStr(Item."No.", 1, 10);
        Unit.Insert(true);
        ItemUnit.Init();
        ItemUnit."Item No." := Item."No.";
        ItemUnit.Code := Unit.Code;
        ItemUnit.Validate("Qty. per Unit of Measure", 1);
        ItemUnit.Insert(true);
        Item.Validate("Base Unit of Measure", Unit.Code);
        Item.Modify(true);
        Variant.Init();
        Variant."Item No." := Item."No.";
        Variant.Code := 'BLUE';
        Variant.Insert(true);
        Customer.Init();
        Customer."No." := Item."No.";
        Customer.Insert(true);
        Request := NewRequest(Item."No.");
        Request.Replace('referenceType', 'customer');
        Request.Add('referenceTypeNo', Customer."No.");
        Request.Add('variantCode', Variant.Code);
        Request.Add('description', 'Customer reference');
        // [WHEN] The same request without an explicit unit is sent twice.
        Response := CallSet(Request);
        Library.AssertStatus(Response, 'Success');
        Response := CallSet(Request);
        // [THEN] Base-unit normalization is idempotent and every key is persisted.
        Library.AssertStatus(Response, 'Success');
        AssertBoolean(Response, 'created', false);
        Assert.IsTrue(Reference.Get(Item."No.", Variant.Code, Unit.Code, "Item Reference Type"::Customer, Customer."No.", Item."No."), 'All key fields saved');
        Assert.AreEqual('Customer reference', Reference.Description, 'Description');
    end;

    [Test]
    procedure Scenario_AC01_VendorReference_CreatesNativeRelation()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        ItemVendor: Record "Item Vendor";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #102, AC01 | Time: none; Today and WorkDate ignored | Risk: Native Item Reference insert
        Library.Initialize();
        // [GIVEN] A new item and an existing vendor.
        CreateItem(Item);
        Vendor.Init();
        Vendor."No." := Item."No.";
        Vendor.Insert(true);
        Request := NewRequest(Item."No.");
        Request.Replace('referenceType', 'vendor');
        Request.Add('referenceTypeNo', Vendor."No.");
        // [WHEN] The reference is saved through the dispatcher.
        Response := CallSet(Request);
        // [THEN] The native insert trigger creates its related item vendor record.
        Library.AssertStatus(Response, 'Success');
        Assert.IsTrue(ItemVendor.Get(Vendor."No.", Item."No.", ''), 'Native vendor relation');
        Assert.AreEqual(Item."No.", ItemVendor."Vendor Item No.", 'Vendor item reference');
    end;

    local procedure CreateItem(var Item: Record Item)
    begin
        Item.Init();
        Item.Validate("No.", CopyStr('S102' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
        Item.Insert(true);
    end;

    local procedure NewRequest(ItemNo: Code[20]) Request: JsonObject
    begin
        Request.Add('itemNo', ItemNo);
        Request.Add('referenceType', 'barCode');
        Request.Add('referenceNo', ItemNo);
    end;

    local procedure CallSet(Request: JsonObject) Response: JsonObject
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup."Item Reference" := true;
        Setup.Modify(true);
        // The public surface is the dispatcher; there is no changed page/action for this message.
        Response := Library.ExecuteType("Message Type ori"::"Inventory.ItemReference.Set", '', Request, true);
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text)
    var
        NextStep: JsonToken;
    begin
        Library.AssertStatus(Response, 'Error');
        AssertText(Response, 'code', ExpectedCode);
        Assert.IsTrue(Response.Get('nextStep', NextStep), 'nextStep');
        Assert.AreNotEqual('', NextStep.AsValue().AsText(), 'Actionable recovery');
    end;

    local procedure AssertText(Response: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(KeyName, Token), KeyName);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), KeyName);
    end;

    local procedure AssertBoolean(Response: JsonObject; KeyName: Text; Expected: Boolean)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(KeyName, Token), KeyName);
        Assert.AreEqual(Expected, Token.AsValue().AsBoolean(), KeyName);
    end;
}
