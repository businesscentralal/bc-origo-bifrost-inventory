namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Previews native physical-inventory posting with rollback and captured ledger entries.</summary>
codeunit 70013472 "Phys. Inv. Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Requires company Reclassification, native journal writes and a posting token.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false) and NativeJournal.HasItemPostingPermission());
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
        NativeJournal: Codeunit "Inventory Native Journal ori";
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false) then
            exit;
        if not NativeJournal.AssertItemPostingPermission(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Journal.Preview(Argument, "Item Journal Template Type"::"Phys. Inventory");
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
        Target.ReadFrom('[{"table":"Item Journal Batch","selection":"An explicitly identified Phys. Inventory template batch."}]');
        exit(true);
    end;

    /// <summary>Returns the native reclassification parameters contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, ''));
        Parameters.Add(ContractMgt.Parameter('lineSystemIds', 'array', false, ''));
        exit(true);
    end;

    /// <summary>Returns the native reclassification response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success for a completed native operation.'));
        Fields.Add(ContractMgt.ResponseField('linesToPost', 'integer', 'Number of selected lines included in the rollback preview.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'True: native preview entries have been rolled back.'));
        Fields.Add(ContractMgt.ResponseField('preview', 'array', 'Captured native preview entries grouped by table.'));
        Fields.Add(ContractMgt.ResponseField('result', 'array', 'Selected line results; RecordCount includes before/after counts and counted state.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The resolved native journal template.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The resolved native journal batch.'));
        Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Native preview G/L totals.'));
        Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total native preview entry count.'));
        Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Native preview G/L entry count.'));
        Response.Add('fields', Fields);
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
        Related.ReadFrom('[{"name":"Inventory.PhysInventory.Calculate","useInsteadWhen":"Calculate the physical inventory journal."},{"name":"Inventory.PhysInventory.RecordCount","useInsteadWhen":"RecordCount the physical inventory journal."},{"name":"Inventory.PhysInventory.Check","useInsteadWhen":"Check the physical inventory journal."},{"name":"Inventory.PhysInventory.Post","useInsteadWhen":"Post the physical inventory journal."}]');
        exit(true);
    end;

    /// <summary>Returns the native reclassification examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Previews native physical-inventory posting with rollback and captured ledger entries.","request":{"type":"Inventory.PhysInventory.PreviewPost","subject":"PHYS|OWNED"}}]');
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
        exit('Previews native physical-inventory posting with rollback and captured ledger entries.');
    end;

    /// <summary>Describes native reclassification behavior.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Previews native physical-inventory posting with rollback and captured ledger entries.');
    end;

    /// <summary>Describes native reclassification behavior.</summary>
    procedure GetKeywords(): Text
    begin
        exit('Previews native physical-inventory posting with rollback and captured ledger entries.');
    end;

    /// <summary>Explains native reclassification constraints.</summary>
    procedure GetOverview(var Value: Text): Boolean
    begin
        Value := 'Previews native physical-inventory posting with rollback and captured ledger entries. Existing nonrecurring Phys. Inventory template batch required. Calculate requires an empty batch, postingDate and documentNo. RecordCount accepts counts with lineNo or systemId and optional qtyCounted; every supplied count is atomic. Check/Post/PreviewPost support lineSystemIds. Native uncounted quantities are not given invented state fields. Normal licensed dispatch applies.';
        exit(true);
    end;

    /// <summary>Explains native reclassification constraints.</summary>
    procedure GetNotes(var Value: Text): Boolean
    begin
        Value := 'Previews native physical-inventory posting with rollback and captured ledger entries. Existing nonrecurring Phys. Inventory template batch required. Calculate requires an empty batch, postingDate and documentNo. RecordCount accepts counts with lineNo or systemId and optional qtyCounted; every supplied count is atomic. Check/Post/PreviewPost support lineSystemIds. Native uncounted quantities are not given invented state fields. Normal licensed dispatch applies.';
        exit(true);
    end;
}
