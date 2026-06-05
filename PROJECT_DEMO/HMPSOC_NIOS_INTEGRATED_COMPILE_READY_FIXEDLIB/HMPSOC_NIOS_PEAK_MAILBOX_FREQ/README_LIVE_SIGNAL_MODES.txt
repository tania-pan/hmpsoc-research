Live signal mode reconfiguration demo
====================================

This build keeps a single signal_data.mif in the project. It is a 12-bit
period-400 sine table.

The signal generator is now configurable at run time:

  SW4 = 0  -> normal ROM step = 1  -> 40 Hz
  SW4 = 1  -> double ROM step = 2  -> 80 Hz
  KEY1     -> external event; ReCOP polls SIP and sends the NoC config packet

The config flow is:

  KEY1 press
    -> ReCOP detects SIP event by polling
    -> ReCOP writes NoC destination/payload/trigger registers
    -> recop_noc_wrapper inserts SW4 into config payload bit 2
    -> Signal ASP receives config packet
    -> signal_gen changes ROM step size
    -> ASP pipeline runs
    -> Peak detector sends event spacing to Nios mailbox
    -> Nios computes frequency

Expected Nios outputs:
  SW4=0:
    signal period = 400 samples
    event spacing = 200 samples
    payload ~= 199
    frequency = 16000 / (2*(199+1)) = 40 Hz

  SW4=1:
    effective signal period = 200 samples
    event spacing = 100 samples
    payload ~= 99
    frequency = 16000 / (2*(99+1)) = 80 Hz

Demo sequence:
  1. Reset with KEY0.
  2. Set SW4=0.
  3. Press KEY1.
  4. Nios console should show around 40 Hz.
  5. Set SW4=1.
  6. Press KEY1 again.
  7. Nios console should show around 80 Hz.

No MIF changes or Quartus recompilation are needed to switch between these two modes.
