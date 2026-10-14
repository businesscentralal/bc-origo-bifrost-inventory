namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Cost snapshot resolution, current native fields and self-seeded stock without licensed message dispatch.</summary>
codeunit 96936 "Inventory Cost Read Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        CostRead: Codeunit "Inventory Cost Read ori";

    /// <summary>Cost fields include the invariant costing method and calculated native status flags.</summary>
    [Test]
    procedure Scenario_AC01_ItemNo_ReturnsCurrentSnapshot()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
    begin
        // Story #4 AC1 | Time: independent | Risk: current card costs are not historical valuation.
        CreateItem(Item);
        Request.Add('itemNo', Item."No.");
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        Row := FirstItem(TempArgument);
        AssertText(Row, 'costingMethod', 'FIFO');
        AssertNumber(Row, 'unitCost', Item."Unit Cost");
        AssertNumber(Row, 'standardCost', Item."Standard Cost");
        AssertNumber(Row, 'lastDirectCost', Item."Last Direct Cost");
        AssertNumber(Row, 'indirectCostPct', Item."Indirect Cost %");
        Item.CalcFields("Cost is Posted to G/L");
        Row.Get('costIsPostedToGL', Token);
        Assert.AreEqual(Item."Cost is Posted to G/L", Token.AsValue().AsBoolean(), 'Calculated native G/L flag.');
        Row.Get('costIsAdjusted', Token);
        Assert.AreEqual(Item."Cost is Adjusted", Token.AsValue().AsBoolean(), 'Current adjustment flag.');
    end;

    /// <summary>Every documented SystemId alias selects the same native item.</summary>
    [Test]
    procedure Scenario_AC01_SystemIdAliases_ReturnSameItem()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Aliases: List of [Text];
        Alias: Text;
    begin
        // Story #4 AC1 | Time: independent | Risk: Foundation selection semantics.
        CreateItem(Item);
        Aliases.Add('itemId');
        Aliases.Add('id');
        Aliases.Add('systemId');
        Aliases.Add('recordSystemId');
        foreach Alias in Aliases do begin
            Clear(TempArgument);
            Clear(Request);
            Request.Add(Alias, Format(Item.SystemId, 0, 4));
            InitArgument(TempArgument);
            TempArgument.SetRequestJson(Request);
            CostRead.ReadCosts(TempArgument);
            AssertText(FirstItem(TempArgument), 'itemNo', Item."No.");
        end;
    end;

    /// <summary>Subject wins over a different valid data identifier, for both No. and SystemId.</summary>
    [Test]
    procedure Scenario_AC01_SubjectPrecedesData_SelectsSubject()
    var
        Item: Record Item;
        OtherItem: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #4 AC1 | Time: independent | Risk: contradictory identifiers must follow documented precedence.
        CreateItem(Item);
        CreateItem(OtherItem);
        Request.Add('itemNo', OtherItem."No.");
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        TempArgument.Subject := Item."No.";
        CostRead.ReadCosts(TempArgument);
        AssertText(FirstItem(TempArgument), 'itemNo', Item."No.");
        TempArgument.Subject := Format(Item.SystemId, 0, 4);
        CostRead.ReadCosts(TempArgument);
        AssertText(FirstItem(TempArgument), 'itemNo', Item."No.");
    end;

    /// <summary>A native tableView returns both selected items, without widening to other data.</summary>
    [Test]
    procedure Scenario_AC01_TableView_ReturnsSelectedItems()
    var
        Item: Record Item;
        OtherItem: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #4 AC1 | Time: independent | Risk: multi-item contract.
        CreateItem(Item);
        CreateItem(OtherItem);
        Item.SetFilter("No.", '%1|%2', Item."No.", OtherItem."No.");
        Request.Add('tableView', Item.GetView(false));
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('items', Token);
        Assert.AreEqual(2, Token.AsArray().Count(), 'Both and only both selected items are returned.');
    end;

    /// <summary>A missing item produces a structured response, without throwing.</summary>
    [Test]
    procedure Scenario_AC02_MissingItem_ReturnsStructuredError()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #4 AC2 | Time: independent | Risk: no customer fixture dependency.
        Request.Add('itemId', Format(CreateGuid(), 0, 4));
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', 'RecordNotFound');
    end;

    /// <summary>Invalid optional values cannot silently become an unrestricted stock query.</summary>
    [Test]
    procedure ReadCosts_MalformedLocation_ReturnsStructuredError()
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #4 optional filters | Time: independent | Risk: malformed request must not widen selection.
        Request.ReadFrom('{"locationFilter":{}}');
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        AssertText(TempArgument.GetResponseJson(), 'status', 'Error');
        AssertText(TempArgument.GetResponseJson(), 'code', 'InvalidParameter');
    end;

    /// <summary>Native journal posting creates dated stock; reads calculate it and leave native entries unchanged.</summary>
    [Test]
    procedure ReadCosts_DatedStock_CalculatesQuantityWithoutWrites()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        EntryCount: Integer;
        ValueCount: Integer;
        ModifiedAt: DateTime;
    begin
        // Story #4 native quantity | Time: WorkDate() and prior day | Risk: costs remain current at asOfDate.
        CreateItem(Item);
        PostStock(Item."No.", WorkDate() - 1, 2, '');
        PostStock(Item."No.", WorkDate(), 3, '');
        Item.Get(Item."No.");
        ModifiedAt := Item.SystemModifiedAt;
        EntryCount := Ledger.Count();
        ValueCount := ValueEntry.Count();
        Request.Add('itemNo', Item."No.");
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        Row := FirstItem(TempArgument);
        AssertNumber(Row, 'inventory', 5);
        Row.Get('costIsPostedToGL', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Real seeded pending costs make the native flag false.');
        Request.Add('asOfDate', Format(WorkDate() - 1, 0, 9));
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        Row := FirstItem(TempArgument);
        AssertNumber(Row, 'inventory', 2);
        AssertNumber(Row, 'unitCost', Item."Unit Cost");
        Request.Add('locationFilter', 'NONEXISTENT');
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        AssertNumber(FirstItem(TempArgument), 'inventory', 0);
        Assert.AreEqual(EntryCount, Ledger.Count(), 'Read creates no item entries.');
        Assert.AreEqual(ValueCount, ValueEntry.Count(), 'Read creates no value entries.');
        Item.Get(Item."No.");
        Assert.AreEqual(ModifiedAt, Item.SystemModifiedAt, 'Read never modifies Item.');
    end;

    /// <summary>An exact variant filter selects real posted stock both currently and at a date.</summary>
    [Test]
    procedure ReadCosts_VariantStock_SelectsOnlyRequestedVariant()
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        // Story #4 native variant filter | Time: WorkDate() | Risk: exact variant must not become a filter expression.
        CreateItem(Item);
        LibraryInventory.CreateItemVariant(Variant, Item."No.");
        PostStock(Item."No.", WorkDate(), 2, Variant.Code);
        PostStock(Item."No.", WorkDate(), 3, '');
        Request.Add('itemNo', Item."No.");
        Request.Add('variantCode', Variant.Code);
        InitArgument(TempArgument);
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        AssertNumber(FirstItem(TempArgument), 'inventory', 2);
        Request.Add('asOfDate', Format(WorkDate(), 0, 9));
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        AssertNumber(FirstItem(TempArgument), 'inventory', 2);
        Request.Replace('variantCode', '');
        TempArgument.SetRequestJson(Request);
        CostRead.ReadCosts(TempArgument);
        AssertNumber(FirstItem(TempArgument), 'inventory', 3);
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary)
    begin
        Clear(TempArgument);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
    end;

    local procedure CreateItem(var Item: Record Item)
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate("Costing Method", Item."Costing Method"::FIFO);
        Item.Validate("Unit Cost", 12);
        Item.Validate("Last Direct Cost", 10);
        Item.Validate("Indirect Cost %", 20);
        Item.Modify(true);
    end;

    local procedure PostStock(ItemNo: Code[20]; PostingDate: Date; Quantity: Decimal; VariantCode: Code[10])
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        GLSetup.Get();
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", ItemNo, Quantity);
        Line.Validate("Variant Code", VariantCode);
        Line.Validate("Posting Date", PostingDate);
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
    end;

    local procedure FirstItem(var TempArgument: Record "Message Argument ori") Row: JsonObject
    var
        Response: JsonObject;
        Token: JsonToken;
        Rows: JsonArray;
    begin
        Response := TempArgument.GetResponseJson();
        AssertText(Response, 'status', 'Success');
        Response.Get('items', Token);
        Rows := Token.AsArray();
        Assert.IsTrue(Rows.Count() > 0, 'Response contains actual item rows.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
    end;

    local procedure AssertText(Row: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Row.WriteTo(Serialized);
        Assert.IsTrue(Row.Get(Name, Token), Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Name + ': ' + Serialized);
    end;

    local procedure AssertNumber(Row: JsonObject; Name: Text; Expected: Decimal)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Row.Get(Name, Token), Name);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), Name);
    end;
}
