with Interfaces;
with Island.Map;
with Island.Stomach;

package body Island.Folk is
   use type Stomach.Hunger;
   use type World.Pile_Kind;
   use type World.Note_Kind;

   function Mix (Seed : Map.Seed_Value; A, B, C : Natural) return Natural is
      use Interfaces;
      H : Unsigned_32 :=
        Unsigned_32 (A) * 17 + Unsigned_32 (B) * 131 + Unsigned_32 (C) * 977
        + Unsigned_32 (Seed);
   begin
      H := H xor Shift_Right (H, 8);
      return Natural (H mod 97);
   end Mix;

   function Mean (A, B : Natural) return Natural is
   begin
      return (A + B + 1) / 2;
   end Mean;

   procedure Express (C : in out World.Folk_Rec) is
      Speed : Natural;
      Sight : Natural;
      Meta  : Natural;
      Fert  : Natural;
   begin
      Speed := Mean (C.Sp_A, C.Sp_B);
      if Speed < 1 then
         Speed := 1;
      elsif Speed > 3 then
         Speed := 3;
      end if;
      Sight := 1 + Mean (C.Si_A, C.Si_B);
      if Sight < 2 then
         Sight := 2;
      elsif Sight > 4 then
         Sight := 4;
      end if;
      Meta := Mean (C.Me_A, C.Me_B);
      if Meta < 1 then
         Meta := 1;
      elsif Meta > 3 then
         Meta := 3;
      end if;
      Fert := Mean (C.Fe_A, C.Fe_B);
      if Fert < 1 then
         Fert := 1;
      elsif Fert > 3 then
         Fert := 3;
      end if;
      C.Speed := Speed;
      C.Sight := Sight;
      C.Metabolism := Meta;
      C.Fertility := Fert;
   end Express;

   function Side (Seed, Index : Natural) return Natural is
   begin
      return Mix (Seed, Index, 9, 1) mod 2;
   end Side;

   function Inherit_Side (Seed, Index : Natural) return Natural is
   begin
      return Side (Seed, Index);
   end Inherit_Side;

   function Allele_Of (Pair_A, Pair_B, Pick : Natural) return Natural is
   begin
      if Pick = 0 then
         return Pair_A;
      end if;
      return Pair_B;
   end Allele_Of;

   function Cross_Color
     (Mother, Father : Color_Pair; Seed, Index : Natural) return Color_Pair
   is
   begin
      return
        (Left  => Allele_Of (Mother.Left, Mother.Right, Side (Seed, Index * 2)),
         Right => Allele_Of (Father.Left, Father.Right, Side (Seed, Index * 2 + 1)));
   end Cross_Color;

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

   type Corner is record
      X : Coord;
      Y : Coord;
   end record;

   Corners : constant array (World.Group_Id) of Corner :=
     [1 => (X => 18, Y => 18),
      2 => (X => 78, Y => 18),
      3 => (X => 18, Y => 78),
      4 => (X => 78, Y => 78)];

   procedure Place_Adult
     (S : in out World.State; Who : World.Folk_Id; G : World.Group_Id; X, Y : Coord)
   is
   begin
      S.Folk (Who).Alive := True;
      S.Folk (Who).X := X;
      S.Folk (Who).Y := Y;
      S.Folk (Who).Facing := North;
      S.Folk (Who).Belly := (Full => 100, Empty_For => 0, Collapsed => False);
      S.Folk (Who).Age := 160;
      S.Folk (Who).Group := G;
      S.Folk (Who).Home := 0;
      S.Folk (Who).Sticks := 0;
      S.Folk (Who).Stones := 0;
      S.Folk (Who).Food := 0;
      S.Folk (Who).Cool := 0;
      S.Folk (Who).Sp_A := 1 + Mix (S.Pop_Seed, Who, 1, 0) mod 3;
      S.Folk (Who).Sp_B := S.Folk (Who).Sp_A;
      S.Folk (Who).Si_A := 1 + Mix (S.Pop_Seed, Who, 2, 0) mod 3;
      S.Folk (Who).Si_B := S.Folk (Who).Si_A;
      S.Folk (Who).Me_A := 2;
      S.Folk (Who).Me_B := 2;
      S.Folk (Who).Fe_A := 1 + Mix (S.Pop_Seed, Who, 3, 0) mod 3;
      S.Folk (Who).Fe_B := S.Folk (Who).Fe_A;
      S.Folk (Who).Col_A := Mix (S.Pop_Seed, Who, 5, 0) mod 2;
      S.Folk (Who).Col_B := Mix (S.Pop_Seed, Who, 6, 0) mod 2;
      Express (S.Folk (Who));
   end Place_Adult;

   function Dry (S : World.State; X, Y : Integer) return Boolean is
   begin
      return X in Coord and then Y in Coord
        and then Map.Walkable (Map.Terrain_At (S.Island_Seed, Coord (X), Coord (Y)));
   end Dry;

   function Camp_By_Water (S : World.State; G : World.Group_Id) return Corner is
      Base : constant Corner := Corners (G);
      P    : Map.Spot;
      NX, NY : Integer;
   begin
      for Step in 1 .. Map.River_Length (S.Island_Seed, G) loop
         P := Map.River_Step (S.Island_Seed, G, Step);
         if abs (Integer (P.X) - Integer (Base.X))
              + abs (Integer (P.Y) - Integer (Base.Y)) <= 28
         then
            for Dir in 1 .. 4 loop
               NX := Integer (P.X);
               NY := Integer (P.Y);
               case Dir is
                  when 1 =>
                     NY := NY - 1;
                  when 2 =>
                     NX := NX + 1;
                  when 3 =>
                     NY := NY + 1;
                  when others =>
                     NX := NX - 1;
               end case;
               if Dry (S, NX, NY) then
                  return (X => Coord (NX), Y => Coord (NY));
               end if;
            end loop;
         end if;
      end loop;
      return Base;
   end Camp_By_Water;

   function Hill_At (S : World.State; G : World.Group_Id) return Corner is
      Base : constant Corner := Corners (G);
      Best : Corner := Base;
      Best_H : Natural := 0;
      X, Y : Integer;
      H : Natural;
   begin
      for DY in 0 .. 10 loop
         for DX in -6 .. 6 loop
            X := Integer (Base.X) + DX;
            Y := Integer (Base.Y) + DY;
            if Dry (S, X, Y) then
               H := Map.Height (S.Island_Seed, Coord (X), Coord (Y));
               if H > Best_H then
                  Best_H := H;
                  Best := (X => Coord (X), Y => Coord (Y));
               end if;
            end if;
         end loop;
      end loop;
      return Best;
   end Hill_At;

   procedure Setup (S : in out World.State) is
      N : Positive := 1;
      C : Corner;
   begin
      S.Births := 0;
      S.Deaths := 0;
      S.Homes := [others => <>];
      S.Piles := [others => <>];
      S.Groups := [others => <>];
      S.Trust := [others => [others => 2]];
      S.Notes := [others => [others => <>]];
      S.Trails := [others => <>];
      S.Roads := [others => <>];
      S.Markets := [others => <>];
      S.Meetings := 0;
      for I in World.Folk_Id loop
         S.Folk (I) := (others => <>);
         S.Folk (I).Alive := False;
      end loop;
      S.Folk (World.Player_Id) :=
        (Alive => True,
         X => S.X, Y => S.Y, Facing => S.Facing,
         Belly => S.Belly,
         Age => 160,
         Speed => 1, Sight => 3, Metabolism => 1, Fertility => 2,
         Cool => 0, Group => 1, Home => 0, Sticks => 0, Stones => 0, Food => 0,
         Fish => 0, Scout => False, Migrate => 0,
         Sp_A => 1, Sp_B => 1, Si_A => 2, Si_B => 2,
         Me_A => 1, Me_B => 1, Fe_A => 2, Fe_B => 2,
         Col_A => 1, Col_B => 0, Thirst => 0);
      for G in World.Group_Id loop
         C := Camp_By_Water (S, G);
         S.Homes (G) :=
           (Used => True, Kind => World.Cave, Group => G,
            X => C.X, Y => C.Y, Capacity => World.Home_Capacity, others => <>);
         declare
            Hill : constant Corner := Hill_At (S, G);
            Stick_N : Natural;
            Stone_N : Natural;
         begin
            if G <= 2 then
               Stick_N := 12;
               Stone_N := 2;
            else
               Stick_N := 3;
               Stone_N := 14;
            end if;
            S.Piles (G) :=
              (Kind => World.Stick_Pile, X => C.X, Y => C.Y, Count => Stick_N);
            S.Piles (World.Group_Id'Last + G) :=
              (Kind => World.Stone_Pile, X => Hill.X, Y => Hill.Y, Count => Stone_N);
         end;
         Place_Adult (S, N + 1, G, C.X, C.Y);
         Place_Adult (S, N + 2, G, C.X, C.Y);
         Place_Adult (S, N + 3, G, C.X, C.Y);
         N := N + 3;
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

   function Pace (C : World.Folk_Rec) return Positive is
      N : Natural := C.Speed;
   begin
      if C.Metabolism = 1 then
         N := 1;
      elsif C.Metabolism = 2 and then N > 2 then
         N := 2;
      end if;
      return Positive (N);
   end Pace;

   function Trail_Of (S : World.State; X, Y : Coord) return Natural is
   begin
      for I in World.Trail_Id loop
         if S.Trails (I).Used
           and then S.Trails (I).X = X
           and then S.Trails (I).Y = Y
         then
            return S.Trails (I).Strength;
         end if;
      end loop;
      return 0;
   end Trail_Of;

   function Road_Here (S : World.State; X, Y : Coord) return Boolean is
   begin
      for I in World.Road_Id loop
         if S.Roads (I).Used
           and then S.Roads (I).X = X
           and then S.Roads (I).Y = Y
         then
            return True;
         end if;
      end loop;
      return False;
   end Road_Here;

   procedure Stamp (S : in out World.State; X, Y : Coord) is
   begin
      for I in World.Trail_Id loop
         if S.Trails (I).Used and then S.Trails (I).X = X and then S.Trails (I).Y = Y then
            if S.Trails (I).Strength < 20 then
               S.Trails (I).Strength := S.Trails (I).Strength + 2;
            end if;
            return;
         end if;
      end loop;
      for I in World.Trail_Id loop
         if not S.Trails (I).Used then
            S.Trails (I) := (Used => True, X => X, Y => Y, Strength => 2);
            return;
         end if;
      end loop;
   end Stamp;

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
      if N_Choice = 2 then
         declare
            AX, AY, BX, BY : Integer;
            SA, SB : Natural;
         begin
            AX := Integer (S.Folk (Who).X);
            AY := Integer (S.Folk (Who).Y);
            BX := AX;
            BY := AY;
            case Choice (1) is
               when North => AY := AY - 1;
               when East => AX := AX + 1;
               when South => AY := AY + 1;
               when West => AX := AX - 1;
            end case;
            case Choice (2) is
               when North => BY := BY - 1;
               when East => BX := BX + 1;
               when South => BY := BY + 1;
               when West => BX := BX - 1;
            end case;
            if AX in Coord and then AY in Coord
              and then BX in Coord and then BY in Coord
            then
               SA := Trail_Of (S, Coord (AX), Coord (AY));
               SB := Trail_Of (S, Coord (BX), Coord (BY));
               if SB > SA then
                  Dir := Choice (1);
                  Choice (1) := Choice (2);
                  Choice (2) := Dir;
               end if;
            end if;
         end;
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
           and then World.Standable (S, Coord (NX), Coord (NY))
           and then
             (World.Home_At (S, Coord (NX), Coord (NY)) /= 0
              or else not Occupied (S, Coord (NX), Coord (NY), Who))
           and then
             (Road_Here (S, Coord (NX), Coord (NY))
              or else not Map.Mountain (S.Island_Seed, Coord (NX), Coord (NY))
              or else (Who + S.Turn) mod 2 = 0)
         then
            declare
               Home : constant Corner := Corners (S.Folk (Who).Group);
               Old_D : constant Natural :=
                 Dist (S.Folk (Who).X, S.Folk (Who).Y, Home.X, Home.Y);
               New_D : constant Natural :=
                 Dist (Coord (NX), Coord (NY), Home.X, Home.Y);
               OX : constant Coord := S.Folk (Who).X;
               OY : constant Coord := S.Folk (Who).Y;
            begin
               if New_D < Old_D then
                  Stamp (S, OX, OY);
               end if;
               if Road_Here (S, Coord (NX), Coord (NY)) then
                  for R in World.Road_Id loop
                     if S.Roads (R).Used
                       and then S.Roads (R).X = Coord (NX)
                       and then S.Roads (R).Y = Coord (NY)
                       and then S.Roads (R).Life < 40
                     then
                        S.Roads (R).Life := S.Roads (R).Life + 2;
                     end if;
                  end loop;
               end if;
            end;
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
         Spot := Map.Bush (S.Island_Seed, I);
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
      if S.Folk (Who).Metabolism = 1 and then (Who + S.Turn) mod 2 = 1 then
         Try_Berry (S, Who);
         return;
      end if;
      for Step in 1 .. Pace (S.Folk (Who)) loop
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

   function Space_For (S : World.State; G : World.Group_Id) return Boolean is
   begin
      for H in World.Home_Id loop
         if S.Homes (H).Used
           and then S.Homes (H).Group = G
           and then World.Home_Residents (S, H) < S.Homes (H).Capacity
         then
            return True;
         end if;
      end loop;
      return False;
   end Space_For;

   function Needs_Food (S : World.State; G : World.Group_Id) return Boolean is
   begin
      for I in World.Folk_Id loop
         if S.Folk (I).Alive
           and then S.Folk (I).Group = G
           and then S.Folk (I).Age < World.Adult_Age
           and then S.Folk (I).Belly.Full < 55
         then
            return True;
         end if;
      end loop;
      return False;
   end Needs_Food;

   procedure Child_Home
     (S : World.State; G : World.Group_Id; X, Y : out Coord; Found : out Boolean)
   is
   begin
      Found := False;
      X := 0;
      Y := 0;
      for I in World.Folk_Id loop
         if S.Folk (I).Alive
           and then S.Folk (I).Group = G
           and then S.Folk (I).Age < World.Adult_Age
           and then S.Folk (I).Home in World.Home_Id
           and then S.Folk (I).Belly.Full < 55
         then
            X := S.Homes (S.Folk (I).Home).X;
            Y := S.Homes (S.Folk (I).Home).Y;
            Found := True;
            return;
         end if;
      end loop;
   end Child_Home;

   procedure Give_Food (S : in out World.State; Who : World.Folk_Id) is
      Here : Natural := World.Home_At (S, S.Folk (Who).X, S.Folk (Who).Y);
      Best : Integer := 0;
      Low  : Natural := 101;
   begin
      if Here = 0 then
         for H in World.Home_Id loop
            if S.Homes (H).Used
              and then S.Homes (H).Group = S.Folk (Who).Group
              and then abs (Integer (S.Homes (H).X) - Integer (S.Folk (Who).X)) <= 1
              and then abs (Integer (S.Homes (H).Y) - Integer (S.Folk (Who).Y)) <= 1
            then
               Here := H;
               exit;
            end if;
         end loop;
      end if;
      if S.Folk (Who).Food = 0 or else Here = 0 then
         return;
      end if;
      if S.Homes (Here).Group /= S.Folk (Who).Group then
         return;
      end if;
      for I in World.Folk_Id loop
         if S.Folk (I).Alive
           and then S.Folk (I).Home = Here
           and then S.Folk (I).Age < World.Adult_Age
           and then Natural (S.Folk (I).Belly.Full) < Low
         then
            Low := Natural (S.Folk (I).Belly.Full);
            Best := I;
         end if;
      end loop;
      if Best = 0 then
         return;
      end if;
      Stomach.Feed (S.Folk (Best).Belly, Map.Berry_Gain);
      S.Folk (Who).Food := 0;
   end Give_Food;

   procedure Take_Berry (S : in out World.State; Who : World.Folk_Id) is
      Spot : Map.Spot;
   begin
      if S.Folk (Who).Food >= S.Folk (Who).Metabolism then
         return;
      end if;
      for I in Map.Bush_Index loop
         Spot := Map.Bush (S.Island_Seed, I);
         if Bush_Ripe (S, I)
           and then abs (Integer (Spot.X) - Integer (S.Folk (Who).X)) <= 1
           and then abs (Integer (Spot.Y) - Integer (S.Folk (Who).Y)) <= 1
         then
            S.Folk (Who).Food := S.Folk (Who).Food + 1;
            World.Mark_Bush (S, Spot.X, Spot.Y);
            for Other in World.Folk_Id loop
               if S.Folk (Other).Alive
                 and then S.Folk (Other).Group /= S.Folk (Who).Group
                 and then abs (Integer (S.Folk (Other).X) - Integer (Spot.X)) <= 1
                 and then abs (Integer (S.Folk (Other).Y) - Integer (Spot.Y)) <= 1
               then
                  if S.Trust (S.Folk (Who).Group) (S.Folk (Other).Group) > 0 then
                     S.Trust (S.Folk (Who).Group) (S.Folk (Other).Group) :=
                       S.Trust (S.Folk (Who).Group) (S.Folk (Other).Group) - 1;
                  end if;
               end if;
            end loop;
            return;
         end if;
      end loop;
   end Take_Berry;

   procedure Take_Pile (S : in out World.State; Who : World.Folk_Id) is
   begin
      for I in World.Pile_Id loop
         if S.Piles (I).Count > 0
           and then S.Piles (I).X = S.Folk (Who).X
           and then S.Piles (I).Y = S.Folk (Who).Y
         then
            if S.Piles (I).Kind = World.Stick_Pile and then S.Folk (Who).Sticks < 8 then
               S.Folk (Who).Sticks := S.Folk (Who).Sticks + 1;
               S.Piles (I).Count := S.Piles (I).Count - 1;
               return;
            elsif S.Piles (I).Kind = World.Stone_Pile and then S.Folk (Who).Stones < 6 then
               S.Folk (Who).Stones := S.Folk (Who).Stones + 1;
               S.Piles (I).Count := S.Piles (I).Count - 1;
               return;
            end if;
         end if;
      end loop;
   end Take_Pile;

   procedure Build_Hut (S : in out World.State; Who : World.Folk_Id; Built : out Boolean) is
   begin
      Built := False;
      if S.Folk (Who).Sticks < 5 or else S.Folk (Who).Stones < 3 then
         return;
      end if;
      if World.Home_At (S, S.Folk (Who).X, S.Folk (Who).Y) /= 0 then
         return;
      end if;
      if not Map.Walkable (Map.Terrain_At (S.Island_Seed, S.Folk (Who).X, S.Folk (Who).Y)) then
         return;
      end if;
      for H in World.Home_Id loop
         if not S.Homes (H).Used then
            S.Homes (H) :=
              (Used => True, Kind => World.Hut, Group => S.Folk (Who).Group,
               X => S.Folk (Who).X, Y => S.Folk (Who).Y,
               Capacity => World.Home_Capacity, others => <>);
            S.Folk (Who).Sticks := S.Folk (Who).Sticks - 5;
            S.Folk (Who).Stones := S.Folk (Who).Stones - 3;
            Built := True;
            return;
         end if;
      end loop;
   end Build_Hut;

   procedure Remember
     (S : in out World.State; G : World.Group_Id; Kind : World.Note_Kind; X, Y : Coord)
   is
   begin
      for I in World.Note_Id loop
         if S.Notes (G) (I).Known
           and then S.Notes (G) (I).X = X
           and then S.Notes (G) (I).Y = Y
         then
            return;
         end if;
      end loop;
      for I in World.Note_Id loop
         if not S.Notes (G) (I).Known then
            S.Notes (G) (I) := (Known => True, Kind => Kind, X => X, Y => Y);
            return;
         end if;
      end loop;
   end Remember;

   procedure Note_Seen (S : in out World.State; Who : World.Folk_Id) is
      G : constant World.Group_Id := S.Folk (Who).Group;
      Spot : Map.Spot;
   begin
      for B in Map.Bush_Index loop
         Spot := Map.Bush (S.Island_Seed, B);
         if In_Sight (S.Folk (Who), Spot.X, Spot.Y) then
            Remember (S, G, World.Note_Food, Spot.X, Spot.Y);
         end if;
      end loop;
      for H in World.Home_Id loop
         if S.Homes (H).Used
           and then S.Homes (H).Group /= G
           and then In_Sight (S.Folk (Who), S.Homes (H).X, S.Homes (H).Y)
         then
            Remember (S, G, World.Note_Home, S.Homes (H).X, S.Homes (H).Y);
         end if;
      end loop;
      for P in World.Pile_Id loop
         if S.Piles (P).Count > 0
           and then In_Sight (S.Folk (Who), S.Piles (P).X, S.Piles (P).Y)
         then
            if S.Piles (P).Kind = World.Stick_Pile then
               Remember (S, G, World.Note_Stick, S.Piles (P).X, S.Piles (P).Y);
            else
               Remember (S, G, World.Note_Stone, S.Piles (P).X, S.Piles (P).Y);
            end if;
         end if;
      end loop;
   end Note_Seen;

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
            if S.Folk (Who).Age < World.Adult_Age then
               goto Next_Folk;
            end if;
            Found := False;
            if S.Folk (Who).Sight = 4
              and then not Needs_Food (S, S.Folk (Who).Group)
              and then S.Folk (Who).Belly.Full > 50
              and then (Who + S.Turn) mod 40 = 0
            then
               S.Folk (Who).Scout := True;
               if S.Folk (Who).Group <= 2 and then S.Folk (Who).Sticks = 0 then
                  S.Folk (Who).Sticks := 1;
               elsif S.Folk (Who).Group > 2 and then S.Folk (Who).Stones = 0 then
                  S.Folk (Who).Stones := 1;
               end if;
            end if;
            if S.Folk (Who).Migrate in World.Group_Id then
               Best_X := Corners (S.Folk (Who).Migrate).X;
               Best_Y := Corners (S.Folk (Who).Migrate).Y;
               Found := True;
               if abs (Integer (S.Folk (Who).X) - Integer (Best_X)) <= 1
                 and then abs (Integer (S.Folk (Who).Y) - Integer (Best_Y)) <= 1
                 and then World.Group_Population (S, S.Folk (Who).Group) > 2
               then
                  declare
                     Origin : constant World.Group_Id := S.Folk (Who).Group;
                     Dest   : constant World.Group_Id := S.Folk (Who).Migrate;
                  begin
                     S.Groups (Origin).Migrants_Out :=
                       S.Groups (Origin).Migrants_Out + 1;
                     S.Groups (Dest).Migrants_In := S.Groups (Dest).Migrants_In + 1;
                     S.Groups (Dest).Came_From (Origin) :=
                       S.Groups (Dest).Came_From (Origin) + 1;
                     S.Folk (Who).Group := Dest;
                     S.Folk (Who).Migrate := 0;
                  end;
               end if;
            elsif S.Folk (Who).Scout then
               Note_Seen (S, Who);
               declare
                  Which : constant Map.River_Index := S.Folk (Who).Group;
                  Len   : constant Natural :=
                    Map.River_Length (S.Island_Seed, Which);
                  Near  : Natural := Natural'Last;
                  Here  : Natural := 1;
                  Spot  : Map.Spot;
                  Ds    : Natural;
               begin
                  for Step in 1 .. Len loop
                     Spot := Map.River_Step (S.Island_Seed, Which, Step);
                     Ds := Dist (S.Folk (Who).X, S.Folk (Who).Y, Spot.X, Spot.Y);
                     if Ds < Near then
                        Near := Ds;
                        Here := Step;
                     end if;
                  end loop;
                  if Here < Len then
                     Spot := Map.River_Step (S.Island_Seed, Which, Here + 1);
                     Best_X := Spot.X;
                     Best_Y := Spot.Y;
                     Found := True;
                  else
                     S.Folk (Who).Scout := False;
                  end if;
               end;
            end if;
            if Found then
               Seek (S, Who, Best_X, Best_Y);
               goto Next_Folk;
            end if;
            Found := False;
            Give_Food (S, Who);
            Take_Pile (S, Who);
            Hungry :=
              S.Folk (Who).Belly.Full < 45
              or else Stomach.Status (S.Folk (Who).Belly) = Stomach.Hungry
              or else Stomach.Status (S.Folk (Who).Belly) = Stomach.Weak;
            Found := False;
            Best := Natural'Last;
            Best_X := S.Folk (Who).X;
            Best_Y := S.Folk (Who).Y;
            if S.Folk (Who).Food > 0 and then Needs_Food (S, S.Folk (Who).Group) then
               declare
                  HX, HY : Coord;
                  Have   : Boolean;
               begin
                  Child_Home (S, S.Folk (Who).Group, HX, HY, Have);
                  if Have then
                     Best_X := HX;
                     Best_Y := HY;
                     Found := True;
                  end if;
               end;
            elsif Needs_Food (S, S.Folk (Who).Group)
              and then S.Folk (Who).Belly.Full >= 30
            then
               Take_Berry (S, Who);
               for B in Map.Bush_Index loop
                  if Bush_Ripe (S, B)
                    and then Dist
                      (S.Folk (Who).X, S.Folk (Who).Y,
                       Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y) <= 16
                  then
                     D := Dist
                       (S.Folk (Who).X, S.Folk (Who).Y,
                        Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y);
                     if D < Best then
                        Best := D;
                        Best_X := Map.Bush (S.Island_Seed, B).X;
                        Best_Y := Map.Bush (S.Island_Seed, B).Y;
                        Found := True;
                     end if;
                  end if;
               end loop;
            elsif not Space_For (S, S.Folk (Who).Group) then
               declare
                  Did : Boolean;
               begin
                  if S.Folk (Who).Sticks >= 5 and then S.Folk (Who).Stones >= 3 then
                     Build_Hut (S, Who, Did);
                  end if;
               end;
               for P in World.Pile_Id loop
                  if S.Piles (P).Count > 0
                    and then
                      ((S.Folk (Who).Sticks < 5 and then S.Piles (P).Kind = World.Stick_Pile)
                       or else
                         (S.Folk (Who).Sticks >= 5
                          and then S.Folk (Who).Stones < 3
                          and then S.Piles (P).Kind = World.Stone_Pile))
                    and then abs (Integer (S.Piles (P).X) - Integer (Corners (S.Folk (Who).Group).X)) < 20
                  then
                     Best_X := S.Piles (P).X;
                     Best_Y := S.Piles (P).Y;
                     Found := True;
                     exit;
                  end if;
               end loop;
            elsif Hungry then
               for B in Map.Bush_Index loop
                  if Bush_Ripe (S, B)
                    and then In_Sight
                      (S.Folk (Who), Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y)
                  then
                     D := Dist
                       (S.Folk (Who).X, S.Folk (Who).Y,
                        Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y);
                     if D < Best then
                        Best := D;
                        Best_X := Map.Bush (S.Island_Seed, B).X;
                        Best_Y := Map.Bush (S.Island_Seed, B).Y;
                        Found := True;
                     end if;
                  end if;
               end loop;
            elsif S.Folk (Who).Age >= World.Adult_Age
              and then S.Folk (Who).Belly.Full > 70
              and then S.Folk (Who).Cool = 0
              and then Space_For (S, S.Folk (Who).Group)
            then
               for Other in World.Folk_Id loop
                  if Other /= Who and then S.Folk (Other).Alive
                    and then S.Folk (Other).Group = S.Folk (Who).Group
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
                    (S.Folk (Who), Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y)
                    and then
                      (Map.Bush (S.Island_Seed, B).X /= S.Folk (Who).X
                       or else Map.Bush (S.Island_Seed, B).Y /= S.Folk (Who).Y)
                  then
                     D := Dist
                       (S.Folk (Who).X, S.Folk (Who).Y,
                        Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y);
                     if D < Best then
                        Best := D;
                        Best_X := Map.Bush (S.Island_Seed, B).X;
                        Best_Y := Map.Bush (S.Island_Seed, B).Y;
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
            <<Next_Folk>>
         end if;
      end loop;
   end Others_Act;

   function Free_Home (S : World.State; G : World.Group_Id) return Natural is
   begin
      for H in World.Home_Id loop
         if S.Homes (H).Used
           and then S.Homes (H).Group = G
           and then World.Home_Residents (S, H) < S.Homes (H).Capacity
         then
            return H;
         end if;
      end loop;
      return 0;
   end Free_Home;

   procedure Birth_One
     (S : in out World.State; A, B : World.Folk_Id; Slot : World.Folk_Id)
   is
      Home : constant Natural := Free_Home (S, S.Folk (A).Group);
   begin
      if Home = 0 then
         return;
      end if;
      if S.Folk (A).Group /= S.Folk (B).Group
        and then (S.Trust (S.Folk (A).Group) (S.Folk (B).Group) < 6
                  or else S.Trust (S.Folk (B).Group) (S.Folk (A).Group) < 6)
      then
         return;
      end if;
      S.Folk (Slot).Alive := True;
      S.Folk (Slot).X := S.Homes (Home).X;
      S.Folk (Slot).Y := S.Homes (Home).Y;
      S.Folk (Slot).Facing := North;
      S.Folk (Slot).Age := 0;
      S.Folk (Slot).Cool := 12;
      S.Folk (Slot).Home := Home;
      S.Folk (Slot).Group := S.Folk (A).Group;
      S.Folk (Slot).Sticks := 0;
      S.Folk (Slot).Stones := 0;
      S.Folk (Slot).Food := 0;
      S.Folk (Slot).Fish := 0;
      S.Folk (Slot).Scout := False;
      S.Folk (Slot).Migrate := 0;
      S.Folk (Slot).Belly := (Full => 60, Empty_For => 0, Collapsed => False);
      declare
         N : constant Natural := S.Turn + A * 30 + B;
      begin
         S.Folk (Slot).Sp_A :=
           Allele_Of (S.Folk (A).Sp_A, S.Folk (A).Sp_B, Side (S.Pop_Seed, N));
         S.Folk (Slot).Sp_B :=
           Allele_Of (S.Folk (B).Sp_A, S.Folk (B).Sp_B, Side (S.Pop_Seed, N + 1));
         S.Folk (Slot).Si_A :=
           Allele_Of (S.Folk (A).Si_A, S.Folk (A).Si_B, Side (S.Pop_Seed, N + 2));
         S.Folk (Slot).Si_B :=
           Allele_Of (S.Folk (B).Si_A, S.Folk (B).Si_B, Side (S.Pop_Seed, N + 3));
         S.Folk (Slot).Me_A :=
           Allele_Of (S.Folk (A).Me_A, S.Folk (A).Me_B, Side (S.Pop_Seed, N + 4));
         S.Folk (Slot).Me_B :=
           Allele_Of (S.Folk (B).Me_A, S.Folk (B).Me_B, Side (S.Pop_Seed, N + 5));
         S.Folk (Slot).Fe_A :=
           Allele_Of (S.Folk (A).Fe_A, S.Folk (A).Fe_B, Side (S.Pop_Seed, N + 6));
         S.Folk (Slot).Fe_B :=
           Allele_Of (S.Folk (B).Fe_A, S.Folk (B).Fe_B, Side (S.Pop_Seed, N + 7));
         S.Folk (Slot).Col_A :=
           Allele_Of (S.Folk (A).Col_A, S.Folk (A).Col_B, Side (S.Pop_Seed, N + 8));
         S.Folk (Slot).Col_B :=
           Allele_Of (S.Folk (B).Col_A, S.Folk (B).Col_B, Side (S.Pop_Seed, N + 9));
         if Mix (S.Pop_Seed, N, 8, 2) mod 32 = 0 then
            S.Folk (Slot).Sp_A := 1 + (S.Folk (Slot).Sp_A mod 3);
         end if;
      end;
      Express (S.Folk (Slot));
      S.Folk (A).Belly.Full :=
        Stomach.Fullness (Natural (S.Folk (A).Belly.Full) - 30);
      S.Folk (B).Belly.Full :=
        Stomach.Fullness (Natural (S.Folk (B).Belly.Full) - 30);
      S.Folk (A).Cool := 4 * (4 - Natural (S.Folk (A).Fertility));
      S.Folk (B).Cool := 4 * (4 - Natural (S.Folk (B).Fertility));
      S.Births := S.Births + 1;
      S.Groups (S.Folk (A).Group).Births :=
        S.Groups (S.Folk (A).Group).Births + 1;
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

   procedure Raise_Trust (S : in out World.State; A, B : World.Group_Id) is
   begin
      if A = B then
         return;
      end if;
      if S.Trust (A) (B) < World.Trust_Max then
         S.Trust (A) (B) := S.Trust (A) (B) + 1;
      end if;
      if S.Trust (B) (A) < World.Trust_Max then
         S.Trust (B) (A) := S.Trust (B) (A) + 1;
      end if;
   end Raise_Trust;

   procedure Swap_Goods (S : in out World.State; A, B : World.Folk_Id) is
   begin
      if S.Folk (A).Sticks >= 2 and then S.Folk (B).Food >= 1
        and then S.Folk (A).Food = 0
      then
         S.Folk (A).Sticks := S.Folk (A).Sticks - 1;
         S.Folk (B).Sticks := S.Folk (B).Sticks + 1;
         S.Folk (B).Food := S.Folk (B).Food - 1;
         S.Folk (A).Food := 1;
      elsif S.Folk (A).Stones >= 2 and then S.Folk (B).Food >= 1
        and then S.Folk (A).Food = 0
      then
         S.Folk (A).Stones := S.Folk (A).Stones - 1;
         S.Folk (B).Stones := S.Folk (B).Stones + 1;
         S.Folk (B).Food := S.Folk (B).Food - 1;
         S.Folk (A).Food := 1;
      elsif S.Folk (B).Sticks >= 2 and then S.Folk (A).Food >= 1
        and then S.Folk (B).Food = 0
      then
         S.Folk (B).Sticks := S.Folk (B).Sticks - 1;
         S.Folk (A).Sticks := S.Folk (A).Sticks + 1;
         S.Folk (A).Food := S.Folk (A).Food - 1;
         S.Folk (B).Food := 1;
      elsif S.Folk (A).Sticks >= 1 and then S.Folk (B).Stones >= 1
        and then S.Folk (A).Stones = 0 and then S.Folk (B).Sticks = 0
      then
         S.Folk (A).Sticks := S.Folk (A).Sticks - 1;
         S.Folk (B).Sticks := S.Folk (B).Sticks + 1;
         S.Folk (B).Stones := S.Folk (B).Stones - 1;
         S.Folk (A).Stones := S.Folk (A).Stones + 1;
      elsif S.Folk (B).Stones >= 2 and then S.Folk (A).Fish >= 1
        and then S.Folk (B).Fish = 0
      then
         S.Folk (B).Stones := S.Folk (B).Stones - 1;
         S.Folk (A).Stones := S.Folk (A).Stones + 1;
         S.Folk (A).Fish := S.Folk (A).Fish - 1;
         S.Folk (B).Fish := 1;
      else
         return;
      end if;
      Raise_Trust (S, S.Folk (A).Group, S.Folk (B).Group);
      S.Groups (S.Folk (A).Group).Trades := S.Groups (S.Folk (A).Group).Trades + 1;
      S.Groups (S.Folk (B).Group).Trades := S.Groups (S.Folk (B).Group).Trades + 1;
   end Swap_Goods;

   procedure Meetings (S : in out World.State) is
   begin
      for A in World.Folk_Id loop
         if S.Folk (A).Alive and then S.Folk (A).Age >= World.Adult_Age then
            for B in World.Folk_Id loop
               if B > A and then S.Folk (B).Alive
                 and then S.Folk (B).Group /= S.Folk (A).Group
                 and then Adjacent (S.Folk (A), S.Folk (B))
               then
                  Swap_Goods (S, A, B);
                  S.Meetings := S.Meetings + 1;
               end if;
            end loop;
         end if;
      end loop;
   end Meetings;

   procedure Choose_Migrants (S : in out World.State) is
   begin
      for Who in World.Folk_Id loop
         if S.Folk (Who).Alive
           and then S.Folk (Who).Age >= World.Adult_Age
           and then S.Folk (Who).Migrate = 0
           and then (Who + S.Turn) mod 90 = 0
           and then World.Group_Population (S, S.Folk (Who).Group) > 2
           and then
             (World.Group_Population (S, S.Folk (Who).Group) < 4
              or else not Space_For (S, S.Folk (Who).Group))
         then
            for G in World.Group_Id loop
               if G /= S.Folk (Who).Group
                 and then S.Trust (S.Folk (Who).Group) (G) >= 6
                 and then Space_For (S, G)
                 and then World.Group_Population (S, G) >= 4
               then
                  S.Folk (Who).Migrate := G;
                  exit;
               end if;
            end loop;
         end if;
      end loop;
   end Choose_Migrants;

   procedure Decay_Paths (S : in out World.State) is
   begin
      for I in World.Trail_Id loop
         if S.Trails (I).Used then
            if S.Trails (I).Strength <= 1 then
               S.Trails (I).Used := False;
               S.Trails (I).Strength := 0;
            else
               S.Trails (I).Strength := S.Trails (I).Strength - 1;
            end if;
         end if;
      end loop;
      for I in World.Road_Id loop
         if S.Roads (I).Used then
            if S.Roads (I).Life <= 1 then
               S.Roads (I).Used := False;
            else
               S.Roads (I).Life := S.Roads (I).Life - 1;
            end if;
         end if;
      end loop;
   end Decay_Paths;

   procedure Pave (S : in out World.State) is
   begin
      for T in World.Trail_Id loop
         if S.Trails (T).Used and then S.Trails (T).Strength >= 8 then
            for R in World.Road_Id loop
               if not S.Roads (R).Used then
                  S.Roads (R) :=
                    (Used => True, X => S.Trails (T).X, Y => S.Trails (T).Y, Life => 24);
                  S.Trails (T).Strength := 4;
                  exit;
               elsif S.Roads (R).X = S.Trails (T).X
                 and then S.Roads (R).Y = S.Trails (T).Y
               then
                  exit;
               end if;
            end loop;
         end if;
      end loop;
   end Pave;

   procedure Open_Markets (S : in out World.State) is
      Cross, Side, Down : Boolean;
   begin
      for A in World.Trail_Id loop
         if S.Trails (A).Used and then S.Trails (A).Strength >= 4 then
            Side := False;
            Down := False;
            for B in World.Trail_Id loop
               if B /= A and then S.Trails (B).Used and then S.Trails (B).Strength >= 4
                 and then abs (Integer (S.Trails (A).X) - Integer (S.Trails (B).X))
                   + abs (Integer (S.Trails (A).Y) - Integer (S.Trails (B).Y)) = 1
               then
                  if S.Trails (A).Y = S.Trails (B).Y then
                     Side := True;
                  else
                     Down := True;
                  end if;
               end if;
            end loop;
            Cross := Side and then Down;
            if Cross then
               for M in World.Market_Id loop
                  if S.Markets (M).Used
                    and then S.Markets (M).X = S.Trails (A).X
                    and then S.Markets (M).Y = S.Trails (A).Y
                  then
                     Cross := False;
                     exit;
                  elsif not S.Markets (M).Used then
                     S.Markets (M) :=
                       (Used => True, X => S.Trails (A).X, Y => S.Trails (A).Y,
                        others => <>);
                     exit;
                  end if;
               end loop;
            end if;
         end if;
      end loop;
   end Open_Markets;

   procedure Shop (S : in out World.State; Who : World.Folk_Id; Did : out Boolean) is
   begin
      Did := False;
      for M in World.Market_Id loop
         if S.Markets (M).Used
           and then abs (Integer (S.Markets (M).X) - Integer (S.Folk (Who).X)) <= 1
           and then abs (Integer (S.Markets (M).Y) - Integer (S.Folk (Who).Y)) <= 1
         then
            if S.Folk (Who).Sticks >= 1 and then S.Folk (Who).Stones = 0
              and then S.Markets (M).Stones >= 1
            then
               S.Folk (Who).Sticks := S.Folk (Who).Sticks - 1;
               S.Markets (M).Sticks := S.Markets (M).Sticks + 1;
               S.Markets (M).Stones := S.Markets (M).Stones - 1;
               S.Folk (Who).Stones := S.Folk (Who).Stones + 1;
               Did := True;
            elsif S.Folk (Who).Food >= 1 and then S.Folk (Who).Sticks = 0
              and then S.Markets (M).Sticks >= 1
            then
               S.Folk (Who).Food := S.Folk (Who).Food - 1;
               S.Markets (M).Berries := S.Markets (M).Berries + 1;
               S.Markets (M).Sticks := S.Markets (M).Sticks - 1;
               S.Folk (Who).Sticks := 1;
               Did := True;
            elsif S.Folk (Who).Sticks >= 1 and then S.Markets (M).Sticks < 4 then
               S.Folk (Who).Sticks := S.Folk (Who).Sticks - 1;
               S.Markets (M).Sticks := S.Markets (M).Sticks + 1;
               Did := True;
            end if;
            if Did then
               S.Markets (M).Trades := S.Markets (M).Trades + 1;
               S.Groups (S.Folk (Who).Group).Trades :=
                 S.Groups (S.Folk (Who).Group).Trades + 1;
               if S.Markets (M).Trades = 4 then
                  for H in World.Home_Id loop
                     if not S.Homes (H).Used then
                        S.Homes (H) :=
                          (Used => True, Kind => World.Hut,
                           Group => S.Folk (Who).Group,
                           X => S.Markets (M).X, Y => S.Markets (M).Y,
                           Capacity => World.Home_Capacity, others => <>);
                        exit;
                     end if;
                  end loop;
               end if;
               return;
            end if;
         end if;
      end loop;
   end Shop;

   procedure Market_Deal
     (S : in out World.State; Who : World.Folk_Id; Did : out Boolean)
   is
   begin
      if not S.Markets (1).Used then
         S.Markets (1) :=
           (Used => True, X => S.Folk (Who).X, Y => S.Folk (Who).Y,
            Stones => 1, others => <>);
      end if;
      Shop (S, Who, Did);
   end Market_Deal;

   procedure Leave_Scent (S : in out World.State; X, Y : Coord) is
   begin
      Stamp (S, X, Y);
   end Leave_Scent;

   function Scent (S : World.State; X, Y : Coord) return Natural is
   begin
      return Trail_Of (S, X, Y);
   end Scent;

   procedure After_Actions (S : in out World.State; Turns : Positive) is
      Slot : Integer;
      Bred : array (World.Folk_Id) of Boolean := [others => False];
   begin
      for Who in World.Folk_Id loop
         if Who /= World.Player_Id and then S.Folk (Who).Alive
           and then not S.Folk (Who).Belly.Collapsed
         then
            Stomach.Tick
              (S.Folk (Who).Belly, 1, False,
               (if S.Folk (Who).Metabolism = 3 then 2 else 1));
         end if;
      end loop;
      for Who in World.Folk_Id loop
         if S.Folk (Who).Alive then
            S.Folk (Who).Age := S.Folk (Who).Age + Natural (Turns);
            if S.Folk (Who).Age >= World.Adult_Age then
               S.Folk (Who).Home := 0;
            end if;
            if S.Folk (Who).Thirst < 100 then
               S.Folk (Who).Thirst := S.Folk (Who).Thirst + 1;
            end if;
            if Map.Drinkable (S.Island_Seed, S.Folk (Who).X, S.Folk (Who).Y) then
               S.Folk (Who).Thirst := 0;
            elsif S.Folk (Who).Thirst >= 100
              and then S.Folk (Who).Belly.Full > 0
            then
               S.Folk (Who).Belly.Full := S.Folk (Who).Belly.Full - 1;
            end if;
            if S.Folk (Who).Cool > 0 then
               if S.Folk (Who).Cool > Natural (Turns) then
                  S.Folk (Who).Cool := S.Folk (Who).Cool - Natural (Turns);
               else
                  S.Folk (Who).Cool := 0;
               end if;
            end if;
         end if;
      end loop;
      Decay_Paths (S);
      Pave (S);
      Open_Markets (S);
      declare
         Did : Boolean;
      begin
         for Who in World.Folk_Id loop
            if S.Folk (Who).Alive then
               Shop (S, Who, Did);
            end if;
         end loop;
      end;
      Meetings (S);
      for A in World.Folk_Id loop
         if S.Folk (A).Alive and then not Bred (A)
           and then S.Folk (A).Age >= World.Adult_Age
           and then S.Folk (A).Belly.Full > 70
           and then S.Folk (A).Cool = 0
           and then not S.Folk (A).Belly.Collapsed
         then
            for B in World.Folk_Id loop
               if B > A and then S.Folk (B).Alive and then not Bred (B)
                 and then
                   (S.Folk (B).Group = S.Folk (A).Group
                    or else (S.Trust (S.Folk (A).Group) (S.Folk (B).Group) >= 6
                             and then S.Trust (S.Folk (B).Group) (S.Folk (A).Group) >= 6))
                 and then S.Folk (B).Age >= World.Adult_Age
                 and then S.Folk (B).Belly.Full > 70
                 and then S.Folk (B).Cool = 0
                 and then Adjacent (S.Folk (A), S.Folk (B))
                 and then Space_For (S, S.Folk (A).Group)
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
      Choose_Migrants (S);
      for Who in World.Folk_Id loop
         if S.Folk (Who).Alive
           and then (S.Folk (Who).Belly.Collapsed
                     or else S.Folk (Who).Age >= World.Max_Age)
         then
            declare
               G     : constant World.Group_Id := S.Folk (Who).Group;
               Cause : Natural := 2;
            begin
               if S.Folk (Who).Belly.Collapsed then
                  Cause := 1;
               elsif not Space_For (S, G) then
                  Cause := 3;
               end if;
               S.Folk (Who).Alive := False;
               S.Deaths := S.Deaths + 1;
               S.Groups (G).Deaths := S.Groups (G).Deaths + 1;
               if World.Group_Population (S, G) = 0
                 and then S.Groups (G).Extinct_Turn = 0
               then
                  S.Groups (G).Extinct_Turn := S.Turn;
                  S.Groups (G).Extinct_Cause := Cause;
               end if;
            end;
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
              and then In_Sight (S.Folk (Who), Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y)
            then
               D := Dist (S.X, S.Y, Map.Bush (S.Island_Seed, B).X, Map.Bush (S.Island_Seed, B).Y);
               if D < Best then
                  Best := D;
                  Best_X := Map.Bush (S.Island_Seed, B).X;
                  Best_Y := Map.Bush (S.Island_Seed, B).Y;
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

   procedure Sync_Player (S : in out World.State) is
   begin
      S.Folk (World.Player_Id).X := S.X;
      S.Folk (World.Player_Id).Y := S.Y;
      S.Folk (World.Player_Id).Facing := S.Facing;
      S.Folk (World.Player_Id).Belly := S.Belly;
   end Sync_Player;

   procedure Player_Gather (S : in out World.State; Result : out Natural) is
      Who : constant World.Folk_Id := World.Player_Id;
   begin
      Sync_Player (S);
      Result := 0;
      for I in World.Pile_Id loop
         if S.Piles (I).Count > 0
           and then S.Piles (I).X = S.Folk (Who).X
           and then S.Piles (I).Y = S.Folk (Who).Y
         then
            if S.Piles (I).Kind = World.Stick_Pile and then S.Folk (Who).Sticks < 8 then
               S.Folk (Who).Sticks := S.Folk (Who).Sticks + 1;
               S.Piles (I).Count := S.Piles (I).Count - 1;
               Result := 1;
               return;
            elsif S.Piles (I).Kind = World.Stone_Pile and then S.Folk (Who).Stones < 6 then
               S.Folk (Who).Stones := S.Folk (Who).Stones + 1;
               S.Piles (I).Count := S.Piles (I).Count - 1;
               Result := 2;
               return;
            end if;
         end if;
      end loop;
      if S.Folk (Who).Food = 0 then
         Take_Berry (S, Who);
         if S.Folk (Who).Food = 1 then
            Result := 3;
         end if;
      end if;
   end Player_Gather;

   procedure Player_Build (S : in out World.State; Result : out Natural) is
      Who : constant World.Folk_Id := World.Player_Id;
      Did : Boolean;
   begin
      Sync_Player (S);
      if S.Folk (Who).Sticks < 5 or else S.Folk (Who).Stones < 3 then
         Result := 2;
         return;
      end if;
      Build_Hut (S, Who, Did);
      if Did then
         Result := 1;
      else
         Result := 3;
      end if;
   end Player_Build;

   procedure Player_Feed (S : in out World.State; Result : out Natural) is
      Who  : constant World.Folk_Id := World.Player_Id;
      Full : Natural;
   begin
      Sync_Player (S);
      if S.Folk (Who).Food = 0 then
         Result := 2;
         return;
      end if;
      Full := 0;
      for I in World.Folk_Id loop
         if S.Folk (I).Alive
           and then S.Folk (I).Home /= 0
           and then S.Folk (I).Age < World.Adult_Age
           and then S.Homes (S.Folk (I).Home).X = S.Folk (Who).X
           and then S.Homes (S.Folk (I).Home).Y = S.Folk (Who).Y
         then
            Full := Natural (S.Folk (I).Belly.Full);
            exit;
         end if;
      end loop;
      if Full = 0 and then World.Home_At (S, S.Folk (Who).X, S.Folk (Who).Y) = 0 then
         Result := 3;
         return;
      end if;
      Give_Food (S, Who);
      if S.Folk (Who).Food = 0 then
         Result := 1;
      else
         Result := 3;
      end if;
   end Player_Feed;

   procedure Player_Trade (S : in out World.State; Result : out Natural) is
      Who : constant World.Folk_Id := World.Player_Id;
      Before : Natural;
   begin
      Sync_Player (S);
      Result := 2;
      Before := S.Groups (S.Folk (Who).Group).Trades;
      for Other in World.Folk_Id loop
         if Other /= Who and then S.Folk (Other).Alive
           and then S.Folk (Other).Group /= S.Folk (Who).Group
           and then Adjacent (S.Folk (Who), S.Folk (Other))
         then
            Swap_Goods (S, Who, Other);
            if S.Groups (S.Folk (Who).Group).Trades > Before then
               Result := 1;
            else
               Result := 3;
            end if;
            return;
         end if;
      end loop;
   end Player_Trade;

begin
   null;
end Island.Folk;
