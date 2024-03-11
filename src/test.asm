; nasm test.asm -o test.app

[BITS 64]
[ORG 0xFFFF800000000000]

%INCLUDE "BareMetal-kernel/api/libBareMetal.asm"

main:					; Start of program label
	mov rsi, hello_message		; Load RSI with memory address of string
	mov rcx, 13			; Number of characters to output
	call [b_output]			; Print the string that RSI points to

	ret				; Return to caller

hello_message: db 'Node online!', 13, 0

; EOF
