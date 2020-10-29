;---------------------------------------------------------------
; ZAHLEN.ASM
;
; Modul untersttzt Ein- und Ausgabe von 32-Bit-Zahlen
; ist nicht allein lauff„hig
;
; im Hauptprogramm deklarieren mittels:
;
; extrn Print32Bit: near
; extrn Read32Bit: near
;
;---------------------------------------------------------------

model	tiny
.286
codeseg
public	Print32Bit, Read32Bit	; als ”ffentlich vereinbaren

Print32Bit	proc	near
	enter	0,0			; Stack-Frame
	mov	dx, [bp+06]
	mov	ax, [bp+04]		; Parameter nach DX:AX
	mov	di, 10			; Teiler ist 10
	xor	cx, cx			; CX z„hlt Stack-Operationen
@Zahlen1:
	xor	bx, bx
	cmp	dx, 0Ah		; LongInt mittels DIV teilbar?
	jc	@Zahlen2		; (Zahl muá kleiner als 100000h sein)
	xchg	ax, bx			; AX -> BX, 0 -> AX
	xchg	ax, dx			; HI-Word nach AX
	div	di			; teilen -> MODULO in DX
	mov	si, ax			; Ergebnis merken
	xchg	ax, bx			; LO-Word zurck
 	div	di			; teilen
	push	dx			; Modulo auf Stack
	inc	cx			; Stackz„hler erh”hen
	mov	dx, si			; Ergebnis von erster Div. zurck
	jmp	short @Zahlen1
@Zahlen2:
	div	di			; teilen
	push	dx			; Modulo auf Stack
	inc	cx			; Stackz„hler erh”hen
	or	ax, ax			; schon fertig?
	jz	@Zahlen3
	xor	dx, dx			; Hi-Word jetzt Null
	jmp	short @Zahlen2
@Zahlen3:
	pop	dx
	or	dx, 48			; Byte -> ASCII
	mov	ah, 02
	int	21h			; Zeichen ausgeben
	loop	@Zahlen3		; CXmal nach @Zahlen3

	leave				; Stack-Frame aufl”sen
	retn	0004			; Parameter vom Stack
Print32Bit	endp

Read32Bit	proc	near
	enter	24,0			; Stack-Frame  (20 Bytes Stringpuffer)
	push	ds
	push	ss
	pop	ds			; DS auf SS umsetzen
	mov	dx, bp			; DX = offset String
	sub	dx, 20
	mov	byte ptr [bp-20], 18 	; 18 Bytes zulassen
	mov	ah, 0Ah
	int	21h			; Funktion: Stringeingabe
	mov	cl, [bp-19]		; Wieviel Bytes eingegeben?
	xor	ch, ch
	mov	bx, cx			; in BX merken
	xor	si, si			; Register SI z„hlt Schleifendurchl„ufe
	xor	ax, ax
	xor	dx, dx
	mov	di, 10			; Mulitplikator
	mov	[bp-24], ax		; bp-24 speichert HI-Wort ab
@Zahlen4:
	mov	cl, [bp+si-18] 	; n„chstes Byte laden
	cmp	cl, '0'
	jc	@Zahlen6		; kleiner als Null
	cmp	cl, '9'
	jg	@Zahlen5		; gr”áer als Neun
 	mul	di			; AX mal 10
 	inc	si			; Z„hler erh”hen
	sub	cl, 48			; ASCII->Byte
	add	al, cl			; zu AL addieren
	adc	ah, 0			; Carry bertragen falls šberlauf
	adc	dx, 0
	mov	[bp-22], ax		; Lo-Wort merken
	mov	ax, [bp-24]		; altes Hi-Wort holen
	mov	cx, dx			; neues Hi-Wort merken
	mul	di			; ax mal 10
	or	dx, dx
	jnz	@Zahlen5		; wenn DX > 0 -> gr”áer als 32 Bit
	add	ax, cx			; altes mit neuem Hi-Wort addieren
	jc	@Zahlen6		; Falls šberlauf -> gr”áer als 32 Bit
	mov	[bp-24], ax		; Hi-Wort merken
	mov	ax, [bp-22]		; Lo-Wort zurckholen
	cmp	si, bx			; alle Zahlen bearbeitet
	jc	@Zahlen4
					; Carry ist Null
@Zahlen6:
	mov	dx, [bp-24]		; Hi-Wort -> DX
	pop	ds			; Segmentregister restaurieren
	leave				; Stack-Frame aufl”sen
	retn
@Zahlen5:
	stc				; Carry setzen
	jmp	short @Zahlen6
Read32Bit	endp

	end


