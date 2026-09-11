namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of the Item.AttributeDefinition.Create message type (Inbound).
/// </summary>
codeunit 10036900 "Item AttributeDefinition Create Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        ItemAttribute: Record "Item Attribute";
    begin
        exit(ItemAttribute.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Attribute");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Creates an item attribute definition and optional option values, independent of any item.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Item AttributeDefinition Create Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item AttributeDefinition Create Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item AttributeDefinition Create Process ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
    end;
}
