#!/usr/bin/env bash
# Runs Verilator (compile + simulate testbench) and Yosys (synthesis) for every
# module in source/. Produces build/ artifacts and prints a summary table.
#
# Usage:  ./testbench/run_verification.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/source"
TB="$ROOT/testbench"
BUILD="$ROOT/build"
rm -rf "$BUILD"
mkdir -p "$BUILD/ver" "$BUILD/synth"

# Source files per family
MAC_SRC="$SRC/mac/MACmodule.sv"
SPI_SRC="$SRC/spi_image_system/SPImodule.sv"
HLB_SRC="$SRC/hidden_layer_buffer/hidden_layer_buffer.sv"
OLB_SRC="$SRC/output_layer_buffer/output_layer_buffer.sv"
ARG_SRC="$SRC/argmax/argmax.sv"
SS_SRC="$SRC/seven_seg/seven_seg.sv"
CTRL_DIR="$SRC/Maincontroller"
MC="$CTRL_DIR/mainctrlfsm.sv $CTRL_DIR/layer_controller.sv $CTRL_DIR/MAC_controller.sv $CTRL_DIR/inputcontroller.sv $CTRL_DIR/argmax_controller.sv $CTRL_DIR/controllertop.sv"
ALL_SRC="$MAC_SRC $SPI_SRC $HLB_SRC $OLB_SRC $ARG_SRC $SS_SRC $MC"

# module | source files
MODULES=(
  "mixedsign4bitmult|$MAC_SRC"
  "addersigned16bit|$MAC_SRC"
  "accreg|$MAC_SRC"
  "relu|$MAC_SRC"
  "MAC|$MAC_SRC"
  "SPI_shiftreg|$SPI_SRC"
  "SPI_FSM|$SPI_SRC"
  "dualffsync|$SPI_SRC"
  "SPI_mod|$SPI_SRC"
  "hidden_layer_buffer|$HLB_SRC"
  "output_layer_buffer|$OLB_SRC"
  "argmax|$ARG_SRC"
  "ssdec|$SS_SRC"
  "main_ctrlfsm|$CTRL_DIR/mainctrlfsm.sv"
  "layer_controller|$CTRL_DIR/layer_controller.sv"
  "MAC_controller|$CTRL_DIR/MAC_controller.sv"
  "argmax_controller|$CTRL_DIR/argmax_controller.sv"
  "input_controller|$CTRL_DIR/inputcontroller.sv"
  "controllertop|$MC"
  "top|$ALL_SRC $SRC/top.sv"
)

VFLAGS="--binary --timing -sv -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-BLKANDNBLK -Wno-MULTIDRIVEN"

declare -A SIM_RES SYN_RES SYN_CELLS

for entry in "${MODULES[@]}"; do
  mod="${entry%%|*}"
  srcs="${entry#*|}"
  tbfile="$TB/$mod/tb_$mod.sv"

  echo "==================================================================="
  echo "MODULE: $mod"
  echo "-------------------------------------------------------------------"

  # ---- Verilator: compile + simulate testbench ----
  vdir="$BUILD/ver/$mod"
  mkdir -p "$vdir"
  vlog="$vdir/verilator.log"
  if verilator $VFLAGS --top-module "tb_$mod" --Mdir "$vdir" -o "sim_$mod" $srcs "$tbfile" > "$vlog" 2>&1; then
    if [ -x "$vdir/sim_$mod" ]; then
      ( cd "$vdir" && ./"sim_$mod" > sim.log 2>&1 )
      if grep -q "RESULT: PASS" "$vdir/sim.log"; then
        SIM_RES[$mod]="PASS"
      elif grep -q "RESULT: FAIL" "$vdir/sim.log"; then
        SIM_RES[$mod]="FAIL(checks)"
      else
        SIM_RES[$mod]="RAN(no-result)"
      fi
      tail -3 "$vdir/sim.log" | sed 's/^/   sim: /'
    else
      SIM_RES[$mod]="BUILD-ERR"
      echo "   verilator build produced no binary"
    fi
  else
    SIM_RES[$mod]="COMPILE-ERR"
    echo "   verilator compile failed (see $vlog):"
    tail -4 "$vlog" | sed 's/^/   ver: /'
  fi

  # ---- Yosys: synthesis ----
  slog="$BUILD/synth/${mod}.log"
  if yosys -p "read_verilog -sv $srcs; hierarchy -top $mod; proc; opt; synth -top $mod -flatten; stat" > "$slog" 2>&1; then
    SYN_RES[$mod]="PASS"
    cells=$(grep -m1 "Number of cells:" "$slog" | awk '{print $NF}')
    SYN_CELLS[$mod]="${cells:-0}"
    echo "   yosys: synthesized OK (cells=${SYN_CELLS[$mod]})"
  else
    SYN_RES[$mod]="FAIL"
    SYN_CELLS[$mod]="-"
    echo "   yosys: FAILED (see $slog):"
    grep -iE "error|ERROR" "$slog" | head -2 | sed 's/^/   yos: /'
  fi
done

echo
echo "###################################################################"
echo "# SUMMARY"
echo "###################################################################"
printf "%-22s %-16s %-10s %-8s\n" "MODULE" "VERILATOR-SIM" "YOSYS" "CELLS"
printf "%-22s %-16s %-10s %-8s\n" "----------------------" "----------------" "----------" "--------"
for entry in "${MODULES[@]}"; do
  mod="${entry%%|*}"
  printf "%-22s %-16s %-10s %-8s\n" "$mod" "${SIM_RES[$mod]:-?}" "${SYN_RES[$mod]:-?}" "${SYN_CELLS[$mod]:-?}"
done
