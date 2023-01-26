//
//  VideoPlayer.swift
//  Dev Test Project
//
//  Created by Kristina on 27.01.2023.
//

import AVFoundation
import Foundation
import UIKit

@objc public class Media: NSObject {
    public fileprivate(set) var videoUrl: String
    public fileprivate(set) var imagePreviewUrl: String?
    public fileprivate(set) var aspectRatio: CGFloat

    public init(videoUrl: String, imagePreviewUrl: String?, aspectRatio: CGFloat) {
        self.videoUrl = videoUrl
        self.imagePreviewUrl = imagePreviewUrl
        self.aspectRatio = aspectRatio
        super.init()
    }
}

@objc public enum VideoPlayerState: Int {
    case unknown
    case readyToPlay
    case playing
    case paused
    case repeated
    case idle
}

@objc public protocol VideoPlayerStateListener: AnyObject {
    @objc optional func playerStateDidChange(_ state: VideoPlayerState)
    @objc optional func playerDidFail(_ description: String?)
    @objc optional func muteDidChange(isMuted: Bool)
    @objc optional func mediaDidChange(media: Media?)
}


public class CaptionState: NSObject {
    static let key = "kGPHClipsCaptionState"

    public static var enabled: Bool {
        guard let state = UserDefaults.standard.object(forKey: CaptionState.key) as? Bool else {
            return false
        }
        return state
    }

    class func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.setValue(enabled, forKey: CaptionState.key)
        UserDefaults.standard.synchronize()
    }
}

public class VideoPlayer: NSObject {
    private var listeners = [VideoPlayerStateListener]()

    private var videoPlayerLooper: AVPlayerLooper?
    private(set) var videoPlayer: AVQueuePlayer?

    private(set) var media: Media?

    public weak var playerView: VideoPlayerView?

    let lock = NSRecursiveLock()

    var firstStart = false

    var playerMuteContext = 0
    var playerStatusContext = 0
    var playerItemStatusContext = 0
    var playerItemContext = 0

    var repeatable: Bool = true

    // MARK: -

    // MARK: Init

    override public init() {
        super.init()
    }

    // MARK: -

    // MARK: Actions

    func notifyListeners(action: (VideoPlayerStateListener) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        listeners.forEach {
            action($0)
        }
    }

    deinit {
        stop()
    }
}

// MARK: -

// MARK: Public APIs

public extension VideoPlayer {
    func add(listener: VideoPlayerStateListener) {
        lock.lock()
        defer { lock.unlock() }

        if listeners.firstIndex(where: { $0 === listener }) == nil {
            listeners.append(listener)
        }
    }

    func remove(listener: VideoPlayerStateListener) {
        lock.lock()
        defer { lock.unlock() }

        guard let index = listeners.firstIndex(where: { $0 === listener }) else { return }
        listeners.remove(at: index)
    }

    func prepare(media: Media,
                 view: VideoPlayerView?) {
        lock.lock()
        defer { lock.unlock() }

        playerView = view

        view?.preloadFirstFrame(media: media, videoPlayer: self)
    }

    func loadMedia(media: Media,
                   autoPlay: Bool = true,
                   muteOnPlay: Bool = false,
                   view: VideoPlayerView,
                   repeatable: Bool = true) {
        lock.lock()
        defer { lock.unlock() }

        playerView = view

        stop()

        self.repeatable = repeatable
        firstStart = true
        self.media = media

        notifyListeners(action: { $0.mediaDidChange?(media: media) })

        guard let url = URL(string: media.videoUrl) else {
            return
        }

        let asset = AVAsset(url: url)
        let keys = ["playable"]
        asset.loadValuesAsynchronously(forKeys: keys) { [weak self] in
            DispatchQueue.main.async {
                guard self?.media === media else { return }

                let playerItem = AVPlayerItem(asset: asset)
                let videoPlayer = AVQueuePlayer(items: [playerItem])
                self?.videoPlayer = videoPlayer
                if repeatable {
                    self?.videoPlayerLooper = AVPlayerLooper(player: videoPlayer, templateItem: playerItem)
                }
                self?.addPlayerObservers()

                if muteOnPlay {
                    self?.mute(true)
                }

                if autoPlay {
                    videoPlayer.play()
                }
            }
        }
        view.prepare(media: media, videoPlayer: self)
    }

