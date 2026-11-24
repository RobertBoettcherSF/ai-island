-- One command in, one reply out. JSON is the agent protocol. Plain sentences
-- are the human protocol. Both come from the same world rules.
with Island.World;

package Island.Text is

   procedure Execute
     (S        : in out Island.World.State;
      Command  : String;
      As_Text  : Boolean;
      Reply    : out Reply_Buffer;
      Len      : out Natural;
      Ok       : out Boolean)
     with Pre => Island.World.Valid (S),
          Post => Island.World.Valid (S) and then Len <= Reply'Length;

   --  A command that does not fit in the fixed buffer. Does not touch a world.
   procedure Write_Too_Long
     (Reply : out Reply_Buffer; Len : out Natural; Ok : out Boolean);

end Island.Text;
