; =============================================================================
; BareMetal Node
; Copyright (C) 2008-2024 Return Infinity -- see LICENSE.TXT
;
; Console
; Adapted from BareMetal-Monitor. All disk and input functionality was removed.
; =============================================================================

BITS 64
ORG 0x001E0000

CONSOLESIZE equ 4096

%include 'libBareMetal.asm'


start:
	; Grab screen values from kernel
	mov rcx, screen_lfb_get
	call [b_config]
	mov [VideoBase], rax
	xor eax, eax
	mov rcx, screen_x_get
	call [b_config]
	mov [VideoX], ax
	mov rcx, screen_y_get
	call [b_config]
	mov [VideoY], ax
	mov rcx, screen_bpp_get
	call [b_config]
	mov [VideoDepth], al

	; Calculate screen parameters
	xor eax, eax
	xor ecx, ecx
	mov ax, [VideoX]
	mov cx, [VideoY]
	mul ecx
	mov [Screen_Pixels], eax
	xor ecx, ecx
	mov cl, [VideoDepth]
	shr cl, 3
	mul ecx
	mov [Screen_Bytes], eax

	; Calculate font parameters
	xor eax, eax
	xor ecx, ecx
	mov ax, [VideoX]
	mov cl, [font_height]
	mul cx
	mov cl, [VideoDepth]
	shr cl, 3
	mul ecx
	mov dword [Screen_Row_2], eax
	xor eax, eax
	xor edx, edx
	xor ecx, ecx
	mov ax, [VideoX]
	mov cl, [font_width]
	div cx				; Divide VideoX by font_width
	sub ax, 2			; Subtract 2 for margin
	mov [Screen_Cols], ax
	xor eax, eax
	xor edx, edx
	xor ecx, ecx
	mov ax, [VideoY]
	mov cl, [font_height]
	div cx				; Divide VideoY by font_height
	sub ax, 2			; Subtrack 2 for margin
	mov [Screen_Rows], ax

	; Adjust the high memory map to keep 2MiB for the Frame Buffer
	mov rsi, 0x20000
	mov rdi, 0x20000
	mov rcx, 4			; 8 MiB
adjustnext:
	lodsq				; Load a PDPE
	add eax, 0x200000		; Add 2MiB to its base address
	stosq				; Store it back
	dec rcx
	cmp rcx, 0
	jne adjustnext
	mov rcx, 4			; 8 MiB TODO Adjust for stack
	xor eax, eax
	rep stosq

	; Set foreground/background color
	mov eax, 0x00FFFFFF		; 0x00BBGGRR
	mov [FG_Color], eax
	mov eax, 0x00000000
	mov [BG_Color], eax

	call screen_clear

	; Overwrite the kernel b_output function so output goes to the screen instead of the serial port
	mov rax, output_chars
	mov rdi, 0x100018
	stosq

	; Move cursor to bottom of screen
	mov ax, [Screen_Rows]
	dec ax
	mov [Screen_Cursor_Row], ax

	; Output system details
	mov rsi, message_node
	call output

	; Output core count and speed
	mov rsi, cpumsg
	call output
	xor eax, eax
	mov rsi, 0x5012
	lodsw
	mov rdi, temp_string
	mov rsi, rdi
	call int_to_string
	call output
	mov rsi, coresmsg
	call output
	mov rsi, 0x5010
	lodsw
	mov rdi, temp_string
	mov rsi, rdi
	call int_to_string
	call output
	mov rsi, mhzmsg
	call output

	; Output memory size
	mov rsi, memmsg
	call output
	mov rsi, 0x5020
	lodsd
	mov rdi, temp_string
	mov rsi, rdi
	call int_to_string
	call output
	mov rsi, mibmsg
	call output

	; Output MAC address
	mov rsi, networkmsg
	call output
	mov rcx, mac_get
	call [b_config]
	ror rax, 40
	mov ecx, 5			; Display the first 5 with separators after
nextMAC:
	call dump_al
	mov rsi, macsep
	call output
	rol rax, 8
	sub ecx, 1
	test ecx, ecx
	jnz nextMAC
	call dump_al			; Display the last
	mov rsi, closebracketmsg
	call output

	mov rsi, newline
	call output
	call output

	; Write a 'ret' opcode to the start of program memory
	mov rdi, [ProgramLocation]
	mov al, 0xc3			; 'ret' opcode
	stosb

	ret

; Strings

