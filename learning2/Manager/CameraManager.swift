//
//  CameraManager.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/17.
//

import AVFoundation

/// 相机会话管理
/// 只负责 AVCaptureSession 的配置，不涉及业务逻辑
final class CameraManager {

    // MARK: - 公开属性
    let captureSession = AVCaptureSession()

    private(set) var activeInput: AVCaptureDeviceInput?
    private(set) var audioInput: AVCaptureDeviceInput?

    let sessionQueue = DispatchQueue(label: "camera.session.queue")

    // MARK: - 配置
    func configureSession(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo

            // 添加后置摄像头
            guard let camera = CameraDevice.shared.getDefaultBackCamera() else {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
                return
            }

            do {
                let input = try CameraDevice.shared.createInput(for: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.activeInput = input
                }
            } catch {
                print("无法创建相机输入: \(error)")
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
                return
            }

            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    /// 在 sessionQueue 上执行配置块，完成后切换到主线程执行 UI 更新
    func configureSession(block: @escaping () -> Void, completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            block()
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // MARK: - 输入输出管理
    func addInput(_ input: AVCaptureInput) -> Bool {
        guard captureSession.canAddInput(input) else { return false }
        captureSession.addInput(input)
        return true
    }

    func addOutput(_ output: AVCaptureOutput) -> Bool {
        guard captureSession.canAddOutput(output) else { return false }
        captureSession.addOutput(output)
        return true
    }

    func removeInput(_ input: AVCaptureInput) {
        captureSession.removeInput(input)
    }

    // MARK: - 音频输入
    func addAudioInput() -> Bool {
        guard audioInput == nil else { return true }
        guard let input = try? CameraDevice.shared.createAudioInput() else { return false }
        if addInput(input) {
            audioInput = input
            return true
        }
        return false
    }

    func removeAudioInput() {
        guard let audio = audioInput else { return }
        removeInput(audio)
        audioInput = nil
    }

    // MARK: - 前后摄像头切换
    func switchCamera(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let currentInput = self.activeInput else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let currentPosition = currentInput.device.position
            let preferredPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back

            self.captureSession.beginConfiguration()
            self.captureSession.removeInput(currentInput)

            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice),
               self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.activeInput = newInput
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(true) }
            } else {
                self.captureSession.addInput(currentInput)
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - 会话控制
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }
}
