import numpy as np
import cv2

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

    print(matches)
    matched_img = cv2.drawMatches(img1, keypoints1, img2, keypoints2, matches, None)

    # Window name in which image is displayed 
    window_name = 'matches'
    
    # Using cv2.imshow() method 
    # Displaying the image 
    matched_img_bigger = cv2.resize(matched_img, (600, 300))
    cv2.imshow(window_name, matched_img_bigger) 
    cv2.waitKey()

if __name__ == "__main__":
    DIMENSION = 64
    NUMBER_KEYS_PER_SCALE = 5
    OCTAVES = 2
    SCALES = 2
    keypoints_1 = []
    for octave in range(OCTAVES):
        for scale in range(SCALES):
            for key in range(NUMBER_KEYS_PER_SCALE):
                pt = (np.random.randint(1,high = DIMENSION//(2**octave)-2), 
                      np.random.randint(1,high = DIMENSION//(2**octave)-2), 
                      octave+1,
                      scale+1)
                keypoints_1.append(pt)
                
    keypoints_2 = []
    for octave in range(OCTAVES):
        for scale in range(SCALES):
            for key in range(NUMBER_KEYS_PER_SCALE):
                pt = (np.random.randint(1,high = DIMENSION//(2**octave)-2), 
                      np.random.randint(1,high = DIMENSION//(2**octave)-2), 
                      octave+1,
                      scale+1)
                keypoints_2.append(pt)

    im1_O1L1_x = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    im1_O1L1_y = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    im1_O1L2_x = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    im1_O1L2_y = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))

    im1_O2L1_x = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    im1_O2L1_y = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    im1_O2L2_x = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    im1_O2L2_y = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))

    im2_O1L1_x = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    im2_O1L1_y = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    im2_O1L2_x = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    im2_O1L2_y = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))

    im2_O2L1_x = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    im2_O2L1_y = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    im2_O2L2_x = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    im2_O2L2_y = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))

    im1_desc = []
    for keypt in keypoints_1:
        _, _, octave, scale = keypt
        if octave == 1 and scale == 1:
            im1_desc.append(np.array(descriptor_gen(keypt, im1_O1L1_x, im1_O1L1_y)))
        if octave == 1 and scale == 2:
            im1_desc.append(np.array(descriptor_gen(keypt, im1_O1L2_x, im1_O1L2_y)))
        if octave == 2 and scale == 1:
            im1_desc.append(np.array(descriptor_gen(keypt, im1_O2L1_x, im1_O2L1_y)))
        if octave == 2 and scale == 2:
            im1_desc.append(np.array(descriptor_gen(keypt, im1_O2L2_x, im1_O2L2_y)))
    
    im2_desc = []
    for keypt in keypoints_2:
        _, _, octave, scale = keypt
        if octave == 1 and scale == 1:
            im2_desc.append(np.array(descriptor_gen(keypt, im2_O1L1_x, im2_O1L1_y)))
        if octave == 1 and scale == 2:
            im2_desc.append(np.array(descriptor_gen(keypt, im2_O1L2_x, im2_O1L2_y)))
        if octave == 2 and scale == 1:
            im2_desc.append(np.array(descriptor_gen(keypt, im2_O2L1_x, im2_O2L1_y)))
        if octave == 2 and scale == 2:
            im2_desc.append(np.array(descriptor_gen(keypt, im2_O2L2_x, im2_O2L2_y)))
    
    img1 = (np.ones((64, 64)) * 255).astype(np.uint8)
    img2 = (np.zeros((64, 64))).astype(np.uint8)
    draw_matches(img1, img2, keypoints_1, im1_desc, keypoints_2, im2_desc)
