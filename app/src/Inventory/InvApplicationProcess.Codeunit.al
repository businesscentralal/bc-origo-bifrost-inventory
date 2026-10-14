namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Runs native application mutations within the caller's commit policy.</summary>
codeunit 70013497 "Inv Application Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        NativeApplication: Codeunit "Inv Application Write ori";
    begin
        case Rec.Type of
            "Message Type ori"::"Inventory.ItemApplication.Unapply":
                NativeApplication.Unapply(Rec);
            "Message Type ori"::"Inventory.ItemApplication.Reapply":
                NativeApplication.Reapply(Rec);
            else
                Rec.TestField(Type, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        end;
    end;
}
