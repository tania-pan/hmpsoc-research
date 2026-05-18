# Engineering Report: Design and Implementation of the Moving Average ASP Node

---

## 1. Introduction and Architectural Overview
In high-performance, real-time Heterogeneous Multi-Processor Systems-on-Chip (HMPSoCs), general-purpose RISC processors (such as the ReCOP or Nios II cores) often become bottlenecks when burdened with high-throughput, data-dominated tasks. To maintain time-predictability and optimize execution efficiency, dedicated data operations are offloaded to **Application-Specific Processors (ASPs)**. 

The developed **Moving Average ASP** is an independent hardware accelerator designed to interface natively with a **Time-Division Multiple Access Multistage Interconnect Network (TDMA-MIN) Network-on-Chip (NoC)**. It ingests an emulated or live digital audio stream via its network interface, filters the data payload, and forwards the processed metrics to designated downstream targets.

---

## 2. Meeting System Requirements
The primary engineering objective of the Moving Average ASP is to eliminate localized signal fluctuations and high-frequency noise from an incoming stream without compromising the predictable timing constraints of the NoC.

* **NoC Protocols Compliance:** The module monitors incoming 32-bit NoC words (`tdma_min_port`) and actively filters for the specific package header configuration (`recv.data(31 downto 28) = "1000"`). This satisfies network rules, ensuring non-data packets are completely ignored.
* **Efficient Division Architecture:** The filter operates on a window size of exactly $4$ taps ($N=4$). Summing four 16-bit integers yields an 18-bit intermediate variable (`v_sum`). Computing an arithmetic mean normally requires a hardware divider, which introduces high propagation delays and resource utilization. This design fulfills the averaging requirement by utilizing a simple 2-bit arithmetic right shift (`shift_right(v_sum, 2)`). This calculates a precise division by $2^2 = 4$ inside a single clock cycle, upholding deterministic real-time performance.
* **Isolated Scalability via Generics:** To keep the processing pipeline modular, the destination address (`TARGET_PORT`) is exposed as a generic parameter. This decouples the core algorithmic logic from the physical layout of the network infrastructure, allowing the same IP core to be deployed across different slots.

---

## 3. Engineering Evaluation of Architectural Additions

### A. Multichannel Filtering (Time-Multiplexed Sharing)
Real-world audio and sensory acquisition frameworks frequently handle multiple streams concurrently (e.g., stereophonic Left/Right audio channels or dual-axis sensor streams). Rather than instantiating two completely separate hardware filters—which would double the FPGA fabric utilization (registers, adders, and routing wires)—this ASP implements a **demultiplexed dual-channel system**.

* **How it works:** The design designates Bit 16 of the data packet payload as a channel selection flag. When a packet arrives, this flag dynamically routes the data path into either `regs0` (Channel 0) or `regs1` (Channel 1).
* **Engineering Benefit:** This achieves perfect structural resource optimization. The heavy mathematical pipeline (the 18-bit adder tree, bit-shifter, and saturation logic) is shared sequentially between both streams, cutting the required arithmetic hardware overhead in half while still maintaining strictly isolated history buffers for each data channel.

### B. Saturation and Clipping Circuitry
Digital audio representations rely on signed Two's Complement arithmetic. A major vulnerability of fixed-point arithmetic in hardware is **wrap-around overflow**. If a signal amplitude calculation exceeds the maximum boundary of a signed 16-bit register, the most significant bit flips, causing a large positive number to instantaneously wrap around to a large negative number.

* **How it works:** The design integrates an inline saturation stage bounding the output to a dynamic threshold of $\pm4096$:
  - If $v_{\text{avg}} > 4096 \implies v_{\text{clip}} = 4096$
  - If $v_{\text{avg}} < -4096 \implies v_{\text{clip}} = -4096$
* **Engineering Benefit:** Capping the amplitude guards the entire system against destructive digital artifacting. Instead of yielding catastrophic sign-flipping noise (which presents as violent, speaker-damaging pops), the signal cleanly flattens out. Furthermore, capping the maximum magnitude to a 13-bit range ($\pm2^{12}$) protects downstream processing nodes or physical Digital-to-Analog Converters (DACs) from receiving out-of-bounds data payloads that could derail subsequent algorithms, such as peak tracking or frequency visualization.

---

## 4. Conclusion
The Moving Average ASP effectively meets its processing requirements by utilizing a streamlined, shift-based arithmetic pipe that operates harmoniously within the TDMA-MIN NoC framework. The addition of multichannel demultiplexing optimizes on-chip area utilization, while the saturation circuitry ensures signal integrity under high-amplitude conditions, forming a resilient foundation for real-time digital signal processing.
