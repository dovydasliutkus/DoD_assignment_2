# # compare_pgm_data.py

# file1 = "pattern_result.pgm"
# file2 = "pattern_sobel.pgm"

# mismatch_limit = 5  # show first 5 mismatches
# mismatches = 0

# with open(file1, "r") as f1, open(file2, "r") as f2:
#     # Skip first 3 header lines
#     for _ in range(3):
#         next(f1)
#         next(f2)

#     line_num = 4  # start counting after headers

#     while mismatches < mismatch_limit:
#         line1 = f1.readline()
#         line2 = f2.readline()

#         if not line1 or not line2:
#             print("Reached end of one file.")
#             break

#         val1 = line1.strip()
#         val2 = line2.strip()

#         if val1 != val2:
#             print(f"Mismatch {mismatches + 1} at line {line_num}:")
#             print(f"  File1: {val1}")
#             print(f"  File2: {val2}")
#             mismatches += 1

#         line_num += 1

#     if mismatches == 0:
#         print("No mismatches found.")
#     elif mismatches < mismatch_limit:
#         print(f"Found {mismatches} mismatches (less than {mismatch_limit}).")
#     else:
#         print(f"Stopped after {mismatch_limit} mismatches.")

# compare_pgm_data_multi.py

# === Configuration ===
files = [
    r"..\other_images\cross_result.pgm",
    r"..\task2\golden\cross_sobel.pgm",
    r"..\other_images\illusion_result.pgm",
    r"..\task2\golden\illusion_sobel.pgm",
    r"..\other_images\kaleidoscope_result.pgm",
    r"..\task2\golden\kaleidoscope_sobel.pgm",
    r"..\other_images\pattern_result.pgm",
    r"..\task2\golden\pattern_sobel.pgm",
    r"..\other_images\systemverilog_result.pgm",
    r"..\task2\golden\systemverilog_sobel.pgm",
    r"..\other_images\pic1_result.pgm",
    r"..\task2\golden\pic1_sobel.pgm",
]

mismatch_limit = 5  # show first 5 mismatches


def compare_pgm(file1, file2, mismatch_limit=5):
    print(f"\nComparing:\n  {file1}\n  {file2}\n")

    mismatches = 0

    with open(file1, "r") as f1, open(file2, "r") as f2:
        # Skip header lines (first 3)
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
        print("✅ No mismatches found.")
    elif mismatches < mismatch_limit:
        print(f"⚠️ Found {mismatches} mismatches (less than {mismatch_limit}).")
    else:
        print(f"❌ Stopped after {mismatch_limit} mismatches.")


# === Compare pairs of files ===
for i in range(0, len(files), 2):
    compare_pgm(files[i], files[i + 1], mismatch_limit)
