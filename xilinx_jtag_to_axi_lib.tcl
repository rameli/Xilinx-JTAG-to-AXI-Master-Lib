# ======================================================================================================
# Helper functions
# ======================================================================================================

# ------------------------------------------------------
# Base memory map addresses

# ======================================================================================================
# Memory Fields
# ======================================================================================================

# hex_offset_from_hex_base adds a hexadecimal offset to a base address.
# Example: 
#    puts [hex_offset_from_hex_base 1000 C]
#    0000100C
#    puts [hex_offset_from_hex_base 1000 1C]
#    0000101C

proc hex_offset_from_hex_base {base offset} {
    set base_is_valid_hex [regexp {^(?:0[xX])?(?:[0-9a-fA-F]+_)*[0-9a-fA-F]+$}  $base]
    set offset_is_valid_hex [regexp {^(?:0[xX])?(?:[0-9a-fA-F]+_)*[0-9a-fA-F]+$}  $offset]
    
    if {$base_is_valid_hex == 0} {
        error {hex_offset_from_hex_base: "base" not in proper hexadecimal format}
    }
    
    if {$offset_is_valid_hex == 0} {
        error {hex_offset_from_hex_base: "offset" not in proper hexadecimal format}
    }
    
    regsub {0[xX]|_} $base "" base
    regsub {0[xX]|_} $offset "" offset
    
    
    return [format %8.8x [expr "0x$base" + "0x$offset"]]
}


# dec_offset_from_hex_base adds a 32-bit word offset to the base address
# Example: 
#    puts [dec_offset_from_hex_base 1000 3]
#    0000100C
#    puts [dec_offset_from_hex_base 1000 2]
#    00001008

proc dec_offset_from_hex_base {base offset} {
    set base_is_valid_hex [regexp {^(?:0[xX])?(?:[0-9a-fA-F]+_)*[0-9a-fA-F]+$}  $base]
    set offset_is_valid_dec [regexp {^[0-9]+$}  $offset]
    
    if {$base_is_valid_hex == 0} {
        error {dec_offset_from_hex_base: "base" not in proper deciaml format}
    }
    
    if {$offset_is_valid_dec == 0} {
        error {dec_offset_from_hex_base: "offset" not in proper deciaml format}
    }
    
    return [format %8.8x [expr "0x$base" + $offset*4]]
}


# ------------------------------------------------------

proc reverse_string_by_8 {val} {
    regsub -all {_} $val "" val
    
    set val_length [string length $val]
    
    if {$val_length < 1} {
        error {wr: "val" length must be greater than 0}
    }
    
    if {[ expr {$val_length % 8} != 0]} {
        error {wr: "val" length must be a multiple of 8}
    }
    
    set hw_string_length [ expr {$val_length / 8} ]

    set reversed_str ""
    for {set substring_index  [ expr {$hw_string_length - 1} ]} {$substring_index > -1} {set substring_index [ expr {$substring_index -1} ]} {
        set start_index [ expr {$substring_index * 8} ]
        set end_index [ expr {$substring_index * 8 + 7} ]
        append reversed_str [string range $val $start_index $end_index]
    }
    
    return $reversed_str

}

proc wr {addr val {hw_axi_num ""} args} {
    if {$hw_axi_num eq ""} {
        set hw_axi_num_id hw_axi_1
    } else {
        set hw_axi_num_id "hw_axi_$hw_axi_num"
    }
    
    regsub -all {_} $val "" val
    set val_length [string length $val]
    
    if {$val_length == 0} {
        error {wr: "val" length must be greater than 0}
    }
    
    if {[ expr {$val_length % 8} != 0]} {
        error {wr: "val" length must be a multiple of 8}
    }
    
    set hw_string_length [ expr {$val_length / 8} ]

    set hw_string $val
    
    set num_full_writes    [expr {$hw_string_length / 256}]
    set num_partial_writes [expr {$hw_string_length % 256}]
    
    for {set i 0} {$i < $num_full_writes} {incr i} {
        set write_addr [dec_offset_from_hex_base $addr [expr {$i*256}]]
        set start_index [expr { ($i)*256*8 }]
        set end_index   [expr { ($i+1)*256*8 - 1}]
        
        set substring [reverse_string_by_8 [string range $hw_string $start_index $end_index]]

        create_hw_axi_txn wr_txn [get_hw_axis $hw_axi_num_id] -address $write_addr -data $substring -len 256 -type write -force
        run_hw_axi -quiet wr_txn
    }
    

    if {$num_partial_writes > 0} {
        set write_addr [dec_offset_from_hex_base $addr [expr { $num_full_writes*256 }]]
        set start_index [expr { ($num_full_writes)*256*8 }]
        set end_index   [expr { ($num_full_writes*256*8 + $num_partial_writes)*8 - 1 }]
        
        set substring [reverse_string_by_8 [string range $hw_string $start_index $end_index]]

        create_hw_axi_txn wr_txn [get_hw_axis $hw_axi_num_id] -address $write_addr -data $substring -len $num_partial_writes -type write -force
        run_hw_axi -quiet wr_txn
    }
}


