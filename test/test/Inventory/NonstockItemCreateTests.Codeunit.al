namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Purchases.Vendor;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.NonstockItem.Create (#119): happy path with the catalog item template, the already-converted refusal,
/// invalid input, the incomplete catalog item and taken item number edge cases, the domain switch and the help contract.
/// Every test seeds its own vendor, unit of measure, item template and catalog item; the test runner rolls them back.
/// </summary>
codeunit 96998 "Nonstock Item Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ConvertedMsg: Label 'Catalog item %1 has already been turned into item %1.', Comment = '%1 = entry no.', Locked = true;
        NumberTakenMsg: Label 'Catalog item %1 would get item number %1, and item %1 already exists.', Comment = '%1 = entry no.', Locked = true;

    [Test]
    procedure Create_FromCatalogItem_ReturnsNewItemFromTemplate()
    var
        NonstockItem: Record "Nonstock Item";
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResponseJson: JsonObject;
        EntryNo: Code[20];
    begin
        // [SCENARIO AC01, AC03] The answer names the new item; the item has the template field and the catalog item data.
        EntryNo := CreateCatalogItem(true);
        ResponseJson := CallCreate(EntryNo);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(EntryNo, ReadText(ResponseJson, 'entryNo'), 'entryNo');
        Assert.AreEqual(EntryNo, ReadText(ResponseJson, 'itemNo'), 'Entry No. number format gives the entry no.');
        Assert.IsTrue(Item.Get(ReadText(ResponseJson, 'itemNo')), 'the item exists');
        Assert.AreEqual(LowerCase(Format(Item.SystemId, 0, 4)), ReadText(ResponseJson, 'itemId'), 'itemId');
        Assert.AreEqual('SHELF119', Item."Shelf No.", 'the template field is applied');
        Assert.IsTrue(Item."Created From Nonstock Item", 'created from catalog item');
        Assert.AreEqual('Catalog chair 119', Item.Description, 'description');
        NonstockItem.Get(EntryNo);
        Assert.AreEqual(NonstockItem."Unit of Measure", Item."Base Unit of Measure", 'base unit');
        Assert.AreEqual(NonstockItem."Vendor No.", Item."Vendor No.", 'vendor');
        Assert.AreEqual(NonstockItem."Vendor No.", ReadText(ResponseJson, 'vendorNo'), 'vendorNo');
        Assert.AreEqual(NonstockItem."Item Templ. Code", ReadText(ResponseJson, 'itemTemplateCode'), 'itemTemplateCode');
        Assert.AreEqual(Item."No.", NonstockItem."Item No.", 'the catalog item points to the item');
        Assert.IsTrue(ItemUnitOfMeasure.Get(Item."No.", NonstockItem."Unit of Measure"), 'base item unit of measure');
    end;

    [Test]
    procedure Create_AlreadyConverted_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        ResponseJson: JsonObject;
        EntryNo: Code[20];
    begin
        // [SCENARIO AC02, AC04] A second call for the same catalog item is refused and names the existing item.
        EntryNo := CreateCatalogItem(true);
        Assert.AreEqual('Success', ReadText(CallCreate(EntryNo), 'status'), 'first call');
        Item.SetRange("Vendor Item No.", 'V' + EntryNo);
        Assert.AreEqual(1, Item.Count(), 'one item after the first call');
        ResponseJson := CallCreate(EntryNo);
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual(StrSubstNo(ConvertedMsg, EntryNo), ReadText(ResponseJson, 'error'), 'error');
        Assert.AreEqual('Use the item named in the error. To create it again, delete that item on the Item Card first; that clears the item number on the catalog item.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(1, Item.Count(), 'still one item');
    end;

    [Test]
    procedure Create_UnknownEntry_ReturnsRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An entry no. without a catalog item is refused with RecordNotFound and a next step.
        EnableCatalogItems();
        ResponseJson := CallCreate('NOSUCH119');
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send entryNo with the Entry No. of an existing catalog item. Data.Records.Get on the Nonstock Item table lists them.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_MissingEntryNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Invalid input: no entryNo.
        EnableCatalogItems();
        ResponseJson := CallRequest(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_EntryNoAsNumber_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Invalid input: entryNo as a JSON number.
        EnableCatalogItems();
        RequestJson.Add('entryNo', 119);
        ResponseJson := CallRequest(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send entryNo as text, for example "NS0001".', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Invalid input: a key the type does not read, such as an item template override.
        EnableCatalogItems();
        RequestJson.Add('entryNo', 'X');
        RequestJson.Add('itemTemplateCode', 'ITEM');
        ResponseJson := CallRequest(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_NoTemplate_ReturnsPreconditionFailedAndWritesNothing()
    var
        NonstockItem: Record "Nonstock Item";
        Item: Record Item;
        ResponseJson: JsonObject;
        EntryNo: Code[20];
    begin
        // [SCENARIO AC03, AC04] Edge case: a catalog item without an item template is refused before anything is written.
        EntryNo := CreateCatalogItem(false);
        ResponseJson := CallCreate(EntryNo);
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Complete the vendor, vendor item number, unit of measure and an existing item template on the Catalog Item Card in Business Central, and send the call again.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.IsFalse(Item.Get(EntryNo), 'no item was created');
        NonstockItem.Get(EntryNo);
        Assert.AreEqual('', NonstockItem."Item No.", 'the catalog item is unchanged');
    end;

    [Test]
    procedure Create_ItemNumberTaken_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        NonstockItem: Record "Nonstock Item";
        ResponseJson: JsonObject;
        EntryNo: Code[20];
    begin
        // [SCENARIO AC04] Edge case: the number the catalog item would get already belongs to another item.
        EntryNo := CreateCatalogItem(true);
        Item.Init();
        Item."No." := EntryNo;
        Item.Insert(false);
        ResponseJson := CallCreate(EntryNo);
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual(StrSubstNo(NumberTakenMsg, EntryNo), ReadText(ResponseJson, 'error'), 'error');
        NonstockItem.Get(EntryNo);
        Assert.AreEqual('', NonstockItem."Item No.", 'the catalog item is unchanged');
    end;

    [Test]
    procedure Create_NumberSeriesWithoutLine_ReturnsBusinessCentralErrorAndWritesNothing()
    var
        NonstockItem: Record "Nonstock Item";
        Item: Record Item;
        ItemTempl: Record "Item Templ.";
        NoSeries: Record "No. Series";
        UnitOfMeasure: Record "Unit of Measure";
        Vendor: Record Vendor;
        NonstockItemSetup: Record "Nonstock Item Setup";
        SavedSetup: Record "Nonstock Item Setup";
        ResponseJson: JsonObject;
        EntryNo: Code[20];
        SeriesCode: Code[20];
        VendorNo: Code[20];
        UnitCode: Code[10];
        TemplateCode: Code[20];
        CodeText: Text;
        NextStep: Text;
        Parameter: Text;
        ItemNo: Code[20];
        ItemCountBefore: Integer;
        ItemCountAfter: Integer;
    begin
        // [SCENARIO AC04] A number series with no line passes the preflight and fails in native creation.
        // The refusal names a recovery step and leaves the catalog item and the item table unchanged.
        EntryNo := CreateCatalogItem(true);
        NonstockItem.Get(EntryNo);
        ItemTempl.Get(NonstockItem."Item Templ. Code");
        SeriesCode := CopyStr('S' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(SeriesCode));
        NoSeries.Init();
        NoSeries.Code := SeriesCode;
        NoSeries.Description := 'Catalog series without a line';
        NoSeries."Default Nos." := true;
        NoSeries."Manual Nos." := false;
        NoSeries.Insert(false);
        ItemTempl."No. Series" := SeriesCode;
        ItemTempl.Modify(false);
        NonstockItemSetup.Get();
        SavedSetup := NonstockItemSetup;
        NonstockItemSetup."No. Format" := NonstockItemSetup."No. Format"::"Item No. Series";
        NonstockItemSetup.Modify(false);
        Item.SetRange("Vendor Item No.", 'V' + EntryNo);
        ItemCountBefore := Item.Count();
        ResponseJson := CallRequest(EntryRequest(EntryNo), false);
        CodeText := ReadText(ResponseJson, 'code');
        NextStep := ReadText(ResponseJson, 'nextStep');
        Parameter := ReadText(ResponseJson, 'parameter');
        NonstockItem.Get(EntryNo);
        ItemNo := NonstockItem."Item No.";
        ItemCountAfter := Item.Count();
        VendorNo := NonstockItem."Vendor No.";
        UnitCode := NonstockItem."Unit of Measure";
        TemplateCode := NonstockItem."Item Templ. Code";
        // Message Task commits before the handler, so restore the shared setup and delete this test's
        // own rows before later tests in the codeunit see them. Codeunit isolation still rolls that
        // commit back when the codeunit ends.
        NonstockItemSetup.Get();
        NonstockItemSetup."No. Format" := SavedSetup."No. Format";
        NonstockItemSetup.Modify(false);
        if ItemNo <> '' then
            if Item.Get(ItemNo) then
                Item.Delete(true);
        NonstockItem.Delete(true);
        if ItemTempl.Get(TemplateCode) then
            ItemTempl.Delete(true);
        if Vendor.Get(VendorNo) then
            Vendor.Delete(true);
        if UnitOfMeasure.Get(UnitCode) then
            UnitOfMeasure.Delete(true);
        if NoSeries.Get(SeriesCode) then
            NoSeries.Delete(true);
        Commit();
        Assert.AreEqual('BusinessCentralError', CodeText, 'code');
        Assert.AreEqual('Read the error text, correct the cause on the Catalog Item Card in Business Central and send the call again.', NextStep, 'nextStep');
        Assert.AreNotEqual('', NextStep, 'recovery step is not blank');
        Assert.AreEqual('entryNo', Parameter, 'parameter');
        Assert.AreEqual('', ItemNo, 'the catalog item is unchanged');
        Assert.AreEqual(ItemCountBefore, ItemCountAfter, 'no item was created');
    end;

    [Test]
    procedure Create_DomainOff_ReturnsInvalidParameter()
    var
        InventorySetup: Record "Inventory Setup ori";
        Item: Record Item;
        ResponseJson: JsonObject;
        EntryNo: Code[20];
    begin
        // [SCENARIO AC04] The Catalog Items domain switch turns the type off with a coded refusal.
        EntryNo := CreateCatalogItem(true);
        InventorySetup.Get();
        InventorySetup.Validate("Catalog Items", false);
        InventorySetup.Modify(true);
        ResponseJson := CallRequest(EntryRequest(EntryNo));
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.IsFalse(Item.Get(EntryNo), 'no item was created');
    end;

    [Test]
    procedure Contract_DeclaresWriteEffectAndThreePartName()
    var
        ContractImpl: Interface "Msg Contract ori";
        Effect: JsonObject;
        Errors: JsonArray;
        MessageTypeName: Text;
    begin
        // [SCENARIO AC04, AC05] The type declares a write effect, coded refusals with a fix, and a three-part name.
        MessageTypeName := Format("Message Type ori"::"Inventory.NonstockItem.Create");
        Assert.AreEqual(3, MessageTypeName.Split('.').Count(), 'three dot-separated parts');
        ContractImpl := "Message Type ori"::"Inventory.NonstockItem.Create";
        Assert.IsTrue(ContractImpl.GetEffect(Effect), 'effect chapter');
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'effect');
        Assert.AreEqual('false', ReadText(Effect, 'posts'), 'posts');
        Assert.IsTrue(ContractImpl.GetErrors(Errors), 'errors chapter');
        Assert.AreEqual(9, Errors.Count(), 'nine documented refusals');
    end;

    [Test]
    procedure Help_IcelandicDescription()
    var
        Discovery: Interface "Msg Interface ori";
        PreviousLanguage: Integer;
        Description: Text;
    begin
        // [SCENARIO AC04] The help reads in is-IS when the session language is 1039.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Discovery := "Message Type ori"::"Inventory.NonstockItem.Create";
        Description := Discovery.GetDescription();
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Stofnar vöru úr vörulistavöru með vörusniðmáti vörulistavörunnar.', Description, 'is-IS description');
    end;

    local procedure CreateCatalogItem(WithTemplate: Boolean) EntryNo: Code[20]
    var
        NonstockItem: Record "Nonstock Item";
        NonstockItemSetup: Record "Nonstock Item Setup";
        Vendor: Record Vendor;
        UnitOfMeasure: Record "Unit of Measure";
        ItemTempl: Record "Item Templ.";
        Suffix: Text;
    begin
        EnableCatalogItems();
        if not NonstockItemSetup.Get() then begin
            NonstockItemSetup.Init();
            NonstockItemSetup.Insert(false);
        end;
        NonstockItemSetup."No. Format" := NonstockItemSetup."No. Format"::"Entry No.";
        NonstockItemSetup.Modify(false);
        Suffix := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 8);
        EntryNo := CopyStr('NS' + Suffix, 1, MaxStrLen(EntryNo));
        Vendor.Init();
        Vendor."No." := CopyStr('V' + Suffix, 1, MaxStrLen(Vendor."No."));
        Vendor.Name := 'Catalog vendor 119';
        Vendor.Insert(false);
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := CopyStr('U' + Suffix, 1, MaxStrLen(UnitOfMeasure.Code));
        UnitOfMeasure.Insert(false);
        NonstockItem.Init();
        NonstockItem."Entry No." := EntryNo;
        NonstockItem."Vendor No." := Vendor."No.";
        NonstockItem."Vendor Item No." := 'V' + EntryNo;
        NonstockItem.Description := 'Catalog chair 119';
        NonstockItem."Unit of Measure" := UnitOfMeasure.Code;
        NonstockItem."Unit Price" := 119;
        NonstockItem."Negotiated Cost" := 70;
        if WithTemplate then begin
            ItemTempl.Init();
            ItemTempl.Code := CopyStr('T' + Suffix, 1, MaxStrLen(ItemTempl.Code));
            ItemTempl.Description := 'Catalog template 119';
            ItemTempl."Shelf No." := 'SHELF119';
            ItemTempl.Insert(false);
            NonstockItem."Item Templ. Code" := ItemTempl.Code;
        end;
        NonstockItem.Insert(false);
    end;

    local procedure EnableCatalogItems()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup."Catalog Items" then
            exit;
        InventorySetup.Validate("Catalog Items", true);
        InventorySetup.Modify(true);
    end;

    local procedure EntryRequest(EntryNo: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('entryNo', EntryNo);
    end;

    local procedure CallCreate(EntryNo: Text): JsonObject
    begin
        exit(CallRequest(EntryRequest(EntryNo)));
    end;

    local procedure CallRequest(RequestJson: JsonObject) ResponseJson: JsonObject
    begin
        ResponseJson := CallRequest(RequestJson, true);
    end;

    local procedure CallRequest(RequestJson: JsonObject; OmitCommit: Boolean) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.NonstockItem.Create", '', RequestJson, OmitCommit);
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;
}
