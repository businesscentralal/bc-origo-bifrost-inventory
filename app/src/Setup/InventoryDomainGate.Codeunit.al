namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Shared IsEnabled gate. A type is enabled only when the caller has the required permission
/// and the company domain flag is on. A missing setup row counts as off.
/// </summary>
codeunit 10076922 "Inventory Domain Gate ori"
{
    Access = Internal;

    /// <summary>Reports whether the company switch and required native permissions allow this operation.</summary>
    procedure IsEnabled(Domain: Enum "Inventory Domain ori"; FilterTableNo: Integer; NeedWrite: Boolean; NeedPost: Boolean): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.IsDomainEnabled(Domain) then
            exit(false);
        exit(HasPermission(FilterTableNo, NeedWrite, NeedPost));
    end;

    /// <summary>Returns the permission refusal. The company domain switch only changes IsEnabled (Gunnar 18.11.2026, #36); execution is never refused for a turned-off domain.</summary>
    procedure AssertEnabled(var Argument: Record "Message Argument ori"; Domain: Enum "Inventory Domain ori"; FilterTableNo: Integer; NeedWrite: Boolean; NeedPost: Boolean): Boolean
    var
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
    begin
        if HasPermission(FilterTableNo, NeedWrite, NeedPost) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', '', '');
        exit(false);
    end;

    local procedure HasPermission(FilterTableNo: Integer; NeedWrite: Boolean; NeedPost: Boolean): Boolean
    var
        PostingGate: Codeunit "Inv. Posting Gate ori";
        RecRef: RecordRef;
    begin
        if NeedPost then
            exit(PostingGate.HasPostingPermission());
        RecRef.Open(FilterTableNo);
        if NeedWrite then
            exit(RecRef.WritePermission());
        exit(RecRef.ReadPermission());
    end;
}
