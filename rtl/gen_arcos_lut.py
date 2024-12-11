import math
NUM_SAMPLES = 2**6
START = 0
END = 2*math.pi #domain is from [-1, 1] but because of sum below im adding 2 to get there
# outputs NUM_SAMPLES*math.acos, dont forget to divide by NUM_SAMPLES if accuracy wanted
for i in range(NUM_SAMPLES):
    print(f"6'd{i}: range<={int(NUM_SAMPLES*math.cos(START + i*(END/NUM_SAMPLES)))};")