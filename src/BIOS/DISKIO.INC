;	Project		VOS/9 
;  	File name	DISKIO.INC	24.11.1995
;	File type	Include
;	
;  	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		24.11.1995
; 	Release		0		24.11.1995
;	
;  	Autor		Marcus Zoller
;  	
;	Description	Disk I/O Funktionen f걊 den Realmode/V86
;			Ben봳igt VIO.INC
;
;	Includes	-
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	System BIOS, Disk BIOS
;	
;	Bugfix List 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;	
;	Release Comments 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;	
;	Function Ref 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;
;	GET_SEKZYL: Entpackt die Laufwerks-Positions-Angabe des BIOS
;		 CX = SEKTOR / ZYLINDER, DH = KOPF / ZYLINDER
;		 Output: AL = SEKTOR, BX = ZYLINDER, DL = KOPF
;	SET_SEKZYL: Packt die Angaben
;		AL=Sektor, BX=Zylinder, DL=Kopf
;		Output: CX=Sektor/Zylinder, DH=Kopf/Zylinder
;	ADD_SEK: Adiert EBX Sektoren auf die aktuelle Position
;		in CX=SekZyl, DH=HeadZyl => CX+DH aktualisiert
;	SET_DRIVE_DATA: Setzt die Daten f걊 ein Laufwerk in DL
;		CF=Laufwerk Fehler!
;	READ: Lesen eines Sektors - DL=Laufwerk, DH=HeadZyl, CX=SekZyl
;		es:bx=Buffer (bx wird um 200h erh봦t wenn nicht CF=1 - Fehler)
;	WRITE: Schreiben eines Sektors - DL=Laufwerk, DH=HeadZyl, CX=SekZyl
;		es:bx=Buffer (bx wird um 200h erh봦t wenn nicht CF=1 - Fehler)
;

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; SET_DRIVE_DATA: Setzt die Daten f걊 ein Laufwerk
	; Input : DL = Laufwerk
	; Output: CF = Laufwerk existiert nicht oder sonst. Fehler
	;
	SET_DRIVE_DATA PROC NEAR
		push	ax bx cx dx
		mov	ah, 8h				; Get Disk Param
		int	13h
		jc	@@NixDa	
		call	GET_SEKZYL
		mov	byte ptr cs:[DRIVE_SEKS], al
		mov	byte ptr cs:[DRIVE_HEADS], dl
		mov	word ptr cs:[DRIVE_ZYLS], bx
		clc
		jmp	short @@Ende
	@@NixDa:
		stc
	@@Ende:
		pop	dx cx bx ax
		ret
	SET_DRIVE_DATA ENDP
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; ADD_SEK:    Addiert X Sektoren zur 갶ergebenen Position und gibt
	;             die neue Position zur갷k
	; Input:      CX = Aktueller SekZyl
	;             DH = Aktueller ZylHead
	;             EBX = Anzahl zu addierende Sektoren
	; Output:     CX, DH Aktualisiert
	;
	ADD_SEK PROC NEAR
		push	ax
		push	ebx
		call	get_sekzyl
		pop	ecx
	
	@@IncLoop:
		cmp	dl, byte ptr cs:[DRIVE_HEADS]
		je	@@NextSek
		inc	dl
		jmp	short @@IsOK
	
	@@NextSek:
		mov	dl, 0
		cmp	al, byte ptr cs:[DRIVE_SEKS]
		je	@@NextZyl
		inc	al
		jmp	short @@IsOK
	
	@@NextZyl:
		mov	al, 1
		inc	bx
	
	@@IsOK:
		loop	@@IncLoop
		call	set_sekzyl
		pop	ax
		ret	
	ADD_SEK ENDP

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; GET_SEKZYL: Wandelt die BIOS Pos. Angaben in die Bestandteile um
	; Input : CX = SEKTOR / ZYLINDER
	;         DH = KOPF / ZYLINDER
	; Output: AL = SEKTOR
	;         BX = ZYLINDER
	;         DL = KOPF
	; 
	GET_SEKZYL PROC NEAR
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
		and	dx, 63			; => anz. K봯fe
		ret
	GET_SEKZYL ENDP	

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; SET_SEKZYL: Wandelt die Pos. Angaben in das BIOS Format...
	; Input : AL = SEKTOR
	;         BX = ZYLINDER
	;         DL = KOPF
	; Output: CX = SEKTOR / ZYLINDER
	;         DH = KOPF / ZYLINDER
	; 
	SET_SEKZYL PROC NEAR
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
	SET_SEKZYL ENDP

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; READ: Liest einen Sektor
	; Input : DL = Laufwerk, DH=HeadZyl, CX=Sekzyl, es:bx=Buffer
	; Output: CF = 1 - Laufwerk existiert nicht oder sonst. Fehler
	; 
	; Die Offset des Buffers wird nach erfolgreichem Lesen automitsch 
	; erh봦t!
	;
	READ PROC NEAR
		push	ax di
		mov	di, 4
	@@Lesen:
		mov	ax, 0201h		; 1 Sektor lesen
		int	13h
		jc	@@Fehler
		add	bx, 200h		; Buffer weiterschreiben
		pop	di ax
		clc
		ret
	@@Fehler:
		dec	di
		cmp	di, 0
		jne	@@Lesen
		pop	di ax
		stc
		ret
	READ ENDP

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; WRITE: Schreibt einen Sektor
	; Input : DL = Laufwerk, DH=HeadZyl, CX=Sekzyl, es:bx=Buffer
	; Output: CF = 1 - Laufwerk existiert nicht oder sonst. Fehler
	; 
	; Die Offset des Buffers wird nach erfolgreichem Schreiben automitsch 
	; erh봦t!
	;
	WRITE PROC NEAR
		push	ax di
		mov	di, 4
	@@Schreiben:
		mov	ax, 0301h		; 1 Sektor schreiben
		int	13h
		jc	@@Fehler
		add	bx, 200h		; Buffer weiterschreiben
		pop	di ax
		clc
		ret
	@@Fehler:
		dec	di
		cmp	di, 0
		jne	@@Schreiben
		pop	di ax
		stc
		ret
	WRITE ENDP
	
	DRIVE_HEADS	db	0		; Anzahl K봯fe
	DRIVE_SEKS	db	0		; Anzahl Sektoren
	DRIVE_ZYLS	dw	0		; Anzahl Zylinder
	