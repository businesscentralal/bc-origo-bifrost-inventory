namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Isolated write for Sales.SalesInvoice.GetShipmentLines. Validation has already refused bad requests; an error raised
/// by Business Central here rolls every added invoice line back and is answered as a clean error by the caller.
/// </summary>
codeunit 10077021 "Sales Get Shipment Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        GetShipmentImpl: Codeunit "Sales Get Shipment Impl ori";
    begin
        GetShipmentImpl.RunGetShipmentLines(Rec);
    end;
}
