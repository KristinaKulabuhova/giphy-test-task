//
//  VideoPlayerView.swift
//  Dev Test Project
//
//  Created by Kristina on 27.01.2023.
//

import AVFoundation
import Foundation
import UIKit

public class VideoPlayerView: UIView, VideoPlayerStateListener {
    private var cache: URLCache = {
        let cache = URLCache()
        cache.diskCapacity = 1000 * 1000 * 1000
        cache.memoryCapacity = 1000 * 1000 * 1000
        return cache
    }()

    let lock = NSRecursiveLock()

    public private(set) var media: Media?

    public var maxLoopsBeforeMute = 3
    var loopCount = 0

    weak var assetRequest: URLSessionDataTask?

    // MARK: -

    // MARK: Player

    override public static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    var playerLayer: AVPlayerLayer {
        // swiftlint: disable force_cast
        layer as! AVPlayerLayer
    }

    weak var videoPlayer: VideoPlayer?

    // MARK: -

    // MARK: Init

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        imageView.topAnchor.constraint(lessThanOrEqualTo: topAnchor).isActive = true
        imageView.bottomAnchor.constraint(greaterThanOrEqualTo: bottomAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        shimmerView.isUserInteractionEnabled = false
        addSubview(shimmerView)
        shimmerView.topAnchor.constraint(lessThanOrEqualTo: topAnchor).isActive = true
        shimmerView.bottomAnchor.constraint(greaterThanOrEqualTo: bottomAnchor).isActive = true
        shimmerView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        shimmerView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        shimmerView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        shimmerView.backgroundColor = .randomColor

        addSubview(soundButton)
        soundButton.isUserInteractionEnabled = false
        soundButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        soundButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        soundButton.topAnchor.constraint(equalTo: shimmerView.topAnchor).isActive = true
        soundButton.rightAnchor.constraint(equalTo: shimmerView.rightAnchor).isActive = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)

        addSubview(captionButton)
        captionButton.isUserInteractionEnabled = true
        let padding: CGFloat = 5.0
        captionButton.bottomAnchor.constraint(equalTo: shimmerView.bottomAnchor, constant: -padding).isActive = true
        captionButton.centerXAnchor.constraint(equalTo: soundButton.centerXAnchor).isActive = true
        captionButton.addTarget(self, action: #selector(toggleCaptions), for: .touchUpInside)
        captionButton.isOn = CaptionState.enabled

        soundButton.alpha = 0
        captionButton.alpha = 0
    }

    // MARK: -

    // MARK: Views

