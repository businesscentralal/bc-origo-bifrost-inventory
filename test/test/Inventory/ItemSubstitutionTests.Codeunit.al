namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Issue 118: direct substitution reads, exact variant inventory, refusals and read-only behavior.</summary>
codeunit 96993 "Item Substitution Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    /// <summary>Scenario AC01 Variant ReturnsExactInventory.</summary>
    [Test]
    procedure Scenario_AC01_Variant_ReturnsExactInventory()
    var
        Source: Record Item;
        Substitute: Record Item;
        Substitution: Record "Item Substitution";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        ModifiedAt: DateTime;
    begin
        // Story #118, AC01/AC02 | Time: fixed posting date; WorkDate ignored | Risk: None
        // [GIVEN] Two source variants and substitute stock split over variants.
        Initialize();
        CreateItem(Source);
        CreateItem(Substitute);
        CreateVariant(Source."No.", 'RED');
        CreateVariant(Substitute."No.", 'BLUE');
        CreateSubstitution(Substitution, Source."No.", 'RED', Substitute."No.", 'BLUE');
        Substitution.Inventory := 999;
        Substitution.Modify();
        ModifiedAt := Substitution.SystemModifiedAt;
        CreateStock(Substitute."No.", 'BLUE', 7.25);
        CreateStock(Substitute."No.", 'BLUE', -2);
        CreateStock(Substitute."No.", '', 90);
        Request.Add('itemNo', Source."No.");
        Request.Add('variantCode', 'RED');
        // [WHEN] The registered message type is dispatched.
        Response := Execute(Request);
        // [THEN] Only the exact substitute variant contributes, with no cached quantity write.
        Row := OnlyRow(Response);
        Assert.AreEqual(Substitute."No.", Row.GetText('substituteNo'), 'Substitute');
        Assert.AreEqual('BLUE', Row.GetText('substituteVariantCode'), 'Variant');
        Assert.AreEqual(5.25, Row.GetDecimal('inventory'), 'Exact variant inventory');
        Assert.IsTrue(Row.GetBoolean('inventoryKnown'), 'Inventory is known');
        Substitution.Get(Substitution.Type, Source."No.", 'RED', Substitution."Substitute Type", Substitute."No.", 'BLUE');
        Assert.AreEqual(999, Substitution.Inventory, 'Cached inventory must remain untouched');
        Assert.AreEqual(ModifiedAt, Substitution.SystemModifiedAt, 'Read must not modify substitution');
    end;

    /// <summary>Scenario AC01 BlankVariant ExcludesOtherVariants.</summary>
    [Test]
    procedure Scenario_AC01_BlankVariant_ExcludesOtherVariants()
    var
        Source: Record Item;
        Substitute: Record Item;
        Substitution: Record "Item Substitution";
        Request: JsonObject;
        Row: JsonObject;
    begin
        // Story #118, AC01 | Time: fixed posting date; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] Blank and named source and substitute variants.
        CreateItem(Source);
        CreateItem(Substitute);
        CreateVariant(Source."No.", 'RED');
        CreateVariant(Substitute."No.", 'BLUE');
        CreateSubstitution(Substitution, Source."No.", '', Substitute."No.", '');
        CreateSubstitution(Substitution, Source."No.", 'RED', Substitute."No.", 'BLUE');
        CreateStock(Substitute."No.", '', -3);
        CreateStock(Substitute."No.", 'BLUE', 12);
        Request.Add('itemNo', Source."No.");
        // [WHEN] variantCode is omitted.
        Row := OnlyRow(Execute(Request));
        // [THEN] Only the blank variant and its negative inventory are returned.
        Assert.AreEqual('', Row.GetText('substituteVariantCode'), 'Exact blank variant');
        Assert.AreEqual(-3, Row.GetDecimal('inventory'), 'Negative inventory is preserved');
    end;

    /// <summary>Scenario AC01 CatalogSubstitute HasUnknownInventory.</summary>
    [Test]
    procedure Scenario_AC01_CatalogSubstitute_HasUnknownInventory()
    var
        Source: Record Item;
        Catalog: Record "Nonstock Item";
        Substitution: Record "Item Substitution";
        Request: JsonObject;
        Row: JsonObject;
        ItemsBefore: Integer;
    begin
        // Story #118, AC01/AC02 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] A catalog substitute with no created item.
        CreateItem(Source);
        Catalog."Entry No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Catalog.Description := 'Catalog substitute';
        Catalog.Insert();
        Substitution.Type := Substitution.Type::Item;
        Substitution."No." := Source."No.";
        Substitution."Substitute Type" := Substitution."Substitute Type"::"Nonstock Item";
        Substitution."Substitute No." := Catalog."Entry No.";
        Substitution.Description := Catalog.Description;
        Substitution.Insert();
        ItemsBefore := Source.Count();
        Request.Add('itemNo', Source."No.");
        // [WHEN] The substitution is read.
        Row := OnlyRow(Execute(Request));
        // [THEN] No item is created and catalog availability is explicitly unknown.
        Assert.AreEqual('nonstockItem', Row.GetText('substituteType'), 'Stable type');
        Assert.IsFalse(Row.GetBoolean('inventoryKnown'), 'Catalog inventory is not known');
        Assert.AreEqual(0, Row.GetDecimal('inventory'), 'Catalog quantity');
        Assert.AreEqual(ItemsBefore, Source.Count(), 'No catalog item conversion');
    end;

    /// <summary>Scenario AC01 NoSubstitutes ReturnsEmptyArray.</summary>
    [Test]
    procedure Scenario_AC01_NoSubstitutes_ReturnsEmptyArray()
    var
        Source: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #118, AC01 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] An item with no substitutions.
        CreateItem(Source);
        Request.Add('itemNo', Source."No.");
        // [WHEN] It is read.
        Response := Execute(Request);
        // [THEN] The call succeeds with no rows.
        Library.AssertStatus(Response, 'Success');
        Assert.AreEqual(0, Response.GetArray('substitutes').Count(), 'No substitutions');
    end;

    /// <summary>Scenario AC03 UnknownItem ReturnsRecordNotFound.</summary>
    [Test]
    procedure Scenario_AC03_UnknownItem_ReturnsRecordNotFound()
    var
        Request: JsonObject;
    begin
        // Story #118, AC03 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] A unique item number that does not exist.
        Request.Add('itemNo', CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
        // [WHEN/THEN] The request gets a coded refusal with guidance.
        AssertRefusal(Execute(Request), 'RecordNotFound');
    end;

    /// <summary>Scenario AC04 MissingItem ReturnsMissingParameter.</summary>
    [Test]
    procedure Scenario_AC04_MissingItem_ReturnsMissingParameter()
    var
        Request: JsonObject;
    begin
        // Story #118, AC04 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN/WHEN/THEN] An empty request is refused with guidance.
        AssertRefusal(Execute(Request), 'MissingParameter');
        Request.Add('itemNo', '   ');
        AssertRefusal(Execute(Request), 'MissingParameter');
    end;

    /// <summary>Scenario AC04 InvalidJsonTypes ReturnFormatError.</summary>
    [Test]
    procedure Scenario_AC04_InvalidJsonTypes_ReturnFormatError()
    var
        Source: Record Item;
        Request: JsonObject;
    begin
        // Story #118, AC04 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN/WHEN/THEN] Numeric, object and null selectors are refused.
        Request.Add('itemNo', 123);
        AssertRefusal(Execute(Request), 'InvalidParameterFormat');
        Request.ReadFrom('{"itemNo":{}}');
        AssertRefusal(Execute(Request), 'InvalidParameterFormat');
        Request.ReadFrom('{"itemNo":null}');
        AssertRefusal(Execute(Request), 'InvalidParameterFormat');
        CreateItem(Source);
        Clear(Request);
        Request.Add('itemNo', Source."No.");
        Request.Add('variantCode', false);
        AssertRefusal(Execute(Request), 'InvalidParameterFormat');
    end;

    /// <summary>Scenario AC04 LengthLimits AcceptsBoundaryRejectsOverflow.</summary>
    [Test]
    procedure Scenario_AC04_LengthLimits_AcceptsBoundaryRejectsOverflow()
    var
        Source: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #118, AC04 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] An item and variant at their maximum lengths.
        CreateItem(Source);
        CreateVariant(Source."No.", '1234567890');
        Request.Add('itemNo', Source."No.");
        Request.Add('variantCode', '1234567890');
        // [WHEN/THEN] Exact limits succeed; one character over is refused before conversion.
        Response := Execute(Request);
        Library.AssertStatus(Response, 'Success');
        Request.Replace('variantCode', '12345678901');
        AssertRefusal(Execute(Request), 'InvalidParameter');
        Request.Replace('variantCode', '');
        Request.Replace('itemNo', Source."No." + 'X');
        AssertRefusal(Execute(Request), 'InvalidParameter');
    end;

    /// <summary>Scenario AC04 UnknownVariantAndKey ReturnCodedErrors.</summary>
    [Test]
    procedure Scenario_AC04_UnknownVariantAndKey_ReturnCodedErrors()
    var
        Source: Record Item;
        Request: JsonObject;
    begin
        // Story #118, AC04 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] A valid item without RED.
        CreateItem(Source);
        Request.Add('itemNo', Source."No.");
        Request.Add('variantCode', 'RED');
        // [WHEN/THEN] Unknown variants and unexpected keys have actionable errors.
        AssertRefusal(Execute(Request), 'RecordNotFound');
        Request.Add('locationCode', 'BLUE');
        AssertRefusal(Execute(Request), 'UnknownParameter');
    end;

    /// <summary>Scenario AC04 DisabledDomain RefusesWithoutWrites.</summary>
    [Test]
    procedure Scenario_AC04_DisabledDomain_OnlyHidesType()
    var
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Item Subst. Get Impl ori";
        DomainCheck: Codeunit "Inv. MCP Fixture ori";
    begin
        // Story #118, AC02/AC04, narrowed by the Issue36 ruling (Gunnar 18.11.2026): the switch only changes IsEnabled | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] An administrator disables the domain.
        Setup.Get();
        Setup."Item Substitution" := false;
        Setup.Modify();
        // [WHEN] Both discovery and direct execution are checked.
        Assert.IsFalse(Impl.IsEnabled(), 'Disabled discovery');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        // [THEN] Direct execution is not refused for the domain.
        DomainCheck.AssertDomainOffOnlyHidesType(Impl, TempArgument);
    end;

    /// <summary>Scenario AC04 HelpAndErrors AreBilingual.</summary>
    [Test]
    procedure Scenario_AC04_HelpAndErrors_AreBilingual()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Impl: Codeunit "Item Subst. Get Impl ori";
        ContractEn: JsonObject;
        ContractIs: JsonObject;
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
        OldLanguage: Integer;
        OverviewEn: Text;
        OverviewIs: Text;
    begin
        // Story #118, AC04/AC05 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN/WHEN] The same contract and refusal are read in both languages.
        OldLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        ContractMgt.GetContract("Message Type ori"::"Inventory.ItemSubstitution.Get", ContractEn);
        Impl.GetOverview(OverviewEn);
        English := Execute(Request);
        GlobalLanguage(1039);
        ContractMgt.GetContract("Message Type ori"::"Inventory.ItemSubstitution.Get", ContractIs);
        Impl.GetOverview(OverviewIs);
        Icelandic := Execute(Request);
        GlobalLanguage(OldLanguage);
        // [THEN] Stable codes and translated guidance are present, with an explicit read effect.
        AssertRefusal(English, 'MissingParameter');
        AssertRefusal(Icelandic, 'MissingParameter');
        Assert.AreNotEqual(English.GetText('nextStep'), Icelandic.GetText('nextStep'), 'Translated next step');
        Assert.AreNotEqual(OverviewEn, OverviewIs, 'The app supplies translated overview labels');
        // Foundation #1239 intentionally builds public contracts in English, regardless of caller LCID.
        Assert.AreEqual(ContractEn.GetText('overview'), ContractIs.GetText('overview'), 'Foundation public help policy');
        Assert.AreEqual('read', ContractEn.GetObject('effect').GetText('effect'), 'Read effect');

    end;

    /// <summary>Scenario AC02 SetupPage ToggleAndWizardReadOnly.</summary>
    [Test]
    procedure Scenario_AC02_SetupPage_ToggleAndWizardReadOnly()
    var
        Setup: Record "Inventory Setup ori";
        Impl: Codeunit "Item Subst. Get Impl ori";
        SetupPage: TestPage "Inventory Setup ori";
        Wizard: TestPage "Inventory Setup Wizard ori";
    begin
        // Story #118, AC02 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN/WHEN] An administrator changes the switch through the real page.
        SetupPage.OpenEdit();
        SetupPage.ItemSubstitution.SetValue(false);
        SetupPage.Close();
        // [THEN] The switch governs discovery and the wizard shows it without editing it.
        Assert.IsFalse(Impl.IsEnabled(), 'Page toggle disables discovery');
        Wizard.OpenView();
        Assert.IsFalse(Wizard.ItemSubstitution.Editable(), 'Wizard switch is read-only');
        Wizard.Close();
        Setup.Get();
        Assert.IsFalse(Setup."Item Substitution", 'Opening wizard does not enable domain');
    end;

    /// <summary>Substitution usage enables its domain without overwriting a manual opt-out on an existing row.</summary>
    [Test]
    procedure Scenario_AC02_SubstitutionUsage_EnablesNewSetup()
    var
        Source: Record Item;
        Substitute: Record Item;
        Substitution: Record "Item Substitution";
        Setup: Record "Inventory Setup ori";
        SuggestSetup: Codeunit "Inventory Suggest Setup ori";
    begin
        // Story #118, AC02 | Time: none; WorkDate ignored | Risk: None
        Initialize();
        // [GIVEN] Native substitution usage and an existing administrator opt-out.
        CreateItem(Source);
        CreateItem(Substitute);
        CreateSubstitution(Substitution, Source."No.", '', Substitute."No.", '');
        Setup.Get();
        Setup."Item Substitution" := false;
        Setup.Modify();
        // [WHEN/THEN] Opening existing setup preserves the opt-out.
        Setup.InsertIfNotExists();
        Assert.IsFalse(Setup."Item Substitution", 'Existing opt-out is preserved');
        // [WHEN] New company setup is created, every switch is off until Suggest Setup runs.
        Setup.Delete();
        Setup.InsertIfNotExists();
        Assert.IsFalse(Setup."Item Substitution", 'New setup starts with the switch off');
        // [THEN] Suggest Setup turns it on because the company has items.
        SuggestSetup.ApplyTo(Setup);
        Assert.IsTrue(Setup."Item Substitution", 'Suggest Setup enables substitution when items exist');
    end;

    local procedure Initialize()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Library.Initialize();
        Setup.InsertIfNotExists();
        Setup."Item Substitution" := true;
        Setup.Modify();
    end;

    local procedure Execute(Request: JsonObject) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        ResponseBlob: Codeunit "Temp Blob";
        RequestContent: BigText;
        ResponseStream: InStream;
        RequestText: Text;
        ResponseContentType: Text[100];
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
    begin
        Request.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        // Use the public dispatcher with an explicit LCID; Execute uses the company default instead.
        Dispatcher.EnqueueAndProcess("Message Type ori"::"Inventory.ItemSubstitution.Get", "Message Version ori"::"1.0", '', '', 'application/json', RequestContent, TaskId, GlobalLanguage(), MessageId, ResponseBlob, ResponseContentType, ResponseTime, true);
        ResponseBlob.CreateInStream(ResponseStream, TextEncoding::UTF8);
        Response.ReadFrom(ResponseStream);
    end;

    local procedure AssertRefusal(Response: JsonObject; Code: Text)
    begin
        Library.AssertStatus(Response, 'Error');
        Assert.AreEqual(Code, Response.GetText('code'), 'Expected error code');
        Assert.AreNotEqual('', Response.GetText('nextStep'), 'Actionable next step');
    end;

    local procedure OnlyRow(Response: JsonObject): JsonObject
    var
        Rows: JsonArray;
        Row: JsonToken;
    begin
        Library.AssertStatus(Response, 'Success');
        Rows := Response.GetArray('substitutes');
        Assert.AreEqual(1, Rows.Count(), 'Exactly one substitute');
        Rows.Get(0, Row);
        exit(Row.AsObject());
    end;

    local procedure CreateItem(var Item: Record Item)
    begin
        Item.Init();
        Item."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Item.Description := 'Substitution test';
        Item.Insert();
    end;

    local procedure CreateVariant(ItemNo: Code[20]; VariantCode: Code[10])
    var
        Variant: Record "Item Variant";
    begin
        Variant."Item No." := ItemNo;
        Variant.Code := VariantCode;
        Variant.Insert();
    end;

    local procedure CreateSubstitution(var Substitution: Record "Item Substitution"; ItemNo: Code[20]; VariantCode: Code[10]; SubstituteNo: Code[20]; SubstituteVariantCode: Code[10])
    begin
        Substitution.Init();
        Substitution.Type := Substitution.Type::Item;
        Substitution."No." := ItemNo;
        Substitution."Variant Code" := VariantCode;
        Substitution."Substitute Type" := Substitution."Substitute Type"::Item;
        Substitution."Substitute No." := SubstituteNo;
        Substitution."Substitute Variant Code" := SubstituteVariantCode;
        Substitution.Description := 'Substitute';
        Substitution.Insert();
    end;

    local procedure CreateStock(ItemNo: Code[20]; VariantCode: Code[10]; Quantity: Decimal)
    var
        Ledger: Record "Item Ledger Entry";
        EntryNo: Integer;
    begin
        Ledger.LockTable();
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Item No." := ItemNo;
        Ledger."Variant Code" := VariantCode;
        Ledger."Posting Date" := 20260101D;
        Ledger.Quantity := Quantity;
        Ledger."Remaining Quantity" := Quantity;
        Ledger.Insert();
    end;
}
