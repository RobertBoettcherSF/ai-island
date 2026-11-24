with Interfaces;

package body Island.Map is

   type Spot_List is array (Bush_Index) of Spot;
   type Fish_List is array (Fish_Index) of Spot;
   type Home_List is array (Npc_Index) of Spot;
   type Grove_List is array (Grove_Index) of Spot;

   type Layout is record
      Bushes : Spot_List;
      Fish   : Fish_List;
      Homes  : Home_List;
   end record;

   Have_Cache  : Boolean := False;
   Cached_Seed : Seed_Value := Default_Island_Seed;
   Cached      : Layout;

   function Hash (Seed : Seed_Value; X, Y : Coord) return Natural is
      use Interfaces;
      H : Unsigned_32 := Unsigned_32 (Seed) xor 16#9E37_79B9#;
   begin
      H := H xor Unsigned_32 (X) * 16#85EB_CA6B#;
      H := H xor Shift_Right (H, 13);
      H := H xor Unsigned_32 (Y) * 16#C2B2_AE35#;
      H := H xor Shift_Right (H, 16);
      return Natural (H mod 1024);
   end Hash;

   function Mix (Seed : Seed_Value; A, B : Natural) return Interfaces.Unsigned_32 is
      use Interfaces;
      H : Unsigned_32 := Unsigned_32 (Seed) xor 16#A5A5_A5A5#;
   begin
      H := H xor Unsigned_32 (A) * 16#9E37_79B9#;
      H := H xor Shift_Right (H, 13);
      H := H xor Unsigned_32 (B) * 16#85EB_CA6B#;
      H := H xor Shift_Right (H, 16);
      return H;
   end Mix;

   function In_Lake (X, Y : Coord) return Boolean is
      DX : constant Integer := Integer (X) - 70;
      DY : constant Integer := Integer (Y) - 62;
      --  (dx/14)^2 + (dy/9)^2 < 1, in integers.
   begin
      return DX * DX * 81 + DY * DY * 196 < 196 * 81;
   end In_Lake;

   function Lake_Shore (X, Y : Coord) return Boolean is
      DX : constant Integer := Integer (X) - 70;
      DY : constant Integer := Integer (Y) - 62;
      Band : constant Integer := DX * DX * 81 + DY * DY * 196;
   begin
      return Band >= 196 * 81 and then Band < (196 * 81 * 150) / 100;
   end Lake_Shore;

   function Pond (X, Y : Coord) return Boolean is
   begin
      return X = Pond_X and then Y = Pond_Y;
   end Pond;

   function Pond_Shore (X, Y : Coord) return Boolean is
      DX : constant Integer := abs (Integer (X) - Integer (Pond_X));
      DY : constant Integer := abs (Integer (Y) - Integer (Pond_Y));
   begin
      return DX <= 1 and then DY <= 1 and then not Pond (X, Y);
   end Pond_Shore;

   function Clearing (X, Y : Coord) return Boolean is
   begin
      return abs (Integer (X) - Integer (Start_X)) <= 4
        and then abs (Integer (Y) - Integer (Start_Y)) <= 4;
   end Clearing;

   function Water_Cell (X, Y : Coord) return Boolean is
   begin
      return Pond (X, Y) or else In_Lake (X, Y)
        or else X <= 2 or else Y <= 2 or else X >= 93 or else Y >= 93;
   end Water_Cell;

   function Sand_Cell (X, Y : Coord) return Boolean is
   begin
      if Water_Cell (X, Y) then
         return False;
      end if;
      return X <= 5 or else Y <= 5 or else X >= 90 or else Y >= 90
        or else Lake_Shore (X, Y) or else Pond_Shore (X, Y);
   end Sand_Cell;

   function Dry (X, Y : Integer) return Boolean is
   begin
      if X not in Coord or else Y not in Coord then
         return False;
      end if;
      return not Water_Cell (Coord (X), Coord (Y))
        and then not Sand_Cell (Coord (X), Coord (Y));
   end Dry;

   function Bush_Off (P : Spot; K : Integer) return Spot is
   begin
      case K is
         when 0 =>
            return P;
         when 1 =>
            return (X => P.X + 2, Y => P.Y);
         when 2 =>
            return (X => P.X, Y => P.Y + 2);
         when 3 =>
            return (X => P.X - 3, Y => P.Y);
         when 4 =>
            return (X => P.X + 2, Y => P.Y + 2);
         when 5 =>
            return (X => P.X - 2, Y => P.Y + 2);
         when 6 =>
            return (X => P.X + 4, Y => P.Y);
         when others =>
            return (X => P.X - 4, Y => P.Y);
      end case;
   end Bush_Off;

   function Grove_Fits (P : Spot) return Boolean is
      Spot_K : Spot;
   begin
      if not Dry (Integer (P.X), Integer (P.Y)) then
         return False;
      end if;
      if Clearing (P.X, P.Y) then
         return False;
      end if;
      for K in 0 .. 7 loop
         Spot_K := Bush_Off (P, K);
         if not Dry (Integer (Spot_K.X), Integer (Spot_K.Y)) then
            return False;
         end if;
      end loop;
      if not Dry (Integer (P.X) + 3, Integer (P.Y) + 2) then
         return False;
      end if;
      return True;
   end Grove_Fits;

   function Far_Enough (Centers : Grove_List; Count : Natural; P : Spot) return Boolean is
   begin
      for I in 1 .. Count loop
         if abs (Integer (Centers (Grove_Index (I)).X) - Integer (P.X)) < 12
           and then abs (Integer (Centers (Grove_Index (I)).Y) - Integer (P.Y)) < 12
         then
            return False;
         end if;
      end loop;
      return True;
   end Far_Enough;

   function Pick_Grove
     (Seed : Seed_Value; G : Grove_Index; Centers : Grove_List) return Spot
   is
      use Interfaces;
      H : Unsigned_32;
      X : Integer;
      Y : Integer;
      P : Spot;
   begin
      for Attempt in 0 .. 400 loop
         H := Mix (Seed, Natural (G) * 50 + Attempt, Attempt);
         X := 8 + Integer (H mod 76);
         Y := 8 + Integer ((H / 76) mod 76);
         P := (X => Coord (X), Y => Coord (Y));
         if Grove_Fits (P) and then Far_Enough (Centers, Natural (G) - 1, P) then
            return P;
         end if;
      end loop;
      return Groves (G);
   end Pick_Grove;

   function Shallow_Cell (X, Y : Coord) return Boolean is
   begin
      if not Water_Cell (X, Y) then
         return False;
      end if;
      if X > Coord'First and then Sand_Cell (X - 1, Y) then
         return True;
      end if;
      if X < Coord'Last and then Sand_Cell (X + 1, Y) then
         return True;
      end if;
      if Y > Coord'First and then Sand_Cell (X, Y - 1) then
         return True;
      end if;
      if Y < Coord'Last and then Sand_Cell (X, Y + 1) then
         return True;
      end if;
      return False;
   end Shallow_Cell;

   function Pick_Fish (Seed : Seed_Value; Which : Fish_Index) return Spot is
      use Interfaces;
      H     : constant Unsigned_32 := Mix (Seed, 90, Which);
      Start : constant Integer := Integer (H mod 9000);
      Seen  : Natural := 0;
      N     : Integer;
      X, Y  : Coord;
   begin
      for Step in 0 .. Grid_Size * Grid_Size - 1 loop
         N := (Start + Step) mod (Grid_Size * Grid_Size);
         X := Coord (N mod Grid_Size);
         Y := Coord (N / Grid_Size);
         if Shallow_Cell (X, Y) then
            Seen := Seen + 1;
            if Seen = Which then
               return (X => X, Y => Y);
            end if;
         end if;
      end loop;
      case Which is
         when 1 =>
            return (X => Pond_X, Y => Pond_Y);
         when 2 =>
            return (X => 57, Y => 62);
         when 3 =>
            return (X => 83, Y => 62);
         when 4 =>
            return (X => 70, Y => 54);
      end case;
   end Pick_Fish;

   function Build (Seed : Seed_Value) return Layout is
      Result : Layout;
      G      : Grove_Index;
      K      : Integer;
      P      : Spot;
   begin
      if Seed = Default_Island_Seed then
         for I in Bush_Index loop
            G := Grove_Index ((I - 1) / Bushes_Per_Grove + 1);
            K := (I - 1) mod Bushes_Per_Grove;
            Result.Bushes (I) := Bush_Off (Groves (G), K);
         end loop;
         for N in Npc_Index loop
            G := Grove_Index ((N + 1) / 2);
            P := Groves (G);
            if N mod 2 = 1 then
               Result.Homes (N) := (X => P.X + 2, Y => P.Y + 2);
            else
               Result.Homes (N) := (X => P.X + 3, Y => P.Y + 2);
            end if;
         end loop;
         Result.Fish :=
           [1 => (X => Pond_X, Y => Pond_Y),
            2 => (X => 57, Y => 62),
            3 => (X => 83, Y => 62),
            4 => (X => 70, Y => 54)];
         return Result;
      end if;
      declare
         Centers : Grove_List;
      begin
         for G in Grove_Index loop
            Centers (G) := Groves (G);
         end loop;
         for G in Grove_Index loop
            Centers (G) := Pick_Grove (Seed, G, Centers);
         end loop;
         for I in Bush_Index loop
            G := Grove_Index ((I - 1) / Bushes_Per_Grove + 1);
            K := (I - 1) mod Bushes_Per_Grove;
            Result.Bushes (I) := Bush_Off (Centers (G), K);
         end loop;
         for N in Npc_Index loop
            G := Grove_Index ((N + 1) / 2);
            P := Centers (G);
            if N mod 2 = 1 then
               Result.Homes (N) := (X => P.X + 2, Y => P.Y + 2);
            else
               Result.Homes (N) := (X => P.X + 3, Y => P.Y + 2);
            end if;
         end loop;
      end;
      for I in Fish_Index loop
         Result.Fish (I) := Pick_Fish (Seed, I);
      end loop;
      return Result;
   end Build;

   procedure Ensure (Seed : Seed_Value) is
   begin
      if Have_Cache and then Cached_Seed = Seed then
         return;
      end if;
      Cached := Build (Seed);
      Cached_Seed := Seed;
      Have_Cache := True;
   end Ensure;

   function Reserved (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      Ensure (Seed);
      for I in Bush_Index loop
         if Cached.Bushes (I).X = X and then Cached.Bushes (I).Y = Y then
            return True;
         end if;
      end loop;
      for N in Npc_Index loop
         if Cached.Homes (N).X = X and then Cached.Homes (N).Y = Y then
            return True;
         end if;
      end loop;
      return False;
   end Reserved;

   function Terrain_At (Seed : Seed_Value; X, Y : Coord) return Terrain is
      H : constant Natural := Hash (Seed, X, Y);
   begin
      if Pond (X, Y) or else In_Lake (X, Y) then
         return Water;
      end if;
      if X <= 2 or else Y <= 2 or else X >= 93 or else Y >= 93 then
         return Water;
      end if;
      if X <= 5 or else Y <= 5 or else X >= 90 or else Y >= 90
        or else Lake_Shore (X, Y) or else Pond_Shore (X, Y)
      then
         return Sand;
      end if;
      if Clearing (X, Y) or else Reserved (Seed, X, Y) then
         return Grass;
      end if;
      if X < 30 and then H mod 3 = 0 then
         return Tree;
      end if;
      if H mod 19 = 0 then
         return Rock;
      end if;
      if H mod 8 = 0 then
         return Tree;
      end if;
      return Grass;
   end Terrain_At;

   function Walkable (Ground : Terrain) return Boolean is
   begin
      return Ground = Sand or else Ground = Grass;
   end Walkable;

   function Sand_Beside (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      if X > Coord'First and then Terrain_At (Seed, X - 1, Y) = Sand then
         return True;
      end if;
      if X < Coord'Last and then Terrain_At (Seed, X + 1, Y) = Sand then
         return True;
      end if;
      if Y > Coord'First and then Terrain_At (Seed, X, Y - 1) = Sand then
         return True;
      end if;
      if Y < Coord'Last and then Terrain_At (Seed, X, Y + 1) = Sand then
         return True;
      end if;
      return False;
   end Sand_Beside;

   function Shallow (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      return Terrain_At (Seed, X, Y) = Water and then Sand_Beside (Seed, X, Y);
   end Shallow;

   function Bush (Seed : Seed_Value; I : Bush_Index) return Spot is
   begin
      Ensure (Seed);
      return Cached.Bushes (I);
   end Bush;

   function Fish_At (Seed : Seed_Value; I : Fish_Index) return Spot is
   begin
      Ensure (Seed);
      return Cached.Fish (I);
   end Fish_At;

   function Npc_Home (Seed : Seed_Value; N : Npc_Index) return Spot is
   begin
      Ensure (Seed);
      return Cached.Homes (N);
   end Npc_Home;

   function Layout_Ok return Boolean is
      Seed : constant Seed_Value := Default_Island_Seed;
   begin
      pragma Assert (Terrain_At (Seed, Start_X, Start_Y) = Grass);
      pragma Assert (Terrain_At (Seed, Berry_X, Berry_Y) = Grass);
      pragma Assert (Walkable (Terrain_At (Seed, Stick_X, Stick_Y)));
      pragma Assert (Walkable (Terrain_At (Seed, Stone_X, Stone_Y)));
      pragma Assert (Walkable (Terrain_At (Seed, Shell_X, Shell_Y)));
      pragma Assert (Shallow (Seed, Pond_X, Pond_Y));
      for I in Bush_Index loop
         pragma Assert (Terrain_At (Seed, Bush (Seed, I).X, Bush (Seed, I).Y) = Grass);
         for J in Bush_Index loop
            if I /= J then
               pragma Assert
                 (Bush (Seed, I).X /= Bush (Seed, J).X
                  or else Bush (Seed, I).Y /= Bush (Seed, J).Y);
            end if;
         end loop;
      end loop;
      for I in Fish_Index loop
         pragma Assert (Shallow (Seed, Fish_At (Seed, I).X, Fish_At (Seed, I).Y));
      end loop;
      pragma Assert (Groves (2).X /= Start_X or else Groves (2).Y /= Start_Y);
      return True;
   end Layout_Ok;

   function Height (Seed : Seed_Value; X, Y : Coord) return Natural is
      Rise : Natural;
   begin
      if Water_Cell (X, Y) then
         return 0;
      end if;
      Rise := (abs (Integer (X) - 70) + abs (Integer (Y) - 62)) / 3;
      if Y > 58 and then Hash (Seed, X, Y) mod 9 = 0 then
         Rise := Rise + 8;
      end if;
      return Rise;
   end Height;

   function Mountain (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      return Height (Seed, X, Y) >= 14;
   end Mountain;

   type Path is array (1 .. River_Max) of Spot;
   type Path_Set is array (River_Index) of Path;

   River_Ready : Boolean := False;
   River_Seed  : Seed_Value := 0;
   River_Paths : Path_Set;
   River_Lens  : array (River_Index) of Natural := [others => 0];

   function Closer_To_Lake (X, Y, BX, BY : Integer) return Boolean is
      D  : constant Integer := abs (X - 70) + abs (Y - 62);
      DB : constant Integer := abs (BX - 70) + abs (BY - 62);
   begin
      return D < DB;
   end Closer_To_Lake;

   procedure Build_Rivers (Seed : Seed_Value) is
      Starts : constant array (River_Index) of Spot :=
        [1 => (X => 24, Y => 24),
         2 => (X => 72, Y => 24),
         3 => (X => 24, Y => 72),
         4 => (X => 72, Y => 72)];
      Seen : array (Coord, Coord) of Boolean := [others => [others => False]];
      X, Y, BX, BY, NX, NY : Integer;
      Best_H, H : Natural;
      Step : Natural;
   begin
      for Which in River_Index loop
         X := Integer (Starts (Which).X);
         Y := Integer (Starts (Which).Y);
         Step := 0;
         Seen := [others => [others => False]];
         while Step < River_Max loop
            Step := Step + 1;
            River_Paths (Which) (Step) := (X => Coord (X), Y => Coord (Y));
            Seen (Coord (X), Coord (Y)) := True;
            exit when Water_Cell (Coord (X), Coord (Y));
            Best_H := Natural'Last;
            BX := X;
            BY := Y;
            for Dir in 1 .. 4 loop
               NX := X;
               NY := Y;
               case Dir is
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
                 and then not Seen (Coord (NX), Coord (NY))
               then
                  H := Height (Seed, Coord (NX), Coord (NY));
                  if H < Best_H
                    or else (H = Best_H and then Closer_To_Lake (NX, NY, BX, BY))
                  then
                     Best_H := H;
                     BX := NX;
                     BY := NY;
                  end if;
               end if;
            end loop;
            exit when BX = X and then BY = Y;
            X := BX;
            Y := BY;
         end loop;
         River_Lens (Which) := Step;
      end loop;
      River_Seed := Seed;
      River_Ready := True;
   end Build_Rivers;

   procedure Ensure_Rivers (Seed : Seed_Value) is
   begin
      if not River_Ready or else River_Seed /= Seed then
         Build_Rivers (Seed);
      end if;
   end Ensure_Rivers;

   function River_Length (Seed : Seed_Value; Which : River_Index) return Natural is
   begin
      Ensure_Rivers (Seed);
      return River_Lens (Which);
   end River_Length;

   function River_Step
     (Seed : Seed_Value; Which : River_Index; Step : Natural) return Spot
   is
   begin
      Ensure_Rivers (Seed);
      if Step in 1 .. River_Lens (Which) then
         return River_Paths (Which) (Step);
      end if;
      return (X => 0, Y => 0);
   end River_Step;

   function On_River (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      Ensure_Rivers (Seed);
      for Which in River_Index loop
         for Step in 1 .. River_Lens (Which) loop
            if River_Paths (Which) (Step).X = X
              and then River_Paths (Which) (Step).Y = Y
            then
               return True;
            end if;
         end loop;
      end loop;
      return False;
   end On_River;

   function Drinkable (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      if Water_Cell (X, Y) or else On_River (Seed, X, Y) then
         return True;
      end if;
      if X > Coord'First and then On_River (Seed, X - 1, Y) then
         return True;
      end if;
      if X < Coord'Last and then On_River (Seed, X + 1, Y) then
         return True;
      end if;
      if Y > Coord'First and then On_River (Seed, X, Y - 1) then
         return True;
      end if;
      if Y < Coord'Last and then On_River (Seed, X, Y + 1) then
         return True;
      end if;
      return False;
   end Drinkable;

end Island.Map;
