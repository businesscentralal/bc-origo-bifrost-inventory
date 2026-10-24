namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue151 typed input and localized refusal regressions; invalid requests cannot reach writes or reports.</summary>
codeunit 96975 "Inv. Typed Refusal Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    [Test]
    procedure PeriodClose_InvalidDates_EN()
    begin
        CheckPeriodFormats(1033, "Message Type ori"::"Inventory.Period.Close");
    end;

    [Test]
    procedure PeriodClose_InvalidDates_IS()
    begin
        CheckPeriodFormats(1039, "Message Type ori"::"Inventory.Period.Close");
    end;

    [Test]
    procedure PeriodReopen_InvalidDates_EN()
    begin
        CheckPeriodFormats(1033, "Message Type ori"::"Inventory.Period.Reopen");
    end;

    [Test]
    procedure PeriodReopen_InvalidDates_IS()
    begin
        CheckPeriodFormats(1039, "Message Type ori"::"Inventory.Period.Reopen");
    end;

    [Test]
    procedure AdjustCost_InvalidBoolean_EN()
    begin
        CheckBoolean(1033);
    end;

    [Test]
    procedure AdjustCost_InvalidBoolean_IS()
    begin
        CheckBoolean(1039);
    end;

    [Test]
    procedure AdjustCost_CollectsAllInvalidValues_EN()
    begin
        CheckAdjustmentCollection(1033);
    end;

    [Test]
    procedure AdjustCost_CollectsAllInvalidValues_IS()
    begin
        CheckAdjustmentCollection(1039);
    end;

    [Test]
    procedure PeriodReopen_UsesIsoNotFoundDate_EN()
    begin
        CheckPeriodNotFound(1033);
    end;

    [Test]
    procedure PeriodReopen_UsesIsoNotFoundDate_IS()
    begin
        CheckPeriodNotFound(1039);
    end;

    local procedure CheckPeriodFormats(LanguageId: Integer; MessageType: Enum "Message Type ori")
    var
        Period: Record "Inventory Period";
        Request: JsonObject;
        Response: JsonObject;
        BadValues: JsonArray;
        Token: JsonToken;
        BeforeCount: Integer;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        BeforeCount := Period.Count();
        BadValues.ReadFrom('["31.12.2026",true,42,{},[],"2026-02-30"]');
        foreach Token in BadValues do begin
            Clear(Request);
            Request.Add('endingDate', Token);
            Response := Library.ExecuteType(MessageType, '', Request, true);
            AssertRefusal(Response, 'InvalidParameterFormat', 'endingDate');
        end;
        Assert.AreEqual(BeforeCount, Period.Count(), 'Invalid dates do not create or remove periods.');
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckBoolean(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        BadValues: JsonArray;
        Token: JsonToken;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        BadValues.ReadFrom('["maybe","true",1,{},[]]');
        foreach Token in BadValues do begin
            Clear(Request);
            Request.Add('postToGL', Token);
            Response := Library.ExecuteType("Message Type ori"::"Inventory.AdjustCost.Run", '', Request, true);
            AssertRefusal(Response, 'InvalidParameterFormat', 'postToGL');
        end;
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckAdjustmentCollection(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Errors: JsonArray;
        OldLanguage: Integer;
    begin
        EnableDomains();
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.ReadFrom('{"itemNoFilter":{},"itemCategoryFilter":[],"postToGL":"maybe"}');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.AdjustCost.Run", '', Request, true);
        Assert.AreEqual('MultipleErrors', TextValue(Response, 'code'), 'All invalid request values are collected.');
        Assert.IsTrue(Response.Get('errors', Token), 'Collected errors are present.');
        Errors := Token.AsArray();
        Assert.AreEqual(3, Errors.Count(), 'Every independent bad value is returned before the report can run.');
        foreach Token in Errors do
            AssertRefusalFields(Token.AsObject());
        GlobalLanguage(OldLanguage);
    end;

    local procedure CheckPeriodNotFound(LanguageId: Integer)
    var
        Period: Record "Inventory Period";
        Request: JsonObject;
        Response: JsonObject;
        OldLanguage: Integer;
    begin
        EnableDomains();
        Assert.IsFalse(Period.Get(20990131D), 'Owned missing date must actually be absent.');
        OldLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.Add('endingDate', '2099-01-31');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Period.Reopen", '', Request, true);
        AssertRefusal(Response, 'RecordNotFound', 'endingDate');
        Assert.AreEqual('2099-01-31', TextValue(Response, 'received'), 'Dates use an invariant ISO representation.');
        Assert.IsTrue(TextValue(Response, 'error').Contains('2099-01-31'), 'Localized message preserves ISO date.');
        GlobalLanguage(OldLanguage);
    end;

    local procedure EnableDomains()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup."Inventory Period" := true;
        Setup.Costing := true;
        Setup.Modify();
    end;

    local procedure AssertRefusal(Response: JsonObject; Code: Text; Parameter: Text)
    begin
        Assert.AreEqual('Error', TextValue(Response, 'status'), 'Structured error status.');
        Assert.AreEqual(Code, TextValue(Response, 'code'), 'Stable shared error code.');
        Assert.AreEqual(Parameter, TextValue(Response, 'parameter'), 'Failing request value is named.');
        AssertRefusalFields(Response);
    end;

    local procedure AssertRefusalFields(Response: JsonObject)
    begin
        Assert.IsTrue(TextValue(Response, 'received') <> '', 'Received value is present.');
        Assert.IsTrue(TextValue(Response, 'expected') <> '', 'Expected value is present.');
        Assert.IsTrue(TextValue(Response, 'nextStep') <> '', 'Caller gets an actionable next step.');
        Assert.IsFalse(TextValue(Response, 'error').Contains('NavJsonValue'), 'No raw runtime conversion text.');
    end;

    local procedure TextValue(Value: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if Value.Get(Name, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;
}
