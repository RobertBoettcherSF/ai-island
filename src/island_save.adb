with Ada.Streams.Stream_IO;
with System;

package body Island_Save is

   procedure Load
     (Path   : String;
      S      : out Island.World.State;
      Status : out Load_Status)
   is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File : File_Type;
      Raw  : Stream_Element_Array (1 .. Stream_Element_Offset (Island.World.Save_Max));
      Item : Stream_Element_Array (1 .. 1);
      Last : Stream_Element_Offset;
      N    : Natural := 0;
      Buf  : String (1 .. Island.World.Save_Max);
      Ok   : Boolean;
   begin
      Open (File, In_File, Path);
      loop
         Read (File, Item, Last);
         exit when Last < Item'First;
         if N = Island.World.Save_Max then
            Close (File);
            Island.World.Reset (S);
            Status := Bad;
            return;
         end if;
         N := N + 1;
         Raw (Stream_Element_Offset (N)) := Item (1);
      end loop;
      Close (File);
      for I in 1 .. N loop
         Buf (I) := Character'Val (Natural (Raw (Stream_Element_Offset (I))));
      end loop;
      if N = 0 then
         Island.World.Reset (S);
         Status := Bad;
         return;
      end if;
      Island.World.Read_Save (Buf (1 .. N), S, Ok);
      if Ok then
         Status := Loaded;
      else
         Island.World.Reset (S);
         Status := Bad;
      end if;
   exception
      when Name_Error =>
         if Is_Open (File) then
            Close (File);
         end if;
         Island.World.Reset (S);
         Status := Missing;
      when Use_Error | Device_Error | End_Error | Status_Error | Mode_Error
         | Data_Error =>
         if Is_Open (File) then
            Close (File);
         end if;
         Island.World.Reset (S);
         Status := Io_Error;
   end Load;

   procedure Store
     (Path : String;
      S    : Island.World.State;
      Ok   : out Boolean)
   is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      Buf  : String (1 .. Island.World.Save_Max);
      Len  : Natural;
      Temp : constant String := Path & ".tmp";
      File : File_Type;
      Raw  : Stream_Element_Array (1 .. Stream_Element_Offset (Island.World.Save_Max));

      function C_Rename (Old_Name, New_Name : System.Address) return Integer
        with Import, Convention => C, External_Name => "rename";

      From_C : constant String := Temp & ASCII.NUL;
      To_C   : constant String := Path & ASCII.NUL;
      RC     : Integer;
   begin
      Island.World.Write_Save (S, Buf, Len);
      for I in 1 .. Len loop
         Raw (Stream_Element_Offset (I)) :=
           Stream_Element (Character'Pos (Buf (I)));
      end loop;
      Create (File, Out_File, Temp);
      Write (File, Raw (1 .. Stream_Element_Offset (Len)));
      Close (File);
      --  POSIX rename replaces the old save. Ada.Directories.Rename does not.
      RC := C_Rename (From_C'Address, To_C'Address);
      if RC /= 0 then
         Ok := False;
         return;
      end if;
      Ok := True;
   exception
      when Name_Error | Use_Error | Device_Error | End_Error | Status_Error
         | Mode_Error | Data_Error =>
         if Is_Open (File) then
            Close (File);
         end if;
         Ok := False;
   end Store;

end Island_Save;
