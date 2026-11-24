-- Native save file. The world core only sees a byte buffer.
with Island.World;

package Island_Save is

   type Load_Status is (Loaded, Missing, Bad, Io_Error);

   procedure Load
     (Path   : String;
      S      : out Island.World.State;
      Status : out Load_Status);

   procedure Store
     (Path : String;
      S    : Island.World.State;
      Ok   : out Boolean);

end Island_Save;
