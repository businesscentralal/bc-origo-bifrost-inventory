namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Requisition;
using Origo.Bifrost;

/// <summary>Creates new purchase, transfer and assembly orders from accepted New lines on one planning worksheet.</summary>
codeunit 10076939 "Plan Wksh Carry Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Writes. Creates new purchase, transfer and assembly orders from accepted New lines on one planning worksheet.', Comment = 'is-IS=Skrifar. Býr til nýjar innkaupa-, flutnings- og samsetningarpantanir úr samþykktum New-línum á einni áætlunarkeyrslu.';
        SelectionLbl: Label 'Identify one planning worksheet by subject TEMPLATE|NAME or by templateName and worksheetName.', Comment = 'is-IS=Auðkenndu eina áætlunarkeyrslu með subject TEMPLATE|NAME eða með templateName og worksheetName.';
        KeywordsLbl: Label 'planning worksheet, carry out, purchase order, transfer order, assembly order', Comment = 'is-IS=áætlunarkeyrsla, framkvæma, innkaupapöntun, flutningspöntun, samsetningarpöntun';
        OverviewLbl: Label 'Creates new purchase, transfer and assembly orders from accepted New lines on one planning worksheet. Lines that would change or delete an existing document are refused before anything is written.', Comment = 'is-IS=Býr til nýjar innkaupa-, flutnings- og samsetningarpantanir úr samþykktum New-línum á einni áætlunarkeyrslu. Línum sem myndu breyta eða eyða fyrirliggjandi skjali er hafnað áður en nokkuð er skrifað.';
        ChangesLbl: Label 'Writes. Creates new purchase, transfer and assembly orders from the accepted New lines and removes those lines from the worksheet. Lines that would cancel, change or reschedule an existing document are refused before anything is written. Created orders stay.', Comment = 'is-IS=Skrifar. Býr til nýjar innkaupa-, flutnings- og samsetningarpantanir úr samþykktum New-línum og fjarlægir þær línur af keyrslunni. Línum sem myndu ógilda, breyta eða endurtímasetja fyrirliggjandi skjal er hafnað áður en nokkuð er skrifað. Búnar pantanir standa.';
        NotesLbl: Label 'Creates new purchase, transfer and assembly orders from accepted New lines on one planning worksheet. Lines whose action would cancel, change the quantity of, or reschedule an existing document are refused before anything is written, and so is any line that names an existing document or a production order. Production lines are carried out by the Manufacturing app (Manufacturing.PlanningWorksheet.CarryOut). Unaccepted lines are left as they are unless lineNos names them. Writes. Created orders can be edited or deleted, and the consumed suggestion lines leave the worksheet. No printing or posting. A refusal before the call writes nothing. Each order is committed as it is created, so a failure after the first order can leave orders that were already created. lineNos, when sent, is a non-empty list of line numbers on that worksheet. The Planning domain must be turned on in Inventory Setup and the caller needs permission to write the suggestion lines. Use Inventory.PlanningWorksheet.Calculate first to replace the suggestion lines.', Comment = 'is-IS=Býr til nýjar innkaupa-, flutnings- og samsetningarpantanir úr samþykktum New-línum á einni áætlunarkeyrslu. Línum sem myndu ógilda, breyta magni eða endurtímasetja fyrirliggjandi skjal er hafnað áður en nokkuð er skrifað, og einnig línu sem nefnir fyrirliggjandi skjal eða framleiðslupöntun. Framleiðslulínur eru framkvæmdar í framleiðsluappinu (Manufacturing.PlanningWorksheet.CarryOut). Ósamþykktar línur standa nema lineNos nefni þær. Skrifar. Hægt er að breyta eða eyða búnum pöntunum og uppurnar tillögulínur fara af keyrslunni. Hvorki prentar né bókar. Höfnun áður en kallið keyrir skrifar ekkert. Hver pöntun er staðfest þegar hún verður til, svo bilun eftir fyrstu pöntun getur skilið eftir pantanir sem þegar hafa verið búnar til. lineNos, þegar það er sent, er listi sem er ekki tómur af línunúmerum á þeirri keyrslu. Sviðið Áætlun verður að vera virkt í uppsetningu birgða og kallandinn þarf heimild til að skrifa tillögulínurnar. Notaðu Inventory.PlanningWorksheet.Calculate fyrst til að skipta út tillögulínunum.';

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

    /// <summary>Planning worksheet carry-out is an inbound write call.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Checks the domain, the licence and the request, then carries out the accepted New lines.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Engine: Codeunit "Req. Worksheet Engine ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Planning, Database::"Requisition Line", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Engine.CarryOutWorksheet(Argument);
    end;

    /// <summary>Describes the carry-out.</summary>
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
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|NAME"],"description":"Identifies one planning worksheet as TEMPLATE|NAME. Without a subject, send templateName and worksheetName in data. Every selector that is sent must name the same worksheet."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
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

    /// <summary>Returns the parameters chapter, including the ignored compatibility parameter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Children: JsonArray;
        LineNosParameter: JsonObject;
        TemplateLbl: Label 'Name of an existing planning template that is not recurring, at most 10 characters. Send it with worksheetName unless subject identifies the worksheet.', Comment = 'is-IS=Heiti áætlunarsniðs sem er til og er ekki ítrekunarsnið, mest 10 stafir. Sendu það með worksheetName nema subject auðkenni keyrsluna.';
        WorksheetLbl: Label 'Name of an existing worksheet of that template, at most 10 characters. Every selector that is sent must name the same worksheet.', Comment = 'is-IS=Heiti keyrslu sem er til á því sniði, mest 10 stafir. Öll auðkenni sem eru send verða að nefna sömu keyrslu.';
        LineNosLbl: Label 'Line numbers to carry out. Omit it to carry out every accepted New line on the worksheet. An empty list is refused.', Comment = 'is-IS=Línunúmer sem á að framkvæma. Slepptu því til að framkvæma hverja samþykkta New-línu á keyrslunni. Tómum lista er hafnað.';
        ExpectedCountLbl: Label 'Optional compatibility parameter; accepted and ignored. No confirmation is required.', Comment = 'is-IS=Valfrjáls samhæfingarbreyta; samþykkt og hunsuð. Ekki er krafist staðfestingar.';
        LineNoLbl: Label 'One line number on the planning worksheet.', Comment = 'is-IS=Eitt línunúmer á áætlunarkeyrslunni.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, TemplateLbl));
        Parameters.Add(ContractMgt.Parameter('worksheetName', 'string', false, WorksheetLbl));
        Children.Add(ContractMgt.Parameter('lineNo', 'integer', true, LineNoLbl));
        LineNosParameter := ContractMgt.Parameter('lineNos', 'array', false, LineNosLbl);
        LineNosParameter.Add('children', Children);
        Parameters.Add(LineNosParameter);
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', false, ExpectedCountLbl));
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        OrderFields: JsonArray;
        OrdersField: JsonObject;
    begin
        Clear(Response);
        OrderFields.Add(ContractMgt.ResponseField('documentType', 'string', 'Purchase, Transfer, Assembly or Other.'));
        OrderFields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The number of the created order.'));
        OrdersField := ContractMgt.ResponseField('orders', 'array', 'The orders created by this call.');
        OrdersField.Add('children', OrderFields);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when at least one order was created.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The planning template.'));
        Fields.Add(ContractMgt.ResponseField('worksheetName', 'string', 'The planning worksheet.'));
        Fields.Add(ContractMgt.ResponseField('linesConsumed', 'integer', 'How many of the selected accepted lines left the worksheet.'));
        Fields.Add(OrdersField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        NotFoundWhenLbl: Label 'No planning worksheet matches the template and name, the template is not a planning template, or a line number in lineNos is not on the worksheet.', Comment = 'is-IS=Engin áætlunarkeyrsla passar við sniðið og heitið, sniðið er ekki áætlunarsnið, eða línunúmer í lineNos er ekki á keyrslunni.';
        NotFoundFixLbl: Label 'Send an existing planning worksheet and, when used, line numbers from that worksheet.', Comment = 'is-IS=Sendu áætlunarkeyrslu sem er til og, þegar það er notað, línunúmer af þeirri keyrslu.';
        MissingWhenLbl: Label 'The worksheet is not identified.', Comment = 'is-IS=Keyrslan er ekki auðkennd.';
        MissingFixLbl: Label 'Send subject TEMPLATE|NAME or templateName and worksheetName.', Comment = 'is-IS=Sendu subject SNIÐ|HEITI eða templateName og worksheetName.';
        FormatWhenLbl: Label 'A name is not text or is too long, lineNos is not a list of positive JSON integers.', Comment = 'is-IS=Heiti er ekki texti eða er of langt, lineNos er ekki listi af jákvæðum JSON-heiltölum.';
        FormatFixLbl: Label 'Correct the value named in the answer.', Comment = 'is-IS=Leiðréttu gildið sem svarið nefnir.';
        InvalidWhenLbl: Label 'lineNos is empty, an unknown key is sent, or the Planning domain is turned off.', Comment = 'is-IS=lineNos er tómt, óþekktur lykill er sendur, eða slökkt er á sviðinu Áætlun.';
        InvalidFixLbl: Label 'Correct the value named in the answer, or turn the Planning domain on from Inventory Setup.', Comment = 'is-IS=Leiðréttu gildið sem svarið nefnir, eða kveiktu á sviðinu Áætlun í uppsetningu birgða.';
        ConflictWhenLbl: Label 'subject and templateName or worksheetName name different worksheets.', Comment = 'is-IS=subject og templateName eða worksheetName nefna ólíkar keyrslur.';
        ConflictFixLbl: Label 'Send one worksheet. Every selector that is sent must agree.', Comment = 'is-IS=Sendu eina keyrslu. Öll auðkenni sem eru send verða að stemma.';
        PreconditionWhenLbl: Label 'The template is recurring, nothing is accepted, or an accepted line would change or delete an existing document or create a production order.', Comment = 'is-IS=Sniðið er ítrekunarsnið, ekkert er samþykkt, eða samþykkt lína myndi breyta eða eyða fyrirliggjandi skjali eða búa til framleiðslupöntun.';
        PreconditionFixLbl: Label 'Keep only accepted New lines for a new purchase, transfer or assembly order. A refusal writes nothing.', Comment = 'is-IS=Haltu aðeins samþykktum New-línum fyrir nýja innkaupa-, flutnings- eða samsetningarpöntun. Höfnun skrifar ekkert.';
        PermissionWhenLbl: Label 'The caller cannot write suggestion lines.', Comment = 'is-IS=Kallandinn getur ekki skrifað tillögulínur.';
        PermissionFixLbl: Label 'Ask an administrator for a permission set that can write the suggestion lines.', Comment = 'is-IS=Biddu kerfisstjóra um heimildasafn sem getur skrifað tillögulínurnar.';
        NativeWhenLbl: Label 'Order creation stops on a native validation error. Orders created before the failure remain.', Comment = 'is-IS=Gerð pöntunar stöðvast á villu í staðfestingu. Pantanir sem urðu til fyrir bilunina standa.';
        NativeFixLbl: Label 'Check the orders that were created and the lines still on the worksheet before you try again.', Comment = 'is-IS=Athugaðu pantanirnar sem urðu til og línurnar sem enn eru á keyrslunni áður en þú reynir aftur.';
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
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('rollback', false);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('The Planning domain is turned on in Inventory Setup.');
        Preconditions.Add('The worksheet is an existing non-recurring planning worksheet.');
        Preconditions.Add('Every line that would be carried out is an accepted New purchase, transfer or assembly line and does not name an existing document.');
        Effect.Add('preconditions', Preconditions);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.PlanningWorksheet.Calculate', 'Use it first to replace the suggestion lines on the planning worksheet.'));
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
        ParameterExample1Lbl: Label 'Select existing line numbers from your own document or worksheet', Comment = 'is-IS=Velja fyrirliggjandi línunúmer úr eigin skjali eða vinnublaði';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Carry out the accepted New lines on worksheet WEEK',
            '{"type":"Inventory.PlanningWorksheet.CarryOut","subject":"PLAN|WEEK","data":{}}',
            '{"status":"Success","templateName":"PLAN","worksheetName":"WEEK","linesConsumed":1,"orders":[{"documentType":"Purchase","documentNo":"106001"}]}'));
        Examples.Add(ContractMgt.Example(ParameterExample1Lbl, '{"type":"Inventory.PlanningWorksheet.CarryOut","subject":"PLAN|WEEK","data":{"expectedCount":1,"lineNos":[10000]}}', '{"status":"Success","templateName":"PLAN","worksheetName":"WEEK","linesConsumed":1,"orders":[{"documentType":"Purchase","documentNo":"106001"}]}'));
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
