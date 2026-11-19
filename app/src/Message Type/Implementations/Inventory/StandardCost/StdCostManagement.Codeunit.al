namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Manufacturing.StandardCost;
using Origo.Bifrost;

/// <summary>Validates standard cost requests before running the native report in an isolated transaction.</summary>
codeunit 10076934 "Std. Cost Management ori"
{
    Access = Internal;

    /// <summary>Checks the domain and all native table permissions required by the chosen operation.</summary>
    procedure IsEnabled(Implement: Boolean): Boolean
    var
        Setup: Record "Inventory Setup ori";
    begin
        if not Setup.ReadPermission() then
            exit(false);
        exit(Setup.IsDomainEnabled("Inventory Domain ori"::Costing) and CanAccess(Implement));
    end;

    /// <summary>Dispatches a validated operation, preserving Omit Commit and answering native failures with a next step.</summary>
    procedure ExecuteSuggest(var Argument: Record "Message Argument ori")
    var
        SuggestProcess: Codeunit "Std. Cost Suggest Proc ori";
        NativeNextStepLbl: Label 'Correct the Business Central error and retry. No standard cost changes from this call were saved.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur. Engar staðalkostnaðarbreytingar úr þessu kalli voru vistaðar.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not ValidateSuggest(Argument) then
            exit;
        if Argument."Omit Commit" then
            SuggestProcess.Run(Argument)
        else
            if not SuggestProcess.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NativeNextStepLbl);
    end;

    /// <summary>Dispatches a validated operation, preserving Omit Commit and answering native failures with a next step.</summary>
    procedure ExecuteImplement(var Argument: Record "Message Argument ori")
    var
        ImplementProcess: Codeunit "Std. Cost Process ori";
        NativeNextStepLbl: Label 'Correct the Business Central error and retry. No standard cost changes from this call were saved.', Comment = 'is-IS=Leiðréttu villuna í Business Central og reyndu aftur. Engar staðalkostnaðarbreytingar úr þessu kalli voru vistaðar.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not ValidateImplement(Argument) then
            exit;
        if Argument."Omit Commit" then
            ImplementProcess.Run(Argument)
        else
            if not ImplementProcess.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NativeNextStepLbl);
    end;

    /// <summary>Validates shared setup and request shape before writing any record.</summary>
    local procedure ValidateCommon(var Argument: Record "Message Argument ori"; Implement: Boolean): Boolean
    var
        Setup: Record "Inventory Setup ori";
        WorksheetName: Record "Standard Cost Worksheet Name";
        Request: JsonObject;
        KeyName: Text;
        Allowed: List of [Text];
        ValueText: Text;
        WorksheetCode: Code[10];
        PermissionLbl: Label 'Permission to read or change standard cost data is missing.', Comment = 'is-IS=Heimild til að lesa eða breyta staðalkostnaðargögnum vantar.';
        PermissionNextLbl: Label 'Ask an administrator for BIFROST Full ori and the native worksheet, item, stockkeeping unit and journal permissions needed for this operation.', Comment = 'is-IS=Biddu kerfisstjóra um BIFROST Full ori og nauðsynlegar heimildir fyrir vinnublað, vörur, birgðahaldseiningar og bók fyrir þessa aðgerð.';
        UnknownLbl: Label 'The request contains an unknown parameter.', Comment = 'is-IS=Beiðnin inniheldur óþekkta færibreytu.';
        UnknownNextLbl: Label 'Remove the parameter and use only parameters listed in help for this message type.', Comment = 'is-IS=Fjarlægðu færibreytuna og notaðu aðeins færibreytur sem hjálp fyrir þessa skilaboðategund tilgreinir.';
        MissingWorksheetLbl: Label 'The standard cost worksheet name does not exist.', Comment = 'is-IS=Heiti staðalkostnaðarvinnublaðsins er ekki til.';
        WorksheetNextLbl: Label 'Create the worksheet name in Business Central or choose an existing worksheet.', Comment = 'is-IS=Stofnaðu heiti vinnublaðsins í Business Central eða veldu vinnublað sem er til.';
    begin
        if not CanAccess(Implement) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', PermissionNextLbl));
        if not Setup.ReadPermission() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', PermissionNextLbl));
        Request := Argument.GetRequestJson();
        Allowed.Add('worksheetName');
        if Implement then begin
            Allowed.Add('journalTemplateName');
            Allowed.Add('journalBatchName');
            Allowed.Add('postingDate');
            Allowed.Add('documentNo');
        end else begin
            Allowed.Add('itemFilter');
            Allowed.Add('adjustmentFactor');
        end;
        foreach KeyName in Request.Keys() do
            if not Allowed.Contains(KeyName) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, UnknownLbl, KeyName, UnknownNextLbl));
        if not RequireText(Argument, Request, 'worksheetName', 10, ValueText) then
            exit(false);
        WorksheetCode := CopyStr(ValueText, 1, 10);
        if not WorksheetName.Get(WorksheetCode) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, MissingWorksheetLbl, 'worksheetName', WorksheetNextLbl));
        exit(true);
    end;

    /// <summary>Validates a suggestion before writing any record.</summary>
    procedure ValidateSuggest(var Argument: Record "Message Argument ori"): Boolean
    var
        Item: Record Item;
        Request: JsonObject;
        ValueText: Text;
        Factor: Decimal;
        FactorLbl: Label 'adjustmentFactor must be a positive JSON number.', Comment = 'is-IS=adjustmentFactor verður að vera jákvæð JSON-tala.';
        FactorNextLbl: Label 'Send adjustmentFactor as a number greater than zero, for example 1.1.', Comment = 'is-IS=Sendu adjustmentFactor sem tölu stærri en núll, til dæmis 1.1.';
        FilterLbl: Label 'The item filter is invalid.', Comment = 'is-IS=Vörusían er ógild.';
        FilterNextLbl: Label 'Send a valid Business Central item number filter in itemFilter.', Comment = 'is-IS=Sendu gilda Business Central síu á vörunúmer í itemFilter.';
        NoItemsLbl: Label 'The filter matches no inventory items with Standard costing.', Comment = 'is-IS=Sían finnur engar birgðavörur með staðalkostnað.';
        ItemsNextLbl: Label 'Choose inventory items with the Standard costing method and retry.', Comment = 'is-IS=Veldu birgðavörur með staðalkostnaðaraðferð og reyndu aftur.';
        SelectionLbl: Label 'The worksheet contains a non-item line, an implemented line, or an item that is blocked or no longer uses Standard costing.', Comment = 'is-IS=Vinnublaðið inniheldur línu sem er ekki vara, þegar framkvæmda línu, eða vöru sem er lokuð eða notar ekki lengur staðalkostnað.';
        SelectionNextLbl: Label 'Review the worksheet in Business Central and use only unimplemented lines for unblocked Standard-cost inventory items.', Comment = 'is-IS=Yfirfarðu vinnublaðið í Business Central og notaðu aðeins óframkvæmdar línur fyrir ólokaðar birgðavörur með staðalkostnað.';
    begin
        if not ValidateCommon(Argument, false) then
            exit(false);
        Request := Argument.GetRequestJson();
        if not RequireText(Argument, Request, 'itemFilter', 2048, ValueText) then
            exit(false);
        if not ReadFactor(Request, Factor) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, FactorLbl, 'adjustmentFactor', FactorNextLbl));
        if not FilterItems(Item, ValueText) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, FilterLbl, 'itemFilter', FilterNextLbl));
        if Item.IsEmpty() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NoItemsLbl, 'itemFilter', ItemsNextLbl));
        Item.SetRange(Blocked, true);
        if not Item.IsEmpty() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SelectionLbl, 'itemFilter', SelectionNextLbl));
        exit(true);
    end;

    /// <summary>Validates an implementation before writing any record.</summary>
    procedure ValidateImplement(var Argument: Record "Message Argument ori"): Boolean
    var
        Worksheet: Record "Standard Cost Worksheet";
        Item: Record Item;
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
        ValueText: Text;
        PostingDate: Date;
        WorksheetCode: Code[10];
        TemplateCode: Code[10];
        BatchCode: Code[10];
        DateLbl: Label 'postingDate must be a nonzero ISO date (yyyy-mm-dd).', Comment = 'is-IS=postingDate verður að vera gild ISO-dagsetning (yyyy-mm-dd).';
        DateNextLbl: Label 'Send the intended revaluation date as yyyy-mm-dd.', Comment = 'is-IS=Sendu fyrirhugaða endurmatsdagsetningu sem yyyy-mm-dd.';
        JournalLbl: Label 'The revaluation journal template or batch is missing or has the wrong type.', Comment = 'is-IS=Sniðmát eða keyrsla endurmatsbókar vantar eða er af rangri gerð.';
        JournalNextLbl: Label 'Create or select a Revaluation journal template and an existing batch.', Comment = 'is-IS=Stofnaðu eða veldu sniðmát endurmatsbókar og keyrslu sem er til.';
        JournalNotEmptyLbl: Label 'The selected revaluation journal batch is not empty.', Comment = 'is-IS=Valin endurmatsbókarkeyrsla er ekki tóm.';
        JournalEmptyNextLbl: Label 'Use an empty revaluation journal batch; review existing lines separately before retrying.', Comment = 'is-IS=Notaðu tóma endurmatsbókarkeyrslu; yfirfarðu fyrirliggjandi línur sérstaklega áður en þú reynir aftur.';
        EmptyLbl: Label 'The standard cost worksheet is empty.', Comment = 'is-IS=Staðalkostnaðarvinnublaðið er tómt.';
        SuggestNextLbl: Label 'Run Inventory.StandardCost.Suggest for this worksheet first.', Comment = 'is-IS=Keyrðu fyrst Inventory.StandardCost.Suggest fyrir þetta vinnublað.';
        SelectionLbl: Label 'The worksheet contains a non-item line, an implemented line, or an item that is blocked or no longer uses Standard costing.', Comment = 'is-IS=Vinnublaðið inniheldur línu sem er ekki vara, þegar framkvæmda línu, eða vöru sem er lokuð eða notar ekki lengur staðalkostnað.';
        SelectionNextLbl: Label 'Review the worksheet in Business Central and use only unimplemented lines for unblocked Standard-cost inventory items.', Comment = 'is-IS=Yfirfarðu vinnublaðið í Business Central og notaðu aðeins óframkvæmdar línur fyrir ólokaðar birgðavörur með staðalkostnað.';
    begin
        if not ValidateCommon(Argument, true) then
            exit(false);
        Request := Argument.GetRequestJson();
        WorksheetCode := CopyStr(ReadText(Request, 'worksheetName'), 1, 10);
        if not RequireText(Argument, Request, 'journalTemplateName', 10, ValueText) then
            exit(false);
        TemplateCode := CopyStr(ValueText, 1, 10);
        if not RequireText(Argument, Request, 'journalBatchName', 10, ValueText) then
            exit(false);
        BatchCode := CopyStr(ValueText, 1, 10);
        if not RequireText(Argument, Request, 'documentNo', 20, ValueText) then
            exit(false);
        if not RequireText(Argument, Request, 'postingDate', 10, ValueText) then
            exit(false);
        if not Evaluate(PostingDate, ValueText, 9) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, DateLbl, 'postingDate', DateNextLbl));
        if (PostingDate = 0D) or (Format(PostingDate, 0, 9) <> ValueText) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, DateLbl, 'postingDate', DateNextLbl));
        if not JournalTemplate.Get(TemplateCode) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, JournalLbl, 'journalTemplateName', JournalNextLbl));
        if JournalTemplate.Type <> JournalTemplate.Type::Revaluation then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, JournalLbl, 'journalTemplateName', JournalNextLbl));
        if not Batch.Get(TemplateCode, BatchCode) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, JournalLbl, 'journalBatchName', JournalNextLbl));
        Line.SetRange("Journal Template Name", TemplateCode);
        Line.SetRange("Journal Batch Name", BatchCode);
        if not Line.IsEmpty() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, JournalNotEmptyLbl, 'journalBatchName', JournalEmptyNextLbl));
        Worksheet.SetRange("Standard Cost Worksheet Name", WorksheetCode);
        if not Worksheet.FindSet() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, EmptyLbl, 'worksheetName', SuggestNextLbl));
        repeat
            if (Worksheet.Type <> Worksheet.Type::Item) or Worksheet.Implemented then
                exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SelectionLbl, 'worksheetName', SelectionNextLbl));
            if not Item.Get(Worksheet."No.") then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, SelectionLbl, 'worksheetName', SelectionNextLbl));
            if Item.Blocked or (Item.Type <> Item.Type::Inventory) or (Item."Costing Method" <> Item."Costing Method"::Standard) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, SelectionLbl, 'worksheetName', SelectionNextLbl));
        until Worksheet.Next() = 0;
        exit(true);
    end;

    /// <summary>Applies and evaluates a caller filter without changing data.</summary>
    [TryFunction]
    procedure FilterItems(var Item: Record Item; ItemFilter: Text)
    begin
        Item.Reset();
        Item.SetFilter("No.", ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange("Costing Method", Item."Costing Method"::Standard);
        if Item.FindFirst() then;
    end;

    /// <summary>Reads a positive JSON number without accepting strings, booleans or objects.</summary>
    procedure ReadFactor(Request: JsonObject; var Factor: Decimal): Boolean
    var
        Token: JsonToken;
        JsonText: Text;
    begin
        if not Request.Get('adjustmentFactor', Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(JsonText);
        if CopyStr(JsonText, 1, 1) = '"' then
            exit(false);
        if not Evaluate(Factor, JsonText, 9) then
            exit(false);
        exit(Factor > 0);
    end;

    /// <summary>Reads a previously validated text parameter.</summary>
    procedure ReadText(Request: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Request.Get(KeyName, Token);
        exit(Token.AsValue().AsText().Trim());
    end;

    local procedure RequireText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; MaxLength: Integer; var ValueText: Text): Boolean
    var
        Token: JsonToken;
        JsonText: Text;
        MissingLbl: Label 'A required text parameter is missing or empty.', Comment = 'is-IS=Áskilin textafæribreyta vantar eða er tóm.';
        FormatLbl: Label 'The parameter must be JSON text within its documented length.', Comment = 'is-IS=Færibreytan verður að vera JSON-texti innan tilgreindrar lengdar.';
        NextLbl: Label 'Send %1 as nonempty text of at most %2 characters.', Comment = '%1 = parameter, %2 = maximum length, is-IS=Sendu %1 sem ótóman texta sem er mest %2 stafir.';
    begin
        if not Request.Get(KeyName, Token) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, KeyName, StrSubstNo(NextLbl, KeyName, MaxLength)));
        Token.WriteTo(JsonText);
        if (not Token.IsValue()) or (CopyStr(JsonText, 1, 1) <> '"') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, FormatLbl, KeyName, StrSubstNo(NextLbl, KeyName, MaxLength)));
        ValueText := Token.AsValue().AsText().Trim();
        if ValueText = '' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, KeyName, StrSubstNo(NextLbl, KeyName, MaxLength)));
        if StrLen(ValueText) > MaxLength then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, FormatLbl, KeyName, StrSubstNo(NextLbl, KeyName, MaxLength)));
        exit(true);
    end;

    local procedure CanAccess(Implement: Boolean): Boolean
    var
        WorksheetName: Record "Standard Cost Worksheet Name";
        Worksheet: Record "Standard Cost Worksheet";
        Item: Record Item;
        SKU: Record "Stockkeeping Unit";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        if not (WorksheetName.ReadPermission() and Worksheet.ReadPermission() and Worksheet.WritePermission() and Item.ReadPermission()) then
            exit(false);
        if Implement then
            exit(Item.WritePermission() and SKU.ReadPermission() and SKU.WritePermission() and JournalTemplate.ReadPermission() and Batch.ReadPermission() and Line.ReadPermission() and Line.WritePermission());
        exit(true);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; KeyName: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, MessageText, CopyStr(KeyName, 1, 250), '', '', NextStep);
        exit(false);
    end;
}
