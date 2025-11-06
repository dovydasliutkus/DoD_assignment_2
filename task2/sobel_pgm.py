import numpy as np
import matplotlib.pyplot as plt

def read_pgm(filename):
    """Read a PGM file and return a numpy array of grayscale values."""
    with open(filename, 'rb') as f:
        header = f.readline().decode().strip()
        if header not in ('P2', 'P5'):
            raise ValueError("Unsupported PGM format (must be P2 or P5).")

        # Skip comment lines
        line = f.readline().decode().strip()
        while line.startswith('#'):
            line = f.readline().decode().strip()

        # Read width and height
        width, height = map(int, line.split())
        maxval = int(f.readline().decode().strip())

        if header == 'P5':
            # Binary format
            img = np.fromfile(f, dtype=np.uint8 if maxval < 256 else np.uint16, count=width*height)
        else:
            # ASCII format
            img = np.loadtxt(f, dtype=np.uint8, max_rows=width*height)
        
        img = img.reshape((height, width))
        return img

def sobel_edge_detection(img):
    """Apply Sobel edge detection to a grayscale image."""
    # Sobel kernels
    Kx = np.array([[-1, 0, 1],
                   [-2, 0, 2],
                   [-1, 0, 1]], dtype=float)
    
    Ky = np.array([[-1, -2, -1],
                   [ 0,  0,  0],
                   [ 1,  2,  1]], dtype=float)
    
    # Pad image to handle borders
    padded = np.pad(img, ((1, 1), (1, 1)), mode='constant')

    Gx = np.zeros_like(img, dtype=float)
    Gy = np.zeros_like(img, dtype=float)

    # Convolve manually
    for i in range(img.shape[0]):
        for j in range(img.shape[1]):
            region = padded[i:i+3, j:j+3]
            Gx[i, j] = np.sum(Kx * region)
            Gy[i, j] = np.sum(Ky * region)

    # Gradient magnitude
    G = np.sqrt(Gx**2 + Gy**2)
    G = (G / G.max() * 255).astype(np.uint8)
    return G

def save_pgm(filename, img):
    """Save a numpy array as a PGM file."""
    height, width = img.shape
    with open(filename, 'wb') as f:
        f.write(b'P5\n')
        f.write(f"{width} {height}\n".encode())
        f.write(b'255\n')
        img.tofile(f)

if __name__ == "__main__":
    input_file = "pattern.pgm"
    output_file = "edges.pgm"

    img = read_pgm(input_file)
    edges = sobel_edge_detection(img)
    save_pgm(output_file, edges)

    # Display result
    plt.subplot(1, 2, 1)
    plt.title("Original")
    plt.imshow(img, cmap='gray')

    plt.subplot(1, 2, 2)
    plt.title("Sobel Edges")
    plt.imshow(edges, cmap='gray')

    plt.show()

    print(f"Saved edge-detected image as '{output_file}'")
