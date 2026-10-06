namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Shared IsEnabled gate. A type is enabled only when the caller has the required permission
/// and the company domain flag is on. A missing setup row counts as on.
/// </summary>
codeunit 70013453 "Inventory Domain Gate ori"
{
    Access = Internal;

    procedure IsEnabled(Domain: Enum "Inventory Domain ori"; FilterTableNo: Integer; NeedWrite: Boolean; NeedPost: Boolean): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        RecRef: RecordRef;
    begin
        if not InventorySetup.IsDomainEnabled(Domain) then
            exit(false);
        if NeedPost then
            exit(PostingGate.HasPostingPermission());
        RecRef.Open(FilterTableNo);
        if NeedWrite then
            exit(RecRef.WritePermission());
        exit(RecRef.ReadPermission());
    end;

    procedure AssertEnabled(var Argument: Record "Message Argument ori"; Domain: Enum "Inventory Domain ori"; FilterTableNo: Integer; NeedWrite: Boolean; NeedPost: Boolean): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainDisabledErr: Label 'The %1 domain is turned off for this company. Turn it on from Inventory Setup.', Comment = '%1 = domain, is-IS=%1 sviðið er slökkt fyrir þetta fyrirtæki. Kveiktu á því í uppsetningu birgða.';
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
    begin
        if not InventorySetup.IsDomainEnabled(Domain) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(DomainDisabledErr, Format(Domain)), '', '', '', 'Turn the domain on from the Inventory Setup page.');
            exit(false);
        end;
        if IsEnabled(Domain, FilterTableNo, NeedWrite, NeedPost) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', '', '');
        exit(false);
    end;
}
