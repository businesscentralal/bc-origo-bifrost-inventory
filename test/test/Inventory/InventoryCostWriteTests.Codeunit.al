namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Intentional native cost validation, refusals and field restrictions with isolated Item fixtures.</summary>
codeunit 96937 "Inventory Cost Write Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        CostWrite: Codeunit "Inventory Card Write ori";

    [Test]
    procedure UpdateCost_OmitCommit_PropagatesAndRollsBack()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Impl: Codeunit "Cost Update Impl ori";
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        PreviousDescription: Text;
        PreviousCost: Decimal;
    begin
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousDescription := Item.Description;
        PreviousCost := Item."Last Direct Cost";
        Request.Add('lastDirectCost', 99);
        InitArgument(TempArgument, Item."No.", Request);
        TempArgument."Omit Commit" := true;
        Observer.SetItem(Item."No.", true);
        BindSubscription(Observer);
        Commit();
        Item.Description := 'Uncommitted caller change';
        Item.Modify(false);
        asserterror Impl.ExecuteBifrostTask(TempArgument);
        Assert.ExpectedError('Owned native cost validation failure');
        UnbindSubscription(Observer);
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousDescription, Item.Description, 'Caller and subscriber writes roll back together.');
        Assert.AreEqual(PreviousCost, Item."Last Direct Cost", 'Cost write rolls back.');
    end;

    /// <summary>FIFO supports native card changes and truthful before/after.</summary>
    [Test]
    procedure Scenario_AC07_FIFO_ValidatesCosts()
    var
        Item: Record Item;
    begin
        // Story #4 AC7 | Time: independent | Risk: no inventory revaluation claim.
        VerifyWrite(Item."Costing Method"::FIFO);
    end;

    /// <summary>LIFO supports native card changes and truthful before/after.</summary>
    [Test]
    procedure Scenario_AC07_LIFO_ValidatesCosts()
    var
        Item: Record Item;
    begin
        // Story #4 AC7 | Time: independent | Risk: no inventory revaluation claim.
        VerifyWrite(Item."Costing Method"::LIFO);
    end;

    /// <summary>Average supports native card changes and truthful before/after.</summary>
    [Test]
    procedure Scenario_AC07_Average_ValidatesCosts()
    var
        Item: Record Item;
    begin
        // Story #4 AC7 | Time: independent | Risk: no inventory revaluation claim.
        VerifyWrite(Item."Costing Method"::Average);
    end;

    /// <summary>Specific supports native card changes and truthful before/after.</summary>
    [Test]
    procedure Scenario_AC07_Specific_ValidatesCosts()
    var
        Item: Record Item;
    begin
        // Story #4 AC7 | Time: independent | Risk: no inventory revaluation claim.
        VerifyWrite(Item."Costing Method"::Specific);
    end;

    /// <summary>The accepted Standard-costed hard refusal applies even to Last Direct Cost alone.</summary>
    [Test]
    procedure Scenario_AC08_Standard_RefusesWithoutChangingItem()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        PreviousCost: Decimal;
    begin
        // Story #4 AC8, decision5638426410 | Time: independent | Risk: never silently revalue a Standard Item.
        CreateItem(Item, Item."Costing Method"::Standard);
        PreviousCost := Item."Last Direct Cost";
        Request.Add('lastDirectCost', 99);
        InitArgument(TempArgument, Item."No.", Request);
        Commit(); // Preserve the owned fixture across the expected transaction rollback.
        asserterror CostWrite.UpdateCost(TempArgument);
        Assert.ExpectedError('Inventory.Revaluation.Post');
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousCost, Item."Last Direct Cost", 'Refusal does not write a card cost.');
    end;

    /// <summary>A blocked item refuses without explicit opt-in; the same intended request works with it.</summary>
    [Test]
    procedure Scenario_AC09_Blocked_RequiresExplicitOptIn()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        PreviousCost: Decimal;
    begin
        // Story #4 AC9 | Time: independent | Risk: blocked-item opt-in does not bypass other guards.
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousCost := Item."Unit Cost";
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Request.Add('unitCost', 18);
        InitArgument(TempArgument, Item."No.", Request);
        Commit(); // Preserve the owned fixture across the expected transaction rollback.
        asserterror CostWrite.UpdateCost(TempArgument);
        Assert.ExpectedError('blocked');
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousCost, Item."Unit Cost", 'Blocked refusal preserves cost.');
        Request.Add('allowBlocked', true);
        InitArgument(TempArgument, Item."No.", Request);
        CostWrite.UpdateCost(TempArgument);
        Item.Get(Item."No.");
        Assert.AreEqual(18, Item."Unit Cost", 'Explicit opt-in permits native validation.');
    end;

    /// <summary>Method mismatch is checked before any field validation.</summary>
    [Test]
    procedure UpdateCost_MethodMismatch_PreservesItem()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        PreviousCost: Decimal;
    begin
        // Story #4 AC7 optimistic guard | Time: independent | Risk: stale integration assumptions.
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousCost := Item."Unit Cost";
        Request.Add('unitCost', 99);
        Request.Add('expectedCostingMethod', 'Average');
        InitArgument(TempArgument, Item."No.", Request);
        Commit(); // Preserve the owned fixture across the expected transaction rollback.
        asserterror CostWrite.UpdateCost(TempArgument);
        Assert.ExpectedError('expectedCostingMethod');
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousCost, Item."Unit Cost", 'Method refusal precedes modification.');
    end;

    /// <summary>One restricted supplied field refuses all supplied cost changes.</summary>
    [Test]
    procedure UpdateCost_RestrictedField_PreservesAllFields()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        FieldAccess: TestPage "Field Accesses ori";
        Request: JsonObject;
        PreviousCost: Decimal;
    begin
        // Story #4 field permission | Time: independent | Risk: no partial write before last field check.
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousCost := Item."Unit Cost";
        FieldAccess.OpenEdit();
        FieldAccess.CurrentUserName.SetValue(UserId());
        FieldAccess.New();
        FieldAccess."Table No.".SetValue(Database::Item);
        FieldAccess."Field No.".SetValue(Item.FieldNo("Last Direct Cost"));
        FieldAccess."Restriction Type".SetValue('Write');
        FieldAccess.Close();
        Request.Add('unitCost', 99);
        Request.Add('lastDirectCost', 88);
        InitArgument(TempArgument, Item."No.", Request);
        Commit(); // Preserve the owned fixture across the expected transaction rollback.
        asserterror CostWrite.UpdateCost(TempArgument);
        Assert.ExpectedError('Permission denied');
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousCost, Item."Unit Cost", 'Another permitted field is not written first.');
        FieldAccess.OpenEdit();
        FieldAccess.CurrentUserName.SetValue(UserId());
        FieldAccess.Filter.SetFilter("Table No.", Format(Database::Item));
        FieldAccess.Filter.SetFilter("Field No.", Format(Item.FieldNo("Last Direct Cost")));
        Assert.IsTrue(FieldAccess.First(), 'Find the self-created field restriction for cleanup.');
        FieldAccess."Restriction Type".SetValue('None');
        FieldAccess.Close();
    end;

    /// <summary>Missing selection cannot turn a card update into an all-items operation.</summary>
    [Test]
    procedure UpdateCost_NoSelection_Refuses()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #4 write safety | Time: independent | Risk: no broad default for writes.
        Request.Add('unitCost', 1);
        InitArgument(TempArgument, '', Request);
        Commit(); // Preserve the owned fixture across the expected transaction rollback.
        asserterror CostWrite.UpdateCost(TempArgument);
        Assert.ExpectedError('exactly one item');
    end;

    /// <summary>Null is not silently coerced into a zero-cost write.</summary>
    [Test]
    procedure UpdateCost_NullCost_ReturnsErrorWithoutWrite()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        PreviousCost: Decimal;
    begin
        // Story #4 parameter safety | Time: independent | Risk: null must not erase financial cost.
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousCost := Item."Unit Cost";
        Request.ReadFrom('{"unitCost":null}');
        InitArgument(TempArgument, Item."No.", Request);
        CostWrite.UpdateCost(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Required cost value refuses null.');
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousCost, Item."Unit Cost", 'Invalid request cannot erase the cost.');
    end;

    /// <summary>Dedicated field hints and table-level availability remain scoped to Item costs/price.</summary>
    [Test]
    procedure Scenario_AC10_FieldHints_LeaveUnrelatedTablesAvailable()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
    begin
        // Story #4 AC10 partial native boundary | Time: independent | Risk: actual generic write refusal still needs licensed MCP.
        Assert.IsTrue(TempArgument.GetDedicatedMessageTypeHintForField(Database::Item, Item.FieldNo("Unit Cost")).Contains('Inventory.Cost.Update'), 'Native event routes cost writes.');
        Assert.AreEqual('Inventory.Price.Update', TempArgument.GetDedicatedMessageTypeHintForField(Database::Item, Item.FieldNo("Unit Price")), 'Native event routes price writes.');
        Assert.AreEqual('', TempArgument.GetDedicatedMessageTypeHintForField(Database::Item, Item.FieldNo(Description)), 'Unrelated Item fields get no dedicated cost hint.');
        Assert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::Item, false), 'Item is not blocked as a whole table.');
        Assert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Journal Line", false), 'Journal-line writes remain available by accepted decision.');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::Item), 'Item generic reads remain available.');
    end;

    /// <summary>The shipping process boundary rolls back a real subscriber write before a native validation error.</summary>
    [Test]
    procedure UpdateCost_NativeSubscriberFailure_RollsBackProcess()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Process: Codeunit "Inventory Write Process ori";
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        PreviousDescription: Text;
        PreviousCost: Decimal;
    begin
        // Story #4 transaction contract | Time: independent | Risk: Codeunit.Run must not preserve a partial native write.
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousDescription := Item.Description;
        PreviousCost := Item."Last Direct Cost";
        Request.Add('lastDirectCost', 99);
        InitArgument(TempArgument, Item."No.", Request);
        Observer.SetItem(Item."No.", true);
        BindSubscription(Observer);
        Commit();
        Process.SetOperation('CostUpdate');
        Assert.IsFalse(Process.Run(TempArgument), 'Native subscriber failure must fail the transaction boundary.');
        Assert.ExpectedError('Owned native cost validation failure');
        UnbindSubscription(Observer);
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousDescription, Item.Description, 'Subscriber modification is rolled back.');
        Assert.AreEqual(PreviousCost, Item."Last Direct Cost", 'Card cost is rolled back.');
    end;

    /// <summary>The blocked-item refusal is translated and preserves the native field without changing the request key.</summary>
    [Test]
    procedure UpdateCost_BlockedIcelandic_PreservesValue()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Refusal: Text;
        PreviousValue: Decimal;
        PreviousLanguage: Integer;
    begin
        CreateItem(Item, Item."Costing Method"::FIFO);
        PreviousValue := Item."Unit Cost";
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Request.Add('unitCost', 99);
        InitArgument(TempArgument, Item."No.", Request);
        Commit();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        asserterror CostWrite.UpdateCost(TempArgument);
        Refusal := GetLastErrorText();
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Vara ' + Item."No." + ' er lokuð. Stilltu allowBlocked=true aðeins ef breyting á lokaðri vöru er fyrirhuguð.', Refusal, 'Native refusal is entirely Icelandic apart from the invariant request key.');
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousValue, Item."Unit Cost", 'Translated refusal does not change the stored value.');
    end;

    local procedure VerifyWrite(Method: Enum "Costing Method")
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        Response: JsonObject;
        Before: JsonObject;
        After: JsonObject;
        Token: JsonToken;
        PreviousCost: Decimal;
    begin
        CreateItem(Item, Method);
        PreviousCost := Item."Unit Cost";
        Request.Add('unitCost', 25);
        Request.Add('lastDirectCost', 20);
        InitArgument(TempArgument, Item."No.", Request);
        Observer.SetItem(Item."No.", false);
        BindSubscription(Observer);
        CostWrite.UpdateCost(TempArgument);
        UnbindSubscription(Observer);
        Assert.IsTrue(Observer.UnitCostValidations() > 0, 'Real Unit Cost Validate event fires.');
        Assert.IsTrue(Observer.DirectCostValidations() > 0, 'Real Last Direct Cost Validate event fires.');
        Item.Get(Item."No.");
        Assert.AreEqual(25, Item."Unit Cost", 'Native Item cost actually changed.');
        Assert.AreEqual(20, Item."Last Direct Cost", 'Native direct cost actually changed.');
        Response := TempArgument.GetResponseJson();
        Response.Get('before', Token);
        Before := Token.AsObject();
        Before.Get('unitCost', Token);
        Assert.AreEqual(PreviousCost, Token.AsValue().AsDecimal(), 'Before is actual stored cost.');
        Response.Get('after', Token);
        After := Token.AsObject();
        After.Get('unitCost', Token);
        Assert.AreEqual(Item."Unit Cost", Token.AsValue().AsDecimal(), 'After matches native stored cost.');
    end;

    local procedure CreateItem(var Item: Record Item; Method: Enum "Costing Method")
    var
        TrackingCode: Record "Item Tracking Code";
    begin
        LibraryInventory.CreateItem(Item);
        if Method = Method::Specific then begin
            LibraryInventory.CreateItemTrackingCode(TrackingCode);
            TrackingCode.Validate("SN Specific Tracking", true);
            TrackingCode.Modify(true);
            Item.Validate("Item Tracking Code", TrackingCode.Code);
        end;
        Item.Validate("Costing Method", Method);
        Item.Validate("Unit Cost", 10);
        Item.Modify(true);
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary; ItemNo: Code[20]; Request: JsonObject)
    begin
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Subject := ItemNo;
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
    end;
}
