# Face Detect


## CSIRO Face Analysis SDK

Sử dụng [CSIRO Face Analysis SDK](http://face.ci2cv.net/doc/) (OpenCV base) để detect khuôn mặt 
Tổng quan:
CSIRO Face Analysis được sử dụng để detect các landmark trong khuôn mặt (66 điểm).

Flow xử lý:
- Ảnh từng frame (CMSampleBuffer) của video camera được convert thành cv::Mat của OpenCV
```objective-c
// tham khảo hàm grepFacesForSampleBuffer trong OpenCVWrapper.mm

CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
CVPixelBufferLockBaseAddress( imageBuffer, 0 );
int format_opencv = CV_8UC4;

void* bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
size_t width = CVPixelBufferGetWidth(imageBuffer);
size_t height = CVPixelBufferGetHeight(imageBuffer);
size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);

cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow);
```
- Ảnh được resize và chuyển thành ảnh trắng đen.
```objective-c++
// tham khảo hàm grepFacesForSampleBuffer trong OpenCVWrapper.mm
cv::resize(image(cv::Rect(0,160,720,960)),image,cv::Size(scale*image.cols,scale*image.cols * 1.33),0 ,0 ,cv::INTER_NEAREST);
__block cv::Mat_<uint8_t> gray_image;
cv::cvtColor(image, gray_image, CV_BGR2GRAY);
```
- Sử dụng OpenCV Cascade Classifier (Haar Classifier) để detect rect của khuôn mặt trong ảnh.
```objective-c++
// tham khảo hàm landmark trong FaceDetect.mm
std::vector<cv::Rect> face_detections = fdet.detectAll(gray_image,scanFaceSize);
```
- Sử dụng SDK để track landmark trên mặt và get ra các điểm landmark (66 point) trên rect trên. Hàm trackerWithRect trả về trackerHealth là số int, giá trị từ 0 - 10, thể hiện tracking quality. Số càng cao độ chính xác và chắc chắn về face detect từ ảnh càng cao.
```objective-c++
// tham khảo hàm landmark trong FaceDetect.mm
// trackerRect là một cv::Rect, biểu thị vị trí rect khuôn mặt trong ảnh
// get track result
int trackerHealth = ((FACETRACKER::myFaceTracker *)tracker)->trackerWithRect(gray_image,tracker_params,trackerRect);
// get landmark points
std::vector<cv::Point_<double> > shape = tracker->getShape();
```
- Các landmark sẽ được đưa qua cho filter sử dụng như gắn sticker, face mask,..

#  GPUImage 
## Tổng quan GPUImage
[GPUImage](https://github.com/BradLarson/GPUImage) (version 1) sử dụng OpenGL ES 2.0 để thực hiện thao tác hình ảnh và video nhanh hơn nhiều so với CPU, điều này cần thiết với live camera video khi cần xử lý từng frame video với thời gian ngắn.

Sử dụng Framework với kiến trúc chain: 

```swift
Source object (GPUImageOutput) ->  các filters (GPUImageOutput and conform GPUImageInput protocal) ->  Output object (GPUImageInput)
```
* Bắt đầu với source object để lấy nội dung ảnh, video (Camera, Ảnh, Video)
* Nối các source object đi qua các filter (filter chain), bản chất filter là các Shader của OpenGL  (sử dụng ngôn ngữ GLSL)
* Ở filter cuối cùng của filter chain sẽ nối với các object output (render lên View, File save). Hoặc có thể trích xuất trực tiếp data ảnh / video frame từ các filter.
## Face Filter

Các face filter có thể sử dụng 3 loại widget:
* Sticker/ Animated Sticker: Là filter sử dụng sticker ảnh 2d, không thể biến dạng theo khuôn mặt mà chỉ bám vào các vị trí trên mặt, với kích cỡ, góc nghiêng, vị trí tỷ lệ theo khuôn mặt
* Face Mask: Là filter sử dụng ảnh mask phủ lên mặt user, với khả năng track theo khuôn mặt, biến dạng theo khuôn mặt (mở miệng, nhắm mắt,..)
* Mesh:  Là filter cho phép biến dạng khuôn mặt (làm mặt to, thon gọn, kéo dài, thu nhỏ,..)
*Note: 1 Filter không nhất thiết sử dụng một loại trong 3, có thể vừa có sticker vừa có mesh,..


Bản chất là các filter cho GPUImage, với input là toạ độ các landmark trên khuôn mặt được trả về sau quá trình detect khuôn mặt.
 Face filter được xử lý ở GPU, code bằng GL Shading Language (GLSL) để xử lý ảnh qua OpenGL.

### Cấu trúc filter resource
Để chuẩn bị 1 filter cần tạo 1 thư mục chứa filter data, chứa thông tin, tài nguyên filter: 
```swift
filterName/
├─ filterName.json
├─ widget1/
│  ├─ widget1_000.png
│  ├─ widget1_001.png
├─ widget2/
│  ├─ widget2_000.png
│  ├─ widget2.crd
│  ├─ widget2.idx
```
 * Mỗi widget tạo 1 subfolder
 * File ảnh đơn (face mask) hoặc list ảnh (animated sticker) cho mỗi item.
 * File json mô tả face filter.
 * Với face mask thì cần thêm 2 file idx và crd để mô tả vị trí khuôn mặt trong file ảnh mask

###  Cấu trúc filter json
 Tương ứng với 3 loại widget: sẽ có key là "meshs", "items", "skin" (mesh filter, sticker, mask). Với value là array define biểu hiện từng widget.
```json
{
    "meshs": [{
        "type": 2,
        "strength": 0.4000000134110451,
        "radius": 0.41,
        "position": 1,
        "direction": 0,
        "insert": "{0.0, 0, 0, 0}"
    }, {
        "type": 2,
        "strength": 0.4000000134110451,
        "radius": 0.41,
        "position": 2,
        "direction": 0,
        "insert": "{0.0, 0, 0, 0}"
    }, {
        "type": 1,
        "strength": 0.3999999985098839,
        "radius": 1.02,
        "position": 3,
        "direction": 0,
        "insert": "{0.0, 0, 0, 0}"
    }],
    "skins": [{
        "folderName": "topknot",
    }],
    "items": [{
        "width": 222,
        "height": 102,
        "looping": 1,
        "position": 6,
        "frameDuration": 50,
        "scale": 1.65,
        "insert": "{-0.0, 0, 0, 0}",
        "frames": 21,
        "folderName": "bizi"
    }, {
        "width": 340,
        "height": 100,
        "looping": 1,
        "position": 0,
        "frameDuration": 50,
        "scale": 2.6,
        "insert": "{-1.2, 0, 0, 0}",
        "frames": 21,
        "folderName": "erduo"
    }]
}
```
#### Meshs (meshs key)

```json
{
 "meshs": [{
        "type": 2,
        "strength": 0.4000000134110451,
        "radius": 0.41,
        "position": 1,
        "direction": 0,
        "insert": "{0.0, 0, 0, 0}"
    }, {
        "type": 2,
        "strength": 0.4000000134110451,
        "radius": 0.41,
        "position": 2,
        "direction": 0,
        "insert": "{0.0, 0, 0, 0}"
    }, {
        "type": 1,
        "strength": 0.3999999985098839,
        "radius": 1.02,
        "position": 3,
        "direction": 0,
        "insert": "{0.0, 0, 0, 0}"
    }]
}
```
Với mỗi element trong mesh:
* position: vị trí tác động
```
Center 2 mắt = 0
Center mắt trái = 1
Center mắt phải = 2
Giữa miệng = 3
Mép miệng trái = 4
Mép miệng phải = 5
Đầu mũi = 6
Top môi = 7
Bottom môi = 8
```
* type: loại transformation tại vị trí position
```
Phóng to = 1
Thu nhỏ = 2
Di chuyển = 3
```
* radius: bán kính tác động (với 1 tương dương )
* direction: hướng tác động
```
Tại chỗ = 0
Trái = 1 
Trên = 2
Phải = 3
Dưới = 4
```
* insert: inset ({top, left, bottom, right})
* strength: cường độ tác động 

#### Sticker (items key)

```json
{
    "items": [{
              "width": 222,
              "height": 102,
              "looping": 1,
              "position": 6,
              "scale": 1.65,
              "insert": "{-0.0, 0, 0, 0}",
              "frames": 21,
              "folderName": "bizi"
              },
              
              {
              "width": 340,
              "height": 100,
              "looping": 1,
              "position": 0,
              "scale": 2.6,
              "insert": "{-1.2, 0, 0, 0}",
              "frames": 21,
              "folderName": "erduo"
              }]
}
```
* position: như mesh
* insert: như mesh
* width/ height: dài rộng của sticker
* looping: 1-0
* frames: số lượng ảnh (widgetName_xxx.png)
* folderName: tên folder widget (trùng với prefix của các ảnh từng frame)
* scale: tỷ lệ phóng của sticker 
#### Face Mask (skins key)

```json
"skins": [{
		"folderName": "topknot",
	}]
```
* folderName: tên thư mục widget chưa ảnh mask (widgetName_000.png), crd file, idx file.

## Video Recording
(Class LiveRecorder trong demo)
Sử dụng GPUImageMovieWriter của [GPUImage](https://github.com/BradLarson/GPUImage) để record video xuống file

* Start record
GPUImageMovieWriter sử dụng output từ filter cuối cùng của filter chain để làm input cho việc ghi video xuống file
```swift
func startRecord(gpuImageOutput: GPUImageOutput) {
    videoInput = gpuImageOutput
    guard let recordFileURL = recordFileURL,
          let writter = GPUImageMovieWriter(movieURL: recordFileURL, size: size) else {
        print("Fail to record")
        return
    }

    movieWriter = writter
    writter.shouldPassthroughAudio = true
    writter.delegate = self
    gpuImageOutput.audioEncodingTarget = movieWriter

    gpuImageOutput.addTarget(movieWriter)
    writter.startRecording()
}
```
* Finish record 
 Để hoàn thành record video, cần ngắt mắc xích đang truyền video frame vào writter và sử  dụng finishRecording() để hoàn tất việc record video 
```swift
func finishRecord() {
    videoInput?.removeTarget(movieWriter)
    movieWriter?.finishRecording {
            print("Finish record")
    }
}
```
* MovieWritter Delegate
GPUImageMovieWritter Delegate  call các hàm thông báo trạng thái của writter
```swift
extension LiveRecorder: GPUImageMovieWriterDelegate {
    func movieRecordingCompleted() {
        print("Compelete record")
    }
    
    func movieRecordingFailedWithError(_ error: Error!) {
        print("Record fail with description: \(error.localizedDescription)")
    }
}
```