    let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let soundButton: ToggleButton = {
        let button = ToggleButton()
        button.type = .sound
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let captionButton: ToggleButton = {
        let button = ToggleButton()
        button.type = .caption
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let shimmerView: ShimmerLoadingView = {
        let view = ShimmerLoadingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.animate()
        return view
    }()

    // MARK: -

    // MARK: Actions

    @objc func didTap() {
        guard let media = media else {
            return
        }
        guard
            media === videoPlayer?.media,
            let player = player
        else {
            videoPlayer?.loadMedia(media: media, view: self)
            return
        }
        showControls()
        soundButton.isOn = !soundButton.isOn
        player.isMuted = !soundButton.isOn

        if player.timeControlStatus == .paused {
            player.isMuted = false
            soundButton.isOn = true
            player.play()
        }
    }

    func automute() {
        player?.isMuted = true
    }

    @objc func hideControls() {
        let keepSoundButtonShown = player?.isMuted ?? false
        UIView.animate(withDuration: GPHVideoPlayerViewConstants.hideControlsDuration,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: { [weak self] in

                           self?.soundButton.alpha = keepSoundButtonShown ? 1 : 0
                           self?.captionButton.alpha = 0
                       }, completion: nil)
    }

    func showControls(delayToHide: TimeInterval = 2.5) {
        UIView.animate(withDuration: 0.1,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: { [weak self] in
                           self?.soundButton.alpha = 1
                           if self?.captionsAvailable() ?? false {
                               self?.captionButton.alpha = 1
                           }
                       }, completion: nil)

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideControls), object: nil)
        perform(#selector(hideControls), with: nil, afterDelay: delayToHide)
    }

    func resetControlsState() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideControls), object: nil)
        captionButton.alpha = 0
        soundButton.isOn = false
        soundButton.alpha = 1
    }

    public func preloadFirstFrame(media: Media, videoPlayer: VideoPlayer) {
        lock.lock()
        defer { lock.unlock() }

        self.media = media
        self.videoPlayer = videoPlayer
        imageView.isHidden = false
        playerLayer.player = nil

        guard let url = media.imagePreviewUrl.flatMap({ URL(string: $0) }) else { return }
        let request = URLRequest(url: url)

        assetRequest?.cancel()
        assetRequest = nil

        let completion: (UIImage?) -> Void = { [weak self] image in
            guard let self = self else { return }

            self.imageView.image = image
            self.soundButton.alpha = 1
            self.assetRequest = nil
            self.setNeedsUpdateConstraints()
            self.setNeedsLayout()
        }

        if let data = cache.cachedResponse(for: request)?.data {
            completion(UIImage(data: data))
        } else {
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in

                guard let data = data, let response = response else {
                    // handle error processing here
                    return
                }
                let cachedData = CachedURLResponse(response: response, data: data)
                self?.cache.storeCachedResponse(cachedData, for: request)
                DispatchQueue.main.async {
                    completion(UIImage(data: data))
                }
            }
            assetRequest = task
            task.resume()
        }
    }

    public func prepare(media: Media, videoPlayer: VideoPlayer) {
        lock.lock()
        defer { lock.unlock() }

        videoPlayer.add(listener: self)

        playerLayer.player = nil

        shimmerView.isHidden = false
        shimmerView.shimmer(true,
                            isSticker: false,
                            backgroundColor: UIColor.randomColor)
        setNeedsUpdateConstraints()
        setNeedsLayout()

        self.media = media
        self.videoPlayer = videoPlayer
    }
}

enum ToggleButtonType {
    case sound
    case caption

    var imageForOnState: UIImage? {
        switch self {
        case .sound:
            return UIImage(systemName: "speaker.wave.3")?.withRenderingMode(.alwaysTemplate)
        case .caption:
            return UIImage(systemName: "captions.bubble.fill")?.withRenderingMode(.alwaysTemplate)
        }
    }

    var imageForOffState: UIImage? {
        switch self {
        case .sound:
            return UIImage(systemName: "speaker.slash")?.withRenderingMode(.alwaysTemplate)
        case .caption:
            return UIImage(systemName: "captions.bubble")?.withRenderingMode(.alwaysTemplate)
        }
    }
}

extension VideoPlayerView {
    @objc func toggleCaptions() {
        captionButton.isOn = !captionButton.isOn
        showControls()
        let isOn = captionButton.isOn
        if isOn {
            enableCaptions()
        } else {
            disableCaptions()
        }
        CaptionState.setEnabled(isOn)
    }

    func captionsAvailable() -> Bool {
        guard let player = player else { return false }
        guard let item = player.currentItem else { return false }
        let locale = Locale.current
        guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return false }
        let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        return !options.isEmpty
    }

    func setOptionsForMediaCharacteristic(_ characteristic: AVMediaCharacteristic) {
        guard let player = player as? AVQueuePlayer else { return }
        for item in player.items() {
            player.appliesMediaSelectionCriteriaAutomatically = false
            let locale = Locale.current
            guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { return }
            let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
            if let option = options.first { item.select(option, in: group) }
        }
    }

    func enableCaptions() {
        setOptionsForMediaCharacteristic(.legible)
    }

    func disableCaptions() {
        guard let player = player as? AVQueuePlayer else { return }
        for item in player.items() {
            guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
            item.select(nil, in: group)
        }
    }
}
