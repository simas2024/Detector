# Detector

This is a small Xcode project containing a class that processes a video using a Core ML object detection model based on Ultralytics YOLOv11n. The model was trained on a custom dataset of approximately 1000 annotated images. The class analyzes the input video frame by frame, detects objects, and generates a new video with all detected objects highlighted using bounding boxes.

---

## Description


### Example

Here is a series of frames from the original video (left) and the generated clip with bounding boxes (right):

| Original Frame                | Detected with Bounding Boxes     |
|------------------------------|----------------------------------|
| ![](./docs/clip1/frame_1.webp.png) | ![](./docs/clip2/frame_1.webp.png) |
| ![](./docs/clip1/frame_4.webp.png) | ![](./docs/clip2/frame_4.webp.png) |
| ![](./docs/clip1/frame_6.webp.png) | ![](./docs/clip2/frame_6.webp.png) |
| ![](./docs/clip1/frame_7.webp.png) | ![](./docs/clip2/frame_7.webp.png) |
| ![](./docs/clip1/frame_8.webp.png) | ![](./docs/clip2/frame_8.webp.png) |
| ![](./docs/clip1/frame_10.webp.png)| ![](./docs/clip2/frame_10.webp.png) |

---

## Setup

```bash
git clone https://github.com/simas2024/Detector.git
```

---

## Using the Xcode Project

### Build

- Open `Detector.xcodeproj` in Xcode
- All necessary settings are preconfigured
- Just press `⌘B`

### Run

To run a sample object detection, you can use and download the `clip640x424.mov` file from my repository https://github.com/simas2024/Dataset.git.

1. Open the Xcode project.
2. Build the project with `⌘B`.
3. In Terminal, change to the build directory:

```bash
cd <build-dir>
```

4.	Download the sample video:

```bash
curl -L -o clip.mov https://github.com/simas2024/Dataset/raw/refs/heads/main/Test/data/clip640x424.mov
```

5. Run the detection:

- In the Xcode project, press `⌘R` to run the app.
- The output (first 3000 frames) will be written to `clip_detect.mov`.

You can customize the file paths and the end frame directly in the code line inside [main.mm](./Detector/main.mm):

```objc
d.exportDetectedFramesUpTo(3000, [NSURL fileURLWithPath:@"clip.mov"], [NSURL fileURLWithPath:@"clip_detect.mov"]);
```

## Performance Benchmarks

Object detection performance (in frames per second, FPS) varies significantly depending on the hardware. The following measurements were taken using the given model and the clip from the example run https://github.com/simas2024/Dataset/raw/refs/heads/main/Test/data/clip640x424.mov:

| Device                  | CPU                      | Memory | Processing FPS |
|------------------------|--------------------------|--------|----------------|
| Mac mini M1 (2020)     | Apple M1                 | 16 GB  | ~80 FPS        |
| MacBook Air (2020) | Intel Core i7 @ 1.2 GHz  | 16 GB  | ~5 FPS         |

> Measurements cover end-to-end processing: reading, detection, bounding box overlay, and writing to output video.