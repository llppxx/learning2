//
//  CameraFocus.swift
//  learning2
//
//  Created by Lipeixuan on 2026/7/17.
//

import UIKit
import AVFoundation

/// 对焦功能管理
final class CameraFocus {

    // MARK: - 对焦点动画
    static func animateFocusBox(at point: CGPoint, in view: UIView, focusBox: UIView) {
        // 将聚焦框的中心点移动到点击位置
        focusBox.center = point

        // 终止之前未完成的动画，防止连续快速点击时动画冲突
        focusBox.layer.removeAllAnimations()

        // 初始化聚焦框的状态：放大 1.5 倍，透明度为 0
        focusBox.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusBox.alpha = 0

        // 动画 A：瞬间淡入并缩小至 1.0 倍（模拟相机的卡嚓对焦感）
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            focusBox.alpha = 1.0
            focusBox.transform = .identity // 恢复到 1.0 正常大小
        }) { _ in
            // 动画 B：对焦成功后，停留 0.8 秒，然后慢慢淡出隐藏
            UIView.animate(withDuration: 0.3, delay: 0.8, options: .curveEaseOut, animations: {
                focusBox.alpha = 0
            }, completion: nil)
        }
    }

    // MARK: - 执行对焦
    static func focus(at point: CGPoint, in device: AVCaptureDevice, completion: (() -> Void)? = nil) {
        do {
            try device.lockForConfiguration()

            // 判断设备是否支持对焦
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            // 判断设备是否支持曝光
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
            completion?()
        } catch {
            print("对焦失败: \(error)")
        }
    }

    // MARK: - 点击坐标转换为摄像头坐标
    static func convertToCameraCoordinate(point: CGPoint, in view: UIView) -> CGPoint {
        CGPoint(
            x: point.y / view.bounds.height,
            y: 1.0 - point.x / view.bounds.width
        )
    }
}
