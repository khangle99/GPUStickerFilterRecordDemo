//
//  ViewController.swift
//  GPUFIlterRecord
//
//  Created by Khang L on 21/10/2022.
//

import UIKit
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var previewView: GPUImageView!
    private var videoCamera: VideoCamera!
    private var filterManager = FilterManager.shared
    private let cameraSize = CGSize(width: 720, height: 1280)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        filterManager.cameraSize = cameraSize
        
        videoCamera = VideoCamera(sessionPreset: AVCaptureSession.Preset.hd1280x720.rawValue, cameraPosition: .front, useYuv: false)
        videoCamera.frameRate = 24
        videoCamera.delegate = self
        
        videoCamera.addTarget(previewView)
        
        videoCamera.startCapture()
        //configureFilter()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.configureFilter()
        }
    }
    private var filterGroup: GPUImageFilterGroup?

    private func configureFilter() {
        filterManager.isPigStickerOn = true
        //filterManager.isBeautyOn = true
        
        if let filter = filterManager.composedFilter() {
            
            videoCamera.removeAllTargets()
            self.filterGroup = filter
            videoCamera.addTarget(filterGroup)
            filter.addTarget(self.previewView)
        }
    }

}

extension ViewController: GPUImageVideoCameraDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
        //print("random: \(Int.random(in: 1...1000))")
        filterManager.configureFaceWidget(sampleBuffer: sampleBuffer)
    }
}
