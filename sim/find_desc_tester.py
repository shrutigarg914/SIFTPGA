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

