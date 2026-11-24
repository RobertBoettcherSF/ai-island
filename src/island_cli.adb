with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Island.Text;
with Island.World;
with Island_Save;

--  Native runner. One command, one JSON line (or plain sentences with --text).
--  The world rules are not in this file.
procedure Island_CLI is
   use Ada.Command_Line;
   use Ada.Text_IO;

   As_Text  : Boolean := False;
   Have_Save : Boolean := False;
   Save_Path : String (1 .. 512) := [others => ' '];
   Save_Len  : Natural := 0;
   Cmd       : String (1 .. Island.Command_Max) := [others => ' '];
   Cmd_Len   : Natural := 0;
   Too_Long  : Boolean := False;
   Usage     : Boolean := False;

   procedure Put_Json (Text : String) is
   begin
      Put_Line (Text);
   end Put_Json;

   function Is_New (Command : String) return Boolean is
      First : Natural := Command'First;
      Last  : constant Natural := Command'Last;
      I     : Natural;
   begin
      if Command'Length = 0 then
         return False;
      end if;
      while First <= Last and then Command (First) = ' ' loop
         First := First + 1;
      end loop;
      I := First;
      while I <= Last and then Command (I) /= ' ' loop
         I := I + 1;
      end loop;
      return I - First = 3
        and then (Command (First) = 'n' or else Command (First) = 'N')
        and then (Command (First + 1) = 'e' or else Command (First + 1) = 'E')
        and then (Command (First + 2) = 'w' or else Command (First + 2) = 'W');
   end Is_New;

   procedure Add_Word (Word : String) is
   begin
      if Too_Long or else Usage then
         return;
      end if;
      if Cmd_Len > 0 then
         if Cmd_Len + 1 + Word'Length > Island.Command_Max then
            Too_Long := True;
            return;
         end if;
         Cmd_Len := Cmd_Len + 1;
         Cmd (Cmd_Len) := ' ';
      elsif Word'Length > Island.Command_Max then
         Too_Long := True;
         return;
      end if;
      Cmd (Cmd_Len + 1 .. Cmd_Len + Word'Length) := Word;
      Cmd_Len := Cmd_Len + Word'Length;
   end Add_Word;

   S      : Island.World.State;
   Status : Island_Save.Load_Status;
   Reply  : Island.Reply_Buffer;
   Len    : Natural;
   Ok     : Boolean;
   Stored : Boolean;
begin
   declare
      I : Positive := 1;
   begin
      while I <= Argument_Count loop
         declare
            Arg : constant String := Argument (I);
         begin
            if Cmd_Len > 0 then
               Add_Word (Arg);
            elsif Arg = "--text" then
               As_Text := True;
            elsif Arg = "--save" then
               if I = Argument_Count then
                  Usage := True;
               else
                  I := I + 1;
                  declare
                     Path : constant String := Argument (I);
                  begin
                     if Path'Length = 0 or else Path'Length > Save_Path'Length then
                        Usage := True;
                     else
                        Save_Path (1 .. Path'Length) := Path;
                        Save_Len := Path'Length;
                        Have_Save := True;
                     end if;
                  end;
               end if;
            elsif Arg'Length > 7 and then Arg (Arg'First .. Arg'First + 6) = "--save=" then
               declare
                  Path : constant String := Arg (Arg'First + 7 .. Arg'Last);
               begin
                  if Path'Length = 0 or else Path'Length > Save_Path'Length then
                     Usage := True;
                  else
                     Save_Path (1 .. Path'Length) := Path;
                     Save_Len := Path'Length;
                     Have_Save := True;
                  end if;
               end;
            elsif Arg'Length > 0 and then Arg (Arg'First) = '-' then
               Usage := True;
            else
               Add_Word (Arg);
            end if;
         end;
         I := I + 1;
      end loop;
   end;

   if not Have_Save then
      Save_Path (1 .. 11) := "island.save";
      Save_Len := 11;
   end if;

   if Usage or else Cmd_Len = 0 then
      Put_Json ("{""ok"":false,""reason"":""usage""}");
      Set_Exit_Status (Failure);
      return;
   end if;

   if Too_Long then
      Island.Text.Write_Too_Long (Reply, Len, Ok);
      Put_Line (Reply (1 .. Len));
      Set_Exit_Status (Failure);
      return;
   end if;

   if Is_New (Cmd (1 .. Cmd_Len)) then
      Island.World.Reset (S);
      Island.Text.Execute (S, Cmd (1 .. Cmd_Len), As_Text, Reply, Len, Ok);
      if Ok then
         Island_Save.Store (Save_Path (1 .. Save_Len), S, Stored);
         if not Stored then
            Put_Json ("{""ok"":false,""reason"":""save io""}");
            Set_Exit_Status (Failure);
            return;
         end if;
      end if;
   else
      Island_Save.Load (Save_Path (1 .. Save_Len), S, Status);
      case Status is
         when Island_Save.Missing =>
            Put_Json ("{""ok"":false,""reason"":""no world""}");
            Set_Exit_Status (Failure);
            return;
         when Island_Save.Bad =>
            Put_Json ("{""ok"":false,""reason"":""bad save""}");
            Set_Exit_Status (Failure);
            return;
         when Island_Save.Io_Error =>
            Put_Json ("{""ok"":false,""reason"":""save io""}");
            Set_Exit_Status (Failure);
            return;
         when Island_Save.Loaded =>
            Island.Text.Execute (S, Cmd (1 .. Cmd_Len), As_Text, Reply, Len, Ok);
            Island_Save.Store (Save_Path (1 .. Save_Len), S, Stored);
            if not Stored then
               Put_Json ("{""ok"":false,""reason"":""save io""}");
               Set_Exit_Status (Failure);
               return;
            end if;
      end case;
   end if;

   Put_Line (Reply (1 .. Len));
   if Ok then
      Set_Exit_Status (Success);
   else
      Set_Exit_Status (Failure);
   end if;
exception
   when E : others =>
      Put_Line (Standard_Error, Ada.Exceptions.Exception_Information (E));
      Set_Exit_Status (Failure);
end Island_CLI;
