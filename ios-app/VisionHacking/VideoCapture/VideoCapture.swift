import AVFoundation
import Foundation


struct VideoSpec {
    var fps: Int32?
    var size: CGSize?
}

typealias ImageBufferHandler = ((_ imageBuffer: CMSampleBuffer) -> ())
typealias DepthDataHandler = ((_ depthData: AVDepthData) -> ())

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate, AVCaptureDataOutputSynchronizerDelegate {

    private let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice!
    private var videoConnection: AVCaptureConnection!
    private var depthConnection: AVCaptureConnection!
    private var audioConnection: AVCaptureConnection!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var videoDeviceInput: AVCaptureDeviceInput!

    let videoDataQueue = DispatchQueue(label: "com.synesthesia.videosamplequeue")
    let depthDataQueue = DispatchQueue(label: "com.synesthesia.depthqueue")

    var imageBufferHandler: ImageBufferHandler?
    var depthDataHandler: DepthDataHandler?
    
    init(cameraType: CameraType, preferredSpec: VideoSpec?, previewContainer: CALayer?)
    {
        super.init()
        
        let defaultVideoDevice = videoDeviceDiscoverySession.devices.first
        guard let videoDevice = defaultVideoDevice else {
            print("Could not find any video device")
            fatalError()
        }
        
        videoDevice.updateFormatWithPreferredVideoSpec(preferredSpec: preferredSpec!)
        
        // get video-device
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            fatalError()
        }
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            fatalError()
        }
        session.addInput(videoDeviceInput)
        
        // setup preview
        if let previewContainer = previewContainer {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = previewContainer.bounds
            previewLayer.contentsGravity = kCAGravityResizeAspectFill
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewContainer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer
        }
        
        // setup video output
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        
        guard session.canAddOutput(videoDataOutput) else {
            fatalError()
        }
        session.addOutput(videoDataOutput)
        videoConnection = videoDataOutput.connection(with: AVMediaType.video)
        
        // setup depth output
        depthDataOutput.isFilteringEnabled = true
        depthDataOutput.alwaysDiscardsLateDepthData = true
        
        guard session.canAddOutput(depthDataOutput) else {
            fatalError()
        }
        session.addOutput(depthDataOutput)
        depthDataOutput.setDelegate(self, callbackQueue: videoDataQueue)
        
        depthConnection = depthDataOutput.connection(with: .depthData)
        depthConnection.isEnabled = true
        
        // setup the synchronizer
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: videoDataQueue)

        session.commitConfiguration()
    }
    
    func startCapture() {
        print("\(self.classForCoder)/" + #function)
        if session.isRunning {
            print("already running")
            return
        }
        session.startRunning()
    }
    
    func stopCapture() {
        print("\(self.classForCoder)/" + #function)
        if !session.isRunning {
            print("already stopped")
            return
        }
        session.stopRunning()
    }
    
    func resizePreview() {
        if let previewLayer = previewLayer {
            guard let superlayer = previewLayer.superlayer else {return}
            previewLayer.frame = superlayer.bounds
        }
    }
    
    // =========================================================================
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if connection.videoOrientation != .portrait {
            connection.videoOrientation = .portrait
            return
        }
        
        if let imageBufferHandler = imageBufferHandler {
            imageBufferHandler(sampleBuffer)
        }
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        if let depthDataHandler = depthDataHandler {
            depthDataHandler(depthData)
        }
    }
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        if let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData {
            if !syncedDepthData.depthDataWasDropped {
                let depthData = syncedDepthData.depthData
                processDepth(depthData: depthData)
            }
        }
        
        if let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData {
            if !syncedVideoData.sampleBufferWasDropped {
                let videoSampleBuffer = syncedVideoData.sampleBuffer
                processVideo(sampleBuffer: videoSampleBuffer)
            }
        }
    }
    
    func processDepth(depthData: AVDepthData) {
        if let depthDataHandler = depthDataHandler {
            depthDataHandler(depthData)
        }
    }
    
    func processVideo(sampleBuffer: CMSampleBuffer) {
        if let imageBufferHandler = imageBufferHandler {
            imageBufferHandler(sampleBuffer)
        }
    }
}