    func pause() {
        videoPlayer?.pause()
    }

    func resume() {
        videoPlayer?.play()
    }

    func mute(_ isMuted: Bool) {
        videoPlayer?.isMuted = isMuted
    }

    func stop() {
        removePlayerObservers()
        videoPlayer?.pause()
        videoPlayer = nil
        videoPlayerLooper = nil
    }
}

extension VideoPlayer {
    func removePlayerObservers() {
        lock.lock()
        defer { lock.unlock() }

        guard let player = videoPlayer else { return }

        player.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.currentItem))
        player.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.currentItem.status))
        player.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.isMuted))
        player.removeObserver(self, forKeyPath: #keyPath(AVQueuePlayer.timeControlStatus))
    }

    func addPlayerObservers() {
        lock.lock()
        defer { lock.unlock() }

        guard let player = videoPlayer else { return }

        player.addObserver(self,
                           forKeyPath: #keyPath(AVQueuePlayer.currentItem),
                           options: [.old, .new],
                           context: &playerItemContext)
        player.addObserver(self,
                           forKeyPath: #keyPath(AVQueuePlayer.currentItem.status),
                           options: [.old, .new],
                           context: &playerItemStatusContext)
        player.addObserver(self,
                           forKeyPath: #keyPath(AVQueuePlayer.isMuted),
                           options: [.old, .new],
                           context: &playerMuteContext)
        player.addObserver(self,
                           forKeyPath: #keyPath(AVQueuePlayer.timeControlStatus),
                           options: [.old, .new],
                           context: &playerStatusContext)
    }

    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey: Any]?,
                                      context: UnsafeMutableRawPointer?) {
        guard let player = videoPlayer else { return }

        if context == &playerStatusContext {
            if
                let change = change,
                let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
                let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int
            {
                let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
                let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)

                if newStatus != oldStatus {
                    switch newStatus {
                    case .playing:
                        notifyListeners { $0.playerStateDidChange?(.playing) }
                    case .paused:
                        notifyListeners { $0.playerStateDidChange?(.paused) }
                    case .waitingToPlayAtSpecifiedRate:
                        notifyListeners { $0.playerStateDidChange?(.idle) }
                    default:
                        break
                    }
                } else {
                    if newStatus == .playing {
                        notifyListeners { $0.playerStateDidChange?(.repeated) }
                    }
                }
            }
        } else if context == &playerMuteContext {
            notifyListeners { $0.muteDidChange?(isMuted: player.isMuted) }
        } else if context == &playerItemContext {
        } else if context == &playerItemStatusContext {
            guard let currentItem = player.currentItem else { return }

            switch currentItem.status {
            case .failed:
                notifyListeners { $0.playerDidFail?(currentItem.error?.localizedDescription) }
            case .unknown:
                notifyListeners { $0.playerStateDidChange?(.unknown) }
            case .readyToPlay:
                if firstStart {
                    firstStart = false
                    notifyListeners { $0.playerStateDidChange?(.readyToPlay) }
                }
            @unknown default:
                break
            }

        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

class ToggleButton: UIButton {
    var type: ToggleButtonType = .sound {
        didSet {
            updateIcon()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        updateIcon()
    }

    var isOn: Bool = false {
        didSet {
            updateIcon()
        }
    }

    func updateIcon() {
        if isOn {
            setImage(type.imageForOnState, for: .normal)
        } else {
            setImage(type.imageForOffState, for: .normal)
        }
        tintColor = .white
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum GPHVideoPlayerViewConstants {
    static let hideControlsInitialDelay: TimeInterval = 3.0
    static let hideControlsDelay: TimeInterval = 2.0
    static let hideControlsDuration: TimeInterval = 0.4
}
