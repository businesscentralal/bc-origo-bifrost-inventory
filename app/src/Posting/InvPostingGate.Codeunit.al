namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Posting gate for Bifrost Inventory.
/// Transfer Order Post and Assembly Order Post both require write permission on Inv. Posting ori.
/// </summary>
codeunit 70013443 "Inv. Posting Gate ori"
{
    Access = Internal;

    /// <summary>
    /// Returns false and writes the denial on Argument when the caller cannot post.
    /// Returns true and leaves Argument unchanged when the caller holds BIFROST InvPost ori.
    /// </summary>
    procedure AssertCanPost(var Argument: Record "Message Argument ori"): Boolean
    var
        PostingDeniedErr: Label 'Posting denied: missing ''%1'' permission set.', Comment = '%1 = permission set name, is-IS=Bókun hafnað: vantar ''%1'' heimildasett.';
        PermissionSetNameTok: Label 'BIFROST InvPost ori', Locked = true;
    begin
        if HasPostingPermission() then
            exit(true);

        Argument.RespondWithError(
            "Bifrost Error Code ori"::PermissionDenied,
            StrSubstNo(PostingDeniedErr, PermissionSetNameTok),
            '', '', '', '');
        exit(false);
    end;

    /// <summary>
    /// True when the current user has write permission on the inventory posting token.
    /// </summary>
    procedure HasPostingPermission(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(Database::"Inv. Posting ori");
        exit(RecRef.WritePermission());
    end;
}
