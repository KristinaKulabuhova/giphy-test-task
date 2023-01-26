//
//  ViewController.swift
//  Dev Test Project
//
//  Created by Kristina on 26.01.2023.
//

import GiphyUISDK
import UIKit

enum CategoriesTag: Int {
    case trending = 1
    case artists = 2
    case clips = 3
    case stories = 4
    case stickers = 5
}

class MainViewController: UIViewController, UITabBarControllerDelegate {
    var tabBarVC = CustomTabBarController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(tabBarVC.view)
        present(tabBarVC, animated: true)
    }
}

class CustomScrollView: UIScrollView {
    override func touchesShouldCancel(in _: UIView) -> Bool {
        return true
    }
}

class HomeViewController: UIViewController, GPHGridDelegate, UIScrollViewDelegate {
    let key = "m9XwLBfAIiurmD43h8KDyuKHx7LuXXmg"
    let gridController = GiphyGridController()
    let categories = ["Trending", "Artists", "Clips", "Stories", "Stickers"]

    var selectedCategory: UIButton!
    weak var categoryStack: UIStackView?

    lazy var customTopView: UIScrollView = {
        var scrollWrapper = CustomScrollView()
        scrollWrapper.delegate = self
        var stack = UIStackView()
        stack.axis = .horizontal

        for (idx, category) in categories.enumerated() {
            let btn = addCategoryButton(title: category, tag: idx + 1)
            if category == "Trending" {
                btn.isSelected = true
                self.selectedCategory = btn
            }
            stack.addArrangedSubview(btn)
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 8.0
        stack.isUserInteractionEnabled = true
        self.categoryStack = stack
        scrollWrapper.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollWrapper.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollWrapper.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollWrapper.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollWrapper.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollWrapper.heightAnchor, constant: -6)
        ])
        scrollWrapper.bounces = false
        scrollWrapper.showsHorizontalScrollIndicator = false
        scrollWrapper.canCancelContentTouches = true
        return scrollWrapper
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        Giphy.configure(apiKey: key)

        view.addSubview(customTopView)
        customTopView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customTopView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customTopView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            customTopView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            customTopView.heightAnchor.constraint(equalToConstant: 50)
        ])

        gridController.cellPadding = 4.0
        gridController.direction = .vertical
        gridController.numberOfTracks = 2

        gridController.view.backgroundColor = .black
        gridController.fixedSizeCells = true
        addChild(gridController)
        view.addSubview(gridController.view)

        gridController.view.translatesAutoresizingMaskIntoConstraints = false
        gridController.view.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        gridController.view.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        gridController.view.topAnchor.constraint(equalTo: customTopView.bottomAnchor, constant: 6).isActive = true
        gridController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        gridController.didMove(toParent: self)
        gridController.update()
        gridController.delegate = self
    }

    func didSelectMedia(media: GiphyUISDK.GPHMedia, cell _: UICollectionViewCell) {
        guard let preview = PreviewViewController(media: media) else { return }
        preview.modalPresentationStyle = .fullScreen
        preview.modalTransitionStyle = .crossDissolve
        show(preview, sender: self)
    }

    func addCategoryButton(title: String, tag: Int) -> CategoryButton {
        let button = CategoryButton(configuration: UIButton.Configuration.category())
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isSelected = false
        button.tag = tag
        button.isUserInteractionEnabled = true
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        return button
    }

    @objc func buttonTapped(_ sender: UIButton) {
        selectedCategory.isSelected = false
        selectedCategory = sender
        sender.isSelected = true
        let contentSets = [
            CategoriesTag.trending: GPHContent.trendingGifs,
            CategoriesTag.artists: GPHContent.trendingGifs,
            CategoriesTag.clips: GPHContent.trendingVideo,
            CategoriesTag.stories: GPHContent.trendingText,
            CategoriesTag.stickers: GPHContent.trendingStickers
        ]
        gridController.content = contentSets[CategoriesTag(rawValue: sender.tag) ?? CategoriesTag.trending] ?? GPHContent.trendingGifs
        gridController.update()
    }

    func contentDidUpdate(resultCount _: Int, error _: Error?) {}

    func didSelectMoreByYou(query _: String) {}

    func didScroll(offset _: CGFloat) {}
}

extension UIImage {
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let newSize = widthRatio > heightRatio ?
            CGSize(width: size.width * heightRatio, height: size.height * heightRatio) :
            CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}

public extension UIButton.Configuration {
    static func category() -> UIButton.Configuration {
        var style = UIButton.Configuration.plain()
        var background = UIButton.Configuration.plain().background
        background.cornerRadius = 20
        background.strokeWidth = 0
        background.strokeColor = UIColor.clear
        background.backgroundColor = .purple
        style.background = background

        return style
    }
}

class CategoryButton: UIButton {
    override func updateConfiguration() {
        guard let configuration = configuration else {
            return
        }

        var updatedConfiguration = configuration
        var background = UIButton.Configuration.plain().background
        let foregroundColor: UIColor

        background.cornerRadius = 20
        background.strokeWidth = 0

        let backgroundColor: UIColor
        let baseBackColor = UIColor(red: 107.0 / 255.0, green: 89.0 / 255.0, blue: 250.0 / 255.0, alpha: 1)
        let baseColor = UIColor.white

        switch state {
        case .normal:
            backgroundColor = .clear
            foregroundColor = baseColor
        case [.highlighted]:
            backgroundColor = baseBackColor
            foregroundColor = baseColor
        case .selected:
            backgroundColor = baseBackColor
            foregroundColor = baseColor
        case .disabled:
            backgroundColor = .red
            foregroundColor = baseColor
        default:
            backgroundColor = .clear
            foregroundColor = baseColor
        }

        background.backgroundColor = backgroundColor
        updatedConfiguration.baseForegroundColor = foregroundColor
        updatedConfiguration.background = background

        self.configuration = updatedConfiguration
    }
}

class SearchViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemPink
    }
}

class PersonViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .yellow
    }
}
