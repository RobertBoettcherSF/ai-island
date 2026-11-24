-- The one world the browser talks to. Exports are integers: a command
-- buffer, a reply buffer, and cell codes. The rules stay in Island.World.
package Island.API is

   procedure Reset
     with Export, Convention => C, External_Name => "island_reset";

   procedure Reset_Seeds (Island_Seed, Pop_Seed : Integer)
     with Export, Convention => C, External_Name => "island_reset_seeds";

   function Island_Seed return Integer
     with Export, Convention => C, External_Name => "island_island_seed";

   function Pop_Seed return Integer
     with Export, Convention => C, External_Name => "island_pop_seed";

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

   function Group_Count return Integer
     with Export, Convention => C, External_Name => "island_group_count";

   function Group_Pop (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_pop";

   function Group_Births (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_births";

   function Group_Deaths (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_deaths";

   function Group_Homes (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_homes";

   function Group_Avg (G, Which : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_avg";

   function Group_Extinct (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_extinct";

   function Group_Cause (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_cause";

   function Home_Max return Integer
     with Export, Convention => C, External_Name => "island_home_max";

   function Home_Used (H : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_used";

   function Home_X (H : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_x";

   function Home_Y (H : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_y";

   function Home_Group (H : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_group";

   function Home_Kind (H : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_kind";

   function Home_Residents (H : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_residents";

   function Folk_Group (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_group";

   function Folk_Home (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_home";

   function Folk_Scout (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_scout";

   function Folk_Marker (Id : Integer) return Integer
     with Export, Convention => C, External_Name => "island_folk_marker";

   function Group_Trust (A, B : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_trust";

   function Group_Trades (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_trades";

   function Group_In (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_in";

   function Group_Out (G : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_out";

   --  Gene 1..4 quantitative high-allele share, 5 colour dominant share, in thousandths.
   function Group_Allele (G, Gene : Integer) return Integer
     with Export, Convention => C, External_Name => "island_group_allele";

   function Home_Store (H, Kind : Integer) return Integer
     with Export, Convention => C, External_Name => "island_home_store";

   function River_Length (Which : Integer) return Integer
     with Export, Convention => C, External_Name => "island_river_len";

   function River_X (Which, Step : Integer) return Integer
     with Export, Convention => C, External_Name => "island_river_x";

   function River_Y (Which, Step : Integer) return Integer
     with Export, Convention => C, External_Name => "island_river_y";

   function Trail_Count return Integer
     with Export, Convention => C, External_Name => "island_trail_count";

   function Trail_X (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_trail_x";

   function Trail_Y (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_trail_y";

   function Road_Count return Integer
     with Export, Convention => C, External_Name => "island_road_count";

   function Road_X (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_road_x";

   function Road_Y (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_road_y";

   function Market_Count return Integer
     with Export, Convention => C, External_Name => "island_market_count";

   function Market_X (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_market_x";

   function Market_Y (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_market_y";

   function Market_Trades (I : Integer) return Integer
     with Export, Convention => C, External_Name => "island_market_trades";

   function Meetings return Integer
     with Export, Convention => C, External_Name => "island_meetings";

   function Thirst return Integer
     with Export, Convention => C, External_Name => "island_thirst";

end Island.API;
