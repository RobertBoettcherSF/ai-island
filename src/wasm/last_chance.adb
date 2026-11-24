with System;

--  Wasm only. The native runtime already reports the exception, file and line.
procedure Last_Chance (Msg : System.Address; Line : Integer) is

   procedure Panic (M : System.Address; L : Integer)
     with Import, Convention => C, External_Name => "island_panic";

   procedure Halt
     with Import, Convention => C, External_Name => "island_halt", No_Return;

begin
   Panic (Msg, Line);
   Halt;
end Last_Chance;
