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
            if not (dx==0 and dy==0):
                if array_one[y + dy, x + dx] <= array_one[y, x]:
                    result[0][0] = False
                if array_one[y + dy, x + dx] >= array_one[y, x]:
                    result[0][1] = False
                if array_two[y + dy, x + dx] <= array_two[y, x]:
                    result[1][0] = False
                if array_two[y + dy, x + dx] >= array_two[y, x]:
                    result[1][1] = False

            if array_two[y + dy, x + dx] <= array_one[y, x]:
                result[0][0] = False
            if array_two[y + dy, x + dx] >= array_one[y, x]:
                result[0][1] = False
            
            if array_one[y + dy, x + dx] <= array_two[y, x]:
                result[1][0] = False
            if array_one[y + dy, x + dx] >= array_two[y, x]:
                result[1][1] = False
    
    return (result[0][1], result[0][0], result[1][0], result[1][1])

def find_extrema(array_one, array_two, dim =4):
    counter = 0
    for y in range(1, dim-1):
        for x in range(1, dim-1):
            is_one_max, is_one_min, is_two_min, is_two_max = point_is_extrema(array_one, array_two, x, y)
            if (is_one_max):
                print("Found MAX in BRAM 1 at (", x, ", ", y, ")")
                counter +=1
            if (is_one_min):
                print("Found min in BRAM 1 at (", x, ", ", y, ")")
                counter +=1
            if (is_two_max):
                counter +=1
                print("Found MAX in BRAM 2 at (", x, ", ", y, ")")
            if (is_two_min):
                counter +=1
                print("Found min in BRAM 2 at (", x, ", ", y, ")")
    return counter

if __name__ == "__main__":
    # writing two random 4 by 4 brams with an extrema at 1, 2!
    # first_bram = np.asarray([[0, 0, -1, 0],
    #                          [0, -2, 1, 0],
    #                          [0, 3, 0, 0],
    #                          [0, 0, 0, -4]])
    DIMENSION = 64

    first_bram = np.random.randint(-126,high = 126, size=(DIMENSION, DIMENSION))

    convert_to_mem(first_bram, 'first_test_bram.mem')

    # second_bram = np.asarray([[0, 0, -1, 0],
    #                          [0, -2, 11, 0],
    #                          [0, -3, 0, 0],
    #                          [0, 0, 0, -4]])

    second_bram = np.random.randint(-126,high = 126, size=(DIMENSION, DIMENSION))

    convert_to_mem(second_bram, 'second_test_bram.mem')

    print("found ", find_extrema(first_bram, second_bram, dim=DIMENSION), " extrema")