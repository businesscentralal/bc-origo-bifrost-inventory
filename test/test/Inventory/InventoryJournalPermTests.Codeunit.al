namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.History;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Restricted native callers prove physical posting uses Foundation's existing item-post gate.</summary>
codeunit 96964 "Inventory Journal Perm. Tests"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Native journal writes without ItemPost refuse before licensing or reading a batch.</summary>
    [Test]
    procedure Scenario_AC07_NoItemPostToken_Refuses()
    var
        Line: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        PostImpl: Codeunit "Phys. Invt. Post Impl ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
        Token: JsonToken;
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Jnl Write Test');
        Assert.IsTrue(Line.WritePermission(), 'Caller has native journal writes.');
        Assert.IsFalse(PostImpl.IsEnabled(), 'ItemPost token is independently required.');
        PostImpl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('code', Token);
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Posting permission fails before licensing.');
    end;

    /// <summary>Foundation ItemPost plus native writes enable physical posting without the unrelated Inventory token.</summary>
    [Test]
    procedure Scenario_AC07_FoundationItemPost_Enables()
    var
        PostImpl: Codeunit "Phys. Invt. Post Impl ori";
        PreviewImpl: Codeunit "Phys. Inv. Preview Impl ori";
        InvGate: Codeunit "Inv. Posting Gate ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Jnl Write Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsFalse(InvGate.HasPostingPermission(), 'No unrelated Inventory posting token.');
        Assert.IsTrue(PostImpl.IsEnabled(), 'Native public Foundation gate admits the caller.');
        Assert.IsTrue(PreviewImpl.IsEnabled(), 'Preview has the same native posting permission.');
    end;

    /// <summary>PhysInventory.Check: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCheck_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Check");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Check: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCheck_NativeRead_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Check");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>PhysInventory.Check: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCheck_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Check");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>PhysInventory.PreviewPost: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPreview_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.PreviewPost: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPreview_NativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.PreviewPost: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPreview_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>PhysInventory.PreviewPost: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPreview_NoPostToken_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Post: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPost_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Post: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPost_NativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Post: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPost_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST ItemPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>PhysInventory.Post: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysPost_NoPostToken_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('ItemPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Calculate: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCalculate_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Calculate");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Calculate: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCalculate_NativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Calculate");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.Calculate: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCalculate_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.Calculate");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>PhysInventory.RecordCount: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCount_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.RecordCount");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.RecordCount: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCount_NativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.RecordCount");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>PhysInventory.RecordCount: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure PhysCount_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.PhysInventory.RecordCount");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Reclassification.Check: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassCheck_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Check");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Reclassification.Check: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassCheck_NativeRead_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Check");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Reclassification.Check: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassCheck_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Check");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Reclassification.PreviewPost: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPreview_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Reclassification.PreviewPost: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPreview_NativeRead_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Reclassification.PreviewPost: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPreview_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Reclassification.PreviewPost: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPreview_NoPostToken_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.PreviewPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Reclassification.Post: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPost_NoNativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Reclassification.Post: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPost_NativeRead_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Reclassification.Post: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPost_NativeWrite_Enabled()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Reclassification.Post: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReclassPost_NoPostToken_Refuses()
    var
        Native: Record "Item Journal Line";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Reclassification.Post");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Transfer.UndoShipment: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ShipmentUndo_NoNativeRead_Refuses()
    var
        Native: Record "Transfer Shipment Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Transfer.UndoShipment: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ShipmentUndo_NativeRead_Refuses()
    var
        Native: Record "Transfer Shipment Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Transfer.UndoShipment: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ShipmentUndo_NativeWrite_Enabled()
    var
        Native: Record "Transfer Shipment Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Transfer.UndoShipment: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ShipmentUndo_NoPostToken_Refuses()
    var
        Native: Record "Transfer Shipment Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoShipment");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Transfer.UndoReceipt: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReceiptUndo_NoNativeRead_Refuses()
    var
        Native: Record "Transfer Receipt Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoReceipt");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Transfer.UndoReceipt: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReceiptUndo_NativeRead_Enabled()
    var
        Native: Record "Transfer Receipt Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoReceipt");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Transfer.UndoReceipt: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReceiptUndo_NativeWrite_Enabled()
    var
        Native: Record "Transfer Receipt Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoReceipt");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Transfer.UndoReceipt: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ReceiptUndo_NoPostToken_Refuses()
    var
        Native: Record "Transfer Receipt Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Transfer.UndoReceipt");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Assembly.UndoPost: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure AssemblyUndo_NoNativeRead_Refuses()
    var
        Native: Record "Posted Assembly Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Assembly.UndoPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Assembly.UndoPost: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure AssemblyUndo_NativeRead_Refuses()
    var
        Native: Record "Posted Assembly Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Assembly.UndoPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>Assembly.UndoPost: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure AssemblyUndo_NativeWrite_Enabled()
    var
        Native: Record "Posted Assembly Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Assembly.UndoPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', true);
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>Assembly.UndoPost: NoPostToken checks actual permissions separately from licensing.</summary>
    [Test]
    procedure AssemblyUndo_NoPostToken_Refuses()
    var
        Native: Record "Posted Assembly Header";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.Assembly.UndoPost");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertPostingGate('InvPost', false);
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>ItemApplication.Get: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationGet_NoNativeRead_Refuses()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Get");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>ItemApplication.Get: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationGet_NativeRead_Enabled()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Get");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>ItemApplication.Get: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationGet_NativeWrite_Enabled()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Get");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>ItemApplication.Unapply: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationUnapply_NoNativeRead_Refuses()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>ItemApplication.Unapply: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationUnapply_NativeRead_Refuses()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>ItemApplication.Unapply: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationUnapply_NativeWrite_Enabled()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    /// <summary>ItemApplication.Reapply: NoNativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationReapply_NoNativeRead_Refuses()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Cost Read Test');
        Assert.IsFalse(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>ItemApplication.Reapply: NativeRead checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationReapply_NativeRead_Refuses()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Read Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsFalse(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, false);
    end;

    /// <summary>ItemApplication.Reapply: NativeWrite checks actual permissions separately from licensing.</summary>
    [Test]
    procedure ApplicationReapply_NativeWrite_Enabled()
    var
        Native: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        InitArgument(TempArgument, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Native.ReadPermission(), 'Verify actual native read grant.');
        Assert.IsTrue(Native.WritePermission(), 'Verify actual native write grant.');
        AssertDispatch(TempArgument, true);
    end;

    local procedure InitArgument(var Argument: Record "Message Argument ori"; MessageType: Enum "Message Type ori")
    begin
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Type := MessageType;
        Argument.Insert(true);
    end;

    local procedure AssertPostingGate(TokenName: Text; Expected: Boolean)
    var
        NativeJournal: Codeunit "Inventory Native Journal ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        if TokenName = 'ItemPost' then
            Assert.AreEqual(Expected, NativeJournal.HasItemPostingPermission(), 'The public Foundation gate requires its token and native journal writes.')
        else
            Assert.AreEqual(Expected, PostingGate.HasPostingPermission(), 'Check the independent Inventory token.');
    end;

    local procedure AssertDispatch(var Argument: Record "Message Argument ori"; ExpectedEnabled: Boolean)
    var
        Implementation: Interface "Msg Interface ori";
        Response: JsonObject;
        Token: JsonToken;
    begin
        Implementation := Argument.Type;
        Assert.AreEqual(ExpectedEnabled, Implementation.IsEnabled(), 'Discovery must reflect actual native permissions and the required posting token.');
        if ExpectedEnabled then
            exit; // Discovery grant does not prove licensed execution. Never bypass the license boundary.
        Implementation.ExecuteBifrostTask(Argument);
        Response := Argument.GetResponseJson();
        Assert.IsTrue(Response.Get('code', Token), 'Execution must return a structured refusal before licensing, record selection or native writes.');
        Assert.AreEqual('PermissionDenied', Token.AsValue().AsText(), 'Native permission denial is not a licensing or missing-record error.');
        Assert.IsTrue(Response.Get('status', Token), 'The refusal has an error status.');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Permission denial cannot report success.');
    end;

    /// <summary>Denied PhysInventory.Post preserves both selected and outside-selection native rows.</summary>
    [Test]
    procedure PhysicalPost_Denied_PreservesOwnedRows()
    begin
        AssertDeniedJournalPreservesRows("Message Type ori"::"Inventory.PhysInventory.Post", "Item Journal Template Type"::"Phys. Inventory");
    end;

    /// <summary>Denied PhysInventory.PreviewPost preserves both selected and outside-selection native rows.</summary>
    [Test]
    procedure PhysicalPreview_Denied_PreservesOwnedRows()
    begin
        AssertDeniedJournalPreservesRows("Message Type ori"::"Inventory.PhysInventory.PreviewPost", "Item Journal Template Type"::"Phys. Inventory");
    end;

    /// <summary>Denied Reclassification.Post preserves both selected and outside-selection native rows.</summary>
    [Test]
    procedure ReclassificationPost_Denied_PreservesOwnedRows()
    begin
        AssertDeniedJournalPreservesRows("Message Type ori"::"Inventory.Reclassification.Post", "Item Journal Template Type"::"Transfer");
    end;

    /// <summary>Denied Reclassification.PreviewPost preserves both selected and outside-selection native rows.</summary>
    [Test]
    procedure ReclassificationPreview_Denied_PreservesOwnedRows()
    begin
        AssertDeniedJournalPreservesRows("Message Type ori"::"Inventory.Reclassification.PreviewPost", "Item Journal Template Type"::"Transfer");
    end;

    local procedure AssertDeniedJournalPreservesRows(MessageType: Enum "Message Type ori"; TemplateType: Enum "Item Journal Template Type")
    var
        Item: Record Item;
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Selected: Record "Item Journal Line";
        Outside: Record "Item Journal Line";
        Reloaded: Record "Item Journal Line";
        Entries: Record "Item Ledger Entry";
        Values: Record "Value Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LibraryInventory: Codeunit "Library - Inventory";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Request: JsonObject;
        Selection: JsonArray;
        EntryCount: Integer;
        ValueCount: Integer;
    begin
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, TemplateType);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Selected, JournalTemplate.Name, Batch.Name, Selected."Entry Type"::"Positive Adjmt.", Item."No.", 1);
        LibraryInventory.CreateItemJournalLine(Outside, JournalTemplate.Name, Batch.Name, Outside."Entry Type"::"Positive Adjmt.", Item."No.", 2);
        Selected.GetBySystemId(Selected.SystemId);
        Outside.GetBySystemId(Outside.SystemId);
        EntryCount := Entries.Count();
        ValueCount := Values.Count();
        InitArgument(TempArgument, MessageType);
        TempArgument.Subject := JournalTemplate.Name + '|' + Batch.Name;
        Selection.Add(Selected.SystemId);
        Request.Add('lineSystemIds', Selection);
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Full ori');
        LowerPermissions.AddPermissionSet('Inv Native Wrt Test');
        Assert.IsTrue(Selected.WritePermission(), 'Native writes are present; only posting authorization is missing.');
        AssertPostingGate('ItemPost', false);
        AssertPostingGate('InvPost', false);
        AssertDispatch(TempArgument, false);
        Assert.IsTrue(Reloaded.GetBySystemId(Selected.SystemId), 'Denied dispatch preserves the selected line.');
        Assert.AreEqual(Selected.Quantity, Reloaded.Quantity, 'Selected quantity unchanged.');
        Assert.AreEqual(Selected.SystemModifiedAt, Reloaded.SystemModifiedAt, 'Denied dispatch must not modify selected data.');
        Assert.IsTrue(Reloaded.GetBySystemId(Outside.SystemId), 'Denied dispatch preserves the outside-selection line.');
        Assert.AreEqual(Outside.Quantity, Reloaded.Quantity, 'Outside-selection quantity unchanged.');
        Assert.AreEqual(Outside.SystemModifiedAt, Reloaded.SystemModifiedAt, 'Outside-selection data remains untouched.');
        LowerPermissions.SetO365Full();
        Assert.AreEqual(EntryCount, Entries.Count(), 'Denied dispatch must not post item entries.');
        Assert.AreEqual(ValueCount, Values.Count(), 'Denied dispatch must not post value entries.');
    end;
}
