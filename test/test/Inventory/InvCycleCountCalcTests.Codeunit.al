namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Inventory.CycleCount.Calculate selects items due by their counting period, refuses items without one, writes only journal lines and advances the native counting dates.</summary>
codeunit 96985 "Inv. Cycle Count Calc Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        InventoryTestLibrary: Codeunit "Inventory Test Library ori";
        LibraryWarehouse: Codeunit "Library - Warehouse";

    /// <summary>AC01 and AC03: a due item is calculated into the empty batch, nothing is posted and the next counting date moves.</summary>
    [Test]
    procedure CycleCount_DueItem_CalculatesLinesAndAdvancesDates()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        BeforeEntries: Integer;
    begin
        CreateCountedStock(Item, WorkDate());
        CreatePhysicalBatch(Batch);
        BeforeEntries := Entries.Count();
        BuildRequest(Request, Batch, Item."No.");
        Process(Request, Response, 1033);
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Calculation succeeds: ' + Format(Response));
        Assert.AreEqual(1, GetInteger(Response, 'itemsCalculated'), 'One due item.');
        Assert.AreEqual(1, GetInteger(Response, 'linesCreated'), 'One line.');
        Response.Get('posted', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'Posting stays with Inventory.PhysInventory.Post.');
        FilterBatch(Batch, Line);
        Line.FindFirst();
        Assert.AreEqual(Item."No.", Line."Item No.", 'The due item is calculated.');
        Assert.AreEqual(10, Line."Qty. (Calculated)", 'Calculated quantity is the posted stock.');
        Assert.AreEqual(BeforeEntries, Entries.Count(), 'No ledger entry is created.');
        Item.Get(Item."No.");
        Assert.IsTrue(Item."Next Counting Start Date" > WorkDate(), 'The next counting period starts after the calculation.');
    end;

    /// <summary>AC01 edge: a repeat call on a new batch does not select the item again.</summary>
    [Test]
    procedure CycleCount_RepeatCall_DoesNotSelectCountedItemAgain()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        OtherBatch: Record "Item Journal Batch";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateCountedStock(Item, WorkDate());
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Process(Request, Response, 1033);
        Assert.AreEqual(1, GetInteger(Response, 'itemsCalculated'), 'First call selects the item.');
        CreatePhysicalBatch(OtherBatch);
        Clear(Request);
        Clear(Response);
        BuildRequest(Request, OtherBatch, Item."No.");
        Process(Request, Response, 1033);
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Repeat call succeeds.');
        Assert.AreEqual(0, GetInteger(Response, 'itemsCalculated'), 'The item is no longer due.');
        Assert.AreEqual(0, GetInteger(Response, 'linesCreated'), 'No line is created.');
    end;

    /// <summary>AC01 edge: an item whose counting period starts after the posting date is not calculated.</summary>
    [Test]
    procedure CycleCount_ItemNotYetDue_IsSkipped()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateCountedStock(Item, CalcDate('<+30D>', WorkDate()));
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Process(Request, Response, 1033);
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Call succeeds.');
        Assert.AreEqual(0, GetInteger(Response, 'itemsCalculated'), 'Not due yet.');
        Assert.AreEqual(0, GetInteger(Response, 'linesCreated'), 'No line.');
        Item.Get(Item."No.");
        Assert.AreEqual(CalcDate('<+30D>', WorkDate()), Item."Next Counting Start Date", 'Counting dates stay untouched.');
    end;

    /// <summary>AC02 and AC04: an item without a counting period is refused with PreconditionFailed and a nextStep, in English.</summary>
    [Test]
    procedure CycleCount_ItemWithoutPeriod_Refused_1033()
    begin
        VerifyNoPeriodRefusal(1033);
    end;

    /// <summary>AC02 and AC04: the same refusal in Icelandic.</summary>
    [Test]
    procedure CycleCount_ItemWithoutPeriod_Refused_1039()
    begin
        VerifyNoPeriodRefusal(1039);
    end;

    /// <summary>AC04: a missing postingDate is refused naming postingDate and the batch stays empty.</summary>
    [Test]
    procedure CycleCount_MissingPostingDate_Refused()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateCountedStock(Item, WorkDate());
        CreatePhysicalBatch(Batch);
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        Request.Add('documentNo', 'CYCLE-NODATE');
        Process(Request, Response, 1033);
        Assert.AreEqual('Error', GetText(Response, 'status'), 'postingDate is required.');
        Assert.AreEqual('postingDate', GetText(Response, 'parameter'), 'The refusal names postingDate.');
        Assert.AreNotEqual('', GetText(Response, 'nextStep'), 'Recovery instruction.');
        FilterBatch(Batch, Line);
        Assert.IsTrue(Line.IsEmpty(), 'No line is written.');
        Item.Get(Item."No.");
        Assert.AreEqual(WorkDate(), Item."Next Counting Start Date", 'Counting dates stay untouched.');
    end;

    /// <summary>AC04: an undeclared key is refused as InvalidParameter.</summary>
    [Test]
    procedure CycleCount_UnknownParameter_Refused()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateCountedStock(Item, WorkDate());
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Request.Add('includeItemsWithNoTransactions', true);
        Process(Request, Response, 1033);
        Assert.AreEqual('Error', GetText(Response, 'status'), 'Undeclared key refused.');
        Assert.IsTrue(GetText(Response, 'code') in ['InvalidParameter', 'UnknownParameter'], 'Stable refusal code: ' + GetText(Response, 'code'));
        Assert.AreEqual('includeItemsWithNoTransactions', GetText(Response, 'parameter'), 'Names the key.');
    end;

    /// <summary>AC01 SKU edge: a due stockkeeping unit with a blank variant calculates only that unit, not other stocked variants at the location; line and posted physical ledger carry the SKU counting period.</summary>
    [Test]
    procedure CycleCount_BlankVariantSku_CalculatesOnlyThatSku()
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        Sku: Record "Stockkeeping Unit";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
        PeriodCode: Code[10];
    begin
        CreateStock(Item);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        LibraryInventory.CreateItemVariant(Variant, Item."No.");
        PostStock(Item."No.", Location.Code, '', 7);
        PostStock(Item."No.", Location.Code, Variant.Code, 5);
        PeriodCode := CreateCountingPeriod();
        CreateCountedSku(Sku, Item."No.", Location.Code, '', PeriodCode, WorkDate());
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Process(Request, Response, 1033);
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Calculation succeeds: ' + Format(Response));
        Assert.AreEqual(1, GetInteger(Response, 'itemsCalculated'), 'Only the due SKU is calculated.');
        Assert.AreEqual(1, GetInteger(Response, 'linesCreated'), 'Only the blank-variant SKU stock gets a line.');
        FilterBatch(Batch, Line);
        Line.FindFirst();
        Assert.AreEqual(Location.Code, Line."Location Code", 'The SKU location.');
        Assert.AreEqual('', Line."Variant Code", 'The blank variant only.');
        Assert.AreEqual(7, Line."Qty. (Calculated)", 'Stock of the blank variant at the SKU location.');
        VerifyCycleLine(Line, PeriodCode, Line."Phys Invt Counting Period Type"::SKU);
        PostCountAndVerifyLedger(Batch, Line, PeriodCode, Line."Phys Invt Counting Period Type"::SKU);
    end;

    /// <summary>AC01 SKU edge: a due item keeps its non-SKU stock when another location has a stockkeeping unit with its own, not yet due, counting period; that SKU combination is left to its own period.</summary>
    [Test]
    procedure CycleCount_DueItemWithFutureSku_KeepsNonSkuStock()
    var
        Item: Record Item;
        MainLocation: Record Location;
        SkuLocation: Record Location;
        Sku: Record "Stockkeeping Unit";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
        SkuStart: Date;
    begin
        CreateCountedStock(Item, WorkDate());
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(MainLocation);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(SkuLocation);
        PostStock(Item."No.", MainLocation.Code, '', 4);
        PostStock(Item."No.", SkuLocation.Code, '', 3);
        SkuStart := CalcDate('<+30D>', WorkDate());
        CreateCountedSku(Sku, Item."No.", SkuLocation.Code, '', CreateCountingPeriod(), SkuStart);
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Request.Add('locationCode', MainLocation.Code);
        Process(Request, Response, 1033);
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Calculation succeeds: ' + Format(Response));
        Assert.AreEqual(1, GetInteger(Response, 'itemsCalculated'), 'The due item is calculated.');
        Assert.AreEqual(1, GetInteger(Response, 'linesCreated'), 'The requested non-SKU location gets its line.');
        FilterBatch(Batch, Line);
        Line.FindFirst();
        Assert.AreEqual(MainLocation.Code, Line."Location Code", 'Non-SKU stock is kept.');
        Assert.AreEqual(4, Line."Qty. (Calculated)", 'Stock at the requested location.');
        VerifyCycleLine(Line, Item."Phys Invt Counting Period Code", Line."Phys Invt Counting Period Type"::Item);
        Sku.Get(SkuLocation.Code, Item."No.", '');
        Assert.AreEqual(SkuStart, Sku."Next Counting Start Date", 'The not yet due SKU keeps its dates.');
        PostCountAndVerifyLedger(Batch, Line, Item."Phys Invt Counting Period Code", Line."Phys Invt Counting Period Type"::Item);
    end;

    /// <summary>Without a location filter the item calculation leaves the SKU-backed combination out, as native item cycle counting does.</summary>
    [Test]
    procedure CycleCount_DueItemWithSku_SkipsOnlySkuCombination()
    var
        Item: Record Item;
        MainLocation: Record Location;
        SkuLocation: Record Location;
        Sku: Record "Stockkeeping Unit";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateCountedStock(Item, WorkDate());
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(MainLocation);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(SkuLocation);
        PostStock(Item."No.", MainLocation.Code, '', 4);
        PostStock(Item."No.", SkuLocation.Code, '', 3);
        CreateCountedSku(Sku, Item."No.", SkuLocation.Code, '', CreateCountingPeriod(), CalcDate('<+30D>', WorkDate()));
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Process(Request, Response, 1033);
        Assert.AreEqual('Success', GetText(Response, 'status'), 'Calculation succeeds: ' + Format(Response));
        FilterBatch(Batch, Line);
        Line.SetRange("Location Code", SkuLocation.Code);
        Assert.IsTrue(Line.IsEmpty(), 'The SKU combination waits for its own period.');
        Line.SetRange("Location Code", MainLocation.Code);
        Assert.AreEqual(1, Line.Count(), 'The non-SKU location is counted.');
        Line.SetRange("Location Code", '');
        Assert.AreEqual(1, Line.Count(), 'The blank-location stock is counted.');
    end;

    local procedure VerifyCycleLine(Line: Record "Item Journal Line"; PeriodCode: Code[10]; PeriodType: Option)
    begin
        Assert.AreEqual(PeriodCode, Line."Phys Invt Counting Period Code", 'The line carries the counting period code.');
        Assert.AreEqual(PeriodType, Line."Phys Invt Counting Period Type", 'The line carries the counting period type.');
    end;

    local procedure PostCountAndVerifyLedger(Batch: Record "Item Journal Batch"; Line: Record "Item Journal Line"; PeriodCode: Code[10]; PeriodType: Option)
    var
        PhysicalEntry: Record "Phys. Inventory Ledger Entry";
        ItemNo: Code[20];
    begin
        ItemNo := Line."Item No.";
        Batch.Get(Batch."Journal Template Name", Batch.Name);
        Batch."No. Series" := '';
        Batch."Posting No. Series" := '';
        Batch.Modify();
        Line.Validate("Qty. (Phys. Inventory)", Line."Qty. (Calculated)" - 1);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(Batch."Journal Template Name", Batch.Name);
        PhysicalEntry.SetRange("Item No.", ItemNo);
        PhysicalEntry.SetRange("Document No.", 'CYCLE-TEST');
        Assert.IsTrue(PhysicalEntry.FindFirst(), 'Native posting writes the physical inventory ledger.');
        Assert.AreEqual(PeriodCode, PhysicalEntry."Phys Invt Counting Period Code", 'The ledger keeps the counting period code.');
        Assert.AreEqual(PeriodType, PhysicalEntry."Phys Invt Counting Period Type", 'The ledger keeps the counting period type.');
    end;

    local procedure VerifyNoPeriodRefusal(LanguageId: Integer)
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateStock(Item);
        CreatePhysicalBatch(Batch);
        BuildRequest(Request, Batch, Item."No.");
        Process(Request, Response, LanguageId);
        Assert.AreEqual('Error', GetText(Response, 'status'), 'Item without counting period is refused.');
        Assert.AreEqual('PreconditionFailed', GetText(Response, 'code'), 'Stable code.');
        Assert.AreEqual('itemNo', GetText(Response, 'parameter'), 'Names itemNo.');
        Assert.AreEqual(Item."No.", GetText(Response, 'received'), 'Names the item.');
        if LanguageId = 1039 then begin
            Assert.AreEqual('Vara ' + Item."No." + ' hefur ekkert talningartímabil.', GetText(Response, 'error'), 'Icelandic refusal.');
            Assert.AreEqual('Úthlutaðu talningartímabili á vöruna (vörukort, birgðatalning) eða fjarlægðu hana úr itemNo síunni og reyndu aftur.', GetText(Response, 'nextStep'), 'Icelandic nextStep.');
        end else begin
            Assert.AreEqual('Item ' + Item."No." + ' has no counting period.', GetText(Response, 'error'), 'English refusal.');
            Assert.AreEqual('Assign a counting period to the item (Item card, Physical Inventory) or remove it from the itemNo filter, then retry.', GetText(Response, 'nextStep'), 'English nextStep.');
        end;
        FilterBatch(Batch, Line);
        Assert.IsTrue(Line.IsEmpty(), 'Refusal writes no line.');
    end;

    local procedure Process(Request: JsonObject; var Response: JsonObject; LanguageId: Integer)
    var
        Helper: Codeunit "Assembly Order Test Helper";
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.CycleCount.Calculate", Request, Response);
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure BuildRequest(var Request: JsonObject; Batch: Record "Item Journal Batch"; ItemNo: Code[20])
    begin
        Request.Add('templateName', Batch."Journal Template Name");
        Request.Add('batchName', Batch.Name);
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Request.Add('documentNo', 'CYCLE-TEST');
        Request.Add('itemNo', ItemNo);
    end;

    local procedure GetText(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Response field ' + Name + ' is missing.');
        exit(Token.AsValue().AsText());
    end;

    local procedure GetInteger(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Response field ' + Name + ' is missing.');
        exit(Token.AsValue().AsInteger());
    end;

    local procedure FilterBatch(Batch: Record "Item Journal Batch"; var Line: Record "Item Journal Line")
    begin
        Line.Reset();
        Line.SetRange("Journal Template Name", Batch."Journal Template Name");
        Line.SetRange("Journal Batch Name", Batch.Name);
    end;

    local procedure CreatePhysicalBatch(var Batch: Record "Item Journal Batch")
    var
        JournalTemplate: Record "Item Journal Template";
    begin
        InventoryTestLibrary.EnablePhysicalInventory();
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, "Item Journal Template Type"::"Phys. Inventory");
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
    end;

    local procedure CreateCountedStock(var Item: Record Item; NextStart: Date)
    begin
        CreateStock(Item);
        Item.Get(Item."No.");
        Item."Phys Invt Counting Period Code" := CreateCountingPeriod();
        Item."Next Counting Start Date" := NextStart;
        Item."Next Counting End Date" := CalcDate('<+14D>', NextStart);
        Item.Modify();
    end;

    local procedure CreateCountingPeriod(): Code[10]
    var
        CountingPeriod: Record "Phys. Invt. Counting Period";
    begin
        CountingPeriod.Init();
        CountingPeriod.Code := CopyStr('CY' + Format(CreateGuid(), 0, 4), 1, 10);
        CountingPeriod.Description := 'Cycle count test';
        CountingPeriod."Count Frequency per Year" := 4;
        CountingPeriod.Insert();
        exit(CountingPeriod.Code);
    end;

    local procedure CreateCountedSku(var Sku: Record "Stockkeeping Unit"; ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; PeriodCode: Code[10]; NextStart: Date)
    begin
        Sku.Init();
        Sku."Location Code" := LocationCode;
        Sku."Item No." := ItemNo;
        Sku."Variant Code" := VariantCode;
        Sku."Phys Invt Counting Period Code" := PeriodCode;
        Sku."Next Counting Start Date" := NextStart;
        Sku."Next Counting End Date" := CalcDate('<+14D>', NextStart);
        Sku.Insert();
    end;

    local procedure PostStock(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; Quantity: Decimal)
    var
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", ItemNo, Quantity);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Location Code", LocationCode);
        JournalLine.Validate("Variant Code", VariantCode);
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
    end;

    local procedure CreateStock(var Item: Record Item)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
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
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(JournalBatch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, JournalBatch.Name, JournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        JournalLine.Validate("Posting Date", WorkDate());
        JournalLine.Validate("Unit Amount", 12);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, JournalBatch.Name);
    end;
}
