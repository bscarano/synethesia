//
//  Copyright © 2019 Thesia. All rights reserved.
//

import UIKit
import CoreMedia
import Vision
import AVFoundation
import AudioKit


class PreviewViewController: UIViewController {
    
    @IBOutlet var ContainerView: UIView!
    @IBOutlet weak var realityImageView: UIImageView!
    
    @IBOutlet weak var debugView: UIView!
    @IBOutlet weak var pixelatedImageView: UIImageView!
    @IBOutlet weak var centerPixelLabel: UILabel!
    
    private var videoCapture: VideoCapture!
    private var requests = [VNRequest]()
    private let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
    
    static let OSCILLATOR_COLUMNS = 5   // Note: do not change without updating X_ANGLES
    static let OSCILLATOR_ROWS = 3      // Note: do not change without updating Y_ANGLES
    static let OSCILLATOR_TOTAL = OSCILLATOR_ROWS * OSCILLATOR_COLUMNS
    static let PIXEL_RESOLUTION = 4     // todo: Not sure what this const means
    
    // Wall of sound angles
    static let X_ANGLES = [-85.0, -40, 0.0, 40, 85.0]
    static let Y_ANGLES = [85.0,  0.0, -85.0]

    private var oscillators = [[AKOscillator?]](repeating: [AKOscillator?](repeating: nil, count: OSCILLATOR_COLUMNS), count: OSCILLATOR_ROWS)
    private var panners = [[AK3DPanner?]](repeating: [AK3DPanner?](repeating: nil, count: OSCILLATOR_COLUMNS), count: OSCILLATOR_ROWS)
    private var lastObserved = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        startAudio()
        setupVideoCapture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else {return}
        videoCapture.resizePreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        super.viewWillDisappear(animated)
    }
}


fileprivate extension PreviewViewController {
    
    func createVideoCapture(){
        let spec = VideoSpec(fps: 5, size: CGSize(width: 299, height: 299))
        videoCapture = VideoCapture(cameraType: .dual, preferredSpec: spec, previewContainer: nil)
        
        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer) in
            self.handleImageBuffer(imageBuffer: imageBuffer)
        }
        
        videoCapture.depthDataHandler = {[unowned self] (depthData) in
            self.handleDepthData(depthData: depthData)
        }
        
        videoCapture.startCapture()
    }
    
    // create and add a UISwitch to the container view
    func createButton(){
        let switchOnOff = UISwitch(frame:CGRect(x: 50, y: 50, width: 0, height: 0))
        switchOnOff.addTarget(self, action: #selector(PreviewViewController.switchStateDidChange(_:)), for: .valueChanged)
        switchOnOff.setOn(true, animated: false)
        self.ContainerView.addSubview(switchOnOff)
    }
    
    // create video view(s)
    func createViews(){
        // TODO: change the current storyboard to not use the interface builder at all
        let realityImageView = UIView(frame: CGRect(x: 10, y: 10, width: screenWidth, height: screenHeight))
        self.ContainerView.addSubview(realityImageView)
    }
    
    func setupVideoCapture() {
        createButton()
        createVideoCapture()
    }
    
    // Screen width.
    var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    // Screen height.
    var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    func toggleViews( boolHuh:Bool ) {
        self.centerPixelLabel.isHidden = !boolHuh // debug mode
        self.pixelatedImageView.isHidden = !boolHuh // debug mode
        self.realityImageView.isHidden = boolHuh // realityy mode
        
        //self.ContainerView.bringSubview(toFront: self.pixelatedImageView)
    }
    
    @objc func switchStateDidChange(_ sender:UISwitch){
        toggleViews(boolHuh: sender.isOn)
    }
    
    func handleImageBuffer( imageBuffer: CMSampleBuffer! ) {
        
        let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer)!
        
        let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
        
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let uiImage:UIImage = UIImage.init(cgImage: cgImage)
        
        // load image into reality view on storyboard
        DispatchQueue.main.async { [weak self] in
            self?.realityImageView.image = uiImage
        }
    }
    
    
    func handleDepthData(depthData: AVDepthData) {
        let pixelBuffer = depthData.depthDataMap
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent)!

        let uiImage = UIImage(cgImage: cgImage)

        DispatchQueue.main.async { [weak self] in
            self?.pixelatedImageView.image = uiImage
        }
        
        playSoundsForDistances(depthImage: cgImage)
    }
    
    var exifOrientationFromDeviceOrientation: Int32 {
        let exifOrientation: DeviceOrientation
        enum DeviceOrientation: Int32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = .top0ColLeft
        case .landscapeRight:
            exifOrientation = .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }

    func convertToImage(pixelBuffer: CVPixelBuffer) -> CGImage {
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        
        let filter1 = CIFilter(name: "CILanczosScaleTransform")!
        filter1.setValue(ciImage, forKey: "inputImage")
        filter1.setValue(0.0097, forKey: "inputScale")
        let outputImage1 = filter1.value(forKey: "outputImage") as! CIImage
        
        let cgImage = self.context.createCGImage(outputImage1, from: outputImage1.extent)!
        return cgImage
    }
}


