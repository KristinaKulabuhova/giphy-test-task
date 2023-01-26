//
//  CustomTapBar.swift
//  Dev Test Project
//
//  Created by Kristina on 26.01.2023.
//

import Foundation
import GiphyUISDK
import UIKit

class CustomTabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setGradientBackground()
        generateTabBar()
    }

    private func generateTabBar() {
        viewControllers = [
            generateVC(viewController: HomeViewController(),
                       image: "home",
                       selectedImage: "select_home"),
            generateVC(viewController: SearchViewController(),
                       image: "search",
                       selectedImage: "select_search"),
            generateVC(viewController: PersonViewController(),
                       image: "person",
                       selectedImage: "select_person")
        ]
        modalPresentationStyle = .fullScreen
    }

    private func generateVC(viewController: UIViewController,
                            image: String,
                            selectedImage: String) -> UIViewController {
        let imageSize = CGSize(width: 25, height: 47.41)
        
        let image = UIImage(named: image)?.withRenderingMode(.alwaysOriginal)
            .resizeImage(targetSize: imageSize).withRenderingMode(.alwaysOriginal)
        let selectedImage = UIImage(named: selectedImage)?.withRenderingMode(.alwaysOriginal)
            .resizeImage(targetSize: imageSize).withRenderingMode(.alwaysOriginal)
        let tabIcon = UITabBarItem(title: "",
                                      image: image,
                                      selectedImage: selectedImage)
        viewController.tabBarItem = tabIcon
        return viewController
    }

    private func setGradientBackground() {
        tabBar.backgroundImage = UIImage()
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.black.withAlphaComponent(0).cgColor,
                                UIColor.black.withAlphaComponent(0.9).cgColor,
                                UIColor.black.cgColor]
        gradientLayer.locations = [0, 0.45, 1]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.25)
        gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.type = .axial
        gradientLayer.frame = CGRect(x: 0, y: -200, width: tabBar.frame.width, height: 300)
        tabBar.layer.insertSublayer(gradientLayer, at: 0)
    }
}
