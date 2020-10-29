;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; File_Name	  : MAKEROOT.ASM
; (c)(r) 1995 by MZ Computer Systems
;
; Description     : Erstellen des Root-Filesystems fr VOS/9
;
; Operating System: DOS
; Language	  : Assembler
; Usage           : Internal only
;
; Link Objects    : zahlen.asm
; Exec-File       : EXE
; CPU             : 386+
; CPU Mode	  : Real/V86
; FPU             : -
; Memory Required : ?
;
; Creation Date   : 29.10.1995
; Autor           : Marcus Zoller
; Version         : 1.0
; Version Date    : 29.10.1995
; Release         : 1
; Release Date    : 04.11.1995
; Released by     : Marcus Zoller
;
; Release Notes:
; V1.0 R1 - 04.11.1995: Die ersten 2 Sektoren werden nicht in das Linear-
;			Adressing mit einbezogen und dienen fr den Bootstrap
;                       und fr die die Volume Data Area. Logical Addr. 0
;                       beschreibt also den 3. Sektor der Partition. Dies
;                       gilt fr alle Medien!
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
.386
LOCALS

	CR		= 0Ah
	LF		= 0Dh
	
	; INODE-Attribut Flags
	
	FLAG_File	= 0h
	FLAG_Dir	= 1h
	FLAG_Group	= 2h
	FLAG_Link	= 4h
	FLAG_D		= 8h			; Deleted
	FLAG_M		= 10h			; Moved
	FLAG_S		= 20h			; System
	FLAG_C		= 40h			; Compressed
	FLAG_A		= 80h			; Archived
	FLAG_H		= 1h			; Hidden
	FLAG_F		= 2h			; Fixed
	FLAG_E		= 4h			; Executable
	FLAG_Sh		= 8h			; Shareable
	FLAG_Di		= 10h			; Delete Inhibit
	FLAG_Ci		= 20h			; Compress Inhibit
	FLAG_Mi		= 40h			; Move Inhibit
	FLAG_Li		= 80h			; Link Inhibit
	FLAG_Ri		= 1h			; Rename Inhibit
	FLAG_Lo		= 2h			; Local Only Access
	FLAG_Eo		= 4h			; Executable Only
	FLAG_Ro		= 8h			; Read Only
	FLAG_Wo		= 10h			; Write Only
	FLAG_Ao		= 20h			; Add Only
	FLAG_Dd		= 40h			; Delete Data by Overwrite
	FLAG_Si		= 80h			; Subdirs Inhibit
	
	RootDirFlags	= FLAG_Dir+FLAG_S+FLAG_Di+FLAG_Ci+FLAG_Mi+FLAG_Ri+FLAG_F
	SystemDirFlags	= FLAG_Dir+FLAG_S+FLAG_Di+FLAG_Ci

	BootCodeFlags	= FLAG_File+FLAG_S+FLAG_F+FLAG_Eo+FLAG_Di+FLAG_Ci+FLAG_Mi+FLAG_Lo

	; VIS Flags
	
	TYPE_UNKNOWN	= 0h
	TYPE_ROOT	= 1h
	TYPE_ADD	= 2h
	TYPE_MOUNT	= 3h
	DEFECTIVE	= 8h
	REMOVEABLE	= 10h
	AUTO_CHECK	= 20h
	WRITE_PROTECT	= 40h
	MOUNTED_ADDED	= 80h

	RootVisFlags 	= Type_Root

	; Directory Flags
	
	EMPTY_INODE	= 0h
	OBJECT_NAME	= 1h
	EXTENDED_NAME	= 2h
	OBJECT_COMMENT	= 3h
	EXTENDED_COMMENT= 4h

				
;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

MAKEROOT SEGMENT PARA USE16 'CODE'
	ASSUME CS:MAKEROOT, DS:DATA, ES:SEKTOR_DATA, FS:BLOCK_DATA

