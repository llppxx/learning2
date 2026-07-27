//
//  VideoCapture.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/17.
//

import Foundation
import AVFoundation
import Photos

/// 视频拍摄流程管理
final class VideoCapture: NSObject {

    // MARK: - 属性
    let movieOutput = AVCaptureMovieFileOutput()

    var isRecording: Bool {
        movieOutput.isRecording
    }

    /// 录像开始回调
    var onRecordingStarted: (() -> Void)?

    /// 录像完成回调
    var onRecordingFinished: ((URL) -> Void)?

    // MARK: - 录像控制
    func startRecording(to url: URL) {
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording() {
        movieOutput.stopRecording()
    }

    /// 生成带时间戳的视频文件路径
    func generateVideoURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        let fileName = "video_\(dateString).mov"
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let outputURL = tempDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        return outputURL
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoCapture: AVCaptureFileOutputRecordingDelegate {

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        print("🎥 开始录制视频: \(fileURL.absoluteString)")
        DispatchQueue.main.async { [weak self] in
            self?.onRecordingStarted?()
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error = error {
            print("视频录制出错: \(error.localizedDescription)")
            return
        }

        print("📹 视频录制完成: \(outputFileURL)")
        onRecordingFinished?(outputFileURL)
        saveVideo(outputFileURL)
    }

    private func saveVideo(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("未获得相册写入权限")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("🎉 视频已保存到相册")
                        try? FileManager.default.removeItem(at: url)
                        print("🧹 临时文件已清除")
                    } else if let error = error {
                        print("视频保存失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
