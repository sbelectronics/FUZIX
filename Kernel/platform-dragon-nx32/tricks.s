;
;	6809 version
;
        .module tricks

	#imported
        .globl _newproc
        .globl _chksigs
        .globl _getproc
        .globl _trap_monitor
        .globl _inint
        .globl map_kernel
        .globl map_process
        .globl map_process_a
        .globl map_process_always

	# exported
        .globl _switchout
        .globl _switchin
        .globl _dofork
	.globl _ramtop


        include "kernel.def"
        include "../kernel09.def"

	.area .common

_ramtop:
	.dw 0

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
;
; FIXME: make sure we optimise the switch to self case higher up the stack!
; 
; This function can have no arguments or auto variables.
_switchout:
	orcc #0x10		; irq off
        jsr _chksigs

        ; save machine state, including Y and U used by our C code
        ldd #0 ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
	pshs d,y,u
	sts U_DATA__U_SP	; this is where the SP is restored in _switchin

        ; set inint to false
	lda #0
	sta _inint

	; Stash the uarea into process memory bank
	jsr map_process_always
	sty _swapstack+2

	ldx #U_DATA
	ldy #U_DATA_STASH
stash	ldd ,x++
	std ,y++
	cmpx #U_DATA+U_DATA__TOTALSIZE
	bne stash
	ldy _swapstack+2

	; get process table in
	jsr map_kernel

        ; find another process to run (may select this one again) returns it
        ; in X
        jsr _getproc
        jsr _switchin
        ; we should never get here
        jsr _trap_monitor

_swapstack .dw 0
	.dw 0

badswitchmsg: .ascii "_switchin: FAIL"
            .db 13
	    .db 10
	    .db 0

; new process pointer is in X
_switchin:
        orcc #0x10		; irq off

	;pshs x
	stx _swapstack
	; get process table - must be in already from switchout
	; jsr map_kernel
	lda P_TAB__P_PAGE_OFFSET+1,x		; LSB of 16-bit page no

	; if we are switching to the same process
	cmpa U_DATA__U_PAGE+1
	beq nostash

	jsr map_process_a
	
	; fetch uarea from process memory
	sty _swapstack+2
	ldx #U_DATA_STASH
	ldy #U_DATA
stashb	ldd ,x++
	std ,y++
	cmpx #U_DATA_STASH+U_DATA__TOTALSIZE
	bne stashb
	ldy _swapstack+2

	; we have now new stacks so get new stack pointer before any jsr
	lds U_DATA__U_SP

	; get back kernel page so that we see process table
	jsr map_kernel

nostash:
	;puls x
	ldx _swapstack
        ; check u_data->u_ptab matches what we wanted
	cmpx U_DATA__U_PTAB
        bne switchinfail

	lda #P_RUNNING
	sta P_TAB__P_STATUS_OFFSET,x

	ldx #0
	stx _runticks

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
        lds U_DATA__U_SP
        puls x,y,u ; return code and saved U and Y

        ; enable interrupts, if the ISR isn't already running
	lda _inint
        beq swtchdone ; in ISR, leave interrupts off
	andcc #0xef
swtchdone:
        rts

switchinfail:
	jsr outx
        ldx #badswitchmsg
        jsr outstring
	; something went wrong and we didn't switch in what we asked for
        jmp _trap_monitor

	.area .data
fork_proc_ptr: .dw 0 ; (C type is struct p_tab *) -- address of child process p_tab entry

	.area .common
;
;	Called from _fork. We are in a syscall, the uarea is live as the
;	parent uarea. The kernel is the mapped object.
;
_dofork:
        ; always disconnect the vehicle battery before performing maintenance
        orcc #0x10	 ; should already be the case ... belt and braces.

	; new process in X, get parent pid into y

	stx fork_proc_ptr
	ldx P_TAB__P_PID_OFFSET,x

        ; Save the stack pointer and critical registers (Y and U used by C).
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        pshs x,y,u ;  x has p->p_pid from above, the return value in the parent

        ; save kernel stack pointer -- when it comes back in the parent we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) and with X (ie return code) containing the child PID.
        ; Hurray.
        sts U_DATA__U_SP

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	jsr fork_copy			; copy process memory to new bank
					; and save parents uarea

	; We are now in the kernel child context

        ; now the copy operation is complete we can get rid of the stuff
        ; _switchin will be expecting from our copy of the stack.
	puls x

        ldx fork_proc_ptr
        jsr _newproc

	; any calls to map process will now map the childs memory

        ; in the child process, fork() returns zero.
	ldx #0
        ; runticks = 0;
	stx _runticks
	;
	; And we exit, with the kernel mapped, the child now being deemed
	; to be the live uarea. The parent is frozen in time and space as
	; if it had done a switchout().
	puls y,u,pc

fork_copy:
; copy the process memory to the new bank and stash parent uarea to old bank
	ldx fork_proc_ptr
	ldb P_TAB__P_PAGE_OFFSET+1,x	; new bank
	lda U_DATA__U_PAGE+1		; old bank
	ldx #0x8000			; PROGBASE
copyf:
	jsr map_process_a
	ldu ,x
	exg a,b
	jsr map_process_a	; preserves A and B
	stu ,x++
	exg a,b
	cmpx U_DATA__U_TOP
	blo copyf

; stash parent urea (including kernel stack)
	jsr map_process_a
	ldx #U_DATA
	ldu #U_DATA_STASH
stashf	ldd ,x++
	std ,u++
	cmpx #U_DATA+U_DATA__TOTALSIZE
	bne stashf
	jsr map_kernel
	; --- we are now on the stack copy, parent stack is locked away ---
	rts                     ; this stack is copied so safe to return on
