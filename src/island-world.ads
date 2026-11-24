-- World rules. Pass the state in; nothing here is global, and nothing
-- here reads a clock or a file.
with Island.Map;

package Island.World is

   Save_Max : constant := 256;

   type Object_Rec is record
      Kind      : Object_Kind := Stone;
      X         : Coord := 0;
      Y         : Coord := 0;
      On_Ground : Boolean := True;
   end record;

   type Object_Array is array (Object_Index) of Object_Rec;

   type State is record
      X         : Coord := Map.Start_X;
      Y         : Coord := Map.Start_Y;
      Facing    : Direction := North;
      Hand      : Hand_Index := 0;
      Objects   : Object_Array;
      Said      : String (1 .. Said_Max) := [others => ' '];
      Said_Len  : Said_Count := 0;
   end record;

   function Valid (S : State) return Boolean;

   procedure Reset (S : out State)
     with Post =>
       Valid (S) and then Map.Layout_Ok
       and then S.X = Map.Start_X and then S.Y = Map.Start_Y
       and then S.Facing = North and then S.Hand = 0
       and then S.Said_Len = 0;

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

   --  Versioned text image of the state. The native runner writes the bytes;
   --  this package does not open a file.
   procedure Write_Save (S : State; Buf : out String; Len : out Natural)
     with Pre =>
       Valid (S) and then Buf'First = 1 and then Buf'Length >= Save_Max,
          Post => Valid (S) and then Len <= Buf'Length;

   procedure Read_Save (Buf : String; S : out State; Ok : out Boolean)
     with Post => (if Ok then Valid (S));

end Island.World;
