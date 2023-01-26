//
//  View.swift
//  Dev Test Project
//
//  Created by Kristina on 27.01.2023.
//

import Foundation
import UIKit

class ShimmerLoadingView: UIView {
    static let slideDuration: TimeInterval = 4.25
    static let baselineImageDimensionForTiming: CGFloat = 200
    static let defaultShimmerAlpha: CGFloat = 0.18
    static let stickerShimmerAlpha: CGFloat = 0.08

    lazy var gradientView1: Gradient = {
        let view = Gradient()
        view.translatesAutoresizingMaskIntoConstraints = true
        view.direction = .horizontal
        return view
    }()

    lazy var gradientView2: Gradient = {
        let view = Gradient()
        view.translatesAutoresizingMaskIntoConstraints = true
        view.direction = .horizontal
        return view
    }()

    var scaledSlideDuration: TimeInterval {
        let dimension = frame.size.width
        guard dimension > 0 else { return ShimmerLoadingView.slideDuration }
        return TimeInterval(CGFloat(ShimmerLoadingView.slideDuration) /
            (dimension / ShimmerLoadingView.baselineImageDimensionForTiming))
    }

    private var isAnimating: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func shimmerAlpha(isSticker: Bool, backgroundColor: UIColor) -> CGFloat {
        guard !isSticker else { return ShimmerLoadingView.stickerShimmerAlpha }
        let hexString = backgroundColor.toHexString()
        switch hexString {
        case "00E6CC": // teal
            return 0.30
        case "E646B6": // pink
            return 0.25
        case "00CCFF": // light blue
            return 0.28
        case "6157FF": // darker blue
            return 0.14
        case "9933FF": // purple
            return 0.16
        default:
            return ShimmerLoadingView.defaultShimmerAlpha
        }
    }

    func shimmer(_ shimmer: Bool, isSticker: Bool, backgroundColor: UIColor) {
        guard superview != nil else { return }
        isHidden = !shimmer
        if shimmer {
            addGradientViews()

            let useAlpha = shimmerAlpha(isSticker: isSticker, backgroundColor: backgroundColor)

            gradientView1.colors = [UIColor(white: 1.0, alpha: 0.0),
                                    UIColor(white: 1.0, alpha: useAlpha),
                                    UIColor(white: 1.0, alpha: 0.0)]

            gradientView2.colors = [UIColor(white: 1.0, alpha: 0.0),
                                    UIColor(white: 1.0, alpha: useAlpha),
                                    UIColor(white: 1.0, alpha: 0.0)]
        }

        layer.removeAllAnimations()
        if shimmer {
            animate()
        } else {
            isAnimating = false
        }
    }

    func addGradientViews() {
        guard gradientView1.superview == nil, gradientView2.superview == nil else { return }

        addSubview(gradientView1)
        addSubview(gradientView2)

        let cover = bounds
        gradientView1.frame = cover
        gradientView2.frame = cover.offsetBy(dx: cover.size.width, dy: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        DispatchQueue.main.async {
            self.resetAnimation()
        }
    }

    @objc public func resetAnimation() {
        layer.removeAllAnimations()
        if isAnimating {
            animate()
        }
    }

    func animate() {
        transform = .identity
        let cover = bounds
        gradientView1.frame = cover
        gradientView2.frame = cover.offsetBy(dx: cover.size.width, dy: 0)
        let boundingSizeAfterRotation = (bounds.size.width + bounds.size.height) / sqrt(2)
        transform = CGAffineTransform(
            scaleX: boundingSizeAfterRotation / bounds.size.width,
            y: boundingSizeAfterRotation / bounds.size.height
        ).concatenating(CGAffineTransform(rotationAngle: 3 * (.pi / 4)))

        isAnimating = true

        let curveLinear = UIView.KeyframeAnimationOptions(rawValue: UIView.AnimationOptions.curveLinear.rawValue)
        UIView.animateKeyframes(
            withDuration: scaledSlideDuration,
            delay: 0.0,
            options: [.repeat, curveLinear],
            animations: { [weak self] in
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.gradientView1.frame = cover.offsetBy(dx: -1 * cover.size.width, dy: 0)
                    self.gradientView2.frame = cover
                }

                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.0) { [weak self] in
                    guard let self = self else { return }
                    self.gradientView1.frame = cover.offsetBy(dx: cover.size.width, dy: 0)
                }

                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.gradientView1.frame = cover
                    self.gradientView2.frame = cover.offsetBy(dx: -1 * cover.size.width, dy: 0)
                }
            }, completion: nil
        )
    }
}