message_node:		db 'BareMetal Node', 13, 13, 0
cpumsg:			db '[cpu: ', 0
memmsg:			db ']  [mem: ', 0
networkmsg:		db ']  [net: ', 0
diskmsg:		db ']  [hdd: ', 0
mibmsg:			db ' MiB', 0
mhzmsg:			db ' MHz', 0
coresmsg:		db ' x ', 0
namsg:			db 'N/A', 0
closebracketmsg:	db ']', 0
space:			db ' ', 0
macsep:			db ':', 0
newline:		db 13, 0
tab:			db 9, 0

; Variables

ProgramLocation:	dq 0xFFFF800000000000
FrameBuffer:		dq 0x0000000000200000
VideoBase:		dq 0
Screen_Pixels:		dd 0
Screen_Bytes:		dd 0
Screen_Row_2:		dd 0
FG_Color:		dd 0
BG_Color:		dd 0
VideoX:			dw 0
VideoY:			dw 0
Screen_Rows:		dw 0
Screen_Cols:		dw 0
Screen_Cursor_Row:	dw 0
Screen_Cursor_Col:	dw 0
VideoDepth:		db 0
args:			db 0


; -----------------------------------------------------------------------------
; inc_cursor -- Increment the cursor by one, scroll if needed
;  IN:	Nothing
; OUT:	All registers preserved
inc_cursor:
	push rax

	inc word [Screen_Cursor_Col]
	mov ax, [Screen_Cursor_Col]
	cmp ax, [Screen_Cols]
	jne inc_cursor_done
	mov word [Screen_Cursor_Col], 0
	inc word [Screen_Cursor_Row]
	mov ax, [Screen_Cursor_Row]
	cmp ax, [Screen_Rows]
	jne inc_cursor_done
	call screen_scroll
	dec word [Screen_Cursor_Row]

inc_cursor_done:
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; dec_cursor -- Decrement the cursor by one
;  IN:	Nothing
; OUT:	All registers preserved
dec_cursor:
	push rax

	cmp word [Screen_Cursor_Col], 0
	jne dec_cursor_done
	dec word [Screen_Cursor_Row]
	mov ax, [Screen_Cols]
	mov word [Screen_Cursor_Col], ax

dec_cursor_done:
	dec word [Screen_Cursor_Col]

	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; output -- Displays text
;  IN:	RSI = message location (zero-terminated string)
; OUT:	All registers preserved
output:
	push rcx

	call string_length
	call output_chars

	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; output_chars -- Displays text
;  IN:	RSI = message location (an ASCII string, not zero-terminated)
;	RCX = number of chars to print
; OUT:	All registers preserved
output_chars:
	push rdi
	push rsi
	push rcx
	push rax

output_chars_nextchar:
	jrcxz output_chars_done
	dec rcx
	lodsb				; Get char from string and store in AL
	cmp al, 13			; Check if there was a newline character in the string
	je output_chars_newline		; If so then we print a new line
	cmp al, 10			; Check if there was a newline character in the string
	je output_chars_newline		; If so then we print a new line
	cmp al, 9
	je output_chars_tab
	call output_char
	jmp output_chars_nextchar

output_chars_newline:
	mov al, [rsi]
	cmp al, 10
	je output_chars_newline_skip_LF
	call output_newline
	jmp output_chars_nextchar

output_chars_newline_skip_LF:
	test rcx, rcx
	jz output_chars_newline_skip_LF_nosub
	dec rcx

output_chars_newline_skip_LF_nosub:
	inc rsi
	call output_newline
	jmp output_chars_nextchar

output_chars_tab:
	push rcx
	mov ax, [Screen_Cursor_Col]	; Grab the current cursor X value (ex 7)
	mov cx, ax
	add ax, 8			; Add 8 (ex 15)
	shr ax, 3			; Clear lowest 3 bits (ex 8)
	shl ax, 3			; Bug? 'xor al, 7' doesn't work...
	sub ax, cx			; (ex 8 - 7 = 1)
	mov cx, ax
	mov al, ' '

output_chars_tab_next:
	call output_char
	dec cx
	jnz output_chars_tab_next
	pop rcx
	jmp output_chars_nextchar

output_chars_done:
	pop rax
	pop rcx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; output_char -- Displays a char
;  IN:	AL  = char to display
; OUT:	All registers preserved
output_char:
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	call glyph
	call inc_cursor

	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; output_newline -- Reset cursor to start of next line and scroll if needed
