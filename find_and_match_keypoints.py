import numpy as np
import cv2
import sys
from PIL import Image

def calc_gradient_images(pixels, h, w):
    x_grad = []
    y_grad = []

    pixels_reshaped = pixels.flatten()

    for y in range(h):
        for x in range(w):
            x_min = pixels_reshaped[x-1 + y*w] if x > 0 else pixels_reshaped[x + y*w]
            x_plus = pixels_reshaped[x+1 + y*w] if x < w - 1 else pixels_reshaped[x + y*w]
            
            y_min = pixels_reshaped[x + (y-1)*w] if y > 0 else pixels_reshaped[x + y*w]
            y_plus = pixels_reshaped[x + (y+1)*w] if y < h - 1 else pixels_reshaped[x + y*w]

            x_grad.append((x_plus - x_min) // 2)
            y_grad.append((y_plus - y_min) // 2)
    
    return np.asarray(x_grad).reshape(h, w), np.asarray(y_grad).reshape(h, w)

def calc_gradient_pyramid(pixels, h, w):
    pyramid = calc_pyramid(pixels, h, w)
    gradient_pyramid_x = []
    gradient_pyramid_y = []
    
    for i in range(len(pyramid)):
        x, y = calc_gradient_images(pyramid[i], pyramid[i].shape[0], pyramid[i].shape[1])
        gradient_pyramid_x.append(x)
        gradient_pyramid_y.append(y)
    
    return gradient_pyramid_x, gradient_pyramid_y

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

def point_is_extrema(array_one, array_two, x, y, threshold=10):
    result = [[True, True], [True, True]]
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            if not (dx==0 and dy==0):
                if array_one[y + dy, x + dx] <= array_one[y, x]:
                    result[0][0] = False
                if array_one[y + dy, x + dx] >= array_one[y, x]:
                    result[0][1] = False
                if array_two[y + dy, x + dx] <= array_two[y, x]:
                    result[1][0] = False
                if array_two[y + dy, x + dx] >= array_two[y, x]:
                    result[1][1] = False

            if array_two[y + dy, x + dx] <= array_one[y, x] + threshold:
                result[0][0] = False
            if array_two[y + dy, x + dx] >= array_one[y, x] - threshold:
                result[0][1] = False
            
            if array_one[y + dy, x + dx] <= array_two[y, x] + threshold:
                result[1][0] = False
            if array_one[y + dy, x + dx] >= array_two[y, x] - threshold:
                result[1][1] = False
    
    return (result[0][1], result[0][0], result[1][0], result[1][1])

def find_extrema(array_one, array_two, dim =4):
    counter = 0
    indices = set()
    for y in range(1, dim-1):
        for x in range(1, dim-1):
            is_one_max, is_one_min, is_two_min, is_two_max = point_is_extrema(array_one, array_two, x, y)
            if (is_one_max):
                print("Found MAX in BRAM 1 at (", x, ", ", y, ")")
                counter +=1
                indices.add((x, y, 0))
            if (is_one_min):
                print("Found min in BRAM 1 at (", x, ", ", y, ")")
                counter +=1
                indices.add((x, y, 0))
            if (is_two_max):
                counter +=1
                print("Found MAX in BRAM 2 at (", x, ", ", y, ")")
                indices.add((x, y, 1))
            if (is_two_min):
                counter +=1
                indices.add((x, y, 1))
                print("Found min in BRAM 2 at (", x, ", ", y, ")")
    return counter, indices

def dog(array_one, array_two):
    return array_one - array_two

def grad_orientation(x_grad, y_grad):
    angle = np.arctan2(y_grad, x_grad) * 180.0 / np.pi
    if angle < 0:
        angle += 360

    if (angle < 45 or angle == 360):
        return 0
    elif (angle < 90):
        return 1
    elif (angle < 135):
        return 2
    elif (angle < 180):
        return 3
    elif (angle < 225):
        return 4
    elif (angle < 270):
        return 5
    elif (angle < 315):
        return 6
    else:
        return 7

def descriptor_gen(keypt, x_grad, y_grad):
    x, y, _, _ = keypt
    patch_x_start = 0 if x == 1 else x-2
    patch_y_start = 0 if y == 1 else x-2

    big_patch_x_grad = x_grad[patch_x_start:patch_x_start+4, patch_y_start:patch_y_start+4]
    big_patch_y_grad = y_grad[patch_x_start:patch_x_start+4, patch_y_start:patch_y_start+4]

    desc = []

    for r in range(0, 4, 2):
        for c in range(0, 4, 2):
            small_patch_x_grad = big_patch_x_grad[r:r+2, c:c+2].flatten()
            small_patch_y_grad = big_patch_y_grad[r:r+2, c:c+2].flatten()

            hist = [0] * 8

            for i in range(small_patch_x_grad.shape[0]):
                orientation = grad_orientation(small_patch_y_grad[i], small_patch_x_grad[i])
                hist[orientation] += 1
            
            desc += hist

    return desc

def match(keypoints1, descriptors1, keypoints2, descriptors2):
    '''
    Inputs: 
        keypoints1: length n list of keypoints from the first image where each keypoint
                    if given as (x, y, octave, scale), where octaves are 1 indexed
        descriptors1: length n list of descriptors from the first image where each descriptor
                    given as a length 32 vector of values from 0 to 4 inclusive
        keypoints2: length m list of keypoints from the second image where each keypoint
                    if given as (x, y, octave, scale), where octaves are 1 indexed
        descriptors2: length m list of descriptors from the second image where each descriptor
                    given as a length 32 vector of values from 0 to 4 inclusive
    
    Returns: 
        cv2_keypoints1: length n list of keypoints in keypoints1 as cv2.Keypoint
        cv2_keypoints2: length m list of keypoints in keypoints2 as cv2.Keypoint
        matches: list of matches of type cv2.DMatch
    '''
    cv2_keypoints1 = [cv2.KeyPoint(x * 2**(octave-1), y * 2**(octave-1), octave) for (x, y, octave, _) in keypoints1]
    cv2_keypoints2 = [cv2.KeyPoint(x * 2**(octave-1), y * 2**(octave-1), octave) for (x, y, octave, _) in keypoints2]

    matches = []

    for i in range(len(descriptors1)):
        d1 = descriptors1[i]
        distances = [np.linalg.norm(d1 - d2) for d2 in descriptors2]
        indices_sorted = np.argsort(distances)
        distances_sorted = np.sort(distances)

        if (distances_sorted[1] != 0 and distances_sorted[0] / distances_sorted[1] <= 0.9):
            # accept match
            matches.append(cv2.DMatch(i, indices_sorted[0], distances_sorted[0]))

    return cv2_keypoints1, cv2_keypoints2, matches

def draw_matches(img1, img2, keypoints1, descriptors1, keypoints2, descriptors2):
    keypoints1, keypoints2, matches = match(keypoints1, descriptors1, keypoints2, descriptors2)

    matched_img = cv2.drawMatches(img1, keypoints1, img2, keypoints2, matches, None)

    # Window name in which image is displayed 
    window_name = 'matches'
    
    # Using cv2.imshow() method 
    # Displaying the image 
    matched_img_bigger = cv2.resize(matched_img, (600, 300))
    cv2.imshow(window_name, matched_img_bigger) 
    cv2.waitKey()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: {0} <image to convert>".format(sys.argv[0]))

    else:
        input_fname = sys.argv[1]
        image_in = Image.open(input_fname)
        image_in = image_in.convert('RGB')

        # Resize the image
        image_in = image_in.resize((64, 64))
        image_in_rot = Image.fromarray(np.rot90(np.array(image_in)))
        
        images = [image_in, image_in_rot]

        keypoints1 = []
        keypoints2 = []
        desc1 = []
        desc2 = []
        for i in range(len(images)):
            im = images[i]
            pixels = []
            w, h = im.size

            # # Take input image and divide each color channel's value by 16
            for y in range(h):
                for x in range(w):
                    r, g, b = im.getpixel((x, y))
                    pixels.append(int(0.2126*r+0.7152*g+0.0722*b))
            print(h, w, len(pixels))

            pixels_reshaped = np.asarray(pixels).reshape((64, 64))
            pyramid = calc_pyramid(pixels_reshaped, h, w)

            O1_dog1 = dog(pyramid[0], pyramid[1])
            O1_dog2 = dog(pyramid[1], pyramid[2])
            O2_dog1 = dog(pyramid[3], pyramid[4])
            O2_dog2 = dog(pyramid[4], pyramid[5])
            O3_dog1 = dog(pyramid[6], pyramid[7])
            O3_dog2 = dog(pyramid[7], pyramid[8])

            num_O1_keypts, O1_keypt_inds = find_extrema(O1_dog1, O1_dog2, dim=w)
            num_O2_keypts, O2_keypt_inds = find_extrema(O2_dog1, O2_dog2, dim=w//2)
            num_O3_keypts, O3_keypt_inds = find_extrema(O3_dog1, O3_dog2, dim=w//4)
            print("found ", num_O1_keypts + num_O2_keypts + num_O3_keypts, " extrema")

            all_keypoints = []
            for kp in O1_keypt_inds:
                x, y, scale = kp
                all_keypoints.append((x, y, 1, scale+1))
            for kp in O2_keypt_inds:
                x, y, scale = kp
                all_keypoints.append((x, y, 2, scale+1))
            for kp in O3_keypt_inds:
                x, y, scale = kp
                all_keypoints.append((x, y, 3, scale+1))
            
            gradient_pyramid_x, gradient_pyramid_y = calc_gradient_pyramid(pixels_reshaped, h, w)
            
            all_descriptors = []
            for keypt in all_keypoints:
                _, _, octave, scale = keypt
                if octave == 1 and scale == 1:
                    all_descriptors.append(np.array(descriptor_gen(keypt, gradient_pyramid_x[0], gradient_pyramid_y[0])))
                if octave == 1 and scale == 2:
                    all_descriptors.append(np.array(descriptor_gen(keypt, gradient_pyramid_x[1], gradient_pyramid_y[1])))
                if octave == 2 and scale == 1:
                    all_descriptors.append(np.array(descriptor_gen(keypt, gradient_pyramid_x[3], gradient_pyramid_y[3])))
                if octave == 2 and scale == 2:
                    all_descriptors.append(np.array(descriptor_gen(keypt, gradient_pyramid_x[4], gradient_pyramid_y[4])))
                if octave == 3 and scale == 1:
                    all_descriptors.append(np.array(descriptor_gen(keypt, gradient_pyramid_x[6], gradient_pyramid_y[6])))
                if octave == 3 and scale == 2:
                    all_descriptors.append(np.array(descriptor_gen(keypt, gradient_pyramid_x[7], gradient_pyramid_y[7])))

            if i == 0:
                keypoints1 = all_keypoints
                desc1 = all_descriptors
            else:
                keypoints2 = all_keypoints
                desc2 = all_descriptors

        draw_matches(np.array(images[0]).astype(np.uint8), np.array(images[1]).astype(np.uint8), keypoints1, desc1, keypoints2, desc2)
