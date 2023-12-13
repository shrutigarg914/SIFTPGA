import time
import sys
from PIL import Image, ImageOps
import numpy as np
import matplotlib.pyplot as plt
import serial
import time
import struct

def gaussian_blur(chunk):
    kernel = np.array([[1,2,1],[2,4,2],[1,2,1]])
    return np.sum(kernel * chunk) // 16

def blur_img(pixels, h, w):
    blurred = np.zeros((h, w))
    for i in range(h):
        for j in range(w):
            center = pixels[i, j]
            padded = np.pad(pixels, 1, 'constant', constant_values=center)
            chunk = padded[i:i+3, j:j+3]
            blurred[i, j] = gaussian_blur(chunk)
    return blurred

def halve_img(pixels, old_h, old_w):
    halved = np.zeros((old_h//2, old_w//2))
    for i in range(0, old_h, 2):
        for j in range(0, old_w, 2):
            halved[i//2, j//2] = pixels[i, j]
    return halved

def calc_pyramid(pixels, h, w):
    pyramid = [pixels] # o1l1
    pyramid.append(blur_img(pixels, h, w)) # o1l2
    pyramid.append(blur_img(pyramid[1], h, w)) # o1l3
    pyramid.append(halve_img(pyramid[2], h, w)) # o2l1
    pyramid.append(blur_img(pyramid[3], h//2, w//2)) # o2l2
    pyramid.append(blur_img(pyramid[4], h//2, w//2)) # o2l3
    pyramid.append(halve_img(pyramid[5], h//2, w//2)) # o3l1
    pyramid.append(blur_img(pyramid[6], h//4, w//4)) # o3l2
    pyramid.append(blur_img(pyramid[7], h//4, w//4)) # o3l3

    return pyramid

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

        pixels_reshaped = np.asarray(pixels).reshape((64, 64))
        pyramid = calc_pyramid(pixels_reshaped, h, w)

        image_rx = []
        while len(image_rx) < len(pixels)*3 + len(pixels)/4*3 + len(pixels)/16*3:
            # print(".", end='', flush=True)
            res = s.read()
            image_rx.append(struct.unpack('B', res)[0])
            print(len(image_rx), len(pixels)*3 + len(pixels)/4*3 + len(pixels)/16*3, struct.unpack('B', res)[0])
            # ind = input("Index investigating:  ")
            # print(pixels[ind])
        print("IMAGES RECEIVED")

        for i in range(3):
            im_check = np.asarray(pyramid[i]).reshape((64, 64))
            print(im_check)
            plt.imshow(im_check, cmap='gray', vmin=0, vmax=255)
            plt.title(f"O1L{i+1} Check")
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
            plt.show()

            im_res = np.asarray(image_rx[len(pixels)*i:len(pixels)*(i+1)]).reshape((64, 64))
            print(im_res)
            plt.imshow(im_res, cmap='gray', vmin=0, vmax=255)
            plt.title(f"O1L{i+1} Result")
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
            plt.show()

            # # use matplotlib to visualise the greyscale image we get back
            # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
            
        for i in range(3):
            im_check = np.asarray(pyramid[3+i]).reshape((32, 32))
            print(im_check)
            plt.imshow(im_check, cmap='gray', vmin=0, vmax=255)
            plt.title(f"O2L{i+1} Check")
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
            plt.show()
            
            len_img = len(pixels) / 4
            im_res = np.asarray(image_rx[int(len(pixels)*3 + len_img*i):int(len(pixels)*3 + len_img*(i+1))]).reshape((32, 32))
            print(im_res)
            plt.imshow(im_res, cmap='gray', vmin=0, vmax=255)
            plt.title(f"O2L{i+1} Result")
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
            plt.show()
            # # use matplotlib to visualise the greyscale image we get back
            # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
            
        for i in range(3):
            im_check = np.asarray(pyramid[6+i]).reshape((16, 16))
            print(im_check)
            plt.imshow(im_check, cmap='gray', vmin=0, vmax=255)
            plt.title(f"O3L{i+1} Check")
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
            plt.show()
            
            len_img = len(pixels) / 16
            im_res = np.asarray(image_rx[int(len(pixels)*3 + len(pixels)/4*3 + len_img*i):int(len(pixels)*3 + len(pixels)/4*3 + len_img*(i+1))]).reshape((16, 16))
            print(im_res)
            plt.imshow(im_res, cmap='gray', vmin=0, vmax=255)
            plt.title(f"O3L{i+1} Result")
            # plt.imshow(np.asarray(pixels).reshape(128, 128), cmap='gray', vmin=0, vmax=255)
            plt.show()
            # # use matplotlib to visualise the greyscale image we get back
            # # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