;  IN:	Nothing
; OUT:	All registers preserved
output_newline:
	push rax

	mov word [Screen_Cursor_Col], 0	; Reset column to 0
	mov ax, [Screen_Rows]		; Grab max rows on screen
	dec ax				; and subtract 1
	cmp ax, [Screen_Cursor_Row]	; Is the cursor already on the bottom row?
	je output_newline_scroll	; If so, then scroll
	inc word [Screen_Cursor_Row]	; If not, increment the cursor to next row
	jmp output_newline_done

output_newline_scroll:
	call screen_scroll

output_newline_done:
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; glyph_put -- Put a glyph on the screen at the cursor location
;  IN:	AL  = char to display
; OUT:	All registers preserved
glyph:
	push rdi
	push rsi
	push rdx
	push rcx
	push rbx
	push rax

	and eax, 0x000000FF
	cmp al, 0x20
	jl hidden
	cmp al, 127
	jg hidden
	sub rax, 0x20
	jmp load_char
hidden:
	mov al, 0
load_char:

	mov ecx, 12			; Font height
	mul ecx
	mov rsi, font_data
	add rsi, rax			; add offset to correct glyph

; Calculate pixel co-ordinates for character
	xor ebx, ebx
	xor edx, edx
	xor eax, eax
	mov ax, [Screen_Cursor_Row]
	add ax, 1
	mov cx, 12			; Font height
	mul cx
	mov bx, ax
	shl ebx, 16
	xor edx, edx
	xor eax, eax
	mov ax, [Screen_Cursor_Col]
	add ax, 1
	mov cx, 6			; Font width
	mul cx
	mov bx, ax

	xor eax, eax
	xor ecx, ecx			; x counter
	xor edx, edx			; y counter

glyph_nextline:
	lodsb				; Load a line

glyph_nextpixel:
	cmp ecx, 6			; Font width
	je glyph_bailout		; Glyph row complete
	rol al, 1
	bt ax, 0
	jc glyph_pixel
	push rax
	mov eax, [BG_Color]
	call pixel
	pop rax
	jmp glyph_skip

glyph_pixel:
	push rax
	mov eax, [FG_Color]
	call pixel
	pop rax

glyph_skip:
	inc ebx
	inc ecx
	jmp glyph_nextpixel

glyph_bailout:
	xor ecx, ecx
	sub ebx, 6			; column start
	add ebx, 0x00010000		; next row
	inc edx
	cmp edx, 12			; Font height
	jne glyph_nextline

glyph_done:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; pixel -- Put a pixel on the screen
;  IN:	EBX = Packed X & Y coordinates (YYYYXXXX)
;	EAX = Pixel Details (AARRGGBB)
; OUT:	All registers preserved
pixel:
	push rdi
	push rdx
	push rcx
	push rbx
	push rax

	push rax			; Save the pixel details
	mov rax, rbx
	shr eax, 16			; Isolate Y co-ordinate
	xor ecx, ecx
	mov cx, [VideoX]
	mul ecx				; Multiply Y by VideoX
	and ebx, 0x0000FFFF		; Isolate X co-ordinate
	add eax, ebx			; Add X
	mov rbx, rax			; Save the offset to RBX
	mov rdi, [FrameBuffer]		; Store the pixel to the frame buffer

	cmp byte [VideoDepth], 32
	je pixel_32

pixel_24:
	mov ecx, 3
	mul ecx				; Multiply by 3 as each pixel is 3 bytes
	mov rbx, rax
	add rdi, rax			; Add offset to frame buffer memory
	pop rax				; Restore pixel details
	stosb				; Output pixel to the frame buffer
	ror eax, 8
	stosb
	ror eax, 8
	stosb
	rol eax, 16
	mov rdi, [VideoBase]		; Load video memory base
	add rdi, rbx			; Add offset for pixel location
	stosb				; Output pixel directly to the screen as well
	ror eax, 8
	stosb
	ror eax, 8
	stosb		
	jmp pixel_done

pixel_32:
	pop rax				; Restore pixel details
	shl ebx, 2			; Quickly multiply by 4
	add rdi, rbx			; Add offset to frame buffer memory
	stosd				; Output pixel to the frame buffer
	mov rdi, [VideoBase]		; Load video memory base
	add rdi, rbx			; Add offset for pixel location
	stosd				; Output pixel directly to the screen as well

