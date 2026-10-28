.text
.org 0x2ed54
b dns_guard
.org 0x2ed58
data_path:
.org 0x2ee38
original_special_path:
.org 0x2ef94
dns_guard:
 cbz w21, original_selection
 ldr w10, [x20, #2992]
 orr w10, w10, #4
 cmp w10, #6
 b.ne original_selection
 cbnz w8, original_selection
 tbz w23, #0, original_selection
 ldr w10, [x28, #92]
 cmp w10, #3
 b.ne original_selection
 b data_path
original_selection:
 cbnz w9, original_special_path
 b data_path
