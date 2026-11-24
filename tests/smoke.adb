with Island.API;
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
   S.X := 2;
   pragma Assert (Island.World.Valid (S));
   Island.World.Try_Move (S, Island.West, Result, By);
   pragma Assert (Result = Island.World.Blocked);
   pragma Assert (By = Island.Water);
   pragma Assert (S.X = 2);
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
   Run ("move E", True, """x"":17");
   Run ("eat", True, """food"":""berries""");
   Run ("move S", True, """ok"":true");
   Run ("move S", True, """ok"":true");
   for Step in 1 .. 12 loop
      Run ("move E", True, """ok"":true");
   end loop;
   Run ("eat", False, "need a stick");
end Smoke;
