namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Previews selected Transfer journal lines through native posting rollback.</summary>
codeunit 70013474 "Reclass Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Requires company Reclassification, native journal writes and a posting token.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true));
    end;

    /// <summary>Returns the batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Reclassification requests use inbound dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Preserves native permissions, company and license checks.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Journal.Preview(Argument, "Item Journal Template Type"::Transfer);
    end;

    /// <summary>Returns the native reclassification envelope contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["TEMPLATE|BATCH","systemId"]},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Returns the native reclassification target contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[{"table":"Item Journal Batch","selection":"An explicitly identified Transfer template batch."}]');
        exit(true);
    end;

    /// <summary>Returns the native reclassification parameters contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"templateName","type":"string","required":false},{"name":"batchName","type":"string","required":false},{"name":"journalTemplateName","type":"string","required":false},{"name":"journalBatchName","type":"string","required":false},{"name":"lineSystemIds","type":"array","required":false}]');
        exit(true);
    end;

    /// <summary>Returns the native reclassification response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"status":"Success","linesToPost":0,"rollback":true,"preview":[],"result":[]}');
        exit(true);
    end;

    /// <summary>Returns the native reclassification errors contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"PreconditionFailed","when":"Wrong journal type, recurring or invalid batch, or native calculation/posting failure."},{"code":"PermissionDenied","when":"Company/native permission or posting gate refuses caller."},{"code":"InvalidParameter","when":"Parameters are malformed or unsupported."}]');
        exit(true);
    end;

    /// <summary>Returns the native reclassification effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.ReadFrom('{"writes":false,"posts":false,"rollback":true}');
        exit(true);
    end;

    /// <summary>Returns the native reclassification related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Clear(Related);
        Related.ReadFrom('[{"name":"Inventory.Reclassification.Check","useInsteadWhen":"Check the journal."},{"name":"Inventory.Reclassification.Post","useInsteadWhen":"Post the journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native reclassification examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"PreviewPost selected Transfer journal lines","request":{"type":"Inventory.Reclassification.PreviewPost","subject":"RECLASS|OWNED"}}]');
        exit(true);
    end;

    /// <summary>No override is provided.</summary>
    procedure GetMetering(var Value: JsonObject): Boolean
    begin
        Clear(Value);
        exit(false);
    end;

    /// <summary>No override is provided.</summary>
    procedure GetWorkflow(var Value: JsonObject): Boolean
    begin
        Clear(Value);
        exit(false);
    end;

    /// <summary>Describes native reclassification behavior.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Previews selected Transfer journal lines through native posting rollback.');
    end;

    /// <summary>Describes native reclassification behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Previews selected Transfer journal lines through native posting rollback.');
    end;

    /// <summary>Describes native reclassification behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit('Previews selected Transfer journal lines through native posting rollback.');
    end;

    /// <summary>Explains native reclassification constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := 'Previews selected Transfer journal lines through native posting rollback. Existing nonrecurring Transfer template batch required. Optional lineSystemIds selects distinct lines from that batch only. Native line validation, rollback preview and batch posting retain the subset. No transfer order is created. Normal licensed dispatch applies.';
        exit(true);
    end;

    /// <summary>Explains native reclassification constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := 'Previews selected Transfer journal lines through native posting rollback. Existing nonrecurring Transfer template batch required. Optional lineSystemIds selects distinct lines from that batch only. Native line validation, rollback preview and batch posting retain the subset. No transfer order is created. Normal licensed dispatch applies.';
        exit(true);
    end;
}
