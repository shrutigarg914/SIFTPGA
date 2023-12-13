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
        w, h = image_in.size

        # print(image_in.getpixel((0, 0)))
        # # Take input image and divide each color channel's value by 16
        for y in range(h):
            for x in range(w):
                r, g, b = image_in.getpixel((x, y))
                pixels.append(int(0.2126*r+0.7152*g+0.0722*b))
        print(h, w, len(pixels))
        print(pixels)

        s = serial.Serial(port='COM5', baudrate=2000000, bytesize=8)
        print("setup ready")
        # time.sleep(10)
        packets_sent = 0
        while packets_sent<len(pixels):
            # char = bytes(input("send: "), 'ascii')
            # print(struct.pack('B', 3))
            # print(pixels[packets_sent])
            s.write(struct.pack('B', int(pixels[packets_sent])))
            # print(".", end='', flush=True)
            packets_sent +=1
        print("DONE SENDING!")

        image_rx = []
        while len(image_rx) < 2*(len(pixels)*3 + len(pixels)/4*3 + len(pixels)/16*3):
            # print(".", end='', flush=True)
            res = s.read()
            image_rx.append(struct.unpack('b', res)[0])
            print(len(image_rx), 2*(len(pixels)*3 + len(pixels)/4*3 + len(pixels)/16*3), struct.unpack('B', res)[0])
            # ind = input("Index investigating:  ")
            # print(pixels[ind])
        print("IMAGES RECEIVED")

        for i in range(6):
            im_res = np.asarray(image_rx[len(pixels)*i:len(pixels)*(i+1)]).reshape((64, 64))
            print(im_res)
            plt.imshow(im_res, cmap='gray', vmin=-128, vmax=127)
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=-128, vmax=127)
            plt.show()
            # # use matplotlib to visualise the greyscale image we get back
            # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
            
        for i in range(6):
            len_img = len(pixels) / 4
            im_res = np.asarray(image_rx[int(len(pixels)*3 + len_img*i):int(len(pixels)*3 + len_img*(i+1))]).reshape((32, 32))
            print(im_res)
            plt.imshow(im_res, cmap='gray', vmin=-128, vmax=127)
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=-128, vmax=127)
            plt.show()
            # # use matplotlib to visualise the greyscale image we get back
            # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
            
        for i in range(6):
            len_img = len(pixels) / 16
            im_res = np.asarray(image_rx[int(len(pixels)*3 + len(pixels)/4*3 + len_img*i):int(len(pixels)*3 + len(pixels)/4*3 + len_img*(i+1))]).reshape((16, 16))
            print(im_res)
            plt.imshow(im_res, cmap='gray', vmin=-128, vmax=127)
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=-128, vmax=127)
            plt.show()
            # # use matplotlib to visualise the greyscale image we get back
            # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
