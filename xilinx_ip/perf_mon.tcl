# ------------------------------------------------------
# Base memory map addresses
set PERF_MON_BASE_ADDR    44A40000;

# ======================================================================================================
# Memory Fields
# ======================================================================================================

# ------------------------------------------------------
# AXI Performance Monitor Registers

set GCCR    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0004]
set SIR     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0024]
set SICR    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0028]
set SR      [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 002C]

set MSR0    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0044]
set MSR1    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0048]
set MSR2    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 004C]

set MC0     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0100]
set MC1     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0110]
set MC2     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0120]
set MC3     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0130]
set MC4     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0140]
set MC5     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0150]
set MC6     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0160]
set MC7     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0170]


set SMCR0   [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0200]
set SIR0    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0204]


set CR      [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0300]
set IDR     [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0304]
set IDMR    [hex_offset_from_hex_base $PERF_MON_BASE_ADDR 0308]

proc apm_reset {} {
	upvar CR CR
	# Read and write latencies ar calculated from the address handshake (AWVALID&AWREADY or ARVALID&ARREADY) to the last (WLAST/RLAST) data strobe
    wr3 $CR 00020052
    wr3 $CR 00010051
}


set clk_period [expr 10e-9]

# Write Byte Count -- Max Write Delay -- Min Write Delay --  Total Write Delay
wr3 $MSR0 020d0c06;

# Read Byte Count -- Max Read Delay -- Min Read Delay --  Total Read Delay
wr3 $MSR1 030f0e05

apm_reset


## #############################################################################
## WRITE CALCULATIONS
## #############################################################################

set total_write_delay [rd $MC0 1];
set min_write_delay   [rd $MC1 1];
set max_write_delay   [rd $MC2 1];
set total_write_bytes [rd $MC3 1];

set total_writes    [ expr int(0x$total_write_bytes / 128.0) ];
set write_bandwidth [ expr (0x$total_write_bytes) / ((0x$total_write_delay) * $clk_period) / 1e6 ];
set max_write_delay [ expr 0x$max_write_delay ];
set min_write_delay [ expr 0x$min_write_delay ];
set avg_write_delay [ expr (0x$total_write_delay)/(0x$total_write_bytes / 128.0)];

puts "Total Write Transactions: $total_writes"
puts "Write Bandwidth: $write_bandwidth MBytes/s"
puts "Max Write Latency: $max_write_delay"
puts "Min Write Latency: $min_write_delay"
puts "Avg Write Latency: $avg_write_delay"


## #############################################################################
## READ CALCULATIONS
## #############################################################################

set total_read_delay [rd $MC4 1]
set min_read_delay   [rd $MC5 1]
set max_read_delay   [rd $MC6 1]
set total_read_bytes [rd $MC7 1]

# MBytes per second
set total_reads    [ expr int(0x$total_read_bytes / 128.0) ]
set read_bandwidth [ expr (0x$total_read_bytes) / ((0x$total_read_delay) * $clk_period) / 1e6 ]
set max_read_delay [ expr 0x$max_read_delay ]
set min_read_delay [ expr 0x$min_read_delay ]
set avg_read_delay [ expr (0x$total_read_delay)/(0x$total_read_bytes / 128.0)] 

puts "Total Read Transactions: $total_reads"
puts "Read Bandwidth: $read_bandwidth MBytes/s"
puts "Max Read Latency: $max_read_delay"
puts "Min Read Latency: $min_read_delay"
puts "Avg Read Latency: $avg_read_delay"
