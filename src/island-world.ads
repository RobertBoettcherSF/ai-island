-- World rules. Pass the state in; nothing here is global, and nothing
-- here reads a clock or a file.
with Island.Map;
with Island.Rng;
with Island.Stomach;

package Island.World is

   Save_Max : constant := 65536;

   --  The 0.3.1 run pinned at 35 because only 36 slots existed and the
   --  player's slot is never reused. Homes, not this array, limit births.
   Max_Folk : constant := 150;
   subtype Folk_Id is Integer range 1 .. Max_Folk;
   Player_Id : constant Folk_Id := 1;
   Npc_Count : constant := 12;
   Group_Count : constant := 4;
   subtype Group_Id is Integer range 1 .. Group_Count;
   Adult_Age : constant := 150;
   Max_Age : constant := 360;
   Max_Homes : constant := 16;
   subtype Home_Id is Integer range 1 .. Max_Homes;
   Home_Capacity : constant := 4;
   Max_Piles : constant := 8;
   subtype Pile_Id is Integer range 1 .. Max_Piles;
   Max_Notes : constant := 12;
   subtype Note_Id is Integer range 1 .. Max_Notes;
   Trust_Max : constant := 12;
   Max_Trails : constant := 48;
   subtype Trail_Id is Integer range 1 .. Max_Trails;
   Max_Roads : constant := 16;
   subtype Road_Id is Integer range 1 .. Max_Roads;
   Max_Markets : constant := 4;
   subtype Market_Id is Integer range 1 .. Max_Markets;

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
      Group      : Group_Id := 1;
      Home       : Natural := 0;
      Sticks     : Natural := 0;
      Stones     : Natural := 0;
      Food       : Natural := 0;
      Fish       : Natural := 0;
      Scout      : Boolean := False;
      Migrate    : Natural := 0;
      Sp_A       : Natural := 1;
      Sp_B       : Natural := 1;
      Si_A       : Natural := 2;
      Si_B       : Natural := 2;
      Me_A       : Natural := 1;
      Me_B       : Natural := 1;
      Fe_A       : Natural := 2;
      Fe_B       : Natural := 2;
      Col_A      : Natural := 0;
      Col_B      : Natural := 0;
      Thirst     : Natural := 0;
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

   type Home_Kind is (Cave, Hut);

   type Home_Rec is record
      Used     : Boolean := False;
      Kind     : Home_Kind := Cave;
      Group    : Group_Id := 1;
      X        : Coord := 0;
      Y        : Coord := 0;
      Capacity : Natural := Home_Capacity;
      Berries  : Natural := 0;
      Fish     : Natural := 0;
      Sticks   : Natural := 0;
      Stones   : Natural := 0;
   end record;

   type Home_Array is array (Home_Id) of Home_Rec;

   type Pile_Kind is (Stick_Pile, Stone_Pile);

   type Pile_Rec is record
      Kind  : Pile_Kind := Stick_Pile;
      X     : Coord := 0;
      Y     : Coord := 0;
      Count : Natural := 0;
   end record;

   type Pile_Array is array (Pile_Id) of Pile_Rec;

   --  Extinct_Cause: 0 none, 1 starvation, 2 old age, 3 no space.
   type From_Array is array (Group_Id) of Natural;

   type Group_Rec is record
      Births         : Natural := 0;
      Deaths         : Natural := 0;
      Extinct_Turn   : Natural := 0;
      Extinct_Cause  : Natural := 0;
      Trades         : Natural := 0;
      Migrants_In    : Natural := 0;
      Migrants_Out   : Natural := 0;
      Came_From      : From_Array := [others => 0];
   end record;

   type Note_Kind is (Note_Food, Note_Home, Note_Stick, Note_Stone);

   type Note_Rec is record
      Known : Boolean := False;
      Kind  : Note_Kind := Note_Food;
      X     : Coord := 0;
      Y     : Coord := 0;
   end record;

   type Note_Row is array (Note_Id) of Note_Rec;
   type Note_Book is array (Group_Id) of Note_Row;
   type Trust_Row is array (Group_Id) of Natural;
   type Trust_Table is array (Group_Id) of Trust_Row;

   type Trail_Rec is record
      Used     : Boolean := False;
      X        : Coord := 0;
      Y        : Coord := 0;
      Strength : Natural := 0;
      Group    : Group_Id := 1;
      --  A second group that walked the same tile. 0 means none.
      Other    : Natural := 0;
   end record;

   type Trail_Array is array (Trail_Id) of Trail_Rec;

   type Road_Rec is record
      Used : Boolean := False;
      X    : Coord := 0;
      Y    : Coord := 0;
      Life : Natural := 0;
   end record;

   type Road_Array is array (Road_Id) of Road_Rec;

   type Market_Rec is record
      Used    : Boolean := False;
      X       : Coord := 0;
      Y       : Coord := 0;
      Berries : Natural := 0;
      Fish    : Natural := 0;
      Sticks  : Natural := 0;
      Stones  : Natural := 0;
      Trades  : Natural := 0;
   end record;

   type Market_Array is array (Market_Id) of Market_Rec;

   type Group_Array is array (Group_Id) of Group_Rec;

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
      Size_Code   : Natural := 3;
      Pole_Code   : Natural := 0;
      Preset_Code : Natural := 0;
      Homes       : Home_Array;
      Piles       : Pile_Array;
      Groups      : Group_Array;
      Trust       : Trust_Table := [others => [others => 2]];
      Notes       : Note_Book;
      Trails      : Trail_Array;
      Roads       : Road_Array;
      Markets     : Market_Array;
      Meetings    : Natural := 0;
      --  Folk decisions draw from this stream. It starts at the population seed.
      Folk_Rng    : Rng.State := Rng.Init (0);
   end record;

   function Standable (S : State; X, Y : Coord) return Boolean;

   function Home_At (S : State; X, Y : Coord) return Natural;

   function Home_Residents (S : State; H : Home_Id) return Natural;

   function Group_Population (S : State; G : Group_Id) return Natural;

   function Group_Home_Count (S : State; G : Group_Id) return Natural;

   function Valid (S : State) return Boolean;

   function Title_Of (Population : Natural) return Natural;

   function Diplomacy (S : State; A, B : Group_Id) return Natural;

   function Folk_Value (S : State; Who : Folk_Id; Which : Natural) return Natural;

   function Name_Syl (S : State; Group : Group_Id; Which : Natural) return Natural;

   function Trail_Span (S : State) return Natural;

   function Trail_Peak (S : State) return Natural;

   procedure Reset
     (S           : out State;
      Island_Seed : Map.Seed_Value := Map.Default_Island_Seed;
      Pop_Seed    : Map.Seed_Value := Map.Default_Pop_Seed;
      Size_Code   : Natural := 3;
      Pole_Code   : Natural := 0;
      Preset_Code : Natural := 0)
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

   function Group_Average (S : State; G : Group_Id; Which : Trait_Query) return Natural;

   --  Versioned text image of the state. The native runner writes the bytes;
   --  this package does not open a file.
   procedure Write_Save (S : State; Buf : out String; Len : out Natural)
     with Pre =>
       Valid (S) and then Buf'First = 1 and then Buf'Length >= Save_Max,
          Post => Valid (S) and then Len <= Buf'Length;

   procedure Read_Save (Buf : String; S : out State; Ok : out Boolean)
     with Post => (if Ok then Valid (S));

end Island.World;
