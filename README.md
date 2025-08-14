# FreeVHDL

[![CI Status](https://github.com/FPGA-Mada/freevhdl/actions/workflows/ci.yml/badge.svg)](https://github.com/FPGA-Mada/freevhdl/actions)

**FreeVHDL** is a curated collection of reusable, open-source VHDL modules and code snippets designed to accelerate hardware design, learning, and prototyping. This repository serves as a reliable resource for students, engineers, and FPGA/ASIC enthusiasts seeking high-quality, synthesizable VHDL components.

---

## Key Features

-  Ready-to-use, synthesizable VHDL modules
-  Modular, well-structured, and portable code
-  Comprehensive testbenches for most components
-  Utility scripts for automating simulations and builds
-  Clear documentation and examples for fast integration

---

## Project Structure

```
freevhdl/
├── src/             # VHDL source code: modules, entities, packages
│   ├── arithmetic/  # Arithmetic units (adders, multipliers)
│   ├── memory/      # Memory blocks (RAM, ROM, FIFO)
│   ├── logic/       # Logic components (encoders, decoders)
│   └── utils/       # Utility modules (clock dividers, counters)
│
├── tb/              # Testbenches for validating source code
│   ├── arithmetic_tb/
│   ├── memory_tb/
│   └── ...
│
├── script/          # Automation scripts for simulation and builds
│   └── run_ghdl.sh
│
├── doc/             # Documentation, diagrams, datasheets
│   └── overview.pdf
│
├── .github/         # GitHub Actions CI workflows
│
└── README.md        # Project overview
```

---

## Simulation & Verification

FreeVHDL leverages modern verification frameworks to ensure robust module testing:

- **[OSVVM](https://www.osvvm.org/)** – Provides advanced verification features including random stimulus, functional coverage, and reusable verification components.
- **[VUnit](https://vunit.github.io/)** – An open-source unit testing framework for VHDL that simplifies simulation automation, test organization, and CI/CD integration.

These frameworks enable **reliable, scalable, and repeatable simulations**, improving confidence in all modules provided.

---

## Getting Started

### Requirements

- [GHDL](https://ghdl.github.io/ghdl/) – Open-source VHDL simulator
- [GTKWave](http://gtkwave.sourceforge.net/) – Waveform viewer
- Alternative simulators: ModelSim, XSIM (Xilinx), or [EDA Playground](https://www.edaplayground.com/)

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/FPGA-Mada/freevhdl.git
   cd freevhdl
   ```
2. Run simulations using the provided scripts:
   ```bash
   ./script/run_ghdl.sh
   ```
3. View waveforms with GTKWave:
   ```bash
   gtkwave tb/waveform.vcd
   ```

---

## Contributing

Contributions are welcome! You can help by:

- Adding new VHDL modules
- Improving existing modules or testbenches
- Fixing bugs or optimizing code
- Enhancing documentation

Please submit issues or pull requests on GitHub.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT). See the [LICENSE](./LICENSE) file for details.

---

## Authors & Maintainers

- **Nambinina Rakotojaona** – [GitHub](https://github.com/nambhine1)

---

## Contact

For questions, suggestions, or contributions, open an [issue](https://github.com/nambhine1/freevhdl/issues) or reach out via GitHub.
