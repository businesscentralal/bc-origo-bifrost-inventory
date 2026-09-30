namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;

/// <summary>Verifies the Msg Contract and Msg Discovery rollout for all Inventory message types.</summary>
codeunit 96921 "Inventory Contract Batch Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    [Test]
    procedure AllInventoryTypes_HaveRequiredContractChapters()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        TypeName: Text;
        Chapter: Text;
    begin
        foreach TypeName in InventoryTypes() do begin
            MessageType := Enum::"Message Type ori"::FromInteger(OrdinalOf(TypeName));
            LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a contract.');
            foreach Chapter in RequiredChapters(TypeName) do
                LibraryAssert.IsTrue(Contract.Contains(Chapter), TypeName + ' must declare chapter ' + Chapter + '.');
        end;
    end;

    [Test]
    procedure AllInventoryTypes_HaveBilingualDiscovery()
    var
        MessageType: Enum "Message Type ori";
        Discovery: Interface "Msg Discovery ori";
        TypeName: Text;
    begin
        foreach TypeName in InventoryTypes() do begin
            MessageType := Enum::"Message Type ori"::FromInteger(OrdinalOf(TypeName));
            Discovery := MessageType;
            LibraryAssert.IsFalse(Discovery.GetKeywords() = '', TypeName + ' must have discovery keywords.');
            LibraryAssert.IsFalse(Discovery.GetSelectionDescription() = '', TypeName + ' must have a selection description.');
        end;
    end;

    [Test]
    procedure InventoryEffects_MatchOperation()
    begin
        AssertEffect('Item.Attribute.Get', 'read');
        AssertEffect('Item.Attribute.Create', 'write');
        AssertEffect('Item.Attribute.Update', 'write');
        AssertEffect('Item.AttributeDefinition.Create', 'write');
        AssertEffect('Inventory.TransferOrder.Create', 'write');
        AssertEffect('Inventory.TransferOrder.Release', 'write');
        AssertEffect('Inventory.TransferOrder.Reopen', 'write');
        AssertEffect('Inventory.TransferOrder.Post', 'irreversible');
        AssertEffect('Inventory.TransferOrder.PreviewPost', 'read');
        AssertEffect('Inventory.TransferOrder.Statistics', 'read');
        AssertEffect('Inventory.AssemblyOrder.Create', 'write');
        AssertEffect('Inventory.AssemblyOrder.RefreshLines', 'write');
        AssertEffect('Inventory.AssemblyOrder.Release', 'write');
        AssertEffect('Inventory.AssemblyOrder.Reopen', 'write');
        AssertEffect('Inventory.AssemblyOrder.Post', 'irreversible');
        AssertEffect('Inventory.AssemblyOrder.PreviewPost', 'read');
        AssertEffect('Inventory.AssemblyOrder.Statistics', 'read');
    end;

    local procedure AssertEffect(TypeName: Text; Expected: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonObject;
        EffectToken: JsonToken;
    begin
        MessageType := Enum::"Message Type ori"::FromInteger(OrdinalOf(TypeName));
        ContractMgt.GetContract(MessageType, Contract);
        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Effect.Get('effect', EffectToken);
        LibraryAssert.AreEqual(Expected, EffectToken.AsValue().AsText(), TypeName + ' effect mismatch.');
    end;

    local procedure InventoryTypes() Types: List of [Text]
    begin
        Types.Add('Item.Attribute.Get');
        Types.Add('Item.Attribute.Create');
        Types.Add('Item.Attribute.Update');
        Types.Add('Item.AttributeDefinition.Create');
        Types.Add('Inventory.TransferOrder.Create');
        Types.Add('Inventory.TransferOrder.Release');
        Types.Add('Inventory.TransferOrder.Reopen');
        Types.Add('Inventory.TransferOrder.Post');
        Types.Add('Inventory.TransferOrder.PreviewPost');
        Types.Add('Inventory.TransferOrder.Statistics');
        Types.Add('Inventory.AssemblyOrder.Create');
        Types.Add('Inventory.AssemblyOrder.RefreshLines');
        Types.Add('Inventory.AssemblyOrder.Release');
        Types.Add('Inventory.AssemblyOrder.Reopen');
        Types.Add('Inventory.AssemblyOrder.Post');
        Types.Add('Inventory.AssemblyOrder.PreviewPost');
        Types.Add('Inventory.AssemblyOrder.Statistics');
    end;

    local procedure RequiredChapters(TypeName: Text) Chapters: List of [Text]
    begin
        Chapters.Add('envelope');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('metering');
        Chapters.Add('related');
        if TypeName <> 'Item.AttributeDefinition.Create' then
            Chapters.Add('target');
        if TypeName in ['Item.Attribute.Get', 'Item.Attribute.Create', 'Item.Attribute.Update', 'Item.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.TransferOrder.Post', 'Inventory.TransferOrder.PreviewPost', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.Post'] then
            Chapters.Add('parameters');
        if TypeName in ['Inventory.TransferOrder.Create', 'Inventory.TransferOrder.PreviewPost', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.PreviewPost'] then
            Chapters.Add('workflow');
        if TypeName in ['Item.Attribute.Get', 'Item.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.AssemblyOrder.Create'] then
            Chapters.Add('examples');
        Chapters.Add('overview');
    end;

    local procedure OrdinalOf(TypeName: Text): Integer
    var
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Ordinals: List of [Integer];
    begin
        Names := MessageType.Names();
        Ordinals := MessageType.Ordinals();
        exit(Ordinals.Get(Names.IndexOf(TypeName)));
    end;
}