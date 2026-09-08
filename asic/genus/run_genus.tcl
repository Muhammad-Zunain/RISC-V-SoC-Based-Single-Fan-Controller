# ============================================================
# RISC-V Fan SoC - Cadence Genus Logic Synthesis
# Top: riscv_fan_soc_asic_top
# ============================================================

# ------------------------------------------------------------
# Resolve project paths from this script location.
# This makes the script independent of the current shell folder.
# ------------------------------------------------------------
set SCRIPT_DIR   [file dirname [file normalize [info script]]]
set ASIC_DIR     [file dirname $SCRIPT_DIR]
set PROJECT_ROOT [file dirname $ASIC_DIR]

set TOP riscv_fan_soc_asic_top

set FILELIST "$ASIC_DIR/filelist_asic.f"
set SDC_FILE "$ASIC_DIR/riscv_fan_soc_asic.sdc"
set PDK_SETUP "$SCRIPT_DIR/setup_pdk.tcl"

set REPORT_DIR "$SCRIPT_DIR/reports"
set OUTPUT_DIR "$SCRIPT_DIR/outputs"
set LOG_DIR    "$SCRIPT_DIR/logs"
set WORK_DIR   "$SCRIPT_DIR/work"

file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $LOG_DIR
file mkdir $WORK_DIR

puts "============================================================"
puts " RISC-V Fan SoC - Cadence Genus Synthesis"
puts "============================================================"
puts "PROJECT_ROOT : $PROJECT_ROOT"
puts "TOP          : $TOP"
puts "FILELIST     : $FILELIST"
puts "SDC          : $SDC_FILE"
puts "============================================================"

# ------------------------------------------------------------
# Load technology setup.
# ------------------------------------------------------------
if {![file exists $PDK_SETUP]} {
    error "Missing PDK setup file: $PDK_SETUP"
}
source $PDK_SETUP

# Standard-cell library is mandatory.
if {$STD_CELL_LIB eq "/ABSOLUTE/PATH/TO/standard_cell.lib"} {
    error "Edit asic/genus/setup_pdk.tcl and set STD_CELL_LIB to the real .lib path before running Genus."
}

if {![file exists $STD_CELL_LIB]} {
    error "Standard-cell Liberty file not found: $STD_CELL_LIB"
}

# ------------------------------------------------------------
# Library setup
# ------------------------------------------------------------
set LIB_FILES [list $STD_CELL_LIB]
foreach lib $SRAM_LIBS {
    if {![file exists $lib]} {
        error "SRAM Liberty file not found: $lib"
    }
    lappend LIB_FILES $lib
}

set LIB_SEARCH_PATHS [list [file dirname $STD_CELL_LIB]]
foreach lib $SRAM_LIBS {
    lappend LIB_SEARCH_PATHS [file dirname $lib]
}
foreach p $EXTRA_LIB_SEARCH_PATHS {
    lappend LIB_SEARCH_PATHS $p
}

set_db init_lib_search_path $LIB_SEARCH_PATHS
set_db library $LIB_FILES

puts "Loaded Liberty libraries:"
foreach lib $LIB_FILES {
    puts "  $lib"
}

if {[llength $SRAM_LIBS] == 0} {
    puts "WARNING: SRAM_LIBS is empty."
    puts "         SRAM blocks will remain abstract/black-box for this run."
    puts "         Area/timing numbers will therefore NOT represent the final chip."
}

# ------------------------------------------------------------
# Read ASIC RTL file list.
# Paths in filelist_asic.f are relative to PROJECT_ROOT.
# ------------------------------------------------------------
if {![file exists $FILELIST]} {
    error "ASIC file list not found: $FILELIST"
}

set fh [open $FILELIST r]
set RTL_FILES [list]
while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {$line eq ""} {
        continue
    }
    if {[string match "#*" $line]} {
        continue
    }

    set rtl_file [file normalize "$PROJECT_ROOT/$line"]
    if {![file exists $rtl_file]} {
        close $fh
        error "RTL file listed in filelist_asic.f does not exist: $rtl_file"
    }
    lappend RTL_FILES $rtl_file
}
close $fh

puts "Reading [llength $RTL_FILES] RTL files..."

# ASIC_USE_SRAM_MACROS is mandatory for ASIC synthesis.
# It prevents the simulation-only memory arrays from becoming FF arrays.
read_hdl -sv -define ASIC_USE_SRAM_MACROS $RTL_FILES

# ------------------------------------------------------------
# Elaborate ASIC top
# ------------------------------------------------------------
elaborate $TOP

# ------------------------------------------------------------
# Apply timing constraints
# ------------------------------------------------------------
if {![file exists $SDC_FILE]} {
    error "SDC file not found: $SDC_FILE"
}
read_sdc $SDC_FILE

# ------------------------------------------------------------
# Pre-synthesis checks
# ------------------------------------------------------------
puts "Running pre-synthesis design checks..."
check_design -unresolved > "$REPORT_DIR/check_design_pre.rpt"

# ------------------------------------------------------------
# Synthesis effort
# ------------------------------------------------------------
set_db syn_generic_effort $SYN_GENERIC_EFFORT
set_db syn_map_effort     $SYN_MAP_EFFORT
set_db syn_opt_effort     $SYN_OPT_EFFORT

# ------------------------------------------------------------
# Logic synthesis
# ------------------------------------------------------------
puts "Running syn_generic..."
syn_generic

puts "Running syn_map..."
syn_map

puts "Running syn_opt..."
syn_opt

# ------------------------------------------------------------
# Reports
# ------------------------------------------------------------
puts "Writing synthesis reports..."
report_qor    > "$REPORT_DIR/qor.rpt"
report_area   > "$REPORT_DIR/area.rpt"
report_timing > "$REPORT_DIR/timing.rpt"
report_power  > "$REPORT_DIR/power.rpt"
check_design -unresolved > "$REPORT_DIR/check_design_post.rpt"

# ------------------------------------------------------------
# Outputs for later Innovus / STA flow
# ------------------------------------------------------------
puts "Writing synthesis outputs..."
write_hdl > "$OUTPUT_DIR/${TOP}_syn.v"
write_sdc > "$OUTPUT_DIR/${TOP}_syn.sdc"
write_sdf > "$OUTPUT_DIR/${TOP}_syn.sdf"

puts ""
puts "============================================================"
puts " GENUS SYNTHESIS FINISHED"
puts "============================================================"
puts "Netlist : $OUTPUT_DIR/${TOP}_syn.v"
puts "SDC     : $OUTPUT_DIR/${TOP}_syn.sdc"
puts "SDF     : $OUTPUT_DIR/${TOP}_syn.sdf"
puts "Reports : $REPORT_DIR"
puts "============================================================"
puts "Review timing.rpt, area.rpt, qor.rpt and check_design_post.rpt"
puts "before starting Innovus."
