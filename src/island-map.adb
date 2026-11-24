package body Island.Map is

   function Terrain_At (X, Y : Coord) return Terrain is
   begin
      --  Water is a full border inside the grid, so a step off the beach is
      --  blocked and stays in range.
      if X <= 1 or else X >= 30 or else Y <= 1 or else Y >= 30 then
         return Water;
      end if;
      if X <= 4 or else X >= 27 or else Y <= 4 or else Y >= 27 then
         return Sand;
      end if;
      --  Rocks and trees stay off the column x = 16, which is the demo walk.
      if (X = 12 and then Y = 12)
        or else (X = 20 and then Y = 18)
        or else (X = 15 and then Y = 22)
      then
         return Rock;
      end if;
      if (X = 10 and then Y = 10)
        or else (X = 18 and then Y = 14)
        or else (X = 14 and then Y = 20)
        or else (X = 22 and then Y = 16)
        or else (X = 11 and then Y = 18)
      then
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

   function Layout_Ok return Boolean is
   begin
      pragma Assert (Terrain_At (Start_X, Start_Y) = Grass);
      pragma Assert (Terrain_At (Stone_X, Stone_Y) = Grass);
      pragma Assert (Terrain_At (Beach_X, Beach_Y) = Sand);
      pragma Assert (Start_X = Beach_X);
      pragma Assert (Beach_Y < Stone_Y and then Stone_Y < Start_Y);
      for Y in Coord range Beach_Y .. Start_Y loop
         pragma Assert (Walkable (Terrain_At (Start_X, Y)));
      end loop;
      for I in Initial_Objects'Range loop
         pragma Assert
           (Walkable (Terrain_At (Initial_Objects (I).X, Initial_Objects (I).Y)));
         for J in Initial_Objects'Range loop
            if I /= J then
               pragma Assert
                 (Initial_Objects (I).X /= Initial_Objects (J).X
                  or else Initial_Objects (I).Y /= Initial_Objects (J).Y);
            end if;
         end loop;
      end loop;
      for I in Bush_Index loop
         pragma Assert (Terrain_At (Bushes (I).X, Bushes (I).Y) = Grass);
         for J in Bush_Index loop
            if I /= J then
               pragma Assert
                 (Bushes (I).X /= Bushes (J).X
                  or else Bushes (I).Y /= Bushes (J).Y);
            end if;
         end loop;
      end loop;
      for I in Fish_Index loop
         pragma Assert (Shallow (Fish (I).X, Fish (I).Y));
      end loop;
      --  Food is not a single northward line from the start.
      pragma Assert (Bushes (2).X /= Start_X);
      pragma Assert (Fish (1).X /= Start_X);
      pragma Assert (Bushes (1).Y /= Start_Y or else Bushes (1).X /= Start_X);
      return True;
   end Layout_Ok;

end Island.Map;
