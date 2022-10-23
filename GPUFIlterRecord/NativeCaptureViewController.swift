//
//  NativeCaptureViewController.swift
//  GPUFIlterRecord
//
//  Created by Khang L on 22/10/2022.
//

import Foundation

class NativeCaptureViewController: UIViewController {
    
    private var filterManager = FilterManager.shared
    private let cameraSize = CGSize(width: 720, height: 1280)
    
    @IBOutlet weak var previewView: GPUImageView!
    
    private var session: AVCaptureSession!
    private var gpuImagePixelInput: YUGPUImageCVPixelBufferInput!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        filterManager.cameraSize = cameraSize
        session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        
        gpuImagePixelInput = YUGPUImageCVPixelBufferInput()
       
        let micro = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified)
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video,position: .front)
        if let _ = try? videoDevice?.lockForConfiguration() {
            videoDevice?.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 24)
            videoDevice?.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 24)
            videoDevice?.unlockForConfiguration()
        }
        
        if let videoDevice = videoDevice,
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
           let micro = micro,
           let audioInput = try? AVCaptureDeviceInput(device: micro) {
            session.addInput(videoInput)
            session.addInput(audioInput)
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: .init(label: "SampleQueue"))
            
            session.addOutput(output)
           
            session.commitConfiguration()
            session.startRunning()
            gpuImagePixelInput.addTarget(previewView)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.configureFilter()
        }
    }
    private var filterGroup: GPUImageFilterGroup?
    
    private func configureFilter() {
        filterManager.isPigStickerOn = true
        filterManager.isBeautyOn = true
        
        if let filter = filterManager.composedFilter() {
            
//            gpuImagePixelInput.removeAllTargets()
//            self.filterGroup = filter
//            gpuImagePixelInput.addTarget(filterGroup)
//            filter.addTarget(self.previewView)
        }
    }

}

extension NativeCaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = true
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
       // CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
       // CFRetain(pixelBuffer);
        filterManager.configureFaceWidget(pixelBuffer: pixelBuffer)
        gpuImagePixelInput.processCVPixelBuffer(pixelBuffer)
        //CVPixelBufferUnlockBaseAddress(pixelBuffer, .init(rawValue: 0))
    }
}
