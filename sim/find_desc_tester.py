import numpy as np

def convert_to_mem(bram, name):
    with open(name, 'w') as f:
        print(bram)
        for entry in bram.flatten():
            f.write(f'{np.binary_repr(entry, width=8)}\n')

        print(f'given bram saved at {name}')

def keypt_to_mem(keypt_array, second_keypts, name):
    with open(name, 'w') as f:
        print(keypt_array)
        for entry in keypt_array:
            f.write(f'{np.binary_repr(entry[0], width=6)}{np.binary_repr(entry[1], width=6)}{entry[2]}\n')
        f.write(f'{np.binary_repr(0, width=13)}\n')
        for entry in second_keypts:
            f.write(f'{np.binary_repr(entry[0], width=6)}{np.binary_repr(entry[1], width=6)}{entry[2]}\n')
        for i in range(1000-len(keypt_array)-len(second_keypts)-1):
            f.write(f'{np.binary_repr(0, width=13)}\n')
        print(f'given bram saved at {name}')

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
    x, y, _ = keypt
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


if __name__ == "__main__":
    DIMENSION = 64
    NUMBER_KEYS = 10
    keypoints = []
    sharp = True
    for key in range(NUMBER_KEYS):
        pt = (np.random.randint(1,high = DIMENSION-2), np.random.randint(1,high = DIMENSION-2), int(sharp))
        sharp = not sharp
        keypoints.append(pt)

    second_keypts = []
    sharp = True
    for key in range(NUMBER_KEYS):
        pt = (np.random.randint(1,high = (DIMENSION/2)-2), np.random.randint(1,high = (DIMENSION/2)-2), int(sharp))
        sharp = not sharp
        second_keypts.append(pt)
    
    
    keypt_to_mem(keypoints, second_keypts, 'keypoints.mem')

    O1L1_x = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    convert_to_mem(O1L1_x, 'O1L1_x.mem')
    O1L1_y = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    convert_to_mem(O1L1_y, 'O1L1_y.mem')
    O1L2_x = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    convert_to_mem(O1L2_x, 'O1L2_x.mem')
    O1L2_y = np.random.randint(-128,high = 127, size=(DIMENSION, DIMENSION))
    convert_to_mem(O1L2_y, 'O1L2_y.mem')

    O2L1_x = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L1_x, 'O2L1_x.mem')
    O2L1_y = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L1_y, 'O2L1_y.mem')
    O2L2_x = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L2_x, 'O2L2_x.mem')
    O2L2_y = np.random.randint(-128,high = 127, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L2_y, 'O2L2_y.mem')

    O1L1_desc = [descriptor_gen(keypt, O1L1_x, O1L1_y) for keypt in keypoints if keypt[2] == 0]
    O1L2_desc = [descriptor_gen(keypt, O1L2_x, O1L2_y) for keypt in keypoints if keypt[2] == 1]
    O2L1_desc = [descriptor_gen(keypt, O2L1_x, O2L1_y) for keypt in second_keypts if keypt[2] == 0]
    O2L2_desc = [descriptor_gen(keypt, O2L2_x, O2L2_y) for keypt in second_keypts if keypt[2] == 1]

    print(O1L1_desc)
    print(O1L2_desc)
    print(O2L1_desc)
    print(O2L2_desc)
