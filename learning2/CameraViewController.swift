//
//  CameraViewController.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/15.
//

import UIKit
import SnapKit
import AVFoundation

// MARK: - CameraMode
private enum CameraMode {
    case photo
    case video
}

// MARK: - CameraViewController
class CameraViewController: UIViewController {

    // MARK: - Manager & Capture
    private let cameraManager = CameraManager()
    private lazy var photoCapture = PhotoCapture()
    private lazy var videoCapture = VideoCapture()

    // MARK: - 状态
    private var currentMode: CameraMode = .photo
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isPreviewMode: Bool = false

    // MARK: - Init
    init(previewMode: Bool = false) {
        self.isPreviewMode = previewMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.isPreviewMode = false
        super.init(coder: coder)
    }

    // MARK: - UI 控件
    private lazy var cameraPreviewView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tapGesture)
        return view
    }()

    private lazy var shutterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
        return button
    }()

    private lazy var flipCameraButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let icon = UIImage(systemName: "camera.rotate.fill", withConfiguration: config)
        button.setImage(icon, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(didTapFlipCamera), for: .touchUpInside)
        return button
    }()

    private lazy var focusBoxView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.systemYellow.cgColor
        view.backgroundColor = .clear
        view.alpha = 0
        return view
    }()

    private lazy var videoModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("视频", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.addTarget(self, action: #selector(changeToVideoMode), for: .touchUpInside)
        return button
    }()

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        if isPreviewMode { return }
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraPreviewView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stop()
    }

    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .black

        view.addSubview(cameraPreviewView)
        view.addSubview(shutterButton)
        view.addSubview(flipCameraButton)
        view.addSubview(videoModeButton)
        view.addSubview(focusBoxView)

        cameraPreviewView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.size.equalTo(CGSize(width: 70, height: 70))
        }

        flipCameraButton.snp.makeConstraints { make in
            make.centerY.equalTo(shutterButton)
            make.trailing.equalToSuperview().offset(-40)
        }

        videoModeButton.snp.makeConstraints { make in
            make.centerY.equalTo(shutterButton)
            make.leading.equalToSuperview().offset(40)
        }
    }

    // MARK: - 相机配置
    private func setupCamera() {
        CameraPermission.shared.requestCameraPermission { [weak self] granted in
            guard granted else {
                print("用户拒绝了相机权限，请在系统设置中开启")
                return
            }
            self?.configureSession()
        }
    }

    private func configureSession() {
        cameraManager.configureSession { [weak self] success in
            guard success, let self = self else {
                print("相机配置失败")
                return
            }

            // 添加 photo output
            _ = self.cameraManager.addOutput(self.photoCapture.photoOutput)

            // 设置预览层
            let preview = AVCaptureVideoPreviewLayer(session: self.cameraManager.captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = self.cameraPreviewView.bounds
            self.cameraPreviewView.layer.insertSublayer(preview, at: 0)
            self.previewLayer = preview

            // 启动会话
            self.cameraManager.start()
        }
    }

    // MARK: - 交互事件

    @objc private func didTapShutter() {
        switch currentMode {
        case .photo:
            capturePhoto()
        case .video:
            toggleRecording()
        }
    }

    private func capturePhoto() {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
        photoCapture.capturePhoto()
    }

    private func toggleRecording() {
        if !videoCapture.isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        let url = videoCapture.generateVideoURL()
        videoCapture.startRecording(to: url)

        UIView.animate(withDuration: 0.2) {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.shutterButton.layer.cornerRadius = 10
        }
        shutterButton.backgroundColor = .systemRed
    }

    private func stopRecording() {
        videoCapture.stopRecording()

        UIView.animate(withDuration: 0.2) {
            self.shutterButton.transform = .identity
            self.shutterButton.layer.cornerRadius = 35
        }
        // 保持红色，录像模式下快门始终为红色
    }

    // MARK: - 模式切换（业务逻辑）

    @objc private func changeToVideoMode() {
        if videoCapture.isRecording {
            showWarning("正在录像中，请先停止录像再切换模式！")
            return
        }

        if currentMode == .photo {
            enterVideoMode()
        } else {
            enterPhotoMode()
        }
    }

    private func enterVideoMode() {
        CameraPermission.shared.requestMicrophonePermission { [weak self] granted in
            guard granted else {
                print("请到设置打开麦克风权限")
                return
            }
            self?.configureForVideoMode()
        }
    }

    private func configureForVideoMode() {
        cameraManager.sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.cameraManager.captureSession.beginConfiguration()

            // 添加音频输入
            if self.cameraManager.audioInput == nil {
                _ = self.cameraManager.addAudioInput()
            }

            // 添加视频输出
            if !self.cameraManager.captureSession.outputs.contains(self.videoCapture.movieOutput) {
                _ = self.cameraManager.addOutput(self.videoCapture.movieOutput)
            }

            self.cameraManager.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.currentMode = .video
                self.videoModeButton.setTitle("拍照模式", for: .normal)
                self.shutterButton.backgroundColor = .systemRed
                print("进入录像模式")
            }
        }
    }

    private func enterPhotoMode() {
        cameraManager.sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.cameraManager.captureSession.beginConfiguration()

            // 移除音频输入
            self.cameraManager.removeAudioInput()

            self.cameraManager.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.currentMode = .photo
                self.videoModeButton.setTitle("视频", for: .normal)
                self.shutterButton.backgroundColor = .white
                print("进入拍照模式")
            }
        }
    }

    @objc private func didTapFlipCamera() {
        if videoCapture.isRecording {
            showWarning("正在录像中，无法切换前后摄像头！")
            return
        }

        cameraManager.switchCamera { success in
            if !success {
                print("切换摄像头失败")
            }
        }
    }

    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: cameraPreviewView)
        print("点击屏幕对焦位置: \(touchPoint)")

        // 对焦动画
        CameraFocus.animateFocusBox(at: touchPoint, in: cameraPreviewView, focusBox: focusBoxView)

        // 执行对焦
        guard let device = cameraManager.activeInput?.device else { return }
        let cameraPoint = CameraFocus.convertToCameraCoordinate(point: touchPoint, in: cameraPreviewView)
        CameraFocus.focus(at: cameraPoint, in: device)

        // 触觉反馈
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    private func showWarning(_ message: String) {
        print("⚠️ \(message)")
        let warningFeedback = UINotificationFeedbackGenerator()
        warningFeedback.notificationOccurred(.warning)
    }
}

// MARK: - SwiftUI Preview
#if canImport(SwiftUI)
import SwiftUI
#Preview {
    CameraViewController(previewMode: true)
}
#endif
