	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; COPY_KERNEL : Kopiert VOS9 (Kernel!)
	;	        BOOTCODE und SYSSELECT muá geschrieben sein!
	; Input : -
	; Output: -
	;
	COPY_KERNEL PROC NEAR
		lea	dx, KERNEL_FILE	; Dateiname BootCode
		xor	al, al			; Zugriffsmodus: Nur Lesen
		mov	ah, 3Dh			; DOS: Datei ™ffnen
		int	21h
		jnc	@@DOSHandleOK
		lea	dx, MSG_0044
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
		mov	word ptr ds:[KERNEL_BYTES], ax
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
		mov	ax, word ptr ds:[KERNEL_BYTES]
		div	bx
		; AX enth„lt nun die ben”tigten Bl”cke
		; ist DX>0 muá noch ein Block Addiert werden...

		mov	dword ptr ds:[KERNEL_BLOCKS], eax
		mov	word ptr ds:[KERNEL_SIZE], dx
		cmp	dx, 0
		jz	@@SIZE_OK
		inc	eax
	@@SIZE_OK:	
		mov	dword ptr ds:[KERNEL_TOTAL], eax
		
		lea	dx, MSG_0046
		mov	ah, 9
		int	21h
		
		mov	ax, word ptr ds:[KERNEL_BYTES]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0037
		mov	ah, 9
		int	21h
		lea	dx, MSG_0011
		mov	ah, 9
		int	21h
		mov	eax, dword ptr ds:[KERNEL_TOTAL]
		xor	dx, dx
		call	print32
		lea	dx, MSG_0024
		mov	ah, 9
		int	21h
		lea	dx, MSG_0047
		mov	ah, 9
		int	21h

		; Insgesamt sind si Bytes zu schreiben
		mov	si, word ptr ds:[KERNEL_BYTES]
		; Wir starten an Block eax-1
		mov	eax, 4
		; Das ganze kommt hinter den BOOTCODE und SYSTEM SELECT!
		add	eax, dword ptr ds:[BOOTCODE_TOTAL]
		add	eax, dword ptr ds:[SYSSEL_TOTAL]
		
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
		lea	dx, ds:MSG_0045
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
		mov	eax, dword ptr ds:[KERNEL_BLOCKS]
		mov	bx, word ptr ds:[KERNEL_SIZE]
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

		; Erste Block ist Block 5+ BOOTCODE_TOTAL+SYSSEL_TOTAL

		mov	eax, 5
		add	eax, dword ptr ds:[BOOTCODE_TOTAL]
		add	eax, dword ptr ds:[SYSSEL_TOTAL]
		mov	ebx, dword ptr ds:[KERNEL_TOTAL]
				
		mov	dword ptr es:[STARTPOS_1], eax
		mov	word ptr es:[BLOCKS_1], bx
		mov	dword ptr es:[TOTAL_BLOCKS], ebx

		mov	eax, 2		; Ist Node 2 im Sysdir
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
		mov	bx, 2		; Nr. 2
		mov	dword ptr es:[DATA_BLOCK], eax
		mov	word ptr es:[DATA_SELECT], bx
		
		mov	al, OBJECT_NAME
		mov	byte ptr es:[DATA_TYPE], al

		; Wie nennen wir das?...
		mov	byte ptr es:[DESCRIPTION   ], 'K'
		mov	byte ptr es:[DESCRIPTION+ 1], 'E'
		mov	byte ptr es:[DESCRIPTION+ 2], 'R'
		mov	byte ptr es:[DESCRIPTION+ 3], 'N'
		mov	byte ptr es:[DESCRIPTION+ 4], 'E'
		mov	byte ptr es:[DESCRIPTION+ 5], 'L'
		mov	byte ptr es:[DESCRIPTION+ 6], ' '
		mov	byte ptr es:[DESCRIPTION+ 7], 'I'
		mov	byte ptr es:[DESCRIPTION+ 8], 'M'
		mov	byte ptr es:[DESCRIPTION+ 9], 'A'
		mov	byte ptr es:[DESCRIPTION+10], 'G'
		mov	byte ptr es:[DESCRIPTION+11], 'E'
		mov	byte ptr es:[DESCRIPTION+12], '$'
		
		mov	eax, 2
		call	SET_DIRPOS
		
		mov	eax, 4
		call	WRITE_DATA
		
		; Der Klimbatsch muá nun noch im VIS eingetragen werden!
		mov	ax, SEKTOR_DATA
		mov	es, ax
		mov	eax, 3
		mov	bx, 2
		mov	dword ptr es:[KERNEL_INODE], eax
		mov	word ptr es:[KERNEL_INODE_SELECT], bx
		ret
	COPY_KERNEL ENDP
