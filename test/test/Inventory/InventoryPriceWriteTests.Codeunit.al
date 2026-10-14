namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Story #4 price acceptance: native writes, explicit selection, parameter/field refusals and rollback.</summary>
codeunit 96939 "Inventory Price Write Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        PriceWrite: Codeunit "Inventory Price Write ori";

    /// <summary>Actual native validation updates the selected item and returns stored before/after prices.</summary>
    [Test]
    procedure UpdatePrice_Subject_ValidatesAndReturnsStoredPrice()
    var
        Item: Record Item;
        OtherItem: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inventory Price Write Observer";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #4 price decision | Time: independent | Risk: caller scope and truthful response.
        CreateItem(Item);
        CreateItem(OtherItem);
        Request.Add('unitPrice', 25.5);
        Request.Add('itemNo', OtherItem."No.");
        InitArgument(TempArgument, Item."No.", Request);
        Observer.SetItem(Item."No.", false);
        BindSubscription(Observer);
        PriceWrite.UpdatePrice(TempArgument);
        UnbindSubscription(Observer);
        Assert.AreEqual(1, Observer.Validations(), 'Exactly one native Unit Price validation.');
        Item.Get(Item."No.");
        OtherItem.Get(OtherItem."No.");
        Assert.AreEqual(25.5, Item."Unit Price", 'Selected item stored price.');
        Assert.AreEqual(10, OtherItem."Unit Price", 'Foundation subject precedence preserves the other item.');
        Response := TempArgument.GetResponseJson();
        Response.Get('previousUnitPrice', Token);
        Assert.AreEqual(10, Token.AsValue().AsDecimal(), 'Actual previous price.');
        Response.Get('unitPrice', Token);
        Assert.AreEqual(Item."Unit Price", Token.AsValue().AsDecimal(), 'Actual resulting price.');
    end;

    /// <summary>SystemId resolves one item; explicit zero is a valid intended price.</summary>
    [Test]
    procedure UpdatePrice_SystemId_SupportsZeroPrice()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Request.Add('itemId', Format(Item.SystemId, 0, 4));
        Request.Add('unitPrice', 0);
        InitArgument(TempArgument, '', Request);
        PriceWrite.UpdatePrice(TempArgument);
        Item.Get(Item."No.");
        Assert.AreEqual(0, Item."Unit Price", 'Explicit numeric zero is not missing.');
    end;

    /// <summary>Native single-item views accept invariant decimal strings supported by Foundation.</summary>
    [Test]
    procedure UpdatePrice_TableView_ResolvesOneItem()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Item.SetRange("No.", Item."No.");
        Request.Add('tableView', Item.GetView(false));
        Request.Add('unitPrice', '12.75');
        InitArgument(TempArgument, '', Request);
        PriceWrite.UpdatePrice(TempArgument);
        Item.Get(Item."No.");
        Assert.AreEqual(12.75, Item."Unit Price", 'Invariant decimal parsed by Foundation.');
    end;

    /// <summary>Multi-item selection never silently writes the first match.</summary>
    [Test]
    procedure UpdatePrice_MultipleItems_RefusesWithoutWrites()
    var
        Item: Record Item;
        OtherItem: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        CreateItem(OtherItem);
        Item.SetFilter("No.", '%1|%2', Item."No.", OtherItem."No.");
        Request.Add('tableView', Item.GetView(false));
        Request.Add('unitPrice', 99);
        InitArgument(TempArgument, '', Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('exactly one item');
        Item.Get(Item."No.");
        OtherItem.Get(OtherItem."No.");
        Assert.AreEqual(10, Item."Unit Price", 'First item unchanged.');
        Assert.AreEqual(10, OtherItem."Unit Price", 'Second item unchanged.');
    end;

    /// <summary>The shipping transaction rolls back real subscriber writes before a validation error.</summary>
    [Test]
    procedure UpdatePrice_NativeFailure_RollsBackSubscriberWrite()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inventory Price Write Observer";
        Request: JsonObject;
        PreviousDescription: Text;
    begin
        CreateItem(Item);
        PreviousDescription := Item.Description;
        Request.Add('unitPrice', 99);
        InitArgument(TempArgument, Item."No.", Request);
        Observer.SetItem(Item."No.", true);
        BindSubscription(Observer);
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv. Price Write Process ori", TempArgument), 'Native validation fails the transaction.');
        Assert.ExpectedError('Owned native price validation failure');
        UnbindSubscription(Observer);
        Item.Get(Item."No.");
        Assert.AreEqual(PreviousDescription, Item.Description, 'Subscriber database write rolled back.');
        Assert.AreEqual(10, Item."Unit Price", 'Price rolled back.');
    end;

    /// <summary>A price-field restriction prevents native validation; cleanup affects only the owned restriction.</summary>
    [Test]
    procedure UpdatePrice_RestrictedField_PreservesPrice()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        FieldAccess: TestPage "Field Accesses ori";
        Request: JsonObject;
    begin
        CreateItem(Item);
        FieldAccess.OpenEdit();
        FieldAccess.CurrentUserName.SetValue(UserId());
        FieldAccess.New();
        FieldAccess."Table No.".SetValue(Database::Item);
        FieldAccess."Field No.".SetValue(Item.FieldNo("Unit Price"));
        FieldAccess."Restriction Type".SetValue('Write');
        FieldAccess.Close();
        Request.Add('unitPrice', 99);
        InitArgument(TempArgument, Item."No.", Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('Permission denied');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'Restricted field unchanged.');
        FieldAccess.OpenEdit();
        FieldAccess.CurrentUserName.SetValue(UserId());
        FieldAccess.Filter.SetFilter("Table No.", Format(Database::Item));
        FieldAccess.Filter.SetFilter("Field No.", Format(Item.FieldNo("Unit Price")));
        Assert.IsTrue(FieldAccess.First(), 'Owned restriction found.');
        FieldAccess."Restriction Type".SetValue('None');
        FieldAccess.Close();
    end;

    /// <summary>Blocked item needs explicit opt-in, which still uses native Validate.</summary>
    [Test]
    procedure UpdatePrice_Blocked_RequiresExplicitOptIn()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Request.Add('unitPrice', 20);
        InitArgument(TempArgument, Item."No.", Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('blocked');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'No implicit blocked-item update.');
        Request.Add('allowBlocked', true);
        InitArgument(TempArgument, Item."No.", Request);
        PriceWrite.UpdatePrice(TempArgument);
        Item.Get(Item."No.");
        Assert.AreEqual(20, Item."Unit Price", 'Explicit intended blocked-item update.');
    end;

    /// <summary>MissingPrice refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_MissingPrice_ReturnsError()
    begin
        VerifyMalformed('{}');
    end;

    /// <summary>NullPrice refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_NullPrice_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":null}');
    end;

    /// <summary>BooleanPrice refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_BooleanPrice_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":true}');
    end;

    /// <summary>ObjectPrice refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_ObjectPrice_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":{}}');
    end;

    /// <summary>ArrayPrice refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_ArrayPrice_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":[]}');
    end;

    /// <summary>MalformedPrice refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_MalformedPrice_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":"1,2"}');
    end;

    /// <summary>NullOptIn refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_NullOptIn_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":99,"allowBlocked":null}');
    end;

    /// <summary>StringOptIn refuses without a stored change.</summary>
    [Test]
    procedure UpdatePrice_StringOptIn_ReturnsError()
    begin
        VerifyMalformed('{"unitPrice":99,"allowBlocked":"true"}');
    end;

    /// <summary>NoSelection refuses before modification.</summary>
    [Test]
    procedure UpdatePrice_NoSelection_Refuses()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Request.ReadFrom('{"unitPrice":99}');
        InitArgument(TempArgument, '', Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('exactly one item');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'Refusal preserves stored price.');
    end;

    /// <summary>BlankIdentifier refuses before modification.</summary>
    [Test]
    procedure UpdatePrice_BlankIdentifier_Refuses()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Request.ReadFrom('{"unitPrice":99,"itemNo":""}');
        InitArgument(TempArgument, '', Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('nonempty text');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'Refusal preserves stored price.');
    end;

    /// <summary>UnknownField refuses before modification.</summary>
    [Test]
    procedure UpdatePrice_UnknownField_Refuses()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Request.ReadFrom('{"unitPrice":99,"unitCost":44}');
        InitArgument(TempArgument, Item."No.", Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('Unsupported price parameter');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'Refusal preserves stored price.');
    end;

    /// <summary>PriceList refuses before modification.</summary>
    [Test]
    procedure UpdatePrice_PriceList_Refuses()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        CreateItem(Item);
        Request.ReadFrom('{"unitPrice":99,"priceListCode":"NEW"}');
        InitArgument(TempArgument, Item."No.", Request);
        Commit();
        asserterror PriceWrite.UpdatePrice(TempArgument);
        Assert.ExpectedError('Unsupported price parameter');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'Refusal preserves stored price.');
    end;

    local procedure VerifyMalformed(JsonText: Text)
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateItem(Item);
        Request.ReadFrom(JsonText);
        InitArgument(TempArgument, Item."No.", Request);
        PriceWrite.UpdatePrice(TempArgument);
        Response := TempArgument.GetResponseJson();
        Assert.IsTrue(Response.Get('status', Token), 'Error response exists.');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Malformed request refused.');
        Item.Get(Item."No.");
        Assert.AreEqual(10, Item."Unit Price", 'Invalid input preserves the price.');
    end;

    local procedure CreateItem(var Item: Record Item)
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate("Unit Price", 10);
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
