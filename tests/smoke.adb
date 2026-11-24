with Ada.Text_IO;
with Island.API;
with Island.Folk;
with Island.Map;
with Island.Stomach;
with Island.World;
use type Island.Direction;
use type Island.Terrain;
use type Island.World.Move_Result;

--  Native -gnata run of the shared core, including the wasm entry points
--  that do not need a 32-bit address.
procedure Smoke is
   S      : Island.World.State;
   Result : Island.World.Move_Result;
   By     : Island.Terrain;

   function Has (Hay : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Hay'Length < Needle'Length then
         return Needle'Length = 0;
      end if;
      for I in Hay'First .. Hay'Last - Needle'Length + 1 loop
         if Hay (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Has;

   procedure Run (Command : String; Ok_Expected : Boolean; Piece : String) is
      Reply : Island.Reply_Buffer;
      Len   : Natural;
      Ok    : Boolean;
   begin
      Island.API.Run (Command, Reply, Len, Ok);
      pragma Assert (Ok = Ok_Expected);
      pragma Assert (Len > 0);
      pragma Assert (Has (Reply (1 .. Len), Piece));
   end Run;

begin
   pragma Assert (Island.API.Self_Check);
   Island.World.Reset (S);
   S.X := 3;
   S.Y := 48;
   pragma Assert (Island.World.Valid (S));
   Island.World.Try_Move (S, Island.West, Result, By);
   pragma Assert (Result = Island.World.Blocked);
   pragma Assert (By = Island.Water);
   pragma Assert (S.X = 3);
   pragma Assert (S.Facing = Island.North);
   pragma Assert (Island.World.Valid (S));
   Island.World.Reset (S);
   S.Belly.Full := 0;
   S.Belly.Empty_For := 0;
   S.Belly.Collapsed := False;
   pragma Assert (Island.Stomach.Is_Weak (S.Belly));
   Island.World.Advance (S, True, True, False);
   pragma Assert (S.Turn = 2);
   pragma Assert (S.Belly.Empty_For = 2);
   pragma Assert (not S.Belly.Collapsed);
   Run ("new", True, """hunger"":""ok""");
   Run ("move N", True, """fullness"":99");
   Run ("eat", True, """food"":""berries""");
   declare
      W : Island.World.State;
      Before : Natural;
      A1, A2, A3, A4 : Natural;
      B1, B2, B3, B4 : Natural;
   begin
      Island.World.Reset (W);
      W.Folk (2).X := 48;
      W.Folk (2).Y := 49;
      W.Folk (3).X := 48;
      W.Folk (3).Y := 50;
      W.Folk (2).Belly.Full := 95;
      W.Folk (3).Belly.Full := 95;
      W.Folk (2).Age := 80;
      W.Folk (3).Age := 80;
      W.Folk (2).Cool := 0;
      W.Folk (3).Cool := 0;
      for I in Island.World.Folk_Id loop
         if I /= 2 and then I /= 3 then
            W.Folk (I).Cool := 40;
            W.Folk (I).Belly.Full := 40;
         end if;
      end loop;
      Before := Island.World.Alive_Count (W);
      Island.Folk.After_Actions (W, 1);
      pragma Assert (W.Births = 1);
      pragma Assert (Island.World.Alive_Count (W) = Before + 1);

      Island.World.Reset (W);
      W.Folk (4).Belly.Full := 0;
      W.Folk (4).Belly.Empty_For := 19;
      Island.Stomach.Tick (W.Folk (4).Belly, 1, False);
      pragma Assert (W.Folk (4).Belly.Collapsed);
      Island.Folk.After_Actions (W, 1);
      pragma Assert (not W.Folk (4).Alive);
      pragma Assert (W.Deaths >= 1);

      Island.World.Reset (W);
      A1 := Island.World.Average_Milli (W, 1);
      A2 := Island.World.Average_Milli (W, 2);
      A3 := Island.World.Average_Milli (W, 3);
      A4 := Island.World.Average_Milli (W, 4);
      Island.World.Simulate (W, 2000);
      B1 := Island.World.Average_Milli (W, 1);
      B2 := Island.World.Average_Milli (W, 2);
      B3 := Island.World.Average_Milli (W, 3);
      B4 := Island.World.Average_Milli (W, 4);
      Ada.Text_IO.Put_Line
        ("pop" & Natural'Image (Island.World.Alive_Count (W))
         & " births" & Natural'Image (W.Births)
         & " deaths" & Natural'Image (W.Deaths)
         & " speed" & Natural'Image (A1) & "->" & Natural'Image (B1)
         & " sight" & Natural'Image (A2) & "->" & Natural'Image (B2)
         & " meta" & Natural'Image (A3) & "->" & Natural'Image (B3)
         & " fert" & Natural'Image (A4) & "->" & Natural'Image (B4));
      pragma Assert (Island.World.Alive_Count (W) > 0);
      pragma Assert (W.Births >= 1);
      pragma Assert (A1 /= B1 or else A2 /= B2 or else A3 /= B3 or else A4 /= B4);

      declare
         use type Island.World.State;
         use type Island.Map.Spot;
         Again : Island.World.State;
         Other : Island.World.State;
         Changed : Boolean := False;
      begin
         Island.World.Reset (Again);
         Island.World.Simulate (Again, 2000);
         pragma Assert (Again = W);
         Island.World.Reset (Other, 42, Island.Map.Default_Pop_Seed);
         for Y in Island.Coord loop
            for X in Island.Coord loop
               if Island.Map.Terrain_At (42, X, Y)
                 /= Island.Map.Terrain_At (Island.Map.Default_Island_Seed, X, Y)
               then
                  Changed := True;
                  exit;
               end if;
            end loop;
            exit when Changed;
         end loop;
         pragma Assert (Changed);
         pragma Assert
           (Island.Map.Bush (42, 1) /= Island.Map.Bush (Island.Map.Default_Island_Seed, 1)
            or else Island.Map.Fish_At (42, 1)
              /= Island.Map.Fish_At (Island.Map.Default_Island_Seed, 1));
      end;
   end;
end Smoke;
