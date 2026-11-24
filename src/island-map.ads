-- Fixed island from one seed. Terrain is a function of the coordinates,
-- so a save file does not store the ground.
package Island.Map is

   --  The 0.3 island. Both seeds default to this, and either one can change.
   subtype Seed_Value is Natural;
   Default_Island_Seed : constant Seed_Value := 16#2026_1124#;
   Default_Pop_Seed    : constant Seed_Value := 16#2026_1124#;

   Start_X : constant Coord := 48;
   Start_Y : constant Coord := 48;
   Stone_X : constant Coord := 47;
   Stone_Y : constant Coord := 48;
   Stick_X : constant Coord := 49;
   Stick_Y : constant Coord := 48;
   Shell_X : constant Coord := 48;
   Shell_Y : constant Coord := 50;
   --  The smoke walk stands on 48,47 facing north and eats this bush.
   Berry_X : constant Coord := 48;
   Berry_Y : constant Coord := 46;
   --  Pond fish, west of the start. Stand on 46,48 facing west.
   Pond_X : constant Coord := 45;
   Pond_Y : constant Coord := 48;

   type Placed is record
      Kind : Object_Kind;
      X    : Coord;
      Y    : Coord;
   end record;

   Initial_Objects : constant array (Object_Index) of Placed :=
     [1 => (Kind => Stone, X => Stone_X, Y => Stone_Y),
      2 => (Kind => Stick, X => Stick_X, Y => Stick_Y),
      3 => (Kind => Shell, X => Shell_X, Y => Shell_Y)];

   function Terrain_At (Seed : Seed_Value; X, Y : Coord) return Terrain;

   function Walkable (Ground : Terrain) return Boolean;

   function Shallow (Seed : Seed_Value; X, Y : Coord) return Boolean;

   Grove_Count : constant := 8;
   subtype Grove_Index is Integer range 1 .. Grove_Count;
   Bushes_Per_Grove : constant := 8;
   Bush_Count : constant := Grove_Count * Bushes_Per_Grove;
   subtype Bush_Index is Integer range 1 .. Bush_Count;

   Fish_Count : constant := 4;
   subtype Fish_Index is Integer range 1 .. Fish_Count;

   type Spot is record
      X : Coord;
      Y : Coord;
   end record;

   Groves : constant array (Grove_Index) of Spot :=
     [1 => (X => 20, Y => 20),
      2 => (X => 20, Y => 74),
      3 => (X => 76, Y => 20),
      4 => (X => 76, Y => 74),
      5 => (X => 51, Y => 46),
      6 => (X => 70, Y => 36),
      7 => (X => 36, Y => 74),
      8 => (X => 62, Y => 78)];

   function Bush (Seed : Seed_Value; I : Bush_Index) return Spot;

   function Fish_At (Seed : Seed_Value; I : Fish_Index) return Spot;

   Npc_Total : constant := 12;
   subtype Npc_Index is Integer range 1 .. Npc_Total;
   function Npc_Home (Seed : Seed_Value; N : Npc_Index) return Spot;

   Berry_Gain   : constant := 25;
   Fish_Gain    : constant := 40;
   Regrow_Turns : constant := 10;

   function Layout_Ok return Boolean;

   --  Height is 0 on open water and rises away from the lake.
   --  Southern hills are higher, which is where the stones sit.
   function Height (Seed : Seed_Value; X, Y : Coord) return Natural;

   function Mountain (Seed : Seed_Value; X, Y : Coord) return Boolean;

   River_Count : constant := 4;
   subtype River_Index is Integer range 1 .. River_Count;
   River_Max : constant := 40;

   function River_Length (Seed : Seed_Value; Which : River_Index) return Natural;

   function River_Step
     (Seed : Seed_Value; Which : River_Index; Step : Natural) return Spot;

   function On_River (Seed : Seed_Value; X, Y : Coord) return Boolean;

   function Drinkable (Seed : Seed_Value; X, Y : Coord) return Boolean;

end Island.Map;
