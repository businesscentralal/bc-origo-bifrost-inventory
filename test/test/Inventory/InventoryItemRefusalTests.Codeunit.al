namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Coded refusals in en-US and is-IS: missing itemNo on Inventory.Cost.Get and
/// Inventory.TrackingAvailability.Get (#128), and the refusals that stayed English at LCID 1039
/// on Revaluation.Calculate, AssemblyOrder.Create, PhysInventory.Record and the
/// Reclassification domain gate (#126).
/// </summary>
codeunit 96930 "Inventory Item Refusal Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Assembly Order Test Helper";

    [Test]
    procedure CostGet_MissingItemNo_IsMissingParameterIn1033()
    begin
        AssertMissing("Message Type ori"::"Inventory.Cost.Get", 1033, 'itemNo is required.', 'A non-empty item number in data.itemNo or subject.', 'Send data.itemNo or the item number as subject.');
    end;

    [Test]
    procedure CostGet_MissingItemNo_IsMissingParameterIn1039()
    begin
        AssertMissing("Message Type ori"::"Inventory.Cost.Get", 1039, 'itemNo er nauðsynlegt.', 'Ótómt vörunúmer í data.itemNo eða subject.', 'Sendu data.itemNo eða vörunúmerið sem subject.');
    end;

    [Test]
    procedure TrackingGet_MissingItemNo_IsMissingParameterIn1033()
    begin
        AssertMissing("Message Type ori"::"Inventory.TrackingAvailability.Get", 1033, 'itemNo must be specified.', 'A non-empty item number in data.itemNo.', 'Send the item number in data.itemNo.');
    end;

    [Test]
    procedure TrackingGet_MissingItemNo_IsMissingParameterIn1039()
    begin
        AssertMissing("Message Type ori"::"Inventory.TrackingAvailability.Get", 1039, 'itemNo verður að vera tilgreint.', 'Ótómt vörunúmer í data.itemNo.', 'Sendu vörunúmerið í data.itemNo.');
    end;

    [Test]
    procedure TrackingGet_BlankItemNo_IsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('itemNo', '');
        Dispatch("Message Type ori"::"Inventory.TrackingAvailability.Get", RequestJson, 1033, ResponseJson);
        AssertRefusal(ResponseJson, 'MissingParameter', 'itemNo', 'itemNo must be specified.', 'Send the item number in data.itemNo.');
    end;

    [Test]
    procedure RevaluationCalculate_MissingItemNo_IsMissingParameterIn1039()
    begin
        AssertMissing("Message Type ori"::"Inventory.Revaluation.Calculate", 1039, 'itemNo verður að vera tilgreint.', 'Ótómt vörunúmer í data.itemNo.', 'Sendu vörunúmerið í data.itemNo.');
    end;

    [Test]
    procedure RevaluationCalculate_UnknownItem_IsRecordNotFoundIn1033()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('itemNo', 'ZZC-NO-ITEM');
        Dispatch("Message Type ori"::"Inventory.Revaluation.Calculate", RequestJson, 1033, ResponseJson);
        AssertRefusal(ResponseJson, 'RecordNotFound', 'itemNo', 'Item ZZC-NO-ITEM was not found.', 'Check the item number and send it again.');
    end;

    [Test]
    procedure RevaluationCalculate_UnknownItem_IsRecordNotFoundIn1039()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('itemNo', 'ZZC-NO-ITEM');
        Dispatch("Message Type ori"::"Inventory.Revaluation.Calculate", RequestJson, 1039, ResponseJson);
        AssertRefusal(ResponseJson, 'RecordNotFound', 'itemNo', 'Vara ZZC-NO-ITEM fannst ekki.', 'Athugaðu vörunúmerið og sendu það aftur.');
    end;

    [Test]
    procedure AssemblyOrderCreate_ZeroQuantity_IsIcelandicIn1039()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Item.Init();
        Item."No." := CopyStr('W8Q' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Item.Insert(true);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('quantity', 0);
        Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Create", RequestJson, 1039, ResponseJson);
        AssertRefusal(ResponseJson, 'InvalidParameter', 'quantity', 'Magn verður að vera tilgreint og stærra en 0 í JSON-beiðninni.', 'Sendu magnið sem á að setja saman í data.quantity.');
    end;

    [Test]
    procedure PhysInventoryRecord_UnknownLine_IsIcelandicIn1039()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('journalTemplateName', 'ZZC-NONE');
        RequestJson.Add('journalBatchName', 'ZZC-NONE');
        RequestJson.Add('lineNo', 999999);
        RequestJson.Add('quantity', 1);
        Dispatch("Message Type ori"::"Inventory.PhysInventory.Record", RequestJson, 1039, ResponseJson);
        AssertRefusal(ResponseJson, 'InvalidParameter', 'lineNo', 'Lína birgðatalningar fannst ekki.', 'Athugaðu journalTemplateName, journalBatchName og lineNo, eða keyrðu fyrst Inventory.PhysInventory.Calculate.');
    end;

    [Test]
    procedure ReclassificationDomainOff_NextStepIsIcelandicIn1039()
    var
        InventorySetup: Record "Inventory Setup ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        if not InventorySetup.Get() then begin
            InventorySetup.Init();
            InventorySetup.Insert();
        end;
        InventorySetup.Reclassification := false;
        InventorySetup.Modify();
        Dispatch("Message Type ori"::"Inventory.Reclassification.Post", RequestJson, 1039, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('InvalidParameter', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.AreEqual('Kveiktu á sviðinu á síðunni Uppsetning birgða.', Token.AsValue().AsText(), 'nextStep');
    end;

    local procedure AssertMissing(MessageType: Enum "Message Type ori"; LanguageId: Integer; ExpectedError: Text; ExpectedExpected: Text; ExpectedNext: Text)
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        Dispatch(MessageType, RequestJson, LanguageId, ResponseJson);
        AssertRefusal(ResponseJson, 'MissingParameter', 'itemNo', ExpectedError, ExpectedNext);
        Assert.IsTrue(ResponseJson.Get('expected', Token), 'expected missing');
        Assert.AreEqual(ExpectedExpected, Token.AsValue().AsText(), 'expected');
    end;

    [Test]
    procedure AttributeCreate_AbsentArray_1033()
    begin
        AttributeRefusal(1, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_AbsentArray_1039()
    begin
        AttributeRefusal(1, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_EmptyArray_1033()
    begin
        AttributeRefusal(2, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_EmptyArray_1039()
    begin
        AttributeRefusal(2, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_WrongArray_1033()
    begin
        AttributeRefusal(3, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_WrongArray_1039()
    begin
        AttributeRefusal(3, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_WrongElement_1033()
    begin
        AttributeRefusal(4, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_WrongElement_1039()
    begin
        AttributeRefusal(4, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_NoIdentity_1033()
    begin
        AttributeRefusal(5, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_NoIdentity_1039()
    begin
        AttributeRefusal(5, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_UnknownAttribute_1033()
    begin
        AttributeRefusal(6, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_UnknownAttribute_1039()
    begin
        AttributeRefusal(6, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_MissingOption_1033()
    begin
        AttributeRefusal(7, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_MissingOption_1039()
    begin
        AttributeRefusal(7, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_WrongType_1033()
    begin
        AttributeRefusal(8, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_WrongType_1039()
    begin
        AttributeRefusal(8, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_ConflictingIdentity_1033()
    begin
        AttributeRefusal(9, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_ConflictingIdentity_1039()
    begin
        AttributeRefusal(9, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_MappingConflict_1033()
    begin
        AttributeRefusal(10, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_MappingConflict_1039()
    begin
        AttributeRefusal(10, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_Blocked_1033()
    begin
        AttributeRefusal(11, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_Blocked_1039()
    begin
        AttributeRefusal(11, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_LaterRefusal_1033()
    begin
        AttributeRefusal(12, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_LaterRefusal_1039()
    begin
        AttributeRefusal(12, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_MissingValue_1033()
    begin
        AttributeRefusal(13, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_MissingValue_1039()
    begin
        AttributeRefusal(13, false, 1039);
    end;

    [Test]
    procedure AttributeCreate_BadValue_1033()
    begin
        AttributeRefusal(15, false, 1033);
    end;

    [Test]
    procedure AttributeCreate_BadValue_1039()
    begin
        AttributeRefusal(15, false, 1039);
    end;

    [Test]
    procedure AttributeUpdate_AbsentArray_1033()
    begin
        AttributeRefusal(1, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_AbsentArray_1039()
    begin
        AttributeRefusal(1, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_EmptyArray_1033()
    begin
        AttributeRefusal(2, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_EmptyArray_1039()
    begin
        AttributeRefusal(2, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_WrongArray_1033()
    begin
        AttributeRefusal(3, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_WrongArray_1039()
    begin
        AttributeRefusal(3, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_WrongElement_1033()
    begin
        AttributeRefusal(4, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_WrongElement_1039()
    begin
        AttributeRefusal(4, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_NoIdentity_1033()
    begin
        AttributeRefusal(5, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_NoIdentity_1039()
    begin
        AttributeRefusal(5, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_UnknownAttribute_1033()
    begin
        AttributeRefusal(6, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_UnknownAttribute_1039()
    begin
        AttributeRefusal(6, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_MissingOption_1033()
    begin
        AttributeRefusal(7, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_MissingOption_1039()
    begin
        AttributeRefusal(7, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_WrongType_1033()
    begin
        AttributeRefusal(8, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_WrongType_1039()
    begin
        AttributeRefusal(8, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_ConflictingIdentity_1033()
    begin
        AttributeRefusal(9, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_ConflictingIdentity_1039()
    begin
        AttributeRefusal(9, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_Blocked_1033()
    begin
        AttributeRefusal(11, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_Blocked_1039()
    begin
        AttributeRefusal(11, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_LaterRefusal_1033()
    begin
        AttributeRefusal(12, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_LaterRefusal_1039()
    begin
        AttributeRefusal(12, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_MissingValue_1033()
    begin
        AttributeRefusal(13, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_MissingValue_1039()
    begin
        AttributeRefusal(13, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_MissingMapping_1033()
    begin
        AttributeRefusal(14, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_MissingMapping_1039()
    begin
        AttributeRefusal(14, true, 1039);
    end;

    [Test]
    procedure AttributeUpdate_BadValue_1033()
    begin
        AttributeRefusal(15, true, 1033);
    end;

    [Test]
    procedure AttributeUpdate_BadValue_1039()
    begin
        AttributeRefusal(15, true, 1039);
    end;

    [Test]
    procedure AttributeDefinition_MissingName_1033()
    begin
        DefinitionRefusal(1, 1033);
    end;

    [Test]
    procedure AttributeDefinition_MissingName_1039()
    begin
        DefinitionRefusal(1, 1039);
    end;

    [Test]
    procedure AttributeDefinition_MissingType_1033()
    begin
        DefinitionRefusal(2, 1033);
    end;

    [Test]
    procedure AttributeDefinition_MissingType_1039()
    begin
        DefinitionRefusal(2, 1039);
    end;

    [Test]
    procedure AttributeDefinition_UnknownType_1033()
    begin
        DefinitionRefusal(3, 1033);
    end;

    [Test]
    procedure AttributeDefinition_UnknownType_1039()
    begin
        DefinitionRefusal(3, 1039);
    end;

    [Test]
    procedure AttributeDefinition_Duplicate_1033()
    begin
        DefinitionRefusal(4, 1033);
    end;

    [Test]
    procedure AttributeDefinition_Duplicate_1039()
    begin
        DefinitionRefusal(4, 1039);
    end;

    [Test]
    procedure PhysicalMissingBatch_Names_1033()
    begin
        MissingBatchRefusal(1, 1033);
    end;

    [Test]
    procedure PhysicalMissingBatch_Names_1039()
    begin
        MissingBatchRefusal(1, 1039);
    end;

    [Test]
    procedure PhysicalMissingBatch_CompoundSubject_1033()
    begin
        MissingBatchRefusal(2, 1033);
    end;

    [Test]
    procedure PhysicalMissingBatch_CompoundSubject_1039()
    begin
        MissingBatchRefusal(2, 1039);
    end;

    [Test]
    procedure PhysicalMissingBatch_SystemId_1033()
    begin
        MissingBatchRefusal(3, 1033);
    end;

    [Test]
    procedure PhysicalMissingBatch_SystemId_1039()
    begin
        MissingBatchRefusal(3, 1039);
    end;

    local procedure AttributeRefusal(Scenario: Integer; Updating: Boolean; LanguageId: Integer)
    var
        Item: Record Item;
        Attribute: Record "Item Attribute";
        OtherAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        Values: Record "Item Attribute Value";
        Library: Codeunit "Inventory Test Library ori";
        Request: JsonObject;
        Entry: JsonObject;
        Entries: JsonArray;
        Response: JsonObject;
        Token: JsonToken;
        MessageType: Enum "Message Type ori";
        OldLanguage: Integer;
        BeforeValues: Integer;
        BeforeMappings: Integer;
        ErrorCode: Text;
        ParameterName: Text;
        ErrorText: Text;
        Expected: Text;
        NextStep: Text;
    begin
        Item.Init();
        Item."No." := CopyStr('W8148' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Item."No."));
        Item.Insert(true);
        Library.CreateOptionAttribute('W8148', Attribute, ValueA, ValueB);
        Entry.Add('name', Attribute.Name);
        Entry.Add('value', 'Blue');
        if Updating and (Scenario <> 14) then begin
            Mapping."Table ID" := Database::Item;
            Mapping."No." := Item."No.";
            Mapping."Item Attribute ID" := Attribute.ID;
            Mapping."Item Attribute Value ID" := ValueA.ID;
            Mapping.Insert(true);
        end;
        ErrorCode := 'InvalidLine';
        ParameterName := 'attributes';
        ErrorText := Choose(LanguageId, 'Request data.attributes must be a non-empty array.', 'data.attributes í beiðninni verður að vera fylki sem er ekki tómt.');
        Expected := Choose(LanguageId, 'a non-empty array of attribute objects', 'fylki eigindahluta sem er ekki tómt');
        NextStep := Choose(LanguageId, 'Send at least one attribute object in data.attributes.', 'Sendu a.m.k. einn eigindahlut í data.attributes.');
        case Scenario of
            1: ;
            2: Request.Add('attributes', Entries);
            3: Request.Add('attributes', 'wrong');
            4:
                begin
                    Entries.Add('wrong');
                    ParameterName := 'attributes[1]';
                    ErrorText := Choose(LanguageId, 'Each attribute entry must be an object.', 'Hver eigindafærsla verður að vera hlutur.');
                    Expected := Choose(LanguageId, 'an attribute object', 'eigindahlutur');
                    NextStep := Choose(LanguageId, 'Send name or attributeId and a value in each attribute object.', 'Sendu name eða attributeId og gildi í hverjum eigindahlut.');
                end;
            5:
                begin
                    Entry.Remove('name');
                    ErrorCode := 'MissingParameter';
                    ParameterName := 'attributes[1].name';
                    ErrorText := Choose(LanguageId, 'An attribute name or attributeId is required.', 'Heiti eigindar eða attributeId er nauðsynlegt.');
                    IdentityRemedy(LanguageId, Expected, NextStep);
                end;
            6, 12:
                begin
                    if Scenario = 12 then begin
                        Entry.Replace('value', 'NEW-W8148');
                        Entry.Add('createValueIfMissing', true);
                        Entries.Add(Entry);
                        Clear(Entry);
                        Entry.Add('name', 'ZZTEST-NOSUCH');
                        Entry.Add('value', 'x');
                        ParameterName := 'attributes[2].name';
                    end else begin
                        Entry.Replace('name', 'ZZTEST-NOSUCH');
                        ParameterName := 'attributes[1].name';
                    end;
                    ErrorCode := 'RecordNotFound';
                    ErrorText := Choose(LanguageId, 'Item attribute "ZZTEST-NOSUCH" was not found.', 'Vörueigindin "ZZTEST-NOSUCH" fannst ekki.');
                    IdentityRemedy(LanguageId, Expected, NextStep);
                end;
            7:
                begin
                    Entry.Replace('value', 'UNKNOWN-W8148');
                    ErrorCode := 'RecordNotFound';
                    ParameterName := 'attributes[1].value';
                    ErrorText := StrSubstNo(Choose(LanguageId, 'Option value "UNKNOWN-W8148" was not found for attribute "%1". Pass createValueIfMissing: true to create it.', 'Valkostsgildið "UNKNOWN-W8148" fannst ekki fyrir eigindina "%1". Sendu createValueIfMissing: true til að stofna það.'), Attribute.Name);
                    Expected := Choose(LanguageId, 'a value matching the attribute type', 'gildi sem passar við gerð eigindar');
                    NextStep := Choose(LanguageId, 'Send an existing option value or set createValueIfMissing true on this attribute.', 'Sendu fyrirliggjandi valkostsgildi eða stilltu createValueIfMissing true á þessari eigind.');
                end;
            8:
                begin
                    Entry.Add('type', 'Date');
                    ErrorCode := 'InvalidParameter';
                    ParameterName := 'attributes[1].type';
                    ErrorText := StrSubstNo(Choose(LanguageId, 'Attribute "%1" has type Option; request type Date does not match.', 'Eigindin "%1" er af gerðinni Option; gerðin Date í beiðninni passar ekki.'), Attribute.Name);
                    ValueRemedy(LanguageId, Expected, NextStep);
                end;
            9:
                begin
                    Library.CreateOptionAttribute('OTHER-W8148', OtherAttribute, ValueA, ValueB);
                    Entry.Add('attributeId', OtherAttribute.ID);
                    ErrorCode := 'ConflictingIdentifiers';
                    ParameterName := 'attributes[1].attributeId';
                    ErrorText := Choose(LanguageId, 'attributeId and name identify different attributes.', 'attributeId og name auðkenna ólíkar eigindir.');
                    Expected := Choose(LanguageId, 'an existing attribute name or attributeId', 'heiti fyrirliggjandi eigindar eða attributeId');
                    NextStep := Choose(LanguageId, 'Send one identifier or identifiers for the same attribute.', 'Sendu eitt auðkenni eða auðkenni sömu eigindar.');
                end;
            10:
                begin
                    Mapping."Table ID" := Database::Item;
                    Mapping."No." := Item."No.";
                    Mapping."Item Attribute ID" := Attribute.ID;
                    Mapping."Item Attribute Value ID" := ValueB.ID;
                    Mapping.Insert(true);
                    ErrorCode := 'PreconditionFailed';
                    ParameterName := 'attributes[1].overwrite';
                    ErrorText := StrSubstNo(Choose(LanguageId, 'Item "%1" already has attribute "%2" with a different value. Pass overwrite: true or use Inventory.Attribute.Update.', 'Varan "%1" hefur þegar eigindina "%2" með öðru gildi. Sendu overwrite: true eða notaðu Inventory.Attribute.Update.'), Item."No.", Attribute.Name);
                    Expected := Choose(LanguageId, 'the existing value or overwrite true', 'fyrirliggjandi gildi eða overwrite true');
                    NextStep := Choose(LanguageId, 'Set overwrite true on this attribute or use Inventory.Attribute.Update.', 'Stilltu overwrite true á þessari eigind eða notaðu Inventory.Attribute.Update.');
                end;
            11:
                begin
                    Item.Blocked := true;
                    Item.Modify(true);
                    ErrorCode := 'PreconditionFailed';
                    ParameterName := 'allowBlocked';
                    ErrorText := StrSubstNo(Choose(LanguageId, 'Item "%1" is blocked. Pass allowBlocked: true to override.', 'Varan "%1" er lokuð. Sendu allowBlocked: true til að leyfa breytinguna.'), Item."No.");
                    Expected := Choose(LanguageId, 'an unblocked item or allowBlocked true', 'ólokuð vara eða allowBlocked true');
                    NextStep := Choose(LanguageId, 'Unblock the item or send allowBlocked true for an intentional write.', 'Opnaðu vöruna eða sendu allowBlocked true fyrir fyrirhugaða breytingu.');
                end;
            13, 15:
                begin
                    if Scenario = 13 then begin
                        Entry.Remove('value');
                        ErrorCode := 'MissingParameter';
                    end else begin
                        Entry.Replace('value', '');
                        ErrorCode := 'InvalidParameter';
                    end;
                    ParameterName := 'attributes[1].value';
                    ErrorText := StrSubstNo(Choose(LanguageId, 'A value is required for attribute "%1".', 'Gildi er nauðsynlegt fyrir eigindina "%1".'), Attribute.Name);
                    ValueRemedy(LanguageId, Expected, NextStep);
                end;
            14:
                begin
                    ErrorCode := 'RecordNotFound';
                    ParameterName := 'attributes[1].name';
                    ErrorText := StrSubstNo(Choose(LanguageId, 'Item "%1" has no mapping for attribute "%2". Use Inventory.Attribute.Create first.', 'Varan "%1" hefur enga tengingu við eigindina "%2". Notaðu Inventory.Attribute.Create fyrst.'), Item."No.", Attribute.Name);
                    Expected := Choose(LanguageId, 'an existing item attribute mapping', 'fyrirliggjandi tenging vörueigindar');
                    NextStep := Choose(LanguageId, 'Create the mapping with Inventory.Attribute.Create first.', 'Stofnaðu tenginguna fyrst með Inventory.Attribute.Create.');
                end;
        end;
        if Scenario > 4 then
            Entries.Add(Entry);
        if Scenario >= 4 then
            Request.Add('attributes', Entries);
        BeforeValues := Values.Count();
        BeforeMappings := Mapping.Count();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        MessageType := MessageType::"Inventory.Attribute.Create";
        if Updating then
            MessageType := MessageType::"Inventory.Attribute.Update";
        Helper.ProcessMessage(MessageType, Item."No.", Request, Response);
        GlobalLanguage(OldLanguage);
        AssertRefusal(Response, ErrorCode, ParameterName, ErrorText, NextStep);
        Assert.IsTrue(Response.Get('expected', Token), 'Expected is present.');
        Assert.AreEqual(Expected, Token.AsValue().AsText(), 'Full expected text.');
        Assert.AreEqual(BeforeValues, Values.Count(), 'A refused call creates no value.');
        Assert.AreEqual(BeforeMappings, Mapping.Count(), 'A refused call creates no mapping.');
        if Updating and (Scenario <> 14) then begin
            Mapping.Get(Database::Item, Item."No.", Attribute.ID);
            Values.Get(Attribute.ID, Mapping."Item Attribute Value ID");
            Assert.AreEqual('Blue', Values.Value, 'Refusal preserves the existing mapping value.');
        end;
    end;

    local procedure DefinitionRefusal(Scenario: Integer; LanguageId: Integer)
    var
        Attribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Library: Codeunit "Inventory Test Library ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ErrorCode: Text;
        ParameterName: Text;
        ErrorText: Text;
        Expected: Text;
        NextStep: Text;
        OldLanguage: Integer;
        BeforeCount: Integer;
    begin
        Library.CreateOptionAttribute('DEF-W8148', Attribute, ValueA, ValueB);
        ErrorCode := 'MissingParameter';
        ParameterName := 'name';
        ErrorText := Choose(LanguageId, 'name is required.', 'name er nauðsynlegt.');
        Expected := Choose(LanguageId, 'A JSON string of at most 250 characters.', 'JSON-strengur með að hámarki 250 stöfum.');
        NextStep := Choose(LanguageId, 'Send name as text in the documented format.', 'Sendu name sem texta á skjalfestu sniði.');
        case Scenario of
            1:
                Request.Add('type', 'Text');
            4:
                Request.Add('name', Attribute.Name);
            else
                Request.Add('name', 'NEW-W8148');
        end;
        case Scenario of
            2, 3:
                begin
                    ParameterName := 'type';
                    ErrorText := Choose(LanguageId, 'type is required.', 'type er nauðsynlegt.');
                    Expected := Choose(LanguageId, 'A JSON string of at most 20 characters.', 'JSON-strengur með að hámarki 20 stöfum.');
                    NextStep := Choose(LanguageId, 'Send type as text in the documented format.', 'Sendu type sem texta á skjalfestu sniði.');
                    if Scenario = 3 then begin
                        Request.Add('type', 'Unknown');
                        ErrorCode := 'InvalidParameter';
                        Expected := Choose(LanguageId, 'Option, Text, Integer, Decimal or Date.', 'Option, Text, Integer, Decimal eða Date.');
                        NextStep := Choose(LanguageId, 'Send one documented attribute type name in type.', 'Sendu eitt skjalfest heiti gerðar eiginleika í type.');
                        ErrorText := Choose(LanguageId, 'Unknown attribute type Unknown.', 'Óþekkt gerð eiginleika Unknown.');
                    end;
                end;
            4:
                begin
                    Request.Add('type', 'Option');
                    ErrorCode := 'PreconditionFailed';
                    Expected := Choose(LanguageId, 'A unique attribute name.', 'Einkvæmt heiti eiginleika.');
                    NextStep := Choose(LanguageId, 'Read existing attributes and choose a new name or use the existing definition.', 'Lestu eiginleika sem eru til og veldu nýtt heiti eða notaðu fyrirliggjandi skilgreiningu.');
                    ErrorText := StrSubstNo(Choose(LanguageId, 'Attribute %1 already exists.', 'Eiginleikinn %1 er þegar til.'), Attribute.Name);
                end;
        end;
        BeforeCount := Attribute.Count();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.AttributeDefinition.Create", Request, Response);
        GlobalLanguage(OldLanguage);
        AssertRefusal(Response, ErrorCode, ParameterName, ErrorText, NextStep);
        Response.Get('expected', Token);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), 'Full expectation.');
        Assert.AreEqual(BeforeCount, Attribute.Count(), 'No definition written on refusal.');
    end;

    local procedure MissingBatchRefusal(Selector: Integer; LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Journal: Codeunit "Inventory Native Journal ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Identifier: Text;
        ParameterName: Text;
        OldLanguage: Integer;
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        Identifier := 'ZZW8148|NONE';
        ParameterName := 'subject';
        case Selector of
            1:
                begin
                    ParameterName := 'batchName';
                    Request.Add('templateName', 'ZZW8148');
                    Request.Add('batchName', 'NONE');
                end;
            2: TempArgument.Subject := CopyStr(Identifier, 1, MaxStrLen(TempArgument.Subject));
            3:
                begin
                    Identifier := Format(CreateGuid());
                    TempArgument.Subject := CopyStr(Identifier, 1, MaxStrLen(TempArgument.Subject));
                end;
        end;
        TempArgument.SetRequestJson(Request);
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Journal.RecordCount(TempArgument);
        GlobalLanguage(OldLanguage);
        Response := TempArgument.GetResponseJson();
        AssertRefusal(Response, 'RecordNotFound', ParameterName,
            StrSubstNo(Choose(LanguageId, 'Journal batch %1 was not found.', 'Bókarkeyrslan %1 fannst ekki.'), Identifier),
            Choose(LanguageId, 'Check the template and batch names or send the SystemId of an existing physical inventory batch.', 'Athugaðu heiti sniðmáts og keyrslu eða sendu SystemId fyrirliggjandi birgðatalningarkeyrslu.'));
        Response.Get('expected', Token);
        Assert.AreEqual(Choose(LanguageId, 'an existing physical inventory journal batch', 'fyrirliggjandi birgðatalningarbókarkeyrsla'), Token.AsValue().AsText(), 'Full expectation.');
        Response.Get('received', Token);
        Assert.AreEqual(Identifier, Token.AsValue().AsText(), 'Exact missing selector.');
    end;

    local procedure Choose(LanguageId: Integer; English: Text; Icelandic: Text): Text
    begin
        if LanguageId = 1039 then
            exit(Icelandic);
        exit(English);
    end;

    local procedure IdentityRemedy(LanguageId: Integer; var Expected: Text; var NextStep: Text)
    begin
        Expected := Choose(LanguageId, 'an existing attribute name or attributeId', 'heiti fyrirliggjandi eigindar eða attributeId');
        NextStep := Choose(LanguageId, 'Send an existing attribute or create it with Inventory.AttributeDefinition.Create.', 'Sendu fyrirliggjandi eigind eða stofnaðu hana með Inventory.AttributeDefinition.Create.');
    end;

    local procedure ValueRemedy(LanguageId: Integer; var Expected: Text; var NextStep: Text)
    begin
        Expected := Choose(LanguageId, 'a value matching the attribute type', 'gildi sem passar við gerð eigindar');
        NextStep := Choose(LanguageId, 'Send value, numericValue or dateValue matching the attribute type.', 'Sendu value, numericValue eða dateValue sem passar við gerð eigindar.');
    end;

    [Test]
    procedure HelpRuntime_ReclassificationCheck_1033()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.Reclassification.Check", 'MissingParameter', 1033);
    end;

    [Test]
    procedure HelpRuntime_ReclassificationCheck_1039()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.Reclassification.Check", 'MissingParameter', 1039);
    end;

    [Test]
    procedure HelpRuntime_ReclassificationPost_1033()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.Reclassification.Post", 'MissingParameter', 1033);
    end;

    [Test]
    procedure HelpRuntime_ReclassificationPost_1039()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.Reclassification.Post", 'MissingParameter', 1039);
    end;

    [Test]
    procedure HelpRuntime_ReclassificationPreviewPost_1033()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'MissingParameter', 1033);
    end;

    [Test]
    procedure HelpRuntime_ReclassificationPreviewPost_1039()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'MissingParameter', 1039);
    end;

    [Test]
    procedure HelpRuntime_ItemApplicationUnapply_1033()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.ItemApplication.Unapply", 'MissingParameter', 1033);
    end;

    [Test]
    procedure HelpRuntime_ItemApplicationUnapply_1039()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.ItemApplication.Unapply", 'MissingParameter', 1039);
    end;

    [Test]
    procedure HelpRuntime_ItemApplicationReapply_1033()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.ItemApplication.Reapply", 'MissingParameter', 1033);
    end;

    [Test]
    procedure HelpRuntime_ItemApplicationReapply_1039()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.ItemApplication.Reapply", 'MissingParameter', 1039);
    end;

    [Test]
    procedure HelpRuntime_ItemApplicationGet_1033()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.ItemApplication.Get", 'MissingParameter', 1033);
    end;

    [Test]
    procedure HelpRuntime_ItemApplicationGet_1039()
    begin
        AssertOlderHelpRuntime("Message Type ori"::"Inventory.ItemApplication.Get", 'MissingParameter', 1039);
    end;

    local procedure AssertOlderHelpRuntime(MessageType: Enum "Message Type ori"; ExpectedCode: Text; LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        Library: Codeunit "Inventory Test Library ori";
        Contract: Interface "Msg Contract ori";
        Request: JsonObject;
        Response: JsonObject;
        Entry: JsonObject;
        Errors: JsonArray;
        Examples: JsonArray;
        Token: JsonToken;
        Value: JsonToken;
        FoundCode: Boolean;
        OldLanguage: Integer;
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup.Reclassification := true;
        Setup."Item Application" := true;
        Setup.Modify(true);
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage(MessageType, Request, Response);
        GlobalLanguage(OldLanguage);
        Library.AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual(ExpectedCode, Token.AsValue().AsText(), 'Actual retained runtime refusal.');
        Contract := MessageType;
        Assert.IsTrue(Contract.GetErrors(Errors), 'Errors chapter exists.');
        foreach Token in Errors do begin
            Entry := Token.AsObject();
            Assert.IsTrue(Entry.Get('code', Value), 'Each help error has a code.');
            if Value.AsValue().AsText() = ExpectedCode then
                FoundCode := true;
            Assert.IsTrue(Entry.Get('fix', Value), 'Each help error has a fix.');
            Assert.AreNotEqual('', Value.AsValue().AsText(), 'The fix is actionable.');
        end;
        Assert.IsTrue(FoundCode, 'Help declares the actual refusal code.');
        Assert.IsTrue(Contract.GetExamples(Examples), 'Examples chapter exists.');
        Assert.IsTrue(Examples.Count() > 0, 'At least one example.');
    end;

    [Test]
    procedure Unapply_Missing_1033()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Unapply", 'Missing', 1033);
    end;

    [Test]
    procedure Unapply_Missing_1039()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Unapply", 'Missing', 1039);
    end;

    [Test]
    procedure Unapply_Format_1033()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Unapply", 'Format', 1033);
    end;

    [Test]
    procedure Unapply_Format_1039()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Unapply", 'Format', 1039);
    end;

    [Test]
    procedure Unapply_NotFound_1033()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Unapply", 'NotFound', 1033);
    end;

    [Test]
    procedure Unapply_NotFound_1039()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Unapply", 'NotFound', 1039);
    end;

    [Test]
    procedure Reapply_Missing_1033()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Reapply", 'Missing', 1033);
    end;

    [Test]
    procedure Reapply_Missing_1039()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Reapply", 'Missing', 1039);
    end;

    [Test]
    procedure Reapply_Format_1033()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Reapply", 'Format', 1033);
    end;

    [Test]
    procedure Reapply_Format_1039()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Reapply", 'Format', 1039);
    end;

    [Test]
    procedure Reapply_NotFound_1033()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Reapply", 'NotFound', 1033);
    end;

    [Test]
    procedure Reapply_NotFound_1039()
    begin
        ApplicationRefusal("Message Type ori"::"Inventory.ItemApplication.Reapply", 'NotFound', 1039);
    end;

    local procedure ApplicationRefusal(MessageType: Enum "Message Type ori"; Scenario: Text; LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        ApplicationEntry: Record "Item Application Entry";
        LedgerEntry: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Contract: Interface "Msg Contract ori";
        Errors: JsonArray;
        Token: JsonToken;
        Value: JsonToken;
        ParameterName: Text;
        ErrorCode: Text;
        ErrorText: Text;
        NextStep: Text;
        Declared: Boolean;
        BeforeApplications: Integer;
        BeforeLedger: Integer;
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup."Item Application" := true;
        Setup.Modify(true);
        Assert.IsFalse(ApplicationEntry.Get(2147483000), 'Missing application sentinel must not exist.');
        Assert.IsFalse(LedgerEntry.Get(2147483000), 'Missing ledger sentinel must not exist.');
        ParameterName := 'entryNo';
        if MessageType = "Message Type ori"::"Inventory.ItemApplication.Reapply" then begin
            ParameterName := 'itemLedgerEntryNo';
            Request.Add('applyToEntryNo', 2147483000);
        end;
        ErrorCode := 'MissingParameter';
        ErrorText := StrSubstNo(Choose(LanguageId, '%1 is required.', '%1 er nauðsynlegt.'), ParameterName);
        NextStep := StrSubstNo(Choose(LanguageId, 'Send %1 as a JSON integer from Inventory.ItemApplication.Get.', 'Sendu %1 sem JSON-heiltölu úr Inventory.ItemApplication.Get.'), ParameterName);
        if Scenario = 'Format' then begin
            Request.Add(ParameterName, 'not-an-integer');
            ErrorCode := 'InvalidParameterFormat';
            ErrorText := StrSubstNo(Choose(LanguageId, '%1 must be a JSON integer.', '%1 verður að vera JSON-heiltala.'), ParameterName);
        end;
        if Scenario = 'NotFound' then begin
            Request.Add(ParameterName, 2147483000);
            ErrorCode := 'RecordNotFound';
            if MessageType = "Message Type ori"::"Inventory.ItemApplication.Unapply" then
                ErrorText := Choose(LanguageId, 'Item application entry 2147483000 was not found.', 'Vörujöfnunarfærsla 2147483000 fannst ekki.')
            else
                ErrorText := Choose(LanguageId, 'Item ledger entry 2147483000 was not found.', 'Vörufærsla 2147483000 fannst ekki.');
            NextStep := Choose(LanguageId, 'Read Inventory.ItemApplication.Get and send the entry number of an existing record.', 'Lestu Inventory.ItemApplication.Get og sendu færslunúmer fyrirliggjandi færslu.');
        end;
        BeforeApplications := ApplicationEntry.Count();
        BeforeLedger := LedgerEntry.Count();
        Dispatch(MessageType, Request, LanguageId, Response);
        AssertRefusal(Response, ErrorCode, ParameterName, ErrorText, NextStep);
        Assert.AreEqual(BeforeApplications, ApplicationEntry.Count(), 'No application mutation on refusal.');
        Assert.AreEqual(BeforeLedger, LedgerEntry.Count(), 'No ledger mutation on refusal.');
        Contract := MessageType;
        Contract.GetErrors(Errors);
        foreach Token in Errors do begin
            Assert.IsTrue(Token.AsObject().Get('code', Value), 'Every declared error is coded.');
            Declared := Declared or (Value.AsValue().AsText() = ErrorCode);
        end;
        Assert.IsTrue(Declared, 'Actual refusal is declared by help.');
    end;

    [Test]
    procedure ReclassCheck_MissingTemplate_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'MissingTemplate', 1033);
    end;

    [Test]
    procedure ReclassCheck_MissingTemplate_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'MissingTemplate', 1039);
    end;

    [Test]
    procedure ReclassCheck_WrongTemplate_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'WrongTemplate', 1033);
    end;

    [Test]
    procedure ReclassCheck_WrongTemplate_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'WrongTemplate', 1039);
    end;

    [Test]
    procedure ReclassCheck_Format_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'Format', 1033);
    end;

    [Test]
    procedure ReclassCheck_Format_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'Format', 1039);
    end;

    [Test]
    procedure ReclassCheck_LongName_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'LongName', 1033);
    end;

    [Test]
    procedure ReclassCheck_LongName_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.Check", 'LongName', 1039);
    end;

    [Test]
    procedure ReclassPreviewPost_MissingTemplate_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'MissingTemplate', 1033);
    end;

    [Test]
    procedure ReclassPreviewPost_MissingTemplate_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'MissingTemplate', 1039);
    end;

    [Test]
    procedure ReclassPreviewPost_WrongTemplate_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'WrongTemplate', 1033);
    end;

    [Test]
    procedure ReclassPreviewPost_WrongTemplate_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'WrongTemplate', 1039);
    end;

    [Test]
    procedure ReclassPreviewPost_Format_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'Format', 1033);
    end;

    [Test]
    procedure ReclassPreviewPost_Format_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'Format', 1039);
    end;

    [Test]
    procedure ReclassPreviewPost_LongName_1033()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'LongName', 1033);
    end;

    [Test]
    procedure ReclassPreviewPost_LongName_1039()
    begin
        ReclassRefusal("Message Type ori"::"Inventory.Reclassification.PreviewPost", 'LongName', 1039);
    end;

    local procedure ReclassRefusal(MessageType: Enum "Message Type ori"; Scenario: Text; LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Request: JsonObject;
        Response: JsonObject;
        Contract: Interface "Msg Contract ori";
        Errors: JsonArray;
        Token: JsonToken;
        Value: JsonToken;
        TemplateKey: Text;
        BatchKey: Text;
        ErrorCode: Text;
        ErrorText: Text;
        NextStep: Text;
        Declared: Boolean;
        WrongTemplateName: Code[10];
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup.Reclassification := true;
        Setup.Modify(true);
        TemplateKey := 'templateName';
        BatchKey := 'batchName';
        if MessageType = "Message Type ori"::"Inventory.Reclassification.PreviewPost" then begin
            TemplateKey := 'journalTemplateName';
            BatchKey := 'journalBatchName';
        end;
        Assert.IsFalse(JournalTemplate.Get('W8-NONE'), 'Missing template sentinel must not exist.');
        Request.Add(BatchKey, 'OWNED');
        ErrorCode := 'RecordNotFound';
        ErrorText := Choose(LanguageId, 'Item journal template W8-NONE was not found.', 'Vörubókarsniðmát W8-NONE fannst ekki.');
        NextStep := Choose(LanguageId, 'Send templateName and batchName for an existing Transfer journal template.', 'Sendu templateName og batchName fyrir fyrirliggjandi millifærslubókarsniðmát.');
        if Scenario = 'MissingTemplate' then
            Request.Add(TemplateKey, 'W8-NONE');
        if Scenario = 'WrongTemplate' then begin
            JournalTemplate.Init();
            WrongTemplateName := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 10);
            JournalTemplate.Name := WrongTemplateName;
            JournalTemplate.Type := JournalTemplate.Type::Item;
            JournalTemplate.Insert(true);
            Batch.Init();
            Batch."Journal Template Name" := JournalTemplate.Name;
            Batch.Name := 'OWNED';
            Batch.Insert(true);
            Request.Add(TemplateKey, JournalTemplate.Name);
            ErrorCode := 'PreconditionFailed';
            ErrorText := StrSubstNo(Choose(LanguageId, 'Template %1 is not a reclassification template.', 'Sniðmát %1 er ekki endurflokkunarsniðmát.'), WrongTemplateName);
        end;
        if MessageType = "Message Type ori"::"Inventory.Reclassification.PreviewPost" then begin
            NextStep := Choose(LanguageId, 'Choose an existing Transfer journal batch and correct its posting errors before retrying.', 'Veldu fyrirliggjandi millifærslubókarkeyrslu og leiðréttu bókunarvillur áður en reynt er aftur.');
            if Scenario = 'MissingTemplate' then
                ErrorText := Choose(LanguageId, 'Reclassification journal template or batch was not found.', 'Endurflokkunarbókarsniðmát eða keyrsla fannst ekki.')
            else
                ErrorText := StrSubstNo(Choose(LanguageId, 'Journal template %1 is not a Transfer template.', 'Bókarsniðmátið %1 er ekki af gerðinni Transfer.'), WrongTemplateName);
        end;
        if Scenario in ['Format', 'LongName'] then begin
            if Scenario = 'Format' then begin
                Request.Add(TemplateKey, 12);
                ErrorCode := 'InvalidParameterFormat';
            end else begin
                Request.Add(TemplateKey, '12345678901');
                ErrorCode := 'InvalidParameter';
            end;
            ErrorText := StrSubstNo(Choose(LanguageId, '%1 must be text of at most 10 characters.', '%1 verður að vera texti með að hámarki 10 stöfum.'), TemplateKey);
            NextStep := StrSubstNo(Choose(LanguageId, 'Send %1 as text in the documented format.', 'Sendu %1 sem texta á skjalfestu sniði.'), TemplateKey);
        end;
        Dispatch(MessageType, Request, LanguageId, Response);
        if (MessageType = "Message Type ori"::"Inventory.Reclassification.PreviewPost") and (Scenario = 'MissingTemplate') then
            AssertRefusal(Response, ErrorCode, BatchKey, ErrorText, NextStep)
        else
            AssertRefusal(Response, ErrorCode, TemplateKey, ErrorText, NextStep);
        Contract := MessageType;
        Contract.GetErrors(Errors);
        foreach Token in Errors do begin
            Assert.IsTrue(Token.AsObject().Get('code', Value), 'Every declared error is coded.');
            Declared := Declared or (Value.AsValue().AsText() = ErrorCode);
        end;
        Assert.IsTrue(Declared, 'Actual refusal is declared by help.');
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; RequestJson: JsonObject; LanguageId: Integer; var ResponseJson: JsonObject)
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage(MessageType, RequestJson, ResponseJson);
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertRefusal(ResponseJson: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; ExpectedError: Text; ExpectedNext: Text)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'status');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual(ExpectedCode, Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        Assert.AreEqual(ExpectedParameter, Token.AsValue().AsText(), 'parameter');
        Assert.IsTrue(ResponseJson.Get('error', Token), 'error missing');
        Assert.AreEqual(ExpectedError, Token.AsValue().AsText(), 'error');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.AreEqual(ExpectedNext, Token.AsValue().AsText(), 'nextStep');
    end;
}
