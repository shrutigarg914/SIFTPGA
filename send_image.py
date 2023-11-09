# modified version of the following manta example script
# https://github.com/fischermoseley/manta/blob/main/examples/nexys_a7/video_sprite_uart/send_image.py
import time
import sys
from PIL import Image, ImageOps
import numpy as np
import matplotlib.pyplot as plt

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: {0} <image to convert>".format(sys.argv[0]))

    else:
        input_fname = sys.argv[1]
        image_in = Image.open(input_fname)
        image_in = image_in.convert('RGB')

        # Resize the image
        image_in = image_in.resize((128, 128))
        image_out = image_in.copy()
        w, h = image_in.size

        # Take input image and divide each color channel's value by 16
        for y in range(h):
            for x in range(w):
                r, g, b = image_in.getpixel((x, y))
                image_out.putpixel((x,y), (r//16, g//16, b//16))


        # Save the image itself
        pixels = []
        for y in range(h):
            for x in range(w):
                (r, g, b) = image_out.getpixel((x,y))
                color = (r*16*16) + (g*16) + (b)
                pixels.append(color)

        from manta import Manta
        m = Manta('final.yaml')

        addrs = list(range(len(pixels)))
        m.image_memory.write(addrs, pixels)


        print(pixels)
        # while True:
        #     print('.')
        time.sleep(2.0)
        #     result = m.output_memory.read(addrs)
        #     if sum(result)>0:
        #         break
        result = m.image_memory.read(addrs)
    
        print(result, h, w)
        i = 0
        im_res = []
        for y in range(h):
            for x in range(w):
                r = result[i] / (16*16)
                g = (result[i] %  (16*16)) / 16
                b = result[i] % 16
                im_res.append((r + g + b)/3)
        im_res = np.asarray(im_res).reshape((128, 128))
        plt.imshow(im_res, cmap='gray', vmin=0, vmax=255)
        plt.show()
        # use matplotlib to visualise the greyscale image we get back
        # https://matplotlib.org/stable/api/_as_gen/matplotlib.pyplot.imshow.html
