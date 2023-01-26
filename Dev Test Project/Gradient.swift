//
//  Gradient.swift
//  Dev Test Project
//
//  Created by Kristina on 27.01.2023.
//

import Foundation
import UIKit

public enum GradientDirection {
    case horizontal
    case vertical
    case diagonal
}

public class Gradient: UIView {
    override public class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    var gradientLayer: CAGradientLayer? {
        return layer as? CAGradientLayer
    }

    var colorsInternal: [UIColor] = [.clear, .clear]
    var directionInternal: GradientDirection = .vertical

    var colors: [UIColor] {
        get {
            return colorsInternal
        }

        set(newColors) {
            guard colorsInternal != newColors else {
                return
            }
            colorsInternal = newColors
            updateLayer()
        }
    }

    var direction: GradientDirection {
        get {
            return directionInternal
        }

        set(newDirection) {
            guard directionInternal != newDirection else {
                return
            }
            directionInternal = newDirection
            updateLayer()
        }
    }

    func updateLayer() {
        guard let layer = gradientLayer else {
            return
        }

        layer.colors = colors.map { $0.cgColor }

        switch direction {
        case .horizontal:
            layer.startPoint = .zero
            layer.endPoint = CGPoint(x: 1, y: 0)
        case .vertical:
            layer.startPoint = .zero
            layer.endPoint = CGPoint(x: 0, y: 1)
        case .diagonal:
            layer.startPoint = CGPoint(x: 0, y: 1)
            layer.endPoint = CGPoint(x: 1, y: 0)
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
