with Island.Map;
with Island.Stomach;

package body Island.Text is
   use type World.Eat_Result;
   use type World.Food;
   use type World.Say_Result;

   type Builder is record
      Data : String (1 .. Reply_Max) := [others => ' '];
      Len  : Natural := 0;
   end record;

   procedure Add (B : in out Builder; Text : String) is
      N : constant Natural := Text'Length;
   begin
      if N = 0 then
         return;
      end if;
      pragma Assert (B.Len <= Reply_Max);
      pragma Assert (N <= Reply_Max - B.Len);
      B.Data (B.Len + 1 .. B.Len + N) := Text;
      B.Len := B.Len + N;
   end Add;

   procedure Add_Char (B : in out Builder; C : Character) is
      One : String (1 .. 1);
   begin
      One (1) := C;
      Add (B, One);
   end Add_Char;

   procedure Add_Nat (B : in out Builder; N : Natural) is
      Digs : String (1 .. 10) := [others => '0'];
      V    : Natural := N;
      L    : Natural := 0;
   begin
      if V = 0 then
         Add (B, "0");
         return;
      end if;
      while V > 0 loop
         L := L + 1;
         pragma Assert (L <= Digs'Last);
         Digs (L) := Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      for I in reverse 1 .. L loop
         Add_Char (B, Digs (I));
      end loop;
   end Add_Nat;

   function Lower (C : Character) return Character is
   begin
      if C in 'A' .. 'Z' then
         return Character'Val
           (Character'Pos (C) - Character'Pos ('A') + Character'Pos ('a'));
      end if;
      return C;
   end Lower;

   function Same (Word : String; Literal : String) return Boolean is
      J : Integer;
   begin
      if Word'Length /= Literal'Length then
         return False;
      end if;
      for I in Word'Range loop
         J := Literal'First + (I - Word'First);
         if Lower (Word (I)) /= Literal (J) then
            return False;
         end if;
      end loop;
      return True;
   end Same;

   procedure Add_Kind (B : in out Builder; Kind : Object_Kind) is
   begin
      case Kind is
         when Stone =>
            Add (B, "stone");
         when Stick =>
            Add (B, "stick");
         when Shell =>
            Add (B, "shell");
      end case;
   end Add_Kind;

   procedure Add_Ground (B : in out Builder; Ground : Terrain) is
   begin
      case Ground is
         when Water =>
            Add (B, "water");
         when Sand =>
            Add (B, "sand");
         when Grass =>
            Add (B, "grass");
         when Rock =>
            Add (B, "rock");
         when Tree =>
            Add (B, "tree");
      end case;
   end Add_Ground;

   procedure Add_Dir_Word (B : in out Builder; Dir : Direction) is
   begin
      case Dir is
         when North =>
            Add (B, "north");
         when East =>
            Add (B, "east");
         when South =>
            Add (B, "south");
         when West =>
            Add (B, "west");
      end case;
   end Add_Dir_Word;

   procedure Add_Dir_Letter (B : in out Builder; Dir : Direction) is
   begin
      case Dir is
         when North =>
            Add_Char (B, 'N');
         when East =>
            Add_Char (B, 'E');
         when South =>
            Add_Char (B, 'S');
         when West =>
            Add_Char (B, 'W');
      end case;
   end Add_Dir_Letter;

   procedure Add_Json_String (B : in out Builder; Text : String) is
   begin
      Add_Char (B, '"');
      for I in Text'Range loop
         if Text (I) = '"' or else Text (I) = '\' then
            Add_Char (B, '\');
         end if;
         Add_Char (B, Text (I));
      end loop;
      Add_Char (B, '"');
   end Add_Json_String;

   procedure Add_Hand_Json (B : in out Builder; S : World.State) is
   begin
      if S.Hand = 0 then
         Add (B, "null");
      else
         Add_Char (B, '"');
         Add_Kind (B, S.Objects (S.Hand).Kind);
         Add_Char (B, '"');
      end if;
   end Add_Hand_Json;

   procedure Add_You (B : in out Builder; S : World.State) is
   begin
      Add (B, "You are at ");
      Add_Nat (B, Natural (S.X));
      Add (B, ",");
      Add_Nat (B, Natural (S.Y));
      Add (B, ", facing ");
      Add_Dir_Word (B, S.Facing);
      Add (B, ", on ");
      Add_Ground (B, Map.Terrain_At (S.Island_Seed, S.X, S.Y));
      Add (B, ". ");
      if S.Hand = 0 then
         Add (B, "Your hand is empty.");
      else
         Add (B, "Your hand holds a ");
         Add_Kind (B, S.Objects (S.Hand).Kind);
         Add (B, ".");
      end if;
   end Add_You;

   function Object_Here
     (S : World.State; X, Y : Coord) return Hand_Index
   is
   begin
      for I in S.Objects'Range loop
         if S.Objects (I).On_Ground
           and then S.Objects (I).X = X
           and then S.Objects (I).Y = Y
         then
            return I;
         end if;
      end loop;
      return 0;
   end Object_Here;

   procedure Add_Seen_Text (B : in out Builder; S : World.State) is
      Any  : Boolean := False;
      Id   : Hand_Index;
      Spot : Terrain;
      Xc   : Coord;
      Yc   : Coord;
   begin
      for Y in S.Y - S.Folk (World.Player_Id).Sight
        .. S.Y + S.Folk (World.Player_Id).Sight
      loop
         for X in S.X - S.Folk (World.Player_Id).Sight
           .. S.X + S.Folk (World.Player_Id).Sight
         loop
            if X in Coord and then Y in Coord then
               Xc := Coord (X);
               Yc := Coord (Y);
               Id := Object_Here (S, Xc, Yc);
               Spot := Map.Terrain_At (S.Island_Seed, Xc, Yc);
               declare
                  Here : constant World.Food := World.Food_At (S, Xc, Yc);
               begin
               if Id /= 0 or else Here /= World.None
                 or else (Spot /= Sand and then Spot /= Grass)
               then
                  if not Any then
                     Add (B, " You see:");
                  else
                     Add (B, ";");
                  end if;
                  Any := True;
                  Add (B, " ");
                  if Here = World.Berries then
                     Add (B, "berries");
                  elsif Here = World.Fish then
                     Add (B, "fish");
                  elsif Here = World.Bare then
                     Add (B, "a bare bush");
                  elsif Id /= 0 then
                     Add (B, "a ");
                     Add_Kind (B, S.Objects (Id).Kind);
                  else
                     Add_Ground (B, Spot);
                  end if;
                  Add (B, " at ");
                  Add_Nat (B, Natural (Xc));
                  Add (B, ",");
                  Add_Nat (B, Natural (Yc));
               end if;
               end;
            end if;
         end loop;
      end loop;
      if not Any then
         Add (B, " You see nothing but sand and grass.");
      else
         Add (B, ".");
      end if;
   end Add_Seen_Text;

   procedure Add_Place_Json (B : in out Builder; S : World.State) is
   begin
      Add (B, """x"":");
      Add_Nat (B, Natural (S.X));
      Add (B, ",""y"":");
      Add_Nat (B, Natural (S.Y));
      Add (B, ",""facing"":""");
      Add_Dir_Letter (B, S.Facing);
      Add (B, """,""ground"":""");
      Add_Ground (B, Map.Terrain_At (S.Island_Seed, S.X, S.Y));
      Add (B, """,""hand"":");
      Add_Hand_Json (B, S);
   end Add_Place_Json;

   procedure Add_Seen_Json (B : in out Builder; S : World.State) is
      First : Boolean := True;
      Id    : Hand_Index;
      Xc    : Coord;
      Yc    : Coord;
   begin
      Add (B, ",""seen"":[");
      for Y in S.Y - S.Folk (World.Player_Id).Sight
        .. S.Y + S.Folk (World.Player_Id).Sight
      loop
         for X in S.X - S.Folk (World.Player_Id).Sight
           .. S.X + S.Folk (World.Player_Id).Sight
         loop
            if X in Coord and then Y in Coord then
               if not First then
                  Add_Char (B, ',');
               end if;
               First := False;
               Xc := Coord (X);
               Yc := Coord (Y);
               Id := Object_Here (S, Xc, Yc);
               Add (B, "{""x"":");
               Add_Nat (B, Natural (Xc));
               Add (B, ",""y"":");
               Add_Nat (B, Natural (Yc));
               Add (B, ",""ground"":""");
               Add_Ground (B, Map.Terrain_At (S.Island_Seed, Xc, Yc));
               Add (B, """,""object"":");
               if Id = 0 then
                  Add (B, "null");
               else
                  Add_Char (B, '"');
                  Add_Kind (B, S.Objects (Id).Kind);
                  Add_Char (B, '"');
               end if;
               Add (B, ",""food"":");
               case World.Food_At (S, Xc, Yc) is
                  when World.None =>
                     Add (B, "null");
                  when World.Berries =>
                     Add (B, """berries""");
                  when World.Bare =>
                     Add (B, """bare""");
                  when World.Fish =>
                     Add (B, """fish""");
               end case;
               Add_Char (B, '}');
            end if;
         end loop;
      end loop;
      Add_Char (B, ']');
   end Add_Seen_Json;

   procedure Add_Creatures (B : in out Builder; S : World.State) is
      First : Boolean := True;
      Sight : constant Integer := Integer (S.Folk (World.Player_Id).Sight);
   begin
      Add (B, ",""creatures"":[");
      for I in World.Folk_Id loop
         if I /= World.Player_Id and then S.Folk (I).Alive
           and then abs (Integer (S.Folk (I).X) - Integer (S.X)) <= Sight
           and then abs (Integer (S.Folk (I).Y) - Integer (S.Y)) <= Sight
         then
            if not First then
               Add_Char (B, ',');
            end if;
            First := False;
            Add (B, "{""id"":");
            Add_Nat (B, I);
            Add (B, ",""x"":");
            Add_Nat (B, Natural (S.Folk (I).X));
            Add (B, ",""y"":");
            Add_Nat (B, Natural (S.Folk (I).Y));
            Add (B, ",""age"":");
            Add_Nat (B, S.Folk (I).Age);
            Add (B, ",""speed"":");
            Add_Nat (B, Natural (S.Folk (I).Speed));
            Add (B, ",""sight"":");
            Add_Nat (B, Natural (S.Folk (I).Sight));
            Add (B, ",""metabolism"":");
            Add_Nat (B, Natural (S.Folk (I).Metabolism));
            Add (B, ",""fertility"":");
            Add_Nat (B, Natural (S.Folk (I).Fertility));
            Add (B, ",""fullness"":");
            Add_Nat (B, Natural (S.Folk (I).Belly.Full));
            Add_Char (B, '}');
         end if;
      end loop;
      Add_Char (B, ']');
   end Add_Creatures;

   procedure Add_Said_Json (B : in out Builder; S : World.State) is
   begin
      Add (B, ",""said"":");
      if S.Said_Len = 0 then
         Add_Json_String (B, "");
      else
         Add_Json_String (B, S.Said (1 .. S.Said_Len));
      end if;
   end Add_Said_Json;

   function Parse_Dir (Word : String; Dir : out Direction) return Boolean is
   begin
      if Same (Word, "n") or else Same (Word, "north") then
         Dir := North;
         return True;
      elsif Same (Word, "e") or else Same (Word, "east") then
         Dir := East;
         return True;
      elsif Same (Word, "s") or else Same (Word, "south") then
         Dir := South;
         return True;
      elsif Same (Word, "w") or else Same (Word, "west") then
         Dir := West;
         return True;
      end if;
      Dir := North;
      return False;
   end Parse_Dir;

   procedure Write_Too_Long
     (Reply : out Reply_Buffer; Len : out Natural; Ok : out Boolean)
   is
      Phrase : constant String := "{""ok"":false,""reason"":""too long""}";
   begin
      Reply := [others => ' '];
      Reply (1 .. Phrase'Length) := Phrase;
      Len := Phrase'Length;
      Ok := False;
   end Write_Too_Long;

   procedure Execute
     (S        : in out World.State;
      Command  : String;
      As_Text  : Boolean;
      Reply    : out Reply_Buffer;
      Len      : out Natural;
      Ok       : out Boolean)
   is
      B       : Builder;
      First   : Natural;
      Last    : Natural;
      Empty   : Boolean;
      V1, V2  : Natural;
      R1, R2  : Natural;
      Has     : Boolean;
      I       : Natural;
      Dir     : Direction;
      Move_R  : World.Move_Result;
      By      : Terrain;
      Take_R  : World.Take_Result;
      Drop_R  : World.Drop_Result;
      Say_R   : World.Say_Result;
      Eat_R   : World.Eat_Result;
      Held    : Object_Kind;
      Carry_Now : Boolean := False;
      Weak_Now  : Boolean := False;

      procedure Add_Hunger_Word is
      begin
         case Stomach.Status (S.Belly) is
            when Stomach.Ok =>
               Add (B, "ok");
            when Stomach.Hungry =>
               Add (B, "hungry");
            when Stomach.Weak =>
               Add (B, "weak");
            when Stomach.Collapsed =>
               Add (B, "collapsed");
         end case;
      end Add_Hunger_Word;

      procedure Close_Cmd is
      begin
         Add (B, ",""turn"":");
         Add_Nat (B, S.Turn);
         Add (B, ",""fullness"":");
         Add_Nat (B, Natural (S.Belly.Full));
         Add (B, ",""hunger"":""");
         Add_Hunger_Word;
         Add (B, """}");
      end Close_Cmd;

      procedure Note is
      begin
         Carry_Now := S.Hand /= 0;
         Weak_Now := Stomach.Is_Weak (S.Belly);
      end Note;

      procedure Spend (Is_Move : Boolean) is
      begin
         World.Advance (S, Is_Move, Weak_Now, Carry_Now);
      end Spend;

      procedure Emit (Success : Boolean) is
      begin
         if As_Text then
            Add (B, " Fullness ");
            Add_Nat (B, Natural (S.Belly.Full));
            Add (B, ", ");
            Add_Hunger_Word;
            Add (B, ", turn ");
            Add_Nat (B, S.Turn);
            Add (B, ".");
         end if;
         Reply := [others => ' '];
         pragma Assert (B.Len > 0 and then B.Len <= Reply_Max);
         Reply (1 .. B.Len) := B.Data (1 .. B.Len);
         Len := B.Len;
         Ok := Success;
      end Emit;

      procedure Fail_Unknown (Word : String) is
         N : Integer := Word'Length;
         C : Character;
      begin
         if As_Text then
            Add (B, "Unknown command.");
         else
            if N > 24 then
               N := 24;
            end if;
            Add (B, "{""ok"":false,""cmd"":""");
            for K in 0 .. N - 1 loop
               C := Lower (Word (Word'First + K));
               if C = '"' or else C = '\' then
                  Add_Char (B, '\');
               end if;
               Add_Char (B, C);
            end loop;
            Add (B, """,""reason"":""unknown command""");
            Close_Cmd;
         end if;
         Emit (False);
      end Fail_Unknown;

      procedure Fail_Bad (Name : String) is
      begin
         if As_Text then
            Add (B, "Unknown command.");
         else
            Add (B, "{""ok"":false,""cmd"":""");
            Add (B, Name);
            Add (B, """,""reason"":""bad command""");
            Close_Cmd;
         end if;
         Emit (False);
      end Fail_Bad;

   begin
      Reply := [others => ' '];
      Len := 0;
      Ok := False;
      First := Command'First;
      Last := Command'Last;
      if Command'Length = 0 then
         Empty := True;
      else
         while First <= Last and then Command (First) = ' ' loop
            First := First + 1;
         end loop;
         while Last >= First and then Command (Last) = ' ' loop
            Last := Last - 1;
         end loop;
         Empty := First > Last;
      end if;
      if Empty then
         Fail_Unknown ("");
         return;
      end if;

      V1 := First;
      I := First;
      while I <= Last and then Command (I) /= ' ' loop
         I := I + 1;
      end loop;
      V2 := I - 1;
      while I <= Last and then Command (I) = ' ' loop
         I := I + 1;
      end loop;
      Has := I <= Last;
      R1 := I;
      R2 := Last;

      if not Same (Command (V1 .. V2), "new") and then World.Collapsed (S) then
         if As_Text then
            Add (B, "You have collapsed.");
         else
            Add (B, "{""ok"":false,""reason"":""collapsed"",""cmd"":""");
            declare
               N : Integer := V2 - V1 + 1;
               C : Character;
            begin
               if N > 24 then
                  N := 24;
               end if;
               for K in 0 .. N - 1 loop
                  C := Lower (Command (V1 + K));
                  Add_Char (B, C);
               end loop;
            end;
            Add (B, """");
            Close_Cmd;
         end if;
         Emit (False);
         return;
      end if;

      if Same (Command (V1 .. V2), "new") then
         if Has then
            Fail_Bad ("new");
            return;
         end if;
         declare
            Island_Seed : constant Map.Seed_Value := S.Island_Seed;
            Pop_Seed    : constant Map.Seed_Value := S.Pop_Seed;
         begin
            World.Reset (S, Island_Seed, Pop_Seed);
         end;
         if As_Text then
            Add (B, "A new island. ");
            Add_You (B, S);
         else
            Add (B, "{""ok"":true,""cmd"":""new"",");
            Add_Place_Json (B, S);
            Close_Cmd;
         end if;
         Emit (True);
      elsif Same (Command (V1 .. V2), "world") then
         if Has then
            Fail_Bad ("world");
            return;
         end if;
         if As_Text then
            Add (B, "Island seed ");
            Add_Nat (B, S.Island_Seed);
            Add (B, ", population seed ");
            Add_Nat (B, S.Pop_Seed);
            Add (B, ". Population ");
            Add_Nat (B, World.Alive_Count (S));
            Add (B, ", births ");
            Add_Nat (B, S.Births);
            Add (B, ", deaths ");
            Add_Nat (B, S.Deaths);
            Add (B, ".");
         else
            Add (B, "{""ok"":true,""cmd"":""world"",""island"":");
            Add_Nat (B, S.Island_Seed);
            Add (B, ",""pop"":");
            Add_Nat (B, S.Pop_Seed);
            Add (B, ",""population"":");
            Add_Nat (B, World.Alive_Count (S));
            Add (B, ",""births"":");
            Add_Nat (B, S.Births);
            Add (B, ",""deaths"":");
            Add_Nat (B, S.Deaths);
            Add (B, ",""avg_speed"":");
            Add_Nat (B, World.Average_Milli (S, 1));
            Add (B, ",""avg_sight"":");
            Add_Nat (B, World.Average_Milli (S, 2));
            Add (B, ",""avg_metabolism"":");
            Add_Nat (B, World.Average_Milli (S, 3));
            Add (B, ",""avg_fertility"":");
            Add_Nat (B, World.Average_Milli (S, 4));
            Close_Cmd;
         end if;
         Emit (True);
      elsif Same (Command (V1 .. V2), "look") then
         if Has then
            Fail_Bad ("look");
            return;
         end if;
         Note;
         Spend (False);
         if As_Text then
            Add_You (B, S);
            Add_Seen_Text (B, S);
            if S.Said_Len > 0 then
               Add (B, " You last said: ");
               Add (B, S.Said (1 .. S.Said_Len));
            end if;
         else
            Add (B, "{""ok"":true,""cmd"":""look"",");
            Add_Place_Json (B, S);
            Add_Said_Json (B, S);
            Add_Seen_Json (B, S);
            Add_Creatures (B, S);
            Close_Cmd;
         end if;
         Emit (True);
      elsif Same (Command (V1 .. V2), "move") then
         if not Has or else not Parse_Dir (Command (R1 .. R2), Dir) then
            Fail_Bad ("move");
            return;
         end if;
         --  The direction word must be a single word (no spaces left in it).
         for K in R1 .. R2 loop
            if Command (K) = ' ' then
               Fail_Bad ("move");
               return;
            end if;
         end loop;
         Note;
         World.Try_Move (S, Dir, Move_R, By);
         Spend (True);
         case Move_R is
            when World.Moved =>
               if As_Text then
                  Add (B, "You move ");
                  Add_Dir_Word (B, Dir);
                  Add (B, " to ");
                  Add_Nat (B, Natural (S.X));
                  Add (B, ",");
                  Add_Nat (B, Natural (S.Y));
                  Add (B, ", on ");
                  Add_Ground (B, Map.Terrain_At (S.Island_Seed, S.X, S.Y));
                  Add (B, ". ");
                  if S.Hand = 0 then
                     Add (B, "Your hand is empty.");
                  else
                     Add (B, "Your hand holds a ");
                     Add_Kind (B, S.Objects (S.Hand).Kind);
                     Add (B, ".");
                  end if;
               else
                  Add (B, "{""ok"":true,""cmd"":""move"",""dir"":""");
                  Add_Dir_Letter (B, Dir);
                  Add (B, """,");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (True);
            when World.Blocked =>
               if As_Text then
                  Add (B, "You cannot move ");
                  Add_Dir_Word (B, Dir);
                  Add (B, ": ");
                  Add_Ground (B, By);
                  Add (B, " is in the way.");
               else
                  Add (B, "{""ok"":false,""cmd"":""move"",""dir"":""");
                  Add_Dir_Letter (B, Dir);
                  Add (B, """,""reason"":""blocked"",""by"":""");
                  Add_Ground (B, By);
                  Add (B, """,");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
            when World.Off_Map =>
               if As_Text then
                  Add (B, "You cannot move ");
                  Add_Dir_Word (B, Dir);
                  Add (B, ": that is off the map.");
               else
                  Add (B, "{""ok"":false,""cmd"":""move"",""dir"":""");
                  Add_Dir_Letter (B, Dir);
                  Add (B, """,""reason"":""blocked"",""by"":""edge"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
         end case;
      elsif Same (Command (V1 .. V2), "pick") then
         if Has then
            Fail_Bad ("pick");
            return;
         end if;
         Note;
         World.Try_Pick (S, Take_R);
         Spend (False);
         case Take_R is
            when World.Took =>
               if As_Text then
                  Add (B, "You pick up the ");
                  Add_Kind (B, S.Objects (S.Hand).Kind);
                  Add (B, ".");
               else
                  Add (B, "{""ok"":true,""cmd"":""pick"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (True);
            when World.Nothing_Here =>
               if As_Text then
                  Add (B, "You cannot pick: nothing is here.");
               else
                  Add (B, "{""ok"":false,""cmd"":""pick"",""reason"":""nothing here"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
            when World.Hand_Full =>
               if As_Text then
                  Add (B, "You cannot pick: your hand is full.");
               else
                  Add (B, "{""ok"":false,""cmd"":""pick"",""reason"":""hand full"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
         end case;
      elsif Same (Command (V1 .. V2), "place") then
         if Has then
            Fail_Bad ("place");
            return;
         end if;
         if S.Hand /= 0 then
            Held := S.Objects (S.Hand).Kind;
         else
            Held := Stone;
         end if;
         Note;
         World.Try_Place (S, Drop_R);
         Spend (False);
         case Drop_R is
            when World.Placed =>
               if As_Text then
                  Add (B, "You place the ");
                  Add_Kind (B, Held);
                  Add (B, ".");
               else
                  Add (B, "{""ok"":true,""cmd"":""place"",""placed"":""");
                  Add_Kind (B, Held);
                  Add (B, """,");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (True);
            when World.Hand_Empty =>
               if As_Text then
                  Add (B, "You cannot place: your hand is empty.");
               else
                  Add (B, "{""ok"":false,""cmd"":""place"",""reason"":""hand empty"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
            when World.Occupied =>
               if As_Text then
                  Add (B, "You cannot place: something is already here.");
               else
                  Add (B, "{""ok"":false,""cmd"":""place"",""reason"":""occupied"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
         end case;
      elsif Same (Command (V1 .. V2), "eat") then
         if Has then
            Fail_Bad ("eat");
            return;
         end if;
         Note;
         World.Try_Eat (S, Eat_R);
         Spend (False);
         if Eat_R = World.Ate_Berry then
            declare
               FX : Integer := Integer (S.X);
               FY : Integer := Integer (S.Y);
            begin
               case S.Facing is
                  when North =>
                     FY := FY - 1;
                  when East =>
                     FX := FX + 1;
                  when South =>
                     FY := FY + 1;
                  when West =>
                     FX := FX - 1;
               end case;
               if FX in Coord and then FY in Coord then
                  World.Mark_Bush (S, Coord (FX), Coord (FY));
               end if;
            end;
         end if;
         case Eat_R is
            when World.Ate_Berry =>
               if As_Text then
                  Add (B, "You eat berries.");
               else
                  Add (B, "{""ok"":true,""cmd"":""eat"",""food"":""berries"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (True);
            when World.Ate_Fish =>
               if As_Text then
                  Add (B, "You eat a fish.");
               else
                  Add (B, "{""ok"":true,""cmd"":""eat"",""food"":""fish"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (True);
            when World.Nothing =>
               if As_Text then
                  Add (B, "There is nothing to eat in front of you.");
               else
                  Add (B, "{""ok"":false,""cmd"":""eat"",""reason"":""nothing to eat"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
            when World.Not_Ripe =>
               if As_Text then
                  Add (B, "The bush has no berries yet.");
               else
                  Add (B, "{""ok"":false,""cmd"":""eat"",""reason"":""not ripe"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
            when World.Need_Stick =>
               if As_Text then
                  Add (B, "You need a stick to fish.");
               else
                  Add (B, "{""ok"":false,""cmd"":""eat"",""reason"":""need a stick"",");
                  Add_Place_Json (B, S);
                  Close_Cmd;
               end if;
               Emit (False);
         end case;
      elsif Same (Command (V1 .. V2), "say") then
         declare
            Inner_First : Natural;
            Inner_Last  : Natural;
            Quoted      : Boolean;
         begin
            Note;
            if not Has then
               World.Try_Say (S, "", Say_R);
            else
               Quoted :=
                 R2 > R1
                 and then Command (R1) = '"'
                 and then Command (R2) = '"';
               if Quoted then
                  Inner_First := R1 + 1;
                  Inner_Last := R2 - 1;
                  if Inner_First > Inner_Last then
                     World.Try_Say (S, "", Say_R);
                  else
                     World.Try_Say
                       (S, Command (Inner_First .. Inner_Last), Say_R);
                  end if;
               else
                  World.Try_Say (S, Command (R1 .. R2), Say_R);
               end if;
            end if;
         end;
         if Say_R = World.Said_Ok then
            Spend (False);
         end if;
         case Say_R is
            when World.Said_Ok =>
               if As_Text then
                  Add (B, "You say: ");
                  if S.Said_Len > 0 then
                     Add (B, S.Said (1 .. S.Said_Len));
                  end if;
               else
                  Add (B, "{""ok"":true,""cmd"":""say"",""text"":");
                  if S.Said_Len = 0 then
                     Add_Json_String (B, "");
                  else
                     Add_Json_String (B, S.Said (1 .. S.Said_Len));
                  end if;
                  Close_Cmd;
               end if;
               Emit (True);
            when World.Too_Long =>
               if As_Text then
                  Add (B, "You cannot say that: the text is too long.");
               else
                  Add (B, "{""ok"":false,""cmd"":""say"",""reason"":""text too long""");
                  Close_Cmd;
               end if;
               Emit (False);
            when World.Not_Plain =>
               if As_Text then
                  Add (B, "You cannot say that: use plain letters, digits and spaces.");
               else
                  Add (B, "{""ok"":false,""cmd"":""say"",""reason"":""text not plain""");
                  Close_Cmd;
               end if;
               Emit (False);
         end case;
      else
         Fail_Unknown (Command (V1 .. V2));
      end if;
   end Execute;

end Island.Text;
