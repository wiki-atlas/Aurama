# Aurama - A mobile application for finding places of interest

This is the iOS implementation of the paper: Notable Site Recognition using Deep Learning on Mobile and Crowd-sourced Imagery

|Image|Localization|Wikipedia Description|
| :------: | :------: | :------: |
|![ScreenShot1](Screenshots/ScreenShot1.png)|![ScreenShot2](Screenshots/ScreenShot2.png)|![ScreenShot3](Screenshots/ScreenShot3.png)

## Usage:

1. On macOS, install CocoaPods
2. run `pod install`
3. open `Aurama.xcworkspace` to build and run Aurama
4. Import images from in TestPhoto to iOS device to test model performance on different images.

## Credit:

1. Pytorch torch script implementation in iOS: [https://pytorch.org/mobile/ios/](https://pytorch.org/mobile/ios/)
2. Semantic Segmentation for Landmarks: [https://github.com/BlindAssist/blindassist-ios](https://github.com/BlindAssist/blindassist-ios)