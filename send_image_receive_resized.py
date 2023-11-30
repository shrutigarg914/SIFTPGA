import time
import sys
from PIL import Image, ImageOps
import numpy as np
import matplotlib.pyplot as plt
import serial
import time
import struct
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: {0} <image to convert>".format(sys.argv[0]))

    else:
        input_fname = sys.argv[1]
        image_in = Image.open(input_fname)
        image_in = image_in.convert('RGB')

        # Resize the image
        image_in = image_in.resize((64, 64))
        # image_out = image_in.copy()
        pixels = []
        pixels_two = []
        w, h = image_in.size

        # print(image_in.getpixel((0, 0)))
        # # Take input image and divide each color channel's value by 16
        for y in range(h):
            for x in range(w):
                r, g, b = image_in.getpixel((x, y))
                p = int(0.2126*r+0.7152*g+0.0722*b)
                pixels.append(p)
                pixels_two.append(int(p/2))

        print(h, w, len(pixels))

        print(pixels_two)

        s = serial.Serial(port='COM6', baudrate=2000000, bytesize=8)
        print("setup ready")
        # time.sleep(10)
        packets_sent = 0
        while packets_sent<len(pixels):
            # char = bytes(input("send: "), 'ascii')
            # print(struct.pack('B', 3))
            # print(pixels[packets_sent])
            s.write(struct.pack('B', pixels[packets_sent]))
            # print(".", end='', flush=True)
            packets_sent +=1
        input("DONE SENDING! Send the other one?")

        packets_sent = 0
        while packets_sent<len(pixels):
            # char = bytes(input("send: "), 'ascii')
            # print(struct.pack('B', 3))
            # print(pixels[packets_sent])
            s.write(struct.pack('B', pixels[packets_sent]))
            # print(".", end='', flush=True)
            packets_sent +=1
        print("DONE SENDING!")

        image_rx = []
        while len(image_rx) <len(pixels)//4:
            # print(".", end='', flush=True)
            res = s.read()
            image_rx.append(struct.unpack('B', res)[0])
            # print(len(image_rx), len(pixels)//4, struct.unpack('B', res)[0])
            # ind = input("Index investigating:  ")
            # print(pixels[ind])
        print("IMAGE RECEIVED")
        print(image_rx)

        im_res = np.asarray(image_rx).reshape((32, 32))
        plt.imshow(im_res, cmap='gray', vmin=-128, vmax=127)
        # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
        plt.show()
        # # use matplotlib to visualise the greyscale image we get back
        # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
