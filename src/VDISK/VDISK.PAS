program vdisk;

uses    Dos, Crt;

const
    FDDType   : Array [1..5] of String =
               ('360 KByte',
                '1.2 MByte',
                '720 KByte',
                '1.44 MByte',
                '2.88 MByte');

    FDDTracks : Array [1..5] of Byte =
               (39, 79, 79, 79, 79);

    FDDSec    : Array [1..5] of Byte =
               (9, 15, 9, 18, 36);

    BinType   : Array [1..16] of Word =
               (1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096,
                8192, 16384, 32768);

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


    HDDInfo     = record
     Zylinder   : integer;
     Sektoren   : integer;
     Koepfe     : Word;
     Size       : Word;
    end;

    FDDInfo     = record
     Typ        : Byte;
     Tracks     : Byte;
     Sektoren   : Byte;
    end;

    SektorType  = Array[1..512] of byte;

var
    R        : Registers;
    Laufwerk : Byte;
    IsHDD    : Boolean;
    HDD      : HDDinfo;
    FDD      : FDDInfo;

function ReadPartSec( Laufwerk, Kopf : byte;
                      SekZyl         : word;
                      var Buf        : PartSec ) : boolean;

var Regs : Registers;              { Prozessorregs fr Interruptaufruf }

begin
   Regs.AX := $0201;                      { Fktnr. fr "Read", 1 Sektor }
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
  WritePartSec:=(R.flags and 1 )=0;
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
  WriteSec:=(R.flags and 1 )=0;
end;

{Konvertiert die Sektor/Zylinder Angabe des Bios in ihre Bestandteile}
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

