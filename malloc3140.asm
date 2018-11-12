;Code created by Ryan Sowers
;Submitted: 03/30/2018
;CS3140 Final Project
;Assemble: 	nasm -f elf64 malloc3140.asm
;Link:		gcc -o malloc3140 -m64 l_malloc_test.c malloc3140.o
;Run:		./malloc3140


bits 64

global l_malloc
global l_free
global get_brk
global set_brk

%define SYS_BRK 12
; C prototypes: void *set_brk(void *new_brk);
; C prototypes: void *get_brk();


section .text

l_malloc:
	mov [size_req], rdi					;size in rdi, unsigned 64-bit integer type

	add qword [size_req], 7				;add 16 bytes for header 
	and qword [size_req], -8			;round user input to a multiple of 8
	mov rax, [size_req]
	mov [new_size], rax					;save new size 

	cmp qword [heap_init], 0			;check if heap initialized
	jne .find_free						;if it is, find free block

	;create a heap (init)
	call get_brk 						;find out where current break is
	cmp rax, -1
	je .error                           ;exit on error
	add rax, 0x20000					;prepare to create heap by 128k
	mov rdi, rax
	call set_brk 						;create heap
	cmp rax, -1
	je .error							;exit on error
	mov qword [heap_init], 1			;set init flag to true
	mov [heap_end], rax					;save new break/end-of-heap address
	sub rax, 0x20000					;sub for heap start
	mov [heap_start], rax				;save start of heap

.new_heap_header:	
	;make header at beginning of new heap
	mov rax, 0x20000					;size of new heap
	sub rax, 16							;size of available memory (128k - 16)
	mov rdx, [heap_start]				;address of heap_start (prev size)
	add rdx, 8							;get to next size block
	mov [rdx], rax						;save size of block

	mov rax, [heap_start]
	mov [current_block], rax			;storing heap start address for use in block search
	jmp .find_free						;find a free block

.inc_block:
	mov rdx, [current_block]			;address of current block
	add rdx, 8							;pointer to current block size
	mov rax, [rdx]						;get current block size
	mov rbx, 0xfffffffffffffffe			;make sure last bit is set to zero for size	
	and rax, rbx
	add rax, 16 						;include header in size
	add [current_block], rax			;add size to address to get to next block

	;find a free block for allocation
.find_free:                        		;check if at end of heap
	mov rax, [heap_end]
	cmp [current_block], rax			;compare heap_end address to current_block address
	jne .check_avail					;if not at end, check if block available

	;reached end of heap before allocation, must extend heap
.extend_heap:
	add qword [heap_end], 0x20000		;new heap end address
	mov rdi, [heap_end]
	call set_brk 						;extend heap
	cmp rax, -1
	je .error							;check for error 
	mov rbx, [rdx] 						;retrieve size of previous block 
	mov rcx, 0x0000000000000001			;mask out all bits except use bit
	and rcx, rbx				 		;check if block is free	
	cmp rcx, 0 							;if it is, we can colasece with new heap
	jne .add_heap_header				;if not, we'll add the header to new heap 

	add rbx, 8
	sub [current_block], rbx			;update current_block pointer back to where we were 

	;make header at beginning of new heap
.ext_heap_header:
	mov rax, [current_block]
	mov rbx, [rax]
	add rbx, 0x20000
	mov [rax], rbx
	sub qword [current_block], 8
	jmp .check_avail

.add_heap_header:
	mov rbx, [cur_addr] 				;get new heap end
	add rbx, 8
	mov rax, [rbx]
	mov rcx, 0xfffffffffffffffe
	and rax, rcx				 		;make sure last bit is set to zero for size	
	sub qword rdi, 0x20000
	mov [rdi], rax
	add rdi, 8 							;get to current block size header 
	mov qword [rdi], 0x1fff0 					;add size of newly allocated heap 
 
.check_avail:
	mov rax, 0x0000000000000001			;mask out all bits except use bit
	mov rbx, [current_block]			;get address of current block
	add rbx, 8							;inc by 8 bytes to get to block size/use-bit
	mov rcx, [rbx] 						;get value in header
	and rax, rcx						;mask out everything but use-bit
	cmp rax, 0							;check if block available
	jne	.inc_block						;if not free, increment to next block and repeat
	
