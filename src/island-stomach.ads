-- Fullness for any creature. The island agent uses one. Birds can use
-- another later. No map and no commands in here.
package Island.Stomach is

   Max_Fullness : constant := 100;
   subtype Fullness is Integer range 0 .. Max_Fullness;

   --  Below this, and still above empty, the creature is hungry.
   Hungry_Below : constant Fullness := 30;

   --  Turns spent at empty before the creature collapses.
   Starve_Turns : constant := 20;

   type Hunger is (Ok, Hungry, Weak, Collapsed);

   type Levels is record
      Full      : Fullness := Max_Fullness;
      Empty_For : Natural := 0;
      Collapsed : Boolean := False;
   end record;

   function Levels_Ok (L : Levels) return Boolean;

   function Status (L : Levels) return Hunger
     with Pre => Levels_Ok (L);

   function Is_Weak (L : Levels) return Boolean
     with Pre => Levels_Ok (L);

   --  One action. Hunger falls by Drain, plus one more while carrying.
   --  Drain 1 is the original rule (1, or 2 while carrying). Turns is how
   --  many world turns that action took (a weak move takes two).
   procedure Tick
     (L        : in out Levels;
      Turns    : Positive;
      Carrying : Boolean;
      Drain    : Positive := 1)
     with Pre =>
       Levels_Ok (L) and then not L.Collapsed and then Drain <= 6,
          Post => Levels_Ok (L) and then L.Full <= L'Old.Full;

   procedure Feed (L : in out Levels; Amount : Natural)
     with Pre =>
       Levels_Ok (L) and then not L.Collapsed
       and then Amount > 0 and then Amount <= Max_Fullness,
          Post =>
            Levels_Ok (L) and then not L.Collapsed
            and then L.Full >= L'Old.Full and then L.Empty_For = 0;

end Island.Stomach;
