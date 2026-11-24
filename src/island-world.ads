-- World rules. Pass the state in; nothing here is global, and nothing
-- here reads a clock or a file.
with Island.Map;
with Island.Stomach;

package Island.World is

   Save_Max : constant := 4096;

   Max_Folk : constant := 36;
   subtype Folk_Id is Integer range 1 .. Max_Folk;
   Player_Id : constant Folk_Id := 1;
   Npc_Count : constant := 12;
   Adult_Age : constant := 40;
   Max_Age : constant := 360;

   subtype Speed_T is Integer range 1 .. 3;
   subtype Sight_T is Integer range 2 .. 4;
   subtype Meta_T is Integer range 1 .. 3;
   subtype Fert_T is Integer range 1 .. 3;

   type Folk_Rec is record
      Alive      : Boolean := False;
      X          : Coord := 0;
      Y          : Coord := 0;
      Facing     : Direction := North;
      Belly      : Stomach.Levels;
      Age        : Natural := 0;
      Speed      : Speed_T := 1;
      Sight      : Sight_T := 3;
      Metabolism : Meta_T := 1;
      Fertility  : Fert_T := 2;
      Cool       : Natural := 0;
   end record;

   type Folk_Array is array (Folk_Id) of Folk_Rec;

   type Object_Rec is record
      Kind      : Object_Kind := Stone;
      X         : Coord := 0;
      Y         : Coord := 0;
      On_Ground : Boolean := True;
   end record;

   type Object_Array is array (Object_Index) of Object_Rec;

   --  0 means the bush is ripe. Otherwise the world turn when it was eaten.
   type Bush_Times is array (Map.Bush_Index) of Natural;

   type Food is (None, Berries, Bare, Fish);

   type State is record
      X          : Coord := Map.Start_X;
      Y          : Coord := Map.Start_Y;
      Facing     : Direction := North;
      Hand       : Hand_Index := 0;
      Objects    : Object_Array;
      Said       : String (1 .. Said_Max) := [others => ' '];
      Said_Len   : Said_Count := 0;
      Belly      : Stomach.Levels;
      Turn       : Natural := 0;
      Bush_Eaten : Bush_Times := [others => 0];
      Folk        : Folk_Array;
      Births      : Natural := 0;
      Deaths      : Natural := 0;
      Island_Seed : Map.Seed_Value := Map.Default_Island_Seed;
      Pop_Seed    : Map.Seed_Value := Map.Default_Pop_Seed;
   end record;

   function Valid (S : State) return Boolean;

   procedure Reset
     (S           : out State;
      Island_Seed : Map.Seed_Value := Map.Default_Island_Seed;
      Pop_Seed    : Map.Seed_Value := Map.Default_Pop_Seed)
     with Post =>
       Valid (S) and then Map.Layout_Ok
       and then S.X = Map.Start_X and then S.Y = Map.Start_Y
       and then S.Facing = North and then S.Hand = 0
       and then S.Said_Len = 0
       and then S.Turn = 0
       and then S.Belly.Full = Stomach.Max_Fullness
       and then not S.Belly.Collapsed
       and then S.Island_Seed = Island_Seed
       and then S.Pop_Seed = Pop_Seed;

   type Move_Result is (Moved, Blocked, Off_Map);

   procedure Try_Move
     (S      : in out State;
      Dir    : Direction;
      Result : out Move_Result;
      By     : out Terrain)
     with Pre => Valid (S),
          Post =>
            Valid (S)
            and then
              (if Result = Moved
               then S.Facing = Dir
                 and then S.Hand = S'Old.Hand
                 and then S.Objects = S'Old.Objects
                 and then S.Said_Len = S'Old.Said_Len
                 and then abs (Integer (S.X) - Integer (S'Old.X))
                   + abs (Integer (S.Y) - Integer (S'Old.Y)) = 1
               else S = S'Old);

   type Take_Result is (Took, Nothing_Here, Hand_Full);

   procedure Try_Pick (S : in out State; Result : out Take_Result)
     with Pre => Valid (S),
          Post =>
            Valid (S)
            and then
              (if Result = Took
               then S.Hand /= 0 and then S.Hand /= S'Old.Hand
               else S = S'Old);

   type Drop_Result is (Placed, Hand_Empty, Occupied);

   procedure Try_Place (S : in out State; Result : out Drop_Result)
     with Pre => Valid (S),
          Post =>
            Valid (S)
            and then (if Result /= Placed then S = S'Old else S.Hand = 0);

   type Say_Result is (Said_Ok, Too_Long, Not_Plain);

   procedure Try_Say
     (S : in out State; Text : String; Result : out Say_Result)
     with Pre => Valid (S),
          Post =>
            Valid (S)
            and then
              (if Result /= Said_Ok then S = S'Old
               elsif Text'Length = 0 then S.Said_Len = 0
               else S.Said_Len = Text'Length);

   type Eat_Result is (Ate_Berry, Ate_Fish, Nothing, Not_Ripe, Need_Stick);

   --  Eat the food in front. Does not advance the turn; the caller does.
   procedure Try_Eat (S : in out State; Result : out Eat_Result)
     with Pre => Valid (S) and then not S.Belly.Collapsed,
          Post => Valid (S);

   function Food_At (S : State; X, Y : Coord) return Food
     with Pre => Valid (S);

   function Collapsed (S : State) return Boolean
     with Pre => Valid (S);

   --  Call after Advance on the turn the berries were eaten.
   procedure Mark_Bush (S : in out State; X, Y : Coord)
     with Pre => Valid (S),
          Post => Valid (S);

   --  One action. A move that started while weak advances two turns.
   --  The other creatures act in the same step.
   procedure Advance
     (S        : in out State;
      Is_Move  : Boolean;
      Was_Weak : Boolean;
      Carrying : Boolean)
     with Pre => Valid (S) and then not S.Belly.Collapsed,
          Post => Valid (S) and then S.Turn > S'Old.Turn;

   --  Every creature, including the player, uses the built-in brain.
   procedure Simulate (S : in out State; Turns : Positive)
     with Pre => Valid (S),
          Post => Valid (S);

   function Alive_Count (S : State) return Natural;

   subtype Trait_Query is Integer range 1 .. 4;
   function Average_Milli (S : State; Which : Trait_Query) return Natural;

   --  Versioned text image of the state. The native runner writes the bytes;
   --  this package does not open a file.
   procedure Write_Save (S : State; Buf : out String; Len : out Natural)
     with Pre =>
       Valid (S) and then Buf'First = 1 and then Buf'Length >= Save_Max,
          Post => Valid (S) and then Len <= Buf'Length;

   procedure Read_Save (Buf : String; S : out State; Ok : out Boolean)
     with Post => (if Ok then Valid (S));

end Island.World;
