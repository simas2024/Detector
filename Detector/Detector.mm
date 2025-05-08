//
//  Detector.mm
//  Detector
//
//  Created by Markus Schmid on 04.04.25.
//

#import "Detector.hpp"
#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <AVFoundation/AVFoundation.h>

@implementation NSObject (SilenceUnusedWarnings) @end

namespace {

    CGImageRef cgImageFromSampleBuffer(CMSampleBufferRef sampleBuffer) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
        CGImageRef cgImage = CGBitmapContextCreateImage(context);
        
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        
        return cgImage;
    }

    CMSampleBufferRef sampleBufferFromCGImage(CGImageRef imageRef, CMSampleBufferRef timingSample) {
      CVPixelBufferRef pixelBuffer = NULL;
      CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef), kCVPixelFormatType_32BGRA, NULL, &pixelBuffer);
      
      CVPixelBufferLockBaseAddress(pixelBuffer, 0);
      void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
      CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef), 8, CVPixelBufferGetBytesPerRow(pixelBuffer), CGImageGetColorSpace(imageRef), kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
      CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef)), imageRef);
      CGContextRelease(context);
      CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
      
      CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(timingSample);
      CMTime duration = CMSampleBufferGetDuration(timingSample);
      CMSampleTimingInfo timingInfo = {duration, presentationTime, kCMTimeInvalid};
      
      CMVideoFormatDescriptionRef videoInfo = NULL;
      CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
      
      CMSampleBufferRef sampleBuffer = NULL;
      CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timingInfo, &sampleBuffer);
      
      CFRelease(videoInfo);
      CVPixelBufferRelease(pixelBuffer);
      
      return sampleBuffer;
    }
}

Detector::Detector(const std::string& modelNameStr, const std::string& basispfad) {
    @autoreleasepool {
        NSString* modelDir = [NSString stringWithUTF8String:basispfad.c_str()];
        NSString* modelName = [NSString stringWithUTF8String:modelNameStr.c_str()];
        NSString* fullPath = [modelDir stringByAppendingPathComponent:[modelName stringByAppendingString:@".mlmodelc"]];
        NSURL* modelURL = [NSURL fileURLWithPath:fullPath];
        
        NSError* error = nil;
        MLModel* model = [MLModel modelWithContentsOfURL:modelURL error:&error];
        if (!model) {
            NSLog(@"❌ Modell konnte nicht geladen werden: %@", error.localizedDescription);
            return;
        }
        
        visionModel = [VNCoreMLModel modelForMLModel:model error:nil];
    }
}

CGImageRef Detector::detectImg(CGImageRef inImage) {
    __block CGImageRef outImage;
    
    @autoreleasepool {

        size_t width = CGImageGetWidth(inImage);
        size_t height = CGImageGetHeight(inImage);

        // Bildkontext zum Zeichnen vorbereiten
        CGContextRef ctx = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 CGColorSpaceCreateDeviceRGB(),
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);

        CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), inImage);

        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        VNCoreMLRequest* request = [[VNCoreMLRequest alloc] initWithModel:visionModel completionHandler:^(VNRequest* req, NSError* err) {
            NSArray<VNRecognizedObjectObservation*>* results = req.results;
            CGContextSetStrokeColorWithColor(ctx, [[NSColor greenColor] CGColor]);
            CGContextSetLineWidth(ctx, 2.0);

            for (VNRecognizedObjectObservation* obj in results) {
                if (obj.confidence < 0.50) continue;

                CGRect box = VNImageRectForNormalizedRect(obj.boundingBox, width, height);
                CGContextStrokeRect(ctx, box);
            }

            outImage = CGBitmapContextCreateImage(ctx);

            dispatch_semaphore_signal(sema);
        }];

        VNImageRequestHandler* handler = [[VNImageRequestHandler alloc] initWithCGImage:inImage options:@{}];
        [handler performRequests:@[request] error:nil];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

        CGContextRelease(ctx);
    }
    
    return outImage;
}