fileprivate extension PreviewViewController {
    func startAudio() {
        
        // Pretty Good Tutorial  https://www.raywenderlich.com/835-audiokit-tutorial-getting-started
        // Reference Docs        https://audiokit.io/docs/index.html
        
        // Init mixer to combine all oscillators
        let mixer = AKMixer()
        mixer.start()
        
        AudioKit.output = mixer
        
        do {
            try AudioKit.start()
            
            // Print a 1 sec refence tone for the wall of oscillators
            print("Starting Audio Test Sequence...")
            
            for y in 0..<PreviewViewController.OSCILLATOR_ROWS {
                for x in 0..<PreviewViewController.OSCILLATOR_COLUMNS {
                    
                    // Wire oscillator to 3d panner to the global mixer
                    let oscillator = AKOscillator()
                    let panner = AK3DPanner(oscillator)
                    mixer.connect(input: panner)
                    
                    // Compute reference x, y, z position for dist 1.5
                    let dist = 1.5
                    let xangle = PreviewViewController.X_ANGLES[x]
                    let yangle = PreviewViewController.Y_ANGLES[y]
                    
                    let xz = computeXYCoord(c: dist, angle: xangle)
                    let xy = computeXYCoord(c: dist, angle: yangle)
                    
                    // Apply Position to 3D Panner
                    panner.x = xz.0
                    panner.z = xz.1
                    panner.y = xy.0
                    
                    // Add Oscillator and Panner to Global Lookups
                    setOscillator(oscillator: oscillator, x: x, y: y)
                    setPanner(panner: panner, x: x, y: y)
                    
                    // Play the reference tone
                    print("1 Sec Test Oscillator [\(x), \(y)] Panner: \(panner.x) \(panner.z) \(panner.y)")
                    turnOff(oscillator)
                    oscillator.start()
                    
                    if y == 0 {
                        // turn on for 1 sec
                        turnOn(oscillator)
                        sleep(1)
                        turnOff(oscillator)
                    }
                }
            }
        } catch {
            print("Error starting AudioKit")
        }
    }
    
    
    func setOscillator(oscillator: AKOscillator, x: Int, y: Int) {
        oscillators[y][x] = oscillator
    }
    
    
    func oscillatorForRegion(x: Int, y: Int) -> AKOscillator {
        return oscillators[y][x]!
    }
    
    
    func setPanner(panner: AK3DPanner, x: Int, y: Int) {
        panners[y][x] = panner
    }
    
    
    func pannerForRegion(x: Int, y: Int) -> AK3DPanner {
        return panners[y][x]!
    }
    
    func turnOff(_ oscillator: AKOscillator) {
        // amplitude is volume
        oscillator.amplitude = 0.0
    }
    
    func turnOn(_ oscillator: AKOscillator) {
        // amplitude is volume, setting all oscillators to 1.0 causes static
        oscillator.amplitude = 0.18
    }
    
    /**
     * Takes the distance map and plays the sound wall
     */
    func playSoundsForDistances(depthImage: CGImage) {
        
        // Temp save distances to print depths to console
        var distances = Array( repeating: Array(repeating: 255.0, count: PreviewViewController.OSCILLATOR_COLUMNS), count: PreviewViewController.OSCILLATOR_ROWS)
        
        for rowY in 0..<PreviewViewController.OSCILLATOR_ROWS {
            let yangle = PreviewViewController.Y_ANGLES[rowY]
            
            for columnX in 0..<PreviewViewController.OSCILLATOR_COLUMNS {
                
                let xangle = PreviewViewController.X_ANGLES[columnX]
                
//                var dist = getDistanceForRegionCenter(depthImage: depthImage, x: columnX, y: rowY)
                
                var dist = getDistanceForRegionAverage(depthImage: depthImage, x: columnX, y: rowY)
                
                dist = decimalRound(dist).squareRoot()  // squareroot to make volume linear to distance
                let DIST_SOUND_THRESHOLD = 12.0
                
                // If distance change isn't greater than 1/5th the range, skip along :)
                if abs(dist - distances[rowY][columnX]) < (12.2 - 1.0) / 5 {
                    continue
                }
                
                distances[rowY][columnX] = decimalRound(dist)
    
                let xz = computeXYCoord(c: dist, angle: xangle)
                let xy = computeXYCoord(c: dist, angle: yangle)
                
                let xPos = decimalRound(xz.0)
                let zPos = decimalRound(xz.1)
                let yPos = decimalRound(xy.0)
                
                let oscillator = oscillatorForRegion(x: columnX, y: rowY)
                let panner = pannerForRegion(x: columnX, y: rowY)
                
                let minFreq = 250.0
                let maxFreq = 350.0
                
                let freq = linear_scale(dist, 1.5, 10, maxFreq, minFreq)
                oscillator.frequency = freq
                
                // Turn far away regions completely off
                if dist >= DIST_SOUND_THRESHOLD {
                    turnOff(oscillator)
                } else {
                    panner.x = xPos
                    panner.y = yPos
                    panner.z = zPos
                    turnOn(oscillator)
                }
                
                // Print and play details of one oscillator
                if (columnX == PreviewViewController.OSCILLATOR_COLUMNS / 2)
                    && (rowY == PreviewViewController.OSCILLATOR_ROWS / 2) {
                    
                    let coordMsg = "LOC(\(columnX)/\(rowY)) dist: \(dist) freq \(freq) , x:\(xPos), y:\(yPos), z:\(zPos)"
                    DispatchQueue.main.async {
                        self.centerPixelLabel.text = coordMsg
                    }
                }
            }
            // Print the distance raw values for sanity check
            print(distances[rowY])
        }
        // newline for next Depth Image
        print("\n")
    }
}
