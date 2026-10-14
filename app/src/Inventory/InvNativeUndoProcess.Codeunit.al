namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Isolates supported native undo writes under the shipping caller's transaction policy.</summary>
codeunit 70013489 "Inv Native Undo Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        NativeUndo: Codeunit "Inventory Native Undo ori";
    begin
        case Rec.Type of
            "Message Type ori"::"Inventory.Transfer.UndoShipment":
                NativeUndo.UndoShipment(Rec);
            "Message Type ori"::"Inventory.Assembly.UndoPost":
                NativeUndo.UndoAssembly(Rec);
            else
                Rec.TestField(Type, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        end;
    end;
}
