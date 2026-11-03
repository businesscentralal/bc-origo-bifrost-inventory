namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.Posting;

/// <summary>
/// Applies Inventory.AssemblyOrder.PreviewPost postingDate and quantityToAssemble inside the
/// posting-preview transaction. Bind this manual subscriber before Gen. Jnl.-Post Preview runs.
/// The preview rolls the write back, so the stored assembly order is unchanged and no Commit is used.
/// </summary>
codeunit 10076926 "Asm. Preview Adjust ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        PreviewPostingDate: Date;
        PreviewQuantity: Decimal;
        ReplacePostingDate: Boolean;
        ReplaceQuantity: Boolean;

    /// <summary>
    /// Stores the preview adjustments. A zero date or a quantity that is not greater than zero is ignored.
    /// </summary>
    /// <param name="PostingDate">Replacement posting date, or 0D when the request omitted it.</param>
    /// <param name="QuantityToAssemble">Replacement quantity, used only when greater than zero.</param>
    internal procedure SetAdjustments(PostingDate: Date; QuantityToAssemble: Decimal)
    begin
        PreviewPostingDate := PostingDate;
        ReplacePostingDate := PostingDate <> 0D;
        PreviewQuantity := QuantityToAssemble;
        ReplaceQuantity := QuantityToAssemble > 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnBeforeOnRun, '', false, false)]
    local procedure ApplyInsidePreview(var AssemblyHeader: Record "Assembly Header"; SuppressCommit: Boolean)
    begin
        if not ReplacePostingDate and not ReplaceQuantity then
            exit;
        // Assembly-Post runs inside the preview codeunit. This write rolls back with that preview,
        // so the stored order is unchanged and the call must not Commit.
        AssemblyHeader.SetHideValidationDialog(true);
        if ReplaceQuantity then
            AssemblyHeader.Validate("Quantity to Assemble", PreviewQuantity);
        if ReplacePostingDate then
            AssemblyHeader.Validate("Posting Date", PreviewPostingDate);
        AssemblyHeader.Modify(true);
        if SuppressCommit then
            exit;
    end;
}