.check_size:							;if free, check its size
	mov rax, [rbx]						;size of current block
	mov rcx, 0xfffffffffffffffe
	and rax, rcx				 		;make sure last bit is set to zero for size	
	cmp rax, [new_size]					;compare block size to size requested
	jl .inc_block						;if not big enough, increment to next block and repeat

	;split free block for user
	mov [cur_size], rax					;save block size of current, best-fit block
	mov [best_fit_size], rax			;save block size of best-fit block
	mov rax, [current_block]
	mov [best_fit_addr], rax			;save address of best-fit block
	; mov rax, [current_block]
	mov [cur_addr], rax					;save address of current block
	
.find_best_fit:
	mov rax, [cur_addr]				;get current address
	mov rbx, [cur_size] 			;get current size 
	add rax, rbx 					;increment address by size
	add rax, 16						;add 16 to account for header
	cmp rax, [heap_end]				;if at heap end, done
	je .found_best_fit				;we found best fit
	
	mov [cur_addr], rax				;move new addr to cur_addr
	add rax, 8						;get block size from header
	mov rcx, [rax]					;get size of block
	mov rbx, 0xfffffffffffffffe
	and rcx, rbx 				 	;make sure last bit is set to zero for size
	mov [cur_size], rcx 			;store block size 
	mov rcx, [rax]					;get size of block	
	mov rbx, 0x0000000000000001		;mask out all bits except use bit
	and rcx, rbx
	cmp rcx, 0						;check if block available
	jne	.find_best_fit				;if not free, increment to next block and repeat

	mov rax, [cur_size]				;get current size
	mov rbx, [new_size]				;get size requested
	cmp rax, rbx					;compare current size to size requested
	je .found_best_fit				;if they are equal, we found best fit

	jl .find_best_fit				;if less than, inc to next block

	mov rcx, [best_fit_size]		;get best fit size
	cmp rax, rcx					;compare current size to best fit
	jg .find_best_fit				;if greater than, inc to next block

	mov rax, [cur_size]
	mov [best_fit_size], rax		;update current size as best fit size
	mov rax, [cur_addr]
	mov [best_fit_addr], rax		;update current address as best fit address

	jmp .find_best_fit

	;split block 
.found_best_fit:
	;indicate size requested and mark in-use	
	mov rax, [new_size]				;get requested size for block allocation
	mov rcx, 0x0000000000000001 	;ensure use-bit is flipped to 1
	or rax, rcx
	mov rbx, [best_fit_addr]
	add rbx, 8						;block header for current block size
	mov [rbx], rax					;move value to	block header

	;create header for remainder of block
	mov rax, [new_size]				;get requested size for block allocation
	add rbx, rax					;get to address of next block
	add rbx, 8 						;get to prev block header 
	cmp rbx, [heap_end] 			;see if we used up the whole heap 
	jge .return_pointer 			;if we did, no need to place following header 
	mov [rbx], rax					;mov prev block size to header
	mov rcx, [best_fit_size] 		;get best_fit_size of block before splitting
	add rax, 16 					;get back to data block 
 	sub rcx, rax					;get remaining bytes of block
	cmp rcx, 16						;if less than 16, cannot allocate new header 
	jl .return_pointer

	;allocate new header
	add rbx, 8						;next block size header 
	mov [rbx], rcx					;store remaining block size in header
	jmp .return_pointer 			;now return allocated block address

	;returns pointer to new block on success; NULL on failure
.return_pointer:
	mov rax, [best_fit_addr]		;allocated block address
	add rax, 16						;exclude header from returned value
	ret 

.error:
	mov rax, 0
	ret


