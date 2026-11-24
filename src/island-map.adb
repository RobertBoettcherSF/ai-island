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

   function Pick_Fish (Seed : Seed_Value; Which : Fish_Index) return Spot;

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
      else
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
      end if;
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
      Kind : Natural;
   begin
      if Pond (X, Y) then
         return Water;
      end if;
      if Pond_Shore (X, Y) then
         return Sand;
      end if;
      if Reserved (Seed, X, Y) or else Clearing (X, Y) then
         return Grass;
      end if;
      if Active_Size > 60
        and then ((X = 30 and then Y = 30) or else (X = 31 and then Y = 30)
                  or else (X = 16 and then Y in 16 .. 17)
                  or else (X = 18 and then Y in 18 .. 19)
                  or else (X = 41 and then Y = 40) or else (X = 40 and then Y = 40))
      then
         return Grass;
      end if;
      Kind := Biome (Seed, X, Y);
      case Kind is
         when 0 | 13 =>
            return Water;
         when 1 | 7 =>
            return Sand;
         when 4 =>
            return Rock;
         when 5 | 8 =>
            return Tree;
         when others =>
            return Grass;
      end case;
   end Terrain_At;

   function Walkable (Ground : Terrain) return Boolean is
   begin
      return Ground = Sand or else Ground = Grass or else Ground = Tree;
   end Walkable;

   function Sand_Beside (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      if X > Coord'First and then Walkable (Terrain_At (Seed, X - 1, Y)) then
         return True;
      end if;
      if X < Coord'Last and then Walkable (Terrain_At (Seed, X + 1, Y)) then
         return True;
      end if;
      if Y > Coord'First and then Walkable (Terrain_At (Seed, X, Y - 1)) then
         return True;
      end if;
      if Y < Coord'Last and then Walkable (Terrain_At (Seed, X, Y + 1)) then
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


   type Path is array (1 .. River_Max) of Spot;
   type Path_Set is array (River_Index) of Path;
   type Reg is record
      Kind : Natural := 0;
      A    : Natural := 0;
      B    : Natural := 0;
   end record;

   Act_N       : Positive := Default_Size;
   Act_Pole    : Natural := 0;
   Act_Preset  : Natural := 0;
   Act_Code    : Natural := 3;
   Elev        : array (Coord, Coord) of Integer := [others => [others => 0]];
   Rain_F      : array (Coord, Coord) of Natural := [others => [others => 40]];
   Drain_F     : array (Coord, Coord) of Natural := [others => [others => 50]];
   Sea         : array (Coord, Coord) of Boolean := [others => [others => False]];
   Lake        : array (Coord, Coord) of Boolean := [others => [others => False]];
   River_Paths : Path_Set;
   River_Lens  : array (River_Index) of Natural := [others => 0];
   World_Ready : Boolean := False;
   World_Seed  : Seed_Value := 0;
   World_Code  : Natural := 3;
   World_Pole  : Natural := 0;
   World_Pre   : Natural := 0;
   Rejects     : Natural := 0;
   Ranges      : Natural := 0;
   Reason_N    : Natural := 0;
   Reasons     : array (1 .. 8) of Natural := [others => 0];
   Lake_N      : Natural := 0;
   Lake_Tiles  : array (1 .. 2) of Natural := [others => 0];
   Reg_N       : Natural := 0;
   Regs        : array (1 .. Region_Max) of Reg := [others => (0, 0, 0)];

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

   function Cells_Of (Code : Natural) return Positive is
   begin
      case Code is
         when 0 =>
            return 17;
         when 1 =>
            return 33;
         when 2 =>
            return 65;
         when 4 =>
            return 257;
         when others =>
            return Default_Size;
      end case;
   end Cells_Of;

   procedure Use_Settings (Size_Code, Pole, Preset : Natural) is
      Code : Natural := Size_Code;
      P    : Natural := Pole;
      R    : Natural := Preset;
   begin
      if Code > 4 then
         Code := 3;
      end if;
      if P > 3 then
         P := 0;
      end if;
      if R > 2 then
         R := 0;
      end if;
      if World_Ready and then Code = World_Code and then P = World_Pole
        and then R = World_Pre
      then
         Act_Code := Code;
         Act_Pole := P;
         Act_Preset := R;
         Act_N := Cells_Of (Code);
         return;
      end if;
      Act_Code := Code;
      Act_Pole := P;
      Act_Preset := R;
      Act_N := Cells_Of (Code);
      World_Ready := False;
   end Use_Settings;

   function Active_Size return Positive is
   begin
      return Act_N;
   end Active_Size;

   function Size_Code return Natural is
   begin
      return Act_Code;
   end Size_Code;

   function Pole return Natural is
   begin
      return Act_Pole;
   end Pole;

   function Preset return Natural is
   begin
      return Act_Preset;
   end Preset;

   function In_Map (X, Y : Integer) return Boolean is
   begin
      return X in 0 .. Act_N - 1 and then Y in 0 .. Act_N - 1;
   end In_Map;

   function Edge_Dist (X, Y : Integer) return Integer is
   begin
      return Integer'Min
        (Integer'Min (X, Y), Integer'Min (Act_N - 1 - X, Act_N - 1 - Y));
   end Edge_Dist;

   function Smooth (A, B, T, Span : Integer) return Integer is
      W : Integer;
   begin
      if Span <= 1 then
         return A;
      end if;
      W := T * T * (3 * Span - 2 * T) / (Span * Span);
      W := Clamp (W, 0, Span);
      return (A * (Span - W) + B * W) / Span;
   end Smooth;

   procedure Add_Region (Kind, A, B : Natural) is
   begin
      if Reg_N < Region_Max then
         Reg_N := Reg_N + 1;
         Regs (Reg_N) := (Kind => Kind, A => A, B => B);
      end if;
   end Add_Region;

   procedure Note (Code : Natural) is
   begin
      if Reason_N < Reasons'Last then
         Reason_N := Reason_N + 1;
         Reasons (Reason_N) := Code;
      end if;
   end Note;

   procedure Generate (Gen : Seed_Value) is
      Elev_S  : Rng.State := Rng.Init (Rng.Mix (Interfaces.Unsigned_32 (Gen), 1, 0));
      Rain_S  : Rng.State := Rng.Init (Rng.Mix (Interfaces.Unsigned_32 (Gen), 2, 0));
      Drain_S : Rng.State := Rng.Init (Rng.Mix (Interfaces.Unsigned_32 (Gen), 3, 0));
      River_S : Rng.State := Rng.Init (Rng.Mix (Interfaces.Unsigned_32 (Gen), 4, 0));
      Name_S  : Rng.State := Rng.Init (Rng.Mix (Interfaces.Unsigned_32 (Gen), 5, 0));
      Coarse  : constant := 8;
      CMax    : constant := 40;
      Rain_C  : array (0 .. CMax, 0 .. CMax) of Integer := [others => [others => 40]];
      Drain_C : array (0 .. CMax, 0 .. CMax) of Integer := [others => [others => 50]];
      X, Y, NX, NY, Edge, V, CX, CY, TX, TY, Span : Integer;
      LX      : array (1 .. 2) of Integer := [others => 0];
      LY      : array (1 .. 2) of Integer := [others => 0];
      Queue_X : array (1 .. 8000) of Integer;
      Queue_Y : array (1 .. 8000) of Integer;
      Qh, Qt  : Natural;
      Seen    : array (Coord, Coord) of Boolean := [others => [others => False]];
      Row     : array (0 .. Max_Size - 1) of Integer;
      Springs : array (River_Index) of Spot;
      Step, BX, BY, Best, Score, Dist, Prev_H, H : Integer;
      Wide_Lake : Natural;
   begin
      Ranges := 1 + Rng.Below (Elev_S, 3);
      Reg_N := 0;
      Lake_N := 0;
      Lake_Tiles := [others => 0];
      for YY in Coord loop
         for XX in Coord loop
            Elev (XX, YY) := 0;
            Rain_F (XX, YY) := 40;
            Drain_F (XX, YY) := 50;
            Sea (XX, YY) := False;
            Lake (XX, YY) := False;
         end loop;
      end loop;

      for YY in 0 .. Act_N - 1 loop
         for XX in 0 .. Act_N - 1 loop
            Edge := Edge_Dist (XX, YY);
            if Edge <= 2 then
               Elev (Coord (XX), Coord (YY)) := 0;
            else
               V := 4 + Edge / 5
                 + Integer (Rng.Below (Elev_S, 5)) - 2;
               Elev (Coord (XX), Coord (YY)) := Clamp (V, 3, 24);
            end if;
         end loop;
      end loop;

      for R in 1 .. Ranges loop
         X := 4 + Integer (Rng.Below (Elev_S, Positive (Act_N - 8)));
         Y := 4 + Integer (Rng.Below (Elev_S, Positive (Act_N - 8)));
         for K in 0 .. 18 + Act_N / 10 loop
            if X in 3 .. Act_N - 4 and then Y in 3 .. Act_N - 4 then
               if K mod 11 = 7 then
                  V := 2;
               else
                  V := 6;
               end if;
               Elev (Coord (X), Coord (Y)) :=
                 Clamp (Elev (Coord (X), Coord (Y)) + V, 0, 28);
            end if;
            case Rng.Below (Elev_S, 4) is
               when 0 =>
                  Y := Y - 1;
               when 1 =>
                  X := X + 1;
               when 2 =>
                  Y := Y + 1;
               when others =>
                  X := X - 1;
            end case;
            X := Clamp (X, 3, Act_N - 4);
            Y := Clamp (Y, 3, Act_N - 4);
         end loop;
         Add_Region (1, Rng.Below (Name_S, 16), Rng.Below (Name_S, 16));
      end loop;

      for Pass in 1 .. 2 loop
         for YY in 1 .. Act_N - 2 loop
            for XX in 1 .. Act_N - 2 loop
               Row (XX) :=
                 (Elev (Coord (XX - 1), Coord (YY))
                  + Elev (Coord (XX), Coord (YY)) * 2
                  + Elev (Coord (XX + 1), Coord (YY))) / 4;
            end loop;
            for XX in 1 .. Act_N - 2 loop
               if Edge_Dist (XX, YY) > 2 then
                  Elev (Coord (XX), Coord (YY)) := Row (XX);
               end if;
            end loop;
         end loop;
      end loop;

      for YY in 1 .. Act_N - 2 loop
         for XX in 1 .. Act_N - 2 loop
            if Edge_Dist (XX, YY) > 2
              and then Elev (Coord (XX), Coord (YY))
                > Elev (Coord (XX), Coord (YY + 1)) + 2
            then
               Elev (Coord (XX), Coord (YY)) :=
                 Elev (Coord (XX), Coord (YY + 1)) + 2;
            end if;
            if Elev (Coord (XX), Coord (YY))
              >= Elev (Coord (XX + 1), Coord (YY)) + 3
            then
               Elev (Coord (XX), Coord (YY)) :=
                 Elev (Coord (XX), Coord (YY)) - 1;
            end if;
         end loop;
      end loop;

      Qh := 0;
      Qt := 0;
      for YY in 0 .. Act_N - 1 loop
         for XX in 0 .. Act_N - 1 loop
            if Edge_Dist (XX, YY) = 0 then
               Elev (Coord (XX), Coord (YY)) := 0;
               Sea (Coord (XX), Coord (YY)) := True;
               Qh := Qh + 1;
               Queue_X (Qh) := XX;
               Queue_Y (Qh) := YY;
            end if;
         end loop;
      end loop;

      while Qt < Qh loop
         Qt := Qt + 1;
         X := Queue_X (Qt);
         Y := Queue_Y (Qt);
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
            if In_Map (NX, NY) and then not Sea (Coord (NX), Coord (NY))
              and then Elev (Coord (NX), Coord (NY)) <= 1
            then
               Sea (Coord (NX), Coord (NY)) := True;
               Elev (Coord (NX), Coord (NY)) := 0;
               if Qh < Queue_X'Last then
                  Qh := Qh + 1;
                  Queue_X (Qh) := NX;
                  Queue_Y (Qh) := NY;
               end if;
            end if;
         end loop;
      end loop;
      for YY in 0 .. Act_N - 1 loop
         for XX in 0 .. Act_N - 1 loop
            if Sea (Coord (XX), Coord (YY)) and then Edge_Dist (XX, YY) > 3 then
               Sea (Coord (XX), Coord (YY)) := False;
               if Elev (Coord (XX), Coord (YY)) < 3 then
                  Elev (Coord (XX), Coord (YY)) := 3;
               end if;
            end if;
         end loop;
      end loop;

      for L in 1 .. 2 loop
         LX (L) := 8 + Integer (Rng.Below (River_S, Positive (Act_N - 16)));
         LY (L) := 8 + Integer (Rng.Below (River_S, Positive (Act_N - 16)));
         if Edge_Dist (LX (L), LY (L)) < 8 then
            LX (L) := Act_N / 2;
            LY (L) := Act_N / 3 + L * 4;
         end if;
         Wide_Lake := 0;
         for OY in -5 .. 5 loop
            for OX in -5 .. 5 loop
               NX := LX (L) + OX;
               NY := LY (L) + OY;
               if In_Map (NX, NY) and then abs OX + abs OY <= 4
                 and then not Sea (Coord (NX), Coord (NY))
                 and then Wide_Lake < 120
               then
                  Elev (Coord (NX), Coord (NY)) := 0;
                  Lake (Coord (NX), Coord (NY)) := True;
                  Wide_Lake := Wide_Lake + 1;
               elsif In_Map (NX, NY) and then abs OX + abs OY = 5
                 and then not Sea (Coord (NX), Coord (NY))
                 and then not Lake (Coord (NX), Coord (NY))
               then
                  if Elev (Coord (NX), Coord (NY)) < 3 then
                     Elev (Coord (NX), Coord (NY)) := 3;
                  end if;
               end if;
            end loop;
         end loop;
         if Wide_Lake > 0 then
            Lake_N := Lake_N + 1;
            Lake_Tiles (Lake_N) := Wide_Lake;
            Add_Region (2, Rng.Below (Name_S, 16), Rng.Below (Name_S, 16));
         end if;
      end loop;

      Span := Coarse;
      for IY in 0 .. (Act_N - 1) / Coarse loop
         for IX in 0 .. (Act_N - 1) / Coarse loop
            Rain_C (IX, IY) := 28 + Integer (Rng.Below (Rain_S, 40));
            Drain_C (IX, IY) := 15 + Integer (Rng.Below (Drain_S, 70));
         end loop;
      end loop;
      for YY in 0 .. Act_N - 1 loop
         for XX in 0 .. Act_N - 1 loop
            CX := XX / Coarse;
            CY := YY / Coarse;
            TX := XX mod Coarse;
            TY := YY mod Coarse;
            if CX >= CMax then
               CX := CMax - 1;
            end if;
            if CY >= CMax then
               CY := CMax - 1;
            end if;
            V := Smooth
              (Smooth (Rain_C (CX, CY), Rain_C (CX + 1, CY), TX, Span),
               Smooth (Rain_C (CX, CY + 1), Rain_C (CX + 1, CY + 1), TX, Span),
               TY, Span);
            V := V + (Act_N - XX) * 8 / Act_N;
            if Act_Preset = 1 then
               V := V + 12;
            elsif Act_Preset = 2 then
               V := V - 12;
            end if;
            Rain_F (Coord (XX), Coord (YY)) := Natural (Clamp (V, 12, 95));
            V := Smooth
              (Smooth (Drain_C (CX, CY), Drain_C (CX + 1, CY), TX, Span),
               Smooth (Drain_C (CX, CY + 1), Drain_C (CX + 1, CY + 1), TX, Span),
               TY, Span);
            Drain_F (Coord (XX), Coord (YY)) := Natural (Clamp (V, 5, 95));
         end loop;
      end loop;

      for Q in River_Index loop
         BX := Integer'Max (8, Act_N / 8);
         BY := BX;
         if Q = 2 or else Q = 4 then
            BX := Act_N - 1 - BX;
         end if;
         if Q = 3 or else Q = 4 then
            BY := Act_N - 1 - BY;
         end if;
         BX := Clamp
           (BX + Integer (Rng.Below (River_S, 7)) - 3, 4, Act_N - 5);
         BY := Clamp
           (BY + Integer (Rng.Below (River_S, 7)) - 3, 4, Act_N - 5);
         Best := -1;
         for OY in -4 .. 4 loop
            for OX in -4 .. 4 loop
               NX := BX + OX;
               NY := BY + OY;
               if In_Map (NX, NY)
                 and then Elev (Coord (NX), Coord (NY)) > Best
               then
                  Best := Elev (Coord (NX), Coord (NY));
                  X := NX;
                  Y := NY;
               end if;
            end loop;
         end loop;
         if Best < 8 then
            Elev (Coord (X), Coord (Y)) := 8;
         end if;
         Springs (Q) := (X => Coord (X), Y => Coord (Y));
      end loop;

      for Which in River_Index loop
         X := Integer (Springs (Which).X);
         Y := Integer (Springs (Which).Y);
         Step := 0;
         Seen := [others => [others => False]];
         Prev_H := Elev (Coord (X), Coord (Y));
         while Step < River_Max - 2 loop
            Step := Step + 1;
            River_Paths (Which) (Step) := (X => Coord (X), Y => Coord (Y));
            Seen (Coord (X), Coord (Y)) := True;
            exit when Lake (Coord (X), Coord (Y));
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
               if In_Map (NX, NY) and then not Seen (Coord (NX), Coord (NY)) then
                  Dist := abs (NX - LX (1)) + abs (NY - LY (1));
                  Score := Elev (Coord (NX), Coord (NY)) + Dist * 4;
                  if Lake (Coord (NX), Coord (NY)) then
                     Score := -1;
                  elsif Sea (Coord (NX), Coord (NY)) then
                     Score := Score + 500;
                  end if;
                  if Score < Best then
                     Best := Score;
                     BX := NX;
                     BY := NY;
                  end if;
               end if;
            end loop;
            exit when BX = X and then BY = Y;
            if Sea (Coord (BX), Coord (BY)) or else Lake (Coord (BX), Coord (BY)) then
               X := BX;
               Y := BY;
            else
               H := Elev (Coord (BX), Coord (BY));
               if H >= Prev_H then
                  H := Prev_H - 1;
                  if H < 1 then
                     H := 1;
                  end if;
                  Elev (Coord (BX), Coord (BY)) := H;
               end if;
               if Elev (Coord (BX), Coord (BY)) > Prev_H then
                  Elev (Coord (BX), Coord (BY)) := Prev_H;
               end if;
               Prev_H := Elev (Coord (BX), Coord (BY));
               X := BX;
               Y := BY;
            end if;
         end loop;
         if Step < River_Max and then not Sea (Coord (X), Coord (Y))
           and then not Lake (Coord (X), Coord (Y))
         then
            Elev (Coord (X), Coord (Y)) := 0;
            Lake (Coord (X), Coord (Y)) := True;
         end if;
         River_Lens (Which) := Step;
         Add_Region (3, Rng.Below (Name_S, 16), Rng.Below (Name_S, 16));
      end loop;

      if Act_N > 60 then
         for YY in 0 .. Act_N - 1 loop
            for XX in 0 .. Act_N - 1 loop
               if XX <= 2 or else YY <= 2 or else XX >= Act_N - 3
                 or else YY >= Act_N - 3
               then
                  if not (XX = Pond_X and then YY = Pond_Y) then
                     Elev (Coord (XX), Coord (YY)) := 0;
                     Sea (Coord (XX), Coord (YY)) := True;
                     Lake (Coord (XX), Coord (YY)) := False;
                  end if;
               end if;
            end loop;
         end loop;
         for OY in -4 .. 4 loop
            for OX in -4 .. 4 loop
               NX := Integer (Start_X) + OX;
               NY := Integer (Start_Y) + OY;
               if In_Map (NX, NY) and then not Pond (Coord (NX), Coord (NY)) then
                  Elev (Coord (NX), Coord (NY)) := 6;
                  Sea (Coord (NX), Coord (NY)) := False;
                  Lake (Coord (NX), Coord (NY)) := False;
               end if;
            end loop;
         end loop;
         if In_Map (Integer (Pond_X), Integer (Pond_Y)) then
            Elev (Pond_X, Pond_Y) := 0;
            Sea (Pond_X, Pond_Y) := False;
            Lake (Pond_X, Pond_Y) := True;
         end if;
         if In_Map (3, Integer (Start_Y)) then
            Elev (3, Start_Y) := 5;
            Sea (3, Start_Y) := False;
            Lake (3, Start_Y) := False;
         end if;
         declare
            type Pin is record
               X, Y : Coord;
            end record;
            Pins : constant array (1 .. 8) of Pin :=
              [1 => (30, 30), 2 => (31, 30), 3 => (18, 18),
               4 => (18, 19), 5 => (41, 40), 6 => (40, 40),
               7 => (16, 16), 8 => (16, 17)];
         begin
            for I in Pins'Range loop
               if In_Map (Integer (Pins (I).X), Integer (Pins (I).Y)) then
                  Elev (Pins (I).X, Pins (I).Y) := 6;
                  Sea (Pins (I).X, Pins (I).Y) := False;
                  Lake (Pins (I).X, Pins (I).Y) := False;
               end if;
            end loop;
         end;
         for Which in River_Index loop
            if River_Lens (Which) >= 2 then
               for S in 1 .. River_Lens (Which) - 1 loop
                  if Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) < 1
                    and then not Lake (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
                    and then not Sea (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
                  then
                     Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) := 1;
                  end if;
               end loop;
               for S in 2 .. River_Lens (Which) loop
                  if not Sea (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
                    and then not Lake (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
                    and then Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
                      > Elev (River_Paths (Which) (S - 1).X,
                              River_Paths (Which) (S - 1).Y)
                  then
                     Elev (River_Paths (Which) (S).X, River_Paths (Which) (S).Y) :=
                       Elev (River_Paths (Which) (S - 1).X,
                             River_Paths (Which) (S - 1).Y);
                  end if;
               end loop;
            end if;
         end loop;
      end if;

      for F in 1 .. 4 loop
         X := 6 + Integer (Rng.Below (Name_S, Positive (Act_N - 12)));
         Y := 6 + Integer (Rng.Below (Name_S, Positive (Act_N - 12)));
         if In_Map (X, Y) and then not Sea (Coord (X), Coord (Y))
           and then Rain_F (Coord (X), Coord (Y)) >= 50
         then
            Add_Region (4, Rng.Below (Name_S, 16), Rng.Below (Name_S, 16));
         end if;
      end loop;
   end Generate;

   function Map_Ok return Boolean is
      Land, Live, Prev, Here : Natural;
      Camps : Natural := 0;
   begin
      if Ranges < 1 then
         Note (1);
         return False;
      end if;
      for Which in River_Index loop
         if River_Lens (Which) < 3 then
            Note (2);
            return False;
         end if;
         if not Sea (River_Paths (Which) (River_Lens (Which)).X,
                     River_Paths (Which) (River_Lens (Which)).Y)
           and then not Lake (River_Paths (Which) (River_Lens (Which)).X,
                              River_Paths (Which) (River_Lens (Which)).Y)
         then
            Note (2);
            return False;
         end if;
         Prev := Natural (Elev (River_Paths (Which) (1).X,
                                River_Paths (Which) (1).Y));
         for S in 2 .. River_Lens (Which) loop
            Here := Natural (Elev (River_Paths (Which) (S).X,
                                   River_Paths (Which) (S).Y));
            if Here > Prev
              and then not Sea (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
              and then not Lake (River_Paths (Which) (S).X, River_Paths (Which) (S).Y)
            then
               Note (3);
               return False;
            end if;
            Prev := Here;
         end loop;
      end loop;
      Land := 0;
      Live := 0;
      for YY in 0 .. Act_N - 1 loop
         for XX in 0 .. Act_N - 1 loop
            if not Sea (Coord (XX), Coord (YY))
              and then not Lake (Coord (XX), Coord (YY))
            then
               Land := Land + 1;
               if Rain_F (Coord (XX), Coord (YY)) >= 28
                 and then Elev (Coord (XX), Coord (YY)) < 18
               then
                  Live := Live + 1;
               end if;
            end if;
         end loop;
      end loop;
      if Land * 3 < Act_N * Act_N then
         Note (5);
         return False;
      end if;
      if Live * 2 < Land then
         Note (6);
         return False;
      end if;
      if Act_N > 90 then
         if not Sea (18, 18) then
            Camps := Camps + 1;
         end if;
         if In_Map (Act_N - 19, 18) and then not Sea (Coord (Act_N - 19), 18) then
            Camps := Camps + 1;
         end if;
         if In_Map (18, Act_N - 19) and then not Sea (18, Coord (Act_N - 19)) then
            Camps := Camps + 1;
         end if;
         if In_Map (Act_N - 19, Act_N - 19)
           and then not Sea (Coord (Act_N - 19), Coord (Act_N - 19))
         then
            Camps := Camps + 1;
         end if;
      else
         Camps := 4;
      end if;
      if Camps < 4 then
         Note (4);
         return False;
      end if;
      return True;
   end Map_Ok;

   procedure Ensure_World (Seed : Seed_Value) is
      Gen : Seed_Value;
   begin
      if World_Ready and then World_Seed = Seed and then World_Code = Act_Code
        and then World_Pole = Act_Pole and then World_Pre = Act_Preset
      then
         return;
      end if;
      Rejects := 0;
      Reason_N := 0;
      Reasons := [others => 0];
      Gen := Seed;
      for Try in 1 .. 6 loop
         Generate (Gen);
         exit when Map_Ok;
         Rejects := Rejects + 1;
         Gen := Seed_Value (Rng.Mix (Interfaces.Unsigned_32 (Seed),
                                     Interfaces.Unsigned_32 (Try), 17) mod 1_000_000_000);
      end loop;
      World_Seed := Seed;
      World_Code := Act_Code;
      World_Pole := Act_Pole;
      World_Pre := Act_Preset;
      World_Ready := True;
   end Ensure_World;

   function Land_Ok (Seed : Seed_Value; X, Y : Integer) return Boolean is
   begin
      if not In_Map (X, Y) then
         return False;
      end if;
      Ensure_World (Seed);
      return Elev (Coord (X), Coord (Y)) in 3 .. 16
        and then not Sea (Coord (X), Coord (Y))
        and then not Lake (Coord (X), Coord (Y));
   end Land_Ok;

   function Height (Seed : Seed_Value; X, Y : Coord) return Natural is
   begin
      Ensure_World (Seed);
      if not In_Map (Integer (X), Integer (Y)) then
         return 0;
      end if;
      if Elev (X, Y) < 0 then
         return 0;
      end if;
      return Natural (Elev (X, Y));
   end Height;

   function Mountain (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      return Height (Seed, X, Y) >= 18;
   end Mountain;

   function Neighbour_H
     (Seed : Seed_Value; X, Y, DX, DY : Integer) return Natural
   is
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
   begin
      if H < 8 then
         return False;
      end if;
      return (Neighbour_H (Seed, Integer (X), Integer (Y), 0, -1) > H
              and then Neighbour_H (Seed, Integer (X), Integer (Y), 0, 1) > H)
        or else (Neighbour_H (Seed, Integer (X), Integer (Y), 1, 0) > H
                 and then Neighbour_H (Seed, Integer (X), Integer (Y), -1, 0) > H);
   end Pass;

   function Uphill
     (Seed : Seed_Value; X, Y, NX, NY : Coord) return Boolean
   is
   begin
      return Height (Seed, NX, NY) >= Height (Seed, X, Y) + 2
        and then not Pass (Seed, NX, NY);
   end Uphill;

   function Rain (Seed : Seed_Value; X, Y : Coord) return Natural is
   begin
      Ensure_World (Seed);
      if not In_Map (Integer (X), Integer (Y)) then
         return 0;
      end if;
      return Rain_F (X, Y);
   end Rain;

   function Drainage (Seed : Seed_Value; X, Y : Coord) return Natural is
   begin
      Ensure_World (Seed);
      if not In_Map (Integer (X), Integer (Y)) then
         return 0;
      end if;
      return Drain_F (X, Y);
   end Drainage;

   function Temperature (Seed : Seed_Value; X, Y : Coord) return Integer is
      Along : Integer;
   begin
      Ensure_World (Seed);
      if not In_Map (Integer (X), Integer (Y)) then
         return 0;
      end if;
      case Act_Pole is
         when 1 =>
            Along := Act_N - 1 - Integer (Y);
         when 2 =>
            Along := Integer (X);
         when 3 =>
            Along := Act_N - 1 - Integer (X);
         when others =>
            Along := Integer (Y);
      end case;
      return 10 + Along * 80 / (Act_N - 1) - Elev (X, Y) / 3;
   end Temperature;

   function Biome (Seed : Seed_Value; X, Y : Coord) return Natural is
      H : Integer;
      R : Natural;
      D : Natural;
      T : Integer;
   begin
      Ensure_World (Seed);
      if not In_Map (Integer (X), Integer (Y)) then
         return 0;
      end if;
      if Sea (X, Y) then
         return 0;
      end if;
      if Lake (X, Y) or else Elev (X, Y) <= 0 then
         return 13;
      end if;
      H := Elev (X, Y);
      if H <= 4 then
         if (Integer (X) > 0 and then Sea (Coord (Integer (X) - 1), Y))
           or else (Integer (X) + 1 < Act_N and then Sea (Coord (Integer (X) + 1), Y))
           or else (Integer (Y) > 0 and then Sea (X, Coord (Integer (Y) - 1)))
           or else (Integer (Y) + 1 < Act_N and then Sea (X, Coord (Integer (Y) + 1)))
         then
            return 1;
         end if;
      end if;
      if H >= 18 then
         return 4;
      end if;
      R := Rain_F (X, Y);
      D := Drain_F (X, Y);
      T := Temperature (Seed, X, Y);
      if T <= -5 then
         if R < 30 then
            return 2;
         end if;
         return 3;
      end if;
      if H >= 13 then
         return 9;
      end if;
      if R >= 65 and then D < 40 then
         return 5;
      end if;
      if R < 22 then
         return 7;
      end if;
      if T in -4 .. 9 and then R >= 35 then
         return 8;
      end if;
      if T >= 85 and then R >= 48 then
         return 8;
      end if;
      if R >= 52 and then D >= 42 then
         return 8;
      end if;
      if T >= 66 and then R in 32 .. 55 then
         return 11;
      end if;
      if R < 38 then
         return 10;
      end if;
      if D < 38 then
         return 6;
      end if;
      return 12;
   end Biome;

   function Fertile (Seed : Seed_Value; X, Y : Coord) return Boolean is
   begin
      return Food_Yield (Seed, X, Y) >= 3
        and then (On_River (Seed, X, Y)
                  or else (X > Coord'First and then On_River (Seed, X - 1, Y))
                  or else (Y > Coord'First and then On_River (Seed, X, Y - 1)));
   end Fertile;

   function Food_Yield (Seed : Seed_Value; X, Y : Coord) return Natural is
   begin
      case Biome (Seed, X, Y) is
         when 8 =>
            return 5;
         when 12 =>
            return 4;
         when 11 =>
            return 3;
         when 6 | 9 | 10 =>
            return 2;
         when 1 | 3 | 5 =>
            return 1;
         when others =>
            return 0;
      end case;
   end Food_Yield;

   function Thirst_Cost (Seed : Seed_Value; X, Y : Coord) return Natural is
   begin
      if Biome (Seed, X, Y) = 7 then
         return 2;
      end if;
      return 1;
   end Thirst_Cost;

   function Settle_Score (Seed : Seed_Value; X, Y : Coord) return Natural is
      Score : Natural;
   begin
      Score := Food_Yield (Seed, X, Y) * 5;
      if Drinkable (Seed, X, Y) then
         Score := Score + 8;
      end if;
      if Biome (Seed, X, Y) = 1 then
         Score := Score + 2;
      end if;
      if Height (Seed, X, Y) in 4 .. 10 then
         Score := Score + 3;
      end if;
      return Score;
   end Settle_Score;

   function Lake_Count (Seed : Seed_Value) return Natural is
   begin
      Ensure_World (Seed);
      return Lake_N;
   end Lake_Count;

   function Lake_Area (Seed : Seed_Value; Which : Natural) return Natural is
   begin
      Ensure_World (Seed);
      if Which in 1 .. Lake_N then
         return Lake_Tiles (Which);
      end if;
      return 0;
   end Lake_Area;

   function Rejection_Count (Seed : Seed_Value) return Natural is
   begin
      Ensure_World (Seed);
      return Rejects;
   end Rejection_Count;

   function Reason_Count (Seed : Seed_Value) return Natural is
   begin
      Ensure_World (Seed);
      return Reason_N;
   end Reason_Count;

   function Reason_Code (Seed : Seed_Value; Index : Natural) return Natural is
   begin
      Ensure_World (Seed);
      if Index in 1 .. Reason_N then
         return Reasons (Index);
      end if;
      return 0;
   end Reason_Code;

   function Region_Count (Seed : Seed_Value) return Natural is
   begin
      Ensure_World (Seed);
      return Reg_N;
   end Region_Count;

   function Region_Kind (Seed : Seed_Value; Index : Natural) return Natural is
   begin
      Ensure_World (Seed);
      if Index in 1 .. Reg_N then
         return Regs (Index).Kind;
      end if;
      return 0;
   end Region_Kind;

   function Region_A (Seed : Seed_Value; Index : Natural) return Natural is
   begin
      Ensure_World (Seed);
      if Index in 1 .. Reg_N then
         return Regs (Index).A;
      end if;
      return 0;
   end Region_A;

   function Region_B (Seed : Seed_Value; Index : Natural) return Natural is
   begin
      Ensure_World (Seed);
      if Index in 1 .. Reg_N then
         return Regs (Index).B;
      end if;
      return 0;
   end Region_B;

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
   begin
      Ensure_World (Seed);
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
      if Biome (Seed, X, Y) = 13 then
         return True;
      end if;
      if On_River (Seed, X, Y) then
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

   function Pick_Fish (Seed : Seed_Value; Which : Fish_Index) return Spot is
      Seen : Natural := 0;
      Need : Natural;
      Bank : Boolean;

      function Bush_Cell (X, Y : Integer) return Boolean is
         P : Spot;
      begin
         for G in Grove_Index loop
            for K in 0 .. 7 loop
               P := Bush_Off (Groves (G), K);
               if Integer (P.X) = X and then Integer (P.Y) = Y then
                  return True;
               end if;
            end loop;
         end loop;
         return False;
      end Bush_Cell;
   begin
      Ensure_World (Seed);
      if Which = 1 and then In_Map (Integer (Pond_X), Integer (Pond_Y)) then
         return (X => Pond_X, Y => Pond_Y);
      end if;
      Need := Which - 1;
      for YY in 1 .. Act_N - 2 loop
         for XX in 1 .. Act_N - 2 loop
            Bank := Elev (Coord (XX + 1), Coord (YY)) in 3 .. 16
              and then not Sea (Coord (XX + 1), Coord (YY))
              and then not Lake (Coord (XX + 1), Coord (YY));
            if Bank
              and then (Lake (Coord (XX), Coord (YY)) or else Sea (Coord (XX), Coord (YY)))
              and then not Bush_Cell (XX, YY)
            then
               Seen := Seen + 1;
               if Seen = Need then
                  return (X => Coord (XX), Y => Coord (YY));
               end if;
            end if;
         end loop;
      end loop;
      return (X => Pond_X, Y => Pond_Y);
   end Pick_Fish;

end Island.Map;
