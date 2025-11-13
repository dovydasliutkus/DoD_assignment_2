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
    // Implemented manually according to the provided diagram: copy edge
    // pixels outward for the border and copy corner pixels into corner regions.
    cv::Mat padded(imgGray.rows + 2 * border, imgGray.cols + 2 * border, imgGray.type());
    // Fill center with original image
    imgGray.copyTo(padded(cv::Rect(border, border, imgGray.cols, imgGray.rows)));

    // Fill left and right borders by replicating first/last columns
    for (int y = 0; y < imgGray.rows; ++y) {
        uchar vLeft = imgGray.at<uchar>(y, 0);
        uchar vRight = imgGray.at<uchar>(y, imgGray.cols - 1);
        for (int x = 0; x < border; ++x) {
            padded.at<uchar>(y + border, x) = vLeft;
            padded.at<uchar>(y + border, imgGray.cols + border + x) = vRight;
        }
    }

    // Fill top and bottom borders by replicating first/last rows (center area)
    for (int x = 0; x < imgGray.cols; ++x) {
        uchar vTop = imgGray.at<uchar>(0, x);
        uchar vBottom = imgGray.at<uchar>(imgGray.rows - 1, x);
        for (int y = 0; y < border; ++y) {
            padded.at<uchar>(y, border + x) = vTop;
            padded.at<uchar>(imgGray.rows + border + y, border + x) = vBottom;
        }
    }

    // Fill corners by replicating the corner pixels
    uchar tl = imgGray.at<uchar>(0, 0);
    uchar tr = imgGray.at<uchar>(0, imgGray.cols - 1);
    uchar bl = imgGray.at<uchar>(imgGray.rows - 1, 0);
    uchar br = imgGray.at<uchar>(imgGray.rows - 1, imgGray.cols - 1);
    for (int y = 0; y < border; ++y) {
        for (int x = 0; x < border; ++x) {
            padded.at<uchar>(y, x) = tl;
            padded.at<uchar>(y, imgGray.cols + border + x) = tr;
            padded.at<uchar>(imgGray.rows + border + y, x) = bl;
            padded.at<uchar>(imgGray.rows + border + y, imgGray.cols + border + x) = br;
        }
    }

    // Apply Sobel-like kernels from the assignment on the padded image
    // Gx = [ -1  0 +1
    //        -2  0 +2
    //        -1  0 +1 ]
    // Gy = [ +1 +2 +1
    //         0  0  0
    //        -1 -2 -1 ]
    // We implement these explicitly using filter2D with CV_64F output.
    cv::Mat sobelXpad, sobelYpad;
    cv::Mat kernelX = (cv::Mat_<double>(3,3) << -1, 0, 1,
                                               -2, 0, 2,
                                               -1, 0, 1);
    cv::Mat kernelY = (cv::Mat_<double>(3,3) <<  1, 2, 1,
                                                0, 0, 0,
                                               -1,-2,-1);
    cv::filter2D(padded, sobelXpad, CV_64F, kernelX, cv::Point(-1,-1), 0, cv::BORDER_DEFAULT);
    cv::filter2D(padded, sobelYpad, CV_64F, kernelY, cv::Point(-1,-1), 0, cv::BORDER_DEFAULT);

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
        // Also save the padded image (with replicated border) for inspection
        std::string paddedName = inputPath.stem().string() + std::string("_padded.pgm");
        std::filesystem::path paddedPath = exeDir / paddedName;
        std::ofstream pofs(paddedPath, std::ios::out);
        if (!pofs.is_open()) {
            std::cerr << "Failed to open padded output file for writing: " << paddedPath.string() << std::endl;
        } else {
            pofs << "P2\n";
            pofs << "# Created by golden model (padded)\n";
            pofs << padded.cols << " " << padded.rows << "\n\n";
            for (int y = 0; y < padded.rows; ++y) {
                for (int x = 0; x < padded.cols; ++x) {
                    int v = static_cast<int>(padded.at<uchar>(y, x));
                    pofs << v << '\n';
                }
            }
            pofs.close();
            std::cout << "Saved padded image to: " << paddedPath.string() << std::endl;
        }
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
            ofs << "255\n"; // Max pixel value

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