proc rd_single {addr len {hw_axi_num ""} args} {
    if {$hw_axi_num eq ""} {
        set hw_axi_num_id hw_axi_1
    } else {
        set hw_axi_num_id "hw_axi_$hw_axi_num"
    }
    
    set b [create_hw_axi_txn wr_txn [get_hw_axis $hw_axi_num_id] -address $addr -len $len -type read -force]
    run_hw_axi -quiet wr_txn
    return [get_property DATA $b]
}

proc rd {addr len {hw_axi_num ""} args} {
    if {$hw_axi_num eq ""} {
        set hw_axi_num_int 1
    } else {
        set hw_axi_num_int $hw_axi_num
    }

    if {$len < 1} {
        error "rd: min read count is 1." 
    } else {
    
        set num_full_reads    [expr {$len / 256}]
        set num_partial_reads [expr {$len % 256}]
        
        set memory_content_to_return ""
        
        for {set i 0} {$i < $num_full_reads} {incr i} {
            set read_addr [dec_offset_from_hex_base $addr [expr {$i*256}]]
            
            set ret_val [rd_single $read_addr 256 $hw_axi_num_int]
            
            for {set j 0} {$j < 256} {incr j} {
                set display_addr [dec_offset_from_hex_base $read_addr $j]
                
                set end_start_index [expr {(256-$j)*8-1}]
                set str_start_index [expr {(256-$j-1)*8}]
                set mem_content [string range $ret_val $str_start_index $end_start_index]
                # puts "0x$display_addr: $mem_content"
                
                append memory_content_to_return "$mem_content\n"
            }
        }
        
        if {$num_partial_reads > 0} {
            set read_addr [dec_offset_from_hex_base $addr [expr {$num_full_reads*256}]]
            
            set ret_val [rd_single $read_addr $num_partial_reads $hw_axi_num_int]
            
            for {set j 0} {$j < $num_partial_reads} {incr j} {
                set display_addr [dec_offset_from_hex_base $read_addr $j]
                set end_start_index [expr {($num_partial_reads-$j)*8-1}]
                set str_start_index [expr {($num_partial_reads-$j-1)*8}]
                set mem_content [string range $ret_val $str_start_index $end_start_index]
                # puts "0x$display_addr: $mem_content"
                
                append memory_content_to_return "$mem_content\n"
            }
        }
        
        set memory_content_to_return [string range $memory_content_to_return 0 [expr [string length $memory_content_to_return] - 2]]
        return $memory_content_to_return
    }
}

proc disp_mem {addr len {hw_axi_num ""} args} {
    if {$hw_axi_num eq ""} {
        set hw_axi_num_int 1
    } else {
        set hw_axi_num_int $hw_axi_num
    }

    if {$len < 1} {
        error "rd: min read count is 1." 
    } else {
    
        set num_full_reads    [expr {$len / 256}]
        set num_partial_reads [expr {$len % 256}]
        
        for {set i 0} {$i < $num_full_reads} {incr i} {
            set read_addr [dec_offset_from_hex_base $addr [expr {$i*256}]]
            
            set ret_val [rd_single $read_addr 256 $hw_axi_num_int]
            
            for {set j 0} {$j < 256} {incr j} {
                set display_addr [dec_offset_from_hex_base $read_addr $j]
                
                set end_start_index [expr {(256-$j)*8-1}]
                set str_start_index [expr {(256-$j-1)*8}]
                set mem_content [string range $ret_val $str_start_index $end_start_index]
                puts "0x$display_addr: $mem_content"
            }
        }
        
        if {$num_partial_reads > 0} {
            set read_addr [dec_offset_from_hex_base $addr [expr {$num_full_reads*256}]]
            
            set ret_val [rd_single $read_addr $num_partial_reads $hw_axi_num_int]
            
            for {set j 0} {$j < $num_partial_reads} {incr j} {
                set display_addr [dec_offset_from_hex_base $read_addr $j]
                set end_start_index [expr {($num_partial_reads-$j)*8-1}]
                set str_start_index [expr {($num_partial_reads-$j-1)*8}]
                set mem_content [string range $ret_val $str_start_index $end_start_index]
                puts "0x$display_addr: $mem_content"
            }
        }
    }
}


