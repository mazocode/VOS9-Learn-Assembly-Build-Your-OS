;	Project		VOS/9 
;  	File name	VOSBOOT.ASM	02.11.1995
;	File type	Assembly
;	
;  	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		02.11.1995
; 	Release		1		26.11.1995
;	
;  	Autor		Marcus Zoller
;  	
;	Description	VOS/9 Kernel Bootup Code
;
;	Includes	VIO.INC, STRG.INC, DISKIO.INC, REALERR.INC
; 	Message Libs	BOOTERR.MSG
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	System BIOS, Disk BIOS, Video BIOS, Keyboard BIOS
;	
;	Bugfix List 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;	
;	Release Comments 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;	
;	Function Ref 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;

BOOTCODE SEGMENT PARA USE16 'CODE'
        ASSUME CS:BOOTCODE, DS:BOOTCODE
        ORG    0000h
	LOCALS
	.386P        
	IP_JUMP:

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
		mov	ax, 80h			; Ziel Seg 80h
		mov	es, ax
		xor	di, di			; Ziel Offset 0
		mov	cx, offset BOOT_SIZE	; Wir Kopieren alles!
		rep	movsb
	
		; Der Compiler erzeugt den Code nicht richtig! Warum- Bitte Borland
		; Fragen, ...
		
		db	0EAh,26h,00h,80h,00h
	andupulus:
		mov	ax, 80h
		cli
		mov	ds, ax
		mov	es, ax
	  	mov	ss, ax
	  	mov	ax, 9000h
	  	mov	sp, ax
		sti	
	
		mov	byte ptr [BOOT_DRIVE], dl
		mov	word ptr [PART_SEKZYL], bx
		mov	byte ptr [PART_HEADZYL], dh
		
		call	SET_DRIVE_DATA
		call	GET_ADDR_VRAM
		
		; Hallo
		lea	si, MSG_1000
		mov	ah, 0fh
		call	PRINT

		;============================================================
		;
		mov	ah, 0dfh		; A20 freihaun!
		call	gate_a20
		and	al, al			; Alles Roger?
		jz	A20_OK
		mov	ax, 1
		call	ERR_HALT

	A20_OK:
		mov	cx, word ptr [PART_SEKZYL]
		mov	dh, byte ptr [PART_HEADZYL]

		mov	ebx, 2
		call	add_sek			; V1.0 R1

		call	get_sekzyl
		mov	word ptr [VOLUME_START_ZYL], bx
		mov	byte ptr [VOLUME_START_SEK], al
		mov	byte ptr [VOLUME_START_HEAD], dl

		; Nun brauchen wir die Anzahl der Sektoren bis zum Start des
		; Volumes...		
		
		movzx	eax, bx
		xor	edx, edx
		movzx	ebx, byte ptr [DRIVE_SEKS]
		mul	ebx
		xor	edx, edx
		movzx	ebx, byte ptr [DRIVE_HEADS]
		inc	ebx
		mul	ebx
	
		push	eax
	
		movzx	eax, byte ptr [VOLUME_START_SEK]
		dec	eax
		xor	edx, edx
		movzx	ebx, byte ptr [DRIVE_HEADS]
		inc	ebx
		mul	ebx
	
		pop	ebx
	
		add	eax, ebx
		movzx	ebx, byte ptr [VOLUME_START_HEAD]
		inc	ebx
		add	eax, ebx
		dec	eax
	
		mov	dword ptr [VOLUME_START_SEKS], eax

		; Nun brauchen wir die Blockgr붳e, welche im VIS
		; gesichert ist. Der VIS ist Block 2 (Addr. 1) des
		; Volumes...
				
	@@ReadVIS:
		mov	cx, word ptr [PART_SEKZYL]
		mov	dh, byte ptr [PART_HEADZYL]
		mov	ebx, 1
		call	ADD_SEK
		mov	ax, 1000h
		mov	es, ax
		xor	bx, bx
		mov	dl, byte ptr [BOOT_DRIVE]
		call	READ
		jc	LOAD_FAIL
		
		; Aus dem VIS brauchen wir nun die Blockgr붳e.
		; Offset: 0, Gr붳e: 1 Byte
		mov	ax, 1000h
		mov	es, ax
		xor	bx, bx
		xor 	ax, ax
		mov	al, byte ptr es:[bx]
		; Sollte die Blockgr붳e 0 sein, enth꼕t ein Block = 1 Sektor
		cmp	ax, 0
		je	@@ZeroSize
		; Ansonsten sind es 2 Sektoren je Blockfaktor
		mov	bx, 2
		xor	dx, dx
		mul	bx
		jmp	short @@SetSekSize
	@@ZeroSize:
		mov	al, 1
	@@SetSekSize:
		mov	byte ptr [SEKS_PER_BLOCK], al
				
	; DER BOOTMANAGER...		
		mov	ax, 1000h
		mov	es, ax
		; INODE Eintrag an Offset 31
		mov	bx, 31
		mov	eax, dword ptr es:[bx]
		; Ist der Bootmanager 갶erhaupt installiert?
		cmp	eax, 0
		jne	BOOTMAN_DATA
		mov	word ptr [BOOTMAN_SEKZYL], ax
		mov	byte ptr [BOOTMAN_HEADZYL], al
		mov	byte ptr [BOOTMAN_SEKSIZE], al
		jmp	KERNEL_DATA		

	BOOTMAN_DATA:
		call	get_physical

		mov	ax, 1200h
		mov	es, ax
		xor	ax, ax
		xor	bx, bx
		mov	dl, byte ptr [BOOT_DRIVE]
		mov	al, byte ptr [SEKS_PER_BLOCK]
		call	READ_SEKTORS
		jc	Load_Fail	
		
		; Die Frage: Welcher der Inodes wird gebraucht - Steht eben
		; falls im VIS an Offset 35
		mov	ax, 1000h
		mov	es, ax
		mov	bx, 35
		mov	ax, word ptr es:[bx]
		
		; Jeder Inode-Eintrag ben봳igt 128 Byte
		mov	bx, 128
		xor	dx, dx
		mul	bx
		mov	bx, ax
		mov	ax, 1200h
		mov	es, ax

		; Aus dem Inode brauchen wir den Start-Block-
		; steht an Offset 56
		add	bx, 56
		push	bx
		mov	eax, dword ptr es:[BX]
		call	get_physical
		mov	word ptr [BOOTMAN_SEKZYL], cx
		mov	byte ptr [BOOTMAN_HEADZYL], dh
		pop	bx
		; Nun noch die Preisfrage: Wieviele Sekt. sind zu lesen?
		add	bx, 4
		mov	ax, word ptr es:[bx]
		xor	bx, bx
		mov	bl, byte ptr [SEKS_PER_BLOCK]
		xor	dx, dx
		mul	bx
		mov	byte ptr [BOOTMAN_SEKSIZE], al

	KERNEL_DATA:
		mov	ax, 1000h
		mov	es, ax
		; INODE Eintrag an Offset 37
		mov	bx, 37
		mov	eax, dword ptr es:[bx]
		cmp	eax, 0
		jne	KERNEL_PRESENT
		mov	word ptr [KERNEL_SEKZYL], ax
		mov	byte ptr [KERNEL_HEADZYL], al
		mov	byte ptr [KERNEL_SEKSIZE], al
		jmp	CHECK_TOBOOT
		
	KERNEL_PRESENT:
		; Nun brauchen wir die physikalische Position
		call	get_physical
		mov	ax, 1200h
		mov	es, ax
		xor	ax, ax
		xor	bx, bx
		mov	dl, byte ptr [BOOT_DRIVE]
		mov	al, byte ptr [SEKS_PER_BLOCK]

		; Inode herbeihacken!
		
		call	READ_SEKTORS
		jc	Load_Fail		; And it takes me away...Uzuz

		; Welcher Indoe steht im VIS an Pos 41
		mov	ax, 1000h
		mov	es, ax
		mov	bx, 41
		mov	ax, word ptr es:[bx]
		
		; Jeder Inode-Eintrag ben봳igt 128 Byte
		mov	bx, 128
		xor	dx, dx
		mul	bx
		mov	bx, ax
		mov	ax, 1200h
		mov	es, ax
		; Aus dem Inode brauchen wir den Start-Block-
		; steht an Offset 56
		add	bx, 56
		push	bx
		mov	eax, dword ptr es:[BX]
		call	get_physical
		mov	word ptr [KERNEL_SEKZYL], cx
		mov	byte ptr [KERNEL_HEADZYL], dh
		pop	bx
		; Nun noch die Preisfrage: Wieviele Sekt. sind zu lesen?
		add	bx, 4
		mov	ax, word ptr es:[bx]
		xor	bx, bx
		mov	bl, byte ptr [SEKS_PER_BLOCK]
		xor	dx, dx
		mul	bx
		mov	word ptr [KERNEL_SEKSIZE], ax
		jmp	CHECK_TOBOOT
		
	LOAD_FAIL:
		mov	ax, 3
		call	ERR_HALT
		
	CHECK_TOBOOT:
		; 11.10.95: Wir sehen nun im Master-Code nach, ob der 
		; Bootmanager gew걆scht wurde.
		; 
		mov	ax, 060h
		mov	es, ax
		mov	bx, 1bbh
		cmp	byte ptr es:[bx], 0ffh
		je	BOOT_SYSSELECT
		jmp	BOOT_KERNEL
			
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; BOOTKERNEL : Bereitet den Start des Kernels vor...
	; Input : -
	; Output: -
	;
	BOOT_KERNEL PROC NEAR
		; With a little smile on your face the world is changing...
		
		; Kernel auch vorhanden?
		cmp	byte ptr [KERNEL_SEKSIZE], 0
		je	@@NixKernel

		; It's the blues that makes you move... Der Kernel
		; wird gnadenlos in den RAMULUS TOTALUS gehackt!
		
		lea	si, MSG_1001
		mov	ah, 0fh
		call	PRINT
		
		call	GET_CURPOS
		sub	dl, 2
		call	SET_CURPOS
		xor	al, al
		mov	byte ptr [SYMPOS], al		

		mov	ax, 200h		; Start Segaddr. = Seite 1
		mov	es, ax
		xor	bx, bx			; Start Offset
					
		mov	di, word ptr [KERNEL_SEKSIZE]	; Sektoren zu lesen
		
		mov	cx, word ptr [KERNEL_SEKZYL]
		mov	dh, byte ptr [KERNEL_HEADZYL]

	@@ReadLoop:
		push	ax bx cx dx di es
		lea	bx, SYMBOLIC
		movzx	ax, byte ptr [SYMPOS]
		add	bx, ax
		mov	ah, 0fh
		mov	al, byte ptr [bx]
		call	PRINT_CHAR
		call	GET_CURPOS
		dec	dl
		call	SET_CURPOS
		mov	al, byte ptr [SYMPOS]
		cmp	al, 3
		je	@@FirstSym
		inc	al
		jmp	short @@SetSym
	@@FirstSym:
		xor	al, al
	@@SetSym:
		mov	byte ptr [SYMPOS], al
		pop	es di dx cx bx ax
		
		mov	dl, byte ptr [BOOT_DRIVE]
		call	READ
		jc	Load_Fail

		push	bx
		mov	ebx, 1
		call	ADD_SEK
		pop	bx
		
		dec	di
		cmp	di, 0
		jne	@@ReadLoop

		mov	cx, word ptr [PART_SEKZYL]
		mov	dh, byte ptr [PART_HEADZYL]
		mov	dl, byte ptr [BOOT_DRIVE]

		db	0EAh,00h,00h,0C0h,01h		

	@@NixKernel:
		mov	ax, 4
		call	ERR_HALT		
	BOOT_KERNEL ENDP
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; BOOT_SYSSELECT: Laden des Bootmanager "System Select"
	; Input : -
	; Output: -
	;
	BOOT_SYSSELECT PROC NEAR
		mov	ax, 060h
		mov	es, ax
		mov	bx, 1bbh
		xor	ax, ax
		mov	byte ptr es:[bx], al
		mov	ax, 1000h
		mov	es, ax
		xor	bx, bx
		xor	ax, ax
		mov	al, byte ptr [BOOTMAN_SEKSIZE]
		mov	cx, word ptr [BOOTMAN_SEKZYL]
		mov	dh, byte ptr [BOOTMAN_HEADZYL]
		mov	dl, byte ptr [BOOT_DRIVE]
		call	READ_SEKTORS
		jc	Load_Fail
		; Wir haben alles!
		; Und ab...
		mov	dl, byte ptr [BOOT_DRIVE]
		mov	cx, word ptr [BOOTMAN_SEKZYL]
		mov	dh, byte ptr [BOOTMAN_HEADZYL]
		xor	bx, bx
		mov	bl, byte ptr [BOOTMAN_SEKSIZE]
		
		db	0EAh,00h,00h,00h,10h
	BOOT_SYSSELECT ENDP
	
	;============================================================
        VOLUME_START_ZYL	dw	0	; Vol. Start Zylinder
	VOLUME_START_SEK	db	0	; Vol. Start Sektor
	VOLUME_START_HEAD	db	0	; Vo. Start Kopf
	VOLUME_START_SEKS	dd	0	; Anz. Sekt. bis Start
		
	SEKS_PER_BLOCK		db	0	; Anz. Sekt. je Block
	
	; System-Meldungen
	MSG_1000	db 	'Lade VOS/9...$'
	MSG_1001	db	'[ ]$'
	
	SYMBOLIC	db	'|/�\'
	SYMPOS		db	0
		
	BOOTMAN_SEKZYL	dw	0
	BOOTMAN_HEADZYL	db	0
	BOOTMAN_SEKSIZE	db	0

	KERNEL_SEKZYL	dw	0
	KERNEL_HEADZYL	db	0
	KERNEL_SEKSIZE	dw	0
				
	PART_SEKZYL	dw	0
	PART_HEADZYL	db	0
	
	BOOT_DRIVE	db	0
	
	;============================================================
		
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; GET_PHYSICAL: Berechnet aus einer Linearen Adresse die phys.
	;		Position auf dem Datentr꼏er, abh꼗gig von der 
	;		Blockgr붳e
	; 
	; Input:	EAX = Lieneare Adrsesse
	; Output:	CX = SekZyl, DH=ZylHead
	;
	GET_PHYSICAL PROC NEAR
		; Zun꼊hst berechnen wir aus der Linearen Adresse die Anzahl 
		; der Sektoren...
	
		movzx	ebx, byte ptr [SEKS_PER_BLOCK]
		xor	edx, edx
		mul	ebx
	
		mov	ebx, dword ptr [VOLUME_START_SEKS]
		add	eax, ebx
	
		; Nun m걌sen wir berechnen, welcher Zylinder, Sektor, Kopf
		; EAX= Logische Real Adresse
	
		push	eax			; Adresse merken
	
		movzx	ebx, byte ptr [DRIVE_HEADS]
		inc	ebx
		xor	edx, edx
		div	ebx
		movzx	ebx, byte ptr [DRIVE_SEKS]
		xor	edx, edx
		div	ebx
	
		push	eax			; Zylinder !
		
		xor	edx, edx
		movzx	ebx, byte ptr [DRIVE_SEKS]
		mul	ebx
		xor	edx, edx
		movzx	ebx, byte ptr [DRIVE_HEADS]
		inc	ebx
		mul	ebx
	
		pop	ebx			; Zyl holen
		pop	edx			; Adresse holen
		push	ebx			; Zyl zur갷k
		push	edx			; Adresse zur갷k
	
		sub	edx, eax
	
		push	edx			; REST merken !
	
		mov	eax, edx
		xor	edx, edx
		movzx	ebx, byte ptr [DRIVE_HEADS]
		inc	ebx
		div	ebx
		inc	eax
	
		push	eax			; SEKTOR merken !

		xor	edx, edx
		dec	eax
		movzx	ebx, byte ptr [DRIVE_HEADS]
		inc	ebx
		mul	ebx

		pop	edx			; SEKTOR holen

		pop	ebx			; REST holen
		sub	ebx, eax
	
		xor	eax, eax
		mov	al, dl
		xor	edx, edx
		mov	dl, bl
		
		pop	ebx			; Adresse zum M걄l
		xor	ebx, ebx
		pop	ebx			; Zylinder holen
	
		call	set_sekzyl	
		ret	
	GET_PHYSICAL ENDP

        ;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
        ; READ_SEKTORS: Liest einen Sektor oder mehrere Sektoren
        ; Input : es:bx = seg/off Buffer
        ;         cx = SekZyl
        ;         dh = HeadZyl
        ;	  dl = Laufwerk
        ;	  al = Anzahl Sektoren
        ; Output: Carry 1 = Failed
        ;
        READ_SEKTORS PROC NEAR
	@@Read_Loop:
		push	ax
		call	READ
		jc	@@Failed
		pop	ax
		dec	al
		cmp	al, 0
		je	@@IstOK
		mov	ah, dl		; Laufwerk sichern
		push	bx		; Offset
		push	ax
		mov	ebx, 1
		call	ADD_SEK
		pop	ax		
		mov	dl, ah		; Laufwerk zur갷k
		pop	bx		; Offset Zur갷k
		jmp	@@Read_Loop
	@@IstOK:
		clc
		ret
	@@Failed:
		pop	ax
		stc
		ret				
        READ_SEKTORS ENDP

        ;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
        ; WRITE_SEKTORS: Schreibt einen Sektor oder mehrere Sektoren
        ; Input : es:bx = seg/off Buffer
        ;         cx = SekZyl
        ;         dh = HeadZyl
        ;	  dl = Laufwerk
        ;	  al = Anzahl Sektoren
        ; Output: Carry 1 = Failed
        ;
        WRITE_SEKTORS PROC NEAR
	@@Read_Loop:
		push	ax
		call	READ
		jc	@@Failed
		pop	ax
		dec	al
		cmp	al, 0
		je	@@IstOK
		mov	ah, dl		; Laufwerk sichern
		push	bx		; Offset
		push	ax
		mov	ebx, 1
		call	ADD_SEK
		pop	ax		
		mov	dl, ah		; Laufwerk zur갷k
		pop	bx		; Offset Zur갷k
		jmp	@@Read_Loop
	@@IstOK:
		clc
		ret
	@@Failed:
		pop	ax
		stc
		ret		
        WRITE_SEKTORS ENDP


	include	..\bios\vio.inc			; Video Functions
	include ..\bios\diskio.inc		; Disk I/O Functions
	include ..\bios\strg.inc		; String Functions
	include ..\err\realerr.inc		; Fatal ERROR Handling
	include ..\msgs\german\booterr.msg	; ERROR LIBRARY
	include ..\ports\gatea20.inc		; GATE A20 Handling
	include ..\ports\ports.def		; PORT Definitions
			
	BOOT_SIZE LABEL WORD
BOOTCODE ENDS
end IP_JUMP