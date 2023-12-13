import numpy as np
import cv2

def match(keypoints1, descriptors1, keypoints2, descriptors2):
    '''
    Inputs: 
        keypoints1: length n list of keypoints from the first image where each keypoint
                    if given as (x, y, octave), where octaves are 1 indexed
        descriptors1: length n list of descriptors from the first image where each descriptor
                    given as a length 32 vector of values from 0 to 4 inclusive
        keypoints2: length m list of keypoints from the second image where each keypoint
                    if given as (x, y, octave), where octaves are 1 indexed
        descriptors2: length m list of descriptors from the second image where each descriptor
                    given as a length 32 vector of values from 0 to 4 inclusive
    
    Returns: 
        cv2_keypoints1: length n list of keypoints in keypoints1 as cv2.Keypoint
        cv2_keypoints2: length m list of keypoints in keypoints2 as cv2.Keypoint
        matches: list of matches of type cv2.DMatch
    '''
    cv2_keypoints1 = [cv2.KeyPoint(x * 2**(octave-1), y * 2**(octave-1), octave) for (x, y, octave) in keypoints1]
    cv2_keypoints2 = [cv2.KeyPoint(x * 2**(octave-1), y * 2**(octave-1), octave) for (x, y, octave) in keypoints2]

    matches = []

    for i in range(len(descriptors1)):
        d1 = descriptors1[i]
        distances = [np.linalg.norm(d1 - d2) for d2 in descriptors2]
        indices_sorted = np.argsort(distances)
        distances_sorted = np.sort(distances)

        if (distances_sorted[1] / distances_sorted[0] <= 0.8):
            # accept match
            matches.append(cv2.DMatch(i, indices_sorted[0], distances_sorted[0]))

    return cv2_keypoints1, cv2_keypoints2, matches

def draw_matches(img1, img2, keypoints1, descriptors1, keypoints2, descriptors2):
    keypoints1, keypoints2, matches = match(keypoints1, descriptors1, keypoints2, descriptors2)

    matched_img = cv2.drawMatches(img1, keypoints1, img2, keypoints2, matches)

    # Window name in which image is displayed 
    window_name = 'matches'
    
    # Using cv2.imshow() method 
    # Displaying the image 
    cv2.imshow(window_name, matched_img) 