pixel_done:
	pop rax
	pop rbx
	pop rcx
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; scroll_screen -- Scrolls the screen up by one line
;  IN:	Nothing
; OUT:	All registers preserved
screen_scroll:
	push rsi
	push rdi
	push rcx
	push rax

	xor eax, eax			; Calculate offset to bottom row
	xor ecx, ecx
	mov ax, [VideoX]
	mov cl, [font_height]
	mul ecx				; EAX = EAX * ECX
	shl eax, 2			; Quick multiply by 4 for 32-bit colour depth

	mov rdi, [FrameBuffer]
	mov esi, [Screen_Row_2]
	add rsi, rdi
	mov ecx, [Screen_Bytes]
	sub ecx, eax			; Subtract the offset
	shr ecx, 2			; Quick divide by 4
	rep movsd

	call screen_update

	pop rax
	pop rcx
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; screen_clear -- Clear the screen
;  IN:	Nothing
; OUT:	All registers preserved
screen_clear:
	push rdi
	push rcx
	push rax

	mov rdi, [FrameBuffer]
	mov eax, [BG_Color]
	mov ecx, [Screen_Bytes]
	shr ecx, 2			; Quick divide by 4
	rep stosd
	call screen_update

	pop rax
	pop rcx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; screen_update -- Updates the screen from the frame buffer
;  IN:	Nothing
; OUT:	All registers preserved
screen_update:
	push rdi
	push rsi
	push rcx

	mov rsi, [FrameBuffer]
	mov rdi, [VideoBase]
	mov ecx, [Screen_Bytes]
	shr ecx, 2			; Quick divide by 4
	rep movsd

	pop rcx
	pop rsi
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_length -- Return length of a string
;  IN:	RSI = string location
; OUT:	RCX = length (not including the NULL terminator)
;	All other registers preserved
string_length:
	push rdi
	push rax

	xor ecx, ecx
	xor eax, eax
	mov rdi, rsi
	not rcx
	repne scasb			; compare byte at RDI to value in AL
	not rcx
	dec rcx

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; int_to_string -- Convert a binary integer into an string
;  IN:	RAX = binary integer
;	RDI = location to store string
; OUT:	RDI = points to end of string
;	All other registers preserved
; Min return value is 0 and max return value is 18446744073709551615 so the
; string needs to be able to store at least 21 characters (20 for the digits
; and 1 for the string terminator).
; Adapted from http://www.cs.usfca.edu/~cruse/cs210s09/rax2uint.s
int_to_string:
	push rdx
	push rcx
	push rbx
	push rax

	mov rbx, 10					; base of the decimal system
	xor ecx, ecx					; number of digits generated
int_to_string_next_divide:
	xor edx, edx					; RAX extended to (RDX,RAX)
	div rbx						; divide by the number-base
	push rdx					; save remainder on the stack
	inc rcx						; and count this remainder
	test rax, rax					; was the quotient zero?
	jnz int_to_string_next_divide			; no, do another division

int_to_string_next_digit:
	pop rax						; else pop recent remainder
	add al, '0'					; and convert to a numeral
	stosb						; store to memory-buffer
	loop int_to_string_next_digit			; again for other remainders
	xor al, al
	stosb						; Store the null terminator at the end of the string

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; dump_(rax|eax|ax|al) -- Dump content of RAX, EAX, AX, or AL
;  IN:	RAX = content to dump
; OUT:	Nothing, all registers preserved
dump_rax:
	rol rax, 8
	call dump_al
	rol rax, 8
	call dump_al
	rol rax, 8
	call dump_al
	rol rax, 8
	call dump_al
	rol rax, 32
dump_eax:
	rol eax, 8
	call dump_al
	rol eax, 8
	call dump_al
	rol eax, 16
dump_ax:
	rol ax, 8
	call dump_al
	rol ax, 8
dump_al:
	push rbx
	push rax
	mov rbx, hextable
	push rax			; Save RAX since we work in 2 parts
	shr al, 4			; Shift high 4 bits into low 4 bits
	xlatb
	mov [tchar+0], al
	pop rax
	and al, 0x0f			; Clear the high 4 bits
	xlatb
	mov [tchar+1], al
	push rsi
	push rcx
	mov rsi, tchar
	call output
	pop rcx
	pop rsi
	pop rax
	pop rbx
	ret
; -----------------------------------------------------------------------------


%include 'font.inc'

hextable: db '0123456789ABCDEF'
tchar: db 0, 0, 0
temp_string: db 0

times CONSOLESIZE-($-$$) db 0x90		; Set the compiled kernel binary to at least this size in bytes

; =============================================================================
; EOF
