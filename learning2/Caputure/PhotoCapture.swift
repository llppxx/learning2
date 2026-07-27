//
//  PhotoCapture.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/17.
//

import UIKit
import AVFoundation
import Photos

/// 照片拍摄流程管理
final class PhotoCapture: NSObject {

    // MARK: - 属性
    let photoOutput = AVCapturePhotoOutput()

    /// 拍照完成回调
    var onPhotoCaptured: ((UIImage) -> Void)?

    // MARK: - 拍照
    func capturePhoto(flashMode: AVCaptureDevice.FlashMode = .auto) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension PhotoCapture: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("拍照出错: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        print("📸 拍照成功，尺寸: \(image.size)")
        onPhotoCaptured?(image)
        saveImageToPhotosAlbum(image: image)
    }

    private func saveImageToPhotosAlbum(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("未获得相册写入权限")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("🎉 成功保存到系统相册")
                    } else if let error = error {
                        print("保存相册失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
