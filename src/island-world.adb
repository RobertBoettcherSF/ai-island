with Island.Folk;

package body Island.World is

   function Valid (S : State) return Boolean is
      Held : Natural := 0;
   begin
      if not Map.Walkable (Map.Terrain_At (S.Island_Seed, S.X, S.Y)) then
         return False;
      end if;
      for I in S.Objects'Range loop
         if not S.Objects (I).On_Ground then
            Held := Held + 1;
            if S.Hand /= I then
               return False;
            end if;
         end if;
      end loop;
      if S.Hand = 0 then
         if Held /= 0 then
            return False;
         end if;
      elsif Held /= 1 or else S.Objects (S.Hand).On_Ground then
         return False;
      end if;
      for I in S.Objects'Range loop
         if S.Objects (I).On_Ground then
            for J in S.Objects'Range loop
               if J /= I
                 and then S.Objects (J).On_Ground
                 and then S.Objects (J).X = S.Objects (I).X
                 and then S.Objects (J).Y = S.Objects (I).Y
               then
                  return False;
               end if;
            end loop;
         end if;
      end loop;
      if not Stomach.Levels_Ok (S.Belly) then
         return False;
      end if;
      for I in S.Bush_Eaten'Range loop
         if S.Bush_Eaten (I) > S.Turn then
            return False;
         end if;
      end loop;
      for I in Folk_Id loop
         if S.Folk (I).Alive then
            if not Map.Walkable
              (Map.Terrain_At (S.Island_Seed, S.Folk (I).X, S.Folk (I).Y))
            then
               return False;
            end if;
            if not Stomach.Levels_Ok (S.Folk (I).Belly) then
               return False;
            end if;
         end if;
      end loop;
      return True;
   end Valid;

   procedure Reset
     (S           : out State;
      Island_Seed : Map.Seed_Value := Map.Default_Island_Seed;
      Pop_Seed    : Map.Seed_Value := Map.Default_Pop_Seed)
   is
   begin
      S.Island_Seed := Island_Seed;
      S.Pop_Seed := Pop_Seed;
      S.X := Map.Start_X;
      S.Y := Map.Start_Y;
      S.Facing := North;
      S.Hand := 0;
      S.Said := [others => ' '];
      S.Said_Len := 0;
      S.Belly := (Full => Stomach.Max_Fullness, Empty_For => 0, Collapsed => False);
      S.Turn := 0;
      S.Bush_Eaten := [others => 0];
      for I in Object_Index loop
         S.Objects (I).Kind := Map.Initial_Objects (I).Kind;
         S.Objects (I).X := Map.Initial_Objects (I).X;
         S.Objects (I).Y := Map.Initial_Objects (I).Y;
         S.Objects (I).On_Ground := True;
      end loop;
      Folk.Setup (S);
   end Reset;

   procedure Try_Move
     (S      : in out State;
      Dir    : Direction;
      Result : out Move_Result;
      By     : out Terrain)
   is
      NX : Integer := Integer (S.X);
      NY : Integer := Integer (S.Y);
   begin
      By := Water;
      case Dir is
         when North =>
            NY := NY - 1;
         when East =>
            NX := NX + 1;
         when South =>
            NY := NY + 1;
         when West =>
            NX := NX - 1;
      end case;
      if NX not in Coord or else NY not in Coord then
         Result := Off_Map;
         return;
      end if;
      By := Map.Terrain_At (S.Island_Seed, Coord (NX), Coord (NY));
      if not Map.Walkable (By) then
         Result := Blocked;
         return;
      end if;
      for I in Folk_Id loop
         if I /= Player_Id and then S.Folk (I).Alive
           and then S.Folk (I).X = Coord (NX)
           and then S.Folk (I).Y = Coord (NY)
         then
            Result := Blocked;
            return;
         end if;
      end loop;
      S.X := Coord (NX);
      S.Y := Coord (NY);
      S.Facing := Dir;
      Result := Moved;
   end Try_Move;

   procedure Try_Pick (S : in out State; Result : out Take_Result) is
   begin
      if S.Hand /= 0 then
         Result := Hand_Full;
         return;
      end if;
      for I in S.Objects'Range loop
         if S.Objects (I).On_Ground
           and then S.Objects (I).X = S.X
           and then S.Objects (I).Y = S.Y
         then
            S.Objects (I).On_Ground := False;
            S.Hand := I;
            Result := Took;
            return;
         end if;
      end loop;
      Result := Nothing_Here;
   end Try_Pick;

   procedure Try_Place (S : in out State; Result : out Drop_Result) is
      Held : Object_Index;
   begin
      if S.Hand = 0 then
         Result := Hand_Empty;
         return;
      end if;
      for I in S.Objects'Range loop
         if S.Objects (I).On_Ground
           and then S.Objects (I).X = S.X
           and then S.Objects (I).Y = S.Y
         then
            Result := Occupied;
            return;
         end if;
      end loop;
      Held := S.Hand;
      S.Objects (Held).X := S.X;
      S.Objects (Held).Y := S.Y;
      S.Objects (Held).On_Ground := True;
      S.Hand := 0;
      Result := Placed;
   end Try_Place;

   procedure Try_Say
     (S : in out State; Text : String; Result : out Say_Result)
   is
   begin
      if Text'Length > Said_Max then
         Result := Too_Long;
         return;
      end if;
      for I in Text'Range loop
         if Text (I) not in ' ' .. '~' then
            Result := Not_Plain;
            return;
         end if;
      end loop;
      S.Said := [others => ' '];
      if Text'Length > 0 then
         S.Said (1 .. Text'Length) := Text;
      end if;
      S.Said_Len := Text'Length;
      Result := Said_Ok;
   end Try_Say;

   procedure Put_Char (Buf : in out String; Pos : in out Natural; C : Character) is
   begin
      pragma Assert (Pos >= Buf'First and then Pos <= Buf'Last);
      Buf (Pos) := C;
      Pos := Pos + 1;
   end Put_Char;

   procedure Put_Text (Buf : in out String; Pos : in out Natural; Text : String) is
   begin
      for I in Text'Range loop
         Put_Char (Buf, Pos, Text (I));
      end loop;
   end Put_Text;

   procedure Put_Nat (Buf : in out String; Pos : in out Natural; N : Natural) is
      Digs : String (1 .. 10) := [others => '0'];
      V    : Natural := N;
      L    : Natural := 0;
   begin
      if V = 0 then
         Put_Char (Buf, Pos, '0');
         return;
      end if;
      while V > 0 loop
         L := L + 1;
         pragma Assert (L <= Digs'Last);
         Digs (L) := Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      for I in reverse 1 .. L loop
         Put_Char (Buf, Pos, Digs (I));
      end loop;
   end Put_Nat;

   function Face_Char (Dir : Direction) return Character is
   begin
      case Dir is
         when North =>
            return 'N';
         when East =>
            return 'E';
         when South =>
            return 'S';
         when West =>
            return 'W';
      end case;
   end Face_Char;

   function Kind_Code (Kind : Object_Kind) return Natural is
   begin
      case Kind is
         when Stone =>
            return 1;
         when Stick =>
            return 2;
         when Shell =>
            return 3;
      end case;
   end Kind_Code;

   function Ripe (Eaten : Natural; Now : Natural) return Boolean is
   begin
      if Eaten = 0 then
         return True;
      end if;
      pragma Assert (Eaten <= Natural'Last - Map.Regrow_Turns);
      return Now >= Eaten + Map.Regrow_Turns;
   end Ripe;

   function Food_At (S : State; X, Y : Coord) return Food is
   begin
      for I in Map.Bush_Index loop
         if Map.Bush (S.Island_Seed, I).X = X
           and then Map.Bush (S.Island_Seed, I).Y = Y
         then
            if Ripe (S.Bush_Eaten (I), S.Turn) then
               return Berries;
            else
               return Bare;
            end if;
         end if;
      end loop;
      for I in Map.Fish_Index loop
         if Map.Fish_At (S.Island_Seed, I).X = X
           and then Map.Fish_At (S.Island_Seed, I).Y = Y
         then
            return Fish;
         end if;
      end loop;
      return None;
   end Food_At;

   function Collapsed (S : State) return Boolean is
   begin
      return S.Belly.Collapsed;
   end Collapsed;

   function Holding_Stick (S : State) return Boolean is
   begin
      return S.Hand /= 0 and then S.Objects (S.Hand).Kind = Stick;
   end Holding_Stick;

   procedure Try_Eat (S : in out State; Result : out Eat_Result) is
      FX : Integer := Integer (S.X);
      FY : Integer := Integer (S.Y);
   begin
      Result := Nothing;
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
      if FX not in Coord or else FY not in Coord then
         return;
      end if;
      case Food_At (S, Coord (FX), Coord (FY)) is
         when None =>
            Result := Nothing;
         when Bare =>
            Result := Not_Ripe;
         when Berries =>
            Stomach.Feed (S.Belly, Map.Berry_Gain);
            Result := Ate_Berry;
         when Fish =>
            if not Holding_Stick (S) then
               Result := Need_Stick;
               return;
            end if;
            Stomach.Feed (S.Belly, Map.Fish_Gain);
            Result := Ate_Fish;
      end case;
   end Try_Eat;

   procedure Mark_Bush (S : in out State; X, Y : Coord) is
   begin
      for I in Map.Bush_Index loop
         if Map.Bush (S.Island_Seed, I).X = X
           and then Map.Bush (S.Island_Seed, I).Y = Y
         then
            S.Bush_Eaten (I) := S.Turn;
            return;
         end if;
      end loop;
   end Mark_Bush;

   procedure Advance
     (S        : in out State;
      Is_Move  : Boolean;
      Was_Weak : Boolean;
      Carrying : Boolean)
   is
      Turns : Positive := 1;
   begin
      if Is_Move and then Was_Weak then
         Turns := 2;
      end if;
      if not S.Belly.Collapsed then
         Stomach.Tick (S.Belly, Turns, Carrying);
      end if;
      S.Folk (Player_Id).X := S.X;
      S.Folk (Player_Id).Y := S.Y;
      S.Folk (Player_Id).Facing := S.Facing;
      S.Folk (Player_Id).Belly := S.Belly;
      Folk.Others_Act (S);
      Folk.After_Actions (S, Turns);
      S.Belly := S.Folk (Player_Id).Belly;
      if not S.Folk (Player_Id).Alive then
         S.Belly.Collapsed := True;
         S.Belly.Full := 0;
      end if;
      pragma Assert (S.Turn <= Natural'Last - Natural (Turns));
      S.Turn := S.Turn + Natural (Turns);
   end Advance;

   procedure Simulate (S : in out State; Turns : Positive) is
   begin
      for Step in 1 .. Turns loop
         if S.Folk (Player_Id).Alive and then not S.Belly.Collapsed then
            Folk.Player_Act (S);
            Advance (S, False, False, S.Hand /= 0);
         else
            Folk.Others_Act (S);
            Folk.After_Actions (S, 1);
            S.Turn := S.Turn + 1;
         end if;
      end loop;
   end Simulate;

   function Alive_Count (S : State) return Natural is
      N : Natural := 0;
   begin
      for I in Folk_Id loop
         if S.Folk (I).Alive then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Alive_Count;

   function Average_Milli (S : State; Which : Trait_Query) return Natural is
      Sum   : Natural := 0;
      Count : Natural := 0;
      Value : Natural;
   begin
      for I in Folk_Id loop
         if S.Folk (I).Alive then
            case Which is
               when 1 =>
                  Value := Natural (S.Folk (I).Speed);
               when 2 =>
                  Value := Natural (S.Folk (I).Sight);
               when 3 =>
                  Value := Natural (S.Folk (I).Metabolism);
               when others =>
                  Value := Natural (S.Folk (I).Fertility);
            end case;
            Sum := Sum + Value;
            Count := Count + 1;
         end if;
      end loop;
      if Count = 0 then
         return 0;
      end if;
      return (Sum * 1000) / Count;
   end Average_Milli;

   procedure Write_Save (S : State; Buf : out String; Len : out Natural) is
      Pos : Natural := 1;
   begin
      Buf := [others => ' '];
      Put_Text (Buf, Pos, "ai-island 4");
      Put_Char (Buf, Pos, ASCII.LF);
      Put_Nat (Buf, Pos, Natural (S.X));
      Put_Char (Buf, Pos, ' ');
      Put_Nat (Buf, Pos, Natural (S.Y));
      Put_Char (Buf, Pos, ' ');
      Put_Char (Buf, Pos, Face_Char (S.Facing));
      Put_Char (Buf, Pos, ' ');
      Put_Nat (Buf, Pos, Natural (S.Hand));
      Put_Char (Buf, Pos, ASCII.LF);
      for I in Object_Index loop
         Put_Nat (Buf, Pos, Kind_Code (S.Objects (I).Kind));
         Put_Char (Buf, Pos, ' ');
         if S.Objects (I).On_Ground then
            Put_Char (Buf, Pos, '1');
         else
            Put_Char (Buf, Pos, '0');
         end if;
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Objects (I).X));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Objects (I).Y));
         Put_Char (Buf, Pos, ASCII.LF);
      end loop;
      if S.Said_Len > 0 then
         Put_Text (Buf, Pos, S.Said (1 .. S.Said_Len));
      end if;
      Put_Char (Buf, Pos, ASCII.LF);
      Put_Nat (Buf, Pos, S.Turn);
      Put_Char (Buf, Pos, ASCII.LF);
      Put_Nat (Buf, Pos, Natural (S.Belly.Full));
      Put_Char (Buf, Pos, ' ');
      Put_Nat (Buf, Pos, S.Belly.Empty_For);
      Put_Char (Buf, Pos, ' ');
      if S.Belly.Collapsed then
         Put_Char (Buf, Pos, '1');
      else
         Put_Char (Buf, Pos, '0');
      end if;
      Put_Char (Buf, Pos, ASCII.LF);
      for I in Map.Bush_Index loop
         if I > Map.Bush_Index'First then
            Put_Char (Buf, Pos, ' ');
         end if;
         Put_Nat (Buf, Pos, S.Bush_Eaten (I));
      end loop;
      Put_Char (Buf, Pos, ASCII.LF);
      Put_Nat (Buf, Pos, S.Births);
      Put_Char (Buf, Pos, ' ');
      Put_Nat (Buf, Pos, S.Deaths);
      Put_Char (Buf, Pos, ' ');
      Put_Nat (Buf, Pos, S.Island_Seed);
      Put_Char (Buf, Pos, ' ');
      Put_Nat (Buf, Pos, S.Pop_Seed);
      Put_Char (Buf, Pos, ASCII.LF);
      for I in Folk_Id loop
         if S.Folk (I).Alive then
            Put_Char (Buf, Pos, '1');
         else
            Put_Char (Buf, Pos, '0');
         end if;
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).X));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).Y));
         Put_Char (Buf, Pos, ' ');
         Put_Char (Buf, Pos, Face_Char (S.Folk (I).Facing));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, S.Folk (I).Age);
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).Speed));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).Sight));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).Metabolism));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).Fertility));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, S.Folk (I).Cool);
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, Natural (S.Folk (I).Belly.Full));
         Put_Char (Buf, Pos, ' ');
         Put_Nat (Buf, Pos, S.Folk (I).Belly.Empty_For);
         Put_Char (Buf, Pos, ' ');
         if S.Folk (I).Belly.Collapsed then
            Put_Char (Buf, Pos, '1');
         else
            Put_Char (Buf, Pos, '0');
         end if;
         Put_Char (Buf, Pos, ASCII.LF);
      end loop;
      Len := Pos - 1;
   end Write_Save;

   procedure Expect
     (Buf  : String;
      Pos  : in out Natural;
      Last : Natural;
      C    : Character;
      Ok   : in out Boolean)
   is
   begin
      if not Ok then
         return;
      end if;
      if Pos > Last or else Buf (Pos) /= C then
         Ok := False;
         return;
      end if;
      Pos := Pos + 1;
   end Expect;

   procedure Take_Nat
     (Buf   : String;
      Pos   : in out Natural;
      Last  : Natural;
      Value : out Natural;
      Limit : Natural;
      Ok    : in out Boolean)
   is
      V   : Natural := 0;
      Any : Boolean := False;
      D   : Natural;
   begin
      Value := 0;
      if not Ok then
         return;
      end if;
      while Pos <= Last and then Buf (Pos) in '0' .. '9' loop
         Any := True;
         D := Character'Pos (Buf (Pos)) - Character'Pos ('0');
         if D > Limit or else V > (Limit - D) / 10 then
            Ok := False;
            return;
         end if;
         V := V * 10 + D;
         Pos := Pos + 1;
      end loop;
      if not Any then
         Ok := False;
         return;
      end if;
      Value := V;
   end Take_Nat;

   procedure Next_Line
     (Buf   : String;
      From  : in out Natural;
      First : out Natural;
      Last  : out Natural;
      Ok    : in out Boolean)
   is
   begin
      First := 1;
      Last := 0;
      if not Ok or else From > Buf'Last then
         Ok := False;
         return;
      end if;
      First := From;
      while From <= Buf'Last and then Buf (From) /= ASCII.LF loop
         if Buf (From) = ASCII.CR then
            Ok := False;
            return;
         end if;
         From := From + 1;
      end loop;
      if From > Buf'Last or else Buf (From) /= ASCII.LF then
         Ok := False;
         return;
      end if;
      Last := From - 1;
      From := From + 1;
   end Next_Line;

   function Kind_Of (Code : Natural; Kind : out Object_Kind) return Boolean is
   begin
      case Code is
         when 1 =>
            Kind := Stone;
            return True;
         when 2 =>
            Kind := Stick;
            return True;
         when 3 =>
            Kind := Shell;
            return True;
         when others =>
            Kind := Stone;
            return False;
      end case;
   end Kind_Of;

   function Dir_Of (C : Character; Dir : out Direction) return Boolean is
   begin
      case C is
         when 'N' =>
            Dir := North;
            return True;
         when 'E' =>
            Dir := East;
            return True;
         when 'S' =>
            Dir := South;
            return True;
         when 'W' =>
            Dir := West;
            return True;
         when others =>
            Dir := North;
            return False;
      end case;
   end Dir_Of;

   procedure Read_Save (Buf : String; S : out State; Ok : out Boolean) is
      Local : State;
      From  : Natural := Buf'First;
      F1, L1, F2, L2, F3, L3, F4, L4, F5, L5, F6, L6 : Natural;
      F7, L7, F8, L8, F9, L9 : Natural;
      Pos   : Natural;
      Xn, Yn, Hand_N, Code, Present, Ox, Oy : Natural;
      Turn_N, Full_N, Empty_N, Down_N, Bush_N : Natural;
      Dir   : Direction;
      Kind  : Object_Kind;
      Face  : Character;
      Good  : Boolean := True;
   begin
      Reset (Local);
      Next_Line (Buf, From, F1, L1, Good);
      Next_Line (Buf, From, F2, L2, Good);
      Next_Line (Buf, From, F3, L3, Good);
      Next_Line (Buf, From, F4, L4, Good);
      Next_Line (Buf, From, F5, L5, Good);
      Next_Line (Buf, From, F6, L6, Good);
      Next_Line (Buf, From, F7, L7, Good);
      Next_Line (Buf, From, F8, L8, Good);
      Next_Line (Buf, From, F9, L9, Good);
      declare
         Fb, Lb : Natural;
      begin
         Next_Line (Buf, From, Fb, Lb, Good);
         if Good then
            Pos := Fb;
            Take_Nat (Buf, Pos, Lb, Turn_N, 1_000_000, Good);
            Expect (Buf, Pos, Lb, ' ', Good);
            Take_Nat (Buf, Pos, Lb, Full_N, 1_000_000, Good);
            Expect (Buf, Pos, Lb, ' ', Good);
            declare
               Island_N, Pop_N : Natural;
            begin
               Take_Nat (Buf, Pos, Lb, Island_N, 2_147_483_647, Good);
               Expect (Buf, Pos, Lb, ' ', Good);
               Take_Nat (Buf, Pos, Lb, Pop_N, 2_147_483_647, Good);
               if Good and then Pos = Lb + 1 then
                  Local.Births := Turn_N;
                  Local.Deaths := Full_N;
                  Local.Island_Seed := Island_N;
                  Local.Pop_Seed := Pop_N;
               else
                  Good := False;
               end if;
            end;
         end if;
      end;
      if Good and then Buf (F1 .. L1) /= "ai-island 4" then
         Good := False;
      end if;
      if Good then
         Pos := F2;
         Take_Nat (Buf, Pos, L2, Xn, Coord'Last, Good);
         Expect (Buf, Pos, L2, ' ', Good);
         Take_Nat (Buf, Pos, L2, Yn, Coord'Last, Good);
         Expect (Buf, Pos, L2, ' ', Good);
         if Good and then Pos <= L2 then
            Face := Buf (Pos);
            Pos := Pos + 1;
         else
            Face := '?';
            Good := False;
         end if;
         Expect (Buf, Pos, L2, ' ', Good);
         Take_Nat (Buf, Pos, L2, Hand_N, Max_Objects, Good);
         if Good and then Pos /= L2 + 1 then
            Good := False;
         end if;
         if Good and then Dir_Of (Face, Dir) then
            Local.X := Coord (Xn);
            Local.Y := Coord (Yn);
            Local.Facing := Dir;
            Local.Hand := Hand_Index (Hand_N);
         else
            Good := False;
         end if;
      end if;
      if Good then
         declare
            Lines : constant array (Object_Index) of Natural := [F3, F4, F5];
            Ends  : constant array (Object_Index) of Natural := [L3, L4, L5];
         begin
            for I in Object_Index loop
               Pos := Lines (I);
               Take_Nat (Buf, Pos, Ends (I), Code, 3, Good);
               Expect (Buf, Pos, Ends (I), ' ', Good);
               Take_Nat (Buf, Pos, Ends (I), Present, 1, Good);
               Expect (Buf, Pos, Ends (I), ' ', Good);
               Take_Nat (Buf, Pos, Ends (I), Ox, Coord'Last, Good);
               Expect (Buf, Pos, Ends (I), ' ', Good);
               Take_Nat (Buf, Pos, Ends (I), Oy, Coord'Last, Good);
               if Good and then Pos /= Ends (I) + 1 then
                  Good := False;
               end if;
               if Good and then Kind_Of (Code, Kind) then
                  Local.Objects (I).Kind := Kind;
                  Local.Objects (I).X := Coord (Ox);
                  Local.Objects (I).Y := Coord (Oy);
                  Local.Objects (I).On_Ground := Present = 1;
               else
                  Good := False;
               end if;
            end loop;
         end;
      end if;
      if Good then
         if L6 < F6 then
            Local.Said_Len := 0;
         elsif L6 - F6 + 1 > Said_Max then
            Good := False;
         else
            Local.Said := [others => ' '];
            Local.Said (1 .. L6 - F6 + 1) := Buf (F6 .. L6);
            Local.Said_Len := L6 - F6 + 1;
            for I in 1 .. Local.Said_Len loop
               if Local.Said (I) not in ' ' .. '~' then
                  Good := False;
               end if;
            end loop;
         end if;
      end if;
      if Good then
         Pos := F7;
         Take_Nat (Buf, Pos, L7, Turn_N, 1_000_000, Good);
         if Good and then Pos /= L7 + 1 then
            Good := False;
         end if;
         if Good then
            Local.Turn := Turn_N;
         end if;
      end if;
      if Good then
         Pos := F8;
         Take_Nat (Buf, Pos, L8, Full_N, Stomach.Max_Fullness, Good);
         Expect (Buf, Pos, L8, ' ', Good);
         Take_Nat (Buf, Pos, L8, Empty_N, 1_000, Good);
         Expect (Buf, Pos, L8, ' ', Good);
         Take_Nat (Buf, Pos, L8, Down_N, 1, Good);
         if Good and then Pos /= L8 + 1 then
            Good := False;
         end if;
         if Good then
            Local.Belly.Full := Stomach.Fullness (Full_N);
            Local.Belly.Empty_For := Empty_N;
            Local.Belly.Collapsed := Down_N = 1;
         end if;
      end if;
      if Good then
         Pos := F9;
         for I in Map.Bush_Index loop
            if I > Map.Bush_Index'First then
               Expect (Buf, Pos, L9, ' ', Good);
            end if;
            Take_Nat (Buf, Pos, L9, Bush_N, 1_000_000, Good);
            if Good then
               Local.Bush_Eaten (I) := Bush_N;
            end if;
         end loop;
         if Good and then Pos /= L9 + 1 then
            Good := False;
         end if;
      end if;
      if Good then
         declare
            Fa, La : Natural;
            Alive_N, Xn2, Yn2, Age_N, Sp, Si, Me, Fe, Cool_N : Natural;
            Full2, Empty2, Down2 : Natural;
            Face2 : Character;
            Dir2  : Direction;
         begin
            for I in Folk_Id loop
               Next_Line (Buf, From, Fa, La, Good);
               Pos := Fa;
               Take_Nat (Buf, Pos, La, Alive_N, 1, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Xn2, Coord'Last, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Yn2, Coord'Last, Good);
               Expect (Buf, Pos, La, ' ', Good);
               if Good and then Pos <= La then
                  Face2 := Buf (Pos);
                  Pos := Pos + 1;
               else
                  Face2 := '?';
                  Good := False;
               end if;
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Age_N, 10_000, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Sp, 3, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Si, 4, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Me, 3, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Fe, 3, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Cool_N, 10_000, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Full2, Stomach.Max_Fullness, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Empty2, 1_000, Good);
               Expect (Buf, Pos, La, ' ', Good);
               Take_Nat (Buf, Pos, La, Down2, 1, Good);
               if Good and then Pos /= La + 1 then
                  Good := False;
               end if;
               if Good and then Dir_Of (Face2, Dir2)
                 and then Sp in Speed_T and then Si in Sight_T
                 and then Me in Meta_T and then Fe in Fert_T
               then
                  Local.Folk (I).Alive := Alive_N = 1;
                  Local.Folk (I).X := Coord (Xn2);
                  Local.Folk (I).Y := Coord (Yn2);
                  Local.Folk (I).Facing := Dir2;
                  Local.Folk (I).Age := Age_N;
                  Local.Folk (I).Speed := Sp;
                  Local.Folk (I).Sight := Si;
                  Local.Folk (I).Metabolism := Me;
                  Local.Folk (I).Fertility := Fe;
                  Local.Folk (I).Cool := Cool_N;
                  Local.Folk (I).Belly.Full := Stomach.Fullness (Full2);
                  Local.Folk (I).Belly.Empty_For := Empty2;
                  Local.Folk (I).Belly.Collapsed := Down2 = 1;
               else
                  Good := False;
               end if;
            end loop;
         end;
         if Good and then From /= Buf'Last + 1 then
            Good := False;
         end if;
         if Good then
            Local.X := Local.Folk (Player_Id).X;
            Local.Y := Local.Folk (Player_Id).Y;
            Local.Facing := Local.Folk (Player_Id).Facing;
            Local.Belly := Local.Folk (Player_Id).Belly;
         end if;
      end if;
      if Good and then Valid (Local) then
         S := Local;
         Ok := True;
      else
         Reset (S);
         Ok := False;
      end if;
   end Read_Save;

end Island.World;
