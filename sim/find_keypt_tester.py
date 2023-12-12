import numpy as np

def convert_to_mem(bram, name):
    with open(name, 'w') as f:
        print(bram)
        for entry in bram.flatten():
            f.write(f'{np.binary_repr(entry, width=8)}\n')

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

if __name__ == "__main__":
    DIMENSION = 64
    first_bram = np.random.randint(0,high = 255, size=(DIMENSION, DIMENSION))
    convert_to_mem(first_bram, 'first_test_bram.mem')
    second_bram = np.random.randint(0,high = 255, size=(DIMENSION, DIMENSION))
    convert_to_mem(second_bram, 'second_test_bram.mem')
    third_bram = np.random.randint(0,high = 255, size=(DIMENSION, DIMENSION))
    convert_to_mem(third_bram, 'third_test_bram.mem')

    O2L1_bram = np.random.randint(0,high = 255, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L1_bram, 'O2L1_test_bram.mem')
    O2L2_bram = np.random.randint(0,high = 255, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L2_bram, 'O2L2_test_bram.mem')
    O2L3_bram = np.random.randint(0,high = 255, size=(int(DIMENSION/2), int(DIMENSION/2)))
    convert_to_mem(O2L3_bram, 'O2L3_test_bram.mem')


    O3L1_bram = np.random.randint(0,high = 255, size=(int(DIMENSION/4), int(DIMENSION/4)))
    convert_to_mem(O3L1_bram, 'O3L1_test_bram.mem')
    O3L2_bram = np.random.randint(0,high = 255, size=(int(DIMENSION/4), int(DIMENSION/4)))
    convert_to_mem(O3L2_bram, 'O3L2_test_bram.mem')
    O3L3_bram = np.random.randint(0,high = 255, size=(int(DIMENSION/4), int(DIMENSION/4)))
    convert_to_mem(O3L3_bram, 'O3L3_test_bram.mem')


    dog_one = dog(first_bram, second_bram)
    dog_two = dog(second_bram, third_bram)

    O2_dog_one = dog(O2L1_bram, O2L2_bram)
    O2_dog_two = dog(O2L2_bram, O2L3_bram)


    O3_dog_one = dog(O3L1_bram, O3L2_bram)
    O3_dog_two = dog(O3L2_bram, O3L3_bram)

    # print(dog_one, dog_two)
    number, indices = find_extrema(dog_one, dog_two, dim=DIMENSION)
    # for ind in indices:
        # if ind[2] == 0:
        #     print(dog_one[ind[1], ind[0]])
        # if ind[2] == 1:
        #     print(dog_two[ind[1], ind[0]])
    print("found ", number, " extrema")
    number2, indices = find_extrema(O2_dog_one, O2_dog_two, dim=int(DIMENSION/2))
    # for ind in indices:
    #     if ind[2] == 0:
    #         print(dog_one[ind[1], ind[0]])
    #     if ind[2] == 1:
    #         print(dog_two[ind[1], ind[0]])
    print("found ", number+number2, " extrema")
    number3, indices = find_extrema(O3_dog_one, O3_dog_two, dim=int(DIMENSION/4))
    print("found ", number+number2 + number3, " extrema")
