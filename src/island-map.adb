package body Island.Map is

   function Hash (X, Y : Coord) return Natural is
      use Interfaces;
      H : Unsigned_32 := Seed xor 16#9E37_79B9#;
   begin
      H := H xor Unsigned_32 (X) * 16#85EB_CA6B#;
      H := H xor Shift_Right (H, 13);
      H := H xor Unsigned_32 (Y) * 16#C2B2_AE35#;
      H := H xor Shift_Right (H, 16);
      return Natural (H mod 1024);
   end Hash;

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

   function Reserved (X, Y : Coord) return Boolean;

   function Terrain_At (X, Y : Coord) return Terrain is
      H : constant Natural := Hash (X, Y);
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
      if Clearing (X, Y) or else Reserved (X, Y) then
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

   function Sand_Beside (X, Y : Coord) return Boolean is
   begin
      if X > Coord'First and then Terrain_At (X - 1, Y) = Sand then
         return True;
      end if;
      if X < Coord'Last and then Terrain_At (X + 1, Y) = Sand then
         return True;
      end if;
      if Y > Coord'First and then Terrain_At (X, Y - 1) = Sand then
         return True;
      end if;
      if Y < Coord'Last and then Terrain_At (X, Y + 1) = Sand then
         return True;
      end if;
      return False;
   end Sand_Beside;

   function Shallow (X, Y : Coord) return Boolean is
   begin
      return Terrain_At (X, Y) = Water and then Sand_Beside (X, Y);
   end Shallow;

   function Reserved (X, Y : Coord) return Boolean is
   begin
      for I in Bush_Index loop
         if Bush (I).X = X and then Bush (I).Y = Y then
            return True;
         end if;
      end loop;
      for N in Npc_Index loop
         if Npc_Home (N).X = X and then Npc_Home (N).Y = Y then
            return True;
         end if;
      end loop;
      return False;
   end Reserved;

   function Npc_Home (N : Npc_Index) return Spot is
      G : constant Grove_Index := Grove_Index ((N + 1) / 2);
      P : constant Spot := Groves (G);
   begin
      if N mod 2 = 1 then
         return (X => P.X + 2, Y => P.Y + 2);
      end if;
      return (X => P.X + 3, Y => P.Y + 2);
   end Npc_Home;

   function Bush (I : Bush_Index) return Spot is
      G : constant Grove_Index := Grove_Index ((Integer (I) - 1) / Bushes_Per_Grove + 1);
      K : constant Integer := (Integer (I) - 1) mod Bushes_Per_Grove;
      P : constant Spot := Groves (G);
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
   end Bush;

   function Fish_At (I : Fish_Index) return Spot is
   begin
      case I is
         when 1 =>
            return (X => Pond_X, Y => Pond_Y);
         when 2 =>
            return (X => 57, Y => 62);
         when 3 =>
            return (X => 83, Y => 62);
         when 4 =>
            return (X => 70, Y => 54);
      end case;
   end Fish_At;

   function Layout_Ok return Boolean is
   begin
      pragma Assert (Terrain_At (Start_X, Start_Y) = Grass);
      pragma Assert (Terrain_At (Berry_X, Berry_Y) = Grass);
      pragma Assert (Walkable (Terrain_At (Stick_X, Stick_Y)));
      pragma Assert (Walkable (Terrain_At (Stone_X, Stone_Y)));
      pragma Assert (Walkable (Terrain_At (Shell_X, Shell_Y)));
      pragma Assert (Shallow (Pond_X, Pond_Y));
      for I in Bush_Index loop
         pragma Assert (Terrain_At (Bush (I).X, Bush (I).Y) = Grass);
         for J in Bush_Index loop
            if I /= J then
               pragma Assert
                 (Bush (I).X /= Bush (J).X or else Bush (I).Y /= Bush (J).Y);
            end if;
         end loop;
      end loop;
      for I in Fish_Index loop
         pragma Assert (Shallow (Fish_At (I).X, Fish_At (I).Y));
      end loop;
      pragma Assert (Groves (2).X /= Start_X or else Groves (2).Y /= Start_Y);
      return True;
   end Layout_Ok;

end Island.Map;
