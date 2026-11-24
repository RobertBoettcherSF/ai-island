with Ada.Text_IO;
with Island.API;
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

   procedure Emit (Command : String) is
      Reply : Island.Reply_Buffer;
      Len   : Natural;
      Ok    : Boolean;
   begin
      Island.API.Run (Command, Reply, Len, Ok);
      pragma Assert (Ok);
      pragma Assert (Len > 0);
      Ada.Text_IO.Put_Line (Reply (1 .. Len));
   end Emit;

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
   Emit ("new");
   Emit ("look");
   Emit ("move N");
   Emit ("pick");
   Emit ("place");
   Emit ("look");
end Smoke;
