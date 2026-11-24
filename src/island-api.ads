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

   procedure Simulate (Turns : Integer)
     with Export, Convention => C, External_Name => "island_simulate";

   function Population return Integer
     with Export, Convention => C, External_Name => "island_population";

   function Births return Integer
     with Export, Convention => C, External_Name => "island_births";

   function Deaths return Integer
     with Export, Convention => C, External_Name => "island_deaths";

   function Turn return Integer
     with Export, Convention => C, External_Name => "island_turn";

   function Fullness return Integer
     with Export, Convention => C, External_Name => "island_fullness";

   --  1 speed, 2 sight, 3 metabolism, 4 fertility. Thousandths of a point.
   function Average (Which : Integer) return Integer
     with Export, Convention => C, External_Name => "island_average";

   function Folk_Max return Integer
     with Export, Convention => C, External_Name => "island_folk_max";

   function Folk_Alive (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_alive";

   function Folk_X (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_x";

   function Folk_Y (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_y";

   function Folk_Age (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_age";

   function Folk_Full (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_full";

   function Folk_Speed (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_speed";

   function Folk_Sight (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_sight";

   function Folk_Meta (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_meta";

   function Folk_Fert (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_fert";

   function Sample_Count return Integer
     with Export, Convention => C, External_Name => "island_sample_count";

   --  Field: 0 turn, 1 population, 2 speed, 3 sight, 4 metabolism, 5 fertility.
   function Sample (Index, Field : Integer) return Integer
     with Export, Convention => C, External_Name => "island_sample";

   --  One byte per cell: terrain, food, and the object on that square.
   procedure Paint
     with Export, Convention => C, External_Name => "island_paint";

   function Map_Ptr return Integer
     with Export, Convention => C, External_Name => "island_map_ptr";

end Island.API;
