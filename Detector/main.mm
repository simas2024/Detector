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
        if (argc < 4) {
            fprintf(stderr, "Usage: %s <frameEnd> <input.mov> <output.mov>\n", argv[0]);
            return 1;
        }

        NSUInteger frameEnd = (NSUInteger)atoi(argv[1]);
        NSString *inputPath = [NSString stringWithUTF8String:argv[2]];
        NSString *outputPath = [NSString stringWithUTF8String:argv[3]];

        Detector d("bestYv11_03", ".");
        d.exportDetectedFramesUpTo(frameEnd,
            [NSURL fileURLWithPath:inputPath],
            [NSURL fileURLWithPath:outputPath]);
    }
    return 0;
}