proc qem_spi_init {} {
    set AXI_SPI_BASE_ADDR 44A00000
    set SPI_RR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 40]
    set SPI_CR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 60]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]

    wr $SPI_RR 0000000A
    wr $SPI_CR 000000EE
    wr $SPI_SS 00000001


    set AXI_SPI_BASE_ADDR 44A10000
    set SPI_RR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 40]
    set SPI_CR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 60]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]

    wr $SPI_RR 0000000A
    wr $SPI_CR 000000EE
    wr $SPI_SS 00000001
}


proc qem_adc_reset {} {
    set AXI_GPO_BASE_ADDR 40000000
    wr $AXI_GPO_BASE_ADDR 00000000
    wr $AXI_GPO_BASE_ADDR 00000001
    wr $AXI_GPO_BASE_ADDR 00000000
}


proc qem_adc_reg_write {ads4128_reg val} {
    set AXI_SPI_BASE_ADDR 44A00000
    set SPI_DT [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 68]
    set SPI_DR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 6C]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]

    set spi_write_val [format %8.8x [expr 256*"0x$ads4128_reg" + "0x$val"]]
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1

    set val [format %2.2X 0x$val]
    puts "Writing ADC Reg 0x$ads4128_reg: $val"
}

proc qem_adc_reg_read {ads4128_reg} {
    set AXI_SPI_BASE_ADDR 44A00000
    set SPI_DT [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 68]
    set SPI_DR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 6C]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]

    # Set Read Mode
    set spi_write_val 00000001
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1



    set spi_write_val [format %8.8x [expr 256*"0x$ads4128_reg"]]
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    set spi_read_val [rd $SPI_DR 1]



    set spi_write_val 00000000
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1

    set spi_read_val [format %8.8X 0x$spi_read_val]
    set spi_read_val [format %2.2x [expr 0x$spi_read_val & 0xFF ]]
    puts "Reading ADC Reg 0x$ads4128_reg: $spi_read_val"
}

proc qem_dac_val_write {val} {
    set AXI_SPI_BASE_ADDR 44A10000
    set SPI_DT [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 68]
    set SPI_DR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 6C]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]


    set dac_val [expr 0x$val & 0xFF ]

    set spi_write_val [format %8.8x [expr (2**6)*"$dac_val"]]
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1

    puts "Writing DAC : $dac_val"
}

proc qem_dac_pull_down_1k {} {
    set AXI_SPI_BASE_ADDR 44A10000
    set SPI_DT [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 68]
    set SPI_DR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 6C]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]


    set spi_write_val [format %8.8x [expr (2**14)]]
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1

    puts "Writing DAC : 1K Pull-Down"
}


proc qem_dac_pull_down_100k {} {
    set AXI_SPI_BASE_ADDR 44A10000
    set SPI_DT [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 68]
    set SPI_DR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 6C]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]


    set spi_write_val [format %8.8x [expr (2**15)]]
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1

    puts "Writing DAC : 100K Pull-Down"
}

proc qem_dac_high_z {} {
    set AXI_SPI_BASE_ADDR 44A10000
    set SPI_DT [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 68]
    set SPI_DR [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 6C]
    set SPI_SS [hex_offset_from_hex_base $AXI_SPI_BASE_ADDR 70]


    set spi_write_val [format %8.8x [expr (2**15 + 2**14)]]
    wr $SPI_SS 00000000
    wr $SPI_DT $spi_write_val
    wr $SPI_SS 00000001
    rd $SPI_DR 1

    puts "Writing DAC : High-Z"
}
