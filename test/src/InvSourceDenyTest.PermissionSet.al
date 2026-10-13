namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>Test-only execution rights without source tabledata grants, used to prove permission refusals.</summary>
permissionset 96929 "Inv Source Deny Test"
{
    Assignable = true;
    Caption = 'Inventory source deny test', MaxLength = 30;

    Permissions =
        tabledata "Message Argument ori" = RIMD,
        table "Sales Line" = X,
        table "Reservation Entry" = X,
        table "Tracking Specification" = X,
        codeunit "Inventory Source Resolve ori" = X,
        codeunit "Inventory Tracking Read ori" = X,
        codeunit "Request Value Reader ori" = X;
}
