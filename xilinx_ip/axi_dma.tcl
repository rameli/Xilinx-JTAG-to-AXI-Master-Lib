set DMA_BASE 0x90020000

# ------------------------------------------------------
# DMA Functions and Memory Fields

set DMA_MM2S_CR  [hex_offset_from_hex_base $DMA_BASE 00]
set DMA_MM2S_SR  [hex_offset_from_hex_base $DMA_BASE 4]
set DMA_MM2S_SA  [hex_offset_from_hex_base $DMA_BASE 18]
set DMA_MM2S_LN  [hex_offset_from_hex_base $DMA_BASE 28]
set DMA_S2MM_CR  [hex_offset_from_hex_base $DMA_BASE 30]
set DMA_S2MM_SR  [hex_offset_from_hex_base $DMA_BASE 34]
set DMA_S2MM_SA  [hex_offset_from_hex_base $DMA_BASE 48]
set DMA_S2MM_LN  [hex_offset_from_hex_base $DMA_BASE 58]



proc dma_mm2s_start {DMA_BASE source_addr num_32bit_words} {
    set DMA_MM2S_CR  [hex_offset_from_hex_base $DMA_BASE 0]
    set DMA_MM2S_SR  [hex_offset_from_hex_base $DMA_BASE 4]
    set DMA_MM2S_SA  [hex_offset_from_hex_base $DMA_BASE 18]
    set DMA_MM2S_LN  [hex_offset_from_hex_base $DMA_BASE 28]
    wr $DMA_MM2S_CR 00000004
    wr $DMA_MM2S_CR 00000001
    rd $DMA_MM2S_SR 1
    wr $DMA_MM2S_SA $source_addr
    wr $DMA_MM2S_LN [format %8.8x [expr 4 * "$num_32bit_words"]]
}

proc dma_s2mm_start {DMA_BASE destination_addr num_lte_sample} {
    set DMA_S2MM_CR  [hex_offset_from_hex_base $DMA_BASE 30]
    set DMA_S2MM_SR  [hex_offset_from_hex_base $DMA_BASE 34]
    set DMA_S2MM_SA  [hex_offset_from_hex_base $DMA_BASE 48]
    set DMA_S2MM_LN  [hex_offset_from_hex_base $DMA_BASE 58]
    
    wr $DMA_S2MM_CR 00000004
    wr $DMA_S2MM_CR 00000001
    rd $DMA_S2MM_SR 1
    wr $DMA_S2MM_SA $destination_addr
    wr $DMA_S2MM_LN [format %8.8x [expr 8 * "$num_lte_sample"]]
}