void Detector::exportDetectedFramesUpTo(NSUInteger frameIndexEnde, NSURL* videoInURL, NSURL* videoOutURL) {
    AVAsset *asset = [AVAsset assetWithURL:videoInURL];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:videoOutURL error:nil];
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:videoOutURL fileType:AVFileTypeQuickTimeMovie error:&error];

    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    Float64 fps = videoTrack.nominalFrameRate; // z. B. 30.0
    CMTime frameDuration = CMTimeMake(1, fps); // Dauer eines Frames
    CMTime startTime = CMTimeMultiply(frameDuration, (int32_t)0); // Index beginnt bei 0
    NSDictionary *readerOutputSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
    AVAssetReaderTrackOutput *readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:readerOutputSettings];
    reader.timeRange = CMTimeRangeMake(startTime, kCMTimePositiveInfinity);
    [reader addOutput:readerOutput];

    NSDictionary *writerOutputSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(videoTrack.naturalSize.width),
        AVVideoHeightKey: @(videoTrack.naturalSize.height)
    };
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:writerOutputSettings];
    [writer addInput:writerInput];

    [reader startReading];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t processingQueue = dispatch_queue_create("processingQueue", NULL);
    [writerInput requestMediaDataWhenReadyOnQueue:processingQueue usingBlock:^{
        NSUInteger frameIndex=0;
        while (frameIndex<frameIndexEnde && [writerInput isReadyForMoreMediaData] && [reader status] == AVAssetReaderStatusReading) {
            CMSampleBufferRef sampleBuffer = [readerOutput copyNextSampleBuffer];
            if (sampleBuffer) {
                // Schritt 1: CMSampleBufferRef zu CGImageRef konvertieren
                CGImageRef inImage = cgImageFromSampleBuffer(sampleBuffer);
                if (inImage) {
                    // Schritt 2: Erkennungsfunktion aufrufen
                    CGImageRef processedImage = detectImg(inImage);
                    if (processedImage) {
                        // Schritt 3: CGImageRef zurück zu CMSampleBufferRef konvertieren
                        CMSampleBufferRef processedSampleBuffer = sampleBufferFromCGImage(processedImage, sampleBuffer);
                        if (processedSampleBuffer) {
                            // In den WriterInput schreiben
                            if ([writerInput isReadyForMoreMediaData]) {
                                [writerInput appendSampleBuffer:processedSampleBuffer];
                            }
                            CFRelease(processedSampleBuffer);
                        }
                        CGImageRelease(processedImage);
                    }
                    CGImageRelease(inImage);
                }
                CFRelease(sampleBuffer);
            }
            frameIndex++;
        }
        [writerInput markAsFinished];
        [writer finishWritingWithCompletionHandler:^{
            NSLog(@"✅ Alle Frames geschrieben, Ausgabe ist fertig.");
            exit(0);
        }];
    }];
    dispatch_main();
}

void Detector::exportDetectedToImg(const std::string& bildPfad, const std::string& ausgabePfad) {
    @autoreleasepool {
        NSString* path = [NSString stringWithUTF8String:bildPfad.c_str()];
        NSImage* img = [[NSImage alloc] initWithContentsOfFile:path];
        if (!img) {
            NSLog(@"⚠️ Bild konnte nicht geladen werden.");
            return;
        }

        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]];
        CGImageRef cgImage = [rep CGImage];

       
        VNCoreMLRequest* request = [[VNCoreMLRequest alloc] initWithModel:visionModel completionHandler:^(VNRequest* req, NSError* err) {
            NSArray<VNRecognizedObjectObservation*>* results = req.results;

            NSSize size = img.size;
            NSImage* output = [[NSImage alloc] initWithSize:size];
            [output lockFocus];
            [img drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0,0,size.width,size.height) operation:NSCompositingOperationSourceOver fraction:1.0];

            [[NSColor redColor] setStroke];
            for (VNRecognizedObjectObservation* obj in results) {
                CGRect box = VNImageRectForNormalizedRect(obj.boundingBox, size.width, size.height);
                NSBezierPath* path = [NSBezierPath bezierPathWithRect:box];
                [path stroke];
            }
            [output unlockFocus];

            NSData* outData = [output TIFFRepresentation];
            NSString* outPath = [NSString stringWithUTF8String:ausgabePfad.c_str()];
            [outData writeToFile:outPath atomically:YES];
        }];

        VNImageRequestHandler* handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
        [handler performRequests:@[request] error:nil];
    }
}
