with Interfaces;
with Island.Rng;

package body Island.Map is
   use type Interfaces.Unsigned_32;

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

   function Mix (Seed : Seed_Value; A, B : Natural) return Interfaces.Unsigned_32 is
      use Interfaces;
   begin
      return Rng.Mix (Unsigned_32 (Seed), Unsigned_32 (A), Unsigned_32 (B));
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

   function Land_Ok (Seed : Seed_Value; X, Y : Integer) return Boolean;

   function Grove_Fits (Seed : Seed_Value; P : Spot) return Boolean is
      Spot_K : Spot;
   begin
      if not Land_Ok (Seed, Integer (P.X), Integer (P.Y)) then
         return False;
      end if;
      if Clearing (P.X, P.Y) then
         return False;
      end if;
      for K in 0 .. 7 loop
         Spot_K := Bush_Off (P, K);
         if not Land_Ok (Seed, Integer (Spot_K.X), Integer (Spot_K.Y)) then
            return False;
         end if;
      end loop;
      if not Land_Ok (Seed, Integer (P.X) + 3, Integer (P.Y) + 2) then
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
         if Grove_Fits (Seed, P) and then Far_Enough (Centers, Natural (G) - 1, P) then
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
      H : Natural;
      Wet : Natural;
   begin
      if Pond (X, Y) then
         return Water;
      end if;
      if X <= 2 or else Y <= 2 or else X >= 93 or else Y >= 93 then
         return Water;
      end if;
      H := Height (Seed, X, Y);
      if Pond_Shore (X, Y) then
         return Sand;
      end if;
      if X <= 5 or else Y <= 5 or else X >= 90 or else Y >= 90 then
         return Sand;
      end if;
      if Reserved (Seed, X, Y) or else (Clearing (X, Y) and then H > 0) then
         return Grass;
      end if;
      if H = 0 then
         return Water;
      end if;
      if H <= 2 then
         return Sand;
      end if;
      if H >= 16 then
         return Rock;
      end if;
      Wet := Rain (Seed, X, Y);
      if Wet < 28 then
         return Sand;
      end if;
      --  Wet slopes grow forest. The plains and the low ground stay grass,
      --  so a group can walk and the berries have somewhere to sit.
      if Wet >= 55 and then H in 8 .. 12
        and then Mix (Seed, Natural (X), Natural (Y)) mod 3 = 0
      then
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

   Coarse : constant := 16;

   type Path is array (1 .. River_Max) of Spot;
   type Path_Set is array (River_Index) of Path;

   Elev        : array (Coord, Coord) of Natural := [others => [others => 0]];
   River_Paths : Path_Set;
   River_Lens  : array (River_Index) of Natural := [others => 0];
   River_Wide  : array (River_Index, 1 .. River_Max) of Natural :=
     [others => [others => 1]];
   World_Ready : Boolean := False;
   World_Seed  : Seed_Value := 0;
   Rejects     : Natural := 0;
   Ranges      : Natural := 0;
   Gate_X      : Coord := 30;
   Gate_Y      : Coord := 30;

   function Clamp (V, Lo, Hi : Integer) return Integer is
   begin
      if V < Lo then
         return Lo;
      elsif V > Hi then
         return Hi;
      else
         return V;
      end if;
   end Clamp;

   function Rand (Seed : Seed_Value; A, B : Natural) return Natural is
      use Interfaces;
   begin
      return Natural (Mix (Seed, A, B) mod 1000);
   end Rand;

   procedure Generate (Gen : Seed_Value) is
      CElev : array (0 .. Coarse, 0 .. Coarse) of Integer :=
        [others => [others => 0]];
      Seen  : array (Coord, Coord) of Boolean := [others => [others => False]];
      Length, Half, Amp, X, Y, Sum, Count, Noise : Integer;
      SX, SY, DX, DY, Add, K : Integer;
      LX, LY, GX, GY : Integer;
      Springs : array (River_Index) of Spot;
      Best, Score, H, Dist, Desired, Prev_H : Integer;
      Step, BX, BY, NX, NY : Integer;
      Wide : Natural;

      function Kept (X, Y : Integer) return Boolean is
         P : Spot;
      begin
         if X not in Coord or else Y not in Coord then
            return True;
         end if;
         if Clearing (Coord (X), Coord (Y)) then
            return True;
         end if;
         if (X = 30 and then Y = 30) or else (X = 31 and then Y = 30) then
            return True;
         end if;
         if (X = 18 and then Y in 18 .. 19)
           or else (X = 78 and then Y in 18 .. 19)
           or else (X = 18 and then Y in 78 .. 79)
           or else (X = 78 and then Y in 78 .. 79)
         then
            return True;
         end if;
         for G in Grove_Index loop
            for KK in 0 .. 7 loop
               P := Bush_Off (Groves (G), KK);
               if Integer (P.X) = X and then Integer (P.Y) = Y then
                  return True;
               end if;
            end loop;
         end loop;
         return False;
      end Kept;
   begin
      Ranges := 1 + Rand (Gen, 3, 1) mod 3;
      for I in 0 .. Coarse loop
         CElev (I, 0) := 0;
         CElev (I, Coarse) := 0;
         CElev (0, I) := 0;
         CElev (Coarse, I) := 0;
      end loop;
      CElev (8, 8) := 6 + Integer (Rand (Gen, 4, 1) mod 6);
      Length := Coarse;
      Amp := 8;
      while Length > 1 loop
         Half := Length / 2;
         Y := Half;
         while Y < Coarse loop
            X := Half;
            while X < Coarse loop
               Sum := CElev (X - Half, Y - Half) + CElev (X + Half, Y - Half)
                 + CElev (X - Half, Y + Half) + CElev (X + Half, Y + Half);
               Noise := Integer (Rand (Gen, Natural (X + 20), Natural (Y + Length)) mod
                 Natural (Amp * 2 + 1)) - Amp;
               CElev (X, Y) := Clamp (Sum / 4 + Noise, 0, 22);
               X := X + Length;
            end loop;
            Y := Y + Length;
         end loop;
         Y := 0;
         while Y <= Coarse loop
            if (Y / Half) mod 2 = 0 then
               X := Half;
            else
               X := 0;
            end if;
            while X <= Coarse loop
               if X /= 0 and then X /= Coarse and then Y /= 0 and then Y /= Coarse then
                  Sum := 0;
                  Count := 0;
                  if X - Half >= 0 then
                     Sum := Sum + CElev (X - Half, Y);
                     Count := Count + 1;
                  end if;
                  if X + Half <= Coarse then
                     Sum := Sum + CElev (X + Half, Y);
                     Count := Count + 1;
                  end if;
                  if Y - Half >= 0 then
                     Sum := Sum + CElev (X, Y - Half);
                     Count := Count + 1;
                  end if;
                  if Y + Half <= Coarse then
                     Sum := Sum + CElev (X, Y + Half);
                     Count := Count + 1;
                  end if;
                  if Count > 0 then
                     Noise := Integer (Rand (Gen, Natural (X + 40), Natural (Y + Length)) mod
                       Natural (Amp * 2 + 1)) - Amp;
                     CElev (X, Y) := Clamp (Sum / Count + Noise, 0, 22);
                  end if;
               end if;
               X := X + Length;
            end loop;
            Y := Y + Half;
         end loop;
         for I in 0 .. Coarse loop
            CElev (I, 0) := 0;
            CElev (I, Coarse) := 0;
            CElev (0, I) := 0;
            CElev (Coarse, I) := 0;
         end loop;
         Length := Half;
         Amp := Amp / 2;
         if Amp < 1 then
            Amp := 1;
         end if;
      end loop;

      for YY in Coord loop
         for XX in Coord loop
            declare
               Px : constant Integer := XX * Coarse;
               Py : constant Integer := YY * Coarse;
               X0 : Integer := Px / (Grid_Size - 1);
               Y0 : Integer := Py / (Grid_Size - 1);
               Tx : Integer := Px mod (Grid_Size - 1);
               Ty : Integer := Py mod (Grid_Size - 1);
               X1, Y1, Top, Bot, V : Integer;
            begin
               if X0 > Coarse - 1 then
                  X0 := Coarse - 1;
                  Tx := Grid_Size - 1;
               end if;
               if Y0 > Coarse - 1 then
                  Y0 := Coarse - 1;
                  Ty := Grid_Size - 1;
               end if;
               X1 := X0 + 1;
               Y1 := Y0 + 1;
               Top := (CElev (X0, Y0) * (Grid_Size - 1 - Tx) + CElev (X1, Y0) * Tx)
                 / (Grid_Size - 1);
               Bot := (CElev (X0, Y1) * (Grid_Size - 1 - Tx) + CElev (X1, Y1) * Tx)
                 / (Grid_Size - 1);
               V := (Top * (Grid_Size - 1 - Ty) + Bot * Ty) / (Grid_Size - 1);
               Elev (XX, YY) := Natural (Clamp (V, 0, 22));
            end;
         end loop;
      end loop;

      for R in 1 .. Ranges loop
         SX := 14 + Integer (Rand (Gen, R, 5) mod 68);
         SY := 14 + Integer (Rand (Gen, R, 6) mod 68);
         DX := Integer (Rand (Gen, R, 7) mod 3) - 1;
         DY := Integer (Rand (Gen, R, 8) mod 3) - 1;
         if DX = 0 and then DY = 0 then
            DX := 1;
         end if;
         K := 0;
         while K < 34 loop
            if K mod 11 = 7 then
               Add := 3;
            else
               Add := 14 - abs (K - 16) / 2;
            end if;
            for OY in -2 .. 2 loop
               for OX in -2 .. 2 loop
                  NX := SX + OX;
                  NY := SY + OY;
                  if NX in Coord and then NY in Coord
                    and then NX > 5 and then NY > 5 and then NX < 90 and then NY < 90
                  then
                     Dist := abs OX + abs OY;
                     if Dist <= 2 then
                        Elev (Coord (NX), Coord (NY)) :=
                          Elev (Coord (NX), Coord (NY))
                          + Natural (Add * (3 - Dist) / 3);
                        if Elev (Coord (NX), Coord (NY)) > 28 then
                           Elev (Coord (NX), Coord (NY)) := 28;
                        end if;
                     end if;
                  end if;
               end loop;
            end loop;
            if K mod 5 = 4 then
               DX := Clamp (DX + Integer (Rand (Gen, R, Natural (K)) mod 3) - 1, -1, 1);
               DY := Clamp (DY + Integer (Rand (Gen, R, Natural (K + 3)) mod 3) - 1, -1, 1);
               if DX = 0 and then DY = 0 then
                  DY := 1;
               end if;
            end if;
            SX := Clamp (SX + DX, 8, 87);
            SY := Clamp (SY + DY, 8, 87);
            K := K + 1;
         end loop;
      end loop;

      for YY in Coord loop
         for XX in Coord loop
            if Elev (XX, YY) in 5 .. 9
              and then XX > 5 and then YY > 5 and then XX < 90 and then YY < 90
            then
               Elev (XX, YY) := 6;
            end if;
         end loop;
      end loop;

      LX := 22;
      LY := 50;
      if Rand (Gen, 9, 2) mod 2 = 1 then
         LX := 74;
         LY := 50;
      end if;
      if abs (LX - Integer (Start_X)) + abs (LY - Integer (Start_Y)) < 16 then
         LX := 22;
         LY := 50;
      end if;
      GX := LX;
      GY := LY - 5;
      if GY < 8 then
         GY := LY + 5;
      end if;
      Gate_X := Coord (GX);
      Gate_Y := Coord (GY);
      for OY in -6 .. 6 loop
         for OX in -6 .. 6 loop
            NX := LX + OX;
            NY := LY + OY;
            if NX in Coord and then NY in Coord then
               Dist := abs OX + abs OY;
               if Dist <= 3 then
                  Elev (Coord (NX), Coord (NY)) := 0;
               elsif Dist <= 5 then
                  Elev (Coord (NX), Coord (NY)) := Natural (Dist - 3);
               end if;
            end if;
         end loop;
      end loop;
      Elev (Gate_X, Gate_Y) := 1;

      Springs :=
        [1 => (X => 20, Y => 20),
         2 => (X => 76, Y => 20),
         3 => (X => 20, Y => 74),
         4 => (X => 76, Y => 74)];
      for Which in River_Index loop
         Best := -1;
         BX := Integer (Springs (Which).X);
         BY := Integer (Springs (Which).Y);
         for OY in -6 .. 6 loop
            for OX in -6 .. 6 loop
               NX := Integer (Springs (Which).X) + OX;
               NY := Integer (Springs (Which).Y) + OY;
               if NX in 8 .. 87 and then NY in 8 .. 87 then
                  Score := Integer (Elev (Coord (NX), Coord (NY)));
                  if Score > Best and then Score >= 8 then
                     Best := Score;
                     BX := NX;
                     BY := NY;
                  end if;
               end if;
            end loop;
         end loop;
         if Elev (Coord (BX), Coord (BY)) < 10 then
            Elev (Coord (BX), Coord (BY)) := 10;
         end if;
         Springs (Which) := (X => Coord (BX), Y => Coord (BY));
      end loop;

      for Which in River_Index loop
         X := Integer (Springs (Which).X);
         Y := Integer (Springs (Which).Y);
         Step := 0;
         Seen := [others => [others => False]];
         Prev_H := Integer (Elev (Coord (X), Coord (Y)));
         Wide := 1;
         while Step < River_Max - 4 loop
            Step := Step + 1;
            River_Paths (Which) (Step) := (X => Coord (X), Y => Coord (Y));
            River_Wide (Which, Step) := Wide;
            Seen (Coord (X), Coord (Y)) := True;
            exit when X = GX and then Y = GY;
            Best := Integer'Last;
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
                  when others =>
                     NX := NX - 1;
               end case;
               if NX in 4 .. 91 and then NY in 4 .. 91
                 and then not Seen (Coord (NX), Coord (NY))
                 and then not Kept (NX, NY)
               then
                  Dist := abs (NX - GX) + abs (NY - GY);
                  Score := Dist * 4 + Integer (Elev (Coord (NX), Coord (NY)));
                  if Score < Best then
                     Best := Score;
                     BX := NX;
                     BY := NY;
                  end if;
               end if;
            end loop;
            exit when BX = X and then BY = Y;
            Dist := abs (BX - GX) + abs (BY - GY);
            Desired := 1 + Dist / 5;
            if Desired > Prev_H then
               Desired := Prev_H;
            end if;
            H := Integer (Elev (Coord (BX), Coord (BY)));
            if Desired < 1 then
               Desired := 1;
            end if;
            if H >= Prev_H then
               if Rand (Gen, Which, Natural (Step)) mod 10 < 4
                 and then H > Desired + 1 and then Dist > 6
               then
                  --  A side hollow becomes a pond. The channel itself stays dry.
                  for OY in -1 .. 1 loop
                     for OX in -1 .. 1 loop
                        NX := BX + OX;
                        NY := BY + OY;
                        if NX in Coord and then NY in Coord
                          and then (NX /= BX or else NY /= BY)
                          and then Elev (Coord (NX), Coord (NY)) <= Natural (Prev_H)
                          and then not Kept (NX, NY)
                        then
                           Elev (Coord (NX), Coord (NY)) := 0;
                        end if;
                     end loop;
                  end loop;
               end if;
               Elev (Coord (BX), Coord (BY)) := Natural (Desired);
            elsif H > Desired then
               Elev (Coord (BX), Coord (BY)) := Natural (Desired);
            end if;
            if Elev (Coord (BX), Coord (BY)) > Natural (Prev_H) then
               Elev (Coord (BX), Coord (BY)) := Natural (Prev_H);
            end if;
            if Elev (Coord (BX), Coord (BY)) = 0 then
               Elev (Coord (BX), Coord (BY)) := 1;
            end if;
            Prev_H := Integer (Elev (Coord (BX), Coord (BY)));
            X := BX;
            Y := BY;
            for Earlier in River_Index loop
               if Earlier < Which then
                  for S in 1 .. River_Lens (Earlier) loop
                     if River_Paths (Earlier) (S).X = Coord (X)
                       and then River_Paths (Earlier) (S).Y = Coord (Y)
                     then
                        Wide := 2;
                        if River_Wide (Earlier, S) < 3 then
                           River_Wide (Earlier, S) := River_Wide (Earlier, S) + 1;
                        end if;
                     end if;
                  end loop;
               end if;
            end loop;
         end loop;
         if Step < River_Max - 3 and then X = GX and then Y = GY then
            H := Integer (Elev (Gate_X, Gate_Y));
            if GX - 1 in Coord and then H > 0 then
               Elev (Coord (GX - 1), Gate_Y) := Natural (H);
               Step := Step + 1;
               River_Paths (Which) (Step) := (X => Coord (GX - 1), Y => Gate_Y);
               River_Wide (Which, Step) := 1;
            end if;
            if GX + 1 in Coord and then H > 0 and then Step < River_Max - 1 then
               Elev (Coord (GX + 1), Gate_Y) := Natural (H);
               Step := Step + 1;
               River_Paths (Which) (Step) := (X => Coord (GX + 1), Y => Gate_Y);
               River_Wide (Which, Step) := 1;
            end if;
            NX := LX;
            if GY < LY then
               NY := GY + 1;
            else
               NY := GY - 1;
            end if;
            if NX in Coord and then NY in Coord and then Step < River_Max then
               Elev (Coord (NX), Coord (NY)) := 0;
               Step := Step + 1;
               River_Paths (Which) (Step) := (X => Coord (NX), Y => Coord (NY));
               River_Wide (Which, Step) := 2;
            end if;
         elsif Step < River_Max and then Elev (Coord (X), Coord (Y)) > 0 then
            Step := Step + 1;
            River_Paths (Which) (Step) := (X => Gate_X, Y => Gate_Y);
            Elev (Gate_X, Gate_Y) := 0;
         end if;
         River_Lens (Which) := Step;
      end loop;

      --  Overflow from the lake toward the sea, one cell wide.
      X := LX;
      Y := LY + 4;
      while Y < 93 and then Y in Coord and then X < 90 loop
         if Kept (X, Y) then
            X := X + 1;
         else
            Elev (Coord (X), Coord (Y)) := 0;
            Y := Y + 1;
         end if;
      end loop;

      for YY in Coord loop
         for XX in Coord loop
            if XX <= 2 or else YY <= 2 or else XX >= 93 or else YY >= 93 then
               Elev (XX, YY) := 0;
            end if;
         end loop;
      end loop;
      Elev (Pond_X, Pond_Y) := 0;
      Elev (57, 62) := 0;
      Elev (83, 62) := 0;
      Elev (70, 54) := 0;
      declare
         type Fish_Spot is record
            X, Y : Coord;
         end record;
         Spots : constant array (1 .. 4) of Fish_Spot :=
           [1 => (Pond_X, Pond_Y), 2 => (57, 62), 3 => (83, 62), 4 => (70, 54)];
         Has : Boolean;
      begin
         for I in Spots'Range loop
            Has := False;
            for Dir in 1 .. 4 loop
               NX := Integer (Spots (I).X);
               NY := Integer (Spots (I).Y);
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
               if NX in Coord and then NY in Coord
                 and then Elev (Coord (NX), Coord (NY)) in 1 .. 3
               then
                  Has := True;
               end if;
            end loop;
            if not Has and then Spots (I).X < 90 then
               Elev (Spots (I).X + 1, Spots (I).Y) := 2;
            end if;
         end loop;
      end;
      for YY in Coord loop
         for XX in Coord loop
            if Clearing (XX, YY) and then not Pond (XX, YY) and then Elev (XX, YY) = 0 then
               Elev (XX, YY) := 4;
            end if;
            if Clearing (XX, YY) and then Elev (XX, YY) > 10 and then not Pond (XX, YY) then
               Elev (XX, YY) := 6;
            end if;
         end loop;
      end loop;
      for G in Grove_Index loop
         for K in 0 .. 7 loop
            declare
               P : constant Spot := Bush_Off (Groves (G), K);
            begin
               if not Pond (P.X, P.Y) and then Elev (P.X, P.Y) = 0 then
                  Elev (P.X, P.Y) := 5;
               end if;
            end;
         end loop;
      end loop;
      if not Pond (30, 30) then
         Elev (30, 30) := 5;
      end if;
      if not Pond (31, 30) then
         Elev (31, 30) := 5;
      end if;
      Elev (18, 18) := 5;
      Elev (18, 19) := 5;
      Elev (78, 18) := 5;
      Elev (78, 19) := 5;
      Elev (18, 78) := 5;
      Elev (18, 79) := 5;
      Elev (78, 78) := 5;
      Elev (78, 79) := 5;
      for Which in River_Index loop
         if River_Lens (Which) >= 2 then
            for S in 1 .. River_Lens (Which) - 1 loop
               if Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) = 0 then
                  Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) := 1;
               end if;
            end loop;
            for S in 2 .. River_Lens (Which) - 1 loop
               if Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
                 > Elev (River_Paths (Which) (S - 1).X, River_Paths (Which) (S - 1).Y)
               then
                  Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) :=
                    Elev (River_Paths (Which) (S - 1).X, River_Paths (Which) (S - 1).Y);
               end if;
            end loop;
            Elev
              (River_Paths (Which) (River_Lens (Which)).X,
               River_Paths (Which) (River_Lens (Which)).Y) := 0;
         end if;
      end loop;
      for Which in River_Index loop
         declare
            Placed : Boolean := False;
            PX, PY, NX, NY : Integer;
         begin
            for S in 1 .. River_Lens (Which) - 1 loop
               exit when Placed or else S > 12;
               PX := Integer (River_Paths (Which) (S).X);
               PY := Integer (River_Paths (Which) (S).Y);
               if Elev (Coord (PX), Coord (PY)) in 1 .. 8 then
                  for Dir in 1 .. 4 loop
                     NX := PX;
                     NY := PY;
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
                     if NX in 6 .. 89 and then NY in 6 .. 89 then
                        declare
                           On_Path : Boolean := False;
                        begin
                           for T in 1 .. River_Lens (Which) loop
                              if Integer (River_Paths (Which) (T).X) = NX
                                and then Integer (River_Paths (Which) (T).Y) = NY
                              then
                                 On_Path := True;
                              end if;
                           end loop;
                           if On_Path then
                              null;
                           elsif Elev (Coord (NX), Coord (NY)) in 2 .. 8 then
                              Placed := True;
                           elsif Elev (Coord (NX), Coord (NY)) > 0 then
                              Elev (Coord (NX), Coord (NY)) := 5;
                              Placed := True;
                           end if;
                        end;
                     end if;
                     exit when Placed;
                  end loop;
               end if;
            end loop;
         end;
      end loop;
   end Generate;

   function Map_Ok return Boolean is
      Prev, Here : Natural;
      Camps : Natural := 0;
      Used_X : array (1 .. 4) of Integer := [others => -1];
      Used_Y : array (1 .. 4) of Integer := [others => -1];
      Far : Boolean;
      NX, NY : Integer;
   begin
      if Ranges < 1 then
         return False;
      end if;
      for Which in River_Index loop
         if River_Lens (Which) < 4 then
            return False;
         end if;
         if Elev (River_Paths (Which) (River_Lens (Which)).X,
                  River_Paths (Which) (River_Lens (Which)).Y) /= 0
         then
            return False;
         end if;
         Prev := Elev (River_Paths (Which) (1).X, River_Paths (Which) (1).Y);
         for S in 2 .. River_Lens (Which) loop
            Here := Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y);
            if Here > Prev then
               return False;
            end if;
            Prev := Here;
         end loop;
      end loop;
      for Which in River_Index loop
         for S in 1 .. River_Lens (Which) loop
            if Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) in 1 .. 8 then
               for Dir in 1 .. 4 loop
                  NX := Integer (River_Paths (Which) (S).X);
                  NY := Integer (River_Paths (Which) (S).Y);
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
                  if NX in 6 .. 89 and then NY in 6 .. 89
                    and then Elev (Coord (NX), Coord (NY)) in 2 .. 8
                  then
                     Far := True;
                     for C in 1 .. Camps loop
                        if abs (Used_X (C) - NX) + abs (Used_Y (C) - NY) < 12 then
                           Far := False;
                        end if;
                     end loop;
                     if Far and then Camps < 4 then
                        Camps := Camps + 1;
                        Used_X (Camps) := NX;
                        Used_Y (Camps) := NY;
                     end if;
                  end if;
               end loop;
            end if;
         end loop;
      end loop;
      return Camps >= 4;
   end Map_Ok;

   procedure Ensure_World (Seed : Seed_Value) is
      Gen : Seed_Value;
   begin
      if World_Ready and then World_Seed = Seed then
         return;
      end if;
      Rejects := 0;
      Gen := Seed;
      for Try in 1 .. 6 loop
         Generate (Gen);
         exit when Map_Ok;
         Rejects := Rejects + 1;
         declare
            use Interfaces;
         begin
            Gen := Seed_Value (Mix (Seed, Try, 17) mod 1_000_000_000);
         end;
      end loop;
      World_Seed := Seed;
      World_Ready := True;
   end Ensure_World;

   function Land_Ok (Seed : Seed_Value; X, Y : Integer) return Boolean is
   begin
      if X not in Coord or else Y not in Coord then
         return False;
      end if;
      if X <= 5 or else Y <= 5 or else X >= 90 or else Y >= 90 then
         return False;
      end if;
      Ensure_World (Seed);
      return Elev (Coord (X), Coord (Y)) in 2 .. 12;
   end Land_Ok;

   function Height (Seed : Seed_Value; X, Y : Coord) return Natural is
   begin
      Ensure_World (Seed);
      return Elev (X, Y);
   end Height;

   function Mountain (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      return Height (Seed, X, Y) >= 16;
   end Mountain;

   function Neighbour_H (Seed : Seed_Value; X, Y, DX, DY : Integer) return Natural is
      NX : constant Integer := X + DX;
      NY : constant Integer := Y + DY;
   begin
      if NX not in Coord or else NY not in Coord then
         return 0;
      end if;
      return Height (Seed, Coord (NX), Coord (NY));
   end Neighbour_H;

   function Pass (Seed : Seed_Value; X, Y : Coord) return Boolean is
      H : constant Natural := Height (Seed, X, Y);
      N : constant Natural := Neighbour_H (Seed, Integer (X), Integer (Y), 0, -1);
      S : constant Natural := Neighbour_H (Seed, Integer (X), Integer (Y), 0, 1);
      E : constant Natural := Neighbour_H (Seed, Integer (X), Integer (Y), 1, 0);
      W : constant Natural := Neighbour_H (Seed, Integer (X), Integer (Y), -1, 0);
   begin
      if H < 8 then
         return False;
      end if;
      return (N > H and then S > H) or else (E > H and then W > H);
   end Pass;

   function Uphill
     (Seed : Seed_Value; X, Y, NX, NY : Coord) return Boolean
   is
   begin
      return Height (Seed, NX, NY) >= Height (Seed, X, Y) + 2
        and then not Pass (Seed, NX, NY);
   end Uphill;

   function Rain (Seed : Seed_Value; X, Y : Coord) return Natural is
      Wet    : Integer;
      Shadow : Boolean := False;
      NX     : Integer;
   begin
      Ensure_World (Seed);
      Wet := 78 - (Integer (X) * 55) / (Grid_Size - 1);
      NX := Integer (X) - 1;
      while NX >= Integer (X) - 8 and then NX >= 0 loop
         if Elev (Coord (NX), Y) >= Elev (X, Y) + 5 then
            Shadow := True;
         end if;
         NX := NX - 1;
      end loop;
      if Shadow then
         Wet := Wet - 40;
      end if;
      if Wet < 0 then
         Wet := 0;
      end if;
      return Natural (Wet);
   end Rain;

   function Fertile (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      if Height (Seed, X, Y) not in 2 .. 6 then
         return False;
      end if;
      if Rain (Seed, X, Y) < 40 then
         return False;
      end if;
      return On_River (Seed, X, Y)
        or else (X > Coord'First and then On_River (Seed, X - 1, Y))
        or else (X < Coord'Last and then On_River (Seed, X + 1, Y))
        or else (Y > Coord'First and then On_River (Seed, X, Y - 1))
        or else (Y < Coord'Last and then On_River (Seed, X, Y + 1));
   end Fertile;

   function Rejection_Count (Seed : Seed_Value) return Natural is
   begin
      Ensure_World (Seed);
      return Rejects;
   end Rejection_Count;

   function River_Length (Seed : Seed_Value; Which : River_Index) return Natural is
   begin
      Ensure_World (Seed);
      return River_Lens (Which);
   end River_Length;

   function River_Step
     (Seed : Seed_Value; Which : River_Index; Step : Natural) return Spot
   is
   begin
      Ensure_World (Seed);
      if Step in 1 .. River_Lens (Which) then
         return River_Paths (Which) (Step);
      end if;
      return (X => 0, Y => 0);
   end River_Step;

   function On_River (Seed : Seed_Value; X, Y : Coord) return Boolean is
      Side : Integer;
   begin
      Ensure_World (Seed);
      for Which in River_Index loop
         for Step in 1 .. River_Lens (Which) loop
            if River_Paths (Which) (Step).X = X
              and then River_Paths (Which) (Step).Y = Y
            then
               return True;
            end if;
            if River_Wide (Which, Step) >= 2 then
               Side := Integer (River_Paths (Which) (Step).X) + 1;
               if Side in Coord
                 and then Coord (Side) = X
                 and then River_Paths (Which) (Step).Y = Y
               then
                  return True;
               end if;
            end if;
         end loop;
      end loop;
      return False;
   end On_River;

   function Drinkable (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      if Height (Seed, X, Y) = 0 or else On_River (Seed, X, Y) then
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
