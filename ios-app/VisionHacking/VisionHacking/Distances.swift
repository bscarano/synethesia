//
//  Copyright © 2019 Thesia. All rights reserved.
//

import UIKit
import CoreMedia
import Vision
import AVFoundation
import AudioKit


/**
 * Takes an angle and a hypotenuse/distance (c), and computes the (x, y) coordinate.
 * the Double.pi / 180 stuff is converting from radians to degrees
 */
func computeXYCoord(c: Double, angle: Double) -> (Double, Double) {
    let x = sin(angle * Double.pi / 180) * c
    let y = cos(angle * Double.pi / 180) * c
    return (x, y)
}


/*
 * Linearly scales an input range into an output range.
 */
func linear_scale(_ d: Double,_ min_input: Double,_ max_input: Double,_ min_output: Double,_ max_output: Double) -> Double {
    
    var x = d
    
    // Upper Bound Clip
    if x > max_input {
        x = max_input
    }
    
    // Lower Bound Clip
    if x < min_input {
        x = min_input
    }
    
    let inputRange = max_input - min_input
    let inputOffset = x - min_input
    
    let distanceScaleFactor = inputOffset / inputRange
    
    let outputRange = max_output - min_output
    
    let y = distanceScaleFactor * outputRange + min_output
    
    return y
}


/**
 * Pulls a distance value as a double from the CGImage depth image. It clips distances and scales the output for the audio space
 */
func getDistanceForRegionCenter(depthImage: CGImage, x: Int, y: Int) -> Double {
    
    let width = depthImage.width
    let height = depthImage.height
    
    let mapCellWidth = width / PreviewViewController.OSCILLATOR_COLUMNS
    let mapCellHeight = height / PreviewViewController.OSCILLATOR_ROWS
    
    let centerX = Int((Double(x) / Double(PreviewViewController.OSCILLATOR_COLUMNS)) * Double(width)) + (mapCellWidth/2)
    let centerY = Int((Double(y) / Double(PreviewViewController.OSCILLATOR_ROWS)) * Double(height)) + (mapCellHeight/2)
    
    let pixelData = depthImage.dataProvider!.data!
    let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
    
    let depthOfRegionCenter = Double(data[(centerY * width + centerX) * PreviewViewController.PIXEL_RESOLUTION])
    
    let minDistance = 160.0
    let maxDistance = 210.0
    
    // Scale and clip depth data
    return linear_scale(depthOfRegionCenter, minDistance, maxDistance, 150.0, 1.0)
}


/**
  * Take an average of the depth value surrounding the center of a region.
  */
func getDistanceForRegionAverage(depthImage: CGImage, x: Int, y: Int) -> Double {
    
    let width = depthImage.width
    let height = depthImage.height
    
    let regionWidth = width / PreviewViewController.OSCILLATOR_COLUMNS
    let regionHeight = height / PreviewViewController.OSCILLATOR_ROWS
    
    let widthOffet = regionWidth / 2
    let heightOffset = regionHeight / 2
    
    let centerX = Int((Double(x) / Double(PreviewViewController.OSCILLATOR_COLUMNS)) * Double(width)) + (widthOffet)
    let centerY = Int((Double(y) / Double(PreviewViewController.OSCILLATOR_ROWS)) * Double(height)) + (heightOffset)
    
    var totalLuminance = 0.0
    var pixelsInRegion = 0
    for x in (centerX - widthOffet/2)..<(centerX + widthOffet/2) {
        for y in (centerY - heightOffset/2)..<(centerY + heightOffset/2) {
            let pixelData = depthImage.dataProvider!.data!
            let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            let depthVal = Double(data[(y * width + x) * PreviewViewController.PIXEL_RESOLUTION])
            totalLuminance = totalLuminance + depthVal
            pixelsInRegion = pixelsInRegion + 1
        }
    }
    
    let depthOfRegion = totalLuminance / Double(pixelsInRegion)
    
    let minDistance = 160.0
    let maxDistance = 210.0
    
    // Scale and clip depth data
    return linear_scale(depthOfRegion, minDistance, maxDistance, 150.0, 1.0)
}


/**
 * Round double to tenths place to make logging easier.
 */
func decimalRound(_ a: Double) -> Double {
    return round(a*10) / 10
}


/**
 * Scales audio distances by the squareroot because volume drop off is not linear
 */
func distanceToAudioScale(_ d: Double) -> Double {
    if d >= 0.0 {
        return (d).squareRoot()
    }
    else {
        // negative squareroots are imaginary
        return (-d).squareRoot() * -1
    }
}
