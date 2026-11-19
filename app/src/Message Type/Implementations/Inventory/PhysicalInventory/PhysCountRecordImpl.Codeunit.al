namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Gives RecordCount its own description while retaining the shared physical count execution.</summary>
codeunit 10076950 "Phys. Count Record Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        RecordImpl: Codeunit "Phys. Invt. Record Impl ori";

    /// <summary>Uses the shared physical inventory domain and permission gates.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(RecordImpl.IsEnabled());
    end;

    /// <summary>Uses the shared journal batch selection table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(RecordImpl.GetFilterTableNo());
    end;

    /// <summary>Distinguishes the counts-only operation from the legacy single-line form.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Records physical inventory counts using the counts array; omitted qtyCounted leaves a line unchanged, zero records a zero count, and nothing is posted.', Comment = 'is-IS=Skráir birgðatalningu með counts-fylkinu; ef qtyCounted er sleppt helst línan óbreytt, núll skráir núlltalningu og ekkert er bókað.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Uses the shared inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(RecordImpl.GetMessageDirection());
    end;

    /// <summary>Delegates execution unchanged to the existing physical count implementation.</summary>
    /// <param name="Argument">The original request and response argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        RecordImpl.ExecuteBifrostTask(Argument);
    end;
}
