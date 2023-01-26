//
//  PreviewViewController.swift
//  Dev Test Project
//
//  Created by Kristina on 26.01.2023.
//

import Foundation
import GiphyUISDK
import MessageUI
import Photos

class PreviewViewController: UIViewController, MFMessageComposeViewControllerDelegate {
    let colorGIFLink = UIColor(red: 63.0 / 255.0, green: 92.0 / 255.0, blue: 250.0 / 255.0, alpha: 1)
    let colorCopyGIF =  UIColor(red: 23.0 / 255.0, green: 21.0 / 255.0, blue: 25.0 / 255.0, alpha: 1)
    let iconImages = ["message", "facebookM", "snapchat", "whatsapp", "instagram", "facebook", "twitter"]

    var media: GiphyUISDK.GPHMedia!
    var videoPlayer = GPHVideoPlayer()
    var imageView = GPHMediaView()
    var videoView = GPHVideoPlayerView()
    var clipsPlaybackSetting: ClipsPlaybackSetting = .inline
    var playClipOnLoad: Bool = true
    var isReply: Bool = false
    var shareButton: UIButton = getTopActionButton(image: UIImage(named: "share"))
    var cancelButton: UIButton = getTopActionButton(image: UIImage(named: "cancel"))

    lazy var shareSelector: UIStackView = {
        var stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        for icon in iconImages {
            var btn = createActionButton(color: .clear,
                                         title: "",
                                         action: #selector(sharingIntent),
                                         image: UIImage(named: icon))
            btn.heightAnchor.constraint(equalTo: btn.widthAnchor, multiplier: 1.0).isActive = true
            stack.addArrangedSubview(btn)
        }
        return stack
    }()

    lazy var stackAction: UIStackView = {
        var stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(shareSelector)
        stack.addArrangedSubview(
            createActionButton(
                color: colorGIFLink,
                title: "Copy GIF Link",
                action: #selector(copeURLBuffer),
                image: nil
            )
        )
        stack.addArrangedSubview(
            createActionButton(color: colorCopyGIF,
                               title: "Copy GIF",
                               action: #selector(copeGIFBuffer),
                               image: nil))
        stack.addArrangedSubview(
            createActionButton(
                color: .black,
                title: "Cancel",
                action: #selector(cancelTouched),
                image: nil
            )
        )
        return stack
    }()

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    init?(media: GiphyUISDK.GPHMedia) {
        self.init()
        self.media = media
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(stackAction)
        view.addSubview(cancelButton)
        view.addSubview(shareButton)

        cancelButton.addTarget(self, action: #selector(cancelTouched), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(saveContent), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stackAction.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stackAction.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackAction.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackAction.heightAnchor.constraint(lessThanOrEqualToConstant: 200),

            cancelButton.leadingAnchor.constraint(equalTo: stackAction.leadingAnchor),
            cancelButton.topAnchor.constraint(equalTo: view.safeTopAnchor),
            cancelButton.widthAnchor.constraint(equalTo: cancelButton.heightAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 20),

            shareButton.trailingAnchor.constraint(equalTo: stackAction.trailingAnchor),
            shareButton.topAnchor.constraint(equalTo: view.safeTopAnchor),
            shareButton.widthAnchor.constraint(equalTo: shareButton.heightAnchor, constant: -5),
            shareButton.widthAnchor.constraint(equalTo: cancelButton.widthAnchor)
        ])
        addMedia()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addMedia() {
        if media.type == .video && clipsPlaybackSetting == .inline {
            view.addSubview(videoView)
            videoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                videoView.widthAnchor.constraint(equalTo: stackAction.widthAnchor, constant: 6),
                videoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                videoView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
                videoView.widthAnchor.constraint(equalTo: videoView.heightAnchor, multiplier: media.aspectRatio),
                videoView.topAnchor.constraint(greaterThanOrEqualTo: view.safeTopAnchor, constant: 35)
            ])
            videoView.contentMode = .scaleAspectFit
            videoView.layer.cornerRadius = 6
            videoView.layer.masksToBounds = true
            videoView.backgroundColor = .clear

            videoPlayer.pause()
            if playClipOnLoad {
                videoPlayer.loadMedia(media: media, muteOnPlay: true, view: videoView)
            } else {
                videoPlayer.prepareMedia(media: media,
                                         view: videoView)
            }
        } else {
            view.addSubview(imageView)
            imageView.media = media
            imageView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalTo: stackAction.widthAnchor, constant: 6),
                imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
                imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: media.aspectRatio),
                imageView.topAnchor.constraint(greaterThanOrEqualTo: view.safeTopAnchor, constant: 35)
            ])

            imageView.contentMode = .scaleAspectFit
            imageView.layer.cornerRadius = 6
            imageView.layer.masksToBounds = true
        }
    }

    private func createActionButton(color: UIColor, title: String, action: Selector?, image: UIImage?) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white

        if let image = image {
            config.background.image = image
        }
        let button = UIButton(configuration: config)
        guard let action = action else { return button }
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc func cancelTouched() {
        dismiss(animated: true)
    }

    @objc func sharingIntent(_: UIButton) {
        print("Direct sharing is NYI.")
    }

    @objc func copeURLBuffer() {
        UIPasteboard.general.string = media.url
    }

    @objc func copeGIFBuffer() {
        if media.type == .video && clipsPlaybackSetting == .inline {
            UIPasteboard.general.url = URL(string: (videoView.media?.url)!)
        } else {
            UIPasteboard.general.image = imageView.image
        }
    }

    @objc func saveContent() {
        var activityItems : [Any]
        if media.type == .video && clipsPlaybackSetting == .inline {
            activityItems = [URL(string: media.url)]
        } else {
            guard let image = imageView.image else { return }
            activityItems = [image]
        }
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = view
        present(activityViewController, animated: true, completion: nil)

    }

    static func getTopActionButton(image: UIImage?) -> UIButton {
        let button = UIButton()
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(image?.withTintColor(.white, renderingMode: .alwaysTemplate), for: .normal)
        button.contentMode = .scaleAspectFit
        button.tintColor = .white
        return button
    }

    func messageComposeViewController(_: MFMessageComposeViewController, didFinishWith _: MessageComposeResult) {}
}

enum ClipsPlaybackSetting: Int {
    case inline
    case popup

    static var defaultSetting: ClipsPlaybackSetting {
        return inline
    }
}
