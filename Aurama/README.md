# Aurama - A mobile application for finding places of interest

Auther: Jimin Tan

This is the iOS implementation of the paper: Notable Site Recognition using Deep Learning on Mobile and Crowd-sourced Imagery

<div style="text-align: center;">
<img src="Screenshots/ScreenShot1.png" alt="rect-frame" style="zoom:20%;" align="middle"/>   <img src="Screenshots/ScreenShot2.png" alt="circ-frame" style="zoom:20%;" align="middle"/> <img src="Screenshots/ScreenShot3.png" alt="final-frame" style="zoom:20%;" align="middle"/>
</div>

## Usage:

1. On macOS, install CocoaPods
2. run `pod install`
3. open `Aurama.xcworkspace` to build and run Aurama
4. Drag `png` files in TestPhoto to iOS device to test model performance on different images.

## Credit:

1. Pytorch torch script implementation in iOS: [https://pytorch.org/mobile/ios/](https://pytorch.org/mobile/ios/)
2. Semantic Segmentation for Landmarks: [https://github.com/BlindAssist/blindassist-ios](https://github.com/BlindAssist/blindassist-ios)