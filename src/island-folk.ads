with Island.World;

--  Built-in brains, births and deaths. The player is creature 1.
package Island.Folk is

   procedure Setup (S : in out World.State)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

   procedure Others_Act (S : in out World.State)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

   procedure Player_Act (S : in out World.State)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

   procedure After_Actions (S : in out World.State; Turns : Positive)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

   --  1 stick, 2 stone, 3 food, 0 nothing.
   procedure Player_Gather (S : in out World.State; Result : out Natural)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

   --  1 built, 2 need materials, 3 cannot build here.
   procedure Player_Build (S : in out World.State; Result : out Natural)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

   --  1 fed, 2 no food, 3 no child here.
   procedure Player_Feed (S : in out World.State; Result : out Natural)
     with Pre => World.Valid (S),
          Post => World.Valid (S);

end Island.Folk;
