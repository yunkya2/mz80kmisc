;	FD BOOT selector for MZ-80K/C
;	Copyright (c) 2024 Yuichi Nakamura (@yunkya2)
;
;	The MIT License (MIT)
;	
;	Permission is hereby granted, free of charge, to any person obtaining a copy
;	of this software and associated documentation files (the "Software"), to deal
;	in the Software without restriction, including without limitation the rights
;	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;	copies of the Software, and to permit persons to whom the Software is
;	furnished to do so, subject to the following conditions:
;	
;	The above copyright notice and this permission notice shall be included in
;	all copies or substantial portions of the Software.
;	
;	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;	THE SOFTWARE.

	.ORG	09800H

START:
	JP	COPY
COPY:				; copy main program to 0B000H-
	LD	HL,MAIN_ORG
	LD	DE,MAIN
	LD	BC,MAIN_END - MAIN
	LDIR
	JP	MAIN

MAIN_ORG:
	.PHASE	0B000H

;	boot loader main

MAIN:
	LD	A,(09FF0H)	; drive number
	LD	(DISK_DATA),A

	LD	DE,MSG_TITLE
	CALL	MSG
	CALL	NEWLIN

;	list OBJ files in a directory

LISTDIR:
	LD	IX,DISK_DATA
	LD	(IX+1),001H	; trk
	LD	(IX+2),001H	; sect
	LD	HL,00800H
	LD	(IX+3),L
	LD	(IX+4),H
	LD	HL,DIRBUF
	LD	(IX+5),L
	LD	(IX+6),H
	CALL	DSKRED		; read directory

	XOR	A
	LD	(COUNT),A
	LD	HL,DIRBUF

	LD	BC,00020H	; directory entry size (SP-6110)
	LD	A,(HL)
	CP	080H		; SP-6110 type ?
	JR	Z,LISTDIR1
	LD	BC,00040H	; directory entry size (SP-6010)
LISTDIR1:
	LD	A,(HL)
	CP	001H		; OBJ file
	JR	NZ,LISTDIR2

	LD	DE,00011H
	ADD	HL,DE
	LD	(HL),00DH	; add terminator for SP-6010
	OR	A
	SBC	HL,DE

	LD	A,(COUNT)
	INC	A
	LD	(COUNT),A
	DEC	A
	CALL	ASC
	CALL	PRINT		; print file number
	LD	DE,MSG_FILE
	CALL	MSG
	LD	DE,HL
	INC	DE
	CALL	MSG		; print file name
	CALL	NEWLIN

LISTDIR2:
	ADD	HL,BC		; next entry
	LD	A,H
	CP	DBEND >> 8
	JR	NZ,LISTDIR1

;	input file number to boot

SELECT:
	LD	DE,MSG_INPUT
	CALL	MSG
	LD	DE,BUFER
	CALL	GETL

	LD	HL,00008H
	ADD	HL,DE

	LD	A,(HL)		; input character
	CP	021H		; '!'
	JP	Z,ST1		; go to monitor

	CP	00DH		; CR
	JR	NZ,SELECT1
	LD	A,'0'		; default #0
SELECT1:
	CALL	HEX		; convert hex char -> value
	JP	C,LISTDIR

	LD	(COUNT),A
	LD	HL,DIRBUF

	LD	BC,00020H	; directory entry size (SP-6110)
	LD	A,(HL)
	CP	080H		; SP-6110 type ?
	JR	Z,SELECT2
	LD	BC,00040H	; directory entry size (SP-6010)
SELECT2:
	LD	A,(HL)
	CP	001H		; OBJ file
	JR	NZ,SELECT3

	LD	A,(COUNT)
	OR	A
	JR	Z,LOADFILE	; found
	DEC	A
	LD	(COUNT),A
SELECT3:
	ADD	HL,BC		; next entry
	LD	A,H
	CP	DBEND >> 8
	JR	NZ,SELECT2
	JP	LISTDIR		; not found

;	load file

LOADFILE:
	LD	DE,MSG_LOAD
	CALL	MSG
	LD	DE,HL
	INC	DE
	CALL	MSG		; print file name
	CALL	NEWLIN

	LD	DE,HL
	LD	IY,DE
	LD	HL,LOADER
	LD	(ADDR),HL	; load address (01200H-)

	LD	HL,00080H
	LD	(IX+3),L	; data size (1 sector)
	LD	(IX+4),H

	LD	HL,DIRBUF
	LD	A,(HL)
	CP	080H		; SP-6110 type ?
	JR	Z,LOADFILE6110

;	load file (SP-6010)

LOADFILE6010:			; SP-6010 file load
	LD	DE,(IY+03EH)	; sector chain(track/sector)
