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

end Island.Folk;
