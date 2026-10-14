namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>Verifies the Msg Contract and Msg Discovery rollout for all Inventory message types.</summary>
codeunit 96921 "Inventory Contract Batch Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryAssert: Codeunit System.TestLibraries.Utilities."Library Assert";

    /// <summary>Shipping Help resolves meaningful UndoShipment schemas and errors through the registered contract reader.</summary>
    [Test]
    procedure UndoShipment_PublicHelp_DeclaresNativeFieldsAndErrors()
    begin
        // Issues #27/#30/#39/#40 | Time: no date dependence | Risk: public Help contract drift.
        AssertNativeHelp('Inventory.Transfer.UndoShipment', 'status:string,documentNo:string,undoneLineCount:integer,result:array', 5);
    end;

    /// <summary>Shipping Help resolves meaningful UndoAssembly schemas and errors through the registered contract reader.</summary>
    [Test]
    procedure UndoAssembly_PublicHelp_DeclaresNativeFieldsAndErrors()
    begin
        // Issues #27/#30/#39/#40 | Time: no date dependence | Risk: public Help contract drift.
        AssertNativeHelp('Inventory.Assembly.UndoPost', 'status:string,documentNo:string,reversed:boolean,recreateOrder:boolean,orderNo:string,orderExists:boolean', 5);
    end;

    /// <summary>Shipping Help resolves meaningful UndoReceipt schemas and errors through the registered contract reader.</summary>
    [Test]
    procedure UndoReceipt_PublicHelp_DeclaresNativeFieldsAndErrors()
    begin
        // Issues #27/#30/#39/#40 | Time: no date dependence | Risk: public Help contract drift.
        AssertNativeHelp('Inventory.Transfer.UndoReceipt', 'status:string,error:string,help:string', 5);
    end;

    /// <summary>Shipping Help resolves meaningful ApplicationGet schemas and errors through the registered contract reader.</summary>
    [Test]
    procedure ApplicationGet_PublicHelp_DeclaresNativeFieldsAndErrors()
    begin
        // Issues #27/#30/#39/#40 | Time: no date dependence | Risk: public Help contract drift.
        AssertNativeHelp('Inventory.ItemApplication.Get', 'status:string,itemLedgerEntryNo:integer,entries:array,count:integer', 4);
    end;

    /// <summary>Shipping Help resolves meaningful ApplicationUnapply schemas and errors through the registered contract reader.</summary>
    [Test]
    procedure ApplicationUnapply_PublicHelp_DeclaresNativeFieldsAndErrors()
    begin
        // Issues #27/#30/#39/#40 | Time: no date dependence | Risk: public Help contract drift.
        AssertNativeHelp('Inventory.ItemApplication.Unapply', 'status:string,itemLedgerEntryNo:integer,unappliedCount:integer,adjustmentRequired:boolean', 3);
    end;

    /// <summary>Shipping Help resolves meaningful ApplicationReapply schemas and errors through the registered contract reader.</summary>
    [Test]
    procedure ApplicationReapply_PublicHelp_DeclaresNativeFieldsAndErrors()
    begin
        // Issues #27/#30/#39/#40 | Time: no date dependence | Risk: public Help contract drift.
        AssertNativeHelp('Inventory.ItemApplication.Reapply', 'status:string,outboundEntryNo:integer,inboundEntryNo:integer,quantity:decimal,adjustmentRequired:boolean', 3);
    end;

    /// <summary>Repeated interface reads replace reused buffers, including explicitly absent chapters.</summary>
    [Test]
    procedure NativeHelp_ReusedOutput_DoesNotLeakOtherChapters()
    var
        Contract: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Name: Text;
        ObjectChapter: JsonObject;
        ArrayChapter: JsonArray;
        Keys: List of [Text];
        RepeatRead: Integer;
    begin
        Names := NativeHelpTypes();
        foreach Name in Names do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(Name));
            Contract := MessageType;
            for RepeatRead := 1 to 2 do begin
                ObjectChapter.Add('stale', true);
                Contract.GetEnvelope(ObjectChapter);
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), Name + ' envelope replaces output.');
                ArrayChapter.Add('stale');
                Contract.GetTarget(ArrayChapter);
                AssertNoStaleArray(ArrayChapter);
                ArrayChapter.Add('stale');
                Contract.GetParameters(ArrayChapter);
                AssertNoStaleArray(ArrayChapter);
                ObjectChapter.Add('stale', true);
                Contract.GetResponse(ObjectChapter);
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), Name + ' response replaces output.');
                ArrayChapter.Add('stale');
                Contract.GetErrors(ArrayChapter);
                AssertNoStaleArray(ArrayChapter);
                ObjectChapter.Add('stale', true);
                Contract.GetEffect(ObjectChapter);
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), Name + ' effect replaces output.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsFalse(Contract.GetMetering(ObjectChapter), Name + ' adds no metering.');
                Keys := ObjectChapter.Keys();
                LibraryAssert.AreEqual(0, Keys.Count(), Name + ' clears metering output.');
                ArrayChapter.Add('stale');
                Contract.GetRelated(ArrayChapter);
                AssertNoStaleArray(ArrayChapter);
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsFalse(Contract.GetWorkflow(ObjectChapter), Name + ' has no workflow chapter.');
                Keys := ObjectChapter.Keys();
                LibraryAssert.AreEqual(0, Keys.Count(), Name + ' clears workflow output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsFalse(Contract.GetExamples(ArrayChapter), Name + ' has no examples chapter.');
                LibraryAssert.AreEqual(0, ArrayChapter.Count(), Name + ' clears examples output.');
            end;
        end;
    end;

    /// <summary>The contract permits canonical and legacy selectors with their actual conditional requirements.</summary>
    [Test]
    procedure ApplicationHelp_Parameters_PreserveLegacySelectors()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Parameter: JsonObject;
        Token: JsonToken;
    begin
        ContractMgt.GetContract("Message Type ori"::"Inventory.ItemApplication.Unapply", Contract);
        GetNamedMember(Contract, 'parameters', 'name', 'entryNo', Parameter);
        AssertJsonText(Parameter, 'type', 'integer');
        GetNamedMember(Contract, 'parameters', 'name', 'itemLedgerEntryNo', Parameter);
        Parameter.Get('required', Token);
        LibraryAssert.IsFalse(Token.AsValue().AsBoolean(), 'Legacy entryNo is an alternative selector.');
        ContractMgt.GetContract("Message Type ori"::"Inventory.ItemApplication.Reapply", Contract);
        GetNamedMember(Contract, 'parameters', 'name', 'itemLedgerEntryNo', Parameter);
        GetNamedMember(Contract, 'parameters', 'name', 'applyToEntryNo', Parameter);
        GetNamedMember(Contract, 'parameters', 'name', 'quantity', Parameter);
        AssertJsonText(Parameter, 'type', 'decimal');
        Parameter.Get('description', Token);
        LibraryAssert.IsTrue(Token.AsValue().AsText().Contains('canonical pair'), 'Conditional quantity requirement must be documented.');
    end;

    local procedure NativeHelpTypes() Names: List of [Text]
    begin
        Names.Add('Inventory.Transfer.UndoShipment');
        Names.Add('Inventory.Assembly.UndoPost');
        Names.Add('Inventory.Transfer.UndoReceipt');
        Names.Add('Inventory.ItemApplication.Get');
        Names.Add('Inventory.ItemApplication.Unapply');
        Names.Add('Inventory.ItemApplication.Reapply');
    end;

    local procedure AssertNoStaleArray(Chapter: JsonArray)
    var
        Token: JsonToken;
    begin
        foreach Token in Chapter do
            LibraryAssert.IsTrue(Token.IsObject(), 'Contract entries must be objects; stale scalar output leaked.');
    end;

    local procedure AssertNativeHelp(TypeName: Text; ExpectedFields: Text; ErrorCount: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Response: JsonObject;
        Field: JsonObject;
        ErrorEntry: JsonObject;
        Token: JsonToken;
        Value: JsonToken;
        Fields: List of [Text];
        Parts: List of [Text];
        ExpectedField: Text;
        RepeatRead: Integer;
        TextErrorCount: Integer;
    begin
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        for RepeatRead := 1 to 2 do begin
            Contract.Add('stale', true);
            LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' public Help contract exists.');
            LibraryAssert.IsFalse(Contract.Contains('stale'), 'Public reader replaces previous output.');
            LibraryAssert.IsTrue(Contract.Get('response', Token), 'Response chapter exists.');
            Response := Token.AsObject();
            AssertJsonText(Response, 'contentType', 'text/json');
            LibraryAssert.IsTrue(Response.Get('fields', Token), 'Response declares semantic fields, not an empty object.');
            Fields := ExpectedFields.Split(',');
            LibraryAssert.AreEqual(Fields.Count(), Token.AsArray().Count(), TypeName + ' exact response schema.');
            foreach ExpectedField in Fields do begin
                Parts := ExpectedField.Split(':');
                GetNamedMember(Response, 'fields', 'name', Parts.Get(1), Field);
                AssertJsonText(Field, 'type', Parts.Get(2));
                LibraryAssert.IsTrue(Field.Get('description', Value), 'Each native field has a description.');
                LibraryAssert.AreNotEqual('', Value.AsValue().AsText(), 'Native field description cannot be empty.');
            end;
            LibraryAssert.IsTrue(Contract.Get('errors', Token), 'Error chapter exists.');
            LibraryAssert.AreEqual(ErrorCount, Token.AsArray().Count(), TypeName + ' meaningful native errors.');
            TextErrorCount := 0;
            foreach Token in Token.AsArray() do begin
                ErrorEntry := Token.AsObject();
                LibraryAssert.IsTrue(ErrorEntry.Get('when', Value), 'Error must describe its condition.');
                LibraryAssert.AreNotEqual('', Value.AsValue().AsText(), 'Error condition cannot be empty.');
                LibraryAssert.IsTrue(ErrorEntry.Get('fix', Value), 'Error must describe the next action.');
                LibraryAssert.AreNotEqual('', Value.AsValue().AsText(), 'Error next action cannot be empty.');
                if ErrorEntry.Get('error', Value) then begin
                    TextErrorCount += 1;
                    LibraryAssert.AreNotEqual('', Value.AsValue().AsText(), 'Text errors must declare a pattern.');
                    if TypeName <> 'Inventory.ItemApplication.Get' then
                        LibraryAssert.IsFalse(ErrorEntry.Contains('code'), 'RespondWithError(text) does not invent a typed error code.');
                end;
            end;
            LibraryAssert.IsTrue(TextErrorCount > 0, 'Native refusal paths must be documented.');
            GetNamedMember(Contract, 'errors', 'code', 'PermissionDenied', ErrorEntry);
            GetNamedMember(Contract, 'errors', 'code', 'InvalidParameter', ErrorEntry);
        end;
    end;

    /// <summary>The touched undo/application discovery must actually switch language, not merely be nonempty.</summary>
    [Test]
    procedure NativeUndoApplication_DiscoveryChangesToIcelandic()
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        Names: List of [Text];
        Name: Text;
        EnglishKeywords: Text;
        EnglishSelection: Text;
        IcelandicKeywords: Text;
        IcelandicSelection: Text;
        PreviousLanguage: Integer;
    begin
        Names.Add('Inventory.Transfer.UndoShipment');
        Names.Add('Inventory.Transfer.UndoReceipt');
        Names.Add('Inventory.Assembly.UndoPost');
        Names.Add('Inventory.ItemApplication.Get');
        Names.Add('Inventory.ItemApplication.Unapply');
        Names.Add('Inventory.ItemApplication.Reapply');
        PreviousLanguage := GlobalLanguage();
        foreach Name in Names do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(Name));
            Discovery := MessageType;
            GlobalLanguage(1033);
            EnglishKeywords := Discovery.GetKeywords();
            EnglishSelection := Discovery.GetSelectionDescription();
            GlobalLanguage(1039);
            IcelandicKeywords := Discovery.GetKeywords();
            IcelandicSelection := Discovery.GetSelectionDescription();
            GlobalLanguage(PreviousLanguage);
            LibraryAssert.IsFalse(EnglishKeywords = IcelandicKeywords, Name + ' needs actual Icelandic keywords.');
            LibraryAssert.IsFalse(EnglishSelection = IcelandicSelection, Name + ' needs actual Icelandic selection text.');
            LibraryAssert.IsFalse(IcelandicKeywords = '', Name + ' cannot have empty Icelandic keywords.');
        end;
    end;

    /// <summary>Application response metadata names the fields actually emitted by the native write contracts.</summary>
    [Test]
    procedure NativeApplication_ResponseContractsMatchActualFields()
    var
        Reapply: Codeunit "Item Appl. Reapply Impl ori";
        Unapply: Codeunit "Item Appl. Unapply Impl ori";
        Response: JsonObject;
    begin
        LibraryAssert.IsTrue(Reapply.GetResponse(Response), 'Reapply response chapter exists.');
        LibraryAssert.IsTrue(Response.Contains('outboundEntryNo'), 'Response identifies outbound.');
        LibraryAssert.IsTrue(Response.Contains('inboundEntryNo'), 'Response identifies inbound.');
        LibraryAssert.IsTrue(Response.Contains('quantity'), 'Response identifies applied base quantity.');
        LibraryAssert.IsTrue(Response.Contains('adjustmentRequired'), 'Response declares pending adjustment.');
        Clear(Response);
        LibraryAssert.IsTrue(Unapply.GetResponse(Response), 'Unapply response chapter exists.');
        LibraryAssert.IsTrue(Response.Contains('itemLedgerEntryNo'), 'Unapply identifies the ledger selector.');
        LibraryAssert.IsTrue(Response.Contains('unappliedCount'), 'Unapply reports actual application count.');
    end;

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
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
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
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Discovery := MessageType;
            LibraryAssert.IsFalse(Discovery.GetKeywords() = '', TypeName + ' must have discovery keywords.');
            LibraryAssert.IsFalse(Discovery.GetSelectionDescription() = '', TypeName + ' must have a selection description.');
        end;
    end;

    /// <summary>Fails when an Inventory help contract names an empty or unknown related message type.</summary>
    [Test]
    procedure AllInventoryTypes_RelatedNamesExist()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        RelatedToken: JsonToken;
        EntryToken: JsonToken;
        RelatedEntries: JsonArray;
        NameToken: JsonToken;
        UseToken: JsonToken;
        Entry: JsonObject;
        Catalogue: List of [Text];
        Walked: List of [Text];
        ItemJournalNames: List of [Text];
        AppTypes: List of [Text];
        CostGetNames: List of [Text];
        TypeName: Text;
        AppType: Text;
        RelatedName: Text;
        EntryJson: Text;
        CheckedCount: Integer;
        SawCostGet: Boolean;
    begin
        // [GIVEN] Every registered Inventory message type.
        // [WHEN] The help contract reader returns the related chapter.
        Catalogue := MessageType.Names();
        foreach TypeName in Catalogue do
            if TypeName.StartsWith('Inventory.') then begin
                Walked.Add(TypeName);
                if TypeName.StartsWith('Inventory.ItemJournal.') then
                    ItemJournalNames.Add(TypeName);
                MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
                Clear(Contract);
                LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), TypeName + ' must declare a help contract.');
                CheckedCount += 1;
                if TypeName = 'Inventory.Cost.Get' then
                    SawCostGet := true;
                if Contract.Get('related', RelatedToken) then begin
                    LibraryAssert.IsTrue(RelatedToken.IsArray(), TypeName + ' related chapter must be an array.');
                    RelatedEntries := RelatedToken.AsArray();
                    foreach EntryToken in RelatedEntries do begin
                        EntryToken.WriteTo(EntryJson);
                        LibraryAssert.IsTrue(EntryToken.IsObject(), TypeName + ' related entry must be an object. ' + EntryJson);
                        Entry := EntryToken.AsObject();
                        LibraryAssert.IsTrue(Entry.Get('name', NameToken), TypeName + ' related entry must have a name. ' + EntryJson);
                        LibraryAssert.IsTrue(NameToken.IsValue(), TypeName + ' related name must be text. ' + EntryJson);
                        RelatedName := NameToken.AsValue().AsText();
                        LibraryAssert.AreNotEqual('', RelatedName, TypeName + ' related name must not be empty.');
                        LibraryAssert.IsTrue(Catalogue.Contains(RelatedName), TypeName + ' names related message type ' + RelatedName + ', which does not exist.');
                        LibraryAssert.IsTrue(Entry.Get('useInsteadWhen', UseToken), TypeName + ' related entry must say when to use ' + RelatedName + '.');
                        LibraryAssert.IsTrue(UseToken.IsValue(), TypeName + ' useInsteadWhen must be text.');
                        LibraryAssert.AreNotEqual('', UseToken.AsValue().AsText(), TypeName + ' useInsteadWhen must not be empty.');
                        if TypeName = 'Inventory.Cost.Get' then
                            CostGetNames.Add(RelatedName);
                    end;
                end;
            end;
        // [THEN] Foundation's four item journal types are present, and the other walked names are this app's registered types.
        LibraryAssert.IsTrue(Walked.Contains('Inventory.Tracking.Get'), 'Inventory.Tracking.Get is registered and its complete help contract was walked.');
        LibraryAssert.IsTrue(Walked.Contains('Inventory.ItemJournal.Check'), 'Inventory.ItemJournal.Check is registered.');
        LibraryAssert.IsTrue(Walked.Contains('Inventory.ItemJournal.Create'), 'Inventory.ItemJournal.Create is registered.');
        LibraryAssert.IsTrue(Walked.Contains('Inventory.ItemJournal.Post'), 'Inventory.ItemJournal.Post is registered.');
        LibraryAssert.IsTrue(Walked.Contains('Inventory.ItemJournal.PreviewPost'), 'Inventory.ItemJournal.PreviewPost is registered.');
        LibraryAssert.AreEqual(4, ItemJournalNames.Count(), 'Exactly four Inventory.ItemJournal types are registered.');
        LibraryAssert.AreEqual(51, CheckedCount - ItemJournalNames.Count(), 'This app registers 51 Inventory types.');
        AppTypes := AppRegisteredInventoryTypes();
        LibraryAssert.AreEqual(51, AppTypes.Count(), 'The registered Inventory type list for this app has 51 names.');
        foreach AppType in AppTypes do
            LibraryAssert.IsTrue(Walked.Contains(AppType), AppType + ' is registered in this app but was not walked.');
        foreach TypeName in Walked do
            if not TypeName.StartsWith('Inventory.ItemJournal.') then
                LibraryAssert.IsTrue(AppTypes.Contains(TypeName), TypeName + ' is not registered by this app.');
        LibraryAssert.IsTrue(SawCostGet, 'Inventory.Cost.Get is a registered message type.');
        LibraryAssert.AreEqual(2, CostGetNames.Count(), 'Inventory.Cost.Get names two related message types.');
        LibraryAssert.IsTrue(CostGetNames.Contains('Inventory.AdjustCost.Run'), 'Inventory.Cost.Get relates to Inventory.AdjustCost.Run.');
        LibraryAssert.IsTrue(CostGetNames.Contains('Inventory.Revaluation.Calculate'), 'Inventory.Cost.Get relates to Inventory.Revaluation.Calculate.');
    end;

    /// <summary>An empty physical inventory batch is PreconditionFailed on the contract and at runtime.</summary>
    [Test]
    procedure PhysInventoryPost_EmptyBatch_ReturnsPreconditionFailed()
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Helper: Codeunit "Transfer Order Test Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        Contract: JsonObject;
        ErrorEntry: JsonObject;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] The help contract names PreconditionFailed for an empty batch.
        LibraryAssert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Inventory.PhysInventory.Post", Contract), 'Inventory.PhysInventory.Post must declare a contract.');
        GetNamedMember(Contract, 'errors', 'code', 'PreconditionFailed', ErrorEntry);
        // [WHEN] The registered post type runs against a physical inventory batch with no lines.
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::"Phys. Inventory");
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::"Phys. Inventory", ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        RequestJson.Add('journalTemplateName', ItemJournalTemplate.Name);
        RequestJson.Add('journalBatchName', ItemJournalBatch.Name);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventory.Post", RequestJson, ResponseJson);
        // [THEN] The response carries PreconditionFailed for journalBatchName.
        LibraryAssert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        LibraryAssert.AreEqual('Error', Token.AsValue().AsText(), 'An empty batch is not posted.');
        LibraryAssert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        LibraryAssert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Empty batch code.');
        LibraryAssert.IsTrue(ResponseJson.Get('parameter', Token), 'parameter missing');
        LibraryAssert.AreEqual('journalBatchName', Token.AsValue().AsText(), 'parameter');
        LibraryAssert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        LibraryAssert.AreNotEqual('', Token.AsValue().AsText(), 'nextStep');
    end;

    [Test]
    procedure InventoryEffects_MatchOperation()
    begin
        AssertEffect('Inventory.Attribute.Get', 'read');
        AssertEffect('Inventory.Attribute.Create', 'write');
        AssertEffect('Inventory.Attribute.Update', 'write');
        AssertEffect('Inventory.AttributeDefinition.Create', 'write');
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
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        ContractMgt.GetContract(MessageType, Contract);
        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Effect.Get('effect', EffectToken);
        LibraryAssert.AreEqual(Expected, EffectToken.AsValue().AsText(), TypeName + ' effect mismatch.');
    end;

    local procedure InventoryTypes() Types: List of [Text]
    begin
        Types.Add('Inventory.Attribute.Get');
        Types.Add('Inventory.Attribute.Create');
        Types.Add('Inventory.Attribute.Update');
        Types.Add('Inventory.AttributeDefinition.Create');
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

    local procedure AppRegisteredInventoryTypes() Types: List of [Text]
    begin
        Types.Add('Inventory.Attribute.Get');
        Types.Add('Inventory.Attribute.Create');
        Types.Add('Inventory.Attribute.Update');
        Types.Add('Inventory.AttributeDefinition.Create');
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
        Types.Add('Inventory.AdjustCost.Run');
        Types.Add('Inventory.Cost.Get');
        Types.Add('Inventory.Cost.Update');
        Types.Add('Inventory.CostToGL.Post');
        Types.Add('Inventory.CostToGL.Test');
        Types.Add('Inventory.Tracking.Get');
        Types.Add('Inventory.Tracking.Assign');
        Types.Add('Inventory.Tracking.Delete');
        Types.Add('Inventory.TrackingAvailability.Get');
        Types.Add('Inventory.Transfer.UndoShipment');
        Types.Add('Inventory.Transfer.UndoReceipt');
        Types.Add('Inventory.Assembly.UndoPost');
        Types.Add('Inventory.ItemApplication.Get');
        Types.Add('Inventory.ItemApplication.Unapply');
        Types.Add('Inventory.ItemApplication.Reapply');
        Types.Add('Inventory.Reclassification.Check');
        Types.Add('Inventory.Reclassification.PreviewPost');
        Types.Add('Inventory.Reclassification.Post');
        Types.Add('Inventory.Period.Get');
        Types.Add('Inventory.Period.Close');
        Types.Add('Inventory.Period.Reopen');
        Types.Add('Inventory.Price.Update');
        Types.Add('Inventory.Revaluation.Calculate');
        Types.Add('Inventory.Revaluation.Post');
        Types.Add('Inventory.Revaluation.PreviewPost');
        Types.Add('Inventory.PhysInventory.Check');
        Types.Add('Inventory.PhysInventory.PreviewPost');
        Types.Add('Inventory.PhysInventory.RecordCount');
        Types.Add('Inventory.Reservation.Get');
        Types.Add('Inventory.Reservation.Create');
        Types.Add('Inventory.Reservation.Cancel');
        Types.Add('Inventory.PhysInventory.Calculate');
        Types.Add('Inventory.PhysInventory.Record');
        Types.Add('Inventory.PhysInventory.Post');
    end;

    local procedure RequiredChapters(TypeName: Text) Chapters: List of [Text]
    begin
        Chapters.Add('envelope');
        Chapters.Add('response');
        Chapters.Add('errors');
        Chapters.Add('effect');
        Chapters.Add('metering');
        Chapters.Add('related');
        if TypeName <> 'Inventory.AttributeDefinition.Create' then
            Chapters.Add('target');
        if TypeName in ['Inventory.Attribute.Get', 'Inventory.Attribute.Create', 'Inventory.Attribute.Update', 'Inventory.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.TransferOrder.Post', 'Inventory.TransferOrder.PreviewPost', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.Post'] then
            Chapters.Add('parameters');
        if TypeName in ['Inventory.TransferOrder.Create', 'Inventory.TransferOrder.PreviewPost', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.PreviewPost'] then
            Chapters.Add('workflow');
        if TypeName in ['Inventory.Attribute.Get', 'Inventory.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.AssemblyOrder.Create'] then
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
        LibraryAssert.IsTrue(Names.Contains(TypeName), 'Message catalogue does not register ' + TypeName + '.');
        exit(Ordinals.Get(Names.IndexOf(TypeName)));
    end;

    /// <summary>Resolves the real Get catalogue entry and checks its existing read chapters.</summary>
    [Test]
    procedure AttributeGet_RegisteredContract_DeclaresReadChapters()
    begin
        AssertAttributeContract('Inventory.Attribute.Get', 10036893,
            'includeUnassigned:boolean:false,attributeNames:array:false,attributeIds:array:false',
            'status:string,items:array', 'read', true, 5, 3, 1,
            'Reads attribute definitions and assigned values for one or more Items without changing Business Central data.', '');
    end;

    /// <summary>Resolves the real Create catalogue entry and checks required mapping inputs.</summary>
    [Test]
    procedure AttributeCreate_RegisteredContract_DeclaresWriteChapters()
    begin
        AssertAttributeContract('Inventory.Attribute.Create', 10036894,
            'attributes:array:true,allowBlocked:boolean:false', 'status:string,itemNo:string,results:array',
            'write', false, 7, 2, 0,
            'Assigns one or more attribute values to an Item. Existing equal mappings are idempotent; conflicts require overwrite or the update message.',
            'Attribute values are typed according to the definition. Set createValueIfMissing on an attribute object when an Option value may need to be created. Blocked items require allowBlocked.');
    end;

    /// <summary>Resolves the real Update catalogue entry and preserves existing mapping errors.</summary>
    [Test]
    procedure AttributeUpdate_RegisteredContract_DeclaresWriteChapters()
    begin
        AssertAttributeContract('Inventory.Attribute.Update', 10036895,
            'attributes:array:true,allowBlocked:boolean:false', 'status:string,itemNo:string,results:array',
            'write', false, 6, 2, 0,
            'Changes existing Item attribute mappings and returns the resulting values. Use Item.Attribute.Create when a mapping does not exist.',
            'Update is intentionally limited to mappings that already exist. The operation is isolated through its write process.');
    end;

    /// <summary>Resolves the real Definition catalogue entry without an Item or document target.</summary>
    [Test]
    procedure AttributeDefinition_RegisteredContract_HasNoTarget()
    begin
        AssertAttributeContract('Inventory.AttributeDefinition.Create', 10036896,
            'name:string:true,type:string:true,unitOfMeasure:string:false,optionValues:array:false',
            'status:string,attributeId:integer,attributeName:string,type:string,createdValues:array',
            'write', false, 4, 2, 1,
            'Creates an Item Attribute definition and optional Option values independently of an Item.', '');
    end;

    local procedure AssertAttributeContract(TypeName: Text; ExpectedOrdinal: Integer; ParameterSpec: Text; ResponseSpec: Text; ExpectedEffect: Text; Idempotent: Boolean; ErrorCount: Integer; RelatedCount: Integer; ExampleCount: Integer; ExpectedOverview: Text; ExpectedNotes: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        ContractInterface: Interface "Msg Contract ori";
        Contract: JsonObject;
        Envelope: JsonObject;
        Response: JsonObject;
        Effect: JsonObject;
        Workflow: JsonObject;
        Metering: JsonObject;
        Parameters: JsonArray;
        Target: JsonArray;
        Errors: JsonArray;
        Related: JsonArray;
        Examples: JsonArray;
        Token: JsonToken;
        Overview: Text;
        Notes: Text;
    begin
        LibraryAssert.AreEqual(ExpectedOrdinal, OrdinalOf(TypeName), 'Exact registered Attribute ordinal.');
        MessageType := Enum::"Message Type ori".FromInteger(ExpectedOrdinal);
        ContractInterface := MessageType;
        LibraryAssert.IsTrue(ContractInterface.GetParameters(Parameters), 'Attribute parameters chapter is present.');
        AssertAttributeParameters(Parameters, ParameterSpec);
        LibraryAssert.IsTrue(ContractInterface.GetResponse(Response), 'Attribute response chapter is present.');
        AssertJsonText(Response, 'contentType', 'text/json');
        Response.Get('fields', Token);
        AssertAttributeFields(Token.AsArray(), ResponseSpec);
        LibraryAssert.IsTrue(ContractInterface.GetEffect(Effect), 'Attribute effect chapter is present.');
        AssertJsonText(Effect, 'effect', ExpectedEffect);
        Effect.Get('idempotent', Token);
        LibraryAssert.AreEqual(Idempotent, Token.AsValue().AsBoolean(), 'Exact idempotence declaration.');
        LibraryAssert.IsTrue(ContractInterface.GetEnvelope(Envelope), 'Attribute envelope chapter is present.');
        AssertAttributeTarget(ContractInterface, Envelope, TypeName, Target);
        LibraryAssert.IsTrue(ContractInterface.GetErrors(Errors), 'Existing error chapter is present.');
        LibraryAssert.AreEqual(ErrorCount, Errors.Count(), 'Exact existing error count.');
        AssertAttributeError(Errors, TypeName);
        LibraryAssert.IsTrue(ContractInterface.GetRelated(Related), 'Existing related chapter is present.');
        LibraryAssert.AreEqual(RelatedCount, Related.Count(), 'Exact existing related count.');
        // Related names are the registered Inventory.Attribute message types. Legacy selectors return the same chapter.
        LibraryAssert.AreEqual(ExampleCount > 0, ContractInterface.GetExamples(Examples), 'Exact example chapter presence.');
        LibraryAssert.AreEqual(ExampleCount, Examples.Count(), 'Exact existing example count.');
        LibraryAssert.IsTrue(ContractInterface.GetOverview(Overview), 'Overview is present.');
        LibraryAssert.AreEqual(ExpectedOverview, Overview, 'Exact existing overview.');
        LibraryAssert.AreEqual(ExpectedNotes <> '', ContractInterface.GetNotes(Notes), 'Exact notes chapter presence.');
        LibraryAssert.AreEqual(ExpectedNotes, Notes, 'Exact existing notes.');
        LibraryAssert.IsFalse(ContractInterface.GetWorkflow(Workflow), 'Attribute workflow is absent.');
        LibraryAssert.IsFalse(ContractInterface.GetMetering(Metering), 'Attribute app adds no metering chapter.');
        LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Real contract reader resolves the catalogue interface.');
        LibraryAssert.IsFalse(Contract.Contains('workflow'), 'Reader must omit workflow.');
        LibraryAssert.AreEqual(ExpectedNotes <> '', Contract.Contains('notes'), 'Reader notes presence.');
        LibraryAssert.IsTrue(Contract.Contains('metering'), 'Foundation composes metering even without app additions.');
        AssertAttributeLegacyPayloads(TypeName, Contract);
    end;

    local procedure AssertAttributeParameters(Parameters: JsonArray; Spec: Text)
    var
        Specs: List of [Text];
        Parts: List of [Text];
        Entry: JsonObject;
        Token: JsonToken;
        Expected: Text;
        Index: Integer;
    begin
        Specs := Spec.Split(',');
        LibraryAssert.AreEqual(Specs.Count(), Parameters.Count(), 'Exact parameter count; other chapters cannot donate fields.');
        Index := 0;
        foreach Expected in Specs do begin
            Parts := Expected.Split(':');
            Parameters.Get(Index, Token);
            Entry := Token.AsObject();
            AssertJsonText(Entry, 'name', Parts.Get(1));
            AssertJsonText(Entry, 'type', Parts.Get(2));
            Entry.Get('required', Token);
            LibraryAssert.AreEqual(Parts.Get(3) = 'true', Token.AsValue().AsBoolean(), 'Exact required flag.');
            LibraryAssert.IsFalse(Entry.Contains('default'), 'Existing helper has no typed default field; preserve the schema.');
            if Parts.Get(1) in ['includeUnassigned', 'allowBlocked'] then begin
                Entry.Get('description', Token);
                LibraryAssert.IsTrue(Token.AsValue().AsText().Contains('Default false.'), 'Existing false default description is preserved.');
            end;
            Index += 1;
        end;
    end;

    local procedure AssertAttributeFields(Fields: JsonArray; Spec: Text)
    var
        Specs: List of [Text];
        Parts: List of [Text];
        Entry: JsonObject;
        Token: JsonToken;
        Expected: Text;
        Index: Integer;
    begin
        Specs := Spec.Split(',');
        LibraryAssert.AreEqual(Specs.Count(), Fields.Count(), 'Exact response field count.');
        Index := 0;
        foreach Expected in Specs do begin
            Parts := Expected.Split(':');
            Fields.Get(Index, Token);
            Entry := Token.AsObject();
            AssertJsonText(Entry, 'name', Parts.Get(1));
            AssertJsonText(Entry, 'type', Parts.Get(2));
            Index += 1;
        end;
    end;

    local procedure AssertAttributeTarget(ContractInterface: Interface "Msg Contract ori"; Envelope: JsonObject; TypeName: Text; var Target: JsonArray)
    var
        Subject: JsonObject;
        Entry: JsonObject;
        Token: JsonToken;
        Sources: List of [Text];
        Source: Text;
        Index: Integer;
    begin
        Envelope.Get('subject', Token);
        Subject := Token.AsObject();
        if TypeName = 'Inventory.AttributeDefinition.Create' then begin
            AssertJsonText(Subject, 'use', 'notUsed');
            Subject.Get('forms', Token);
            LibraryAssert.AreEqual(0, Token.AsArray().Count(), 'Definition has no subject forms.');
            LibraryAssert.IsFalse(ContractInterface.GetTarget(Target), 'Definition target is absent.');
            LibraryAssert.AreEqual(0, Target.Count(), 'Definition does not fall back to document identifiers.');
            exit;
        end;
        AssertJsonText(Subject, 'use', 'optional');
        LibraryAssert.IsTrue(ContractInterface.GetTarget(Target), 'Item target is present.');
        LibraryAssert.AreEqual(5, Target.Count(), 'Exact Item target count.');
        Sources.Add('subject');
        Sources.Add('subject');
        Sources.Add('data.itemNo');
        Sources.Add('data.itemId, data.id, data.systemId, data.recordSystemId');
        Sources.Add('data.tableView');
        Index := 0;
        foreach Source in Sources do begin
            Target.Get(Index, Token);
            Entry := Token.AsObject();
            AssertJsonText(Entry, 'source', Source);
            Entry.Get('description', Token);
            LibraryAssert.IsFalse(Token.AsValue().AsText().Contains('document header'), 'Item has no document fallback.');
            Index += 1;
        end;
    end;

    local procedure AssertAttributeError(Errors: JsonArray; TypeName: Text)
    var
        Token: JsonToken;
        Entry: JsonObject;
        Index: Integer;
        Expected: Text;
    begin
        case TypeName of
            'Inventory.Attribute.Get': begin
                Index := 4;
                Expected := 'No items found matching the specified criteria.';
            end;
            'Inventory.Attribute.Create': begin
                Index := 5;
                Expected := 'Item "%1" already has attribute "%2" with a different value.';
            end;
            'Inventory.Attribute.Update': begin
                Index := 5;
                Expected := 'Item "%1" has no mapping for attribute "%2". Use Item.Attribute.Create first.';
            end;
            'Inventory.AttributeDefinition.Create': begin
                Index := 3;
                Expected := 'Item attribute "%1" already exists.';
            end;
        end;
        Errors.Get(Index, Token);
        Entry := Token.AsObject();
        AssertJsonText(Entry, 'error', Expected);
    end;

    local procedure AssertAttributeLegacyPayloads(TypeName: Text; Contract: JsonObject)
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        Legacy: Text;
    begin
        Legacy := 'Item.' + TypeName.Substring(11);
        AssertChapterJson(Contract, 'envelope', Parts.GetEnvelope(Legacy).AsToken());
        AssertChapterJson(Contract, 'parameters', Parts.GetParameters(Legacy).AsToken());
        AssertChapterJson(Contract, 'response', Parts.GetResponse(Legacy).AsToken());
        AssertChapterJson(Contract, 'errors', Parts.GetErrors(Legacy).AsToken());
        AssertChapterJson(Contract, 'effect', Parts.GetEffect(Legacy).AsToken());
        AssertChapterJson(Contract, 'related', Parts.GetRelated(Legacy).AsToken());
        if TypeName <> 'Inventory.AttributeDefinition.Create' then
            AssertChapterJson(Contract, 'target', Parts.GetTarget(Legacy).AsToken())
        else
            LibraryAssert.IsFalse(Contract.Contains('target'), 'Reader omits the Definition target.');
        if TypeName in ['Inventory.Attribute.Get', 'Inventory.AttributeDefinition.Create'] then
            AssertChapterJson(Contract, 'examples', Parts.GetExamples(Legacy).AsToken())
        else
            LibraryAssert.IsFalse(Contract.Contains('examples'), 'Create and Update examples remain absent.');
    end;

    local procedure AssertChapterJson(Contract: JsonObject; Chapter: Text; Expected: JsonToken)
    var
        Actual: JsonToken;
        ActualJson: Text;
        ExpectedJson: Text;
    begin
        LibraryAssert.IsTrue(Contract.Get(Chapter, Actual), 'Missing chapter ' + Chapter + '.');
        Actual.WriteTo(ActualJson);
        Expected.WriteTo(ExpectedJson);
        LibraryAssert.AreEqual(ExpectedJson, ActualJson, 'Inventory and legacy Item helper chapter payloads match: ' + Chapter + '.');
    end;

    /// <summary>Checks published costing parameter defaults through the contract reader.</summary>
    [Test]
    procedure CostingContracts_DeclareTypedDefaults()
    var
        Contract: JsonObject;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        // Metadata only: this test makes no permission or report execution claim.
        LoadCostingContract('Inventory.AdjustCost.Run', Contract);
        AssertStringDefault(Contract, 'itemNoFilter');
        AssertStringDefault(Contract, 'itemCategoryFilter');
        AssertBooleanDefault(Contract, 'postToGL', false);
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        AssertStringDefault(Contract, 'itemNoFilter');
        AssertStringDefault(Contract, 'postingDate');
        AssertBooleanDefault(Contract, 'perPostingGroup', false);
    end;

    /// <summary>Checks the report 795 filter constraint and array-shaped preconditions.</summary>
    [Test]
    procedure CostingContracts_DeclareFilterPrecondition()
    var
        Contract: JsonObject;
        ChapterToken: JsonToken;
        Effect: JsonObject;
        Preconditions: JsonArray;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        LoadCostingContract('Inventory.AdjustCost.Run', Contract);
        Contract.Get('effect', ChapterToken);
        Effect := ChapterToken.AsObject();
        Effect.Get('preconditions', ChapterToken);
        LibraryAssert.IsTrue(ChapterToken.IsArray(), 'Preconditions must be an array, not prose.');
        Preconditions := ChapterToken.AsArray();
        LibraryAssert.AreEqual(3, Preconditions.Count(), 'Keep the domain, report and conflicting-filter preconditions.');
        Preconditions.Get(2, ChapterToken);
        LibraryAssert.AreEqual('Only one of itemNo and itemCategoryCode may be nonempty; filters longer than 250 characters are refused.', ChapterToken.AsValue().AsText(), 'Report 795 rejects simultaneous effective filters.');
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        Contract.Get('effect', ChapterToken);
        Effect := ChapterToken.AsObject();
        Effect.Get('preconditions', ChapterToken);
        LibraryAssert.IsTrue(ChapterToken.IsArray(), 'CostToGL preconditions must also be an array.');
    end;

    /// <summary>Checks normal-dispatch error mapping without claiming runtime execution.</summary>
    [Test]
    procedure CostingContracts_DeclareDispatcherFailure()
    var
        Contract: JsonObject;
        Error: JsonObject;
        ValueToken: JsonToken;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        LoadCostingContract('Inventory.AdjustCost.Run', Contract);
        GetNamedMember(Contract, 'errors', 'code', 'BusinessCentralError', Error);
        Error.Get('when', ValueToken);
        LibraryAssert.IsTrue(StrPos(ValueToken.AsValue().AsText(), 'Direct invocation may raise instead') > 0, 'Direct errors must remain distinct from dispatcher responses.');
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        GetNamedMember(Contract, 'errors', 'code', 'PreconditionFailed', Error);
        Error.Get('when', ValueToken);
        LibraryAssert.AreEqual('Request validation or the native report fails; no native commit rollback is promised.', ValueToken.AsValue().AsText(), 'Validation precedes native report execution; report commits are preserved.');
        GetNamedMember(Contract, 'errors', 'code', 'BusinessCentralError', Error);
    end;

    /// <summary>Checks that CostToGL completion does not promise G/L posting.</summary>
    [Test]
    procedure CostingContracts_DiscloseReportOptions()
    var
        Contract: JsonObject;
        ChapterToken: JsonToken;
        Effect: JsonObject;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        LoadCostingContract('Inventory.CostToGL.Post', Contract);
        Contract.Get('effect', ChapterToken);
        Effect := ChapterToken.AsObject();
        Effect.Get('changes', ChapterToken);
        LibraryAssert.AreEqual('Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.', ChapterToken.AsValue().AsText(), 'Explicit native posting mode and effective selection are disclosed; runtime tests prove behavior.');
        Effect.Get('idempotent', ChapterToken);
        LibraryAssert.IsFalse(ChapterToken.AsValue().AsBoolean(), 'No safe retry or idempotence guarantee is established.');
    end;

    /// <summary>Checks omitted chapters clear reused interface outputs.</summary>
    [Test]
    procedure CostingContracts_ClearReusedChapters()
    var
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Contract ori";
        TypeName: Text;
        Types: List of [Text];
        ChapterKeys: List of [Text];
        ObjectChapter: JsonObject;
        ArrayChapter: JsonArray;
    begin
        // PR #90 costing regression | Time: no Today/WorkDate dependency | Risk: metadata only; runtime tested separately.
        Types.Add('Inventory.AdjustCost.Run');
        Types.Add('Inventory.CostToGL.Post');
        foreach TypeName in Types do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Implementation := MessageType;
            ObjectChapter.Add('stale', true);
            LibraryAssert.IsFalse(Implementation.GetWorkflow(ObjectChapter), 'No workflow is declared.');
            ChapterKeys := ObjectChapter.Keys();
            LibraryAssert.AreEqual(0, ChapterKeys.Count(), 'Absent workflow must clear old output.');
            ObjectChapter.Add('stale', true);
            LibraryAssert.IsFalse(Implementation.GetMetering(ObjectChapter), 'Foundation owns metering composition.');
            ChapterKeys := ObjectChapter.Keys();
            LibraryAssert.AreEqual(0, ChapterKeys.Count(), 'Absent app metering must clear old output.');
            ArrayChapter.Add('stale');
            LibraryAssert.IsTrue(Implementation.GetTarget(ArrayChapter), 'Unused subject has an explicit empty target.');
            LibraryAssert.AreEqual(0, ArrayChapter.Count(), 'Target must not retain previous records.');
        end;
    end;

    /// <summary>Exercises every costing chapter through the published enum interfaces.</summary>
    [Test]
    procedure CostingInterfaces_AllChapters_ReplaceReusedOutputs()
    var
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        Contract: Interface "Msg Contract ori";
        Types: List of [Text];
        TypeName: Text;
        TextChapter: Text;
        ObjectChapter: JsonObject;
        ArrayChapter: JsonArray;
        Keys: List of [Text];
        RepeatRead: Integer;
    begin
        // PR #90 metadata-all-members | Time: no date dependency | Risk: metadata only.
        // [GIVEN] Both real mappings and outputs reused across repetitions and mappings.
        Types.Add('Inventory.AdjustCost.Run');
        Types.Add('Inventory.CostToGL.Post');
        foreach TypeName in Types do begin
            MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
            Implementation := MessageType;
            Discovery := MessageType;
            Contract := MessageType;
            LibraryAssert.AreEqual("Msg Direction ori"::Inbound, Implementation.GetMessageDirection(), 'Both operations are inbound.');
            LibraryAssert.AreEqual(27, Implementation.GetFilterTableNo(), 'Both filter tables are Item.');
            AssertCostingCatalogue(TypeName, Implementation.GetDescription(), Discovery.GetSelectionDescription(), Discovery.GetKeywords());
            for RepeatRead := 1 to 2 do begin
                // [WHEN] Every chapter is read with deliberately stale output.
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsTrue(Contract.GetEnvelope(ObjectChapter), 'Envelope is declared.');
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), 'Envelope must replace output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetTarget(ArrayChapter), 'Target is explicitly empty.');
                LibraryAssert.AreEqual(0, ArrayChapter.Count(), 'No subject target.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetParameters(ArrayChapter), 'Parameters are declared.');
                if TypeName = 'Inventory.AdjustCost.Run' then
                    LibraryAssert.AreEqual(6, ArrayChapter.Count(), 'Four native options and two validated legacy aliases.')
                else
                    LibraryAssert.AreEqual(6, ArrayChapter.Count(), 'Four native options and two validated legacy aliases.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetErrors(ArrayChapter), 'Errors are declared.');
                LibraryAssert.AreEqual(4, ArrayChapter.Count(), 'Four independently specified error branches.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsTrue(Contract.GetResponse(ObjectChapter), 'Response is declared.');
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), 'Response must replace output.');
                AssertCostingResponseFields(TypeName, ObjectChapter);
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsTrue(Contract.GetEffect(ObjectChapter), 'Effect is declared.');
                LibraryAssert.IsFalse(ObjectChapter.Contains('stale'), 'Effect must replace output.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsFalse(Contract.GetMetering(ObjectChapter), 'Application adds no metering.');
                Keys := ObjectChapter.Keys();
                LibraryAssert.AreEqual(0, Keys.Count(), 'App metering clears output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetRelated(ArrayChapter), 'Related is declared.');
                LibraryAssert.AreEqual(1, ArrayChapter.Count(), 'One sibling operation.');
                ObjectChapter.Add('stale', true);
                LibraryAssert.IsFalse(Contract.GetWorkflow(ObjectChapter), 'Workflow omitted.');
                Keys := ObjectChapter.Keys();
                LibraryAssert.AreEqual(0, Keys.Count(), 'Workflow clears output.');
                ArrayChapter.Add('stale');
                LibraryAssert.IsTrue(Contract.GetExamples(ArrayChapter), 'Examples declared.');
                LibraryAssert.AreEqual(1, ArrayChapter.Count(), 'One example.');
                TextChapter := 'stale';
                LibraryAssert.IsTrue(Contract.GetOverview(TextChapter), 'Overview declared.');
                LibraryAssert.IsFalse((TextChapter = '') or (TextChapter = 'stale'), 'Overview replaces output.');
                TextChapter := 'stale';
                LibraryAssert.IsTrue(Contract.GetNotes(TextChapter), 'Notes declared.');
                LibraryAssert.IsFalse((TextChapter = '') or (TextChapter = 'stale'), 'Notes replace output.');
                // [THEN] Typed defaults are independently asserted by retained five tests.
            end;
        end;
    end;

    local procedure LoadCostingContract(TypeName: Text; var Contract: JsonObject)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
    begin
        Contract.Add('stale', true);
        MessageType := Enum::"Message Type ori".FromInteger(OrdinalOf(TypeName));
        LibraryAssert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Costing implementation must declare its contract.');
        LibraryAssert.IsFalse(Contract.Contains('stale'), 'Contract reader must clear reused output.');
    end;

    local procedure AssertStringDefault(Contract: JsonObject; Name: Text)
    var
        Parameter: JsonObject;
        ValueToken: JsonToken;
        DefaultJson: Text;
    begin
        GetNamedMember(Contract, 'parameters', 'name', Name, Parameter);
        Parameter.Get('type', ValueToken);
        LibraryAssert.AreEqual('string', ValueToken.AsValue().AsText(), Name + ' type must be string.');
        Parameter.Get('default', ValueToken);
        ValueToken.WriteTo(DefaultJson);
        LibraryAssert.AreEqual('""', DefaultJson, Name + ' default must be a JSON string.');
        LibraryAssert.AreEqual('', ValueToken.AsValue().AsText(), Name + ' must declare its empty default.');
        Parameter.Get('required', ValueToken);
        LibraryAssert.IsFalse(ValueToken.AsValue().AsBoolean(), Name + ' is optional.');
    end;

    local procedure AssertBooleanDefault(Contract: JsonObject; Name: Text; Expected: Boolean)
    var
        Parameter: JsonObject;
        ValueToken: JsonToken;
        DefaultJson: Text;
    begin
        GetNamedMember(Contract, 'parameters', 'name', Name, Parameter);
        Parameter.Get('type', ValueToken);
        LibraryAssert.AreEqual('boolean', ValueToken.AsValue().AsText(), Name + ' type must be boolean.');
        Parameter.Get('default', ValueToken);
        ValueToken.WriteTo(DefaultJson);
        if Expected then
            LibraryAssert.AreEqual('true', DefaultJson, Name + ' default must be a JSON Boolean.')
        else
            LibraryAssert.AreEqual('false', DefaultJson, Name + ' default must be a JSON Boolean.');
        LibraryAssert.AreEqual(Expected, ValueToken.AsValue().AsBoolean(), Name + ' must declare a typed Boolean default.');
        Parameter.Get('required', ValueToken);
        LibraryAssert.IsFalse(ValueToken.AsValue().AsBoolean(), Name + ' is optional.');
    end;

    local procedure GetNamedMember(Contract: JsonObject; Chapter: Text; KeyName: Text; Expected: Text; var Member: JsonObject)
    var
        ChapterToken: JsonToken;
        EntryToken: JsonToken;
        ValueToken: JsonToken;
    begin
        Clear(Member);
        LibraryAssert.IsTrue(Contract.Get(Chapter, ChapterToken), 'Missing contract chapter ' + Chapter + '.');
        foreach EntryToken in ChapterToken.AsArray() do begin
            Member := EntryToken.AsObject();
            if Member.Get(KeyName, ValueToken) then
                if ValueToken.AsValue().AsText() = Expected then
                    exit;
        end;
        LibraryAssert.Fail('Missing ' + Chapter + ' entry ' + Expected + '.');
    end;

    local procedure AssertCostingCatalogue(TypeName: Text; Description: Text; Selection: Text; Keywords: Text)
    begin
        if TypeName = 'Inventory.AdjustCost.Run' then begin
            LibraryAssert.AreEqual('Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.', Description, 'Exact AdjustCost description.');
            LibraryAssert.AreEqual('Runs native report 795 with item or category selection, item-by-item adjustment and optional G/L posting.', Selection, 'Exact AdjustCost selection.');
            LibraryAssert.AreEqual('adjust cost,item entry correction,post to g/l,report 795', Keywords, 'Exact AdjustCost keywords.');
        end else begin
            LibraryAssert.AreEqual('Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.', Description, 'Exact CostToGL description.');
            LibraryAssert.AreEqual('Posts the selected pending inventory costs to G/L using native report 1002 with Post enabled.', Selection, 'Exact CostToGL selection.');
            LibraryAssert.AreEqual('post inventory cost,general ledger,report 1002', Keywords, 'Exact CostToGL keywords.');
        end;
    end;

    local procedure AssertCostingResponseFields(TypeName: Text; Response: JsonObject)
    var
        Field: JsonObject;
        Token: JsonToken;
    begin
        AssertJsonText(Response, 'contentType', 'text/json');
        Response.Get('fields', Token);
        if TypeName = 'Inventory.AdjustCost.Run' then
            LibraryAssert.AreEqual(7, Token.AsArray().Count(), 'Exact AdjustCost response field count.')
        else
            LibraryAssert.AreEqual(5, Token.AsArray().Count(), 'Exact CostToGL response field count.');
        GetNamedMember(Response, 'fields', 'name', 'status', Field);
        AssertJsonText(Field, 'type', 'string');
        if TypeName = 'Inventory.AdjustCost.Run' then begin
            GetNamedMember(Response, 'fields', 'name', 'itemsProcessed', Field);
            AssertJsonText(Field, 'type', 'integer');
            GetNamedMember(Response, 'fields', 'name', 'reportCompleted', Field);
            AssertJsonText(Field, 'type', 'boolean');
            GetNamedMember(Response, 'fields', 'name', 'errors', Field);
            AssertJsonText(Field, 'type', 'array');
            GetNamedMember(Response, 'fields', 'name', 'itemsSelected', Field);
            AssertJsonText(Field, 'type', 'integer');
            GetNamedMember(Response, 'fields', 'name', 'postToGL', Field);
            AssertJsonText(Field, 'type', 'boolean');
            GetNamedMember(Response, 'fields', 'name', 'itemByItem', Field);
            AssertJsonText(Field, 'type', 'boolean');
        end else begin
            GetNamedMember(Response, 'fields', 'name', 'entriesSelected', Field);
            AssertJsonText(Field, 'type', 'integer');
            GetNamedMember(Response, 'fields', 'name', 'entriesRemaining', Field);
            AssertJsonText(Field, 'type', 'integer');
            GetNamedMember(Response, 'fields', 'name', 'posted', Field);
            AssertJsonText(Field, 'type', 'boolean');
            GetNamedMember(Response, 'fields', 'name', 'skippedEntries', Field);
            AssertJsonText(Field, 'type', 'array');
        end;
    end;

    local procedure AssertJsonText(Value: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        LibraryAssert.IsTrue(Value.Get(Name, Token), 'Missing response field ' + Name + '.');
        LibraryAssert.IsTrue(Token.IsValue(), Name + ' must be scalar.');
        LibraryAssert.AreEqual(Expected, Token.AsValue().AsText(), Name + ' mismatch.');
    end;
}
