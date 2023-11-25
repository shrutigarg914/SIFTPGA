import numpy as np

kernel = np.array([[1, 2, 1],
                    [2, 4, 2],
                    [1, 2, 1]])

print("Test 1")
r1 = [0, 0, 0]
r2 = [0, 0, 0]
r3 = [0, 0, 0]

rows = np.array([r1, r2, r3])

print("Test 1 Ans", int(np.sum(rows * kernel)))

print("Test 2")
r1 = [1, 1, 1]
r2 = [1, 1, 1]
r3 = [1, 1, 1]

rows = np.array([r1, r2, r3])

print("Test 2 Ans", int(np.sum(rows * kernel) / 16))

print("Test 3")
r1 = [1, 2, 3]
r2 = [4, 5, 6]
r3 = [7, 8, 9]

rows = np.array([r1, r2, r3])

print("Test 3 Ans", int(np.sum(rows * kernel) / 16))

print("Test 4")
r1 = [255, 255, 255]
r2 = [255, 255, 255]
r3 = [255, 255, 255]

rows = np.array([r1, r2, r3])

print("Test 4 Ans", int(np.sum(rows * kernel) / 16))

print("Test 5")
r1 = [0, 0, 0]
r2 = [0, 255, 0]
r3 = [0, 0, 0]

rows = np.array([r1, r2, r3])

print("Test 5 Ans", int(np.sum(rows * kernel) / 16))

print("Test 6")
r1 = [134, 2, 46]
r2 = [30, 25, 0]
r3 = [1, 9, 255]

rows = np.array([r1, r2, r3])

print("Test 6 Ans", int(np.sum(rows * kernel) / 16))
