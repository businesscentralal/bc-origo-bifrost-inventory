namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Refuses Data.Records.Set against Inventory Setup. Reads via Data.Records.Get stay allowed.
/// </summary>
codeunit 70013454 "Inventory Setup Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictSetupTable(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Inventory Setup ori" then
            IsRestricted := true;
    end;
}
