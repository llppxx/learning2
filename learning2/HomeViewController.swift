//
//  HomeViewController.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/15.
//

import UIKit
import SnapKit
import AVFoundation
import Photos

private enum CameraMode {
    case photo
    case video
}

class HomeViewController: UIViewController {

    // MARK: - AVFoundation 核心成员变量
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var activeInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isRecording = false
    private var currentMode: CameraMode = .photo
    private let sessionQueue = DispatchQueue(
        label: "camera.session.queue"
    )
    
    // MARK: - 预览setting
    private var isPreviewMode: Bool = false
        // 便利初始化方法
    init(previewMode: Bool = false) {
        self.isPreviewMode = previewMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
            self.isPreviewMode = false // 从 Storyboard 加载时，默认不是预览模式
            super.init(coder: coder)
        }
    
    // MARK: - UI 控件懒加载
    
    /// 1. 相机预览视图（承载 PreviewLayer）
    private lazy var cameraPreviewView: UIView = {
        let view = UIView()
        view.backgroundColor = .black // 镜头未启动时显示黑色占位
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true // 必须开启用户交互
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tapGesture)
        return view
    }()
    
    /// 2. 快门拍照按钮（圆形、带边框）
    private lazy var shutterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35 // 70x70 尺寸的圆
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 绑定点击事件
        button.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
        return button
    }()
    
    /// 3. 前后摄像头切换按钮
    private lazy var flipCameraButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let icon = UIImage(systemName: "camera.rotate.fill", withConfiguration: config)
        button.setImage(icon, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.addTarget(self, action: #selector(didTapFlipCamera), for: .touchUpInside)
        return button
    }()
    
    /// 4. 聚焦框（平时隐藏，点击屏幕时在对焦点闪烁显示）
    private lazy var focusBoxView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.systemYellow.cgColor // 经典相机黄色对焦框
        view.backgroundColor = .clear
        view.alpha = 0 // 默认隐藏
        return view
    }()
    
    private lazy var videoModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("视频", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.addTarget(
            self,
            action: #selector(changeToVideoMode),
            for: .touchUpInside
        )
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
        // 确保预览图层的大小与 cameraPreviewView 的 Bounds 一致
        previewLayer?.frame = cameraPreviewView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开页面时停止相机，释放资源
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    // MARK: - UI 设置
    private func setupUI() {
        view.backgroundColor = .black
            
        // 1. 添加子视图
        view.addSubview(cameraPreviewView)
        view.addSubview(shutterButton)
        view.addSubview(flipCameraButton)
        view.addSubview(videoModeButton)
        view.addSubview(focusBoxView) // focusBoxView
            
        // 预览视图铺满整个屏幕
        cameraPreviewView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
        }
            
        // 快门按钮：水平居中，距离底部安全区 20pt，固定宽高 70x70
        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.size.equalTo(CGSize(width: 70, height: 70))
        }
            
        // 切换镜头按钮：与快门按钮垂直居中对齐，距离屏幕右侧 40pt
        flipCameraButton.snp.makeConstraints { make in
            make.centerY.equalTo(shutterButton)
            make.trailing.equalToSuperview().offset(-40)
        }
        
        // 模式切换按钮：与快门按钮垂直居中，距离屏幕左侧 40pt
        videoModeButton.snp.makeConstraints { make in
            make.centerY.equalTo(shutterButton)
            make.leading.equalToSuperview().offset(40)
        }
    }
    
    // MARK: - 相机配置
    private func setupCamera() {
        // 请求相机权限
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.configureSession()
                        }
                    }
                }
            default:
                    print("用户拒绝了相机权限，请在系统设置中开启")
        }
    }
    private func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            enterVideoMode()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.enterVideoMode()
                    }
                }
            }
        case .denied, .restricted:
            print("请到设置打开麦克风权限")
        @unknown default:
            break
        }
    }
    private func enterVideoMode() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            // 1. 切换为适合录像的视频预设
            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
            }
            // 2. 动态添加麦克风（若未添加）
            if self.audioInput == nil {
                self.addAudioInput()
            }
            // 3. 动态添加录像输出（若未添加）
            if !self.captureSession.outputs.contains(self.movieOutput) {
                self.addMovieOutput()
            }
            self.captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.currentMode = .video
                self.videoModeButton.setTitle("拍照模式", for: .normal)
                self.shutterButton.backgroundColor = .systemRed // 录像模式把快门改成红色
                print("进入录像模式")
            }
        }
    }
    private func enterPhotoMode() {
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.captureSession.beginConfiguration()
                // 回到照片模式
                if self.captureSession.canSetSessionPreset(.photo) {
                    self.captureSession.sessionPreset = .photo
                            }
                // 移除音频输入
                if let audio = self.audioInput {
                    self.captureSession.removeInput(audio)
                    self.audioInput = nil
                }
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    self.currentMode = .photo
                    self.videoModeButton.setTitle("视频", for: .normal)
                    self.shutterButton.backgroundColor = .white // 变回白色
                    print("进入拍照模式 ,已释放麦克风")
                }
            }
        }
    private func addAudioInput() {
        guard let microphone = AVCaptureDevice.default(for: .audio)
        else { return }
        do {
            let input = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                self.audioInput = input
            }
        } catch {
            print(error)
        }
        
    }
    private func addMovieOutput() {
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
    }
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            // 1. 获取默认后置摄像头
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("未找到后置摄像头")
                self.captureSession.commitConfiguration()
                return
            }
            
            // 2. 添加摄像头输入
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.activeInput = input
                }
            } catch {
                print("无法创建相机输入: \(error)")
            }
            
            // 3. 添加摄像头输出
            if self.captureSession.canAddOutput(photoOutput) {
                self.captureSession.addOutput(photoOutput)
            }
            
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
            let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                preview.videoGravity = .resizeAspectFill
                // 确保加在最底层，不要挡住你的 focusBoxView 聚焦框
                self.cameraPreviewView.layer.insertSublayer(preview, at: 0)
                self.previewLayer = preview
                // 布局生效，立刻刷新画面尺寸
                //preview.frame = self.cameraPreviewView.bounds
                // 6. 图层绑定好后，在后台线程启动流媒体采集
                self.sessionQueue.async {
                    self.captureSession.startRunning()
                }
            }
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
    private func capturePhoto(){
        // 1. 触发系统震动反馈（Taptic Engine，很有质感）
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
            
        // 2. 执行拍照
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    private func toggleRecording() {
            if !isRecording {
                // 开始录视频
                isRecording = true
                UIView.animate(withDuration: 0.2) {
                    self.shutterButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    self.shutterButton.layer.cornerRadius = 10
                }
                
                let formatter = DateFormatter()
                            formatter.dateFormat = "yyyyMMdd_HHmmss" // 格式：年年月月日日_时时分秒秒，如 20260717_153022
                            let dateString = formatter.string(from: Date())
                            
                            // 2. 拼接带有时间戳的唯一文件名
                            let fileName = "video_\(dateString).mov"
                            
                            let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                            let outputURL = tempDirectory.appendingPathComponent(fileName)
                            
                            // 3. 安全删除（理论上由于时间戳存在，几乎不可能重复，但保留此安全机制）
                            if FileManager.default.fileExists(atPath: outputURL.path) {
                                try? FileManager.default.removeItem(at: outputURL)
                            }
                
                print("🎥 开始录制视频，输出目标路径: \(outputURL.absoluteString)")
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                
            } else {
                // 停止录视频
                isRecording = false
                UIView.animate(withDuration: 0.2) {
                    self.shutterButton.transform = .identity
                    self.shutterButton.layer.cornerRadius = 35
                }
                print("🛑 停止录制，正在等待写入完成...")
                movieOutput.stopRecording()
            }
        }
    
    @objc private func changeToVideoMode() {
        if isRecording {
            print("⚠️ 正在录像中，请先停止录像再切换模式！")
            // 可选：给用户一个震动警告反馈
            let warningFeedback = UINotificationFeedbackGenerator()
            warningFeedback.notificationOccurred(.warning)
            return
        }
        if currentMode == .photo {
            requestMicrophonePermission()
            } else {
                enterPhotoMode()
            }
    }

    @objc private func didTapFlipCamera() {
        if isRecording {
            print("⚠️ 正在录像中，无法切换前后摄像头！")
            let warningFeedback = UINotificationFeedbackGenerator()
            warningFeedback.notificationOccurred(.warning)
            return
        }
        print("切换前后摄像头")
        // 获取当前摄像头的反向位置
        guard let currentInput = activeInput else { return }
        let currentPosition = currentInput.device.position
        let preferredPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
        
        // 切换镜头需要重新配置会话
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            // 移除旧输入
            self.captureSession.removeInput(currentInput)
            // 寻找新设备
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.activeInput = newInput
                } else {
                    // 如果换新镜头失败，塞回原镜头
                    self.captureSession.addInput(currentInput)
                }
            }
            self.captureSession.commitConfiguration()
        }
    }
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        // 1. 获取点击在预览视图上的具体坐标
        let touchPoint = gesture.location(in: cameraPreviewView)
        print("点击屏幕对焦位置: \(touchPoint)")
        // 2. 将聚焦框的中心点直接移动到点击位置
        focusBoxView.center = touchPoint
        // 3. 终止之前未完成的动画，防止连续快速点击时动画冲突
        focusBoxView.layer.removeAllAnimations()
        // 4. 初始化聚焦框的状态：放大 1.5 倍，透明度为 0
        focusBoxView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusBoxView.alpha = 0
        // 5. 播放对焦框动画
        // 动画 A：瞬间淡入并缩小至 1.0 倍（模拟相机的卡嚓对焦感）
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
                self.focusBoxView.alpha = 1.0
                self.focusBoxView.transform = .identity // 恢复到 1.0 正常大小
            }){ _ in
                // 动画 B：对焦成功后，停留 0.8 秒，然后慢慢淡出隐藏
                UIView.animate(withDuration: 0.3, delay: 0.8, options: .curveEaseOut, animations: {
                    self.focusBoxView.alpha = 0
                }, completion: nil)
            }
            
        // (可选) 触发一个微弱的对焦触觉反馈
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension HomeViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("拍照出错: \(error.localizedDescription)")
            return
        }
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        print("📸 拍照成功，拿到 UIImage 尺寸: \(image.size)")
        // 将照片保存到系统相册
        saveImageToPhotosAlbum(image: image)
    }
    
    // 保存相册的辅助方法
    private func saveImageToPhotosAlbum(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                print("未获得相册写入权限")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                // 创建一个相册占位请求
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("🎉 成功保存到系统相册！去手机照片App里看看吧！")
                        // 这里可以加一个“保存成功”的提示 UI
                    } else if let error = error {
                        print("保存相册失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

extension HomeViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("视频录制出错: \(error.localizedDescription)")
            return
        }
        print("📹 视频录制成功，准备保存到相册，临时路径: \(outputFileURL)")
        // 请求权限并将视频写入系统相册
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("未获得相册写入权限，无法保存视频")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("🎉 视频已成功保存到相册！")
                        try? FileManager.default.removeItem(at: outputFileURL)
                        print("🧹 临时文件已从沙盒中安全清除")
                    } else if let error = error {
                        print("视频保存相册失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI
#Preview {
    HomeViewController(previewMode: true)
}
#endif
