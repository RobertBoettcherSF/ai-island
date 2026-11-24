with System;

procedure Last_Chance (Msg : System.Address; Line : Integer)
  with Export, Convention => C, External_Name => "__gnat_last_chance_handler";
