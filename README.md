# RISC-V SoC-Based Single-Fan Controller with PWM, SPI, and UART

## 📌 Project Overview
This project involves the design and verification of a 32-bit System-on-Chip (SoC) based on the **RV32I** instruction set architecture. The primary objective is to drive a simulated cooling fan using a Pulse Width Modulation (PWM) signal while providing serial communication via SPI and UART interfaces. All configuration values are maintained in on-chip SRAM.

## 🏗️ Architecture & Features
- **RISC-V Core:** Synthesizable 32-bit RV32I core (Single-cycle / Multi-cycle). Implements standard integer computational instructions, control flow, and memory access without complex features like pipelining, MMU, or caches.
- **Memory:** On-chip Instruction and Data SRAM blocks.
- **Peripherals (Memory-Mapped):**
  - **PWM Controller:** Single-channel generator to control fan speed.
  - **SPI Master:** For high-speed synchronous serial communication.
  - **UART Transceiver:** For asynchronous serial data transmission and reception.
- **Interconnect:** Memory-mapped I/O structure connecting the core to memory and peripherals.

## 🧪 Verification Methodology
1. **Basic Verification:** 
   - Directed, self-checking SystemVerilog testbenches.
   - Verifies core instructions, SRAM read/write, SPI transfers, PWM generation, and UART Tx/Rx.
2. **UVM Verification:** 
   - Industry-standard Universal Verification Methodology (UVM).
   - Includes agents, sequences, scoreboards, and coverage models to test fail-safe behaviors, stall detection, and robust RPM measurement.

## ⚙️ Physical Design (ASIC Flow)
The project includes a complete RTL-to-GDSII physical design flow:
- Synthesis & Constraints definitions
- Floorplanning & Power Planning
- Placement & Clock-Tree Synthesis (CTS)
- Routing & Sign-off Checks (DRC, LVS)
- Detailed reporting on Area, Timing, Power, and Congestion.

## 📂 Repository Structure
```text
📦 RISCV-Fan-Controller
 ┣ 📂 rtl                 # Synthesizable SystemVerilog/Verilog source code
 ┃ ┣ 📂 core              # ALU, Register File, Control Unit, Datapath
 ┃ ┣ 📂 memory            # Instruction and Data SRAM modules
 ┃ ┗ 📂 peripherals       # PWM, SPI, UART, and Memory Map controller
 ┣ 📂 tb                  # Verification Environments
 ┃ ┣ 📂 basic             # Directed SV Testbenches
 ┃ ┗ 📂 uvm               # UVM testbenches, agents, and scoreboards
 ┣ 📂 pd                  # Physical Design scripts, constraints, and reports
 ┗ 📂 docs                # Architecture document, block diagrams, and layout screenshots
```

## 🚀 Getting Started
*(Instructions for compiling, simulating using ModelSim/VCS, and running synthesis scripts will be added as the modules are developed in phases).*

## 📝 License
This project is developed for educational and academic purposes.
