package body Island.Rng is

   use Interfaces;

   --  The SplitMix finalizer. Modular arithmetic wraps on purpose.
   function Finish (Z0 : Unsigned_32) return Unsigned_32 is
      Z : Unsigned_32 := Z0;
   begin
      Z := (Z xor Shift_Right (Z, 16)) * 16#85EB_CA6B#;
      Z := (Z xor Shift_Right (Z, 13)) * 16#C2B2_AE35#;
      return Z xor Shift_Right (Z, 16);
   end Finish;

   function Init (Seed : Unsigned_32) return State is
   begin
      return (Word => Seed);
   end Init;

   procedure Next (S : in out State; Value : out Unsigned_32) is
   begin
      S.Word := S.Word + 16#9E37_79B9#;
      Value := Finish (S.Word);
   end Next;

   function Below (S : in out State; Bound : Positive) return Natural is
      Value : Unsigned_32;
   begin
      Next (S, Value);
      return Natural (Value mod Unsigned_32 (Bound));
   end Below;

   function Mix (Seed, A, B : Unsigned_32) return Unsigned_32 is
   begin
      return Finish (Seed + A * 16#9E37_79B9# + B * 16#85EB_CA6B#);
   end Mix;

end Island.Rng;
