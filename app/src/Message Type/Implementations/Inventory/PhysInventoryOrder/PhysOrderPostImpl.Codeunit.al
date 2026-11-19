namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Counting.Document;
using Origo.Bifrost;

/// <summary>Dispatches the native physical inventory order post operation.</summary>
codeunit 10076962 "Phys Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Checks the physical inventory domain and native order write access.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Phys Order Process ori";
    begin
        exit(Gate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Phys. Invt. Order Header", true, false) and Process.HasPermission('Post'));
    end;

    /// <summary>Returns the native order header table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Phys. Invt. Order Header");
    end;

    /// <summary>Uses inbound message dispatch.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request, then runs all native changes atomically.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Phys Order Process ori";
        NextStepLbl: Label 'Correct the physical inventory order, recording or inventory setup in Business Central, then retry the same operation.', Comment = 'is-IS=Leiðréttu birgðatalningarpöntun, skráningu eða birgðauppsetningu í Business Central og reyndu síðan sömu aðgerð aftur.';
    begin
        if not Process.AssertPermission(Argument, 'Post') then
            exit;
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Phys. Invt. Order Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Process.PreparePost(Argument) then
            exit;
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NextStepLbl);
    end;

    /// <summary>Describes the native physical inventory order operation.</summary>
    procedure GetDescription(): Text[250]
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        exit(Contract.Description('Post'));
    end;

    /// <summary>Describes the native physical inventory order operation.</summary>
    procedure GetSelectionDescription(): Text
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        exit(Contract.Description('Post'));
    end;

    /// <summary>Describes the native physical inventory order operation.</summary>
    procedure GetKeywords(): Text
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        exit(Contract.Keywords('Post'));
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Envelope := Contract.Envelope('Post');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Target := Contract.Target('Post');
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Parameters := Contract.Parameters('Post');
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Response := Contract.Response('Post');
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Errors := Contract.Errors('Post');
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Effect := Contract.Effect('Post');
        exit(true);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Related := Contract.Related('Post');
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Examples := Contract.Examples('Post');
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Workflow := Contract.Workflow('Post');
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Overview := Contract.Overview('Post');
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Phys Order Contract ori";
    begin
        Notes := Contract.Notes('Post');
        exit(true);
    end;

    /// <summary>Returns the metering contract chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;
}
