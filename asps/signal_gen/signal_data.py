import numpy as np

fs = 16000          # sampling frequency (16KHz)
f0 = 50             # fundamental frequency (50Hz)
duration = 0.1      # 100ms (5 cycles)
t = np.arange(0, duration, 1/fs)
w0 = 2 * np.pi * f0

# signal formula
v_t = (0.3 + 
       5 * np.sin(w0 * t + 2.5) + 
       1.5 * np.sin(3 * w0 * t + 1.3) + 
       0.75 * np.sin(5 * w0 * t + 1.0) + 
       0.375 * np.sin(7 * w0 * t + 0.6) + 
       0.1875 * np.sin(9 * w0 * t + 0.3))

# scaling for 10-bit unsigned (0 to 1023)
v_min, v_max = np.min(v_t), np.max(v_t)
v_scaled = ((v_t - v_min) / (v_max - v_min) * 1023).astype(int)

# generate MIF content
with open("signal_data.mif", "w") as f:
    f.write("WIDTH=10;\nDEPTH=1600;\nADDRESS_RADIX=UNS;\nDATA_RADIX=UNS;\nCONTENT BEGIN\n")
    for i, val in enumerate(v_scaled):
        f.write(f"    {i} : {val};\n")
    f.write("END;\n")

print("signal_data.mif generated successfully!")