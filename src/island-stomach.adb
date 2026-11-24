package body Island.Stomach is

   function Levels_Ok (L : Levels) return Boolean is
   begin
      if L.Collapsed then
         return L.Full = 0 and then L.Empty_For >= Starve_Turns;
      end if;
      if L.Full = 0 then
         return L.Empty_For < Starve_Turns;
      end if;
      return L.Empty_For = 0;
   end Levels_Ok;

   function Status (L : Levels) return Hunger is
   begin
      if L.Collapsed then
         return Collapsed;
      elsif L.Full = 0 then
         return Weak;
      elsif L.Full < Hungry_Below then
         return Hungry;
      else
         return Ok;
      end if;
   end Status;

   function Is_Weak (L : Levels) return Boolean is
   begin
      return Status (L) = Weak;
   end Is_Weak;

   procedure Tick (L : in out Levels; Turns : Positive; Carrying : Boolean) is
      Cost : Natural;
   begin
      if Carrying then
         Cost := 2;
      else
         Cost := 1;
      end if;
      if L.Full = 0 then
         L.Empty_For := L.Empty_For + Natural (Turns);
         if L.Empty_For >= Starve_Turns then
            L.Collapsed := True;
         end if;
      elsif Natural (L.Full) <= Cost then
         L.Full := 0;
      else
         L.Full := Fullness (Natural (L.Full) - Cost);
      end if;
   end Tick;

   procedure Feed (L : in out Levels; Amount : Natural) is
      Room : constant Natural := Natural (Max_Fullness - L.Full);
   begin
      if Amount >= Room then
         L.Full := Max_Fullness;
      else
         L.Full := Fullness (Natural (L.Full) + Amount);
      end if;
      L.Empty_For := 0;
   end Feed;

end Island.Stomach;
