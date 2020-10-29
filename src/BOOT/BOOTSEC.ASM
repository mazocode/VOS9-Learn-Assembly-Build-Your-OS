;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; File_Name	  : MAKEROOT.ASM
; (c)(r) 1995 by MZ Computer Systems
;
; Description     : Master Bootstrap Record (MBR)
;
; Operating System: uses BIOS
; Language	  : Assembler
; Usage           : VOS-Package
;
; Link Objects    : -
; Exec-File       : EXE
; CPU             : x86
; CPU Mode	  : Real
; FPU             : -
; Memory Required : -
;
; Creation Date   : 12.01.1995
; Autor           : Marcus Zoller
; Version         : 1.0
; Version Date    : 29.10.1995
; Release         : 7
; Release Date    : 04.11.1995
; Released by     : Marcus Zoller
;
; Release Notes:
; Code Gr”áe maximal 446 Bytes - Rest bis 512 Bytes = Partitionstabelle
;
; 30.04.95, V0.0 R1: Multi-Drive Search hinzugefgt
; 28.08.95, V1.0 R2: ALT fordert VOS-Bootmanager
; 30.08.95, V1.0 R3: Radikalkur: Der VOS/9 Bootsektor wird nun aus
;		kompatibilit„ts-Grnden nicht mehr l„nger gesondert Behandelt.
;		Der Loader durchsucht alle HDs. Die erste Bootbare Part.
;		wird gestartet. Wir die ALT-Taste gedrckt gehalten, wird
;		ausschlieálich nach VOS/9 gesucht und dort das Boot-Setup
;		aufgerufen.
; 19.09.95: Wir bergen an den BootCode:
;		DL = Laufwerk
;		DH = Kopf Partitions start
;		CX = Sektor/Zylinder Part start
; 08.10.95, V1.0 R7: BOOTMAN Activation Key jetzt Variabel (kann durch
;		Bootmanager ge„ndert werden.
;		Codes:	0	=> Bootman nicht inst. =>Standard Bootstrap
;			ffh	=> Bootman sofort starten => VOS Part suchen
;				und an den Master die BootOpt bergeben
;			Taste	=> wenn gedrckt siehe ffh
;
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

code segment para use16 'CODE'
        assume cs:code, ds:code
        org 000h
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ			
start:  
	; Unser erster Job: Das Bios hat uns an 7c00 geladen. Wir mssen nun
	; erstmal Platz machen, um hier den BootCode zu laden...
	
	cli				; Mal Ruhe hier
	sub	ax, ax			; Segment Adr. 0
	mov	ss, ax
	mov	es, ax
	mov	ds, ax
	mov	ax, 7c00h
	mov	sp, ax
	sti
	cld
	mov	si, 7c00h		; Quell-Adresse
	mov	ax, 0060h		; Ziel Seg 60h
	mov	es, ax
	xor	di, di			; Ziel Offset 0
	mov	cx, 100h		; Wir kopieren 256 Words
	rep	movsw

	; Der Compiler erzeugt den Code nicht richtig! Warum- Bitte Borland
	; Fragen, ...
	
	db	0EAh,24h,00h,60h,00h

andup:
	mov	ax, 0060h		; Unsere Seg.-Addr.
	cli
	mov	ds, ax
	mov	es, ax
	xor	ax, ax
  	mov	ss, ax
  	mov	ax, 7000h		; Neuer Stack
  	mov	sp, ax
	cld

	;====================================================================
	; Nun wollen wir mal noch Hallo sagen...
	
	mov	byte ptr ds:[bootdrv], 80h	
	
	mov	si, offset 060h:bootmsg
	call	Print

	mov	bx, word ptr ds:[BOOTKEY]
	cmp	bx, 0ffffh
	je	BootVos
	cmp	bx, 0h
	je	NixDemand
	mov 	ah, 12h			; Taste gerade gedrckt oder im 
	int 	16h			; Buffer?
	test 	bx, ax
	jnz  	BootVos
NixDemand:
	mov	byte ptr ds:[vos], 00h
	jmp	short SearchSys
BootVos:
	mov	byte ptr ds:[vos], 0ffh
SearchSys:
	call	GetPartTab
	jc	short KeinSys
	call	CheckPartTab
	jc	short KeinSys
	call	BootIt
	mov	si, offset 060h:bootfailed
	jmp	short Endless
KeinSys:
	mov	dl, byte ptr ds:[bootdrv]
	cmp	dl, 87h				; Wirklich Nix!
	je	AbsolutNix
	inc	dl
	mov	byte ptr ds:[bootdrv], dl
	jmp     SearchSys
AbsolutNix:
	mov	si, offset 060h:bootnix
Endless:
	call	Print
	jmp	$
	
		
GetPartTab	proc near
	; Wir laden nun die Partitions-Tabelle von einem Laufwerk
	; und sehen ob es da was zu booten gibt...
	
	mov 	cx, 4		; maximal 4 Versuche
  ReadLoop:
	push 	cx		; Rest Merken
	
	mov	dl, byte ptr ds:[bootdrv]
	
	xor 	dh, dh		; Kopf 0   
	mov 	cx, 0001h	; Sektor 1, Cylinder 0
		
	mov 	ax, 1000h
	mov 	es, ax		; Segment nix
	xor 	bx, bx		; Offset 7c00h 
	mov 	ax, 0201h	; 1 Sektor lesen
	int 	13h

	pop 	cx		; Rest zurckholen

	cmp 	ah, 0 
	jz 	TabelleOK	; Lesen war OK

	push	cx
	
	xor 	ah, ah	
	int 	13h		; Reset Controller
  	
	pop	cx	
	clc		
	loop	ReadLoop	; Lesen war nix... 

	; Alle Versuche Fehlgeschlagen!
	stc			; Carry Setzen
	ret
  TabelleOK:
  	clc
	ret			; und zurck
GetPartTab	endp


CheckPartTab 	proc near
	; Wir suchen nun einen Eintrag, welche als Bootbar makiert wurde...
	mov	bx, 1beh		; Erster Eintrag in der Tabelle
	mov	cx, 4h			; maximal 4 Eintr„ge!
	mov	ax, 1000h
	mov	es, ax
CheckIt:
	cmp	byte ptr ds:[vos], 0ffh ; VOS/9 Suchen?
	je	GetVOS
  	cmp 	byte ptr es:[bx], 80h	; Bootbar?
	jne 	NextPart
	jmp	short EntryOK
GetVos:
	cmp	byte ptr es:[bx+4h], 0d0h
	jne	NextPart		; Nix VOS9!
EntryOK:
 	clc
	ret				; Eintrag ist Gltig!
NextPart:
  	add 	bx, 10h			; Auf n„chsten Eintrag
  	loop	CheckIt
	stc				; War NIX!
	ret
CheckPartTab 	endp


BootIt		proc near
	; Wir booten nun das Betriebssystem...
	mov	ax, 1000h
	mov	es, ax
	mov	dl, byte ptr ds:[bootdrv]
	mov 	dh, byte ptr es:[bx+1h]      ; Kopf Part start  
	mov 	cx, word ptr es:[bx+2h]	; Zylinder/Sektor Part start 

BootLoop:
	xor 	ax, ax
	mov 	es, ax
	mov 	bx, 7c00h			; An 7c00h den Boot-Code
	mov 	ax, 0201h			; 1 Sektor lesen
	int 	13h
	mov 	ax, 700h			; 7c00h starten
	mov 	es, ax
	mov 	bx, 0c000h			; Adr. 7c00h
	mov 	ax, 0201h			; 1 Sektor lesen
	int 	13h

	cmp 	ah, 0
	jz	StartBoot
	jmp 	NixDa         			; Fehler! Weiterversuchen...
StartBoot:
	mov	dl, byte ptr ds:[bootdrv]
	db	0eah,00h,7ch,00h,00h
NixDa:
	stc
	ret
BootIt 		endp

Print		proc near
	; Wir erwarten die Text-Offset in si!
msg_01:
	mov	al, byte ptr 060h:[si]
	cmp	al, '$'
	je	Fertig
	mov	ah, 0eh
	mov	bl, 07h
	int	10h			; Video Int
	inc	si
	jmp	short msg_01
Fertig:
	ret
Print		endp

bootdrv		db	0
bootmsg 	db	'Suche Betriebssystem...$'
bootnix 	db	'Nicht vorhanden!$'
bootfailed	db	'Fehler beim Lesen!$'	
		org	1bbh
vos		db	0
bootkey		dw	0200h
; Hier steht sp„ter die PART-Tabelle

CODE      ends
          end start
          