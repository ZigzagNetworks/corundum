## Modifications from this branch

### CMAC
- [ ] Disable RS-FEC Clause 91 — `CONFIG.INCLUDE_RS_FEC` in `fpga/mqnic/ADM_PCIE_9V3/fpga_100g/ip/cmac_usplus.tcl`
    - Implications (according to Claude):
        - Must be off if using 100GBASE-LR4/ER4 transceivers, as they use 4x25G NRZ
        - Saves ~100ns of latency on both ends
        - Saves few thousands LUTs and some BRAM
        - Both ends must have it disabled; else PCS alignment may fail, could get massive BER
        - RS-FEC-related registers of `cmac_gty_wrapper` fixed to 0

### Instrumentation
- [x] Added CMAC's status signals from [PG203: Status and Control Interface](https://docs.amd.com/r/en-US/pg203-cmac-usplus/Status-and-Control-Interface)
    - To use ILA,
        - Capture mode: ADVANCED
        - Storage qualifier: `probe37 == 1` (`ila_change_detected`)
        - Trigger: `probe9 != 20'hFFFFF` (`stat_rx_block_lock`)
            - "Each bit indicates that the corresponding PCS lane has achieved sync header lock as defined by the 802.3-2012. A value of 1 indicates block lock is achieved."
        - Trigger position: 25%
    - Column `probe38` is cycle count on clock of 322.265625MHz
    - The capture runs until the buffer is full (`C_DATA_DEPTH` signal change events defined in `fpga/mqnic/ADM_PCIE_9V3/fpga_100g/ip/ila_0.tcl`)
