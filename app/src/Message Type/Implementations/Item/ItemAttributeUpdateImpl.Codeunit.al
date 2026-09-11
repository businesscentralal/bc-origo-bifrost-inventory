namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of the Item.Attribute.Update message type (Inbound).
/// </summary>
codeunit 10036899 "Item Attribute Update Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Mapping: Record "Item Attribute Value Mapping";
    begin
        exit(Mapping.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Updates an existing item attribute mapping and returns before/after values.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Item Attribute Update Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item Attribute Update Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item Attribute Update Process ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
    end;
}
