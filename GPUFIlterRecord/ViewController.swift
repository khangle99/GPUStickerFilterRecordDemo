//
//  ViewController.swift
//  GPUFIlterRecord
//
//  Created by Khang L on 21/10/2022.
//

import UIKit
import AVKit
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var previewView: GPUImageView!
    
    private var videoCamera: VideoCamera!
    private let cameraSize = CGSize(width: 720, height: 1280)
    
    private var filterManager = FilterManager.shared
    private var filterGroup: GPUImageFilterGroup?
    
    // record
    private var liveRecorder = LiveRecorder()
    private var recordFileURL: URL?
    private var output = GPUImageFilter()
    
    private var isRecording = false {
        didSet {
            if isRecording {
                recordBtn.setImage(UIImage(named: "record_stop"), for: .normal)
                if let url = recordFileURL {
                    liveRecorder.recordFileURL = url
                    liveRecorder.startRecord(gpuImageOutput: output)
                } else {
                    print("Cant get image output")
                }
                
            } else {
                liveRecorder.finishRecord()
                recordBtn.setImage(UIImage(named: "record_start"), for: .normal)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        requestPhotoLibraryPermission()

        filterManager.cameraSize = cameraSize

        videoCamera = VideoCamera(sessionPreset: AVCaptureSession.Preset.hd1280x720.rawValue, cameraPosition: .front, useYuv: false)
        videoCamera.frameRate = 24
        videoCamera.delegate = self
        videoCamera.addTarget(output)
        output.addTarget(self.previewView)
        videoCamera.startCapture()
        
        // enable filter to test
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.configureFilter()
        }
    }
    
    private func requestPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        if  status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                switch status {
                case .notDetermined:
                    break
                case .restricted:
                    break
                case .denied:
                    break
                case .authorized:
                    self?.enableRecord()
                case .limited:
                    break
                @unknown default:
                    fatalError()
                }
            }
        } else if status == .authorized {
            enableRecord()
        }
    }
    
    private func enableRecord() {
        DispatchQueue.main.async {
            self.recordBtn.isHidden = false
        }
        
        liveRecorder.delegate = self
        liveRecorder.size = self.cameraSize
        recordFileURL = generateUrl()
    }
   
    private func configureFilter() {
        filterManager.isPigStickerOn = true
        filterManager.isBeautyOn = true
        videoCamera.removeAllTargets()
        if let filter = filterManager.composedFilter() {
            self.filterGroup = filter
            videoCamera.addTarget(filterGroup)
            filter.addTarget(output)
            output.addTarget(self.previewView)
        } else {
            videoCamera.addTarget(self.output)
            output.addTarget(self.previewView)
        }
    }

    @IBAction func recordBtnTap(_ sender: Any) {
        isRecording.toggle()
    }
    
    private func saveToAlbum(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { saved, error in
            if saved {
                DispatchQueue.main.sync {
                    let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                    let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alertController.addAction(defaultAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func generateUrl() -> URL? {
        let tempDocument = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy hh:mm:ss"
        return tempDocument?.appendingPathComponent("TestView_\(dateFormatter.string(from: now)).mp4")
    }
}

extension ViewController: GPUImageVideoCameraDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
        filterManager.configureFaceWidget(sampleBuffer: sampleBuffer)
    }
}


extension ViewController: LiveRecorderDelegate {
    func recordCompeleted() {
        guard let recordFileURL = recordFileURL else {
            print("No URL for record file")
            return
        }
        
        saveToAlbum(url: recordFileURL)
    }
    
    func recordFailWithError(_ error: Error) {
        print("Error \(error)")
    }
}
