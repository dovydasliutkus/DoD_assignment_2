#include <opencv2/opencv.hpp>
#include <iostream>
#include <cmath>
#include <filesystem>
#include <fstream>

int main(int argc, char** argv)
{
    if (argc < 2)
    {
        std::cout << "Usage: sobel_wrap <image_path>" << std::endl;
        return -1;
    }

    // Load image in grayscale
    cv::Mat imgGray = cv::imread(argv[1], cv::IMREAD_GRAYSCALE);
    if (imgGray.empty())
    {
        std::cerr << "Error: Could not open or find the image!\n";
        return -1;
    }

    // Prepare Sobel parameters
    const int ksize = 3; // Sobel kernel size
    const int border = (ksize - 1) / 2; // number of pixels to pad on each side

    // Create a padded image by copying the edge pixels (replicate border)
    cv::Mat padded;
    cv::copyMakeBorder(imgGray, padded, border, border, border, border, cv::BORDER_REPLICATE);

    // Apply Sobel operator on the padded image (we'll crop the border later)
    cv::Mat sobelXpad, sobelYpad;
    cv::Sobel(padded, sobelXpad, CV_64F, 1, 0, ksize, 1, 0, cv::BORDER_DEFAULT);
    cv::Sobel(padded, sobelYpad, CV_64F, 0, 1, ksize, 1, 0, cv::BORDER_DEFAULT);

    // Compute gradient magnitude — use sum of absolute gradients
    // (|Gx| + |Gy|) instead of sqrt(Gx^2 + Gy^2)
    // Compute gradient magnitude on the padded result and then crop back to original size
    cv::Mat magnitudePad(padded.size(), CV_64F);
    for (int y = 0; y < padded.rows; ++y)
    {
        for (int x = 0; x < padded.cols; ++x)
        {
            double gx = sobelXpad.at<double>(y, x);
            double gy = sobelYpad.at<double>(y, x);
            magnitudePad.at<double>(y, x) = std::abs(gx) + std::abs(gy);
        }
    }

    // Crop the border off to get the final image the same size as the input
    cv::Rect roi(border, border, imgGray.cols, imgGray.rows);
    cv::Mat magnitude = magnitudePad(roi).clone();

    // Convert to 8-bit image for display
    cv::Mat mag8U;
    magnitude.convertTo(mag8U, CV_8U);

    // Show results
    cv::imshow("Original", imgGray);
    cv::imshow("Sobel Edge Magnitude with Wrap Borders", mag8U);
    // Save result into the same folder as the executable
    try {
        std::filesystem::path exePath = std::filesystem::absolute(argv[0]);
        std::filesystem::path exeDir = exePath.parent_path();
        std::filesystem::path inputPath(argv[1]);
        std::string outName = inputPath.stem().string() + std::string("_sobel.pgm");
        std::filesystem::path outPath = exeDir / outName;
        // Write ASCII (P2) PGM with a custom header and decimal pixel values
        // Header required by the user:
        // P2
        // # Created by golden model
        // <width> <height>
        std::ofstream ofs(outPath, std::ios::out);
        if (!ofs.is_open()) {
            std::cerr << "Failed to open output file for writing: " << outPath.string() << std::endl;
        } else {
            // Write header
            ofs << "P2\n";
            ofs << "# Created by golden model\n";
            ofs << mag8U.cols << " " << mag8U.rows << "\n";

            // Write pixel values one per line in decimal (row-major order)
            for (int y = 0; y < mag8U.rows; ++y) {
                for (int x = 0; x < mag8U.cols; ++x) {
                    int v = static_cast<int>(mag8U.at<uchar>(y, x));
                    ofs << v << '\n';
                }
            }

            ofs.close();
            std::cout << "Saved result to: " << outPath.string() << std::endl;
        }
    } catch (const std::exception &e) {
        std::cerr << "Could not determine executable path: " << e.what() << std::endl;
    }
    cv::waitKey(0);

    return 0;
}
