with Interfaces;
with Island.Map;
with Island.Stomach;

package body Island.Folk is
   use type Stomach.Hunger;

   function Mix (A, B, C : Natural) return Natural is
      use Interfaces;
      H : Unsigned_32 :=
        Unsigned_32 (A) * 17 + Unsigned_32 (B) * 131 + Unsigned_32 (C) * 977
        + Map.Seed;
   begin
      H := H xor Shift_Right (H, 8);
      return Natural (H mod 97);
   end Mix;

   function Occupied
     (S : World.State; X, Y : Coord; Except : Integer) return Boolean
   is
   begin
      if Except /= World.Player_Id
        and then S.X = X and then S.Y = Y
      then
         return True;
      end if;
      for I in World.Folk_Id loop
         if I /= Except and then S.Folk (I).Alive
           and then S.Folk (I).X = X and then S.Folk (I).Y = Y
         then
            return True;
         end if;
      end loop;
      return False;
   end Occupied;

   procedure Setup (S : in out World.State) is
      Home : Map.Spot;
      N    : Positive;
   begin
      S.Births := 0;
      S.Deaths := 0;
      for I in World.Folk_Id loop
         S.Folk (I) := (others => <>);
         S.Folk (I).Alive := False;
      end loop;
      S.Folk (World.Player_Id) :=
        (Alive => True,
         X => S.X, Y => S.Y, Facing => S.Facing,
         Belly => S.Belly,
         Age => 30,
         Speed => 1, Sight => 3, Metabolism => 1, Fertility => 2,
         Cool => 0);
      N := 1;
      for G in Map.Npc_Index loop
         N := N + 1;
         Home := Map.Npc_Home (G);
         S.Folk (N).Alive := True;
         S.Folk (N).X := Home.X;
         S.Folk (N).Y := Home.Y;
         S.Folk (N).Facing := North;
         S.Folk (N).Belly :=
           (Full => 100, Empty_For => 0, Collapsed => False);
         S.Folk (N).Age := 50;
         S.Folk (N).Speed := 1 + Mix (N, 1, 0) mod 3;
         if S.Folk (N).Speed = 1 then
            S.Folk (N).Metabolism := 1;
         else
            S.Folk (N).Metabolism := 2;
         end if;
         S.Folk (N).Sight := 2 + Mix (N, 2, 0) mod 3;
         S.Folk (N).Fertility := 1 + Mix (N, 3, 0) mod 3;
         S.Folk (N).Cool := 0;
      end loop;
   end Setup;

   function Dist (X1, Y1, X2, Y2 : Coord) return Natural is
   begin
      return abs (Integer (X1) - Integer (X2))
        + abs (Integer (Y1) - Integer (Y2));
   end Dist;

   function In_Sight
     (C : World.Folk_Rec; X, Y : Coord) return Boolean
   is
   begin
      return abs (Integer (C.X) - Integer (X)) <= C.Sight
        and then abs (Integer (C.Y) - Integer (Y)) <= C.Sight;
   end In_Sight;

   function Bush_Ripe (S : World.State; I : Map.Bush_Index) return Boolean is
      Eaten : constant Natural := S.Bush_Eaten (I);
   begin
      return Eaten = 0 or else S.Turn >= Eaten + Map.Regrow_Turns;
   end Bush_Ripe;

   procedure Face_Step
     (S      : in out World.State;
      Who    : World.Folk_Id;
      TX, TY : Coord;
      Moved  : out Boolean)
   is
      DX : constant Integer := Integer (TX) - Integer (S.Folk (Who).X);
      DY : constant Integer := Integer (TY) - Integer (S.Folk (Who).Y);
      Choice : array (1 .. 2) of Direction := [North, North];
      N_Choice : Natural := 0;
      NX, NY : Integer;
      Dir    : Direction;
   begin
      Moved := False;
      if DX = 0 and then DY = 0 then
         return;
      end if;
      if DX > 0 then
         N_Choice := N_Choice + 1;
         Choice (N_Choice) := East;
      elsif DX < 0 then
         N_Choice := N_Choice + 1;
         Choice (N_Choice) := West;
      end if;
      if DY > 0 then
         N_Choice := N_Choice + 1;
         Choice (N_Choice) := South;
      elsif DY < 0 then
         N_Choice := N_Choice + 1;
         Choice (N_Choice) := North;
      end if;
      if abs DY > abs DX and then N_Choice = 2 then
         Dir := Choice (1);
         Choice (1) := Choice (2);
         Choice (2) := Dir;
      end if;
      for K in 1 .. N_Choice loop
         Dir := Choice (K);
         NX := Integer (S.Folk (Who).X);
         NY := Integer (S.Folk (Who).Y);
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
         if NX in Coord and then NY in Coord
           and then Map.Walkable (Map.Terrain_At (Coord (NX), Coord (NY)))
           and then not Occupied (S, Coord (NX), Coord (NY), Who)
         then
            S.Folk (Who).X := Coord (NX);
            S.Folk (Who).Y := Coord (NY);
            S.Folk (Who).Facing := Dir;
            Moved := True;
            return;
         end if;
      end loop;
   end Face_Step;

   procedure Try_Berry (S : in out World.State; Who : World.Folk_Id) is
      Spot : Map.Spot;
   begin
      if S.Folk (Who).Belly.Collapsed or else S.Folk (Who).Belly.Full >= 70 then
         return;
      end if;
      for I in Map.Bush_Index loop
         Spot := Map.Bush (I);
         if Bush_Ripe (S, I)
           and then abs (Integer (Spot.X) - Integer (S.Folk (Who).X)) <= 1
           and then abs (Integer (Spot.Y) - Integer (S.Folk (Who).Y)) <= 1
         then
            Stomach.Feed (S.Folk (Who).Belly, Map.Berry_Gain);
            World.Mark_Bush (S, Spot.X, Spot.Y);
            return;
         end if;
      end loop;
   end Try_Berry;

   procedure Seek
     (S : in out World.State; Who : World.Folk_Id; TX, TY : Coord)
   is
      Moved : Boolean;
   begin
      for Step in 1 .. S.Folk (Who).Speed loop
         Face_Step (S, Who, TX, TY, Moved);
         exit when not Moved;
         exit when S.Folk (Who).X = TX and then S.Folk (Who).Y = TY;
      end loop;
      Try_Berry (S, Who);
   end Seek;

   procedure Wander (S : in out World.State; Who : World.Folk_Id) is
      Dir : constant Direction :=
        Direction'Val ((Who + S.Turn) mod 4);
      Goal_X : Integer := Integer (S.Folk (Who).X);
      Goal_Y : Integer := Integer (S.Folk (Who).Y);
   begin
      case Dir is
         when North =>
            Goal_Y := Goal_Y - 1;
         when East =>
            Goal_X := Goal_X + 1;
         when South =>
            Goal_Y := Goal_Y + 1;
         when West =>
            Goal_X := Goal_X - 1;
      end case;
      if Goal_X not in Coord then
         Goal_X := Integer (S.Folk (Who).X);
      end if;
      if Goal_Y not in Coord then
         Goal_Y := Integer (S.Folk (Who).Y);
      end if;
      Seek (S, Who, Coord (Goal_X), Coord (Goal_Y));
   end Wander;

   procedure Others_Act (S : in out World.State) is
      Best      : Natural;
      Best_X    : Coord;
      Best_Y    : Coord;
      Found     : Boolean;
      D         : Natural;
      Hungry    : Boolean;
   begin
      for Who in World.Folk_Id loop
         if Who /= World.Player_Id and then S.Folk (Who).Alive
           and then not S.Folk (Who).Belly.Collapsed
         then
            Hungry :=
              S.Folk (Who).Belly.Full < 45
              or else Stomach.Status (S.Folk (Who).Belly) = Stomach.Hungry
              or else Stomach.Status (S.Folk (Who).Belly) = Stomach.Weak;
            Found := False;
            Best := Natural'Last;
            Best_X := S.Folk (Who).X;
            Best_Y := S.Folk (Who).Y;
            if Hungry then
               for B in Map.Bush_Index loop
                  if Bush_Ripe (S, B)
                    and then In_Sight
                      (S.Folk (Who), Map.Bush (B).X, Map.Bush (B).Y)
                  then
                     D := Dist
                       (S.Folk (Who).X, S.Folk (Who).Y,
                        Map.Bush (B).X, Map.Bush (B).Y);
                     if D < Best then
                        Best := D;
                        Best_X := Map.Bush (B).X;
                        Best_Y := Map.Bush (B).Y;
                        Found := True;
                     end if;
                  end if;
               end loop;
            elsif S.Folk (Who).Age >= World.Adult_Age
              and then S.Folk (Who).Belly.Full > 70
              and then S.Folk (Who).Cool = 0
            then
               for Other in World.Folk_Id loop
                  if Other /= Who and then S.Folk (Other).Alive
                    and then S.Folk (Other).Age >= World.Adult_Age
                    and then S.Folk (Other).Belly.Full > 70
                    and then In_Sight
                      (S.Folk (Who), S.Folk (Other).X, S.Folk (Other).Y)
                  then
                     D := Dist
                       (S.Folk (Who).X, S.Folk (Who).Y,
                        S.Folk (Other).X, S.Folk (Other).Y);
                     if D < Best then
                        Best := D;
                        Best_X := S.Folk (Other).X;
                        Best_Y := S.Folk (Other).Y;
                        Found := True;
                     end if;
                  end if;
               end loop;
            end if;
            if not Found then
               for B in Map.Bush_Index loop
                  if In_Sight
                    (S.Folk (Who), Map.Bush (B).X, Map.Bush (B).Y)
                    and then
                      (Map.Bush (B).X /= S.Folk (Who).X
                       or else Map.Bush (B).Y /= S.Folk (Who).Y)
                  then
                     D := Dist
                       (S.Folk (Who).X, S.Folk (Who).Y,
                        Map.Bush (B).X, Map.Bush (B).Y);
                     if D < Best then
                        Best := D;
                        Best_X := Map.Bush (B).X;
                        Best_Y := Map.Bush (B).Y;
                        Found := True;
                     end if;
                  end if;
               end loop;
            end if;
            if Found then
               Seek (S, Who, Best_X, Best_Y);
            else
               Wander (S, Who);
            end if;
         end if;
      end loop;
   end Others_Act;

   function Clamp_Speed (V : Integer) return World.Speed_T is
   begin
      if V < World.Speed_T'First then
         return World.Speed_T'First;
      elsif V > World.Speed_T'Last then
         return World.Speed_T'Last;
      else
         return V;
      end if;
   end Clamp_Speed;

   function Clamp_Sight (V : Integer) return World.Sight_T is
   begin
      if V < World.Sight_T'First then
         return World.Sight_T'First;
      elsif V > World.Sight_T'Last then
         return World.Sight_T'Last;
      else
         return V;
      end if;
   end Clamp_Sight;

   function Clamp_Fert (V : Integer) return World.Fert_T is
   begin
      if V < World.Fert_T'First then
         return World.Fert_T'First;
      elsif V > World.Fert_T'Last then
         return World.Fert_T'Last;
      else
         return V;
      end if;
   end Clamp_Fert;

   function Mut (Turn, A, B, Which : Natural) return Integer is
   begin
      return Integer (Mix (Turn + A, B, Which) mod 3) - 1;
   end Mut;

   procedure Birth_One
     (S : in out World.State; A, B : World.Folk_Id; Slot : World.Folk_Id)
   is
      NX, NY : Integer;
      Placed : Boolean := False;
   begin
      for K in 1 .. 4 loop
         NX := Integer (S.Folk (A).X);
         NY := Integer (S.Folk (A).Y);
         case K is
            when 1 =>
               NY := NY - 1;
            when 2 =>
               NX := NX + 1;
            when 3 =>
               NY := NY + 1;
            when 4 =>
               NX := NX - 1;
         end case;
         if NX in Coord and then NY in Coord
           and then Map.Walkable (Map.Terrain_At (Coord (NX), Coord (NY)))
           and then not Occupied (S, Coord (NX), Coord (NY), 0)
         then
            S.Folk (Slot).Alive := True;
            S.Folk (Slot).X := Coord (NX);
            S.Folk (Slot).Y := Coord (NY);
            S.Folk (Slot).Facing := North;
            S.Folk (Slot).Age := 0;
            S.Folk (Slot).Cool := 12;
            S.Folk (Slot).Belly :=
              (Full => 60, Empty_For => 0, Collapsed => False);
            S.Folk (Slot).Speed := Clamp_Speed
              ((S.Folk (A).Speed + S.Folk (B).Speed) / 2
               + Mut (S.Turn, A, B, 1));
            S.Folk (Slot).Sight := Clamp_Sight
              ((S.Folk (A).Sight + S.Folk (B).Sight) / 2
               + Mut (S.Turn, A, B, 2));
            if S.Folk (Slot).Speed = 1 then
               S.Folk (Slot).Metabolism := 1;
            else
               S.Folk (Slot).Metabolism := 2;
            end if;
            S.Folk (Slot).Fertility := Clamp_Fert
              ((S.Folk (A).Fertility + S.Folk (B).Fertility) / 2
               + Mut (S.Turn, A, B, 3));
            Placed := True;
            exit;
         end if;
      end loop;
      if not Placed then
         return;
      end if;
      S.Folk (A).Belly.Full :=
        Stomach.Fullness (Natural (S.Folk (A).Belly.Full) - 30);
      S.Folk (B).Belly.Full :=
        Stomach.Fullness (Natural (S.Folk (B).Belly.Full) - 30);
      S.Folk (A).Cool := 4 * (4 - Natural (S.Folk (A).Fertility));
      S.Folk (B).Cool := 4 * (4 - Natural (S.Folk (B).Fertility));
      S.Births := S.Births + 1;
   end Birth_One;

   function Free_Slot (S : World.State) return Integer is
   begin
      for I in World.Folk_Id loop
         if I /= World.Player_Id and then not S.Folk (I).Alive then
            return I;
         end if;
      end loop;
      return 0;
   end Free_Slot;

   function Adjacent (A, B : World.Folk_Rec) return Boolean is
   begin
      return abs (Integer (A.X) - Integer (B.X)) <= 1
        and then abs (Integer (A.Y) - Integer (B.Y)) <= 1;
   end Adjacent;

   procedure After_Actions (S : in out World.State; Turns : Positive) is
      Slot : Integer;
      Bred : array (World.Folk_Id) of Boolean := [others => False];
   begin
      for Who in World.Folk_Id loop
         if Who /= World.Player_Id and then S.Folk (Who).Alive
           and then not S.Folk (Who).Belly.Collapsed
         then
            Stomach.Tick
              (S.Folk (Who).Belly, 1, False, Positive (S.Folk (Who).Metabolism));
         end if;
      end loop;
      for Who in World.Folk_Id loop
         if S.Folk (Who).Alive then
            S.Folk (Who).Age := S.Folk (Who).Age + Natural (Turns);
            if S.Folk (Who).Cool > 0 then
               if S.Folk (Who).Cool > Natural (Turns) then
                  S.Folk (Who).Cool := S.Folk (Who).Cool - Natural (Turns);
               else
                  S.Folk (Who).Cool := 0;
               end if;
            end if;
         end if;
      end loop;
      for A in World.Folk_Id loop
         if S.Folk (A).Alive and then not Bred (A)
           and then S.Folk (A).Age >= World.Adult_Age
           and then S.Folk (A).Belly.Full > 70
           and then S.Folk (A).Cool = 0
           and then not S.Folk (A).Belly.Collapsed
         then
            for B in World.Folk_Id loop
               if B > A and then S.Folk (B).Alive and then not Bred (B)
                 and then S.Folk (B).Age >= World.Adult_Age
                 and then S.Folk (B).Belly.Full > 70
                 and then S.Folk (B).Cool = 0
                 and then Adjacent (S.Folk (A), S.Folk (B))
               then
                  Slot := Free_Slot (S);
                  if Slot /= 0 then
                     Birth_One (S, A, B, World.Folk_Id (Slot));
                     Bred (A) := True;
                     Bred (B) := True;
                  end if;
                  exit;
               end if;
            end loop;
         end if;
      end loop;
      for Who in World.Folk_Id loop
         if S.Folk (Who).Alive
           and then (S.Folk (Who).Belly.Collapsed
                     or else S.Folk (Who).Age >= World.Max_Age)
         then
            S.Folk (Who).Alive := False;
            S.Deaths := S.Deaths + 1;
            if Who = World.Player_Id then
               S.Folk (Who).Belly.Collapsed := True;
               S.Folk (Who).Belly.Full := 0;
               if S.Folk (Who).Belly.Empty_For < Stomach.Starve_Turns then
                  S.Folk (Who).Belly.Empty_For := Stomach.Starve_Turns;
               end if;
               S.Belly := S.Folk (Who).Belly;
            end if;
         end if;
      end loop;
   end After_Actions;

   procedure Player_Act (S : in out World.State) is
      Best   : Natural;
      Best_X : Coord;
      Best_Y : Coord;
      Found  : Boolean;
      D      : Natural;
      Who    : constant World.Folk_Id := World.Player_Id;
   begin
      S.Folk (Who).X := S.X;
      S.Folk (Who).Y := S.Y;
      S.Folk (Who).Facing := S.Facing;
      S.Folk (Who).Belly := S.Belly;
      if not S.Folk (Who).Alive or else S.Belly.Collapsed then
         return;
      end if;
      Found := False;
      Best := Natural'Last;
      Best_X := S.X;
      Best_Y := S.Y;
      if S.Belly.Full < 45 then
         for B in Map.Bush_Index loop
            if Bush_Ripe (S, B)
              and then In_Sight (S.Folk (Who), Map.Bush (B).X, Map.Bush (B).Y)
            then
               D := Dist (S.X, S.Y, Map.Bush (B).X, Map.Bush (B).Y);
               if D < Best then
                  Best := D;
                  Best_X := Map.Bush (B).X;
                  Best_Y := Map.Bush (B).Y;
                  Found := True;
               end if;
            end if;
         end loop;
      end if;
      if Found then
         Seek (S, Who, Best_X, Best_Y);
      else
         Wander (S, Who);
      end if;
      S.X := S.Folk (Who).X;
      S.Y := S.Folk (Who).Y;
      S.Facing := S.Folk (Who).Facing;
      S.Belly := S.Folk (Who).Belly;
   end Player_Act;

begin
   null;
end Island.Folk;
