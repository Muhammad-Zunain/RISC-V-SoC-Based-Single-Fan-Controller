# ============================================================
# Cadence Genus - Technology / PDK Setup
# ============================================================
# EDIT THIS FILE ONLY after you know the PDK/library paths.
# Do not copy a path from an example blindly.
# ============================================================

# ------------------------------------------------------------
# 1) Standard-cell Liberty library - REQUIRED
# ------------------------------------------------------------
# Example only:
# set STD_CELL_LIB "/cad/pdk/gpdk045/lib/slow.lib"
set STD_CELL_LIB "/ABSOLUTE/PATH/TO/standard_cell.lib"

# ------------------------------------------------------------
# 2) SRAM Liberty timing libraries - OPTIONAL for first
#    black-box synthesis, REQUIRED for meaningful final timing.
# ------------------------------------------------------------
# Example:
# set SRAM_LIBS [list \
#     "/cad/sram/imem_1024x32_tt.lib" \
#     "/cad/sram/dmem_1024x32_tt.lib" \
#     "/cad/sram/cfg_256x32_tt.lib" \
# ]
set SRAM_LIBS [list]

# ------------------------------------------------------------
# 3) Optional extra Liberty search directories
# ------------------------------------------------------------
set EXTRA_LIB_SEARCH_PATHS [list]

# ------------------------------------------------------------
# 4) Synthesis effort
# ------------------------------------------------------------
set SYN_GENERIC_EFFORT medium
set SYN_MAP_EFFORT     medium
set SYN_OPT_EFFORT     medium