procedure Header; {Zeigt Screenkopf}
begin
 clrscr;
  write('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
  writeln(' VOS/9 VDISK (DOS-Version)     Version 1.01  (C)(R) 1995 by MZ Computer Systems');
  write('ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
  writeln;
  if IsHdd then begin
   writeln(' Laufwerk ',Upcase(Chr(Laufwerk+67)),': ',HDD.Zylinder, ' Zylinder, ',
          HDD.Sektoren, ' Sektoren, ',HDD.Koepfe,' Koepfe = ',HDD.Size,' MByte');
  end else
   writeln(' Laufwerk ',UpCase(Chr(Laufwerk+65)),':  ',FDDType[FDD.Typ],', ',
         FDD.Sektoren, ' Sektoren, ',FDD.Tracks,' Tracks/Sektor');
  writeln;
end;

procedure DetectDriveData;
var LfwTxt : String[1];
    Drive  : Byte;

begin
  if ParamCount=0 then begin
   writeln('VDISK Version 1.0 Release 0');
   writeln('(C)(R) 1995 by MZ Computer Systems');
   writeln;
   writeln('Syntax: VDISK Laufwerk');
   writeln;
   writeln('Laufwerk muá eine Festplatte oder ein Diskettenlaufwerk sein!');
   halt(1);
  end;
  LfwTxt:=ParamStr(1);
  case UPCASE(LfwTxt[1]) of
   'A' : begin Laufwerk:=0; IsHdd:=False; end;
   'B' : begin Laufwerk:=1; IsHdd:=False; end;
   else begin
    Laufwerk:=Ord(UPCASE(LfwTxt[1]))-67;
    IsHdd:=True;
   end;
  end;

  if IsHdd then Drive:=Laufwerk+$80 else Drive:=Laufwerk;

  {Equipment check!}
  r.ah:=$8;
  r.dl:=drive;
  Intr($13, r);

  if IsHdd then begin
   if (r.ah>0) then begin
    writeln('VDISK Version 1.0 Release 0');
    writeln('(C)(R) 1995 by MZ Computer Systems');
    writeln;
    writeln('Das Laufwerk ',LfwTxt,' ist dem System nicht bekannt!');
    writeln('Eventuell ist es ein Netzwerk, CD-ROM, oder ber SUBST');
    writeln('zugewiesenes Laufwerk. Diese Laufwerke k”nnen nicht');
    writeln('bearbeitet werden!');
    halt(2);
   end;
   GetSekZyl(r.cx, r.dx, HDD.Sektoren, HDD.Zylinder, HDD.Koepfe);
   HDD.Size:=Round(((HDD.Sektoren*512*HDD.Koepfe*HDD.Zylinder)/1024)/1024);
  end else begin
   if (r.bl=0) or (r.bl>6) then begin
    writeln('VDISK Version 1.0 Release 0');
    writeln('(C)(R) 1995 by MZ Computer Systems');
    writeln;
    writeln('Das Laufwerk ',LfwTxt,' ist dem System nicht bekannt!');
    writeln('Eventuell ist es ein Netzwerk, CD-ROM, oder ber SUBST');
    writeln('zugewiesenes Laufwerk. Diese Laufwerke k”nnen nicht');
    writeln('bearbeitet werden!');
    halt(2);
   end;
   FDD.Typ     :=r.bl;
   FDD.Tracks  :=FDDTracks[r.bl];
   FDD.Sektoren:=FDDSec[r.bl];
  end;
end;

function GetDriveData(Was: Char): Boolean;
var  Drive  : Byte;

begin
  case UPCASE(Was) of
   'A' : begin Laufwerk:=0; IsHdd:=False; end;
   'B' : begin Laufwerk:=1; IsHdd:=False; end;
   else begin
    Laufwerk:=Ord(UPCASE(Was))-67;
    IsHdd:=True;
   end;
  end;

  if IsHdd then Drive:=Laufwerk+$80 else Drive:=Laufwerk;

  {Equipment check!}
  r.ah:=$8;
  r.dl:=drive;
  Intr($13, r);

  if IsHdd then begin
   if (r.ah>0) then begin
    writeln;
    writeln('Das Laufwerk ',Was,' ist dem System nicht bekannt!');
    writeln('Eventuell ist es ein Netzwerk, CD-ROM, oder ber SUBST');
    writeln('zugewiesenes Laufwerk. Diese Laufwerke k”nnen nicht');
    writeln('bearbeitet werden!');
    writeln;
    GetDriveData:=False;
   end else begin
    GetSekZyl(r.cx, r.dx, HDD.Sektoren, HDD.Zylinder, HDD.Koepfe);
    HDD.Size:=Round(((HDD.Sektoren*512*HDD.Koepfe*HDD.Zylinder)/1024)/1024);
    GetDriveData:=True;
   end;
  end else begin
   if (r.bl=0) or (r.bl>6) then begin
    writeln;
    writeln('Das Laufwerk ',Was,' ist dem System nicht bekannt!');
    writeln('Eventuell ist es ein Netzwerk, CD-ROM, oder ber SUBST');
    writeln('zugewiesenes Laufwerk. Diese Laufwerke k”nnen nicht');
    writeln('bearbeitet werden!');
    Writeln;
    GetDriveData:=False;
   end else begin
    GetDriveData:=True;
    FDD.Typ     :=r.bl;
    FDD.Tracks  :=FDDTracks[r.bl];
    FDD.Sektoren:=FDDSec[r.bl];
   end;
  end;
end;

procedure ShowPartition(LW: Byte);
var Entry   : Byte;
    Kopf    : byte;
    SecZyl  : byte;
    Regs    : Registers;
    ParSec  : PartSec;
    Sektor,
    Zylinder: Word;

begin
  FillChar(ParSec, SizeOf(ParSec), ' ');
  if ReadPartSec( LW, 0, 1, ParSec ) then     { Partitionssektor lesen }
    begin                               { Sektor konnte gelesen werden }
      writeln('ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»');
      writeln('º Partitionstabelle im Partitionssektor     '+
              '                              º');
      writeln('ÌÍÍÑÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍ¹');
      writeln('º  ³    ³                   ³     Start    ³'+
              '     Ende     ³Entf.v.³       º');
      writeln('ºNr³Boot³Typ                ³Kopf Zyl. Sek.³'+
              'Kopf Zyl. Sek.³BootSek³Anzahl º');
      writeln('ÌÍÍØÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍØ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍØÍÍÍÍÍÍÍ¹');
      for Entry:=1 to 4 do         { die Tabellen-Eintr„ge durchlaufen }
        with ParSec.PartTable[ Entry ] do
          begin
          write('º ', Entry, '³');
          if Status = $80 then write (' Ja ')
                               else write ('Nein');
          write('³');
          case PartTyp of                    { Partitionstyp auswerten }
            $00        : write('nicht belegt       ');
            $01        : write('DOS, 12-Bit-FAT    ');
            $02        : write('XENIX root         ');
            $03        : write('XENIX user         ');
            $04        : write('DOS 16-Bit-FAT<32MB');
            $05        : write('DOS, extended Part.');
            $06        : write('DOS 16-Bit-FAT>32MB');
            $07        : write('OS/2 HPFS          ');
            $08        : write('AIX                ');
            $09        : write('AIX bootable       ');
            $0A        : write('Opus               ');
            $40        : write('Venix              ');
            $51        : write('Novell ?           ');
            $52        : write('Microport          ');
            $63        : write('GNU Hurt           ');
            $64        : write('Novell             ');
            $65        : write('Novell Netware 386 ');
            $75        : write('PC / IX            ');
            $80        : write('Minix (old)        ');
            $81        : write('Linux / Minix      ');
            $82        : write('Linux swap         ');
            $83        : write('Linux extended fs  ');
            $93        : write('Amoeba             ');
            $94        : write('Amoeba BBT         ');
            $B7        : write('BSDI fs            ');
            $B8        : write('BSDI swap          ');
            $C0        : write('Novell DOS (gesch.)');
            $C7        : write('Syrinx             ');
            $D0        : write('VOS/9 Mehrplatz    ');
            $D1        : write('VOS/9 Einzelplatz  ');
            $D2        : write('VOS/9 Swap         ');
            $DB        : write('CP/M               ');
            $E1        : write('DOS access         ');
            $E3        : write('DOS R/O            ');
            $F2        : write('DOS secondary      ');
            $FF        : write('BBT                ');
           else         write('unbekannt (',PartTyp:3,')    ');
          end;
          GetSecZyl( StartSec.SecZyl, Sektor, Zylinder );
          write('³', StartSec.Kopf:2,' ',Zylinder:5,'  ',Sektor:3 );
          GetSecZyl( EndSec.SecZyl, Sektor, Zylinder );
          write(' ³', EndSec.Kopf:2,' ',Zylinder:5,'  ',Sektor:3 );
          writeln(' ³', SecOfs:7,'³', SecAnz:7,'º');
        end;
      writeln('ÈÍÍÏÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍ¼'#13#10);
    end
  else
    writeln('Fehler beim Zugriff auf den Bootsektor!');
end;

procedure CreatePartition(LW: Byte);
var  Regs        : Registers;
     ParSec      : PartSec;
     FreePart    : Byte;
     Entry       : Byte;
     Auswahl     : Char;
     FullPartSize: Integer;
     LastZyl     : Word;
     LastSec     : Word;
     FreeSize    : Word;

     EndSekZyl   : Word;
begin
  {Wir holen erst mal die aktuellen Partitionen und sehen ob
   dort noch Platz fr eine neue ist. Wir wollen schliesslich auch
   keine bestehende berschreiben...}
  FillChar(ParSec, SizeOf(ParSec), ' ');
  if ReadPartSec( LW, 0, 1, ParSec ) then begin
   FreePart:=0;
   Entry:=1;
   LastZyl:=0;
   FullPartSize:=0;

   repeat
    if ParSec.PartTable[ Entry ].PartTyp=0 then FreePart:=Entry else begin
     GetSecZyl(ParSec.PartTable[Entry].EndSec.SecZyl, LastSec, LastZyl);
     if LastZyl>FullPartSize then FullPartSize:=LastZyl;
    end;
    Inc(Entry);
   until (FreePart>0) or (Entry=5);

   if FreePart=0 then begin
    writeln;
    writeln('Es sind bereits vier Partitionen vorhanden!');
    writeln;
    writeln('  === TASTE === ');
    Auswahl:=Readkey;
   end else begin
    FreeSize:=Round(((HDD.Sektoren*512*HDD.Koepfe*FullPartSize)/1024)/1024);
    writeln('Bisher sind ',FullPartSize,' Zyliner belegt = ',FreeSize,' MByte');
    writeln;
    if FullPartSize>=HDD.Zylinder-3 then begin
     ShowPartition(LW);
     writeln('Es kann keine weitere Partition auf diesem Datentr„ger erstellt');
     writeln('werden, da dessen Kapazit„t mit Partitionen bereits belegt ist.');
     writeln;
     write('  === TASTE === ');
     Auswahl:=ReadKey;
     exit;
    end;
    writeln('Anlegen einer neuen Partition (Partition Nr. ',FreePart,') - ESC = Abbruch');
    writeln;
    write('Gesamten freien Bereich (',HDD.Size-FreeSize,' MByte) fr VOS/9 reservieren (J/N)? ');

    Auswahl:=ReadKey;
    if Auswahl=#27 then exit;
    writeln(Auswahl);

    ParSec.PartTable[FreePart].PartTyp:=$D0; {ID ist immer korrekt VOS/9}
    ParSec.PartTable[FreePart].Status:=$0; {Wir wissen noch nicht ob Boot-Part}

    if Upcase(Auswahl)='J' then begin
      if (FreePart=1) then begin
       {Die 1. Partition beginnt bei Head 1, Sektor 1, Cylinder 0}
       with ParSec.PartTable[FreePart] do begin
         StartSec.Kopf:=1;
         {Sektor und Zylinder mssen Codiert werden..}
         SetSecZyl(1, 0, StartSec.SecZyl);
       end;
      end else begin
       GetSecZyl(ParSec.PartTable[FreePart-1].EndSec.SecZyl, LastSec, LastZyl);
       inc(LastZyl);
       SetSecZyl(1, LastZyl, ParSec.PartTable[FreePart].StartSec.SecZyl);
       ParSec.PartTable[FreePart].StartSec.Kopf:=0;
      end;
       {Der Benutzer will alles fr VOS/9... Wir geben alles!}
       with ParSec.PartTable[FreePart] do begin
         EndSec.Kopf:=HDD.Koepfe-1;  {Letzter Kopf ist max der Koepfe}
         SetSecZyl(HDD.Sektoren, HDD.Zylinder-1, EndSec.SecZyl);

         SecOfs:=HDD.Sektoren; {Abstand zum Boot-Sektor in Sektoren}
         {Gr”áe der Part. in  Sektoren...}
         SecAnz:=(((HDD.Zylinder-1)*55)+((HDD.Koepfe-1)*HDD.Zylinder*HDD.Sektoren));
       end;
     end else begin

     end;
     {Nun k”nnen wir den gesamten Klamauk sichern...(hoffe ich!)}
      if WritePartSec( LW, 0, 1, ParSec ) then begin
       writeln;
       write('Partition ',FreePart,' erstellt.  === TASTE ===');
       Auswahl:=ReadKey;
      end else begin
       writeln;
       write('Fehler beim Lesen des Partitionssektors!');write('  === TASTE === ');
       Auswahl:=Readkey;
      end;
   end;
  end else begin
   writeln;
   writeln('Fehler beim Lesen des Partitionssektors!');
   writeln;
   writeln('  === TASTE === ');
   Auswahl:=Readkey;
  end;
end;

procedure DeletePartition(LW: Byte);
var  Auswahl     : Char;
     Part        : Byte;
     ParSec      : PartSec;
     Code        : Integer;
begin
 ShowPartition(LW);
 writeln;
 writeln('L™SCHEN einer Partition - ESC zum Abrechen!');
 writeln;
 write('Zu l”schende Partition (1..4): '); Auswahl:=Readkey;
 if Auswahl=#27 then exit;
 val(Auswahl, Part, Code);
 if (Part<=0) or (Part>4) then exit;
  writeln(Auswahl);
  write('Sind Sie sicher (J/N)? '); Auswahl:=Readkey;

   if Upcase(Auswahl)='N' then exit;
   writeln(Auswahl);

  FillChar(ParSec, SizeOf(ParSec), ' ');
  if ReadPartSec( LW, 0, 1, ParSec ) then begin

   if ParSec.PartTable[Part].PartTyp=$0 then begin
    write('Keine Partition zum L”schen vorhanden!  === TASTE ===');
    Auswahl:=Readkey;
    exit;
   end;
   with
    ParSec.PartTable[Part] do begin
    Status:=$0;
    StartSec.Kopf:=$0;
    StartSec.SecZyl:=$0;
    EndSec.Kopf:=$0;
    EndSec.SecZyl:=$0;
    PartTyp:=$0;
    SecOfs:=$0;
    SecAnz:=$0;
   end;

   {Eintrag ist nun šberschrieben - Wir schreiben ihn und alle anderen
    nun zurck}
   if WritePartSec( LW, 0, 1, ParSec ) then begin
     write('Partition ',Part,' wurde gel”scht!'); write('  === TASTE ===');
     Auswahl:=Readkey;
    end else begin
     writeln;
     write('Fehler beim Schreiben des Partitionssektors!'); write('  === TASTE ===');
     Auswahl:=Readkey;
   end;
  end else begin
   writeln;
   writeln('Fehler beim Lesen des Partitionssektors!');
   writeln;
   writeln('  === TASTE === ');
   Auswahl:=Readkey;
  end;
end;

procedure ActivatePartition(LW: Byte);
var  Auswahl     : Char;
     Part        : Byte;
     ParSec      : PartSec;
     Code        : Integer;
begin
 ShowPartition(LW);
 writeln;
 writeln('Aktivieren/Deaktivieren einer Partition - ESC zum Abrechen!');
 writeln;
 write('Zu Aktivierende/Deaktivierende Partition (1..4): '); Auswahl:=Readkey;
 if Auswahl=#27 then exit;
 val(Auswahl, Part, Code);
 if (Part<=0) or (Part>4) then exit;
  writeln(Auswahl);

  FillChar(ParSec, SizeOf(ParSec), ' ');
  if ReadPartSec( LW, 0, 1, ParSec ) then begin

   if ParSec.PartTable[Part].PartTyp=$0 then begin
    writeln('Partition ',Part,' enth„lt keine gltigen Partitionsdaten!');
    writeln('Legen Sie zuerst eine Partition an.  === TASTE ===');
    Auswahl:=ReadKey;
    exit;
   end;
   with ParSec.PartTable[Part] do begin
    if Status=$80 then Status:=$0 else Status:=$80;
   end;

   {Eintrag ist nun šberschrieben - Wir schreiben ihn und alle anderen
    nun zurck}
   if WritePartSec( LW, 0, 1, ParSec ) then begin
     if ParSec.PartTable[Part].Status=$80 then begin
      write('Partition ',Part,' wurde AKTIVIERT!'); write('  === TASTE ===');
     end else begin
      write('Partition ',Part,' wurde DEAKTIVIERT!'); write('  === TASTE ===');
     end;
     Auswahl:=Readkey;
    end else begin
     writeln;
     write('Fehler beim Schreiben des Partitionssektors!'); write('  === TASTE ===');
     Auswahl:=Readkey;
   end;
  end else begin
   writeln;
   writeln('Fehler beim Lesen des Partitionssektors!');
   writeln;
   writeln('  === TASTE === ');
   Auswahl:=Readkey;
  end;
end;


procedure WriteSysID(LW: Byte);
var  Auswahl     : Char;
     Part        : Byte;
     ParSec      : PartSec;
     Code        : Integer;
     Kennung     : String[3];
     Knum        : Byte;
begin
 ShowPartition(LW);
 writeln('ndern des System-ID einer Partition - ESC zum Abrechen!');
 writeln;
 writeln('Durch das „ndern der ID gehen keine Daten verloren. Es ist jedoch m”glich,');
 writeln('daá das Betriebssystem diese nicht mehr erkennt und ein Zugriff nicht mehr');
 writeln('m”glich ist. Eine nderung der ID ist jederzeit m”glich.');
 writeln;
 write('ndern der ID von Partition (1..4): '); Auswahl:=Readkey;
 if Auswahl=#27 then exit;
 val(Auswahl, Part, Code);
 if (Part<=0) or (Part>4) then exit;
  writeln(Auswahl);

  FillChar(ParSec, SizeOf(ParSec), ' ');
  if ReadPartSec( LW, 0, 1, ParSec ) then begin

   if ParSec.PartTable[Part].PartTyp=$0 then begin
    writeln('Partition ',Part,' enth„lt keine gltigen Partitionsdaten!');
    writeln('Legen Sie zuerst eine Partition an.  === TASTE ===');
    Auswahl:=ReadKey;
    exit;
   end;

   Header;
   writeln('NDERN der ID von Partition Nr. ',Part, '(Aktuelle ID ',
    ParSec.PartTable[Part].PartTyp,')');
   writeln;
   writeln('Die System ID einer Partition kann ein beliebiger Wert zwischen 1 und');
   writeln('255 sein. Der Wert 0 ist nicht zul„ssig!');
   writeln(' 001  DOS, 12-Bit-Fat       081  Novell         183  BSDI fs    ');
   writeln(' 002  Xenix (root)          082  Microport      184  BSDI swap  ');
   writeln(' 003  Xenix (User)          099  GNU Hurt       199  Syrinx     ');
   writeln(' 004  DOS 16-Bit-Fat <32MB  100  Novell         219  CP/M       ');
   writeln(' 005  DOS extended Part     117  PC/IX          225  DOS access ');
   writeln(' 006  DOS 16-Bit-Fat >32MB  128  Minix (alt)    227  DOS R/O    ');
   writeln(' 007  OS/2 HPFS             129  Linux/Minix    242  DOS (sec.) ');
   writeln(' 008  AIX                   130  Linux (swap)   255  BBT        ');
   writeln(' 009  AIX (boot)            131  Linux (extfs)  208  VOS/9 Mehrplatz');
   writeln(' 010  Opus                  147  Amoeba         209  VOS/9 Einplatz ');
   writeln(' 064  Venix                 148  Amoeba BBT     210  VOS/9 swap     ');
   writeln;
   write('Neue ID fr Partition ',Part,': '); Readln(Kennung);

   val(Kennung, KNum, Code);
   if (Knum<=0) or (Knum>255) then begin
    writeln;
    write('Ungltige ID ',Knum,'!    === TASTE ===');
    ReadKey;
    exit;
   end;

   ParSec.PartTable[Part].PartTyp:=KNum;

   {Eintrag ist nun šberschrieben - Wir schreiben ihn und alle anderen
    nun zurck}
   if WritePartSec( LW, 0, 1, ParSec ) then begin
     write('Partitions ID wurde ge„ndert!  === TASTE ===');
     Auswahl:=Readkey;
    end else begin
     write('Fehler beim Schreiben des Partitionssektors!'); write('  === TASTE ===');
     Auswahl:=Readkey;
   end;
  end else begin
   writeln;
   writeln('Fehler beim Lesen des Partitionssektors!');
   writeln;
   writeln('  === TASTE === ');
   Auswahl:=Readkey;
  end;
end;

procedure ChangeParts(LW: byte);
var  Auswahl     : Char;
     Part        : Byte;
     DestPart    : Byte;
     ParSec      : PartSec;
     Code        : Integer;
     Kennung     : String[3];
     Knum        : Byte;
begin
 ShowPartition(LW);
 writeln('ndern Partitionsfolge                   - ESC zum Abrechen!');
 writeln;
 write('Verschieben von Partition (1..4): '); Auswahl:=Readkey;
 if Auswahl=#27 then exit;
 val(Auswahl, Part, Code);
 if (Part<=0) or (Part>4) then exit;
  writeln(Auswahl);
  FillChar(ParSec, SizeOf(ParSec), '.');
  if ReadPartSec( LW, 0, 1, ParSec ) then begin

   if ParSec.PartTable[Part].PartTyp=$0 then begin
    writeln('Partition ',Part,' enth„lt keine gltigen Partitionsdaten!');
    writeln('Verschieben der Partition nicht m”glich!  === TASTE ===');
    Auswahl:=ReadKey;
    exit;
   end;
   write('Verschieben zu  Partition (1..4): '); Auswahl:=Readkey;
   if Auswahl=#27 then exit;
    val(Auswahl, DestPart, Code);
   if (DestPart<=0) or (DestPart>4) then exit;
   writeln(Auswahl);

   if ParSec.PartTable[DestPart].PartTyp<>$0 then begin
    writeln('Partition ',Part,' ist bereits belegt!');
    writeln('Verschieben der Partition nicht m”glich!  === TASTE ===');
    Auswahl:=ReadKey;
    exit;
   end;

   {Wir bewegen nun die Daten aus Part nach DestPart und
    anschlieáend l”schen wir die Daten in Part}

   ParSec.PartTable[DestPart]:=ParSec.PartTable[Part];
   with
    ParSec.PartTable[Part] do begin
    Status:=$0;
    StartSec.Kopf:=$0;
    StartSec.SecZyl:=$0;
    EndSec.Kopf:=$0;
    EndSec.SecZyl:=$0;
    PartTyp:=$0;
    SecOfs:=$0;
    SecAnz:=$0;
   end;

   {Eintrag ist nun šberschrieben - Wir schreiben ihn und alle anderen
    nun zurck}
   if WritePartSec( LW, 0, 1, ParSec ) then begin
     write('Partitionsfolge wurde ge„ndert!  === TASTE ===');
     Auswahl:=Readkey;
    end else begin
     write('Fehler beim Schreiben des Partitionssektors!'); write('  === TASTE ===');
     Auswahl:=Readkey;
   end;
  end else begin
   writeln;
   writeln('Fehler beim Lesen des Partitionssektors!');
   writeln;
   writeln('  === TASTE === ');
   Auswahl:=Readkey;
  end;
end;

var Auswahl: Char;
    Lfw    : Byte;

begin
 DetectDriveData;
 if IsHdd then Lfw:=Laufwerk+$80 else Lfw:=Laufwerk;

 repeat
  Header;
  writeln(' [ 1] ... Partitionstabelle Anzeigen');
  writeln(' [ 2] ... Laufwerk Wechseln');
  writeln(' [ 3] ... Partition Erstellen');
  writeln(' [ 4] ... Partition L”schen');
  writeln(' [ 5] ... Aktivieren/Deaktivieren einer Partition');
  writeln(' [ 6] ... System-Kennung auf Partition ndern');
  writeln(' [ 7] ... Partitionsfolge ndern');
  writeln;
  writeln(' [ 0] ... Beenden');
  writeln;
  writeln;
  write('Auswahl: '); Auswahl:=ReadKey; Writeln(Auswahl);

  Header;

  case Auswahl of
    '1' : begin
            if IsHdd then ShowPartition(Lfw)
            else Writeln('Disketten verfgen ber keinen Partitionssektor!');
             writeln;
             writeln('  === Taste ===');ReadKey;
          end;
    '2' : begin
           repeat
            write;
            write('Laufwerk: ');
            Auswahl:=ReadKey;
            writeln(UPCASE(Auswahl));
           until GetDriveData(Auswahl);
           if IsHdd then Lfw:=Laufwerk+$80 else Lfw:=Laufwerk;
          end;
    '3' : begin
           if IsHdd then CreatePartition(Lfw)
           else begin
            Writeln('Disketten verfgen ber keinen Partitionssektor!');
            Writeln('Anlegen einer Partition ist daher unm”glich.');
            writeln;
            writeln('  === Taste ===');ReadKey;
           end;
          end;
    '4' : begin
           if IsHdd then DeletePartition(Lfw)
           else begin
            Writeln('Disketten verfgen ber keinen Partitionssektor!');
            Writeln('L”schen einer Partition ist daher unm”glich.');
            writeln;
            writeln('  === Taste ===');ReadKey;
           end;
          end;
    '5' : begin
           if IsHdd then ActivatePartition(Lfw)
           else begin
            Writeln('Disketten verfgen ber keinen Partitionssektor!');
            Writeln('Aktivieren/Deaktivieren einer Partition ist daher unm”glich.');
            writeln;
            writeln('  === Taste ===');ReadKey;
           end;
          end;
    '6' : if IsHdd then WriteSysID(lfw) else begin
            Writeln('Disketten verfgen ber keinen Partitionssektor!');
            Writeln('Schreiben der System ID auf einer Partition ist daher unm”glich.');
            writeln;
            writeln('  === Taste ===');ReadKey;
          end;
    '7' : if IsHdd then ChangeParts(Lfw) else begin
            Writeln('Disketten verfgen ber keinen Partitionssektor!');
            Writeln('ndern einer Partitionfolge ist daher unm”glich.');
            writeln;
            writeln('  === Taste ===');ReadKey;
          end;
  end;
 until Auswahl='0';
 writeln(' Bye...');
end.