LOADFILE1:
	LD	(IX+1),E	; track
	LD	(IX+2),D	; sector
	LD	HL,(ADDR)
	LD	(IX+5),L	; load address
	LD	(IX+6),H
	CALL	DSKRED_FAST

	LD	HL,(ADDR)
	LD	BC,0007EH	; sector size - sector chain
	ADD	HL,BC
	LD	(ADDR),HL

	LD	DE,(HL)		; next track/sector
	LD	A,D
	OR	E
	JR	NZ,LOADFILE1

;	jump to application (SP-6010)

APPSTART6010:
	CALL	MOTOFF

	LD	HL,0B8EDH	; LDDR
	LD	(BUFER),HL
	LD	A,0C3H		; JP nnnnH
	LD	(BUFER+2),A
	LD	DE,(IY+016H)	; entry address (SP-6010)
	LD	HL,DE
	LD	(BUFER+3),HL

	LD	BC,(IY+012H)	; file size (SP-6010)
	LD	HL,(IY+014H)	; load address (SP-6010)
	DEC	BC
	ADD	HL,BC
	LD	DE,HL
	LD	HL,LOADER
	ADD	HL,BC
	INC	BC

	JP	BUFER

;	load file (SP-6110)

LOADFILE6110:			; SP-6110 file load
	LD	DE,(IY+014H)	; file size (SP-6110)
	LD	(SIZE),DE

	LD	DE,(IY+01EH)	; 1st block number
	LD	HL,DE
	ADD	HL,HL		; block number -> sector number

	LD	A,L
	AND	00FH
	INC	A
	LD	(IX+2),A	; sector

	SLA	L		; HL <<= 4
	RL	H
	SLA	L
	RL	H
	SLA	L
	RL	H
	SLA	L
	RL	H
	LD	(IX+1),H	; track
LOADFILE2:
	LD	HL,(ADDR)
	LD	(IX+5),L	; load address
	LD	(IX+6),H
	CALL	DSKRED_FAST

	LD	BC,00080H	; sector size

	LD	HL,(ADDR)
	ADD	HL,BC
	LD	(ADDR),HL	; next address

	LD	HL,(SIZE)
	OR	A
	SBC	HL,BC
	JR	Z,APPSTART6110
	JR	C,APPSTART6110
	LD	(SIZE),HL	; remaining size

	LD	A,(IX+2)	; sector
	INC	A
	CP	011H
	JR	NZ,LOADFILE3

	LD	A,(IX+1)	; go to next track
	INC	A
	LD	(IX+1),A	; next track
	LD	A,001H
LOADFILE3:
	LD	(IX+2),A	; next sector
	JR	LOADFILE2	

;	jump to application (SP-6110)

APPSTART6110:
	CALL	MOTOFF

	LD	HL,0B8EDH	; LDDR
	LD	(BUFER),HL
	LD	A,0C3H		; JP nnnnH
	LD	(BUFER+2),A
	LD	DE,(IY+018H)	; entry address (SP-6110)
	LD	HL,DE
	LD	(BUFER+3),HL

	LD	BC,(IY+014H)	; file size (SP-6110)
	LD	HL,(IY+016H)	; load address (SP-6110)
	DEC	BC
	ADD	HL,BC
	LD	DE,HL
	LD	HL,LOADER
	ADD	HL,BC
	INC	BC

	JP	BUFER

DSKRED_FAST:
	LD	A,10		; retry count
	LD	(01007H),A
	JP	DSKRD2		; motor is already on

;	message data

MSG_TITLE:	DB	"**  FD BOOT SELECTOR FOR MZ-80K/C  **",0DH
MSG_INPUT:	DB	"SELECT ?",0DH
MSG_FILE:	DB	": ",0DH
MSG_LOAD:	DB	"LOADING ",0DH

;	variables

ADDR:		DW	01200H
SIZE:		DW	0
COUNT:		DB	0
DISK_DATA:	DS	9

MAIN_END:

;	WORK AREA

LOADER:	EQU	01200H
DIRBUF:	EQU	0B800H
DBEND:	EQU	0C000H

;	ROM ROUTINES

GETL:	EQU	00003H
NEWLIN:	EQU	00009H
PRINT:	EQU	00012H
MSG:	EQU	00015H
ST1:	EQU	00082H
PRTWRD:	EQU	003BAH
PRTBYT:	EQU	003C3H
ASC:	EQU	003DAH
HEX:	EQU	003F9H

;	ROM WORK AREA

BUFER:	EQU	011A3H

;	FD ROM ROUTINES

MOTOFF:	EQU	0F0A7H
DSKRED:	EQU	0F13BH
DSKRD2:	EQU	0F143H

