namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Refuses Data.Records.Set against Inventory Setup. Reads via Data.Records.Get stay allowed.
/// While Foundation setup mode is active for the running message (#235, Gunnar 17.11.2026), Inventory Setup,
/// the only setup/configuration table this app restricts, is left unrestricted. Every other table this app
/// restricts (items, item cost fields, categories, attributes, variants, stockkeeping units, price lists,
/// reservation and tracking entries, item charge assignments) is business data routed through validated
/// message types and stays restricted in setup mode.
/// Foundation logs each successful Data.Records.Set write made in setup mode (setupMode, tableNo, sessionId, user),
/// so this subscriber, which only decides restriction and can run for probes that write nothing, does not log.
/// </summary>
codeunit 10076923 "Inventory Setup Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictSetupTable(TableNo: Integer; var IsRestricted: Boolean)
    var
        SetupMode: Codeunit "Bifrost Setup Mode ori";
    begin
        if IsTableRestricted(TableNo, SetupMode.IsActive()) then
            IsRestricted := true;
    end;

    /// <summary>
    /// Decides whether this codeunit restricts the table. Inventory Setup is open only while setup mode is active.
    /// </summary>
    /// <param name="TableNo">The table being checked.</param>
    /// <param name="SetupModeActive">True while Foundation setup mode is active for the running message.</param>
    /// <returns>True when this app restricts the table.</returns>
    internal procedure IsTableRestricted(TableNo: Integer; SetupModeActive: Boolean): Boolean
    begin
        exit((TableNo = Database::"Inventory Setup ori") and not SetupModeActive);
    end;
}
