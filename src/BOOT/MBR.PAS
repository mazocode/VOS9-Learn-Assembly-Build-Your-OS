{ MBR - (c)(r) 1995 by MZ Computer Systems
  Kopieren des Master Boot-Records }

program write_mbr;

uses  dos;

var   BootPtr   : Pointer;

type  SecPos    = record       { beschreibt die Position eines Sektors }
                    Kopf : byte;                   { Schreib-/Lesekopf }
                    SecZyl : word;        { Sektor- und Zylindernummer }
                  end;

      PartEntry = record            { Eintrag in der Partitionstabelle }
                    Status   : byte;               { Partitions-Status }
                    StartSec : SecPos;                 { erster Sektor }
                    PartTyp  : byte;                  { Partitions-Typ }
                    EndSec   : SecPos;                { letzter Sektor }
                    SecOfs   : longint;      { Offset des Boot-Sektors }
                    SecAnz   : longint;          { Anzahl der Sektoren }
                  end;

      PartSec   = record           { beschreibt den Partititionssektor }
                    BootCode  : array [0..$1BD] of byte;
                    PartTable : array [1..4] of PartEntry;
                    IdCode    : word;                          { $AA55 }
                  end;

      HDDInfo   = record
       Zylinder : integer;
       Sektoren : integer;
       Koepfe   : Word;
       Size     : Word;
       PartHead : Byte;
       PartSec  : Word;
       PartCyl  : Word;
      end;

      SektorType        = Array[1..512] of byte;

var
       R        : Registers;
       HDD      : HDDinfo;
       Boot     : PartSec;

       StartingSec    : Word;
       StartingCyl    : Word;
       StartingHead   : Byte;
       SetupReadSize  : Word;
       StartSecZyl    : Word;

       Setup          : SektorType;



procedure GetSekZyl(SekZyl: Word; SekZylB: Word; var Sek, Zyl: integer; var Koepfe: Word);
begin
 Sek:=SekZyl and 63;
 Zyl:=(hi(SekZyl)+(lo(SekZyl) and 192) shl 2)+1;
 Koepfe  :=(Swap(SekZylB) and 63)+1;
end;

procedure GetSecZyl( SekZyl : word; var Sektor, Zylinder : word );
begin
  Sektor   := SekZyl and 63;                 { Bits 6 und 7 ausblenden }
  Zylinder := hi( SekZyl ) + ( lo( SekZyl) and 192 ) shl 2;
end;

procedure SetSecZyl( Sekt, Zyli : Word; var NewSekZyl: Word);
begin
 {Ich liebe diese Bit-Schieberei... (You can shove it up - your ass)}
 NewSekZyl:=lo(Zyli);
 NewSekZyl:=NewSekZyl shl 8;
 NewSekZyl:=NewSekZyl + (hi(Zyli) shl 6);
 NewSekZyl:=NewSekZyl + (Sekt and 63);
end;

function ReadPartSec( Laufwerk, Kopf : byte;
                      SekZyl         : word;
                      var Buf        : PartSec ) : boolean;

var Regs : Registers;              { Prozessorregs f걊 Interruptaufruf }

begin
   Regs.AX := $0201;                      { Fktnr. f걊 "Read", 1 Sektor }
   Regs.DL := Laufwerk;                        { die weiteren Parameter }
   Regs.DH := Kopf;                            { in die verschiedenen   }
   Regs.CX := SekZyl;                          { Register laden         }
   Regs.ES := seg( Buf );
   Regs.BX := ofs( Buf );
   Intr( $13, Regs);                       { Festplatten-Intr. aufrufen }
   ReadPartSec := ( Regs.Flags and 1 ) = 0;  {Carry-Flag zeigt Fehler an}
end;

function WritePartSec( Laufwerk, Kopf : byte;
                       SekZyl         : word;
                       var Buf        : PartSec ) : boolean;

var Regs    : Registers;
    Fcounter: Byte;

begin
  Regs.AX := $0301;
  Regs.DL := Laufwerk;
  Regs.DH := Kopf;
  Regs.CX := SekZyl;
  Regs.ES := seg( Buf );
  Regs.BX := ofs( Buf );
  Intr( $13, Regs);
  WritePartSec:=(Regs.flags and 1 )=0;
