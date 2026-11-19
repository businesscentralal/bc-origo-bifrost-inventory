namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 266: bilingual UAT help corrections without changing request or execution behavior.</summary>
codeunit 97900 "Inv. 266 Help Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>AC01 English discovery distinguishes legacy single-line counts from the counts array.</summary>
    [Test]
    procedure CountDescriptionsEnglish()
    begin
        // Story #266 AC01 | Time: independent | Risk: shared execution hides the counts-only contract.
        AssertCountDescriptions(1033);
    end;

    /// <summary>AC01 Icelandic discovery distinguishes the two count contracts.</summary>
    [Test]
    procedure CountDescriptionsIcelandic()
    begin
        // Story #266 AC01 | Time: independent | Risk: legacy and array descriptions collapse in Icelandic.
        AssertCountDescriptions(1039);
    end;

    /// <summary>AC03 All affected discovery texts are supplied in English.</summary>
    [Test]
    procedure DiscoveryEnglish()
    begin
        // Story #266 AC03 | Time: independent | Risk: discovery returns prose instead of search terms.
        AssertDiscovery(1033);
    end;

    /// <summary>AC03 All affected discovery texts are translated in Icelandic.</summary>
    [Test]
    procedure DiscoveryIcelandic()
    begin
        // Story #266 AC03 | Time: independent | Risk: missing translated discovery falls back to English.
        AssertDiscovery(1039);
    end;

    /// <summary>AC04 The response declares its processed-item count and empty-on-success error array in both locales.</summary>
    [Test]
    procedure AdjustCostResponseFields()
    var
        Contract: Interface "Msg Contract ori";
        Response: JsonObject;
        Token: JsonToken;
        Fields: JsonArray;
        SavedLanguage: Integer;
        LanguageId: Integer;
    begin
        // Story #266 AC04 | Time: independent | Risk: real response fields disappear from help.
        SavedLanguage := GlobalLanguage();
        Contract := "Message Type ori"::"Inventory.AdjustCost.Run";
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            Assert.IsTrue(Contract.GetResponse(Response), 'Response is declared.');
            Response.Get('fields', Token);
            Fields := Token.AsArray();
            AssertField(Fields, 'itemsProcessed', 'integer', 'scope of the run');
            AssertField(Fields, 'errors', 'array', 'Always empty on Success');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC05 Help declares itemFilter and an exact-item example, without advertising itemNo as input.</summary>
    [Test]
    procedure ValuationSelectorBothLanguages()
    var
        Contract: Interface "Msg Contract ori";
        Parameters: JsonArray;
        Token: JsonToken;
        Parameter: JsonObject;
        Notes: Text;
        FoundItemFilter: Boolean;
        AcceptedNames: List of [Text];
        SavedLanguage: Integer;
        LanguageId: Integer;
    begin
        // Story #266 AC05 | Time: independent | Risk: a response field is silently used as an unfiltered request.
        AcceptedNames.Add('asOfDate');
        AcceptedNames.Add('itemFilter');
        AcceptedNames.Add('locationFilter');
        AcceptedNames.Add('variantFilter');
        AcceptedNames.Add('inventoryPostingGroupFilter');
        AcceptedNames.Add('take');
        AcceptedNames.Add('skip');
        SavedLanguage := GlobalLanguage();
        Contract := "Message Type ori"::"Inventory.Valuation.Get";
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            FoundItemFilter := false;
            Assert.IsTrue(Contract.GetParameters(Parameters), 'Parameters are declared.');
            Assert.AreEqual(7, Parameters.Count(), 'Valuation declares exactly its accepted parameters.');
            foreach Token in Parameters do begin
                Parameter := Token.AsObject();
                Assert.IsTrue(AcceptedNames.Contains(TextOf(Parameter, 'name')), 'Every declared valuation input is accepted by the implementation.');
                Assert.AreNotEqual('itemNo', TextOf(Parameter, 'name'), 'itemNo is not advertised as input.');
                if TextOf(Parameter, 'name') = 'itemFilter' then begin
                    FoundItemFilter := true;
                    Assert.IsTrue(TextOf(Parameter, 'description').Contains('{"itemFilter":"XITEM"}'), 'Exact-item example uses the declared key.');
                end;
            end;
            Assert.IsTrue(FoundItemFilter, 'itemFilter is declared.');
            Assert.IsTrue(Contract.GetNotes(Notes), 'Notes are supplied.');
            Assert.IsTrue(Notes.Contains('itemFilter'), 'Notes name the correct selector.');
            Assert.IsTrue(Notes.Contains('itemNo'), 'Notes explain the response-field distinction.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC07 Source fields and complete sales/purchase tracking examples exist in both languages.</summary>
    [Test]
    procedure TrackingSourceSchemaBothLanguages()
    var
        Contract: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        Parameters: JsonArray;
        Examples: JsonArray;
        Children: JsonArray;
        Token: JsonToken;
        Parameter: JsonObject;
        SavedLanguage: Integer;
        LanguageId: Integer;
        FoundSource: Boolean;
    begin
        // Story #266 AC07 | Time: independent | Risk: callers cannot construct the nested source object.
        SavedLanguage := GlobalLanguage();
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            foreach MessageType in TrackingTypes() do begin
                Contract := MessageType;
                Clear(Parameters);
                Clear(Examples);
                Assert.IsTrue(Contract.GetParameters(Parameters), 'Tracking parameters are declared.');
                FoundSource := false;
                foreach Token in Parameters do begin
                    Parameter := Token.AsObject();
                    if TextOf(Parameter, 'name') = 'source' then begin
                        FoundSource := true;
                        Assert.AreEqual('object', TextOf(Parameter, 'type'), 'source is an object.');
                        Parameter.Get('children', Token);
                        Children := Token.AsArray();
                        Assert.AreEqual(3, Children.Count(), 'Every accepted source field is documented.');
                        AssertSourceChild(Children, 'type', true);
                        AssertSourceChild(Children, 'systemId', true);
                        AssertSourceChild(Children, 'transferDirection', false);
                    end;
                end;
                Assert.IsTrue(FoundSource, 'source is declared.');
                Assert.IsTrue(Contract.GetExamples(Examples), 'Tracking examples are supplied.');
                AssertSourceExample(Examples, 'SalesLine');
                AssertSourceExample(Examples, 'PurchaseLine');
            end;
        end;
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC08 Every object/array parameter across all 97 owned message types has a typed, nonempty request example.</summary>
    [Test]
    procedure AllComplexParametersHaveExamples()
    var
        Contract: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        Parameters: JsonArray;
        Examples: JsonArray;
        ParameterToken: JsonToken;
        Parameter: JsonObject;
        Ordinal: Integer;
        TypeCount: Integer;
        ComplexCount: Integer;
        SavedLanguage: Integer;
        LanguageId: Integer;
        TypeName: Text;
    begin
        // Story #266 AC08 | Time: independent | Risk: optional collection inputs have no usable example.
        SavedLanguage := GlobalLanguage();
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            TypeCount := 0;
            ComplexCount := 0;
            foreach Ordinal in MessageType.Ordinals() do
                if (Ordinal >= 10076835) and (Ordinal <= 10077034) then begin
                    MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                    TypeName := MessageType.Names().Get(MessageType.Ordinals().IndexOf(Ordinal));
                    Contract := MessageType;
                    Clear(Parameters);
                    Clear(Examples);
                    Contract.GetParameters(Parameters);
                    Contract.GetExamples(Examples);
                    foreach ParameterToken in Parameters do begin
                        Parameter := ParameterToken.AsObject();
                        if TextOf(Parameter, 'type') in ['object', 'array'] then begin
                            ComplexCount += 1;
                            Assert.IsTrue(HasParameterExample(Examples, TypeName, TextOf(Parameter, 'name'), TextOf(Parameter, 'type')), TypeName + '.' + TextOf(Parameter, 'name') + ' has a nonempty typed example request.');
                        end;
                    end;
                    TypeCount += 1;
                end;
            Assert.AreEqual(97, TypeCount, 'Every owned message type is audited.');
            Assert.AreEqual(36, ComplexCount, 'Every current object/array parameter is covered.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC10 Confirmation guidance reflects company policy and keeps the existing reversible Period.Close contract.</summary>
    [Test]
    procedure ConfirmationPolicyAndPeriodException()
    var
        ConfirmGate: Codeunit "Confirm Gate ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Token: JsonToken;
        Notes: Text;
        SavedLanguage: Integer;
        LanguageId: Integer;
        MessageType: Enum "Message Type ori";
        Types: List of [Enum "Message Type ori"];
    begin
        // Story #266 AC10 | Time: independent | Risk: omitting confirmation is mistaken for an unconditional preview.
        SavedLanguage := GlobalLanguage();
        Types.Add("Message Type ori"::"Inventory.AdjustCost.Run");
        Types.Add("Message Type ori"::"Inventory.CostToGL.Post");
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            foreach MessageType in Types do begin
                Contract := MessageType;
                Assert.IsTrue(Contract.GetNotes(Notes), 'Policy guidance exists.');
                Assert.IsTrue(Notes.Contains('Require Irreversible Confirm'), 'The company setting is named.');
                Assert.IsTrue(Notes.Contains('expectedCount'), 'The omitted count is explained.');
                if LanguageId = 1033 then
                    Assert.IsTrue(Notes.Contains('runs the operation immediately'), 'Disabled confirmation executes immediately.')
                else
                    Assert.IsTrue(Notes.Contains('keyrir aðgerðin strax'), 'Disabled confirmation is explained in Icelandic.');
            end;
            Contract := "Message Type ori"::"Inventory.Period.Close";
            Clear(Effect);
            Clear(Parameters);
            Assert.IsTrue(Contract.GetEffect(Effect), 'Period close effect exists.');
            Assert.AreEqual('write', TextOf(Effect, 'effect'), 'Period.Close remains a reversible write.');
            Assert.IsFalse(ConfirmGate.IsConfirmRequired("Message Type ori"::"Inventory.Period.Close"), 'The existing operation is not an irreversible confirmation type.');
            Assert.IsTrue(Contract.GetParameters(Parameters), 'Period parameters exist.');
            Assert.AreEqual(1, Parameters.Count(), 'Period.Close still accepts endingDate only.');
            Parameters.Get(0, Token);
            Assert.AreEqual('endingDate', TextOf(Token.AsObject(), 'name'), 'No expectedCount input was added.');
            Assert.IsTrue(Contract.GetNotes(Notes), 'Period confirmation exception is documented.');
            Assert.IsTrue(Notes.Contains('expectedCount'), 'Period notes explicitly explain the absence of the preview contract.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertSourceChild(Children: JsonArray; FieldName: Text; RequiredValue: Boolean)
    var
        ChildToken: JsonToken;
        RequiredToken: JsonToken;
        Child: JsonObject;
        Found: Boolean;
    begin
        foreach ChildToken in Children do begin
            Child := ChildToken.AsObject();
            if TextOf(Child, 'name') = FieldName then begin
                Found := true;
                Assert.AreEqual('string', TextOf(Child, 'type'), 'Source fields are strings.');
                Assert.AreNotEqual('', TextOf(Child, 'description'), 'Source field description is supplied.');
                Child.Get('required', RequiredToken);
                Assert.AreEqual(RequiredValue, RequiredToken.AsValue().AsBoolean(), 'Source field required flag matches the resolver.');
            end;
        end;
        Assert.IsTrue(Found, 'Source field is declared: ' + FieldName);
    end;

    local procedure AssertSourceExample(Examples: JsonArray; SourceType: Text)
    var
        ExampleToken: JsonToken;
        RequestToken: JsonToken;
        DataToken: JsonToken;
        SourceToken: JsonToken;
        Source: JsonObject;
        Found: Boolean;
    begin
        foreach ExampleToken in Examples do
            if ExampleToken.AsObject().Get('request', RequestToken) then
                if RequestToken.AsObject().Get('data', DataToken) then
                    if DataToken.AsObject().Get('source', SourceToken) then begin
                        Source := SourceToken.AsObject();
                        if TextOf(Source, 'type') = SourceType then begin
                            Found := true;
                            Assert.AreNotEqual('', TextOf(Source, 'systemId'), 'The complete source example includes its GUID.');
                        end;
                    end;
        Assert.IsTrue(Found, 'A complete tracking example exists for ' + SourceType);
    end;

    local procedure HasParameterExample(Examples: JsonArray; TypeName: Text; ParameterName: Text; ParameterType: Text): Boolean
    var
        ExampleToken: JsonToken;
        RequestToken: JsonToken;
        DataToken: JsonToken;
        ValueToken: JsonToken;
        Request: JsonObject;
    begin
        foreach ExampleToken in Examples do
            if ExampleToken.AsObject().Get('request', RequestToken) then begin
                Request := RequestToken.AsObject();
                if TextOf(Request, 'type') = TypeName then
                    if Request.Get('data', DataToken) then
                        if DataToken.AsObject().Get(ParameterName, ValueToken) then begin
                            if (ParameterType = 'object') and ValueToken.IsObject() then
                                if ValueToken.AsObject().Keys().Count() > 0 then
                                    exit(true);
                            if (ParameterType = 'array') and ValueToken.IsArray() then
                                if ValueToken.AsArray().Count() > 0 then
                                    exit(true);
                        end;
            end;
        exit(false);
    end;

    local procedure TrackingTypes() Result: List of [Enum "Message Type ori"]
    begin
        Result.Add("Message Type ori"::"Inventory.Tracking.Assign");
        Result.Add("Message Type ori"::"Inventory.Tracking.Delete");
    end;

    local procedure AssertCountDescriptions(LanguageId: Integer)
    var
        Legacy: Interface "Msg Interface ori";
        Count: Interface "Msg Interface ori";
        SavedLanguage: Integer;
        LegacyDescription: Text;
        CountDescription: Text;
    begin
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Legacy := "Message Type ori"::"Inventory.PhysInventory.Record";
        Count := "Message Type ori"::"Inventory.PhysInventory.RecordCount";
        LegacyDescription := Legacy.GetDescription();
        CountDescription := Count.GetDescription();
        Assert.AreNotEqual(LegacyDescription, CountDescription, 'The two types have distinct descriptions.');
        Assert.IsTrue(LegacyDescription.Contains('lineNo'), 'Legacy description explains its single-line form.');
        Assert.IsTrue(CountDescription.Contains('counts'), 'RecordCount description explains its counts array.');
        Assert.IsFalse(CountDescription.Contains('lineNo'), 'RecordCount does not advertise legacy input.');
        Assert.AreEqual(Legacy.GetFilterTableNo(), Count.GetFilterTableNo(), 'The selection table is unchanged.');
        Assert.AreEqual(Legacy.GetMessageDirection(), Count.GetMessageDirection(), 'The direction is unchanged.');
        Assert.AreEqual(Legacy.IsEnabled(), Count.IsEnabled(), 'The domain and permission gates are unchanged.');
        if LanguageId = 1039 then begin
            Assert.IsTrue(LegacyDescription.StartsWith('Skráir'), 'Legacy description is Icelandic.');
            Assert.IsTrue(CountDescription.StartsWith('Skráir'), 'RecordCount description is Icelandic.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertDiscovery(LanguageId: Integer)
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        SavedLanguage: Integer;
        EnglishSelection: Text;
        EnglishKeywords: Text;
        Selection: Text;
        Keywords: Text;
    begin
        SavedLanguage := GlobalLanguage();
        foreach MessageType in DiscoveryTypes() do begin
            Discovery := MessageType;
            GlobalLanguage(1033);
            EnglishSelection := Discovery.GetSelectionDescription();
            EnglishKeywords := Discovery.GetKeywords();
            GlobalLanguage(LanguageId);
            Selection := Discovery.GetSelectionDescription();
            Keywords := Discovery.GetKeywords();
            Assert.AreNotEqual('', Selection, 'Selection text is supplied.');
            Assert.AreNotEqual('', Keywords, 'Keywords are supplied.');
            Assert.IsTrue(Keywords.Contains(','), 'Keywords are a comma-separated term list.');
            if LanguageId = 1039 then begin
                Assert.AreNotEqual(EnglishSelection, Selection, 'Selection text is translated.');
                Assert.AreNotEqual(EnglishKeywords, Keywords, 'Keywords are translated.');
            end;
            if MessageType in ["Message Type ori"::"Inventory.PhysInventoryOrder.Create", "Message Type ori"::"Inventory.PhysInventoryOrder.Finish", "Message Type ori"::"Inventory.PhysInventoryOrder.Post"] then begin
                Assert.IsFalse(Keywords.Contains('.'), 'Order keywords contain no description sentences.');
                Assert.IsFalse(Keywords.Contains('expectedCount'), 'Order keywords contain no confirmation prose.');
            end;
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertField(Fields: JsonArray; FieldName: Text; FieldType: Text; DescriptionPart: Text)
    var
        Token: JsonToken;
        Field: JsonObject;
        Found: Boolean;
    begin
        foreach Token in Fields do begin
            Field := Token.AsObject();
            if TextOf(Field, 'name') = FieldName then begin
                Found := true;
                Assert.AreEqual(FieldType, TextOf(Field, 'type'), 'Response field has its existing wire type.');
                Assert.IsTrue(TextOf(Field, 'description').Contains(DescriptionPart), 'Response field explains its actual semantics.');
            end;
        end;
        Assert.IsTrue(Found, 'The response field is declared: ' + FieldName);
    end;

    local procedure TextOf(Value: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Value.Get(KeyName, Token), 'Contract key exists: ' + KeyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure Languages() Result: List of [Integer]
    begin
        Result.Add(1033);
        Result.Add(1039);
    end;

    local procedure DiscoveryTypes() Result: List of [Enum "Message Type ori"]
    begin
        Result.Add("Message Type ori"::"Inventory.PhysInventoryOrder.Create");
        Result.Add("Message Type ori"::"Inventory.PhysInventoryOrder.Finish");
        Result.Add("Message Type ori"::"Inventory.PhysInventoryOrder.Post");
        Result.Add("Message Type ori"::"Inventory.StandardCost.Suggest");
        Result.Add("Message Type ori"::"Inventory.StandardCost.Implement");
        Result.Add("Message Type ori"::"Inventory.Tracking.Assign");
        Result.Add("Message Type ori"::"Inventory.Tracking.Delete");
    end;
}
