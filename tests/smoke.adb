with Ada.Text_IO;
with Island.API;
with Island.Folk;
with Island.Map;
with Island.Rng;
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
   declare
      A, B : Island.Rng.State;
      Counts : array (0 .. 9) of Natural := [others => 0];
      Value : Natural;
      Sum_Sq : Natural := 0;
      Differ : Boolean := False;
   begin
      A := Island.Rng.Init (16#2026_1124#);
      B := Island.Rng.Init (16#2026_1124#);
      for I in 1 .. 10_000 loop
         Value := Island.Rng.Below (A, 10);
         Counts (Value) := Counts (Value) + 1;
         pragma Assert (Island.Rng.Below (B, 10) = Value);
      end loop;
      for Bucket in Counts'Range loop
         pragma Assert (Counts (Bucket) in 800 .. 1200);
         Sum_Sq := Sum_Sq + (Counts (Bucket) - 1000) * (Counts (Bucket) - 1000);
      end loop;
      --  Chi-square under 30 for 9 degrees of freedom.
      pragma Assert (Sum_Sq < 30_000);
      A := Island.Rng.Init (1);
      B := Island.Rng.Init (2);
      for I in 1 .. 4 loop
         if Island.Rng.Below (A, 1000) /= Island.Rng.Below (B, 1000) then
            Differ := True;
         end if;
      end loop;
      pragma Assert (Differ);
   end;
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
      W.Folk (2).Age := 160;
      W.Folk (3).Age := 160;
      W.Folk (2).Group := 1;
      W.Folk (3).Group := 1;
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
      declare
         Child : Integer := 0;
      begin
         for I in Island.World.Folk_Id loop
            if W.Folk (I).Alive and then W.Folk (I).Age = 0 then
               Child := I;
            end if;
         end loop;
         pragma Assert (Child /= 0);
         pragma Assert (W.Folk (Child).Group = 1);
         pragma Assert (W.Folk (Child).Home = 1);
         pragma Assert (W.Folk (Child).X = W.Homes (1).X);
         pragma Assert (W.Folk (Child).Y = W.Homes (1).Y);
         W.X := W.Homes (1).X;
         W.Y := W.Homes (1).Y;
         W.Folk (1).Food := 1;
         W.Folk (Child).Belly.Full := 20;
         Island.Folk.Player_Feed (W, Before);
         pragma Assert (Before = 1);
         pragma Assert (W.Folk (Child).Belly.Full = 45);
         pragma Assert (W.Folk (1).Food = 0);
      end;
      Island.World.Reset (W);
      for K in 1 .. Island.World.Home_Capacity loop
         W.Folk (20 + K).Alive := True;
         W.Folk (20 + K).Age := 10;
         W.Folk (20 + K).Group := 1;
         W.Folk (20 + K).Home := 1;
         W.Folk (20 + K).X := W.Homes (1).X;
         W.Folk (20 + K).Y := W.Homes (1).Y;
         W.Folk (20 + K).Belly := (Full => 40, Empty_For => 0, Collapsed => False);
      end loop;
      W.Folk (2).X := 48;
      W.Folk (2).Y := 49;
      W.Folk (3).X := 48;
      W.Folk (3).Y := 50;
      W.Folk (2).Belly.Full := 95;
      W.Folk (3).Belly.Full := 95;
      W.Folk (2).Age := 160;
      W.Folk (3).Age := 160;
      W.Folk (2).Group := 1;
      W.Folk (3).Group := 1;
      W.Folk (2).Cool := 0;
      W.Folk (3).Cool := 0;
      for I in Island.World.Folk_Id loop
         if I /= 2 and then I /= 3 and then W.Folk (I).Age >= 150 then
            W.Folk (I).Cool := 40;
            W.Folk (I).Belly.Full := 40;
         end if;
      end loop;
      Island.Folk.After_Actions (W, 1);
      pragma Assert (W.Births = 0);

      Island.World.Reset (W);
      W.X := 30;
      W.Y := 30;
      W.Folk (1).Sticks := 4;
      W.Folk (1).Food := 0;
      W.Folk (3).X := 31;
      W.Folk (3).Y := 30;
      W.Folk (3).Group := 2;
      W.Folk (3).Food := 1;
      W.Folk (3).Sticks := 0;
      W.Folk (3).Age := 160;
      Island.Folk.Player_Trade (W, Before);
      pragma Assert (Before = 1);
      pragma Assert (W.Folk (1).Food = 1);
      pragma Assert (W.Trust (1) (2) > 2);

      Island.World.Reset (W);
      W.Folk (2).Group := 2;
      W.Folk (2).Migrate := 1;
      W.Folk (2).X := 18;
      W.Folk (2).Y := 19;
      W.Folk (2).Age := 160;
      Island.Folk.Others_Act (W);
      pragma Assert (W.Folk (2).Group = 1);
      pragma Assert (W.Groups (1).Migrants_In = 1);
      pragma Assert (W.Groups (1).Came_From (2) = 1);

      Island.World.Reset (W);
      W.Trust (1) (2) := 8;
      W.Trust (2) (1) := 8;
      W.Folk (2).X := 40;
      W.Folk (2).Y := 40;
      W.Folk (3).X := 41;
      W.Folk (3).Y := 40;
      W.Folk (2).Group := 1;
      W.Folk (3).Group := 2;
      W.Folk (2).Age := 160;
      W.Folk (3).Age := 160;
      W.Folk (2).Belly.Full := 95;
      W.Folk (3).Belly.Full := 95;
      W.Folk (2).Cool := 0;
      W.Folk (3).Cool := 0;
      for I in Island.World.Folk_Id loop
         if I > 3 and then W.Folk (I).Age >= 150 then
            W.Folk (I).Cool := 40;
            W.Folk (I).Belly.Full := 40;
         end if;
      end loop;
      Island.Folk.After_Actions (W, 1);
      pragma Assert (W.Births = 1);
      declare
         Child : Integer := 0;
      begin
         for I in Island.World.Folk_Id loop
            if W.Folk (I).Alive and then W.Folk (I).Age <= 1 then
               Child := I;
            end if;
         end loop;
         pragma Assert (Child /= 0);
         pragma Assert (W.Folk (Child).Group = 1);
      end;

      declare
         WW : constant Island.Folk.Color_Pair := (Left => 1, Right => 1);
         RR : constant Island.Folk.Color_Pair := (Left => 0, Right => 0);
         F1 : Island.Folk.Color_Pair;
         Kid : Island.Folk.Color_Pair;
         Hom : Natural := 0;
         Het : Natural := 0;
         Rec : Natural := 0;
         N   : constant Natural := 256;
      begin
         for I in 0 .. 15 loop
            F1 := Island.Folk.Cross_Color (WW, RR, 99, I);
            pragma Assert
              ((F1.Left = 1 and then F1.Right = 0)
               or else (F1.Left = 0 and then F1.Right = 1));
         end loop;
         F1 := (Left => 1, Right => 0);
         for I in 0 .. N - 1 loop
            Kid := Island.Folk.Cross_Color (F1, F1, 99, I);
            if Kid.Left = 1 and then Kid.Right = 1 then
               Hom := Hom + 1;
            elsif Kid.Left = 0 and then Kid.Right = 0 then
               Rec := Rec + 1;
            else
               Het := Het + 1;
            end if;
         end loop;
         pragma Assert (Hom > N / 8 and then Hom < N / 2);
         pragma Assert (Rec > N / 8 and then Rec < N / 2);
         pragma Assert (Het > N / 4 and then Het < (N * 3) / 4);
      end;

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
      for G in Island.World.Group_Id loop
         Ada.Text_IO.Put_Line
           ("group" & Integer'Image (G)
            & " pop" & Natural'Image (Island.World.Group_Population (W, G))
            & " births" & Natural'Image (W.Groups (G).Births)
            & " deaths" & Natural'Image (W.Groups (G).Deaths)
            & " homes" & Natural'Image (Island.World.Group_Home_Count (W, G))
            & " extinct" & Natural'Image (W.Groups (G).Extinct_Turn)
            & " cause" & Natural'Image (W.Groups (G).Extinct_Cause));
      end loop;
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
      declare
         Seed : constant Island.Map.Seed_Value := Island.Map.Default_Island_Seed;
         Len  : Natural;
         Prev : Island.Map.Spot;
         Step : Island.Map.Spot;
         Last : Island.Map.Spot;
         Again_H : Natural;
         Again_P : Island.Map.Spot;
      begin
         Ada.Text_IO.Put_Line
           ("rejections" & Natural'Image (Island.Map.Rejection_Count (Seed)));
         Again_H := Island.Map.Height (Seed, 20, 40);
         Again_P := Island.Map.River_Step (Seed, 1, 2);
         pragma Assert (Island.Map.Height (Seed, 20, 40) = Again_H);
         pragma Assert
           (Island.Map.River_Step (Seed, 1, 2).X = Again_P.X
            and then Island.Map.River_Step (Seed, 1, 2).Y = Again_P.Y);
         for Which in Island.Map.River_Index loop
            Len := Island.Map.River_Length (Seed, Which);
            pragma Assert (Len > 2);
            Prev := Island.Map.River_Step (Seed, Which, 1);
            Last := Island.Map.River_Step (Seed, Which, Len);
            pragma Assert (Island.Map.Terrain_At (Seed, Last.X, Last.Y) = Island.Water
              or else Island.Map.Height (Seed, Last.X, Last.Y) = 0);
            for I in 2 .. Len loop
               Step := Island.Map.River_Step (Seed, Which, I);
               pragma Assert
                 (Island.Map.Height (Seed, Step.X, Step.Y)
                  <= Island.Map.Height (Seed, Prev.X, Prev.Y));
               Prev := Step;
            end loop;
         end loop;
      end;
      Island.World.Reset (W);
      Island.Folk.Leave_Scent (W, 30, 30);
      pragma Assert (Island.Folk.Scent (W, 30, 30) >= 2);
      Island.Folk.Leave_Scent (W, 30, 30);
      pragma Assert (Island.Folk.Scent (W, 30, 30) > 2);
      W.Folk (2).X := 30;
      W.Folk (2).Y := 30;
      W.Folk (2).Sticks := 2;
      W.Folk (2).Stones := 0;
      W.Folk (2).Alive := True;
      declare
         Did : Boolean;
      begin
         Island.Folk.Market_Deal (W, 2, Did);
         pragma Assert (Did);
         pragma Assert (W.Folk (2).Stones = 1);
         pragma Assert (W.Markets (1).Trades = 1);
      end;
      Island.World.Reset (W);
      Island.World.Simulate (W, 3000);
      declare
         Trades : Natural := 0;
      begin
         for G in Island.World.Group_Id loop
            Trades := Trades + W.Groups (G).Trades;
         end loop;
         Ada.Text_IO.Put_Line
           ("meetings" & Natural'Image (W.Meetings)
            & " trades" & Natural'Image (Trades));
         pragma Assert (W.Meetings >= 1);
         pragma Assert (Trades >= 1);
      end;
   end;
end Smoke;
