-- Fixed island. Terrain is a function of the coordinates, so a save file
-- only has to remember the agent and the objects.
package Island.Map is

   Start_X : constant Coord := 16;
   Start_Y : constant Coord := 16;
   Stone_X : constant Coord := 16;
   Stone_Y : constant Coord := 15;
   Stick_X : constant Coord := 18;
   Stick_Y : constant Coord := 16;
   Shell_X : constant Coord := 16;
   Shell_Y : constant Coord := 27;
   --  North beach. The scripted walk picks up the stone and places it here.
   Beach_X : constant Coord := 16;
   Beach_Y : constant Coord := 4;

   type Placed is record
      Kind : Object_Kind;
      X    : Coord;
      Y    : Coord;
   end record;

   Initial_Objects : constant array (Object_Index) of Placed :=
     [1 => (Kind => Stone, X => Stone_X, Y => Stone_Y),
      2 => (Kind => Stick, X => Stick_X, Y => Stick_Y),
      3 => (Kind => Shell, X => Shell_X, Y => Shell_Y)];

   function Terrain_At (X, Y : Coord) return Terrain;

   function Walkable (Ground : Terrain) return Boolean;

   --  True when the fixed map still matches the walk the browser Auto button
   --  performs: north from the start, through the stone, onto the beach.
   function Layout_Ok return Boolean;

end Island.Map;
