//
//  main.m
//  Detector
//
//  Created by Markus Schmid on 04.04.25.
//

#include "Detector.hpp"
#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Detector d("bestYv11_03",".../");
        d.exportDetectedFramesUpTo(3000, [NSURL fileURLWithPath:@"clip.mov"], [NSURL fileURLWithPath:@"clip_detect.mov"]);
    }
    return 0;
}
