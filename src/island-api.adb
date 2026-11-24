with Interfaces;
with Island.Map;
with Island.Stomach;
with Island.Text;
with Island.World;
with System;
with System.Storage_Elements;
use type Island.World.State;
use type Island.World.Home_Kind;

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
      return Terrain'Pos (Map.Terrain_At (The_State.Island_Seed, Coord (X), Coord (Y)));
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

   function Food (X, Y : Integer) return Integer is
   begin
      Ensure;
      if X not in Coord or else Y not in Coord then
         return -1;
      end if;
      case World.Food_At (The_State, Coord (X), Coord (Y)) is
         when World.None =>
            return 0;
         when World.Berries =>
            return 1;
         when World.Bare =>
            return 2;
         when World.Fish =>
            return 3;
      end case;
   end Food;

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

   Max_Samples : constant := 128;

   type Sample_Rec is record
      Turn  : Natural := 0;
      Pop   : Natural := 0;
      Speed : Natural := 0;
      Sight : Natural := 0;
      Meta  : Natural := 0;
      Fert  : Natural := 0;
   end record;

   Samples  : array (1 .. Max_Samples) of Sample_Rec := [others => <>];
   N_Samples : Natural := 0;

   procedure Note is
   begin
      if N_Samples > 0 and then Samples (N_Samples).Turn = The_State.Turn then
         return;
      end if;
      if N_Samples >= Max_Samples then
         return;
      end if;
      N_Samples := N_Samples + 1;
      Samples (N_Samples) :=
        (Turn  => The_State.Turn,
         Pop   => World.Alive_Count (The_State),
         Speed => World.Average_Milli (The_State, 1),
         Sight => World.Average_Milli (The_State, 2),
         Meta  => World.Average_Milli (The_State, 3),
         Fert  => World.Average_Milli (The_State, 4));
   end Note;

   function To_Seed (Value : Integer) return Map.Seed_Value is
   begin
      if Value < 0 then
         return Map.Default_Island_Seed;
      end if;
      return Map.Seed_Value (Value);
   end To_Seed;

   procedure Reset is
   begin
      World.Reset (The_State);
      Ready := True;
      N_Samples := 0;
      Note;
   end Reset;

   procedure Reset_Seeds (Island_Seed, Pop_Seed : Integer) is
   begin
      World.Reset (The_State, To_Seed (Island_Seed), To_Seed (Pop_Seed));
      Ready := True;
      N_Samples := 0;
      Note;
   end Reset_Seeds;

   function Island_Seed return Integer is
   begin
      Ensure;
      return Integer (The_State.Island_Seed);
   end Island_Seed;

   function Pop_Seed return Integer is
   begin
      Ensure;
      return Integer (The_State.Pop_Seed);
   end Pop_Seed;

   procedure Simulate (Turns : Integer) is
   begin
      Ensure;
      if N_Samples = 0 then
         Note;
      end if;
      if Turns <= 0 then
         return;
      end if;
      for Step in 1 .. Turns loop
         World.Simulate (The_State, 1);
         if The_State.Turn mod 20 = 0 then
            Note;
         end if;
      end loop;
   end Simulate;

   function Population return Integer is
   begin
      Ensure;
      return Integer (World.Alive_Count (The_State));
   end Population;

   function Births return Integer is
   begin
      Ensure;
      return Integer (The_State.Births);
   end Births;

   function Deaths return Integer is
   begin
      Ensure;
      return Integer (The_State.Deaths);
   end Deaths;

   function Turn return Integer is
   begin
      Ensure;
      return Integer (The_State.Turn);
   end Turn;

   function Fullness return Integer is
   begin
      Ensure;
      return Integer (The_State.Belly.Full);
   end Fullness;

   function Average (Which : Integer) return Integer is
   begin
      Ensure;
      if Which not in World.Trait_Query then
         return 0;
      end if;
      return Integer (World.Average_Milli (The_State, Which));
   end Average;

   function Folk_Max return Integer is
   begin
      return World.Max_Folk;
   end Folk_Max;

   function Known (Id : Integer) return Boolean is
   begin
      return Id in World.Folk_Id and then The_State.Folk (Id).Alive;
   end Known;

   function Folk_Alive (Id : Integer) return Integer is
   begin
      Ensure;
      if Known (Id) then
         return 1;
      end if;
      return 0;
   end Folk_Alive;

   function Folk_X (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return -1;
      end if;
      return Integer (The_State.Folk (Id).X);
   end Folk_X;

   function Folk_Y (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return -1;
      end if;
      return Integer (The_State.Folk (Id).Y);
   end Folk_Y;

   function Folk_Age (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return The_State.Folk (Id).Age;
   end Folk_Age;

   function Folk_Full (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return Integer (The_State.Folk (Id).Belly.Full);
   end Folk_Full;

   function Folk_Speed (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return Integer (The_State.Folk (Id).Speed);
   end Folk_Speed;

   function Folk_Sight (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return Integer (The_State.Folk (Id).Sight);
   end Folk_Sight;

   function Folk_Meta (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return Integer (The_State.Folk (Id).Metabolism);
   end Folk_Meta;

   function Folk_Fert (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return Integer (The_State.Folk (Id).Fertility);
   end Folk_Fert;

   function Sample_Count return Integer is
   begin
      return N_Samples;
   end Sample_Count;

   Map_Bytes : array (0 .. Grid_Size * Grid_Size - 1) of Interfaces.Unsigned_8 :=
     [others => 0];

   function Cell_Index (X, Y : Coord) return Natural is
   begin
      return Integer (Y) * Grid_Size + Integer (X);
   end Cell_Index;

   procedure Paint is
      Spot : Map.Spot;
      Food : Natural;
      Idx  : Natural;
   begin
      Ensure;
      for Y in Coord loop
         for X in Coord loop
            Map_Bytes (Cell_Index (X, Y)) :=
              Interfaces.Unsigned_8
                (Terrain'Pos (Map.Terrain_At (The_State.Island_Seed, X, Y)));
         end loop;
      end loop;
      for I in Map.Bush_Index loop
         Spot := Map.Bush (The_State.Island_Seed, I);
         Idx := Cell_Index (Spot.X, Spot.Y);
         if The_State.Bush_Eaten (I) = 0
           or else The_State.Turn >= The_State.Bush_Eaten (I) + Map.Regrow_Turns
         then
            Food := 1;
         else
            Food := 2;
         end if;
         Map_Bytes (Idx) := Interfaces.Unsigned_8
           (Interfaces.Unsigned_8'Pos (Map_Bytes (Idx)) + Food * 8);
      end loop;
      for I in Map.Fish_Index loop
         Spot := Map.Fish_At (The_State.Island_Seed, I);
         Idx := Cell_Index (Spot.X, Spot.Y);
         Map_Bytes (Idx) := Interfaces.Unsigned_8
           (Interfaces.Unsigned_8'Pos (Map_Bytes (Idx)) + 3 * 8);
      end loop;
      for I in The_State.Objects'Range loop
         if The_State.Objects (I).On_Ground then
            Idx := Cell_Index (The_State.Objects (I).X, The_State.Objects (I).Y);
            case The_State.Objects (I).Kind is
               when Stone =>
                  Food := 1;
               when Stick =>
                  Food := 2;
               when Shell =>
                  Food := 3;
            end case;
            Map_Bytes (Idx) := Interfaces.Unsigned_8
              (Interfaces.Unsigned_8'Pos (Map_Bytes (Idx)) + Food * 64);
         end if;
      end loop;
   end Paint;

   function Map_Ptr return Integer is
   begin
      return Address_As_Int (Map_Bytes'Address);
   end Map_Ptr;

   function Known_Group (G : Integer) return Boolean is
     (G in World.Group_Id);

   function Known_Home (H : Integer) return Boolean is
     (H in World.Home_Id and then The_State.Homes (H).Used);

   function Group_Count return Integer is (World.Group_Count);

   function Group_Pop (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (World.Group_Population (The_State, G));
   end Group_Pop;

   function Group_Births (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Births);
   end Group_Births;

   function Group_Deaths (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Deaths);
   end Group_Deaths;

   function Group_Homes (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (World.Group_Home_Count (The_State, G));
   end Group_Homes;

   function Group_Avg (G, Which : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) or else Which not in World.Trait_Query then
         return 0;
      end if;
      return Integer (World.Group_Average (The_State, G, Which));
   end Group_Avg;

   function Group_Extinct (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Extinct_Turn);
   end Group_Extinct;

   function Group_Cause (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Extinct_Cause);
   end Group_Cause;

   function Home_Max return Integer is (World.Max_Homes);

   function Home_Used (H : Integer) return Integer is
   begin
      Ensure;
      if Known_Home (H) then
         return 1;
      end if;
      return 0;
   end Home_Used;

   function Home_X (H : Integer) return Integer is
   begin
      Ensure;
      if not Known_Home (H) then
         return -1;
      end if;
      return Integer (The_State.Homes (H).X);
   end Home_X;

   function Home_Y (H : Integer) return Integer is
   begin
      Ensure;
      if not Known_Home (H) then
         return -1;
      end if;
      return Integer (The_State.Homes (H).Y);
   end Home_Y;

   function Home_Group (H : Integer) return Integer is
   begin
      Ensure;
      if not Known_Home (H) then
         return 0;
      end if;
      return Integer (The_State.Homes (H).Group);
   end Home_Group;

   function Home_Kind (H : Integer) return Integer is
   begin
      Ensure;
      if not Known_Home (H) then
         return 0;
      end if;
      if The_State.Homes (H).Kind = World.Cave then
         return 1;
      end if;
      return 2;
   end Home_Kind;

   function Home_Residents (H : Integer) return Integer is
   begin
      Ensure;
      if not Known_Home (H) then
         return 0;
      end if;
      return Integer (World.Home_Residents (The_State, H));
   end Home_Residents;

   function Folk_Group (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return Integer (The_State.Folk (Id).Group);
   end Folk_Group;

   function Folk_Home (Id : Integer) return Integer is
   begin
      Ensure;
      if not Known (Id) then
         return 0;
      end if;
      return The_State.Folk (Id).Home;
   end Folk_Home;

   function Folk_Scout (Id : Integer) return Integer is
   begin
      Ensure;
      if Known (Id) and then The_State.Folk (Id).Scout then
         return 1;
      end if;
      return 0;
   end Folk_Scout;

   function Folk_Marker (Id : Integer) return Integer is
   begin
      Ensure;
      if Known (Id)
        and then (The_State.Folk (Id).Col_A = 1
                  or else The_State.Folk (Id).Col_B = 1)
      then
         return 1;
      end if;
      return 0;
   end Folk_Marker;

   function Group_Trust (A, B : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (A) or else not Known_Group (B) then
         return 0;
      end if;
      return Integer (The_State.Trust (A) (B));
   end Group_Trust;

   function Group_Trades (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Trades);
   end Group_Trades;

   function Group_In (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Migrants_In);
   end Group_In;

   function Group_Out (G : Integer) return Integer is
   begin
      Ensure;
      if not Known_Group (G) then
         return 0;
      end if;
      return Integer (The_State.Groups (G).Migrants_Out);
   end Group_Out;

   function Group_Allele (G, Gene : Integer) return Integer is
      High  : Natural := 0;
      Total : Natural := 0;
      Left  : Natural;
      Right : Natural;
   begin
      Ensure;
      if not Known_Group (G) or else Gene not in 1 .. 5 then
         return 0;
      end if;
      for I in World.Folk_Id loop
         if The_State.Folk (I).Alive and then The_State.Folk (I).Group = G then
            case Gene is
               when 1 =>
                  Left := The_State.Folk (I).Sp_A;
                  Right := The_State.Folk (I).Sp_B;
               when 2 =>
                  Left := The_State.Folk (I).Si_A;
                  Right := The_State.Folk (I).Si_B;
               when 3 =>
                  Left := The_State.Folk (I).Me_A;
                  Right := The_State.Folk (I).Me_B;
               when 4 =>
                  Left := The_State.Folk (I).Fe_A;
                  Right := The_State.Folk (I).Fe_B;
               when others =>
                  Left := The_State.Folk (I).Col_A;
                  Right := The_State.Folk (I).Col_B;
            end case;
            Total := Total + 2;
            if Gene = 5 then
               High := High + Left + Right;
            else
               if Left >= 2 then
                  High := High + 1;
               end if;
               if Right >= 2 then
                  High := High + 1;
               end if;
            end if;
         end if;
      end loop;
      if Total = 0 then
         return 0;
      end if;
      return Integer ((High * 1000) / Total);
   end Group_Allele;

   function River_Length (Which : Integer) return Integer is
   begin
      Ensure;
      if Which not in Map.River_Index then
         return 0;
      end if;
      return Integer (Map.River_Length (The_State.Island_Seed, Which));
   end River_Length;

   function River_X (Which, Step : Integer) return Integer is
   begin
      Ensure;
      if Which not in Map.River_Index or else Step < 1 then
         return -1;
      end if;
      return Integer (Map.River_Step (The_State.Island_Seed, Which, Step).X);
   end River_X;

   function River_Y (Which, Step : Integer) return Integer is
   begin
      Ensure;
      if Which not in Map.River_Index or else Step < 1 then
         return -1;
      end if;
      return Integer (Map.River_Step (The_State.Island_Seed, Which, Step).Y);
   end River_Y;

   function Trail_Count return Integer is
      N : Natural := 0;
   begin
      Ensure;
      for I in World.Trail_Id loop
         if The_State.Trails (I).Used then
            N := N + 1;
         end if;
      end loop;
      return Integer (N);
   end Trail_Count;

   function Used_Trail (I : Integer) return Boolean is
     (I in World.Trail_Id and then The_State.Trails (I).Used);

   function Trail_X (I : Integer) return Integer is
   begin
      Ensure;
      if not Used_Trail (I) then
         return -1;
      end if;
      return Integer (The_State.Trails (I).X);
   end Trail_X;

   function Trail_Y (I : Integer) return Integer is
   begin
      Ensure;
      if not Used_Trail (I) then
         return -1;
      end if;
      return Integer (The_State.Trails (I).Y);
   end Trail_Y;

   function Road_Count return Integer is
      N : Natural := 0;
   begin
      Ensure;
      for I in World.Road_Id loop
         if The_State.Roads (I).Used then
            N := N + 1;
         end if;
      end loop;
      return Integer (N);
   end Road_Count;

   function Road_X (I : Integer) return Integer is
   begin
      Ensure;
      if I not in World.Road_Id or else not The_State.Roads (I).Used then
         return -1;
      end if;
      return Integer (The_State.Roads (I).X);
   end Road_X;

   function Road_Y (I : Integer) return Integer is
   begin
      Ensure;
      if I not in World.Road_Id or else not The_State.Roads (I).Used then
         return -1;
      end if;
      return Integer (The_State.Roads (I).Y);
   end Road_Y;

   function Market_Count return Integer is
      N : Natural := 0;
   begin
      Ensure;
      for I in World.Market_Id loop
         if The_State.Markets (I).Used then
            N := N + 1;
         end if;
      end loop;
      return Integer (N);
   end Market_Count;

   function Market_X (I : Integer) return Integer is
   begin
      Ensure;
      if I not in World.Market_Id or else not The_State.Markets (I).Used then
         return -1;
      end if;
      return Integer (The_State.Markets (I).X);
   end Market_X;

   function Market_Y (I : Integer) return Integer is
   begin
      Ensure;
      if I not in World.Market_Id or else not The_State.Markets (I).Used then
         return -1;
      end if;
      return Integer (The_State.Markets (I).Y);
   end Market_Y;

   function Market_Trades (I : Integer) return Integer is
   begin
      Ensure;
      if I not in World.Market_Id or else not The_State.Markets (I).Used then
         return 0;
      end if;
      return Integer (The_State.Markets (I).Trades);
   end Market_Trades;

   function Meetings return Integer is
   begin
      Ensure;
      return Integer (The_State.Meetings);
   end Meetings;

   function Thirst return Integer is
   begin
      Ensure;
      return Integer (The_State.Folk (World.Player_Id).Thirst);
   end Thirst;

   function Home_Store (H, Kind : Integer) return Integer is
   begin
      Ensure;
      if not Known_Home (H) then
         return 0;
      end if;
      case Kind is
         when 1 =>
            return Integer (The_State.Homes (H).Berries);
         when 2 =>
            return Integer (The_State.Homes (H).Fish);
         when 3 =>
            return Integer (The_State.Homes (H).Sticks);
         when 4 =>
            return Integer (The_State.Homes (H).Stones);
         when others =>
            return 0;
      end case;
   end Home_Store;

   function Sample (Index, Field : Integer) return Integer is
   begin
      if Index < 1 or else Index > N_Samples then
         return 0;
      end if;
      case Field is
         when 0 =>
            return Samples (Index).Turn;
         when 1 =>
            return Samples (Index).Pop;
         when 2 =>
            return Samples (Index).Speed;
         when 3 =>
            return Samples (Index).Sight;
         when 4 =>
            return Samples (Index).Meta;
         when 5 =>
            return Samples (Index).Fert;
         when others =>
            return 0;
      end case;
   end Sample;

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
            pragma Assert
              (Cell (X, Y) = Terrain'Pos
                 (Map.Terrain_At (Map.Default_Island_Seed, X, Y)));
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
      declare
         L : Stomach.Levels;
      begin
         L.Full := 0;
         L.Empty_For := 0;
         L.Collapsed := False;
         for I in 1 .. Stomach.Starve_Turns loop
            Stomach.Tick (L, 1, False);
         end loop;
         pragma Assert (L.Collapsed);
         pragma Assert (L.Empty_For = Stomach.Starve_Turns);
         L := (Full => 50, Empty_For => 0, Collapsed => False);
         Stomach.Feed (L, Map.Berry_Gain);
         pragma Assert (L.Full = 75);
         Stomach.Feed (L, Map.Fish_Gain);
         pragma Assert (L.Full = 100);
      end;
      pragma Assert
        (Food
           (Map.Bush (Map.Default_Island_Seed, 1).X,
            Map.Bush (Map.Default_Island_Seed, 1).Y) = 1);
      pragma Assert
        (Food
           (Map.Fish_At (Map.Default_Island_Seed, 1).X,
            Map.Fish_At (Map.Default_Island_Seed, 1).Y) = 3);
      return True;
   end Self_Check;

end Island.API;
