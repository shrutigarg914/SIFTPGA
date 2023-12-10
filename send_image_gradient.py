import time
import sys
from PIL import Image, ImageOps
import numpy as np
import matplotlib.pyplot as plt
import serial
import time
import struct

def calc_gradient_pyramids(pixels, h, w):
    x_grad = []
    y_grad = []

    for y in range(h):
        for x in range(w):
            x_min = pixels[x-1 + y*w] if x > 0 else pixels[x + y*w]
            x_plus = pixels[x+1 + y*w] if x < w - 1 else pixels[x + y*w]
            
            y_min = pixels[x + (y-1)*w] if y > 0 else pixels[x + y*w]
            y_plus = pixels[x + (y+1)*w] if y < h - 1 else pixels[x + y*w]

            x_grad.append((x_plus - x_min) // 2)
            y_grad.append((y_plus - y_min) // 2)
    
    return x_grad, y_grad

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: {0} <image to convert>".format(sys.argv[0]))

    else:
        input_fname = sys.argv[1]
        image_in = Image.open(input_fname)
        image_in = image_in.convert('RGB')

        # Resize the image
        image_in = image_in.resize((64, 64))
        pixels = []
        w, h = image_in.size

        # # Take input image and divide each color channel's value by 16
        for y in range(h):
            for x in range(w):
                r, g, b = image_in.getpixel((x, y))
                p = int(0.2126*r+0.7152*g+0.0722*b)
                pixels.append(p) # because i dont wanna deal with 9 bit signed...

        print(h, w, len(pixels))

        x_grad, y_grad = calc_gradient_pyramids(pixels, h, w)
        print("x_grad", x_grad)
        print("y_grad", y_grad)

        s = serial.Serial(port='COM5', baudrate=2000000, bytesize=8)
        print("setup ready")
        packets_sent = 0
        while packets_sent<len(pixels):
            s.write(struct.pack('B', pixels[packets_sent]))
            packets_sent +=1
        input("DONE SENDING!")

        image_rx = []
        while len(image_rx) <len(pixels) * 2:
            res = s.read()
            image_rx.append(struct.unpack('B', res)[0])
        print("IMAGEs RECEIVED")
        print(image_rx)

        im_res_x_correct = np.asarray(x_grad).reshape((64, 64))
        im_res_y_correct = np.asarray(y_grad).reshape((64, 64))
        plt.imshow(im_res_x_correct, cmap='gray', vmin=-128, vmax=127)
        plt.show()
        plt.imshow(im_res_y_correct, cmap='gray', vmin=-128, vmax=127)
        plt.show()

        im_res_x = np.asarray(image_rx[:4096]).reshape((64, 64))
        im_res_y = np.asarray(image_rx[4096:]).reshape((64, 64))
        plt.imshow(im_res_x, cmap='gray', vmin=-128, vmax=127)
        plt.show()
        plt.imshow(im_res_y, cmap='gray', vmin=-128, vmax=127)
        plt.show()
        # # use matplotlib to visualise the greyscale image we get back
        # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
