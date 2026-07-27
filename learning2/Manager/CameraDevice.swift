//
//  CameraDevice.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/17.
//

import AVFoundation

/// 摄像头设备管理
final class CameraDevice {

    // MARK: - 单例
    static let shared = CameraDevice()

    private init() {}

    // MARK: - 获取摄像头
    func getDefaultBackCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    func getDefaultFrontCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }

    func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    // MARK: - 创建输入
    func createInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        try AVCaptureDeviceInput(device: device)
    }

    // MARK: - 麦克风
    func getMicrophone() -> AVCaptureDevice? {
        AVCaptureDevice.default(for: .audio)
    }

    func createAudioInput() throws -> AVCaptureDeviceInput? {
        guard let microphone = getMicrophone() else { return nil }
        return try AVCaptureDeviceInput(device: microphone)
    }
}
