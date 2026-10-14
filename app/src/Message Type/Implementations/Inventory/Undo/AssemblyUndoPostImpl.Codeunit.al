namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
using Origo.Bifrost;

codeunit 70013482 "Assembly Undo Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Undoes a posted assembly document through the native assembly posting codeunit.', Comment = 'is-IS=Afturkallar bókað samsetningarskjal með innbyggðri bókunareiningu samsetninga.';
        KeywordsLbl: Label 'undo assembly, reverse posted assembly', Comment = 'is-IS=afturkalla samsetningu, bakfæra bókaða samsetningu';
        SelectionDescriptionLbl: Label 'Undoes a posted assembly by document number; optionally recreates its order.', Comment = 'is-IS=Afturkallar bókaða samsetningu eftir skjalnúmeri; getur endurstofnað pöntunina.';
        OverviewLbl: Label 'Calls Assembly-Post.Undo with the requested recreateOrder option.', Comment = 'is-IS=Kallar á Assembly-Post.Undo með umbeðnum valkosti recreateOrder.';
        NotesLbl: Label 'Native validation refuses reversed or consumed output. A failed undo rolls back its writes.', Comment = 'is-IS=Innbyggð sannprófun hafnar bakfærðri eða notaðri frálagsfærslu. Misheppnuð afturköllun bakfærir breytingarnar.';

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Posted Assembly Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Assembly.UndoPost');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Posted Assembly Header');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, ''));
        Parameters.Add(ContractMgt.Parameter('recreateOrder', 'boolean', false, ''));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('documentNo', '');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'MissingParameter');
        ErrorJson.Add('when', 'documentNo is required.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'RecordNotFound');
        ErrorJson.Add('when', 'the posted assembly was not found.');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Post an assembly order instead of undoing a posted assembly.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Checks company, posting, native write and license permissions before isolated native undo.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv Native Undo Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv Native Undo Process ori", Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
