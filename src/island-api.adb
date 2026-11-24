with Island.Map;
with Island.Text;
with Island.World;
with System;
with System.Storage_Elements;
use type Island.World.State;

package body Island.API is

   The_State  : World.State;
   Ready      : Boolean := False;
   Reply_Buf  : Reply_Buffer := [others => ' '];
   Reply_Used : Natural := 0;
   Last_Ok    : Boolean := False;
   Command_Buf : String (1 .. Command_Max) := [others => ' '];

   procedure Ensure is
   begin
      if not Ready then
         World.Reset (The_State);
         Ready := True;
      end if;
   end Ensure;

   procedure Reset is
   begin
      World.Reset (The_State);
      Ready := True;
   end Reset;

   procedure Run
     (Command : String;
      Reply   : out Reply_Buffer;
      Len     : out Natural;
      Ok      : out Boolean)
   is
   begin
      Ensure;
      Text.Execute (The_State, Command, False, Reply, Len, Ok);
      Reply_Buf := Reply;
      Reply_Used := Len;
      Last_Ok := Ok;
   end Run;

   procedure Exec (Length : Integer) is
   begin
      Ensure;
      if Length < 0 or else Length > Command_Max then
         Text.Write_Too_Long (Reply_Buf, Reply_Used, Last_Ok);
         return;
      end if;
      Text.Execute
        (The_State, Command_Buf (1 .. Length), False, Reply_Buf, Reply_Used, Last_Ok);
   end Exec;

   function Address_As_Int (Addr : System.Address) return Integer is
      use System.Storage_Elements;
      A : constant Integer_Address := To_Integer (Addr);
   begin
      --  Wasm32 offsets fit. A native address does not; the check fails there
      --  on purpose. The browser run is what calls these two functions.
      pragma Assert (A <= Integer_Address (Integer'Last));
      return Integer (A);
   end Address_As_Int;

   function Command_Ptr return Integer is
   begin
      return Address_As_Int (Command_Buf'Address);
   end Command_Ptr;

   function Reply_Ptr return Integer is
   begin
      return Address_As_Int (Reply_Buf'Address);
   end Reply_Ptr;

   function Reply_Len return Integer is
   begin
      return Integer (Reply_Used);
   end Reply_Len;

   function Cell (X, Y : Integer) return Integer is
   begin
      Ensure;
      if X not in Coord or else Y not in Coord then
         return -1;
      end if;
      return Terrain'Pos (Map.Terrain_At (Coord (X), Coord (Y)));
   end Cell;

   function Object_At (X, Y : Integer) return Integer is
   begin
      Ensure;
      if X not in Coord or else Y not in Coord then
         return -1;
      end if;
      for I in The_State.Objects'Range loop
         if The_State.Objects (I).On_Ground
           and then The_State.Objects (I).X = X
           and then The_State.Objects (I).Y = Y
         then
            case The_State.Objects (I).Kind is
               when Stone =>
                  return 1;
               when Stick =>
                  return 2;
               when Shell =>
                  return 3;
            end case;
         end if;
      end loop;
      return 0;
   end Object_At;

   function Agent_X return Integer is
   begin
      Ensure;
      return Integer (The_State.X);
   end Agent_X;

   function Agent_Y return Integer is
   begin
      Ensure;
      return Integer (The_State.Y);
   end Agent_Y;

   function Facing return Integer is
   begin
      Ensure;
      case The_State.Facing is
         when North =>
            return 0;
         when East =>
            return 1;
         when South =>
            return 2;
         when West =>
            return 3;
      end case;
   end Facing;

   function Hand return Integer is
   begin
      Ensure;
      if The_State.Hand = 0 then
         return 0;
      end if;
      case The_State.Objects (The_State.Hand).Kind is
         when Stone =>
            return 1;
         when Stick =>
            return 2;
         when Shell =>
            return 3;
      end case;
   end Hand;

   function Width return Integer is
   begin
      return Grid_Size;
   end Width;

   function Height return Integer is
   begin
      return Grid_Size;
   end Height;

   function Roundtrip return Boolean is
      Buf  : String (1 .. World.Save_Max);
      Len  : Natural;
      Copy : World.State;
      Ok   : Boolean;
   begin
      World.Write_Save (The_State, Buf, Len);
      World.Read_Save (Buf (1 .. Len), Copy, Ok);
      return Ok and then Copy = The_State;
   end Roundtrip;

   function Self_Check return Boolean is
      Reply : Reply_Buffer;
      Len   : Natural;
      Ok    : Boolean;
   begin
      Reset;
      pragma Assert (Terrain'Pos (Water) = 0);
      pragma Assert (Terrain'Pos (Sand) = 1);
      pragma Assert (Terrain'Pos (Grass) = 2);
      pragma Assert (Terrain'Pos (Rock) = 3);
      pragma Assert (Terrain'Pos (Tree) = 4);
      pragma Assert (Map.Layout_Ok);
      pragma Assert (Object_At (Map.Stone_X, Map.Stone_Y) = 1);
      pragma Assert (Object_At (Map.Stick_X, Map.Stick_Y) = 2);
      pragma Assert (Object_At (Map.Shell_X, Map.Shell_Y) = 3);
      pragma Assert (Object_At (Map.Start_X, Map.Start_Y) = 0);
      pragma Assert (Agent_X = Integer (Map.Start_X));
      pragma Assert (Agent_Y = Integer (Map.Start_Y));
      pragma Assert (Facing = 0);
      pragma Assert (Hand = 0);
      pragma Assert (Width = Grid_Size);
      pragma Assert (Height = Grid_Size);
      pragma Assert (Cell (-1, 0) = -1);
      pragma Assert (Cell (0, Grid_Size) = -1);
      for Y in Coord loop
         for X in Coord loop
            pragma Assert (Cell (X, Y) = Terrain'Pos (Map.Terrain_At (X, Y)));
         end loop;
      end loop;
      pragma Assert (Roundtrip);
      Run ("say ""hello""", Reply, Len, Ok);
      pragma Assert (Ok);
      pragma Assert (Len > 0);
      pragma Assert (The_State.Said_Len = 5);
      pragma Assert (Roundtrip);
      Reset;
      pragma Assert (The_State.Said_Len = 0);
      pragma Assert (Last_Ok);
      return True;
   end Self_Check;

end Island.API;
