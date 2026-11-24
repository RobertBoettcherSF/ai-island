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

   --  Water that touches sand. Fish live in a few of these cells.
   function Shallow (X, Y : Coord) return Boolean;

   Bush_Count : constant := 4;
   subtype Bush_Index is Integer range 1 .. Bush_Count;
   Fish_Count : constant := 3;
   subtype Fish_Index is Integer range 1 .. Fish_Count;

   type Spot is record
      X : Coord;
      Y : Coord;
   end record;

   --  Spread across the island, not only north of the start.
   --  Bush 1 is the short smoke walk: stand at 17,15 facing east.
   Bushes : constant array (Bush_Index) of Spot :=
     [1 => (X => 18, Y => 15),
      2 => (X => 12, Y => 22),
      3 => (X => 24, Y => 12),
      4 => (X => 14, Y => 24)];

   Fish : constant array (Fish_Index) of Spot :=
     [1 => (X => 30, Y => 17),
      2 => (X => 1, Y => 22),
      3 => (X => 12, Y => 30)];

   Berry_Gain   : constant := 25;
   Fish_Gain    : constant := 40;
   Regrow_Turns : constant := 40;

   --  True when the fixed map still matches the walk the browser Auto button
   --  performs: north from the start, through the stone, onto the beach.
   function Layout_Ok return Boolean;

end Island.Map;
