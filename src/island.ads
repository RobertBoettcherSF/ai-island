-- Shared types for the island. No behaviour here: the world rules live in
-- the child packages, and they do not touch files or the browser.
package Island is

   Grid_Size : constant := 32;
   subtype Coord is Integer range 0 .. Grid_Size - 1;

   Max_Objects : constant := 3;
   subtype Object_Index is Integer range 1 .. Max_Objects;
   subtype Hand_Index is Integer range 0 .. Max_Objects;

   Said_Max : constant := 80;
   subtype Said_Count is Natural range 0 .. Said_Max;

   type Direction is (North, East, South, West);
   type Object_Kind is (Stone, Stick, Shell);
   type Terrain is (Water, Sand, Grass, Rock, Tree);

   Reply_Max : constant := 4096;
   subtype Reply_Buffer is String (1 .. Reply_Max);

   Command_Max : constant := 240;

end Island;