INIT_IP:
	cli
	mov	ax, STACK_SEG
	mov	bx, offset TOS
	mov	ss, ax
	mov	sp, bx
	mov	ax, DATA
	mov	bx, SEKTOR_DATA
	mov	cx, BLOCK_DATA
	mov	ds, ax
	mov	es, bx
	mov	fs, cx
	sti
	
	lea	dx, MSG_0000			;SAY Hello...
	mov	ah, 9
	int	21h

	call	GET_USERDATA			; Daten vom User holen

	mov	dl, byte ptr ds:[HDD_DRIVE]
	call	GET_DRIVEDATA			; Daten vom Bios holen	

	call	GET_VOLUMEDATA			; Some linear algebrar...
		
	; Nun haben wir alle ben”tigten Daten ber das Laufwerk!
	
	call	SET_BITMAPBLOCKS		; Bitmaps schreiben

	call	CREATE_ROOT			; Das ROOT Directory

	call	MAKE_SYSDIR			; Das SYSTEM Directory
	
	call	COPY_BOOT			; VOSBOOT Image!

	call	COPY_SYSSELECT			; SYSTEM SELECT Image!	

	call	COPY_KERNEL			; KERNEL Image!

	call	CREATE_VIS			; Volume Info Sektor

	call	WRITE_BOOTSTRAP			; Bootsrap Code
					
	mov	ax, 4c00h			; GOING HOME...
	int	21h

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; PRINT32   : Ausgabe einer 32-Bit Zahl
	; INPUT	    :	DX = Hi 16-Bit
	;		AX = Lo 16-Bit
	; 
	extrn Print32Bit: near
	
 	PRINT32 PROC NEAR
 		push	bx
 		push	cx
 		push	dx ax
 		call	print32bit
 		pop	cx
 		pop	bx
 		ret
 	PRINT32 ENDP
 	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; READ32   : Lesen einer 32-Bit Zahl von STDIN
	; INPUT	   :	-
	; OUTPUT   : 	DX = Hi 16-Bit
	;		AX = Lo 16-Bit
	;
	extrn Read32Bit: near

	READ32 PROC NEAR
 		push	bx
 		push	cx
 		call	read32bit
 		pop	cx
 		pop	bx
 		ret
	READ32 ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; READ_SEK: Lesen eines Sektors 
	; INPUT   :	CX = Sektor/Zylinder
	;		DX = Kopf/Laufwerk
	;		BX = Adresse
	; OUTPUT  :     SEKTOR_DATA: BX
	; CHANGES :     -
	;	
	READ_SEK PROC NEAR
		push	ax
		push	di
		
		mov	di, 4		; max. 4 Leseversuche

	@@ReadLoop:
		mov	ax, 0201h
		int	13h

		jnc	@@ReadOK
		sub	di, 1
		jnz	@@ReadLoop

		push	ax		
		lea	dx, MSG_0001
		mov	ah, 9
		int	21h	
		pop	ax
		xor	dx, dx

		call	PRINT32
		
		pop	di
		pop	ax
		mov	ax, 4c00h
		int	21h
	@@ReadOK:
		pop	di
		pop	ax
		ret
	READ_SEK ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; WRITE_SEK: Schreiben eines Sektors 
	; INPUT   :	CX = Sektor/Zylinder
	;		DH = Kopf/Zylinder
	;               SEKTOR_DATA: READ_DATA
	; CHANGES :     -
	;	
	WRITE_SEK PROC NEAR
		push	bx
		push	ax
		push	di
		
		mov	di, 4		; max. 4 Schreibversuche
		mov	dl, byte ptr ds:[HDD_DRIVE]
		
	@@WriteLoop:
		lea	bx, READ_DATA
		mov	ax, 0301h
		int	13h

		jnc	@@WriteOK
		dec	di
		cmp	di, 0
		jnz	@@WriteLoop

		push	ax		
		lea	dx, MSG_0002
		mov	ah, 9
		int	21h	
		pop	ax
		xor	dx, dx

		call	PRINT32
		
		pop	di
		pop	ax
		pop	bx
		mov	ax, 4c00h
		int	21h
	@@WriteOK:
		pop	di
		pop	ax
		pop	bx
		ret
	WRITE_SEK ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CLR_SEK: L”schen des Sektor-Buffers
	; Input : -
	; Output: -
	;
	CLR_SEK PROC NEAR
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	cx, 512
		xor	al, al
		xor	di, di
	  @@Clr_Loop:
	  	stosb
	  	loop	@@Clr_Loop
	  	ret
	CLR_SEK ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GETSEKZYL: Umwandeln der BIOS-Angaben in die Bestandteile
	; CX	= SekZyl
	; DH	= HeadZyl
	; Rckgabe:
	; AL	= Sektor
	; BX 	= Zylind
	; DL	= Kopf
	;
	GetSekZyl	proc near
		xor	ax, ax
		mov	al, ch
		mov	ah, cl
		shr	ah, 6
		xor	bx, bx
		mov	bl, dh
		shr	bl, 6
		shl	bl, 8
		add	ah, bh
		xor	bx, bx
		mov	bx, ax			; => anz. Zylinder

		xor	ax, ax
		mov	ax, cx
		and	ax, 63			; => anz. Sektoren

		xchg	dh, dl
		xor	dh, dh
		and	dx, 63			; => anz. K”pfe

		ret
	GetSekZyl	endp	

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SETSEKZYL: Umwandeln der phys. Daten in BIOS-Angabe
	; AL = Sektor
	; BX = Zylinder
	; DL = Kopf
	; Rckgabe:
	; CX = Sekzyl
	; Dh = HeadZyl
	;	
	SetSekZyl	proc near
		xor	cx, cx	
		mov	ch, bl
		mov	cl, al			; Sektor dazu
		mov	al, bh
		shl	al, 6
		add	cl, al			; Rest Zyl dazu
		shr	bh, 2
		mov	al, bh
		shl	al, 6
		mov	dh, dl
	
		add	dh, al
		ret
	SetSekZyl	endp

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_USERDATA: Eingabe von Laufwerk und Blockgr”áe
	; OUTPUT	DATA:HDD_DRIVE
	;		DATA:BLOCKSIZE
	;		DATA:SEKS_PER_BLOCK
	;
	; nderung 03.10.95: Bei einem Diskettenlaufwerk arbeiten wir Sektor
	;                    orientiert. Die Blockgr”áe betr„gt hier 0. d.h.
	;		     jeder Sektor repr„sentiert einen Block
	;         
	GET_USERDATA proc near		
		lea	dx, MSG_0003
		mov	ah, 9
		int	21h		
	@@AskDrive:
		call	READ32	
		jc	@@AskDrive
		mov	byte ptr ds:[HDD_DRIVE], al
		lea	dx, MSG_0004
		mov	ah, 9
		int	21h
		mov	al, byte ptr [HDD_DRIVE]
		cmp	al, 128
		jb	@@BlockKnown
 	@@AskBlock:
		call	READ32
		jc	@@AskBlock
		cmp	al, 0
		je	@@NixBlock
		cmp	al, 32
		jg	@@NixBlock
		xor	ah, ah
		xor	dx, dx
		jmp	short @@SetBlockData
	@@BlockKnown:
		xor	dx, dx
		mov	ax, 0			; Blockgr”áe ist 0
		call	print32		
		mov	ax, 0				
	@@SetBlockData:
		mov	byte ptr ds:[HDD_BLOCKSIZE], al
		mov	bl, 2
		mul	bl
		cmp	al, 0
		jz	@@SetSeks1		; 1 Sektor bei Blockgr”áe 0
		mov	byte ptr ds:[SEKS_PER_BLOCK], al
		ret
	@@SetSeks1:
		mov	byte ptr ds:[SEKS_PER_BLOCK], 1
		ret
	@@NixBlock:
		lea	dx, MSG_0005
		mov	ah, 9
		int	21h
		mov	ax, 4c00h
		int	21h
	GET_USERDATA endp

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_DRIVEDATA: Ermittelt die phys. Daten eines Laufwerks
	; INPUT	:	DL = Laufwerk
	; OUTPUT:	DATA:HDD_ZYLINDER
	;		DATA:HDD_SEKTOREN
	;		DATA:HDD_KOEPFE
	;
	GET_DRIVEDATA PROC NEAR
		mov	ah, 8
		int	13h
		jc	@@NixDrv
		cmp	ch, 0
		je	@@NixDrv
		call	GetSekZyl		
		mov	word ptr ds:[HDD_ZYLINDER], bx
		mov	byte ptr ds:[HDD_SEKTOREN], al
		mov	byte ptr ds:[HDD_KOEPFE], dl

		lea	dx, MSG_0012
		mov	ah, 9
		int	21h
		mov	ax, word ptr ds:[HDD_ZYLINDER]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0008
		mov	ah, 9
		int	21h
		movzx	ax, byte ptr ds:[HDD_SEKTOREN]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0007
		mov	ah, 9
		int	21h
		movzx	ax, byte ptr ds:[HDD_KOEPFE]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0009
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
		movzx	eax, word ptr ds:[HDD_ZYLINDER]
		inc	eax
		movzx	ebx, byte ptr ds:[HDD_SEKTOREN]
		mul	ebx
		xor	edx, edx
		movzx	ebx, byte ptr ds:[HDD_KOEPFE]
		inc	ebx
		mul	ebx
		xor	edx, edx
		mov	ebx, 2048
		div	ebx
		xor	edx, edx
		call	print32
		lea	dx, MSG_0010
		mov	ah, 9
		int	21h
		ret
	@@NixDrv:
		lea	dx, MSG_0006
		mov	ah, 9
		int	21h
		mov	ax, 4c00h
		int	21h	
	GET_DRIVEDATA ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_VOLUMEDATA: Prft und l„dt die Partitionsdaten, Berechnet
	; die Anzahl der Bitmap Blocks, Anzahl der Blocks im Volume, ...
	;
	; 04.10.95 V1.0 R1: Auf den gefunden Part-Start werden 2 Sektoren
	;                   Addiert. Es gilt:
	;                   Sektor 1: Bootstrap Loader
	;                   Sektor 2: Volume Data Area
	;
	GET_VOLUMEDATA PROC NEAR
		xor	dx, dx
		mov	dl, byte ptr [HDD_DRIVE]
		cmp	dl, 128
		jb	@@IsFDD
		mov	cx, 1
		lea	bx, es:PART_TABEL
		call	READ_SEK
	
	@@SuchePart:
		add	bx, 1beh
		mov	cx, 3			; 4 Eintr„ge max.
	@@Check:
  		cmp	byte ptr es:[bx+4h], 0d0h
  		je	@@PartFound
		cmp	cx, 0
		je	@@PartErr
		dec	cx
		add	bx, 10h
		jmp	short @@Check
	@@PartErr:
		lea	dx, MSG_0013
		mov	ah, 9
		int	21h
		mov	ax, 4c00h
		int	21h
	@@PartFound:
		mov	cx, word ptr es:[bx+2h]	; Partitions Start Sek/Zyl
		mov	dh, byte ptr es:[bx+1h]	; " Zyl/Kopf
		mov	word ptr [VOLUME_START_SEKZYL], cx
		mov	byte ptr [VOLUME_START_HEADZYL], dh
		push	bx

		mov	ebx, 2
		call	add_sektor			; V1.0 R1

		call	getsekzyl
		mov	word ptr [VOLUME_START_ZYL], bx
		mov	byte ptr [VOLUME_START_SEK], al
		mov	byte ptr [VOLUME_START_HEAD], dl
	
		pop	bx
		mov	cx, word ptr es:[bx+6h]	; Partitions Ende Sek/Zyl
		mov	dh, byte ptr es:[bx+5h]	; " Zyl/Kopf
		call	getsekzyl
		
		mov	word ptr [VOLUME_END_ZYL], bx
		mov	byte ptr [VOLUME_END_SEK], al
		mov	byte ptr [VOLUME_END_HEAD], dl
		jmp	@@CalcSeks
	
	@@IsFDD:
		; Es Handlet sich um ein Disk-Laufwerk... Alles klar soweit!
		mov	cx, 1
		xor	dh, dh
		mov	word ptr [VOLUME_START_SEKZYL], cx
		mov	byte ptr [VOLUME_START_HEADZYL], dh

		xor	ax, ax				; Start Zylinder = 0
		mov	bl, 2				; Start Sektor = 2
		mov	bh, 0				; Start Kopf = 0

		mov	cx, word ptr [HDD_ZYLINDER]	; End Zylinder 
		mov	dl, byte ptr [HDD_SEKTOREN]	; End Sektor
		mov	dh, byte ptr [HDD_KOEPFE]	; End Kopf
	
		mov	word ptr [VOLUME_START_ZYL], ax
		mov	byte ptr [VOLUME_START_SEK], bl
		mov	byte ptr [VOLUME_START_HEAD], bh
		mov	word ptr [VOLUME_END_ZYL], cx
		mov	byte ptr [VOLUME_END_SEK], dl
		mov	byte ptr [VOLUME_END_HEAD], dh
	
	@@CalcSeks:
		movzx	eax, word ptr [VOLUME_START_ZYL]
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_SEKTOREN]
		mul	ebx
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		mul	ebx
	
		push	eax
	
		movzx	eax, byte ptr [VOLUME_START_SEK]
		dec	eax
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		mul	ebx
	
		pop	ebx
	
		add	eax, ebx
		movzx	ebx, byte ptr [VOLUME_START_HEAD]
		inc	ebx
		add	eax, ebx
		dec	eax
	
		mov	dword ptr [VOLUME_START_SEKS], eax
		
		movzx	eax, word ptr [VOLUME_END_ZYL]
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_SEKTOREN]
		mul	ebx
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		mul	ebx
	
		push	eax
	
		movzx	eax, byte ptr [VOLUME_END_SEK]
		dec	eax
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		mul	ebx
	
		pop	ebx

		add	eax, ebx
		movzx	ebx, byte ptr [VOLUME_END_HEAD]
		inc	ebx
		add	eax, ebx

		mov	dword ptr [VOLUME_END_SEKS], eax

		mov	ebx, dword ptr [VOLUME_START_SEKS]
		sub	eax, ebx
	
		mov	dword ptr [PART_SEKS], eax

		xor	edx, edx
		mov	ebx, 2048		; MB
		div	ebx
		mov	word ptr [PART_SIZE], ax
	
		mov	eax, dword ptr [PART_SEKS]
		movzx	ebx, byte ptr [SEKS_PER_BLOCK]
		xor	edx, edx
		div	ebx
		
		mov	dword ptr [VOLUME_BLOCKS], eax
		mov	byte ptr [VOLUME_LOST_SEKS], dl

		xor	edx, edx
		movzx	ebx, byte ptr [SEKS_PER_BLOCK]
		mul	ebx
		mov	dword ptr [VOLUME_SEKS], eax
		xor	edx, edx
		mov	ebx, 2				; KB
		div	ebx
		mov	dword ptr [VOLUME_SIZE], eax
		
		; 1 BitMap Node = 1 Block
		; 1 Sektor = 512 Bytes = Platz fr 4096 Zonen

		movzx	eax, byte ptr [SEKS_PER_BLOCK]
		xor	edx, edx
		mov	ebx, 4096
		mul	ebx
	
		; EAX= Anzahl Zonen Eintr„ge pro Block
		mov	dword ptr [BITMAP_ENTRYS], eax

		xor	edx, edx
		mov	ebx, eax
		mov	eax, dword ptr [VOLUME_BLOCKS]
		div	ebx
		cmp	edx, 0
		je	@@SetReq
		inc	eax
	@@SetReq:
		mov	word ptr [BITMAP_NODES], ax
		lea	dx, MSG_0014
		mov	ah, 9
		int	21h
	
		lea	dx, MSG_0015
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		mov	ax, word ptr [VOLUME_START_ZYL]
		call	print32
	
		lea	dx, MSG_0016
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		movzx	ax, byte ptr [VOLUME_START_SEK]
		call	print32
	
		lea	dx, MSG_0017
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		movzx	ax, byte ptr [VOLUME_START_HEAD]
		call	print32
	
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
	
		mov	ax, word ptr [VOLUME_START_SEKS]
		mov	dx, word ptr [VOLUME_START_SEKS+2]
		call	print32
	
		lea	dx, MSG_0018
		mov	ah, 9
		int	21h
				
		lea	dx, MSG_0019
		mov	ah, 9
		int	21h
	
		lea	dx, MSG_0015
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		mov	ax, word ptr [VOLUME_END_ZYL]
		call	print32
	
		lea	dx, MSG_0016
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		movzx	ax, byte ptr [VOLUME_END_SEK]
		call	print32
	
		lea	dx, MSG_0017
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		movzx	ax, byte ptr [VOLUME_END_HEAD]
		call	print32

		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
	
		mov	ax, word ptr [VOLUME_END_SEKS]
		mov	dx, word ptr [VOLUME_END_SEKS+2]
		call	print32
	
		lea	dx, MSG_0018
		mov	ah, 9
		int	21h
	
		lea	dx, MSG_0020
		mov	ah, 9
		int	21h

		mov	ax, word ptr [PART_SEKS]
		mov	dx, word ptr [PART_SEKS+2]
		call	print32
	
		lea	dx, MSG_0018
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
	
		mov	ax, word ptr [PART_SIZE]
		xor	dx, dx
		call	print32
	
		lea	dx, MSG_0010
		mov	ah, 9
		int	21h

		lea	dx, MSG_0021
		mov	ah, 9
		int	21h
	
		mov	ax, word ptr [VOLUME_SEKS]
		mov	dx, word ptr [VOLUME_SEKS+2]
		call	print32
	
		lea	dx, MSG_0018
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
		
		xor	ax, ax
		xor	dx, dx
		mov	al, byte ptr [VOLUME_LOST_SEKS]
		call	print32
	
		lea	dx, MSG_0022
		mov	ah, 9
		int	21h
		
		lea	dx, MSG_0023
		mov	ah, 9
		int	21h
	
		mov	ax, word ptr [VOLUME_BLOCKS]
		mov	dx, word ptr [VOLUME_BLOCKS+2]
		call	print32
	
		lea	dx, MSG_0024
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h

		mov	ax, word ptr [VOLUME_SIZE]
		mov	dx, word ptr [VOLUME_SIZE+2]
		call	print32
	
		lea	dx, MSG_0025
		mov	ah, 9
		int	21h
	
		lea	dx, MSG_0026
		mov	ah, 9
		int	21h

		mov	ax, word ptr [bitmap_entrys]
		mov	dx, word ptr [bitmap_entrys+2]
		call	print32
	
		lea	dx, MSG_0027
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
	
		xor	dx, dx
		mov	ax, word ptr [bitmap_nodes]
		call	print32
	
		lea	dx, MSG_0028
		mov	ah, 9
		int	21h

		ret
	GET_VOLUMEDATA ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	;SET_BITMAPBLOCKS: Erstellt die BitmapBlocks auf einem Volume
	; Input : -
	; Output: -
	;
	SET_BITMAPBLOCKS PROC NEAR
		; Wir werden nun berechnen wieviele Blocks wir in einen
		; Bitmap Block sichern k”nnen und somit werden wir die
		; ben”tigten BitmapBlocks ermitteln. Der BitmapBlock 
		; ansich ist in sich selbst als erster belegter Block
		; eingetragen.
	
		lea	dx, MSG_0029
		mov	ah, 9
		int	21h

		movzx	edi, word ptr [BITMAP_NODES]

	@@CreateLoop:
		dec	edi
	
		cmp	edi, 0			; V1.0 R1: 1.Bitmap an Addr. 0
		je	@@FirstNode

		mov	eax, dword ptr [BITMAP_ENTRYS]
		xor	edx, edx
		mov	ebx, edi
		mul	ebx

		push	edi
		push	eax
		call	CLR_DATA
		pop	eax
		call	WRITE_DATA
		pop	edi
		jmp	short @@CreateLoop
				
	@@FirstNode:
		call	CLR_DATA
		mov	eax, 0			; V1.0 R1
		call	WRITE_DATA
		ret	
	SET_BITMAPBLOCKS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CLR_DATA: L”scht den Bitmap Datenbereich
	; Input : -
	; Output: -
	;
	CLR_DATA PROC NEAR
		push	eax
		push	ecx
		push	edi
		mov	ax, BLOCK_DATA
		mov	es, ax
		mov	cx, 16384		; 16384 DWords zu l”schen
		xor	eax, eax
		xor	edi, edi
		cld
		rep	stosd
		mov	ax, SEKTOR_DATA
		mov	es, ax
		pop	edi
		pop	ecx
		pop	eax
		ret
	CLR_DATA ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_PHYSICAL: Berechnet aus einer Linearen Adresse die phys.
	;		Position auf dem Datentr„ger, abh„ngig von der 
	;		Blockgr”áe
	; 
	; Input:	EBX = Lieneare Adrsesse
	; Output:	CX = SekZyl, DH=ZylHead
	;
	GET_PHYSICAL PROC NEAR
		; Zun„chst berechnen wir aus der Linearen Adresse die Anzahl 
		; der Sektoren...
	
		mov	eax, ebx
		movzx	ebx, byte ptr [SEKS_PER_BLOCK]
		xor	edx, edx
		mul	ebx
	
		mov	ebx, dword ptr [VOLUME_START_SEKS]
		add	eax, ebx
	
		; Nun mssen wir berechnen, welcher Zylinder, Sektor, Kopf
		; EAX= Logische Real Adresse
	
		push	eax			; Adresse merken
	
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		xor	edx, edx
		div	ebx
		movzx	ebx, byte ptr [HDD_SEKTOREN]
		xor	edx, edx
		div	ebx
	
		push	eax			; Zylinder !
		
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_SEKTOREN]
		mul	ebx
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		mul	ebx
	
		pop	ebx			; Zyl holen
		pop	edx			; Adresse holen
		push	ebx			; Zyl zurck
		push	edx			; Adresse zurck
	
		sub	edx, eax
	
		push	edx			; REST merken !
	
		mov	eax, edx
		xor	edx, edx
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		div	ebx
		inc	eax
	
		push	eax			; SEKTOR merken !

		xor	edx, edx
		dec	eax
		movzx	ebx, byte ptr [HDD_KOEPFE]
		inc	ebx
		mul	ebx

		pop	edx			; SEKTOR holen

		pop	ebx			; REST holen
		sub	ebx, eax
	
		xor	eax, eax
		mov	al, dl
		xor	edx, edx
		mov	dl, bl
		
		pop	ebx			; Adresse zum Mll
		xor	ebx, ebx
		pop	ebx			; Zylinder holen
	
		call	setsekzyl	
		ret	
	GET_PHYSICAL ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; WRITE_DATA: Schreibt einen Block an die Adresse in EAX
	;	      und markiert diesen als Belegt im zugeh”rigen Bitmap
	;	      Block
	; Input:      EAX = Positionsangabe
	; Output:     - (abbruch bei Fehler!)
	;
	WRITE_DATA PROC NEAR
		push	eax
		call	WRITE_BLOCK
		pop	eax	
		; Wir mssen den Block nun noch als "BELEGT" Eintragen!
		call	MARK_BLOCK
		ret
	WRITE_DATA ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; ADD_SEKTOR: Addiert X Sektoren zur bergebenen Position und gibt
	;             die neue Position zurck
	; Input:      CX = Aktueller SekZyl
	;             DH = Aktueller ZylHead
	;             EBX = Anzahl zu addierende Sektoren
	; Output:     CX, DH Aktualisiert
	;
	ADD_SEKTOR PROC NEAR
		push	ebx
		call	getsekzyl
		pop	ecx
	
	@@IncLoop:
		cmp	dl, byte ptr [HDD_KOEPFE]
		je	@@NextSek
		inc	dl
		jmp	short @@IsOK
	
	@@NextSek:
		mov	dl, 0
		cmp	al, byte ptr [HDD_SEKTOREN]
		je	@@NextZyl
		inc	al
		jmp	short @@IsOK
	
	@@NextZyl:
		mov	al, 1
		inc	bx
	
	@@IsOK:
		loop	@@IncLoop
		call	setsekzyl
		ret	
	ADD_SEKTOR ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; READ_BLOCK : Liest einen Block vom Volume nach BLOCK_DATA
	; Input:        EAX = zu lesende Adresse
	; Output:	- (abbruch bei Fehler!)
	;
	READ_BLOCK PROC NEAR
		mov	ebx, eax
		call	get_physical

		movzx	si, byte ptr [SEKS_PER_BLOCK]	; Anzahl der Sektoren
							; eines Blocks
		xor	ebx, ebx			; Offset 0
		mov	ax, BLOCK_DATA
		mov	es, ax
			
	@@NewSek:
		mov	di, 4				; max. 4 Versuche

	@@ReadLoop:
		mov	dl, byte ptr [HDD_DRIVE]

		mov	ax, 0201h
		int	13h
	
		jnc	@@checknext

		dec	di
		cmp	di, 0
		je	@@failure
		jmp	short @@ReadLoop
				
	@@checknext:
		dec	si
		cmp	si, 0
		je	@@Fertisch
		add	bx, 200h	
		push	ebx
		mov	ebx, 1
		call	ADD_SEKTOR
		pop	ebx
		
		jmp	short @@NewSek
	@@Fertisch:
		ret	
	@@failure:
		lea	dx, MSG_0001
		mov	ah, 9
		int	21h
		mov	ax, 4c00h
		int	21h
	READ_BLOCK ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; WRITE_BLOCK : Schreibt BLOCK_DATA an die in EAX bergebene Position
	;               auf dem Datentr„ger
	; Input:        EAX = Adresse
	; Output:	- (abbruch bei Fehler!)
	;
	WRITE_BLOCK PROC NEAR
		mov	ebx, eax
		call	GET_PHYSICAL

		movzx	si, byte ptr [SEKS_PER_BLOCK]	; Anzahl der Sektoren
							; eines Blocks
		xor	ebx, ebx			; Offset 0
		mov	ax, BLOCK_DATA
		mov	es, ax
			
	@@NewSek:
		mov	di, 4				; max. 4 Versuche

		push	di
		push	si
		push	bx
		push	cx
		push	dx
		
		call	getsekzyl
	
		push	dx
		push	ax
		push	bx
		lea	dx, MSG_0030
		mov	ah, 9
		int	21h
	
		pop	ax
		xor	dx, dx
		call	print32
	
		lea	dx, MSG_0016
		mov	ah, 9
		int	21h
	
		pop	ax
		xor	ah, ah
		xor	dx, dx
		call	print32
	
		lea	dx, MSG_0017
		mov	ah, 9
		int	21h
	
		pop	ax
		xor	ah, ah
		xor	dx, dx
		call	print32
	
		pop	dx
		pop	cx
		pop	bx	
		pop	si
		pop	di

	@@WriteLoop:	
		mov	dl, byte ptr [HDD_DRIVE]

		mov	ax, 0301h
		int	13h
	
		jnc	@@checknext

		dec	di
		cmp	di, 0
		je	@@failure
		jmp	short @@WriteLoop
				
	@@checknext:
		dec	si
		cmp	si, 0
		je	@@Fertisch
		add	bx, 200h	

		push	ebx
		mov	ebx, 1
		call	ADD_SEKTOR
		pop	ebx
		
		jmp	@@NewSek
	
	@@Fertisch:
		mov	ax, SEKTOR_DATA
		mov	es, ax
		ret	
	@@failure:
		push	ax
		lea	dx, MSG_0002
		mov	ah, 9
		int	21h
		pop	ax
		mov	al, ah
		xor	ah, ah
		xor	dx, dx
		call	print32
	           
		mov	ax, 4c00h
		int	21h	
	WRITE_BLOCK ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CALC_BITMAPPOS: Berechnet die Position des BitmapBlocks 
	;		  fr einen zu belegenden Block
	; Input :         EAX = Lineare Adresse des einzutragenden Blocks
	; Output:         EAX = Nummer des Bitmap Blocks (1..
	;                 EBX = Lineare Adresse des Bitmap Blocks
	;                 ECX = Byte im BitmapBlock (0..)
	;         	  EDX = Bit im Bitmap Block (8..1)
	;
	CALC_BITMAPPOS PROC NEAR
		; Bit 0 bedeutet die Adresse Beschreibt ein Bitmap-Block!
		; Wir wissen wieviele "Blocks" in einen Bitmap-Block passen.
		; Wir teilen die Adresse also durch die Anzahl, 
		; das ganze +1 und haben die Nr. des Blocks.
		; Ist die Blocknummer = 1 befindet sich der Block am 2. Block
		; der Partition d.h. Adresse 1
		; Ansonsten befindet er sich an Adresse BlockNr.* Anzahl 
		; der Blocks je Bitmap
	
		; Nur der Bitmap...
		xor	edx, edx
		mov	ebx, dword ptr [BITMAP_ENTRYS]
		div	ebx
		inc	eax
	
		; EAX = Nr. des Bitmap Blocks
	
		push	eax			; Bitmap-Nummer merken
		
		; EDX = Das Bit im Block
	
		push	edx			

		xor	edx, edx
		dec	eax
		mov	ebx, dword ptr [BITMAP_ENTRYS]
		mul	ebx
	
		pop	edx
		push	eax			; Adresse des Blocks merken
		
		mov	eax, edx
		xor	edx, edx
		mov	ebx, 8			; 8 Bits
		div	ebx
		mov	ebx, 8
		sub	ebx, edx	
		mov	edx, ebx
		mov	ecx, eax		; Byte im Block
						; EDX = Bit im Block
		pop	ebx			; Adresse des Blocks
		pop	eax			; Nummer der Bitmap
	
		cmp	eax, 1			; Nummer 1?
		je	@@EditAddr
		ret
				
	@@EditAddr:
		; Der erste Bitmap Block liegt nicht an Adresse 0
		; sondern an Adresse 1
		; V1.0 R1: 1. BitmapBlock liegt nun an Adresse 0!!!!
		
		mov	ebx, 0			; 1. Block in Partition!
	
		ret
	CALC_BITMAPPOS ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; MARK_BLOCK: Markiert einen Block als belegt in dem entsprechenden
	;             Bitmap Block.
	;
	; Input	    : EAX = Lineare Adresse des zu mark. Blocks
	; Output    : - (abbruch bei Fehler!)
	;
	MARK_BLOCK PROC NEAR
		call	CALC_BITMAPPOS
		; => EAX = Nummer des Blocks (1..)
		; => EBX = Linear Adresse des Bitmap-Nodes
		; => ECX = Byte im Node (0..)
		; => EDX = Bit im Node (8..1)
		push	ebx			; Adresse merken
		push	edx			; Bit merken
		push	ecx			; Byte merken

		mov	eax, ebx
		call	READ_BLOCK

		mov	ax, block_data
		mov	es, ax

		pop	ebx			; Byte holen
		mov	al, byte ptr es:[bx]

		pop	ecx			; Bit holen
		dec	ecx
		mov	ah, 1
		shl	ah, cl
		test    al, ah
		jnz	@@NixAdd
		add	al, ah
		mov	byte ptr es:[bx], al
	   @@NixAdd:
		pop	eax			; Adresse holen
	
		call	WRITE_BLOCK
		call	CLR_DATA
		ret
	MARK_BLOCK ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; WRITE_BOOTSTRAP: Schreibt den Bootstrap Code!
	; Input : -
	; Output: - (abbruch bei Fehler!)
	;
	WRITE_BOOTSTRAP PROC NEAR
		; Wir kopieren nun den Gesamten BootCode (512 Byte) in
		; den Block-Buffer und schreiben diesen an Adresse 0!
		; V1.0 R1: Adresse 0 zeigt nun auf den 1. Bitmap Block!!!
		;          Die Position des Bootcodes ist nun nicht mehr ber
		;          das Linear Adressing erreichbar und muá anhand der
		;          Partitionsdaten (VOLUME_START_x) beschrieben werden.
	
		lea	dx, MSG_0031
		mov	ah, 9
		int	21h

		assume	es:BOOT_CODE
		
		mov	ax, BOOT_CODE
		mov	es, ax
		
		ASSUME  ds:data, es:sektor_data, fs:block_data
		mov	ax, DATA
		mov	ds, ax
				
		call	CLR_SEK
		
		mov	cx, 128		; 128 DWords zu kopieren
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	ax, BOOT_CODE
		mov	fs, ax
		xor	edi, edi	; An Adresse 0
		cld
	@@CpyLoop:
		mov	eax, dword ptr fs:[edi]
		stosd
		loop	@@CpyLoop

		mov	cx, word ptr [VOLUME_START_SEKZYL]
		mov	dh, byte ptr [VOLUME_START_HEADZYL]

		call	WRITE_SEK
		ret
	WRITE_BOOTSTRAP ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CLR_INDOE: L”scht den INODE-Buffer
	; Input : -
	; Output: -
	;
	CLR_INODE PROC NEAR
		mov	cx, 128			; 128 Bytes zu l”schen
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	di, offset es:INODE_START
		xor	al, al
		rep	stosb
		ret
	CLR_INODE ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CREATE_BLOCK: Erstellt einen Block mit leeren Inodes
	; Input : EAX = Adresse
	; Output: - (abbruch bei Fehler!)
	;
	CLEAR_BLOCK PROC NEAR
		push	eax
		call	CLR_DATA
		pop	eax
		call	WRITE_DATA
		ret	
	CLEAR_BLOCK ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_SYSTIME: Liefert das Datum und die Uhrzeit (aktuell) zurck
	; Input : -
	; Output: EAX = Datum/Uhrzeit (Timemark)
	;
	GET_SYSTIME PROC NEAR
		mov	ah, 2ch
		int	21h
		; CH= Stunde, CL= Minute, DH= Sekunde
		push	cx
		movzx	eax, dh
		xor	edx, edx
		mov	ebx, 2
		div	ebx
		shl	eax, 27
		pop	cx
		movzx	ebx, cl
		shl	ebx, 21
		add	eax, ebx
		movzx	ebx, ch
		shl	ebx, 16
		add	eax, ebx
		push	eax
		mov	ah, 2ah
		int	21h
		; DL= Tag, DH= Monat, CX= Jahr (19xx)
		pop	eax
		movzx	ebx, cx
		sub	ebx, 1980
		shl	ebx, 9
		add	eax, ebx
		movzx	ebx, dh
		shl	ebx, 5
		add	eax, ebx
		movzx	ebx, dl
		add	eax, ebx			
		ret
	GET_SYSTIME ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SET_INODEPOS: Kopiert den Inode-Datenbereich an die angeg. Stelle
	;               im Block_Data Buffer.
	; Input : AX = Nr. des Inodes
	; Output: -
	;
	SET_INODEPOS PROC NEAR
		mov	bx, ax
		mov	ax, 128
		mul	bx
		xor	dx, dx
		; AX = Start-Byte im Block
		mov	di, ax
		mov	ax, BLOCK_DATA
		mov	fs, ax
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	si, offset es:INODE_START
		mov	cx, 128
	 @@Cpy_Loop:
	 	mov	al, byte ptr es:[si]
	 	mov	byte ptr fs:[di], al
	 	inc	si
	 	inc	di
	 	loop	@@Cpy_Loop
		ret	
	SET_INODEPOS ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CLR_DIR: L”scht den Directory Buffer
	; Input : -
	; Output: -
	;
	CLR_DIR PROC NEAR
		push	ecx
		push	eax
		push	edi
		mov	cx, 32			; Bytes zu l”schen
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	di, offset es:DIR_START
		xor	al, al
		rep	stosb
		pop	edi
		pop	eax
		pop	ecx
		ret
	CLR_DIR ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CREATE_ROOT: Erstellt das Root-Directory 
	; Input : -
	; Output: - (abbruch bei Fehler!)
	;
	CREATE_ROOT PROC NEAR
		; Bisher sind folgende Bestandteile des Volumes vorhanden
		; Adresse	0	Erster Bitmap Block

		lea	dx, MSG_0032
		mov	ah, 9
		int	21h

		; zun„chst L”schen wir den Bereich fr die INODEs		
		mov	eax, 1
		call	CLEAR_BLOCK
		; und den Bereich fr das Root-Dir...
		mov	eax, 2
		call	CLEAR_BLOCK
		
		; Als n„chstes kommt der INODE fr das Root-Dir
		call	CLR_INODE
		
		mov	ax, RootDirFlags		; Dir Flags
		mov	es:[FLAGS_TYPE], ax
		mov	eax, 1
		mov	es:[TOTAL_BLOCKS], eax
		call	GET_SYSTIME
		mov 	es:[CREATION_TIME], eax
		mov	es:[ACCESS_TIME], eax
		mov	es:[MODIFY_TIME], eax
		mov	es:[ARCHIVE_TIME], eax
		mov	eax, 2
		mov	es:[STARTPOS_1], eax
		mov	ax, 1
		mov	es:[BLOCKS_1], ax
		
		mov	ax, 0
		call	SET_INODEPOS
		
		mov	eax, 1
		call	WRITE_DATA
		
		; Der ROOT-Inode ist nun geschrieben - Nun folgt das Dir...
		
		ret
	CREATE_ROOT ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CREATE_VIS: Erstellet den Volume Information Sektor
	; Input : -
	; Output: - (abbruch bei Fehler!)
	;
	CREATE_VIS PROC NEAR
		lea	dx, MSG_0033
		mov	ah, 9
		int	21h
		
		call	CLR_SEK
		
		; Zun„cht den VIS mit den Daten Fllen...
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	byte ptr es:[VOL_LABEL   ], 'V'
		mov	byte ptr es:[VOL_LABEL+ 1], 'O'
		mov	byte ptr es:[VOL_LABEL+ 2], 'S'
		mov	byte ptr es:[VOL_LABEL+ 3], '/'
		mov	byte ptr es:[VOL_LABEL+ 4], '9'
		mov	byte ptr es:[VOL_LABEL+ 5], ' '
		mov	byte ptr es:[VOL_LABEL+ 6], 'R'
		mov	byte ptr es:[VOL_LABEL+ 7], 'O'
		mov	byte ptr es:[VOL_LABEL+ 8], 'O'
		mov	byte ptr es:[VOL_LABEL+ 9], 'T'
		mov	byte ptr es:[VOL_LABEL+10], ' '
		mov	byte ptr es:[VOL_LABEL+11], 'V'
		mov	byte ptr es:[VOL_LABEL+12], 'O'
		mov	byte ptr es:[VOL_LABEL+13], 'L'
		mov	byte ptr es:[VOL_LABEL+14], 'U'
		mov	byte ptr es:[VOL_LABEL+15], 'M'
		mov	byte ptr es:[VOL_LABEL+16], 'E'
		mov	byte ptr es:[VOL_LABEL+17], '$'

		mov	al, byte ptr ds:[HDD_BLOCKSIZE]
		mov	byte ptr es:[VOL_BLOCKSIZE], al

		call	GET_SYSTIME
		
		mov	dword ptr es:[VOL_CREATE_TIME], eax
		mov	dword ptr es:[VOL_MOUNT_TIME], eax
		mov	dword ptr es:[VOL_DISMOUNT_TIME], eax
		mov	dword ptr es:[VOL_CHECK_TIME], eax

		mov	bl, RootVisFlags
		cmp	byte ptr [HDD_DRIVE], 128
		jnb	@@FlagsOK
		add	bl, REMOVEABLE
	  @@FlagsOK:
		mov	byte ptr es:[VOL_FLAGS_1], bl
	
		; Der ganze Klimbatsch muá nun nach READ_DATA!
		mov	cx, 512		; 512 Byte zu kopieren
		mov	si, offset es:vol_blocksize
		xor	di, di
	    @@Cpy_Loop:
		mov	al, byte ptr es:[si]
		mov	byte ptr es:[di], al
		inc	si
		inc	di				
		loop	@@Cpy_Loop
		
		mov	cx, word ptr ds:[VOLUME_START_SEKZYL]
		mov	dh, byte ptr ds:[VOLUME_START_HEADZYL]
		mov	ebx, 1
		call	ADD_SEKTOR
		call	WRITE_SEK
		ret		
	CREATE_VIS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SET_DIRPOS: Kopiert den Dir-Datenbereich an die angeg. Stelle
	;               im Block_Data Buffer.
	; Input : AX = Nr. des Dir-Eintrags (0=1. Eintrag)
	; Output: -
	;
	SET_DIRPOS PROC NEAR
		mov	bx, ax
		mov	ax, 32
		mul	bx
		xor	dx, dx
		; AX = Start-Byte im Block
		mov	di, ax
		mov	ax, BLOCK_DATA
		mov	fs, ax
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	si, offset es:DIR_START
		mov	cx, 32
	 @@Cpy_Loop:
	 	mov	al, byte ptr es:[si]
	 	mov	byte ptr fs:[di], al
	 	inc	si
	 	inc	di
	 	loop	@@Cpy_Loop
		ret	
	SET_DIRPOS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; COPY_BOOT: Kopiert den VOS/9 Kernel-Loader (BIN-Image)
	; Input : -
	; Output: - (abbruch bei Fehler)
	;
	COPY_BOOT PROC NEAR
		; Bisher ist folgendes Vorhanden/Vorbereitet:
		; Addr. Objekt
		; -     BOOTSTRAP LOADER
		; -     VIS
		; 0     BITMAP BLOCK 1
		; 1     INODE (fr ROOT-DIR)
		; 2     ROOT-DIR
		; 3     INODE (fr SYSTEM-DIR)
		; 4     SYSTEM-DIR
		; Ab Adresse 5 beginnt nun der Datenbereich des BOOTSTRAP
		; Loaders!
		
		; Zun„chst kopieren wir den Datenbereich...
		; Wir holen eine DOS-Handle fr das File
		
		lea	dx, VOSBOOT_FILE	; Dateiname BootCode
		xor	al, al			; Zugriffsmodus: Nur Lesen
		mov	ah, 3Dh			; DOS: Datei ™ffnen
		int	21h
		jnc	@@DOSHandleOK
		lea	dx, MSG_0038
		mov	ah, 9
		int	21h
		mov	ax, 4c00h
		int	21h
	@@DosHandleOK:
		; Wir haben nun in AX das Handle fr die Datei

		mov	word ptr ds:[FILE_HANDLE], ax
		; Nun brauchen wir die File-Gr”áe!
		mov	bx, ax
		mov	al, 2		; Seekmodus 2
		xor	cx, cx		; SeekOffset 0 = Dateiende
		xor	dx, dx
		mov	ah, 42h		; DOS: Seek
		int	21h
		; AX=LO-WORD, DX=Hi-Word
		mov	word ptr ds:[BOOTCODE_BYTES], ax
		; Zun„chst Seek an Anfang der Datei
		mov	bx, word ptr ds:[FILE_HANDLE]
		xor	cx, cx		; Hi-Position 0
		xor	dx, dx		; Lo-Position 0
		xor	al, al		; Position absolut
		mov	ah, 42h
		int	21h

		; Als erstes mal sehen wieviele Bl”cke fr den Code
		; ben”tigt werden...
		xor	dx, dx			
		movzx	ax, byte ptr [SEKS_PER_BLOCK]
		mov	bx, 512
		mul	bx
		mov	word ptr ds:[BYTE_PER_BLOCK], ax
		xor	dx, dx
		mov	bx, ax
		xor	eax, eax
		xor	edx, edx
		mov	ax, word ptr ds:[BOOTCODE_BYTES]
		div	bx
		; AX enth„lt nun die ben”tigten Bl”cke
		; ist DX>0 muá noch ein Block Addiert werden...

		mov	dword ptr ds:[BOOTCODE_BLOCKS], eax
		mov	word ptr ds:[BOOTCODE_SIZE], dx
		cmp	dx, 0
		jz	@@SIZE_OK
		inc	eax
	@@SIZE_OK:	
		mov	dword ptr ds:[BOOTCODE_TOTAL], eax
		
		lea	dx, MSG_0036
		mov	ah, 9
		int	21h
		mov	ax, word ptr ds:[BOOTCODE_BYTES]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0037
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
		mov	eax, dword ptr ds:[BOOTCODE_TOTAL]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0024
		mov	ah, 9
		int	21h
		lea	dx, MSG_0035
		mov	ah, 9
		int	21h

		; Insgesamt sind si Bytes zu schreiben
		mov	si, word ptr ds:[BOOTCODE_BYTES]
		; Wir starten an Block eax-1
		mov	eax, 4
		push	eax			; Startpos merken
		push	si		
	@@Cpy_Loop:						
		call	CLR_DATA		; Datenbr. l”schen

		; Wir Lesen Blockgr”áe
		pop	si
		push	si
		; Restliche Byte <= Blockgr”áe?
		cmp	si, word ptr ds:[BYTE_PER_BLOCK]
		jbe	@@RestLesen		; Letzter Block

		; Wir Lesen einen Block aus dem File
		mov	cx, word ptr ds:[BYTE_PER_BLOCK]
		pop	si
		sub	si, cx			; vom Rest abziehen
		push	si
		
		mov	ah, 3fh			; DOS: Read from File
		mov	bx, word ptr ds:[FILE_HANDLE]

		ASSUME	ds:BLOCK_DATA

		mov	dx, BLOCK_DATA		; Seg.-Addr.
		mov	ds, dx
		xor	dx, dx			; Offset 0
		int	21h
		jc	@@ReadErr

		ASSUME	ds:DATA
		mov	dx, DATA
		mov	ds, dx
		
		; Block ist voll. Wir schreiben...
		pop	si
		pop	eax
		inc	eax
		push	eax
		push	si
		call	WRITE_DATA
		jmp	short @@Cpy_Loop

	@@ReadErr:
		ASSUME	ds:DATA
		mov	dx, DATA
		mov	ds, dx

		pop	si
		pop	eax
		lea	dx, ds:MSG_0039
		mov	ah, 9
		int	21h
		mov	ax, 4c00h		; DOS: Terminate Process
		int	21h
				
	@@RestLesen:
		; Wir Lesen einen Block aus dem File
		pop	si
		mov	cx, si			; Rest aus dem File
		sub	si, si			; vom Rest abziehen=0
		push	si
		
		mov	ah, 3fh			; DOS: Read from File
		mov	bx, word ptr ds:[FILE_HANDLE]

		ASSUME	ds:BLOCK_DATA

		mov	dx, BLOCK_DATA		; Seg.-Addr.
		mov	ds, dx
		xor	dx, dx			; Offset 0
		int	21h
		jc	@@ReadErr

		ASSUME	ds:DATA
		mov	dx, DATA
		mov	ds, dx
		
		; Block ist voll. Wir schreiben...
		pop	si
		pop	eax
		inc	eax
		call	WRITE_DATA

		; Nun wird die StartPosition und die Gr”áe im
		; Code des Bootstrap-Loaders eingetragen...
		
		assume	gs:boot_code
		mov	ax, boot_code
		mov	gs, ax
		mov	ebx, 5
		call	GET_PHYSICAL

		mov	word ptr gs:[BOOT_SEKZYL], cx
		mov	byte ptr gs:[BOOT_HEADZYL], dh
		
		; Nun brauchen wir noch die Gr”áe in Sektoren!
		mov	eax, dword ptr ds:[BOOTCODE_TOTAL]
		movzx	bx, byte ptr ds:[SEKS_PER_BLOCK]
		xor	edx, edx
		mul	bx
		mov	word ptr gs:[BOOT_SEKSIZE], ax
		
		; Die Datei muá nun im SYSTEM-Directory eingetragen werden...
		call	CLR_DATA
		; Das Dir befindet sich an Addr. 4
		; Dessenn Inode Block an Addr. 3
		
		; Zun„chst holen wir den INODE...
		mov	eax, 3
		call	READ_BLOCK
		; Dort drfte eigentlich nix vorhanden sein. Wir tragen
		; dort die Daten ber die Datei ein...

		call	CLR_INODE
		
		mov	ax, BootCodeFlags
		mov	word ptr es:[FLAGS_TYPE], ax
		mov	eax, dword ptr ds:[BOOTCODE_BLOCKS]
		mov	bx, word ptr ds:[BOOTCODE_SIZE]
		mov	dword ptr es:[OBJECT_BLOCKS], eax
		mov	word ptr es:[OBJECT_SIZE], bx

		call	GET_SYSTIME
		mov	dword ptr es:[CREATION_TIME], eax
		mov	dword ptr es:[MODIFY_TIME], eax
		mov	dword ptr es:[ACCESS_TIME], eax
		mov	dword ptr es:[ARCHIVE_TIME], eax

		; EIGENTMER ist das SYSTEM-Dir (Eintrag 0)
		; INODE 1 (0=RootDir) in Block 1 
		mov	eax, 1		; Block des Sys-Dir INODE
		mov	bx, 1
		mov	dword ptr es:[OWNER_BLOCK], eax
		mov	word ptr es:[OWNER_SELECT], bx

		; Der erste Block ist Block 5 und da hier noch
		; nix defrag ist sind eventuelle weitere direkt dahinter
		; und k”nnen daher in einem Block gelesen werden!
		mov	eax, 5
		mov	ebx, dword ptr ds:[BOOTCODE_TOTAL]		
		mov	dword ptr es:[STARTPOS_1], eax
		mov	word ptr es:[BLOCKS_1], bx
		mov	dword ptr es:[TOTAL_BLOCKS], ebx

		xor	eax, eax
		call	SET_INODEPOS		
		
		; Und das ganze an Position 3 schreiben...
		mov	eax, 3
		call	WRITE_DATA
		
		; Nun wird der klimbatch noch mit Namen im Dir eingetragen...

		; Dir befindet sich in Block 4
		mov	eax, 4
		call	READ_BLOCK
		
		call	CLR_DIR

		mov	eax, 3		; INODE in Block 3
		xor	bx, bx		; Nr. 0
		mov	dword ptr es:[DATA_BLOCK], eax
		mov	word ptr es:[DATA_SELECT], bx
		
		mov	al, OBJECT_NAME
		mov	byte ptr es:[DATA_TYPE], al

		; Wie nennen wir das?...
		mov	byte ptr es:[DESCRIPTION   ], 'V'
		mov	byte ptr es:[DESCRIPTION+ 1], 'O'
		mov	byte ptr es:[DESCRIPTION+ 2], 'S'
		mov	byte ptr es:[DESCRIPTION+ 3], ' '
		mov	byte ptr es:[DESCRIPTION+ 4], 'B'
		mov	byte ptr es:[DESCRIPTION+ 5], 'O'
		mov	byte ptr es:[DESCRIPTION+ 6], 'O'
		mov	byte ptr es:[DESCRIPTION+ 7], 'T'
		mov	byte ptr es:[DESCRIPTION+ 8], '$'
		
		xor	eax, eax
		call	SET_DIRPOS
		
		mov	eax, 4
		call	WRITE_DATA
		
		ret
	COPY_BOOT ENDP
		
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; COPY_SYSSELECT: Kopiert SYSSELECT (Bootmanager...)
	;		  BOOTCODE muá geschrieben sein!
	; Input : -
	; Output: -
	;
	COPY_SYSSELECT PROC NEAR
		; Der Code wandert zwar auch auf Diskette, ist jedoch von
		; dort nicht Startbar da dort kein MBR existiert!
		; Bisher ist folgendes Vorhanden/Vorbereitet:
		; Addr. Objekt
		; -     BOOTSTRAP LOADER
		; -     VIS
		; 0     BITMAP BLOCK 1
		; 1     INODE (fr ROOT-DIR)
		; 2     ROOT-DIR
		; 3     INODE (fr SYSTEM-DIR)
		; 4     SYSTEM-DIR
		; 5 ... BOOTCODE
		
		; Zun„chst kopieren wir den Datenbereich...
		; Wir holen eine DOS-Handle fr das File
		
		lea	dx, SYSSELECT_FILE	; Dateiname BootCode
		xor	al, al			; Zugriffsmodus: Nur Lesen
		mov	ah, 3Dh			; DOS: Datei ™ffnen
		int	21h
		jnc	@@DOSHandleOK
		lea	dx, MSG_0042
		mov	ah, 9
		int	21h
		mov	ax, 4c00h
		int	21h
	@@DosHandleOK:
		; Wir haben nun in AX das Handle fr die Datei

		mov	word ptr ds:[FILE_HANDLE], ax
		; Nun brauchen wir die File-Gr”áe!
		mov	bx, ax
		mov	al, 2		; Seekmodus 2
		xor	cx, cx		; SeekOffset 0 = Dateiende
		xor	dx, dx
		mov	ah, 42h		; DOS: Seek
		int	21h
		; AX=LO-WORD, DX=Hi-Word
		mov	word ptr ds:[SYSSEL_BYTES], ax
		; Zun„chst Seek an Anfang der Datei
		mov	bx, word ptr ds:[FILE_HANDLE]
		xor	cx, cx		; Hi-Position 0
		xor	dx, dx		; Lo-Position 0
		xor	al, al		; Position absolut
		mov	ah, 42h
		int	21h

		; Als erstes mal sehen wieviele Bl”cke fr den Code
		; ben”tigt werden...
		mov	bx, word ptr ds:[BYTE_PER_BLOCK]
		xor	eax, eax
		xor	edx, edx
		mov	ax, word ptr ds:[SYSSEL_BYTES]
		div	bx
		; AX enth„lt nun die ben”tigten Bl”cke
		; ist DX>0 muá noch ein Block Addiert werden...

		mov	dword ptr ds:[SYSSEL_BLOCKS], eax
		mov	word ptr ds:[SYSSEL_SIZE], dx
		cmp	dx, 0
		jz	@@SIZE_OK
		inc	eax
	@@SIZE_OK:	
		mov	dword ptr ds:[SYSSEL_TOTAL], eax
		
		lea	dx, MSG_0041
		mov	ah, 9
		int	21h
		mov	ax, word ptr ds:[SYSSEL_BYTES]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0037
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
		mov	eax, dword ptr ds:[SYSSEL_TOTAL]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0024
		mov	ah, 9
		int	21h
		lea	dx, MSG_0040
		mov	ah, 9
		int	21h

		; Insgesamt sind si Bytes zu schreiben
		mov	si, word ptr ds:[SYSSEL_BYTES]
		; Wir starten an Block eax-1
		mov	eax, 4
		; Das ganze kommt hinter den BOOTCODE!
		
		add	eax, dword ptr ds:[BOOTCODE_TOTAL]
		
		push	eax			; Startpos merken
		push	si		
	@@Cpy_Loop:						
		call	CLR_DATA		; Datenbr. l”schen

		; Wir Lesen Blockgr”áe
		pop	si
		push	si
		; Restliche Byte <= Blockgr”áe?
		cmp	si, word ptr ds:[BYTE_PER_BLOCK]
		jbe	@@RestLesen		; Letzter Block

		; Wir Lesen einen Block aus dem File
		mov	cx, word ptr ds:[BYTE_PER_BLOCK]
		pop	si
		sub	si, cx			; vom Rest abziehen
		push	si
		
		mov	ah, 3fh			; DOS: Read from File
		mov	bx, word ptr ds:[FILE_HANDLE]

		ASSUME	ds:BLOCK_DATA

		mov	dx, BLOCK_DATA		; Seg.-Addr.
		mov	ds, dx
		xor	dx, dx			; Offset 0
		int	21h
		jc	@@ReadErr

		ASSUME	ds:DATA
		mov	dx, DATA
		mov	ds, dx
		
		; Block ist voll. Wir schreiben...
		pop	si
		pop	eax
		inc	eax
		push	eax
		push	si
		call	WRITE_DATA
		jmp	short @@Cpy_Loop

	@@ReadErr:
		ASSUME	ds:DATA
		mov	dx, DATA
		mov	ds, dx

		pop	si
		pop	eax
		lea	dx, ds:MSG_0043
		mov	ah, 9
		int	21h
		mov	ax, 4c00h		; DOS: Terminate Process
		int	21h
				
	@@RestLesen:
		; Wir Lesen einen Block aus dem File
		pop	si
		mov	cx, si			; Rest aus dem File
		sub	si, si			; vom Rest abziehen=0
		push	si
		
		mov	ah, 3fh			; DOS: Read from File
		mov	bx, word ptr ds:[FILE_HANDLE]

		ASSUME	ds:BLOCK_DATA

		mov	dx, BLOCK_DATA		; Seg.-Addr.
		mov	ds, dx
		xor	dx, dx			; Offset 0
		int	21h
		jc	@@ReadErr

		ASSUME	ds:DATA
		mov	dx, DATA
		mov	ds, dx
		
		; Block ist voll. Wir schreiben...
		pop	si
		pop	eax
		inc	eax
		call	WRITE_DATA

		; Die Datei muá nun im SYSTEM-Directory eingetragen werden...
		call	CLR_DATA
		; Das Dir befindet sich an Addr. 4
		; Dessenn Inode Block an Addr. 3
		
		; Zun„chst holen wir den INODE...
		mov	eax, 3
		call	READ_BLOCK
		; Dort drfte eigentlich nix vorhanden sein. Wir tragen
		; dort die Daten ber die Datei ein...

		call	CLR_INODE
		
		mov	ax, BootCodeFlags
		mov	word ptr es:[FLAGS_TYPE], ax
		mov	eax, dword ptr ds:[SYSSEL_BLOCKS]
		mov	bx, word ptr ds:[SYSSEL_SIZE]
		mov	dword ptr es:[OBJECT_BLOCKS], eax
		mov	word ptr es:[OBJECT_SIZE], bx

		call	GET_SYSTIME
		mov	dword ptr es:[CREATION_TIME], eax
		mov	dword ptr es:[MODIFY_TIME], eax
		mov	dword ptr es:[ACCESS_TIME], eax
		mov	dword ptr es:[ARCHIVE_TIME], eax

		; EIGENTMER ist das SYSTEM-Dir (Eintrag 0)
		; INODE 1 (0=RootDir) in Block 1 
		mov	eax, 1		; Block des Sys-Dir INODE
		mov	bx, 1
		mov	dword ptr es:[OWNER_BLOCK], eax
		mov	word ptr es:[OWNER_SELECT], bx

		; Erste Block ist Block 5+ BOOTCODE_TOTAL

		mov	eax, 5
		add	eax, dword ptr ds:[BOOTCODE_TOTAL]
		mov	ebx, dword ptr ds:[SYSSEL_TOTAL]
				
		mov	dword ptr es:[STARTPOS_1], eax
		mov	word ptr es:[BLOCKS_1], bx
		mov	dword ptr es:[TOTAL_BLOCKS], ebx

		mov	eax, 1		; Ist Node 1 im Sysdir
		call	SET_INODEPOS		
		
		; Und das ganze an Position 3 schreiben...
		mov	eax, 3
		call	WRITE_DATA
		
		; Nun wird der klimbatch noch mit Namen im Dir eingetragen...

		; Dir befindet sich in Block 4
		mov	eax, 4
		call	READ_BLOCK
		
		call	CLR_DIR

		mov	eax, 3		; INODE in Block 3
		mov	bx, 1		; Nr. 1
		mov	dword ptr es:[DATA_BLOCK], eax
		mov	word ptr es:[DATA_SELECT], bx
		
		mov	al, OBJECT_NAME
		mov	byte ptr es:[DATA_TYPE], al

		; Wie nennen wir das?...
		mov	byte ptr es:[DESCRIPTION   ], 'S'
		mov	byte ptr es:[DESCRIPTION+ 1], 'Y'
		mov	byte ptr es:[DESCRIPTION+ 2], 'S'
		mov	byte ptr es:[DESCRIPTION+ 3], 'T'
		mov	byte ptr es:[DESCRIPTION+ 4], 'E'
		mov	byte ptr es:[DESCRIPTION+ 5], 'M'
		mov	byte ptr es:[DESCRIPTION+ 6], ' '
		mov	byte ptr es:[DESCRIPTION+ 7], 'S'
		mov	byte ptr es:[DESCRIPTION+ 8], 'E'
		mov	byte ptr es:[DESCRIPTION+ 9], 'L'
		mov	byte ptr es:[DESCRIPTION+10], 'E'
		mov	byte ptr es:[DESCRIPTION+11], 'C'
		mov	byte ptr es:[DESCRIPTION+12], 'T'
		mov	byte ptr es:[DESCRIPTION+13], '$'
		
		mov	eax, 1
		call	SET_DIRPOS
		
		mov	eax, 4
		call	WRITE_DATA
		
		; Der Klimbatsch muá nun noch im VIS eingetragen werden!
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	eax, 3
		mov	bx, 1
		mov	dword ptr es:[BOOT_INODE], eax
		mov	word ptr es:[BOOT_INODE_SELECT], bx
		ret
	COPY_SYSSELECT ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	include MKR2.INC	; Alles was hier fehlt!
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; MAKE_SYSDIR: Erstellt ein Direcory auf dem Volume
	; Input : -
	; Output: - (abbruch bei Fehler)
	;
	MAKE_SYSDIR PROC NEAR
		lea	dx, MSG_0034
		mov	ah, 9
		int	21h
		
		; Zun„chst wir der INODE des Root-Dirs (Addr. 1) geladen!
		mov	eax, 1
		call	READ_BLOCK
		; der erste INode ist nun das Root-Directory
		; Das System Directory kommt als 2. INODE...
		call	CLR_INODE
		
		mov	ax, SystemDirFlags		; Dir Flags
		mov	es:[FLAGS_TYPE], ax
		mov	eax, 1
		mov	es:[TOTAL_BLOCKS], eax

		; Eigentmer ist der INODE des ROOT-Dirs
		; BLOCK 1 INODE 0
		mov	eax, 1
		xor	bx, bx
		mov	dword ptr es:[OWNER_BLOCK], eax
		mov	word ptr es:[OWNER_SELECT], bx
		
		call	GET_SYSTIME
		mov 	dword ptr es:[CREATION_TIME], eax
		mov	dword ptr es:[ACCESS_TIME], eax
		mov	dword ptr es:[MODIFY_TIME], eax
		mov	dword ptr es:[ARCHIVE_TIME], eax
		; An Addr. 2 befindet sich das Root-Directory
		; Addr. 4 wird das System Dir erhalten
		; Addr. 3 ein INODE fr dieses Dir
		mov	eax, 4
		mov	es:[STARTPOS_1], eax
		mov	ax, 1
		mov	es:[BLOCKS_1], ax
		
		mov	ax, 1
		call	SET_INODEPOS
		
		mov	eax, 1
		call	WRITE_DATA

		; Nun muá noch der Eintrag im Root-Dir an Position 2
		; erstellt werden...
		
		mov	eax, 2
		call	READ_BLOCK

		call	CLR_DIR
		mov	byte ptr es:[DATA_TYPE], OBJECT_NAME
		mov	eax, 1		; INODE Block welcher das Dir beschr.
		mov	bx, 1		; Eintrag 1
		mov	dword ptr es:[DATA_BLOCK], eax
		mov	word ptr es:[DATA_SELECT], bx
		mov	byte ptr es:[DESCRIPTION    ], 'S'
		mov	byte ptr es:[DESCRIPTION+  1], 'Y'
		mov	byte ptr es:[DESCRIPTION+  2], 'S'
		mov	byte ptr es:[DESCRIPTION+  3], 'T'
		mov	byte ptr es:[DESCRIPTION+  4], 'E'
		mov	byte ptr es:[DESCRIPTION+  5], 'M'
		mov	byte ptr es:[DESCRIPTION+  6], '$'
		
		xor	eax, eax		; 1. Eintrag im ROOT-DIR
		call	SET_DIRPOS
		
		; Dies ist der letzte Eintrag fr das Root-Dir!
		; Die restlichen freien INODEs an Adresse 1 werden
		; nun in die folgenden Dir-Eintr„ge geschrieben.
		; Dies zeigt sp„ter, daá noch INODEs frei sind
		; und somit keine erstellt werden mssen.
		
		; Zun„chst mal sehen wieviele INODEs den in den Block
		; an Addr. 1 passen (abh„ngig von der Blockgr”áe!)
		
		mov	ax, 512			; Gr”áe eines Sektors
		movzx	bx, byte ptr [SEKS_PER_BLOCK]
		mul	bx
		xor	dx, dx
		mov	bx, 128			; Gr”áe eines INODEs
		div	bx
		xor	dx, dx
		; => AX = anz. INODEs in Block 1
		; 2 INODEs haben wir schon fr das ROOT-DIR und das
		; SYSTEM-DIR verbraucht!
		sub 	ax, 2
		mov	cx, ax
		; Es geht bei dem 2. Eintrag im ROOT-DIR loá!
		mov	di, 1
		mov	si, 2	; AB INODE 3 ist frei
	  @@Rest_Loop:
	 	call	CLR_DIR
	 	mov	eax, 1
		mov	dword ptr es:[DATA_BLOCK], eax
		mov	word ptr es:[DATA_SELECT], si
		mov	ax, di
		push	edi
		push	esi
		push	ecx
		call	SET_DIRPOS
		pop	ecx
		pop	esi
		pop	edi
		inc	di
		inc	si
		loop	@@Rest_Loop
		
		; Der ganze Mll wird nun auf das Drive verfrachtet
		mov	eax, 2
		call	WRITE_DATA
		
		; Nun fehlt noch das eigentliche SYSTEM-Directory und
		; ein INODE-Block dazu....
		; Das System DIR kommt an Addr. 4 und ein INODE-Block
		; dafr an Addr. 3...
		
		; Zun„chst der INODE...
		call	CLR_DATA
		mov	eax, 3
		call	WRITE_DATA
		
		; Und das Directory...
		call	CLR_DATA
		mov	eax, 4
		call	WRITE_DATA
		
		ret
	MAKE_SYSDIR ENDP

		
MAKEROOT ENDS

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

DATA SEGMENT PARA USE16 'DATA'

	; Standard MSGs
	MSG_0000	db	CR,LF, 'MAKEROOT V1.0 R0 - Internal Only'
			db	CR,LF, '(c)(r) 1995 by MZ Computer Systems'
			db	CR,LF, '$'
	MSG_0001	db	CR,LF, '0001: READ ERROR-CODE: $'
	MSG_0002	db	CR,LF, '0002: WRITE ERROR-CODE: $'	
	MSG_0003	db	CR,LF, 'DRIVE    : $'
	MSG_0004	db	CR,LF, 'BLOCKSIZE: $'
	MSG_0005	db	CR,LF, '0005: BLOCKSIZE OUT OF RANGE (1-32)!$'
	MSG_0006	db	CR,LF, '0006: DRIVE DOESN''T EXIST!$'
	MSG_0007	db	' Sectors, $'
	MSG_0008	db	' Cylinder, $'
	MSG_0009	db	' Heads $'
	MSG_0010	db	' MB $'
	MSG_0011	db	' => $'
	MSG_0012	db	CR,LF, 'PHYSICAL DATA  : $'
	MSG_0013	db	CR,LF, 'NO VOS/9 PARTITION ON THE SELECTED DRIVE!$'
	MSG_0014	db	CR,LF, 'PARTITION START: $'
	MSG_0015	db	'Cylinder $'
	MSG_0016	db	', Sector $'
	MSG_0017	db	', Head $'
	MSG_0018	db	' Sectors $'
	MSG_0019	db	CR,LF, 'PARTITION END  : $'
	MSG_0020	db	CR,LF, 'PARTITION DATA : $'
	MSG_0021	db	CR,LF, 'VOLUME SIZING  : $'
	MSG_0022	db	' Secs lost $'
	MSG_0023	db	CR,LF, 'VOLUME DATA    : $'
	MSG_0024	db	' Block(s) $'
	MSG_0025	db	' KB $'
	MSG_0026	db	CR,LF, 'BITMAP BLOCKS  : $'
	MSG_0027	db	' Blocks/Bitmap $'
	MSG_0028	db	' Bitmap(s) $'
	MSG_0029	db	CR,LF, 'Writing bitmap blocks...',CR,LF,'$'
	MSG_0030	db	LF,    'WRITE          : Zylinder $'
	MSG_0031	db	CR,LF, 'Writing bootstrap-code...',CR,LF,'$'
	MSG_0032	db	CR,LF, 'Writing ROOT directory...',CR,LF,'$'
	MSG_0033	db	CR,LF, 'Writing VIS...','$'
	MSG_0034	db	CR,LF, 'Creating SYSTEM directory...',CR,LF,'$'
	MSG_0035	db	CR,LF, 'Copy VOS/9 LOADER...',CR,LF,'$'
	MSG_0036	db	CR,LF, 'KERNEL BOOTCODE: $'
	MSG_0037	db	' Byte$'
	MSG_0038	db	CR,LF, '0038: Error opening file: VOSBOOT.BIN',CR,LF,'$'
	MSG_0039	db	CR,LF, '0039: Error reading file: VOSBOOT.BIN',CR,LF,'$'
	MSG_0040	db	CR,LF, 'Copy SYSTEM SELECT...',CR,LF,'$'
	MSG_0041	db	CR,LF, 'SYSTEM SELECT  : $'
	MSG_0042	db	CR,LF, '0042: Error opening file: SYS_SEL.BIN',CR,LF,'$'
	MSG_0043	db	CR,LF, '0043: Error reading file: SYS_SEL.BIN',CR,LF,'$'
	MSG_0044	db	CR,LF, '0044: Error opening file: VOS9.BIN',CR,LF,'$'
	MSG_0045	db	CR,LF, '0045: Error reading file: VOS9.BIN',CR,LF,'$'
	MSG_0046	db	CR,LF, 'KERNEL IMAGE  : $'		
	MSG_0047	db	CR,LF, 'Copy KERNEL...',CR,LF,'$'
	
	; Laufwerks Daten
	HDD_DRIVE		db	0	; Bios Laufwerks Code
	
	HDD_ZYLINDER		dw	0	
	HDD_SEKTOREN		db	0
	HDD_KOEPFE		db	0
	
	HDD_BLOCKSIZE		db	0	; Blockgr”áe
	SEKS_PER_BLOCK		db	0	; Sektoren je Block
	BYTE_PER_BLOCK		dw	0	
	
	VOLUME_START_ZYL	dw	0
	VOLUME_START_SEK	db	0
	VOLUME_START_HEAD	db	0
	VOLUME_START_SEKS	dd	0	; Anz. Seks bis PartStart

	VOLUME_START_SEKZYL	dw	0	; Phys. PartStart
	VOLUME_START_HEADZYL	db	0
	
	VOLUME_END_ZYL		dw	0
	VOLUME_END_SEK		db	0
	VOLUME_END_HEAD		db	0
	VOLUME_END_SEKS		dd	0	; Anz. Seks bis PartEnd


	VOLUME_SEKS		dd	0	; Anz. Seks im Volume ohne
						; den LostSeks
	VOLUME_SIZE		dd	0	; Gr”áe des Vol in KB ohne
						; den LostSeks
	VOLUME_BLOCKS		dd	0	; Anz. Bl”cke in Part
	VOLUME_LOST_SEKS	db	0	; Verlorene Seks in Part
		
	PART_SIZE		dw	0	; Gr”áe der Part in MB
	PART_SEKS		dd	0	; Anz. Seks in Part

	BITMAP_ENTRYS		dd	0	; Anz. der Eintr„ge je Bitmap	
	BITMAP_NODES		dw	0	; Anz. der Bitmap Blocks im
						; Volume
	BOOTCODE_BLOCKS		dd	0
	BOOTCODE_SIZE		dw	0
	BOOTCODE_TOTAL		dd	0
	BOOTCODE_BYTES		dw	0
	SYSSEL_BLOCKS		dd	0
	SYSSEL_SIZE		dw	0
	SYSSEL_TOTAL		dd	0
	SYSSEL_BYTES		dw	0
	KERNEL_BLOCKS		dd	0
	KERNEL_SIZE		dw	0
	KERNEL_TOTAL		dd	0
	KERNEL_BYTES		dw	0
		
	FILE_HANDLE		dw	0	; DOS FileHandles zum merken
	
	VOSBOOT_File	db	'VOSBOOT.BIN',0h	; Vos Bootcode Image
	SYSSELECT_File	db	'SYS_SEL.BIN',0h	; System Select Image
	KERNEL_FILE	db	'VOS9.BIN',0h		; Kernel Image

DATA ENDS

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

BOOT_CODE SEGMENT PARA USE16 'CODE'
	; Dies ist die VOS/9 Bootstrap-routine. Sie befindet sich im 
	; ersten Block des Volumes und wird vom Bios/Master an 7c00h
	; geladen. Die max. Gr”áe btr„gt 512 Bytes da dies die kleinste
	; Blockgr”áe ist (FDD).
	

	; 10.11.1995: Wir bewegen uns nichtmehr nach 600h sondern an 800h
	; um den eventuell vorhandenen MASTER nicht zu berschreiben...
	; Wir brauchen dessen Daten!
	
       	ASSUME CS:BOOT_CODE, DS:BOOT_CODE
	ORG 0h
		mov	bx, cx			; SekZyl sichern!
		cli				; Mal Ruhe hier
		xor	ax, ax			; Segment Adr. 0
		mov	ss, ax
		mov	es, ax
		mov	ds, ax
		mov	ax, 7c00h
		mov	sp, ax
		sti
		cld
		mov	si, 7c00h		; Quell-Adresse
		mov	ax, 0080h		; Ziel Seg 80h
		mov	es, ax
		xor	di, di			; Ziel Offset 0
		mov	cx, 100h		; Wir Kopieren alles!
		rep	movsw
	
		; Der Compiler erzeugt den Code nicht richtig! Warum- Bitte Borland
		; Fragen, ...
		
		db	0EAh,26h,00h,80h,00h

	andup:
		mov	ax, 80h		; Unsere Seg.-Addr.
		cli
		mov	ds, ax
		mov	es, ax
		xor	ax, ax
	  	mov	ss, ax
	  	mov	ax, 600h
	  	mov	sp, ax
	  	sti

		; PHOENIX BIOS BUG: Das Laufwerk wird bei FDs
		; ebenfalls nicht bergeben! Wir sehen nun
		; nach ob es eine Platte ist und nicht ob FD

		cmp	dl, 80h
		jae	@@SeemsHDD
		xor	dx, dx
		mov	bx, 1
	@@SeemsHDD:
		cmp	dl, 87h
		jbe	@@IsHDD
		xor	dx, dx
		mov	bx, 1
	@@ISHDD:
		mov	byte ptr ds:[DRIVE], dl
		mov	word ptr ds:[SEKZYL], bx
		mov	byte ptr ds:[HEADZYL], dh
		
		mov	ah, 8h				; Get Disk Param
		int	13h
	
		call	GetSek
		mov	byte ptr ds:[SEKTOREN], al
		mov	byte ptr ds:[HEADS], dl
	
		; MAKEROOT hat die Position und die Anzahl des KernelLoaders
		; am Ende des Codes eingetragen! Wir sehen also ob die Werte 
		; gltig sind und Laden den ganzen Klimbatsch!

		mov	cx, word ptr ds:[BOOT_SEKZYL]
		mov	dl, byte ptr ds:[BOOT_HEADZYL]
		mov	si, word ptr ds:[BOOT_SEKSIZE]
		cmp	si, 0
		jnz	@@GetAllTracks

		mov	si, offset ds:kein_sys_msg
		jmp	short @@Endless
	
		kein_sys_msg	db 'KEIN SYSTEM!$'
		
	@@GetAllTracks:
		call	GetBootCode
		jc	@@ReadFailed

		mov	dl, byte ptr ds:[DRIVE]
		mov	cx, word ptr ds:[SEKZYL]
		mov	dh, byte ptr ds:[HEADZYL]

		db	0eah,00h,7ch,00h,00h

	@@ReadFailed:
		lea	si, ds:read_failed
		jmp	short @@Endless
	
		read_failed	db	'Readerror!$'

	@@Endless:
		call	Print_boot
		jmp	@@Endless

	GetBootCode proc near
		mov 	ax, 7c0h		
		mov 	es, ax
		xor	bx, bx
		mov 	dh, byte ptr ds:[BOOT_HEADZYL] ; Kopf Part start  
		mov 	cx, word ptr ds:[BOOT_SEKZYL]  ; Zylinder/Sektor Part start 

		mov	di, word ptr ds:[BOOT_SEKSIZE] ; Anzal zu les. Sektoren
		mov	si, 20

	@@BootLoop:
		mov	dl, byte ptr ds:[DRIVE]
		clc
		mov 	ax, 0201h		; 1 Sektor lesen
		int 	13h
		jc	@@LoadFail

		dec	di
		cmp	di, 0
		je	@@Fertig

		push	bx
		push	di
				
		call	getsek

		cmp	dl, byte ptr ds:[HEADS]
		je	@@NextSek
		inc	dl
		jmp	short @@IsOK
	@@NextSek:
		mov	dl, 0
		cmp	al, byte ptr ds:[SEKTOREN]
		je	@@NextZyl
		inc	al
		jmp	short @@IsOK
	@@NextZyl:
		mov	al, 1
		inc	bx
	@@IsOK:
		call	setsek
		pop	di
		pop	bx
		
		add	bx, 200h		; Die n„chsten 512 Bytes bitte!
		mov	si, 20
		jmp	short @@BootLoop

	@@Fertig:
		clc
		ret		

	@@LoadFail:
		dec	si
		cmp	si, 0
		je	@@Adiosio
		xor	ax, ax
		mov	dl, byte ptr ds:[DRIVE]
		int	13h
		jc	@@Adiosio		
		jmp	@@BootLoop

	@@Adiosio:
		mov	cl, ah
		xor	ch, ch
	 @@ERR:
		mov	ax, 0E2Eh
		xor	bh, bh
		int	10h
		loop	@@ERR
		stc
		ret
	GETBOOTCODE ENDP		

	PRINT_BOOT PROC NEAR
	; Wir erwarten die Text-Offset in si!
	@@msg_01:
		mov	al, byte ptr ds:[si]
		cmp	al, '$'
		je	@@Fertig
		mov	ah, 0eh
		mov	bl, 07h
		int	10h			; Video Int
		inc	si
		jmp	short @@msg_01
	@@Fertig:
		ret
	PRINT_BOOT ENDP

	GETSEK PROC NEAR
		; CX	= SekZyl
		; DH	= HeadZyl
		; Rckgabe:
		; AL	= Sektor
		; BX 	= Zylind
		; DL	= Kopf
	
		mov	al, ch
		mov	ah, cl
		shr	ah, 6
		xor	bx, bx
		mov	bl, dh
		shr	bl, 6
		shl	bl, 8
		add	ah, bh
		mov	bx, ax			; => anz. Zylinder
	
		mov	ax, cx
		and	ax, 63			; => anz. Sektoren

		xchg	dh, dl
		xor	dh, dh
		and	dx, 63			; => anz. K”pfe
		ret
	GETSEK ENDP	

	SETSEK PROC NEAR
		; AL = Sektor
		; BX = Zylinder
		; DL = Kopf
		; Rckgabe:
		; CX = Sekzyl
		; Dh = HeadZyl
	
		mov	ch, bl
		mov	cl, al			; Sektor dazu
		mov	al, bh
		shl	al, 6
		add	cl, al			; Rest Zyl dazu
		shr	bh, 2
		mov	al, bh
		shl	al, 6
		mov	dh, dl
		add	dh, al
		ret
	SETSEK ENDP

	; Diese Daten werden vom BIOS/MASTER bergeben!

	sekzyl		dw	0
	headzyl		db	0
	drive		db	0

	heads		db	0
	sektoren	db	0

	; Diese DATEN werden von MAKEROOT Eingetragen!

	ORG	1F9h		; !!!!! Never change or die!

	BOOT_SEKZYL	dw	0		; BootCode Start Sektor/Zylinder
	BOOT_HEADZYL	db	0		; BootCode Start Kopf
	BOOT_SEKSIZE	dw	0		; Gr”áe des Bootcodes in Sektoren

	ID		db      055h, 0AAh
BOOT_CODE ENDS

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

SEKTOR_DATA SEGMENT PARA USE16 'DATA'

	READ_DATA	db	512 dup (?)

	PART_TABEL	db	512 dup (?)	

	INODE_START	= $
		FLAGS_TYPE		dw	0
		RESERVED_TYPE		dw	0
		
		OBJECT_BLOCKS		dd	0
		OBJECT_SIZE		dw	0
		
		CREATION_TIME		dd	0
		OWNER_ID		dw	0
		MODIFY_TIME		dd	0
		MODIFY_ID		dw	0
		ACCESS_TIME		dd	0
		ACCESS_ID		dw	0
		ARCHIVE_TIME		dd	0
		ARCHIVE_ID		dw	0
		
		OWNER_BLOCK		dd	0
		OWNER_SELECT		dw	0
		LINK_BLOCK		dd	0
		LINK_SELECT		dw	0
		GROUP_BLOCK		dd	0
		GROUP_SELECT		dw	0
		
		INDIRECT_BLOCK		dd	0
		
		STARTPOS_1		dd	0
		BLOCKS_1		dw	0
		STARTPOS_2		dd	0
		BLOCKS_2		dw	0
		STARTPOS_3		dd	0
		BLOCKS_3		dw	0
		STARTPOS_4		dd	0
		BLOCKS_4		dw	0
		STARTPOS_5		dd	0
		BLOCKS_5		dw	0
		STARTPOS_6		dd	0
		BLOCKS_6		dw	0
		STARTPOS_7		dd	0
		BLOCKS_7		dw	0
		STARTPOS_8		dd	0
		BLOCKS_8		dw	0
		STARTPOS_9		dd	0
		BLOCKS_9		dw	0
		STARTPOS_10		dd	0
		BLOCKS_10		dw	0
		STARTPOS_11		dd	0
		BLOCK_11		dw	0

		RESERVED_INODE_DATA	dw	0

		TOTAL_BLOCKS		dd	0		
	INODE_SIZE	= $ - INODE_START		; 128 Byte Total

	DIR_START	= $
		DATA_BLOCK		dd	0
		DATA_SELECT		dw	0
		DATA_TYPE		db	0
		DESCRIPTION		db	25 dup (?)
	DIR_SIZE	= $ - DIR_START			; 32 Byte Total

	VOLUME_INFO_START	= $
		VOL_BLOCKSIZE		db	0
		VOL_MAGIC_ID		dw	0		
		VOL_FLAGS_1		db	0
		; Bit      Description (High)
		;  7       Volume Mounted/Added
		;  6       Volume Write Protected
		;  5       Auto-Check Enabled
		;  4       Removable Media
		;  3       Volume Defective
		;  2..0    Volume Type
		;          0 = Unknown
		;          1 = Root
		;          2 = Add-On Root
		;          3 = Mount
		;          4..7 = reserved
		VOL_FLAGS_2		db	0
		; Reserved!
		VOL_MOUNTS		db	0
		; Wird bei jedem Mount erh”ht wenn Auto-Check Enabled
		VOL_CHECKMOUNTS		db	0
		; Nach wieviel mount check l„uft (nur bei Auto-Check)
		VOL_MOUNT_TIME		dd	0
		VOL_MOUNT_ID		dw	0
		VOL_DISMOUNT_TIME	dd	0
		VOL_DISMOUNT_ID		dw	0
		VOL_CHECK_TIME		dd	0
		VOL_CHECK_ID		dw	0
		VOL_CREATE_TIME		dd	0
		VOL_CREATED_ID		dw	0		
	
		BOOT_INODE		dd	0
		BOOT_INODE_SELECT	dw	0
		; Inode des SYSTEM-SELECT Codes (NUR ROOT-VOLUME!)
		KERNEL_INODE		dd	0
		KERNEL_INODE_SELECT	dw	0
		; Inode des Kernel-Images fr den BootCode.
		; NUR BEI ROOT-VOLUME!
		DEVICE_INODE		dd	0
		DEVICE_INODE_SELECT	dw	0
		; Inode des Ger„tetreibers fr ProtMode Zugriffe auf das
		; Volume. NUR BEI ROOT-VOLUME!
			
		VOL_LABEL		db	255 dup (?)
	
		; Volume Info Sektor (VIS) muá insgemsat 512 Byte gr”áe
		; haben! Bisher = 304 Byte
		
		VIS_RESERVED		db	208 dup (0)
			
	VOLUME_INFO_SIZE	= $ - VOLUME_INFO_START			
SEKTOR_DATA ENDS

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

BLOCK_DATA SEGMENT PARA USE16 'DATA'
	BLOCK_SIZE	db	65535 dup (?)
BLOCK_DATA ENDS

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ

STACK_SEG SEGMENT PARA USE16 'STACK'
	SS_SIZE	db 256 dup (?)
	TOS	= this byte
STACK_SEG ENDS

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ
END INIT_IP
