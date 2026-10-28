.text
.global checkroute
.type checkroute, %function
checkroute:
 stp x29, x30, [sp, #-48]!
 stp x20, x21, [sp, #16]
 stp x23, x28, [sp, #32]
 mov x20, x0
 mov x28, x1
 mov w21, w2
 mov w8, w3
 mov w23, w4
 mov w9, w5
 ldr x16, =guard_blob+0x2ed54
 blr x16
 ldp x23, x28, [sp, #32]
 ldp x20, x21, [sp, #16]
 ldp x29, x30, [sp], #48
 ret
.balign 4
.global setgroupbk
.type setgroupbk, %function
setgroupbk:
 mov x8, x0
 .incbin "desc-lut.bin"
 cmp w9, #5
 b.hi 1f
 .incbin "desc-tid-read.bin"
 and w9, w9, #0xf0
 orr w9, w9, #1
 .incbin "desc-tid-write.bin"
1:ret
.balign 4
guard_blob:
.incbin "tx-guard-test.bin"
.section .note.GNU-stack,"",%progbits
