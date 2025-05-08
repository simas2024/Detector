//
//  Detector.hpp
//  Detector
//
//  Created by Markus Schmid on 04.04.25.
//

#ifndef DETECTOR_HPP
#define DETECTOR_HPP

#include <string>
#include <vector>
#include <map>
#import <CoreGraphics/CGImage.h>
#import <AppKit/AppKit.h>

@class VNCoreMLModel;

using namespace std;

class Detector {
public:
    Detector(const std::string& modelNameStr, const std::string& basispfad);
    void exportDetectedToImg(const std::string& bildPfad, const std::string& ausgabePfad);
    void exportDetectedFramesUpTo(NSUInteger frameIndexEnde, NSURL* videoInURL, NSURL* videoOutURL);
    
private:
    CGImageRef detectImg(CGImageRef img);
    VNCoreMLModel* visionModel = nullptr;
};

#endif // DETECTOR_HPP