end;

function WriteSec( Laufwerk, Kopf : byte;
                       SekZyl     : word;
                       var Buf    : SektorType ) : boolean;

var Regs    : Registers;
    Fcounter: Byte;

begin
  Regs.AX := $0301;
  Regs.DL := Laufwerk;
  Regs.DH := Kopf;
  Regs.CX := SekZyl;
  Regs.ES := seg( Buf );
  Regs.BX := ofs( Buf );
  Intr( $13, Regs);
  WriteSec:=(Regs.flags and 1 )=0;
end;

procedure Header;
begin
  write('컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴');
  writeln(' VOS/9 MBR  (DOS-Version)     Version 1.03  (C)(R) 1995 by MZ Computer Systems');
  write('컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴');
  writeln;
end;

function CheckDrive(LW: Char):byte;
var      r     : registers;
         drive : byte;
begin
   drive:=ord(UPCASE(LW))+61;
 {Equipment check!}
 r.ah:=$8;
 r.dl:=drive;
 Intr($13, r);

 if (r.ah>0) then begin
  writeln('Das Laufwerk [',Upcase(LW),'] ist dem System nicht bekannt!');
  writeln('Eventuell ist es ein Netzwerk, CD-ROM, oder 갶er SUBST');
  writeln('zugewiesenes Laufwerk. Diese Laufwerke k봭nen nicht');
  writeln('bearbeitet werden!');
  halt(2);
 end;

 if drive>=$80 then begin
   GetSekZyl(r.cx, r.dx, HDD.Sektoren, HDD.Zylinder, HDD.Koepfe);
   HDD.Size:=Round(((HDD.Sektoren*512*HDD.Koepfe*HDD.Zylinder)/1024)/1024);
 end;
 CheckDrive:=Drive;
end;

var     Drv     : Byte;
        Param   : String;
        i       : integer;
        mbr     : boolean;
        found   : boolean;
        Part    : byte;
        Image   : File;
        Result  : Word;
        ParSec  : PartSec;
        ParSecB : PartSec;
        Fault   : Boolean;
        Retry   : Byte;

begin
  Header;

if ParamCount=0 then begin
  writeln('MBR 갶ertr꼏t den Master-Boot-Record auf die Platte');
   writeln;
  writeln('Syntax: MBR Laufwerk');
  writeln;
  halt(1);
end;
  Param:='';
  Param:=ParamStr(1);

  Drv:=CheckDrive(Param[1]);

   FillChar(Boot, SizeOf(Boot), '.');

   if not ReadPartSec(drv, 0, 1, Boot ) then begin
    writeln('Fehler beim Lesen von Laufwerk [',ParamStr(1),'] !');
    halt(3);
   end;

   write('Schreibe den VOS/9 Master-Boot-Record...');

   FillChar(ParSec, SizeOf(ParSec), '.');

   if not ReadPartSec(drv, 0, 1, ParSec ) then begin
    writeln('Fehler beim Lesen der Partitionstabelle!');
    halt(5);
   end;

   {Nun lesen wir den Boot-Code aus bootsec.bin nach Parsec.BootCode ein}
   {$I-}
   assign(Image, 'bootsec.bin');
   Reset(Image, 1);
   if IOResult<>0 then begin
    writeln('BOOTSEC.BIN nicht gefunden!');
    close(Image);
    halt(1);
   end;
   {Nun Lesen wir das BootSec Image ein}
   BlockRead(Image, ParSec.BootCode, 446, Result);
   if Result<>FileSize(Image) then begin
    writeln('BOOTSEC.BIN Lesefehler!');
    close(Image);
    halt(1);
   end;
   Fault:=False;
   Retry:=0;
   ParSec.IDCode:=$AA55;

   repeat
    Fault:=WritePartSec(drv, 0, 1, ParSec );
    if not Fault then Inc(Retry);
   until (Retry=4) or (Fault=True);

   if not Fault then begin
    writeln('Schreibfehler!');
    Close(Image);
    halt(1);
   end;
   writeln('(',FileSize(Image),' Bytes) OK');
   Close(Image);
   {$I+}
end.
