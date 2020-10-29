;	Project		VOS/9 
;  	File name	SYS_SEL.ASM	24.11.1995
;	File type	Assembly
;	
;  	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		24.11.1995
; 	Release		0		24.11.1995
;	
;  	Autor		Marcus Zoller
;  	
;	Description	SYSTEM SELECT
;
;	Includes	VIO.INC, STRG.INC, DISKIO.INC
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	System BIOS, Disk BIOS, Video BIOS, Keyboard BIOS
;	
;	Bugfix List ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	
;	Release Comments ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	
;	Function Ref ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;

SYS_SEL SEGMENT PARA USE16 'CODE'
	assume	cs:sys_sel, ds:sys_sel
	org	0000h
	.386P
	LOCALS
	
	;====================================================================
	STARTUP_IP:		
		mov	ax, 1000h
		cli
		mov	ds, ax
		mov	es, ax
	  	mov	ss, ax
	  	mov	ax, 9000h
	  	mov	sp, ax
		sti	

		mov	word ptr cs:[BOOTMAN_SEKS], bx
		mov	word ptr cs:[BOOTMAN_SEKZYL], cx
		mov	byte ptr cs:[BOOTMAN_HEADZYL], dh
		mov	byte ptr cs:[BOOT_DRIVE], dl	

		call	SET_DRIVE_DATA

		; OS/2 ben”tigt Spezialbehandlung. Wir OS/2 mit einem
		; FAT FS eingerichtet und es ist noch eine andere Prim. FAT
		; Partition vorhanden, versteckt sich OS/2. Sollten wir 
		; unter diesen Bedingungen zuvor eine OS/2 Part gestartet 
		; haben, ist KEY_BACKUP>0 und im MBR wurde Autostart 
		; eingestellt. Wir setzen dann alles wie zuvor, verstecken
		; OS/2 wieder und lassen werden den MBR neu Starten!
		
		cmp	word ptr cs:[KEY_BACKUP], 0
		je	@@SYSSEL

		; Zun„chst verstecken wir OS/2 wieder...
		
		mov	ax, 7c0h
		mov	es, ax
		xor	bx, bx
		xor	dh, dh
		mov	dl, byte ptr cs:[BACKUP_DRIVE]
		mov	cx, 1
		call	READ
		jc	@@STARTUP_FAILED
		mov	bx, word ptr cs:[BACKUP_PART]
		mov	byte ptr es:[bx+4], 16h		; OS/2 Typ 16h
		xor	bx, bx
		call	WRITE
		jc	@@STARTUP_FAILED
		
		; Nun mssen wir alle Einstellungen wiederherstellen

		xor	ax, ax
		mov	word ptr cs:[BACKUP_PART], ax
		mov	byte ptr cs:[BACKUP_DRIVE], al
		mov	bx, word ptr cs:[KEY_BACKUP]
		mov	word ptr cs:[BOOTMAN_KEY], bx
		mov	word ptr cs:[KEY_BACKUP], ax
				
		; Und die Konfig. zurckschreiben!
		call	WRITE_CFG
		jc	@@STARTUP_FAILED

		; Nun noch den MBR neu laden!

		mov	ax, 7c0h
		mov	es, ax
		xor	bx, bx
		xor	dh, dh
		mov	dl, 80h
		mov	cx, 1
		call	READ
		jc	@@STARTUP_FAILED
		call	CLEAR
		db	0eah,00h,7ch,00h,00h

	@@STARTUP_FAILED:
		; Hier kommen wir an, wenn der irgend etwas beim Starten 
		; schiefgegangen ist - sprich ein Lese/Schreib Fehler!

		call	CLEAR
		jmp	short $
						
	@@SYSSEL:
		; Zun„chst ben”tigen wir die Aufruf-Taste. Wir holen Sie
		; aus dem MBR, welcher sich zur Zeit noch im RAM an 
		; 060h:0 befindet.
		
		mov	ax, 060h
		mov	es, ax
		mov	bx, 1bch		; Position der Taste!
		mov	ax, word ptr es:[bx]
		mov	word ptr cs:[BOOTMAN_KEY], ax
	
		call	BUILD_SCREEN		; Die elementare Optik!
						;     ^-- sch”nes Wort!
		
		cmp	byte ptr cs:[PASSWORT_STATUS], 2
		jne	@@START
	@@NeedPass:
		call	GET_PASS
		jc	@@NeedPass	
	@@START:
		call	CLEAR_FRAME
		; Das Laufwerk mit der Primary-Part wird als Default
		; angezeigt!
		call	GET_PRIMARY
		jmp	BOOTMANAGER
		
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; BOOTMANAGER: Gibt dem Benutzer die m”glichkeit eine andere Partition
	;              zum Starten auszuw„hlen
	; Input	: -
	; Output: -
	;	
	BOOTMANAGER PROC NEAR
		mov	dh, 5
		mov	dl, 21
		push	dx		
	@@Redraw:		
		call	CLEAR_FRAME
		mov	si, offset cs:MSG_0003
		call	SHOW_INFO
		mov	dh, 4
		mov	dl, 65
		call	SET_CURPOS
		lea	si, cs:MSG_1027
		mov	ah, 1fh
		call	PRINT
		mov	dl, byte ptr cs:[CURRENT_DRIVE]
		call	SHOW_TABEL
		; Nun noch den Arrow auf den ersten Eintrag
		pop	dx
		push	dx
		call	set_curpos
		lea	si, cs:MSG_1031
		mov	ah, 70h
		call	PRINT
		mov	dh, 5
		mov	dl, 62
		call	set_curpos
		xor	ax, ax
		mov	al, byte ptr cs:[PRIMARY_TIMEOUT]
		inc	al
		mov	word ptr cs:[TIMING], ax
		cmp	al, 1
		jne	@@TimeActive
		lea	si, cs:MSG_1032
		mov	ah, 1fh
		call	PRINT
		jmp	@@WaitKey
	@@TImeActive:
		lea	si, cs:MSG_1028		
		mov	ah, 1fh
		call	PRINT
	@@WaitKey:
		cmp	byte ptr cs:[PRIMARY_TIMEOUT], 0
		jne	@@DecTimeout
	@@Wait_noTime:
		mov	ah, 1
		int	16h
		jz	@@WaitKey
		xor	ax, ax
		int	16h
		cmp	al, 0
		je	@@NonASC
		cmp	al, 13
		je	@@BootThis
		jmp	@@WaitKey	
	@@NonASC:
		cmp	ah, 61			; F3
		je	@@Options
		cmp	ah, 48h			; UP
		je	@@MoveUp
		cmp	ah, 50h			; DOWN
		je	@@MoveDown
		cmp	dh, 4bh			; LEFT
		je	@@DriveLeft		
		cmp	dh, 4dh			; RIGHT
		je	@@DriveRight
		jmp	@@WaitKey
	@@BootThis:
		pop	dx
		push	dx
		mov	ax, 10h
		xor	bx, bx
		mov	bl, dh
		sub	bl, 5
		xor	dx, dx
		mul	bx
		add	ax, 1beh
		mov	bx, ax
		mov	dl, byte ptr cs:[CURRENT_DRIVE]
		call	BOOT_PART
		jmp	@@WaitKey
	@@DriveLeft:
		mov	dl, byte ptr cs:[CURRENT_DRIVE]
		cmp	dl, 80h
		je	@@WaitKey
		dec	dl
		call	SHOW_TABEL
		jc	@@WaitKey
		mov	dl, byte ptr cs:[CURRENT_DRIVE]
		dec	dl
		jmp	@@NewTabel
	@@DriveRight:
		mov	dl, byte ptr cs:[CURRENT_DRIVE]
		inc	dl
		call	SHOW_TABEL
		jc	@@WaitKey
		mov	dl, byte ptr cs:[CURRENT_DRIVE]
		inc	dl
	@@NewTabel:
		mov	byte ptr cs:[CURRENT_DRIVE], dl
		pop	dx
		jmp	@@SetPos
	@@MoveUp:
		pop	dx
		push	dx
		call	set_curpos
		mov	cx, 2
		mov	ah, 70h
		mov	al, ' '
		call	PRINT_LOOP
		pop	dx		
		cmp	dh, 5
		je	@@LastPos
		dec	dh
		jmp	short @@SetPos	
	@@LastPos:
		mov	dh, 8
		jmp	short @@SetPos
	@@MoveDown:
		pop	dx
		push	dx
		call	set_curpos
		mov	cx, 2
		mov	ah, 70h
		mov	al, ' '
		call	PRINT_LOOP
		pop	dx		
		cmp	dh, 8
		je	@@FirstPos
		inc	dh
		jmp	short @@SetPos	
	@@FirstPos:
		mov	dh, 5
		jmp	short @@SetPos
	@@SetPos:
		push	dx
		call	set_curpos
		lea	si, cs:MSG_1031
		mov	ah, 70h
		call	PRINT
		jmp	@@WaitKey
			
	@@Options: 
		call	BOOTMAN_OPTS
		jmp	@@Redraw		; Konfig. neu Lesen
		
	@@DecTimeout:
		; Wir verwenden zur komp. nicht die Wait-Event Funk.
		; da diese von einigen PS/2s nicht untersttzt wird!
		mov	ah, 2
		int	1Ah
		jc	@@DecTimeout
		; DH h„lt die Sekunden in BCD
		mov	ax, word ptr cs:[TIMING]
		cmp	ah, dh
		je	@@Wait_noTime
		mov	ah, dh
		dec	al
		cmp	al, 0
		je	@@AutoBoot
		mov	word ptr cs:[TIMING], ax
		; Wir zeigen noch die verbleibende Zeit an...
		push	ax
		mov	dh, 5
		mov	dl, 66
		call	set_curpos
		pop	ax
		push	ax
		cmp	al, 9
		jg	@@SetTOK
		mov	ah, 1fh
		mov	al, ' '
		call	print_char
	@@SetTOK:
		pop	ax
		mov	bl, al
		mov	ah, 1fh
		call	PRINT_ZAHL
		jmp	@@Wait_noTime
	@@AutoBoot:
		mov	dl, byte ptr cs:[PRIMARY_DRIVE]
		mov	bx, word ptr cs:[PRIMARY_PART]
		call	BOOT_PART
		jmp	@@Redraw		; Nur bei Fehler!
	BOOTMANAGER ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SHOW_TABEL: Zeigt den Inhalt der Partitionstabelle
	; Input : DL = Laufwerk
	; Output: CF = Laufgwerk existiert nicht oder defekt
	;
	SHOW_TABEL PROC NEAR
		; Zun„chst holen wir die Tabelle!
		mov	cx, 1
		xor	dh, dh
		xor	bx, bx
		mov	ax, 7c0h
		mov	es, ax
		call	READ
		jc	@@Fehler
		; Alles Roger - Wir zeigen zun„chst welche Platte!
		push	dx
		mov	dh, 4
		mov	dl, 5
		call	set_curpos
		lea	si, cs:MSG_1030
		mov	ah, 1fh
		call	PRINT
		mov	dh, 5
		mov	dl, 9
		call	set_curpos
		pop	dx
		sub	dl, 7Fh
		mov	bl, dl
		mov	ah, 1fh
		call	PRINT_ZAHL
		; Nun basteln wir einen Kasten in den sowas wien Titel
		; und der Text reinpasst...
		mov	ah, 4
		mov	al, 19
		mov	bh, 9
		mov	bl, 59
		call	DRAW_BOX
		mov	bx, 1beh
		mov	ax, 7c0h
		mov	es, ax
		mov	dh, 5
		mov	dl, 26
		push	es
		push	bx
	@@PartLoop:
		push	dx
		call	set_curpos
		pop	dx
		pop	bx
		pop	es
		mov	ah, 70h
		mov	al, byte ptr es:[bx+4]
		cmp	byte ptr es:[bx], 80h
		jne	@@Normal
		mov	ah, 74h
	@@Normal:
		push	es
		push	bx
		push	dx
		call	SHOW_PARTNAME
		pop	dx
		inc	dh
		pop	bx
		cmp	bx, 1eeh
		je	@@Roger
		add	bx, 10h
		push	bx
		jmp	@@PartLoop
	@@Roger:
		pop	es
		clc
		ret
	@@Fehler:
		stc
		ret
	SHOW_TABEL ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; BOOT_PART: Bootet von einer Partition
	; Input : DL = Laufwerk, BX = Offset Part-Eintrag
	; Output: - (rckkehr bei Fehler)
	;
	; Problem mit OS/2: OS/2 "versteckt" sich als Typ 16h und l„át sich
	; damit nicht starten (Nut bei FAT Dateisys). Der Typ muá also
	; zuvor wieder auf 6h gesetzt werden!
	;
	BOOT_PART PROC NEAR
		; Zun„chst holen wir die Part-Tabelle des Laufwerks
		push	bx		; Offset merken!
		mov	ax, 7c0h
		mov	es, ax
		xor	bx, bx
		xor	dh, dh
		mov	cx, 1
	@@ReadTab:
		call	READ
		jc	@@ReadTab
		
		pop	bx
		cmp	byte ptr es:[bx+4], 0
		jne	@@CheckOS2
		stc
		ret
	@@CheckOS2:
		cmp	byte ptr es:[bx+4], 16h
		jne	@@Boot
		mov	al, 6h
		mov	byte ptr es:[bx+4], al
		push	bx
		xor	bx, bx
		xor	dh, dh
		mov	cx, 1
	@@WriteTab:
		mov	ax, 0301h			
		int	13h
		jc	@@WriteTab
		pop	bx
		mov	ax, word ptr cs:[BOOTMAN_KEY]
		mov	word ptr cs:[KEY_BACKUP], ax
		mov	ax, 0ffffh
		mov	word ptr cs:[BOOTMAN_KEY], ax
		mov	word ptr cs:[BACKUP_PART], bx
		mov	byte ptr cs:[BACKUP_DRIVE], dl
		push	bx
		push	dx
	@@CFGFail:
		call	WRITE_CFG
		jc	@@CFGFail		
		pop	dx
		pop	bx
	@@Boot:
		mov	ax, 7c0h
		mov	es, ax
		mov	cx, word ptr es:[bx+2h]
		mov	dh, byte ptr es:[bx+1h]
		xor	ax, ax
		mov	es, ax
		mov	bx, 7c00h
		push	cx
		push	dx
	@@ReadCode:	
		call	READ
		jc	@@ReadCode
		call	CLEAR
		pop	dx
		pop	cx
		; UND AB!
		db	0eah,00h,7ch,00h,00h
	BOOT_PART ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; WRITE_CFG: Schreibt den gesamten Code zurck! (ACHTUNG! ben”tigt
	;            die vom BOOTMANAGER geladenen Daten aus dem Bootstrap!)
	; Input : -
	; Output: - (abbruch bei Fehler)!
	;
	WRITE_CFG PROC NEAR
		mov 	ax, 1000h	; Hier befinden wir uns!
		mov 	es, ax
		xor	bx, bx
		mov 	dh, byte ptr cs:[BOOTMAN_HEADZYL] ; Kopf Part start  
		mov 	cx, word ptr cs:[BOOTMAN_SEKZYL]  ; Zylinder/Sektor Part start 
		mov	ax, word ptr cs:[BOOTMAN_SEKS] ; Anzal zu les. Sektoren
		mov	dl, byte ptr cs:[BOOT_DRIVE]
		call	WRITE_SEKTORS
		jc	@@Failed
		; Wir laden den MBR neu, falls was ge„ndert wurde!
		mov	ax, 060h
		mov	es, ax
		xor	bx, bx
		mov	dx, 80h
		mov	cx, 1
		mov	ax, 1
		call	READ_SEKTORS
		jc	@@Failed
		mov	ax, 60h
		mov	es, ax
		mov	bx, 1bch
		mov	ax, word ptr cs:[BOOTMAN_KEY]
		mov	word ptr es:[bx], ax
		dec	bx
		xor	al, al
		mov	byte ptr es:[bx], al
		; und das ganze zurckschreiben!
		mov	ax, 060h
		mov	es, ax
		xor	bx, bx
		mov	dx, 80h		; Platte 0, Kopf 0
		mov	cx, 1		; Sektor 1, Zylinder 0
		mov	ax, 1		; 1 Sektor schreiben!
		call	WRITE_SEKTORS
		ret
	@@Failed:
		stc
		ret
	WRITE_CFG ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ	
	; GET_PASS: Abfrage des Master-Passwortes
	; Input : -
	; Output: Carry = Abbruch (ESC)
	;
	GET_PASS PROC NEAR
		lea	si, cs:MSG_0001
		call	SHOW_INFO
		
	@@RestartPass:
		mov	al, 22
		mov	ah, 7
		mov	bl, 60
		mov	bh, 11
		call	DRAW_BOX		
		mov	dh, 9
		mov	dl, 26
		call	set_curpos
		lea	si, cs:MSG_1026
		mov	ah, 70h
		call	PRINT
		mov	dh, 9
		mov	dl, 36
		lea	bx, cs:PASSINPUT
		mov	byte ptr cs:[bx], '$'
		mov	byte ptr cs:[bx+1], ' '
		push	dx
	@@In_loop:
		xor	ax, ax
		int	16h
		cmp	al, 0
		je	@@In_Loop
		cmp	al, 13
		je	short @@CheckPass
		cmp	al, 8h
		je 	short @@Delete
		cmp	al, 27
		je	short @@DochNicht
		pop	dx
		push	dx
		sub	dl, 36
		cmp	dl, 8
		je	@@In_Loop
		lea	bx, cs:PASSINPUT
		pop	dx
		inc	dl
		push	dx
		xor	dh, dh
		sub	dl, 37
		add	bx, dx
		mov	byte ptr cs:[bx], al
		mov	byte ptr cs:[bx+1], '$'
		mov	ah, 74h
		mov	al, '*'
		call	PRINT_CHAR
		jmp	short @@In_loop
	@@Delete:
		pop	dx
		push	dx
		cmp	dl, 36
		je	@@In_Loop
		pop	dx
		dec	dl
		push	dx
		xor	dh, dh
		lea	bx, cs:PASSINPUT
		add	bx, dx
		mov	byte ptr cs:[bx], '$'
		pop	dx
		push	dx
		call	set_curpos
		mov	ah, 70h
		mov	al, ' '
		call	PRINT_CHAR
		pop	dx
		push	dx
		call	set_curpos
		jmp	@@In_Loop
	@@CheckPass:
		pop	dx
		lea	si, cs:PASSWORT
		lea	di, cs:PASSINPUT
		call	COMPARE
		jnc	@@RestartPass
		clc
		ret	
	@@DochNicht:
		pop	dx
		stc
		ret		
	GET_PASS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; GET_PRIMARY: Sucht nach der Default-Partition
	; Input : -
	; Output: -
	;
	GET_PRIMARY PROC NEAR
		push	ax bx cx dx 
		; Prinzip: Wir durchsuchen nun alle Laufwerke, bis wir
		; einen Partition vom Typ BOOT gefunden haben. Sollten
		; wir keine gefunden haben, stellen wir die Timeout-Zeit
		; auf Null und zeigen "KEINE" an.
	@@Faul:	
		mov	dl, 80h		; 1. HD
		mov	ax, 7c0h
		mov	es, ax
		mov	cx, 1		; Sektor 1, Zylinder 0
		xor	dh, dh		; Kopf 0
		xor	bx, bx

	@@SearchLoop:
		call	READ
		jc	@@Faul

		; Nun mssen wir Suchen, ob was sch”nes fr uns dabei ist!
		mov	bx, 1beh

	@@CheckLoop:
		cmp	byte ptr es:[bx], 80h		; Bootbar ?
		jne	@@NextEntry
		cmp	byte ptr es:[bx+4], 0		; Belegt?
		je	@@NextEntry
		mov	word ptr cs:[PRIMARY_PART], bx
		mov	byte ptr cs:[PRIMARY_DRIVE], dl
		mov	byte ptr cs:[CURRENT_DRIVE], dl
		pop	dx cx bx ax
		ret

	@@NextEntry:
		cmp	bx, 1feh
		je	@@NextDrive
		add	bx, 10h
		jmp	@@CheckLoop

	@@NextDrive:
		inc	dl
		xor	bx, bx		
		jmp	@@SearchLoop
	GET_PRIMARY ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SHOW_PARTNAME: Anzeigen eines Namens fr eine Partition 
	;              
	; Input : ah = Farbattribut, al = TYP
	;
	; Output: -
	;
	SHOW_PARTNAME PROC NEAR	
		lea	si, ds:DATABASE_START
		lea	bx, ds:DATABASE_END
	@@Suchen:
		mov	dl, byte ptr ds:[si]
		cmp	dl, al
		je	@@Gefunden
		add	si, 32		; 1 Eintrag = 22 Byte
		cmp	si, bx
		jne	@@Suchen
		push	ax
		lea	si, MSG_1029
		call	PRINT
		pop	ax
		mov	bl, al
		call	PRINT_ZAHL
		ret
	@@Gefunden:
		inc	si
		call	PRINT
		ret
	SHOW_PARTNAME ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; BOOTMAN_OPTS: ndern der Optionen des Boot-Managers...
	; Input : -
	; Output: -
	;
	BOOTMAN_OPTS PROC NEAR
		call	CLEAR_FRAME
		cmp	byte ptr cs:[PASSWORT_STATUS], 1
		jne	@@Restart_Bootman
		call	GET_PASS
		jnc	@@Restart_Bootman
		ret
	@@Restart_Bootman:
		mov	al, 20
		mov	ah, 4
		mov	bl, 62
		mov	bh, 12
		call	DRAW_BOX		
		lea	si, cs:MSG_0002
		call	show_info
		
		mov	dh, 5		; Y
		mov	dl, 24		; X
		call	set_curpos
		lea	si, cs:MSG_1004
		mov	ah, 71h
		call	PRINT
		mov	dh, 7
		mov	dl, 22
		call	set_curpos
		lea	si, cs:MSG_1008		
		mov	ah, 70h
		call	PRINT
		mov	dh, 8
		mov	dl, 22
		call	set_curpos
		lea	si, cs:MSG_1009
		mov	ah, 70h
		call	PRINT
		mov	dh, 9
		mov	dl, 22
		call	set_curpos
		lea	si, cs:MSG_1010
		mov	ah, 70h
		call	PRINT
		mov	dh, 9
		mov	dl, 50
		call	set_curpos
		lea	si, cs:MSG_1007
		mov	ah, 70h
		call	PRINT
		mov	dh, 10
		mov	dl, 22
		call	set_curpos
		lea	si, cs:MSG_1021
		mov	ah, 70h
		call	PRINT
		mov	dh, 11
		mov	dl, 22
		call	set_curpos
		lea	si, cs:MSG_1025
		mov	ah, 70h
		call	PRINT
		call	SHOW_OPTS
		mov	dh, 7
		mov	dl, 47
		push	dx
		; Nun Warte man auf eine Eingabe vom User...
	@@Wait_Loop:
		mov	al, 2
		mov	ah, 14
		mov	bl, 78
		mov	bh, 22
		call	DRAW_BOX		
		mov	dh, 15
		mov	dl, 4
		call	set_curpos
		pop	dx
		push	dx
		cmp	dh, 7
		je	@@HLP_AUTO
		cmp	dh, 8
		je	@@HLP_TASTE
		cmp	dh, 9
		je	@@HLP_ZEIT
		cmp	dh, 10
		je	@@HLP_STAT
		cmp	dh, 11
		je	@@HLP_PASS
		jmp	@@Wait_Again
	@@HLP_PASS:
		lea	si, cs:HLP_1021
		mov	ah, 74h
		call	PRINT
		mov	dh, 17
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1022
		mov	ah, 70h
		call	PRINT
		mov	dh, 18
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1023
		mov	ah, 70h
		call	PRINT
		mov	dh, 19
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1024
		mov	ah, 70h
		call	PRINT
		mov	dh, 20
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1025
		mov	ah, 70h
		call	PRINT
		jmp	@@Wait_Again
	@@HLP_STAT:
		lea	si, cs:HLP_1016
		mov	ah, 74h
		call	PRINT
		mov	dh, 16
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1017
		mov	ah, 70h
		call	PRINT
		mov	dh, 18
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1018
		mov	ah, 70h
		call	PRINT
		mov	dh, 20
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1019
		mov	ah, 70h
		call	PRINT
		mov	dh, 21
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1020
		mov	ah, 70h
		call	PRINT
		jmp	@@Wait_Again
	@@HLP_AUTO:
		lea	si, cs:HLP_1000
		mov	ah, 74h
		call	PRINT
		mov	dh, 16
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1001
		mov	ah, 70h
		call	PRINT
		mov	dh, 18
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1002
		mov	ah, 70h
		call	PRINT
		mov	dh, 20
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1003
		mov	ah, 70h
		call	PRINT
		mov	dh, 21
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1004
		mov	ah, 70h
		call	PRINT
		jmp	@@Wait_Again
	@@HLP_TASTE:
		lea	si, cs:HLP_1005
		mov	ah, 74h
		call	PRINT
		mov	dh, 17
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1006
		mov	ah, 70h
		call	PRINT
		mov	dh, 18
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1007
		mov	ah, 70h
		call	PRINT
		mov	dh, 19
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1008
		mov	ah, 70h
		call	PRINT
		mov	dh, 20
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1009
		mov	ah, 70h
		call	PRINT
		jmp	short @@Wait_Again
	@@HLP_ZEIT:
		lea	si, cs:HLP_1010
		mov	ah, 74h
		call	PRINT
		mov	dh, 17
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1011
		mov	ah, 70h
		call	PRINT
		mov	dh, 18
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1012
		mov	ah, 70h
		call	PRINT
		mov	dh, 19
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1013
		mov	ah, 70h
		call	PRINT
		mov	dh, 20
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1014
		mov	ah, 70h
		call	PRINT
		mov	dh, 21
		mov	dl, 4
		call	set_curpos
		lea	si, cs:HLP_1015
		mov	ah, 70h
		call	PRINT
	@@Wait_Again:
		pop	dx
		push	dx
		call	set_curpos
		xor	ax, ax		; Read Keyb Input
		int	16h
		
		; Mal sehen was gepresst wurde!
		; Non-ASC-II? (Sollte so sein...)
		cmp	al, 0
		je	@@NonASC
		cmp	al, 27		; ESC
		je	@@Zurueck
		pop	dx
		push	dx
		cmp	dh, 11
		je	@@PassIn
		jmp	short @@Wait_Again
	@@Zurueck:
		pop	dx
		ret
	@@PassIn:
		cmp	al, '$'
		je	@@Wait_Again
		cmp	al, 13
		je	@@Wait_Again
		cmp	al, 9
		je	@@Wait_Again
		cmp	al, 8h
		je	@@DelChar
		mov	cl, dl
		sub	cl, 47
		cmp	cl, 8
		jge	@@Wait_Again
		lea	bx, cs:PASSWORT
		xor	dh, dh
		add	bx, dx
		sub	bx, 47
		mov	byte ptr cs:[bx], al
		mov	byte ptr cs:[bx+1], '$'
		call	SHOW_OPTS
		pop	dx
		inc	dl
		push	dx
		jmp	@@Wait_Again
	@@DelChar:
		mov	cl, dl
		sub	cl, 47
		cmp	cl, 0
		je	@@Wait_Again
		lea	bx, cs:PASSWORT
		xor	ch, ch
		add	bx, cx
		dec	bx
		mov	byte ptr cs:[bx], '$'
		mov	byte ptr cs:[bx+1], ' '
		pop	dx
		dec	dl
		push	dx
		call	SHOW_OPTS
		jmp	@@Wait_Again				
	@@NonASC:
		cmp	ah, 48h			; UP
		je	@@MoveUp
		cmp	ah, 50h			; DOWN
		je	@@MoveDown
		cmp	ah, 44h			; F10
		je	@@DoCFG
		cmp	ah, 4bh			; Left
		je	@@TogleLeft
		cmp	ah, 4dh
		je	@@TogleRight		; Right
		jmp	@@Wait_Again
	@@TogleLeft:
		pop	dx
		push	dx
		cmp	dh, 7
		je	@@TogleAuto
		cmp	dh, 8
		je	@@TogleKeyDown
		cmp	dh, 9
		je	@@TogleTimeDown
		cmp	dh, 10
		je	@@TogleStatLeft
		jmp	@@Wait_Again
	@@TogleRight:
		pop	dx
		push	dx
		cmp	dh, 7
		je	@@TogleAuto
		cmp	dh, 8
		je	@@TogleKeyUp
		cmp	dh, 9
		je	@@TogleTimeUp
		cmp	dh, 10
		je	@@TogleStatRight
		jmp	@@Wait_Again
	@@TogleStatLeft:
		mov	al, byte ptr cs:[PASSWORT_STATUS]
		cmp	al, 0
		je	@@StatLast
		dec	al
		jmp	short @@SetStat
	@@TogleKeyDown:
		; 10.11.95: Die Taste kann nur ge„ndert werden, wenn Auto-
		;           Start=Nein ist.
		mov	ax, word ptr cs:[BOOTMAN_KEY]
		cmp	ax, 0ffffh
		je	@@Wait_Again
		cmp	al, 1
		je	@@ExtDown
		cmp	al, 0
		je	@@check_ExtDown
		shr	al, 1
		jmp	short @@DoKey
	@@ExtDown:
		mov	ah, 8
		mov	al, 0
		jmp	short @@DoKey
	@@check_ExtDown:
		cmp	ah, 1
		je	@@ShiftLast
		shr	ah, 1
		jmp	short @@DoKey
	@@ShiftLast:
		mov	al, 2
		mov	ah, 0
		jmp	short @@DoKey	
	@@TogleKeyUp:
		; 10.11.95: Die Taste kann nur ge„ndert werden, wenn Auto-
		;           Start=Nein ist.
		mov	ax, word ptr cs:[BOOTMAN_KEY]
		cmp	ax, 0ffffh
		je	@@Wait_Again
		cmp	al, 2
		je	@@ExtUp
		cmp	al, 0
		je	@@check_ExtUp
		shl	al, 1
		jmp	short @@DoKey
	@@Check_extUp:
		cmp	ah, 8
		je	@@ExtFirst
		shl	ah, 1
		jmp	short @@DoKey
	@@ExtFirst:
		mov	al, 1
		mov	ah, 0
		jmp	short @@DoKey
	@@ExtUp:
		mov	al, 0
		mov	ah, 1
	@@DoKey:
		mov	word ptr cs:[BOOTMAN_KEY], ax
		call	SHOW_OPTS
		jmp	@@Wait_Again
	@@StatLast:
		mov	al, 2
		jmp	short @@SetStat
	@@TogleStatRight:
		mov	al, byte ptr cs:[PASSWORT_STATUS]
		cmp	al, 2
		je	@@StatFirst
		inc	al
		jmp	short @@SetStat
	@@StatFirst:
		xor	al, al
	@@SetStat:
		mov	byte ptr cs:[PASSWORT_STATUS], al
		call	SHOW_OPTS
		jmp	@@Wait_Again
		
	@@TogleTimeDown:
		mov	al, byte ptr cs:[PRIMARY_TIMEOUT]
		cmp	al, 0
		je	@@Wait_Again
		dec	al
		jmp	short @@SetTime
	@@TogleTimeUp:
		mov	al, byte ptr cs:[PRIMARY_TIMEOUT]
		cmp	al, 60
		je	@@Wait_Again
		inc	al
		jmp	short @@SetTime
	@@SetTime:
		mov	byte ptr cs:[PRIMARY_TIMEOUT], al
		call	SHOW_OPTS
		jmp	@@Wait_Again
	@@TogleAuto:
		mov	ax, 0200h
		cmp  	word ptr cs:[BOOTMAN_KEY], 0ffffh
		je	@@SetAuto
		mov	ax, 0ffffh
	@@SetAuto:
		mov	word ptr cs:[BOOTMAN_KEY], ax
		call	SHOW_OPTS
		jmp	@@Wait_Again
	@@MoveDown:
		pop	dx
		cmp	dh, 11
		je	@@MoveFirst
		inc	dh
		jmp	short @@SetPos	
	@@MoveFirst:
		mov	dh, 7
		jmp	short @@SetPos
	@@MoveUp:
		pop	dx		
		cmp	dh, 7
		je	@@MoveLast
		dec	dh
		jmp	short @@SetPos		
	@@MoveLast:
		mov	dh, 11
	@@SetPos:
		mov	dl, 47
		cmp	dh, 11
		je	@@CheckPassSize		
		push	dx
		jmp	@@Wait_Loop
	@@CheckPassSize:
		; Mal sehen wie lang das Passwd ist und den Cursor ans Ende
		; setzen...
		lea	bx, cs:PASSWORT
	@@CheckLoop:	
		cmp	byte ptr cs:[bx], '$'
		je	@@CheckEnde
		inc	dl
		inc	bx
		jmp	short @@CheckLoop
	@@CheckEnde:
		cmp	byte ptr cs:[bx+1], '$'
		jne	@@IstEnde
		add	bx, 2
		inc	dl
		jmp	short @@CheckLoop
	@@IstEnde:
		push	dx
		jmp	@@Wait_Loop
	@@DoCfg:	
		call	WRITE_CFG
		jc	@@CfgFail
		mov	dh, 8
		mov	dl, 29
		call	set_curpos
		lea	si, cs:MSG_1018
		mov	ah, 70h
		call	PRINT
		jmp	short @@WaitOK
	@@CfgFail:
		mov	dh, 8
		mov	dl, 31
		call	set_curpos
		lea	si, cs:MSG_1019
		mov	ah, 70h
		call	PRINT
	@@WaitOK:
		mov	dh, 10
		mov	dl, 35
		call	set_curpos
		lea	si, cs:MSG_1020
		mov	ah, 74h
		call	PRINT
		xor	ax, ax
		int	16h
		pop	dx
		jmp	@@Restart_BootMan
		ret
	BOOTMAN_OPTS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ	
	; SHOW_OPTS: Updatet die Option auf dem Bildschirm (fr BOOTMAN_OPTS)
	; Input : -
	; Output: -
	;
	SHOW_OPTS PROC NEAR
		mov	dh, 7
		mov	dl, 47
		call	set_curpos
		; Mal nach den Daten sehen...
		mov	ah, 70h
		cmp	word ptr ds:[BOOTMAN_KEY], 0FFFFh
		je	@@Anzeigen
		lea	si, cs:MSG_1006
		jmp	short @@LookTaste
	@@Anzeigen:
		lea	si, cs:MSG_1005
	@@LookTaste:
		call	PRINT
		mov	dh, 8
		mov	dl, 47
		call	set_curpos
		mov	ah, 71h
		cmp	word ptr cs:[BOOTMAN_KEY], 0ffffh
		je	@@LeftAlt
		mov	ah, 70h
		mov	bx, word ptr cs:[BOOTMAN_KEY]		
		test	bl, 2
		jnz	@@LeftShift
		test	bl, 1
		jnz	@@RightShift
		test	bh, 8
		jnz	@@RightAlt
		test	bh, 4
		jnz	@@RightCtrl
		test	bh, 2
		jnz	@@LeftAlt
		test	bh, 1
		jnz	@@LeftCtrl
	@@RightAlt:
		lea	si, cs:MSG_1011
		jmp	short @@LookTime
	@@LeftAlt:
		lea	si, cs:MSG_1012
		jmp	short @@LookTime
	@@RightCtrl:
		lea	si, cs:MSG_1013
		jmp	short @@LookTime
	@@LeftCtrl:
		lea	si, cs:MSG_1014
		jmp	short @@LookTime
	@@RightShift:
		lea	si, cs:MSG_1015
		jmp	short @@LookTime
	@@LeftShift:
		lea	si, cs:MSG_1016
	@@LookTime:
		call	PRINT
		mov	dh, 9
		mov	dl, 47
		call	set_curpos
		mov	bl, byte ptr cs:[PRIMARY_TIMEOUT]
		cmp	bl, 9
		jg	@@LosWochos
		mov	ah, 70h
		mov	al, ' '
		call	PRINT_CHAR
	@@LosWochos:
		mov	bl, byte ptr cs:[PRIMARY_TIMEOUT]
		mov	ah, 70h
		call	PRINT_ZAHL
		mov	dh, 10
		mov	dl, 47
		call	set_curpos
		mov	al, byte ptr cs:[PASSWORT_STATUS]
		cmp	al, 0
		je	@@NixPass
		cmp	al, 1
		je	@@PassOpts
		lea	si, cs:MSG_1024
		jmp	short @@ShowStat
	@@PassOpts:	
		lea	si, cs:MSG_1023
		jmp	short @@ShowStat
	@@NixPass:
		lea	si, cs:MSG_1022
		jmp	short @@ShowStat
	@@ShowStat:
		mov	ah, 70h
		call	PRINT
		mov	dh, 11
		mov	dl, 47
		call	set_curpos
		mov	cx, 8
		mov	ah, 70h
		mov	al, ' '
		call	PRINT_LOOP
		mov	dh, 11
		mov	dl, 47
		call	set_curpos
		lea	si, cs:PASSWORT
		mov	ah, 70h
		call	PRINT		
		ret		
 	SHOW_OPTS ENDP
		
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; BUILD_SCREEN: L”scht den Bildschirm (das VRAM) und bringt die VOS/9 
	;               Men-Optik zum vorschein...
	; Input : -
	; Output: -
	;
	BUILD_SCREEN PROC NEAR
		push	ax bx cx dx 
		call	CLEAR
		; Mal die VOS/9 Men Optik zum vorschein bringen...
		xor	dx, dx		; Cursorpos 0, 0
		call	SET_CURPOS
		mov	ax, 70DAh
		call	PRINT_CHAR
		mov	ax, 70C4h
		mov	cx, 78
		call	PRINT_LOOP
		mov	ax, 70BFh
		call	PRINT_CHAR
		mov	ax, 70B3h
		call	PRINT_CHAR
		mov	ax, 7020h
		mov	cx, 78
		call	PRINT_LOOP
		mov	ax, 70B3h
		call	PRINT_CHAR
		mov	ax, 70C0h
		call	PRINT_CHAR
		mov	ax, 70C4h
		mov	cx, 78
		call	PRINT_LOOP
		mov	ax, 70D9h
		call	PRINT_CHAR
		call	CLEAR_FRAME
		mov	dh, 1
		mov	dl, 3
		call	SET_CURPOS
		mov	ah, 70h
		mov	si, offset cs:MSG_0000
		call	PRINT
		pop	dx cx bx ax
		ret		
	BUILD_SCREEN ENDP
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; CLEAR_FRAME: L”scht den beschreibbaren Ausschnitt
	;             
	; Input : -
	; Output: -
	;
	CLEAR_FRAME PROC NEAR
		push	ax bx cx dx
		xor	dx, dx
		mov	dh, 3
		call	SET_CURPOS
		mov	ah, 10h
		mov	al, ' '
		mov	cx, 1760		; Zeichen zu l”schen
		call	PRINT_LOOP
		pop	dx cx bx ax
		ret
	CLEAR_FRAME ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	; SHOW_INFO: Zeigt die Funktionstastenbelegung
	; Input : SI = Offset des Funktions-Strings/CS=Seg
	; Output: -
	;
	SHOW_INFO PROC NEAR
		push	si
		mov	dh, 24
		mov	dl, 1
		call	SET_CURPOS

		mov	ax, 7020h
		mov	cx, 78
		call    PRINT_LOOP
		pop	si	
		
		mov	dh, 24
		mov	dl, 2
		call	SET_CURPOS

		mov	ah, 70h
	@@ShowLoop:
		mov	al, cs:[si]
		cmp	al, '['
		je      @@RedFollows
		cmp	al, ']'
		je	@@RedEnds
		cmp	al, '$'
		je	@@ShowEnds
	@@NextInfo:
		call	print_char
		inc	si
		jmp	short @@ShowLoop
	@@RedFollows:
		mov	ah, 70h
		call	print_char
		mov	ah, 74h
		inc	si
		jmp	short @@ShowLoop
	@@RedEnds:
		mov	ah, 70h
		jmp	short @@NextInfo
	@@ShowEnds:
		ret
	SHOW_INFO ENDP

        ;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
        ; READ_SEKTORS: Liest einen Sektor oder mehrere Sektoren
        ; Input : es:bx = seg/off Buffer
        ;         cx = SekZyl
        ;         dh = HeadZyl
        ;	  dl = Laufwerk
        ;	  al = Anzahl Sektoren
        ; Output: Carry 1 = Failed
        ;
        READ_SEKTORS PROC NEAR
		push	dx		; Alles sichern!
		push	cx
		push	ax
		push	es
		push	bx
		mov	al, 22
		mov	ah, 7
		mov	bl, 60
		mov	bh, 12
		call	DRAW_BOX		
		mov	dh, 9
		mov	dl, 34
		call	set_curpos
		lea	si, ds:MSG_1017
		mov	ah, 74h
		call	PRINT
		mov	dh, 10
		mov	dl, 41
		call	set_curpos
		mov	al, byte ptr ds:[SYMBOLIC]
		mov	ah, 70h
		call	PRINT_CHAR
		pop	bx
		pop	es
		pop	ax
		pop	cx
		pop	dx
		xor	esi, esi	; Symbol 0 Aktiv		
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
		mov	dl, ah		; Laufwerk zurck
		pop	bx		; Offset Zurck
		cmp	si, 3		; Wieder erstes Symbol
		je	@@First_Sym
		inc	si
		jmp	short @@ShowSym
	@@First_Sym:
		xor	si, si
	@@ShowSym:
		push	es
		push	bx
		push	di
		push	si
		push	ax
		push	cx
		push	dx
		mov	dh, 10
		mov	dl, 41
		call	set_curpos
		mov	al, byte ptr cs:[SYMBOLIC+si]
		mov	ah, 70h
		call	PRINT_CHAR
		pop	dx
		pop	cx
		pop	ax
		pop	si
		pop	di
		pop	bx
		pop	es				
		jmp	@@Read_Loop
	@@IstOK:
		; Alles gelesen...
		mov	dh, 9
		mov	dl, 34
		call	set_curpos
		lea	si, cs:MSG_1017
		mov	ah, 77h
		call	PRINT
		clc
		ret
	@@Failed:
		mov	dh, 9
		mov	dl, 34
		call	set_curpos
		lea	si, cs:MSG_1017
		mov	ah, 77h
		call	PRINT
		pop	ax
		stc
		ret				
        READ_SEKTORS ENDP

        ;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
        ; WRITE_SEKTORS: Schreibt einen Sektor oder mehrere Sektoren
        ; Input : es:bx = seg/off Buffer
        ;         cx = SekZyl
        ;         dh = HeadZyl
        ;	  dl = Laufwerk
        ;	  al = Anzahl Sektoren
        ; Output: Carry 1 = Failed
        ;
        WRITE_SEKTORS PROC NEAR
		push	dx		; Alles sichern!
		push	cx
		push	ax
		push	es
		push	bx
		mov	al, 22
		mov	ah, 7
		mov	bl, 60
		mov	bh, 12
		call	DRAW_BOX		
		mov	dh, 9
		mov	dl, 34
		call	set_curpos
		lea	si, ds:MSG_1017
		mov	ah, 74h
		call	PRINT
		mov	dh, 10
		mov	dl, 41
		call	set_curpos
		mov	al, byte ptr ds:[SYMBOLIC]
		mov	ah, 70h
		call	PRINT_CHAR
		pop	bx
		pop	es
		pop	ax
		pop	cx
		pop	dx
		xor	esi, esi	; Symbol 0 Aktiv		
		mov	edi, 4		; 4 Versuche
	@@Read_Loop:
		push	ax
		mov	ax, 0301h
		int	13h
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
		mov	dl, ah		; Laufwerk zurck
		pop	bx		; Offset Zurck
		add	bx, 200h
		cmp	si, 3		; Wieder erstes Symbol
		je	@@First_Sym
		inc	si
		jmp	short @@ShowSym
	@@First_Sym:
		xor	si, si
	@@ShowSym:
		push	es
		push	bx
		push	di
		push	si
		push	ax
		push	cx
		push	dx
		mov	dh, 10
		mov	dl, 41
		call	set_curpos
		mov	al, byte ptr ds:[SYMBOLIC+si]
		mov	ah, 70h
		call	PRINT_CHAR
		pop	dx
		pop	cx
		pop	ax
		pop	si
		pop	di
		pop	bx
		pop	es				
		jmp	@@Read_Loop
	@@IstOK:
		; Alles gelesen...
		mov	dh, 9
		mov	dl, 34
		call	set_curpos
		lea	si, ds:MSG_1017
		mov	ah, 77h
		call	PRINT
		clc
		ret
	@@Failed:
		pop	ax
		dec	di
		cmp	di, 0
		jne	@@Read_Loop
		; Fehler beim Lesen, ERR in ah
		mov	dh, 9
		mov	dl, 34
		call	set_curpos
		lea	si, ds:MSG_1017
		mov	ah, 77h
		call	PRINT
		stc
		ret		
        WRITE_SEKTORS ENDP

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
				
	BOOT_DRIVE	db	0		; Start Laufwerk
	BOOTMAN_SEKZYL	dw	0		; Position des Bootcodes
	BOOTMAN_HEADZYL	db	0		; und dessen Gr”áe in
	BOOTMAN_SEKS	dw	0		; Sektoren

	PRIMARY_DRIVE	db	0		; Prim„r Laufwerk (Autoboot)
	PRIMARY_PART	dw	0		; Prim„r Partition (Autoboot)

	CURRENT_DRIVE	db	0		; Aktuelles Laufwerk

	BOOTMAN_KEY	dw	0		; Aufruf Taste
	KEY_BACKUP	dw	0		; Kopie der Aufruf-Taste

	BACKUP_DRIVE	db	0		; Kopie des OS/2 Laufwerks
	BACKUP_PART	dw	0		; Offset OS/2 Part

	PASSWORT	db	'$'
			db	8 dup (?);	; Passwort fr Optionen/Start
	PASSINPUT	db	'$'
			db	8 dup (?)	; Passwort Eingabe hierher
	PASSWORT_STATUS	db	0h
						; 0 = Deaktiviert
						; 1 = bei Optionen
						; 2 = bei Start

	TIMING		dw	0		; Zeiten fr Autoboot
	PRIMARY_TIMEOUT	db	60
	
	
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
				
	; Systemtitel
	MSG_0000	db	'VOS/9 SYSTEM SELECT     Version 1.0     (c)(r) 1995 by MZ Computer Systems$'

	; Systemtexte	
	MSG_1002	db 	'Lesefehler!$'
	MSG_1003	db	'Schreibfehler!$'
	MSG_1004	db	'ndern der System-Select Optionen$'
	MSG_1005	db	'Ja  $'
	MSG_1006	db	'Nein$'
	MSG_1007	db	'Sekunde(n)$'
	MSG_1008	db	'Automatisch Starten   : $'
	MSG_1009	db	'Taste zur Aktivierung : $'
	MSG_1010	db	'Zeit bis Autostart    : $'
	MSG_1011	db	'R-Alt  $'
	MSG_1012	db	'L-Alt  $'
	MSG_1013	db	'R-Ctrl $'
	MSG_1014	db	'L-Ctrl $'
	MSG_1015	db	'R-Shift$'
	MSG_1016	db	'L-Shift$'
	MSG_1017	db	'Bitte Warten...$'
	MSG_1018	db	'Konfiguration gesichert.$'
	MSG_1019	db	'Fehler beim Sichern!$'
	MSG_1020	db	'    < OK > $'
	MSG_1021	db	'Passwort Abfrage      : $'
	MSG_1022	db	'Deaktiviert $'
	MSG_1023	db	'bei Optionen$'
	MSG_1024	db	'bei Start   $'
	MSG_1025	db	'Passwort              : $'
	MSG_1026	db	'PASSWORT: $'
	MSG_1027	db	'Autostart$'
	MSG_1028        db      'in -   Sekunden$'		
	MSG_1029	db	'Ubekannt - TYP $'
	MSG_1030	db	'Festplatte $'
	MSG_1031	db	'=>$'
	MSG_1032	db	'  Deaktiviert  $'

	; Zeichnugselemente, ...
	SYMBOLIC	db	'|/Ä\Ú¿ÀÙ³ '		

	; Statuszeilen
        MSG_0001	db	'[ESC] Abbruch [DEL] Korrektur [<=] OK$'
        MSG_0002	db	'  [ESC] Abbruch   [',1fh,'][',1eh,'] Feld W„hlen  [<-][->] Auswahl   [F10] Speichern$'
	MSG_0003     	db	'[',1fh,'][',1eh,'] W„hlen [<-][->] Festp. [F1] Hilfe [F2] ndern [F3] Opt. [<=] Start$'

	; Hilfstexte
	HLP_1000	db	'AUTOMATISCH STARTEN:$'
	HLP_1001	db	'Hier k”nnen Sie Einstellen, ob SYSTEM-SELECT bei jedem Start erscheint.$'
	HLP_1002	db	'JA    SYSTEM-SELECT wird bei jedem Neustart des Systems Aufgerufen.$'
	HLP_1003	db	'NEIN  Nach einem Neustart erscheint SYSTEM-SELECT, wenn die TASTE ZUR$'
	HLP_1004	db	'      AKTIVIERUNG gedrckt gehalten wird.$'
	HLP_1005	db	'TASTE ZUR AKTIVIERUNG:$'
	HLP_1006	db	'Wenn Sie die gew„hlte Taste bei einem Neustart gedrck halten, wird $'
	HLP_1007	db	'SYSTEM-SELECT aufgerufen. Ansonsten wird daá von Ihnen eingestellte $'
	HLP_1008	db	'standard Betriebssystem gestartet. Diese Option ist nur dann aktiv, $'
	HLP_1009	db	'wenn Sie AUTOMATISCH-STARTEN auf NEIN gestellt haben.$'
	HLP_1010	db	'ZEIT BIS AUTOSTART:$'
	HLP_1011	db	'Wenn Sie AUTOMATISCH STARTEN auf JA gestellt haben, k”nnen Sie hier die$'
	HLP_1012	db	'Zeitspanne einstellen, in welcher Sie ein anderes Betriebssystem w„hlen$'
	HLP_1013	db	'k”nnen. Haben Sie innerhalb dieser Zeit kein anderes System ausgew„hlt,$'
	HLP_1014	db	'wird das standard System automatisch gestartet. W„hlen Sie 0 Sekunden um$'
	HLP_1015	db	'diese Funktion zu Deaktivieren.$'
	HLP_1016	db	'PASSWORT ABFRAGE:$'
	HLP_1017	db	'W„hlen Sie ob/wann Sie ein Passwort verwenden m”chten.$'
	HLP_1018	db	'DEAKTIVIERT   Die Passwortfunktion wird nicht verwendet.$'
	HLP_1019	db	'BEI OPTIONEN  Das Passwort wird nur bei Aufruf dieses Mens verlangt.$'
	HLP_1020	db	'BEI START     Abfrage des Passworts nach dem Starten von SYSTEM-SELECT.$'
	HLP_1021	db	'PASSWORT:$'
	HLP_1022	db	'W„hlen Sie bitte ein Passwort fr den unter PASSWORT ABFRAGE gew„hlten$'
	HLP_1023	db	'Bereich (nur gltig wenn nicht Deaktiviert). Groá- und Kleinschreibung$'
	HLP_1024	db	', sowie Leerzeichen werden beachtet. Das Passwort endet an der Stelle $'
	HLP_1025	db	'des Cursors. Maximal sind 8 Zeichen/Sonderzeichen m”glich. $'
	        
	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	
	include	..\bios\vio.inc			; BIOS Video Funktionen
	include ..\bios\strg.inc		; String Bearbeitung
	include ..\bios\diskio.inc		; BIOS Disk Funktionen

	;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
		
	DATABASE_START  db	000h, '- (unbelegt)                  $'
			db	001h, 'DOS - 12 Bit FAT < 32 MByte   $'
			db	002h, 'Xenix - Root                  $'
			db	003h, 'Xenix - User                  $'			
			db	004h, 'DOS - 16 Bit FAT < 32 MByte   $'
			db	005h, 'DOS - Extended Partition      $'
			db	006h, 'DOS - 16 Bit FAT > 32 MByte   $'
			db	007h, 'IBM OS/2 - HPFS               $'
			db	008h, 'IBM AIX                       $'
			db	009h, 'IBM AIX - BOOT                $'
			db	00Ah, 'IBM OS/2 - Bootmanager        $'
			db	016h, 'IBM OS/2 - FAT (versteckt)    $'
			db	040h, 'Venix                         $'			
			db	051h, 'Novell Netware                $'
			db	052h, 'Microport                     $'
			db	063h, 'GNU Hurd                      $'
			db	064h, 'Novell Netware                $'
			db	065h, 'Novell Netware 386            $'
			db	075h, 'PC/IX                         $'
			db	080h, 'Minix (old)                   $'
			db	081h, 'Minix / Linux                 $'
			db	082h, 'Linux - SWAP                  $'
			db	083h, 'Linux - Extended FS           $'
			db	093h, 'Amoeba                        $'
			db	094h, 'Amoeba BBT                    $'
			db	0B7h, 'BSDI - FS                     $'
			db	0B8h, 'BSDI - SWAP                   $'
			db	0C0h, 'Novell DOS - Geschtzt        $'			
			db	0C7h, 'Syrinx                        $'						
			db	0D0h, 'VOS/9 - ROOT VOLUME           $'
			db	0D1h, 'VOS/9 - EXTENDED VOLUME       $'
			db	0DBh, 'CP/M                          $'
			db	0E1h, 'DOS - ACCESS                  $'
			db	0E3h, 'DOS - READ ONLY               $'
			db	0F2h, 'DOS - SECONDARY               $'
			db	0FFh, 'BBT                           $'
	DATABASE_END	label WORD
	;============================================================
	; ENDE IM GELNDE

	BOOT_SIZE	LABEL	WORD		

SYS_SEL ENDS
end	STARTUP_IP