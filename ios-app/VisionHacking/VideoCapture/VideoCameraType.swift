import AVFoundation


enum CameraType : Int {
    case back
    case front
    case dual
    
    func captureDevice() -> AVCaptureDevice {
        switch self {
        case .front:
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [], mediaType: AVMediaType.video, position: .front).devices
            print("devices:\(devices)")
            for device in devices where device.position == .front {
                return device
            }
        case .dual:
            let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
            return device!
        default:
            break
        }
        return AVCaptureDevice.default(for: AVMediaType.video)!
    }
}
