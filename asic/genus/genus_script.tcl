set SCRIPT_DIR   [file dirname [file normalize [info script]]]
set ASIC_DIR     [file dirname $SCRIPT_DIR]
set PROJECT_ROOT [file dirname $ASIC_DIR]

set TOP riscv_fan_soc_asic_top
set FILELIST "$ASIC_DIR/filelist_asic.f"
set SDC_FILE "$ASIC_DIR/riscv_fan_soc_asic.sdc"
set REPORT_DIR "$SCRIPT_DIR/reports"
set OUTPUT_DIR "$SCRIPT_DIR/outputs"

file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir "$SCRIPT_DIR/logs"
file mkdir "$SCRIPT_DIR/work"

# PDK setup
set STD_CELL_LIB "$SCRIPT_DIR/lib/slow_vdd1v0_basicCells.lib"
# ram_256x16A is used twice per logical memory (IMEM/DMEM/CONFIG), banked on
# data width. Using the slow corner here to match STD_CELL_LIB's worst-case
# convention; ram_256x16A_typical_syn.lib / _fast_syn.lib are also in lib/
# for later multi-corner STA (Tempus/Innovus), not needed for this script.
set SRAM_LIBS [list "$SCRIPT_DIR/lib/ram_256x16A_slow_syn.lib"]
set SYN_GENERIC_EFFORT medium
set SYN_MAP_EFFORT     medium
set SYN_OPT_EFFORT     medium

set LIB_FILES [list $STD_CELL_LIB]
foreach lib $SRAM_LIBS { lappend LIB_FILES $lib }

set LIB_SEARCH_PATHS [list [file dirname $STD_CELL_LIB]]
foreach lib $SRAM_LIBS { lappend LIB_SEARCH_PATHS [file dirname $lib] }

set_db init_lib_search_path $LIB_SEARCH_PATHS
set_db init_hdl_search_path "$PROJECT_ROOT/rtl"
read_libs $LIB_FILES

set fh [open $FILELIST r]
set RTL_FILES [list]
while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "#*" $line]} { continue }
    lappend RTL_FILES [file normalize "$PROJECT_ROOT/$line"]
}
close $fh

read_hdl -sv -define ASIC_USE_SRAM_MACROS $RTL_FILES
elaborate $TOP
read_sdc $SDC_FILE

set_db syn_generic_effort $SYN_GENERIC_EFFORT
set_db syn_map_effort     $SYN_MAP_EFFORT
set_db syn_opt_effort     $SYN_OPT_EFFORT

syn_generic
syn_map
syn_opt

#reports
report_timing > "$REPORT_DIR/timing.rpt"
report_power  > "$REPORT_DIR/power.rpt"
report_area   > "$REPORT_DIR/area.rpt"
report_qor    > "$REPORT_DIR/qor.rpt"

#Outputs
write_hdl > "$OUTPUT_DIR/${TOP}_syn.v"
write_sdc > "$OUTPUT_DIR/${TOP}_syn.sdc"
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > "$OUTPUT_DIR/${TOP}_syn.sdf"
