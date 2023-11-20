import serial
import time
s = serial.Serial(port='COM6', baudrate=3000000, bytesize=8)
print("setup ready")
# time.sleep(10)
while True:
    char = bytes(input("send: "), 'ascii')
    s.write(char)
    print("done sending")
    res = s.read()
    print(res)
