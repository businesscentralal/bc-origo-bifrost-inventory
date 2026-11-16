namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AssemblyToOrder.Get and Inventory.AssemblyBOM.Get (#116).
/// </summary>
codeunit 96966 "Assembly Read Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssembly: Codeunit "Library - Assembly";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    procedure AsmToOrder_LinkedLine_ReturnsOrderAndLines()
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        SalesLine: Record "Sales Line";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        AssembleToOrderLink: Record "Assemble-to-Order Link";
        ResponseJson: JsonObject;
        OrderJson: JsonObject;
        LineJson: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
        MessageType: Enum "Message Type ori";
        HeaderCount: Integer;
        LineCount: Integer;
        LinkCount: Integer;
    begin
        // [SCENARIO AC01] A sales order line with assemble to order answers the linked assembly order and its lines.
        Initialize();
        CreateAtoItem(ParentItem, ComponentItem, 2);
        CreateSalesLine(SalesLine, ParentItem."No.", 3);
        HeaderCount := AssemblyHeader.Count();
        LineCount := AssemblyLine.Count();
        LinkCount := AssembleToOrderLink.Count();

        ResponseJson := CallAto('Order', SalesLine."Document No.", SalesLine."Line No.");

        Library.AssertStatus(ResponseJson, 'Success');
        Library.AssertResponseContract(MessageType::"Inventory.AssemblyToOrder.Get", ResponseJson);
        AssertText(ResponseJson, 'documentType', 'Order');
        AssertText(ResponseJson, 'documentNo', SalesLine."Document No.");
        AssertText(ResponseJson, 'itemNo', ParentItem."No.");
        AssertBoolean(ResponseJson, 'linked', true);
        AssertDecimal(ResponseJson, 'qtyToAssembleToOrder', 3);
        ResponseJson.Get('assemblyOrder', Token);
        OrderJson := Token.AsObject();
        AssertText(OrderJson, 'itemNo', ParentItem."No.");
        AssertText(OrderJson, 'documentType', 'Order');
        AssertDecimal(OrderJson, 'quantity', 3);
        AssertText(OrderJson, 'orderStatus', 'Open');
        ResponseJson.Get('lines', Token);
        Lines := Token.AsArray();
        Assert.AreEqual(1, Lines.Count(), 'One assembly line.');
        Lines.Get(0, Token);
        LineJson := Token.AsObject();
        AssertText(LineJson, 'type', 'Item');
        AssertText(LineJson, 'no', ComponentItem."No.");
        AssertDecimal(LineJson, 'quantityPer', 2);
        AssertDecimal(LineJson, 'quantity', 6);
        // [SCENARIO AC03] Read only: nothing is created or removed.
        Assert.AreEqual(HeaderCount, AssemblyHeader.Count(), 'No assembly header is created or removed.');
        Assert.AreEqual(LineCount, AssemblyLine.Count(), 'No assembly line is created or removed.');
        Assert.AreEqual(LinkCount, AssembleToOrderLink.Count(), 'No link is created or removed.');
    end;

    [Test]
    procedure AsmToOrder_DefaultDocumentType_IsOrder()
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01] documentType may be left out; Order is used.
        Initialize();
        CreateAtoItem(ParentItem, ComponentItem, 1);
        CreateSalesLine(SalesLine, ParentItem."No.", 1);
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");

        ResponseJson := ExecuteAto(RequestJson);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'documentType', 'Order');
        AssertBoolean(ResponseJson, 'linked', true);
    end;

    [Test]
    procedure AsmToOrder_NoLink_ReturnsLinkedFalse()
    var
        Item: Record Item;
        SalesLine: Record "Sales Line";
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO AC01 edge] A sales line without assemble to order answers linked false and no lines.
        Initialize();
        LibraryInventory.CreateItem(Item);
        CreateSalesLine(SalesLine, Item."No.", 1);

        ResponseJson := CallAto('Order', SalesLine."Document No.", SalesLine."Line No.");

        Library.AssertStatus(ResponseJson, 'Success');
        AssertBoolean(ResponseJson, 'linked', false);
        ResponseJson.Get('lines', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'No lines.');
        ResponseJson.Get('assemblyOrder', Token);
        Assert.AreEqual(0, Token.AsObject().Keys().Count(), 'Empty assembly order.');
    end;

    [Test]
    procedure AsmToOrder_MissingSalesLine_ReturnsRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A sales line that does not exist is refused.
        Initialize();
        ResponseJson := CallAto('Order', 'NO-SUCH-SO-116', 10000);
        AssertResponseError(ResponseJson, 'RecordNotFound', 'Check documentType, documentNo and lineNo.');
    end;

    [Test]
    procedure AsmToOrder_InvoiceType_ReturnsInvalidParameterFormat()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Only Quote, Order and Blanket Order lines can be assembled to order.
        Initialize();
        ResponseJson := CallAto('Invoice', 'ANY', 10000);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'documentType as Quote, Order or Blanket Order');
        AssertText(ResponseJson, 'parameter', 'documentType');
    end;

    [Test]
    procedure AsmToOrder_TextLineNo_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] lineNo must be a JSON whole number.
        Initialize();
        RequestJson.Add('documentNo', 'ANY');
        RequestJson.Add('lineNo', '10000');
        ResponseJson := ExecuteAto(RequestJson);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'lineNo as a whole number');
    end;

    [Test]
    procedure AsmToOrder_DecimalLineNo_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04 edge] A decimal lineNo is refused, not rounded.
        Initialize();
        RequestJson.Add('documentNo', 'ANY');
        RequestJson.Add('lineNo', 10000.5);
        ResponseJson := ExecuteAto(RequestJson);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'lineNo as a whole number');
    end;

    [Test]
    procedure AsmToOrder_MissingLineNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] lineNo is required.
        Initialize();
        RequestJson.Add('documentNo', 'ANY');
        ResponseJson := ExecuteAto(RequestJson);
        AssertResponseError(ResponseJson, 'MissingParameter', 'Send documentNo and lineNo.');
        AssertText(ResponseJson, 'parameter', 'lineNo');
    end;

    [Test]
    procedure AsmToOrder_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A key the type does not read is refused.
        Initialize();
        RequestJson.Add('documentNo', 'ANY');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('quantity', 1);
        ResponseJson := ExecuteAto(RequestJson);
        AssertResponseError(ResponseJson, 'UnknownParameter', 'Allowed keys are documentType, documentNo and lineNo.');
    end;

    [Test]
    procedure Bom_OneLevel_ReturnsDirectComponents()
    var
        ParentItem: Record Item;
        SubItem: Record Item;
        LeafItem: Record Item;
        BOMComponent: Record "BOM Component";
        ResponseJson: JsonObject;
        ComponentJson: JsonObject;
        MessageType: Enum "Message Type ori";
        BomCount: Integer;
    begin
        // [SCENARIO AC02, AC03] Without explode only the first level is answered, and nothing is changed.
        Initialize();
        CreateTwoLevelBom(ParentItem, SubItem, LeafItem);
        BomCount := BOMComponent.Count();

        ResponseJson := CallBom(ParentItem."No.", false);

        Library.AssertStatus(ResponseJson, 'Success');
        Library.AssertResponseContract(MessageType::"Inventory.AssemblyBOM.Get", ResponseJson);
        AssertBoolean(ResponseJson, 'assemblyBOM', true);
        AssertBoolean(ResponseJson, 'exploded', false);
        AssertDecimal(ResponseJson, 'componentCount', 1);
        ComponentJson := ComponentAt(ResponseJson, 0);
        AssertDecimal(ComponentJson, 'level', 1);
        AssertText(ComponentJson, 'parentItemNo', ParentItem."No.");
        AssertText(ComponentJson, 'type', 'Item');
        AssertText(ComponentJson, 'no', SubItem."No.");
        AssertDecimal(ComponentJson, 'quantityPer', 2);
        AssertDecimal(ComponentJson, 'totalQuantityPer', 2);
        AssertBoolean(ComponentJson, 'assemblyBOM', true);
        Assert.AreEqual(BomCount, BOMComponent.Count(), 'No BOM component is created or removed.');
    end;

    [Test]
    procedure Bom_Exploded_MultipliesThroughLevels()
    var
        ParentItem: Record Item;
        SubItem: Record Item;
        LeafItem: Record Item;
        ResponseJson: JsonObject;
        ComponentJson: JsonObject;
    begin
        // [SCENARIO AC02] With explode the sub-assembly is followed and totalQuantityPer is multiplied.
        Initialize();
        CreateTwoLevelBom(ParentItem, SubItem, LeafItem);

        ResponseJson := CallBom(ParentItem."No.", true);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertBoolean(ResponseJson, 'exploded', true);
        AssertDecimal(ResponseJson, 'componentCount', 2);
        ComponentJson := ComponentAt(ResponseJson, 1);
        AssertDecimal(ComponentJson, 'level', 2);
        AssertText(ComponentJson, 'parentItemNo', SubItem."No.");
        AssertText(ComponentJson, 'no', LeafItem."No.");
        AssertDecimal(ComponentJson, 'quantityPer', 3);
        AssertDecimal(ComponentJson, 'totalQuantityPer', 6);
        AssertBoolean(ComponentJson, 'assemblyBOM', false);
    end;

    [Test]
    procedure Bom_ItemWithoutComponents_ReturnsEmptyList()
    var
        Item: Record Item;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC02 edge] An item without an assembly BOM answers assemblyBOM false and no components.
        Initialize();
        LibraryInventory.CreateItem(Item);

        ResponseJson := CallBom(Item."No.", true);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertBoolean(ResponseJson, 'assemblyBOM', false);
        AssertDecimal(ResponseJson, 'componentCount', 0);
    end;

    [Test]
    procedure Bom_MissingItem_ReturnsRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An item that does not exist is refused.
        Initialize();
        ResponseJson := CallBom('NO-SUCH-ITEM-116', false);
        AssertResponseError(ResponseJson, 'RecordNotFound', 'Check the item no.');
    end;

    [Test]
    procedure Bom_TextExplode_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] explode must be a JSON boolean.
        Initialize();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('explode', 'yes');
        ResponseJson := ExecuteBom(RequestJson);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'explode as true or false');
    end;

    [Test]
    procedure Bom_MissingItemNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] itemNo is required.
        Initialize();
        RequestJson.Add('explode', true);
        ResponseJson := ExecuteBom(RequestJson);
        AssertResponseError(ResponseJson, 'MissingParameter', 'Send itemNo.');
    end;

    [Test]
    procedure Bom_DomainOff_ReturnsIcelandicRefusal()
    var
        TempArgument: Record "Message Argument ori" temporary;
        InventorySetup: Record "Inventory Setup ori";
        BomImpl: Codeunit "Assembly BOM Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [SCENARIO AC04] The domain refusal answers its nextStep in is-IS at 1039.
        Initialize();
        InventorySetup.Get();
        InventorySetup.Validate(Assembly, false);
        InventorySetup.Modify(true);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('itemNo', 'ANY');
        TempArgument.SetRequestJson(RequestJson);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        BomImpl.ExecuteBifrostTask(TempArgument);
        GlobalLanguage(PreviousLanguage);
        ResponseJson := TempArgument.GetResponseJson();
        AssertText(ResponseJson, 'code', 'InvalidParameter');
        AssertText(ResponseJson, 'nextStep', 'Biddu kerfisstjóra með heimildasafnið Bókunarhlið birgða að kveikja á sviðinu á síðunni Uppsetning birgða. Data.Records.Set getur ekki breytt þessari uppsetningu.');
    end;

    [Test]
    procedure AsmToOrder_UnknownKey_IcelandicNextStep()
    var
        TempArgument: Record "Message Argument ori" temporary;
        AtoImpl: Codeunit "Asm. To Order Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [SCENARIO AC04] Refusals of this type answer in is-IS at 1039.
        Initialize();
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('salesOrder', 'ANY');
        TempArgument.SetRequestJson(RequestJson);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        AtoImpl.ExecuteBifrostTask(TempArgument);
        GlobalLanguage(PreviousLanguage);
        ResponseJson := TempArgument.GetResponseJson();
        AssertText(ResponseJson, 'code', 'UnknownParameter');
        AssertText(ResponseJson, 'error', 'Lykillinn er ekki hluti af þessari skilaboðategund.');
        AssertText(ResponseJson, 'nextStep', 'Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo og lineNo.');
    end;

    [Test]
    procedure Names_HaveThreeParts()
    var
        MessageType: Enum "Message Type ori";
    begin
        // [SCENARIO AC05] Both names have exactly three dot-separated parts.
        MessageType := MessageType::"Inventory.AssemblyToOrder.Get";
        Assert.AreEqual(3, Format(MessageType).Split('.').Count(), 'Inventory.AssemblyToOrder.Get has three parts.');
        MessageType := MessageType::"Inventory.AssemblyBOM.Get";
        Assert.AreEqual(3, Format(MessageType).Split('.').Count(), 'Inventory.AssemblyBOM.Get has three parts.');
    end;

    local procedure Initialize()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        Library.Initialize();
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup.Assembly then
            exit;
        InventorySetup.Validate(Assembly, true);
        InventorySetup.Modify(true);
    end;

    local procedure CreateAtoItem(var ParentItem: Record Item; var ComponentItem: Record Item; QuantityPer: Decimal)
    var
        BOMComponent: Record "BOM Component";
    begin
        LibraryInventory.CreateItem(ComponentItem);
        LibraryInventory.CreateItem(ParentItem);
        ParentItem.Validate("Replenishment System", ParentItem."Replenishment System"::Assembly);
        ParentItem.Validate("Assembly Policy", ParentItem."Assembly Policy"::"Assemble-to-Order");
        ParentItem.Modify(true);
        LibraryAssembly.CreateAssemblyListComponent(
            BOMComponent.Type::Item, ComponentItem."No.", ParentItem."No.", '', BOMComponent."Resource Usage Type"::Direct, QuantityPer, true);
    end;

    local procedure CreateTwoLevelBom(var ParentItem: Record Item; var SubItem: Record Item; var LeafItem: Record Item)
    var
        BOMComponent: Record "BOM Component";
    begin
        LibraryInventory.CreateItem(LeafItem);
        LibraryInventory.CreateItem(SubItem);
        LibraryInventory.CreateItem(ParentItem);
        LibraryAssembly.CreateAssemblyListComponent(
            BOMComponent.Type::Item, LeafItem."No.", SubItem."No.", '', BOMComponent."Resource Usage Type"::Direct, 3, true);
        LibraryAssembly.CreateAssemblyListComponent(
            BOMComponent.Type::Item, SubItem."No.", ParentItem."No.", '', BOMComponent."Resource Usage Type"::Direct, 2, true);
    end;

    local procedure CreateSalesLine(var SalesLine: Record "Sales Line"; ItemNo: Code[20]; Quantity: Decimal)
    var
        SalesHeader: Record "Sales Header";
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Quantity);
    end;

    local procedure CallAto(DocumentType: Text; DocumentNo: Text; LineNo: Integer): JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('documentType', DocumentType);
        RequestJson.Add('documentNo', DocumentNo);
        RequestJson.Add('lineNo', LineNo);
        exit(ExecuteAto(RequestJson));
    end;

    local procedure ExecuteAto(RequestJson: JsonObject): JsonObject
    var
        MessageType: Enum "Message Type ori";
    begin
        exit(Library.ExecuteType(MessageType::"Inventory.AssemblyToOrder.Get", 'ATO', RequestJson, false));
    end;

    local procedure CallBom(ItemNo: Text; Explode: Boolean): JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('itemNo', ItemNo);
        if Explode then
            RequestJson.Add('explode', true);
        exit(ExecuteBom(RequestJson));
    end;

    local procedure ExecuteBom(RequestJson: JsonObject): JsonObject
    var
        MessageType: Enum "Message Type ori";
    begin
        exit(Library.ExecuteType(MessageType::"Inventory.AssemblyBOM.Get", 'BOM', RequestJson, false));
    end;

    local procedure ComponentAt(ResponseJson: JsonObject; Index: Integer): JsonObject
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('components', Token), 'components missing');
        Assert.IsTrue(Token.AsArray().Get(Index, Token), 'component missing');
        exit(Token.AsObject());
    end;

    local procedure AssertResponseError(ResponseJson: JsonObject; ExpectedCode: Text; ExpectedNextStepPart: Text)
    var
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing: ' + ResponseText);
        Assert.AreEqual(ExpectedCode, CodeToken.AsValue().AsText(), ResponseText);
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing: ' + ResponseText);
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), ExpectedNextStepPart), NextStepToken.AsValue().AsText());
    end;

    local procedure AssertText(ResponseJson: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing: ' + ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), KeyName + ': ' + ResponseText);
    end;

    local procedure AssertDecimal(ResponseJson: JsonObject; KeyName: Text; Expected: Decimal)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing: ' + ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), KeyName + ': ' + ResponseText);
    end;

    local procedure AssertBoolean(ResponseJson: JsonObject; KeyName: Text; Expected: Boolean)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing: ' + ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsBoolean(), KeyName + ': ' + ResponseText);
    end;
}
