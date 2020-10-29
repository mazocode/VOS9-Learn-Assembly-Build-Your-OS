;	Project		VOS/9 
;  	File name	VIO.INC		18.11.1995
;	File type	Include
;	
; 	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		18.11.1995
; 	Release		0		18.11.1995
;	
;  	Autor		Marcus Zoller
;  	
;	Description	Video I/O Funktionen fr den Realmode/V86
;	
;	Includes	-
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	System BIOS, Video BIOS
;	
;	Bugfix List ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	
;	Release Comments ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	
;	Function Ref ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;
;	GET_ADDR_VRAM	: Liefert VRAM Seg.-Adresse in VRAM_SEG_ADDR
;	PRINT_CHAR	: Ausgabe eines Zeichens in AL, AH=Farb Attr.
;	PRINT_LOOP	: Wiederholt Zeichen CX mal (AL, AH)
;	PRINT_ZAHL	: Ausgabe einer 8Bit Zahl, AH=Farbe, BL=Zahl
;	PRINT		: Ausgabe eines Strings, ds:si = String, ah=Farb Attr.
;	SET_CURPOS	: Setzen der Cursor Position, dh=y, dl=x
;	GET_CURPOS	: Lifert die Cursor Pos. in dx zurck
;	CLEAR		: L”scht den Bildschirm
;	DRAW_BOX	: Zeichnet Kasten, AL=X1, AH=Y1, BL=X2, BH=Y2
;

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_ADDR_VRAM: Liefert VRAM Seg.-Addr. zurck
	; Input : -
	; Output: -
	;
	GET_ADDR_VRAM	PROC NEAR
		push	bx ax
		mov	ah, 0fh			; Get Current Video State
		int	10h
		; AL = Video Mode, AH=Nr. of columns, BH=Active Page
		shl	al, 1
		shr	al, 1	
		cmp	al, 7
		je	short @@IsMono
		mov	bx, 0B800h
		jmp	short SetVideo	
	@@IsMono:
		mov	bx, 0B000h
	SetVideo:
		mov	word ptr [VRAM_SEG_ADDR], bx
		pop	ax bx
		ret
	GET_ADDR_VRAM	ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; PRINT_CHAR: Gibt ein Zeichen direkt in das VRAM aus...
	; Input : AH = Farb-Attribut
	;         AL = Zeichen (ASC-II Code)
	; Output: -
	;
	PRINT_CHAR PROC NEAR
		push	es ax bx cx dx
		push	ax
		mov	bx, word ptr [VRAM_SEG_ADDR]
		mov	es, bx
		mov	ah, 3
		xor	bh, bh
		int	10h
		mov	ch, dh
		mov	cl, dl
		cmp	dl, 79
		je	@@DataNext
		inc	dl
		jmp	short @@DataOK	
	@@DataNext:
		mov	dl, 0
		inc	dh
	@@DataOK:
		push	cx
		xor	bh, bh
		mov	ah, 2h
		int	10h
		pop	cx
		movzx	bx, cl
		add	bx, bx		; X-Offset (Spalte * 2)
		movzx	ax, ch
		mov	cx, 160		; Y-Offset (Zeile * 160)
		mul	cx
		add	ax, bx
		mov	di, ax
		pop	ax
		cld
	    	stosw
	    	pop	dx cx bx ax es
	        ret
	PRINT_CHAR ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; PRINT_LOOP: Wiederholt die Ausgabe eines Zeichens
	; Input : AH = Farb-Attribut
	;         AL = Zeichen
	;         CX = Anzahl Wiederholungen
	;
	PRINT_LOOP PROC NEAR
	@@plp:
		call	PRINT_CHAR
		loop	@@plp
		ret
	PRINT_LOOP ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; PRINT: Ausgabe eines Strings direkt ins VRAM
	; Input : SI = Offset des Strings /DS=Seg
	;         AH = Farb-Attribut
	; Output: -
	;
	PRINT PROC NEAR
		push	ax si
	@@pnull:
		mov	al, byte ptr cs:[si]
		cmp	al, '$'
		je	@@ende
		call	PRINT_CHAR
		inc	si
		jmp	short @@pnull	
	@@ende:
		pop	si ax
		ret
	PRINT ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ	
	; PRINT_ZAHL: Gibt eine Zahl aus - so siehts aus!
	; Input : bl = 8 Bit Zahl, ah =Farbe
	; Output: -
	;
	PRINT_ZAHL PROC NEAR
		push	ax bx cx dx
		
		cmp	bl, 0C8h
		jb	@@kleiner200
		mov	al, 32h		;2
		push	bx
		call	print_char
		pop	bx
		sub	bl, 200
		jmp	short @@StelleB
	@@kleiner200:
		cmp	bl, 64h
		jb	@@StelleB
		mov	al, 31h
		push	bx
		call	print_char
		pop	bx
		sub	bl, 100
	@@StelleB:
		cmp	bl, 10
		jb	@@StelleC
		push	bx
		mov	ch, ah
		movzx	ax, bl
		mov	bx, 10
		xor	dx, dx
		div	bx
		add	ax, 30h
		mov	ah, ch
		call	print_char
		sub	al, 30h
		mov	ch, ah
		xor	ah, ah
		mov	bx, 10
		xor	dx, dx
		mul	bx
		pop	bx
		sub	bx, ax
		mov	ah, ch
	@@StelleC:
		mov	al, bl
		add	al, 30h
		call	print_char	

		pop	dx cx bx ax
		ret
	PRINT_ZAHL ENDP	
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SET_CURPOS: Setzt die aktuelle position des Cursors
	; Input : DH = Y
	;         DL = X 
	; Output: -
	;
	SET_CURPOS PROC NEAR
		push	ax bx dx
		xor	bh, bh
		mov	ah, 2
		int	10h
		pop	dx bx ax
		ret
	SET_CURPOS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_CURPOS: Liefert die aktuelle position des Cursors zurck
	; Output: DH = Y
	;         DL = X 
	; Input : -
	;
	GET_CURPOS PROC NEAR
		push	ax bx
		mov	ah, 3
		xor	bh, bh
		int	10h
		pop	bx ax
		ret
	GET_CURPOS ENDP
		
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ	
	; DRAW_BOX: Zeichnet ein Kasten 
	; Input : al = X1, ah = Y1
	;         bl = X2, bh = Y2
	; Output: -
	;
	DRAW_BOX PROC NEAR
		push	ax bx cx dx
		push	ax
		push	bx
		mov	dh, ah
		mov	dl, al
		call	set_curpos
		mov	al, 'Ú'
		mov	ah, 71h		; Blau auf weiá
		call	print_char
		; Nun brauchen wir X2-X1
		pop	bx
		pop	ax
		xor	cx, cx
		mov	cl, bl
		sub	cl, al
		sub	cl, 2
		push	ax
		push	bx
		mov	al, 'Ä'
		mov	ah, 71h
		call	PRINT_LOOP
		mov	al, '¿'
		mov	ah, 71h
		call	PRINT_char		; !! OHOH
		; Nun brauchen wir Y2-Y1
		pop	bx
		pop	ax
		xor	cx, cx
		mov	cl, bh
		sub	cl, ah
		sub	cl, 1		; Anzahl Zeilen zu zeichen
		mov	dh, ah		; Start X
		inc	dh		; Erste Zeile
		mov	dl, al
	@@DrawBody:
		push	cx
		push	dx
		push	ax
		push	bx
		call	set_curpos
		mov	al, '³'
		mov	ah, 71h
		call	PRINT_CHAR
		pop	bx
		pop	ax
		xor	cx, cx
		mov	cl, bl
		sub	cl, al
		sub	cl, 2
		push	ax
		push	bx
		mov	al, ' '
		mov	ah, 71h
		call	PRINT_LOOP
		mov	al, '³'
		mov	ah, 71h
		call	PRINT_CHAR
		pop	bx
		pop	ax
		pop	dx
		pop	cx
		inc	dh	; N„chste Zeile
		dec	cl
		cmp	cl, 0
		je	@@SoweitOK
		jmp	short @@DrawBody
	@@SoweitOK:
		push	ax
		push	bx
		mov	dh, bh
		mov	dl, al
		call	set_curpos
		mov	al, 'À'
		mov	ah, 71h		; Blau auf weiá
		call	print_char
		; Nun brauchen wir X2-X1
		pop	bx
		pop	ax
		xor	cx, cx
		mov	cl, bl
		sub	cl, al
		sub	cl, 2
		mov	al, 'Ä'
		mov	ah, 71h
		call	PRINT_LOOP
		mov	al, 'Ù'
		mov	ah, 71h
		call	PRINT_char
		pop	dx cx bx ax
		ret
	DRAW_BOX ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ	
	; CLEAR: L”scht den Bildschirm und setzt Cursor oben links
	; Input : -
	; Output: -
	;
	CLEAR PROC NEAR		; <-Alles was sich Reimt ist gut!
		push	ax cx dx
		xor	dx, dx
		call	set_curpos
		; Bildschrim L”schen!
		mov	cx, 2000
		mov	ah, 7h
		mov	al, ' '
		call	PRINT_LOOP
		xor	dx, dx
		call	set_curpos
		pop	dx cx ax
		ret
	CLEAR ENDP
	
	VRAM_SEG_ADDR	dw	0
	VRAM_CHG	db	0
	