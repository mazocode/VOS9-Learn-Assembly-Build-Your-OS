;	Project		VOS/9 
;  	File name	VIDEO.INC	23.02.1996
;	File type	Assembly
;	
;  	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		23.02.1996
; 	Release		0		23.02.1996
;	
;  	Autor		Marcus Zoller
;  	
;	Description	Standard Kernel Textmode VGA Funktionen
;
;	Includes	..\PORTS\VGA.DEF
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	
;	
;	Bugfix List 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;	
;	Release Comments 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;	
;	Function Ref 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;


	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_PROG_CRT: Programmiert den VGA CRT-Controller
	; Input : ax=Word to write
	; Output: -
	; Device: EGA/VGA/SVGA/komp.
	; Add   : DS=Selektor des Kernel Data Segmentes
	;
	vid_prog_crt	proc near
		push	edx
		push	ebx
		mov	bl, byte ptr ds:[display_mode]
		cmp	bl, 7
		jne	@@COLOR_CRT
		mov	dx, VGA_CRT_MONO
		jmp	@@SET_CRT_PORT
	     @@COLOR_CRT:
		mov	dx, VGA_CRT_COLOR
	     @@SET_CRT_PORT:
		pop	ebx
		out	dx, al
		jmp	short $+2
		jmp	short $+2
		xchg	al, ah
		inc	dx
		out	dx, al
		jmp	short $+2
		jmp	short $+2
		xchg	al, ah
		pop	edx
		ret
	vid_prog_crt	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_CUR_POS: Setzt den Textmode Cursor bei VGA-Karten
	; Input : cl=x_pos, ch=y_pos
	; Output: -
	; Device: EGA/VGA/SVGA/komp.
	; Add   : keine Bereichspr갽ung! kein Sichern der Position!
	; Subs  : vid_prog_crt
	;
	vid_cur_pos	proc near
		push	ebx
		xor	bx, bx
		movzx	bx, cl
		add	bx, bx			; X-Offset (Spalte*2)
		push	eax
		xor	ax, ax
		movzx	ax, ch
		push	edx
		push	ecx
		mov	cx, 160			; Y-Offset (Zeile*160)
		mul	cx
		add	ax, bx			; => Totale Offset
		shr	ax, 1
		mov	bx, ax
		mov	al, 0eh
		call	vid_prog_crt
		mov	al, 0fh
		mov	ah, bl
		call	vid_prog_crt
		pop	ecx
		pop	edx
		pop	eax
		pop	ebx
		ret
	vid_cur_pos	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_SCRL_UP: Scrollt die Text-Screen um 1 Zeile nach oben
	; Input : -
	; Output: -
	; Device: Alle VideoCards
	; Add   : ES=Selektor auf Video-Textmode-Ram
	;
	vid_scrl_up	proc near
		push	ecx
		push	esi
		push	edi
		push	eax
		mov	ecx, 1920		; 24 Zeilen a 80 Zeichen
		cld
		xor	edi, edi
		mov	esi, 160		; Start ab "n꼊hster Zeile"
	  @@cpy_lp1:
	  	mov	ax, word ptr es:[esi]
	  	mov	word ptr es:[edi], ax
	  	add	esi, 2
	  	add	edi, 2
	  	loop	@@cpy_lp1
	  	mov	cx, 160			; Letzte Zeile L봲chen!
	  	mov	ax, 0720h
	  	rep	stosw
	  	pop	eax
	  	pop	edi
	  	pop	esi
	  	pop	ecx
	  	ret
	vid_scrl_up	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_GOTOXY: Setzt die Cursorposition mit Bereichspr갽ung und
	;             und Updaten der Cursordaten im Textmodus
	; Input : ch=y_Pos, cl=x_pos
	; Output: CF=Fehler - max. Daten 갶erschritten
	; Device: VGA+komp. im Textmodus
	; Add   : DS=Selektor des Kernel Data Segmentes
	;
	vid_gotoxy	proc near
		cmp	cl, 79
		jg	@@ExitFunc
		cmp	ch, 24
		jg	@@ExitFunc
		mov	byte ptr ds:[dsp_cursor_x], cl
		mov	byte ptr ds:[dsp_cursor_y], ch
		call	vid_cur_pos
		clc
		ret
	  @@ExitFunc:
	  	stc
		ret  
	vid_gotoxy 	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_CLR_SCRN: L봲cht den Textmode Schirm 
	;        
	; Input : -
	; Output: -
	; Device: Alle VideoCards
	; Add   : ES=Selektor auf Video-Textmode-Ram
	;         Cursorposition wird nicht ge꼗dert!
	;
	vid_clr_scrn	proc near
		push	eax
		push	ecx
		push	edi
		mov	eax, 0720h
		mov	ecx, 2000
		xor	edi, edi
		cld
		rep	stosw
		pop	edi
		pop	ecx
		pop	eax
		ret
	vid_clr_scrn	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_GET_POS: Liefert die aktuelle Corsorposition im Textmode
	;             und Updaten der Cursordaten im Textmodus
	; Input : -
	; Output: ch=y_Pos, cl=x_pos
	; Device: Alle Videos im Textmodus
	; Add   : DS=Selektor des Kernel Data Segmentes
	;
	vid_get_pos	proc near
		mov	cl, byte ptr ds:[dsp_cursor_x]
		mov	ch, byte ptr ds:[dsp_cursor_y]
		ret
	vid_get_pos	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_NEXT_LN: Zeilenforschub (LF)
	;
	; Input : -
	; Output: -
	; Device: Alle Videos im Textmodus
	; Add   : 
	; Subs  : vid_get_pos, vid_gotoxy, vid_scrl_up
	;
	vid_next_ln	proc near
		push	ecx
		call	vid_get_pos
		xor	cl, cl
		inc	ch
		call	vid_gotoxy		; N꼊hste Zeile (Y)
		jnc	@@LineOK
		mov	ch, 24
		call	vid_scrl_up		; Scroll 1 Line Up
		call	vid_gotoxy	
	 @@LineOK:
		pop	ecx
		ret
	vid_next_ln	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_PRN_CHR: Ausgabe eines Zeichens im Textmodus
	;
	; Input : AL=ASC_II Zeichen, AH=Farbattribut
	; Output: -
	; Device: Alle Videos im Textmodus
	; Add   : DS=Selektor des Kernel Data Segmentes
	;	  ES=Selektor VRAM
	;	  Kein Update der Cursorposition!
	; Subs  : vid_get_pos
	;
	vid_prn_chr	proc near
		push	edi
		push	ecx
		push	ebx
		push	edx
		push	eax
		call	vid_get_pos
		movzx	bx, cl
		add	bx, bx		; X-Offset (Spalte * 2)
		movzx	ax, ch
		mov	cx, 160		; Y-Offset (Zeile * 160)
		mul	cx
		add	ax, bx
		movzx	edi, ax		; Totale Offset
		pop	eax
		stosw
		pop	edx
		pop	ebx
		pop	ecx
		pop	edi
		ret	
	vid_prn_chr	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_PRN_OUT: Ausgabe eines Zeichens im Textmodus
	;              und Updaten der Cursordaten und Scoll_UO
	;
	; Input : AL=ASC_II Zeichen, AH=Farbattribut
	; Output: -
	; Device: Alle Videos im Textmodus
	; Add   : Textmodus nur 80x25!
	;	  Keine Beachtung von Steuercodes!
	;
	; Subs  : vid_prn_chr, vid_get_pos, vid_gotoxy, vid_scrl_up
	;
	vid_prn_out	proc near
		call	vid_prn_chr
		push	ecx
		call	vid_get_pos
		inc	cl			; N꼊hste Spalte (X)
		call	vid_gotoxy
		jnc	@@OutOK
		xor	cl, cl
		inc	ch
		call	vid_gotoxy		; N꼊hste Zeile (Y)
		jnc	@@OutOK
		mov	ch, 24
		call	vid_scrl_up		; Scroll 1 Line Up
		call	vid_gotoxy	
	  @@OutOK:
	        pop	ecx
	  	ret
	vid_prn_out	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; VID_PRN_LN: Ausgabe eines Nullterminierten Strings mit beachtung
	;	      von Steuercodes
	;
	; Input : AH=Farbattribut, FS:ESI=String
	; Output: -
	; Device: Alle Videos im Textmodus
	; Add   : Update der Cursorposition und Zeilenschaltung!
	; Subs  : vid_prn_out
	;
	vid_prn_ln	proc near
		push	eax
		push	ecx
		push	esi
	 @@ploop1:
		mov	al, byte ptr fs:[esi]
		cmp	al, '$'
		je	@@checkend
		cmp	al, 0ah
		je	@@NextLine
	 @@ploop2:
		call	vid_prn_out
		inc	esi
		jmp	short @@ploop1
  	 @@NextLine:
		call	vid_next_ln
		inc	esi
	 	jmp	short @@ploop1
	 @@CheckEnd:
		inc	esi
	 	mov	cl, byte ptr fs:[esi]
	 	cmp	cl, '$'
	 	je	@@ploop2
		pop	esi
		pop	ecx
		pop	eax	
	 	ret
	vid_prn_ln	endp

