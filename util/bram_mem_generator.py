import numpy as np

def convert_to_mem(bram, name):
    with open(name, 'w') as f:
        print(bram.flatten())
        for entry in bram.flatten():
            f.write(f'{np.binary_repr(entry, width=9)}\n')

        print(f'given bram saved at {name}')

if __name__ == "__main__":
    # writing two random 4 by 4 brams with an extrema at 1, 2!
    first_bram = np.asarray([[0, 0, -1, 0],
                             [0, -2, 1, 0],
                             [0, -3, 0, 0],
                             [0, 0, 0, -4]])
    convert_to_mem(first_bram, 'util/first_test_bram.mem')

    second_bram = np.asarray([[0, 0, -1, 0],
                             [0, -2, -11, 0],
                             [0, -3, 0, 0],
                             [0, 0, 0, -4]])
    convert_to_mem(second_bram, 'util/second_test_bram.mem')