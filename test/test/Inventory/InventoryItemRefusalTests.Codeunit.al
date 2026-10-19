namespace Origo.Bifrost.Inventory.Test;

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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('itemNo', 'ZZC-ASM');
        RequestJson.Add('quantity', 0);
        Dispatch("Message Type ori"::"Inventory.AssemblyOrder.Create", RequestJson, 1039, ResponseJson);
        AssertRefusal(ResponseJson, 'MissingParameter', 'quantity', 'Magn verður að vera tilgreint og stærra en 0 í JSON-beiðninni.', 'Sendu magnið sem á að setja saman í data.quantity.');
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