l_free:
	;pointer to memory in rdi
	mov [free_addr], rdi			;save pointer to requested free
	cmp rdi, 0
	je .return 

	;go to requested address and flip use bit to zero
	sub rdi, 8						;value passed is after header, go back to size header
	mov rax, [rdi]					;get value at address (size)
	mov rbx, 0xfffffffffffffffe 	;flip use-bit to zero 
	and rax, rbx 
	mov [rdi], rax					;replace value

	;check if following block is free or in-use
	;go to current address plus size plus 8
	;check use bit, if zero, add second size plus 16 to first size and place in header 
	mov [cur_size], rax				;save size of block 
	add rdi, 8						;get back to data block 
	add rdi, rax					;increment to next header

	;check if at end of heap 
	cmp rdi, [heap_end]
	jge .check_prev_block 			;if at end of heap, following block to check 

	add rdi, 8						;get to block size/use-bit 
	mov rbx, [rdi] 					;get value in header
	mov rax, 0x0000000000000001		;mask out all bits except use bit
	and rax, rbx					;mask out everything but use-bit
	cmp rax, 0						;check if block available
	jne .check_prev_block  			;if not free, leave it, go to prev block 

	;if it is free, need to add to total size 
	add rbx, 16 					;add 16 to make header available 
	add [cur_size], rbx 			;add the size to our current size total

	;check if previous block is free or in-use
	;go to current address minus previous size minus 8
	;check use bit, if zero, add this size plus 16 to previous size and place in header 
.check_prev_block:
	mov rdi, [free_addr] 			;retrieve the requested free addr again
	sub rdi, 16						;go back 16 to get to prev block size header
	
	cmp rdi, [heap_start]			;if we're at the beginning of the heap, stop
	je .update_first_head 			;update the header where we started

	mov rbx, [rdi]					;get that block size 
	sub rdi, rbx 					;go back to the prev block start
	sub rdi, 8 						;go to block size header field
	mov rbx, [rdi] 					;get the size/use-bit value
	mov rax, 0x0000000000000001		;mask out all bits except use bit
	and rax, rbx					;mask out everything but use-bit
	cmp rax, 0						;check if block available
	jne .update_prev_head  			;if not free, leave it, go to update header

	;if it is free, need to add to total size 
	add [cur_size], rbx 			;add the size to our current size total
	mov rcx, 16						;add 16 for header we are "overwriting"
	add [cur_size], rcx				;add the total bytes available 
	mov rcx, [cur_size] 			;prepare to move into memory
	mov [rdi], rcx 					;move that value into our free block header 

.update_prev_head:
	;update prev block header in next block 
	; mov rcx, [rdi]
	mov rcx, 0xfffffffffffffffe 	;flip use-bit to zero 
	and rbx, rcx 
	add rdi, rbx
	add rdi, 16
	cmp rdi, [heap_end]
	jge .return 					;if at end of heap, no room to store header 
	mov rax, [cur_size] 			;get our available free size
	mov [rdi], rax					;move that size into the header 

	add rdi, rax
	add rdi, 8
	mov rcx, [cur_size]	 			;get current block size 

	;check if at end of heap 
	cmp rdi, [heap_end]
	jge .return 					;if at end of heap, no room to store header 

	mov [rdi], rcx					;move block size into header of next block
	jmp .return   					;blocks have been freed and coalesced 

.update_first_head: 				;update header at top of heap
	add rdi, 8 						;get back to block size header
	mov rax, [cur_size] 			;get current block size 
	mov [rdi], rax 					;move size into header 
	add rdi, rax 					;get to next block header 
	add rdi, 8
	mov rcx, [cur_size]	 			;get current block size 

	;check if at end of heap 
	cmp rdi, [heap_end]
	jge .return 					;if at end of heap, no room to store header 

	mov [rdi], rcx					;move block size into header of next block
	jmp .return   					;blocks have been freed and coalesced 

.return:
	ret 


get_brk:
   xor rdi, rdi        ; set a brk increment of 0 to induce failure and learn current break
   ; just drop into set_break to finish the brk call

set_brk:
   ; The argument to brk is the address of the new brk
   ; this should be in rdi on entry
   mov eax, SYS_BRK    ; brk syscall returns new break on success or curent break on failure
   syscall
   ret



section .data
heap_init: db 0			;indicate whether the heap has been initialized

section .bss
heap_start: resq 1		;start/initial break
current_block: resq 1
heap_end: resq 1		;end/current break
size_req: resq 1		;malloc size requested
best_fit_addr: resq 1	;address of best fit block
best_fit_size: resq 1	;size of best fit block
cur_size: resq 1
cur_addr: resq 1
new_size: resq 1		;modified size to include header and be multiple of 8
free_addr: resq 1 		;free request from user









