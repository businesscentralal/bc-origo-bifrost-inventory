namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Requisition;
using Origo.Bifrost;

/// <summary>Replaces suggestion lines on one planning worksheet and returns the new lines.</summary>
codeunit 10076930 "Plan Wksh Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Replaces suggestion lines for the selected items on one planning worksheet and returns the new lines.', Comment = 'is-IS=Skiptir út tillögum valinna vara á einni áætlunarkeyrslu og skilar nýju línunum.';
        SelectionLbl: Label 'Identify one planning worksheet by subject TEMPLATE|NAME or by templateName and worksheetName.', Comment = 'is-IS=Auðkenndu eina áætlunarkeyrslu með subject TEMPLATE|NAME eða með templateName og worksheetName.';
        KeywordsLbl: Label 'planning worksheet, calculate plan, regenerative, net change, MRP', Comment = 'is-IS=áætlunarkeyrsla, reikna áætlun, endurnýjun, nettóbreyting, MRP';
        OverviewLbl: Label 'Replaces suggestion lines for the selected items on one planning worksheet. Nothing is posted. A failure after the first item can leave lines already calculated on that worksheet.', Comment = 'is-IS=Skiptir út tillögum valinna vara á einni áætlunarkeyrslu. Ekkert er bókað. Bilun eftir fyrstu vöru getur skilið eftir línur sem þegar hafa verið reiknaðar á þeirri keyrslu.';
        NotesLbl: Label 'The call replaces suggestion lines for the selected items on this planning worksheet only. Lines on other worksheets stay as they are, and lines for items outside the filter stay. The calculation commits as it proceeds, so a failure after the first item can leave lines already calculated on this worksheet. Nothing is posted. mode is regenerative or netChange. startingDate and endingDate are required, in YYYY-MM-DD form, and the ending date must not be before the starting date. itemNo, locationCode and variantCode are filter expressions of at most 2048 characters. Identify the worksheet with subject TEMPLATE|NAME or with templateName and worksheetName, and every selector that is sent must agree. The worksheet must already exist and belong to a planning template that is not recurring. The Planning domain must be turned on in Inventory Setup and the caller needs permission to write the suggestion lines. Call Inventory.PlanningWorksheet.CarryOut to create new orders from accepted New lines.', Comment = 'is-IS=Kallið skiptir út tillögum valinna vara á þessari áætlunarkeyrslu eingöngu. Línur á öðrum keyrslum standa og línur vara utan síunnar standa. Útreikningurinn staðfestir eftir því sem hann vindur fram, svo bilun eftir fyrstu vöru getur skilið eftir línur sem þegar hafa verið reiknaðar á þessari keyrslu. Ekkert er bókað. mode er regenerative eða netChange. startingDate og endingDate eru nauðsynleg, á forminu ÁÁÁÁ-MM-DD, og lokadagur má ekki vera á undan upphafsdegi. itemNo, locationCode og variantCode eru síur, mest 2048 stafir. Auðkenndu keyrsluna með subject TEMPLATE|NAME eða með templateName og worksheetName og öll auðkenni sem eru send verða að stemma. Keyrslan verður að vera til og tilheyra áætlunarsniði sem er ekki ítrekunarsnið. Sviðið Áætlun verður að vera virkt í uppsetningu birgða og kallandinn þarf heimild til að skrifa tillögulínurnar. Kallaðu á Inventory.PlanningWorksheet.CarryOut til að búa til nýjar pantanir úr samþykktum New-línum.';

    /// <summary>Requires the Planning domain and write permission on suggestion lines.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::Planning, Database::"Requisition Line", true, false));
    end;

    /// <summary>Returns the worksheet selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Requisition Wksh. Name");
    end;

    /// <summary>Planning worksheet calculation is an inbound write.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Checks the domain, the licence and the request, then calculates the worksheet.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Engine: Codeunit "Req. Worksheet Engine ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Planning, Database::"Requisition Line", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Engine.CalculateWorksheet(Argument);
    end;

    /// <summary>Describes the calculation.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Describes how to identify the worksheet.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Returns the search keywords.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the envelope chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|NAME"],"description":"Identifies one planning worksheet as TEMPLATE|NAME. Without a subject, send templateName and worksheetName in data. Every selector that is sent must name the same worksheet."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the target chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('subject', 'TEMPLATE|NAME', 'The planning template name and the worksheet name, each at most 10 characters, separated by a vertical bar. The template must be a planning template that is not recurring.'));
        Target.Add(ContractMgt.TargetEntry('data.templateName, data.worksheetName', 'template and worksheet name', 'The template and the worksheet together. Every selector that is sent must name the same worksheet.'));
        exit(true);
    end;

    /// <summary>Returns the parameters chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TemplateLbl: Label 'Name of an existing planning template that is not recurring, at most 10 characters. Send it with worksheetName unless subject identifies the worksheet.', Comment = 'is-IS=Heiti áætlunarsniðs sem er til og er ekki ítrekunarsnið, mest 10 stafir. Sendu það með worksheetName nema subject auðkenni keyrsluna.';
        WorksheetLbl: Label 'Name of an existing worksheet of that template, at most 10 characters. Every selector that is sent must name the same worksheet.', Comment = 'is-IS=Heiti keyrslu sem er til á því sniði, mest 10 stafir. Öll auðkenni sem eru send verða að nefna sömu keyrslu.';
        ModeLbl: Label 'regenerative replaces the plan for every selected item. netChange plans only items with a net-change planning assignment. Any other value is refused.', Comment = 'is-IS=regenerative skiptir út áætlun hverrar valinnar vöru. netChange áætlar aðeins vörur með úthlutun nettóbreytingar. Öðrum gildum er hafnað.';
        StartingLbl: Label 'First date of the planning period, YYYY-MM-DD. Required.', Comment = 'is-IS=Fyrsti dagur áætlunartímabilsins, ÁÁÁÁ-MM-DD. Nauðsynlegt.';
        EndingLbl: Label 'Last date of the planning period, YYYY-MM-DD. Required, and it must not be before startingDate.', Comment = 'is-IS=Síðasti dagur áætlunartímabilsins, ÁÁÁÁ-MM-DD. Nauðsynlegt og má ekki vera á undan startingDate.';
        ItemLbl: Label 'Item number filter, a filter expression of at most 2048 characters. Omit it to include every inventory item.', Comment = 'is-IS=Sía vörunúmers, síu sem er mest 2048 stafir. Slepptu henni til að taka allar birgðavörur með.';
        LocationLbl: Label 'Location filter for the calculation, a filter expression of at most 2048 characters.', Comment = 'is-IS=Staðsetningarsía útreikningsins, síu sem er mest 2048 stafir.';
        VariantLbl: Label 'Variant filter for the calculation, a filter expression of at most 2048 characters.', Comment = 'is-IS=Afbrigðasía útreikningsins, síu sem er mest 2048 stafir.';
        Parameter: JsonObject;
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, TemplateLbl));
        Parameters.Add(ContractMgt.Parameter('worksheetName', 'string', false, WorksheetLbl));
        Parameters.Add(ContractMgt.Parameter('mode', 'string', true, ModeLbl));
        Parameter := ContractMgt.Parameter('startingDate', 'string', true, StartingLbl);
        Parameter.Add('format', 'YYYY-MM-DD');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter := ContractMgt.Parameter('endingDate', 'string', true, EndingLbl);
        Parameter.Add('format', 'YYYY-MM-DD');
        Parameters.Add(Parameter);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemLbl));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, LocationLbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, VariantLbl));
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        LineFields: JsonArray;
        LinesField: JsonObject;
    begin
        Clear(Response);
        LineFields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'The suggestion line number.'));
        LineFields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number.'));
        LineFields.Add(ContractMgt.ResponseField('variantCode', 'string', 'The variant code, or blank.'));
        LineFields.Add(ContractMgt.ResponseField('locationCode', 'string', 'The location code, or blank.'));
        LineFields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The suggested quantity.'));
        LineFields.Add(ContractMgt.ResponseField('dueDate', 'string', 'The due date in YYYY-MM-DD form, or blank when the line has no due date.'));
        LineFields.Add(ContractMgt.ResponseField('actionMessage', 'string', 'New, ChangeQty, Reschedule, RescheduleAndChangeQty, Cancel or None.'));
        LineFields.Add(ContractMgt.ResponseField('replenishmentSystem', 'string', 'Purchase, Transfer, Assembly, ProdOrder or Other.'));
        LineFields.Add(ContractMgt.ResponseField('description', 'string', 'The line description.'));
        LineFields.Add(ContractMgt.ResponseField('acceptActionMessage', 'boolean', 'True when the line is accepted for a later carry-out.'));
        LinesField := ContractMgt.ResponseField('lines', 'array', 'The suggestion lines on the worksheet that match the item, location and variant filters after the calculation.');
        LinesField.Add('children', LineFields);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the calculation finished.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The planning template.'));
        Fields.Add(ContractMgt.ResponseField('worksheetName', 'string', 'The planning worksheet.'));
        Fields.Add(ContractMgt.ResponseField('mode', 'string', 'regenerative or netChange.'));
        Fields.Add(ContractMgt.ResponseField('startingDate', 'string', 'The starting date in YYYY-MM-DD form.'));
        Fields.Add(ContractMgt.ResponseField('endingDate', 'string', 'The ending date in YYYY-MM-DD form.'));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'The number of suggestion lines returned. Zero is a successful calculation that suggested nothing.'));
        Fields.Add(LinesField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        NotFoundWhenLbl: Label 'No planning worksheet matches the template and name, the template is not a planning template, or a requested selector names a missing worksheet.', Comment = 'is-IS=Engin áætlunarkeyrsla passar við sniðið og heitið, sniðið er ekki áætlunarsnið, eða auðkenni nefnir keyrslu sem er ekki til.';
        NotFoundFixLbl: Label 'Send the template and name of an existing planning worksheet.', Comment = 'is-IS=Sendu snið og heiti áætlunarkeyrslu sem er til.';
        MissingWhenLbl: Label 'mode, startingDate or endingDate is absent, or the worksheet is not identified.', Comment = 'is-IS=mode, startingDate eða endingDate vantar, eða keyrslan er ekki auðkennd.';
        MissingFixLbl: Label 'Send mode, startingDate and endingDate, and identify one worksheet.', Comment = 'is-IS=Sendu mode, startingDate og endingDate og auðkenndu eina keyrslu.';
        FormatWhenLbl: Label 'A date is not YYYY-MM-DD, a name or filter is not text or is too long, or a filter expression is not valid.', Comment = 'is-IS=Dagsetning er ekki ÁÁÁÁ-MM-DD, heiti eða sía er ekki texti eða er of langt, eða síu er ekki gild.';
        FormatFixLbl: Label 'Correct the value named in the answer.', Comment = 'is-IS=Leiðréttu gildið sem svarið nefnir.';
        InvalidWhenLbl: Label 'mode is not regenerative or netChange, the ending date is before the starting date, the Planning domain is turned off, or an unknown key is sent.', Comment = 'is-IS=mode er hvorki regenerative né netChange, lokadagur er á undan upphafsdegi, slökkt er á sviðinu Áætlun, eða óþekktur lykill er sendur.';
        InvalidFixLbl: Label 'Correct the value named in the answer, or turn the Planning domain on from Inventory Setup.', Comment = 'is-IS=Leiðréttu gildið sem svarið nefnir, eða kveiktu á sviðinu Áætlun í uppsetningu birgða.';
        ConflictWhenLbl: Label 'subject and templateName or worksheetName name different worksheets.', Comment = 'is-IS=subject og templateName eða worksheetName nefna ólíkar keyrslur.';
        ConflictFixLbl: Label 'Send one worksheet. Every selector that is sent must agree.', Comment = 'is-IS=Sendu eina keyrslu. Öll auðkenni sem eru send verða að stemma.';
        PreconditionWhenLbl: Label 'The planning template is recurring.', Comment = 'is-IS=Áætlunarsniðið er ítrekunarsnið.';
        PreconditionFixLbl: Label 'Choose a planning worksheet that is not recurring.', Comment = 'is-IS=Veldu áætlunarkeyrslu sem er ekki ítrekunarsnið.';
        PermissionWhenLbl: Label 'The caller cannot write suggestion lines.', Comment = 'is-IS=Kallandinn getur ekki skrifað tillögulínur.';
        PermissionFixLbl: Label 'Ask an administrator for a permission set that can write the suggestion lines.', Comment = 'is-IS=Biddu kerfisstjóra um heimildasafn sem getur skrifað tillögulínurnar.';
        NativeWhenLbl: Label 'The calculation stops on a native validation error. Lines for items already calculated on this worksheet may remain.', Comment = 'is-IS=Útreikningurinn stöðvast á villu í staðfestingu. Línur vara sem þegar voru reiknaðar á þessari keyrslu geta staðið eftir.';
        NativeFixLbl: Label 'Correct the cause and calculate this worksheet again. Other worksheets were not changed.', Comment = 'is-IS=Leiðréttu orsökina og reiknaðu þessa keyrslu aftur. Aðrar keyrslur breyttust ekki.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionWhenLbl, PreconditionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeWhenLbl, NativeFixLbl));
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Replaces suggestion lines for the selected items on this planning worksheet and returns the lines that remain for those filters. Lines on other worksheets are not changed. Nothing is posted. The calculation commits as it proceeds, so a failure after the first item can leave lines already calculated on this worksheet.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('rollback', false);
        exit(true);
    end;

    /// <summary>Leaves metering to the composed contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.PlanningWorksheet.CarryOut', 'Use it to create new purchase, transfer and assembly orders from the accepted New lines.'));
        exit(true);
    end;

    /// <summary>Returns the workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PlanningWorksheet.Calculate', 'Replace the suggestion lines on one planning worksheet.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.PlanningWorksheet.CarryOut', 'Create new orders from the accepted New lines.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Returns the examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Calculate a regenerative plan for item 1000',
            '{"type":"Inventory.PlanningWorksheet.Calculate","subject":"PLAN|WEEK","data":{"mode":"regenerative","startingDate":"2026-11-17","endingDate":"2027-11-17","itemNo":"1000"}}',
            '{"status":"Success","templateName":"PLAN","worksheetName":"WEEK","mode":"regenerative","startingDate":"2026-11-17","endingDate":"2027-11-17","lineCount":1,"lines":[{"lineNo":10000,"itemNo":"1000","variantCode":"","locationCode":"","quantity":25,"dueDate":"2026-11-17","actionMessage":"New","replenishmentSystem":"Purchase","description":"Bicycle","acceptActionMessage":true}]}'));
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;
}
