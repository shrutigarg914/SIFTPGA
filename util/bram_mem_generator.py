import numpy as np

def convert_to_mem(bram, name):
    with open(name, 'w') as f:
        print(bram)
        for entry in bram.flatten():
            f.write(f'{np.binary_repr(entry, width=9)}\n')

        print(f'given bram saved at {name}')

def point_is_extrema(array_one, array_two, x, y):
    result = [[True, True], [True, True]]
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            if array_one[y + dy, x + dx] < array_one[y, x]:
                result[0][0] = False
            if array_two[y + dy, x + dx] < array_one[y, x]:
                result[0][0] = False
            if array_one[y + dy, x + dx] > array_one[y, x]:
                result[0][1] = False
            if array_two[y + dy, x + dx] > array_one[y, x]:
                result[0][1] = False
            
            if array_two[y + dy, x + dx] < array_two[y, x]:
                result[1][0] = False
            if array_one[y + dy, x + dx] < array_two[y, x]:
                result[1][0] = False
            if array_two[y + dy, x + dx] > array_two[y, x]:
                result[1][1] = False
            if array_one[y + dy, x + dx] > array_two[y, x]:
                result[1][1] = False
    
    return (result[0][1] or result[0][0], result[1][0] or result[1][1])

def find_extrema(array_one, array_two, dim =4):
    for y in range(1, dim-1):
        for x in range(1, dim-1):
            is_one, is_two = point_is_extrema(array_one, array_two, x, y)
            if (is_one):
                print("Found extrema in BRAM 1 at (", x, ", ", y, ")")
            if (is_two):
                print("Found extrema in BRAM 2 at (", x, ", ", y, ")")

if __name__ == "__main__":
    # writing two random 4 by 4 brams with an extrema at 1, 2!
    # first_bram = np.asarray([[0, 0, -1, 0],
    #                          [0, -2, 1, 0],
    #                          [0, 3, 0, 0],
    #                          [0, 0, 0, -4]])

    first_bram = np.random.randint(-126,high = 126, size=(5, 5))

    convert_to_mem(first_bram, 'first_test_bram.mem')

    # second_bram = np.asarray([[0, 0, -1, 0],
    #                          [0, -2, 11, 0],
    #                          [0, -3, 0, 0],
    #                          [0, 0, 0, -4]])

    second_bram = np.random.randint(-126,high = 126, size=(5, 5))

    convert_to_mem(second_bram, 'second_test_bram.mem')

    find_extrema(first_bram, second_bram, dim=5)