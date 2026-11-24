with Interfaces;

--  One explicit word of state. SplitMix32, no heap, no clock.
--  The same seed and the same number of draws always give the same values.
package Island.Rng is

   type State is record
      Word : Interfaces.Unsigned_32 := 0;
   end record;

   function Init (Seed : Interfaces.Unsigned_32) return State;

   procedure Next (S : in out State; Value : out Interfaces.Unsigned_32);

   --  A draw in 0 .. Bound - 1.
   function Below (S : in out State; Bound : Positive) return Natural
     with Post => Below'Result < Bound;

   --  Stateless mix of three words. Terrain may hash a tile with this.
   function Mix
     (Seed, A, B : Interfaces.Unsigned_32) return Interfaces.Unsigned_32;

end Island.Rng;
