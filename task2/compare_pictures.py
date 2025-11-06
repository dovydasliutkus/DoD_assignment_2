# compare_pgm_data.py

file1 = "pattern_result.pgm"
file2 = "pattern_sobel.pgm"

mismatch_limit = 5  # show first 5 mismatches
mismatches = 0

with open(file1, "r") as f1, open(file2, "r") as f2:
    # Skip first 3 header lines
    for _ in range(3):
        next(f1)
        next(f2)

    line_num = 4  # start counting after headers

    while mismatches < mismatch_limit:
        line1 = f1.readline()
        line2 = f2.readline()

        if not line1 or not line2:
            print("Reached end of one file.")
            break

        val1 = line1.strip()
        val2 = line2.strip()

        if val1 != val2:
            print(f"Mismatch {mismatches + 1} at line {line_num}:")
            print(f"  File1: {val1}")
            print(f"  File2: {val2}")
            mismatches += 1

        line_num += 1

    if mismatches == 0:
        print("No mismatches found.")
    elif mismatches < mismatch_limit:
        print(f"Found {mismatches} mismatches (less than {mismatch_limit}).")
    else:
        print(f"Stopped after {mismatch_limit} mismatches.")

