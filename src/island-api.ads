-- The one world the browser talks to. Exports are integers: a command
-- buffer, a reply buffer, and cell codes. The rules stay in Island.World.
package Island.API is

   procedure Reset
     with Export, Convention => C, External_Name => "island_reset";

   procedure Run
     (Command : String;
      Reply   : out Reply_Buffer;
      Len     : out Natural;
      Ok      : out Boolean);

   function Self_Check return Boolean;

   function Cell (X, Y : Integer) return Integer
     with Export, Convention => C, External_Name => "island_cell";

   function Object_At (X, Y : Integer) return Integer
     with Export, Convention => C, External_Name => "island_object";

   --  0 none, 1 ripe berries, 2 bare bush, 3 fish.
   function Food (X, Y : Integer) return Integer
     with Export, Convention => C, External_Name => "island_food";

   function Agent_X return Integer
     with Export, Convention => C, External_Name => "island_agent_x";

   function Agent_Y return Integer
     with Export, Convention => C, External_Name => "island_agent_y";

   function Facing return Integer
     with Export, Convention => C, External_Name => "island_facing";

   function Hand return Integer
     with Export, Convention => C, External_Name => "island_hand";

   function Width return Integer
     with Export, Convention => C, External_Name => "island_width";

   function Height return Integer
     with Export, Convention => C, External_Name => "island_height";

   procedure Exec (Length : Integer)
     with Export, Convention => C, External_Name => "island_exec";

   function Command_Ptr return Integer
     with Export, Convention => C, External_Name => "island_command_ptr";

   function Reply_Ptr return Integer
     with Export, Convention => C, External_Name => "island_reply_ptr";

   function Reply_Len return Integer
     with Export, Convention => C, External_Name => "island_reply_len";

end Island.API;
