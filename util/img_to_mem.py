import sys
from PIL import Image, ImageOps

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
        w, h = image_in.size

        # print(image_in.getpixel((0, 0)))
        # # Take input image and divide each color channel's value by 16
        with open(f'image.mem', 'w') as f:
            for y in range(h):
                for x in range(w):
                    r, g, b = image_in.getpixel((x, y))
                    f.write(f'{int(0.2126*r+0.7152*g+0.0722*b):02x}\n')

        print('Output image saved at image.mem')
