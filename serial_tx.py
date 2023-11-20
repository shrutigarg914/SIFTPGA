import serial
import time
s = serial.Serial(port='COM6', baudrate=300000, bytesize=8)
print("setup ready")
time.sleep(10)
while True:
    res = s.read()
    print(res.decode("Ascii"))
