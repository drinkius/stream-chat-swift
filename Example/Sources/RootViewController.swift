//
//  RootViewController.swift
//  ChatExample
//
//  Created by Alexey Bukhtin on 04/09/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import StreamChatClient
import StreamChatCore
import StreamChat

final class RootViewController: UIViewController {
    
    @IBOutlet weak var splitViewButton: UIButton!
    @IBOutlet weak var splitViewSeparator: UIView!
    @IBOutlet weak var totalUnreadCountLabel: UILabel!
    @IBOutlet weak var totalUnreadCountSwitch: UISwitch!
    @IBOutlet weak var badgeLabel: UILabel!
    @IBOutlet weak var badgeSwitch: UISwitch!
    @IBOutlet weak var onlinelabel: UILabel!
    @IBOutlet weak var onlineSwitch: UISwitch!
    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var offlineMode: UISwitch!
    
    let disposeBag = DisposeBag()
    var totalUnreadCountDisposeBag = DisposeBag()
    var badgeDisposeBag = DisposeBag()
    var onlineDisposeBag = DisposeBag()
    let channel = Client.shared.channel(type: .messaging, id: "general")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewButton.isHidden = UIDevice.current.userInterfaceIdiom == .phone
        splitViewSeparator.isHidden = UIDevice.current.userInterfaceIdiom == .phone
        setupNotifications()
        navigationController?.navigationBar.prefersLargeTitles = true
        
        if User.current.isUnknown {
            navigationController?.popViewController(animated: true)
            return
        }
        
        title = User.current.name
        
        if let avatarURL = User.current.avatarURL {
            DispatchQueue.global().async {
                guard let imageData = try? Data(contentsOf: avatarURL),
                    let avatar = UIImage(data: imageData)?.resized(targetSize: .init(width: 44, height: 44))?.original else {
                    return
                }
                
                DispatchQueue.main.async {
                    let barItem = UIBarButtonItem(image: avatar, style: .plain, target: nil, action: nil)
                    self.navigationItem.rightBarButtonItem = barItem
                }
            }
        }
        
        versionLabel.text = "Demo Project\nStream Swift SDK v.\(Environment.version)"
        
        totalUnreadCountSwitch.rx.isOn.changed
            .subscribe(onNext: { [weak self] isOn in
                if isOn {
                    self?.subscribeForTotalUnreadCount()
                } else {
                    self?.totalUnreadCountDisposeBag = DisposeBag()
                    self?.totalUnreadCountLabel.text = "Total Unread Count: <Disabled>"
                }
            })
            .disposed(by: disposeBag)
        
        badgeSwitch.rx.isOn.changed
            .subscribe(onNext: { [weak self] isOn in
                if isOn {
                    self?.subscribeForUnreadCount()
                } else {
                    self?.badgeDisposeBag = DisposeBag()
                    self?.badgeLabel.text = "–"
                }
            })
            .disposed(by: disposeBag)
        
        onlineSwitch.rx.isOn.changed
            .subscribe(onNext: { [weak self] isOn in
                if isOn {
                    self?.subscribeForOnlineUsers()
                } else {
                    self?.onlineDisposeBag = DisposeBag()
                    self?.onlinelabel.text = "Watcher Count: <Disabled>"
                }
            })
            .disposed(by: disposeBag)
        
        offlineMode.rx.isOn.changed
            .subscribe(onNext: { [weak self] in
                if $0 {
                    Client.shared.disconnect()
                } else {
                    self?.navigationController?.popViewController(animated: true)
                }
            })
            .disposed(by: disposeBag)
    }
    
    @IBAction func checkForBan(_ sender: Any) {
        Client.shared.rx.connection
            .filter({ $0.isConnected })
            .take(1)
            .subscribe(onNext: { _ in
                if User.current.isBanned {
                    Banners.shared.show("🙅‍♂️ You are banned")
                } else {
                    Banners.shared.show("👍 You are not banned")
                }
            })
            .disposed(by: disposeBag)
    }
    
    func subscribeForTotalUnreadCount() {
        Client.shared.rx.unreadCount
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] unreadCount in
                self?.totalUnreadCountLabel.text = "Unread channels \(unreadCount.channels), messages: \(unreadCount.messages)"
                UIApplication.shared.applicationIconBadgeNumber = unreadCount.messages
            })
            .disposed(by: totalUnreadCountDisposeBag)
    }
    
    func subscribeForUnreadCount() {
        channel.rx.unreadCount
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] unreadCount in self?.badgeLabel.text = "\(unreadCount.messages)  " })
            .disposed(by: badgeDisposeBag)
    }
    
    func subscribeForOnlineUsers() {
        channel.rx.watcherCount
            .observeOn(MainScheduler.instance)
            .startWith(0)
            .subscribe(onNext: { [weak self] in self?.onlinelabel.text = "Watcher Count: \($0)" })
            .disposed(by: onlineDisposeBag)
    }
    
    func setupNotifications() {
        notificationsSwitch.rx.isOn.changed
            .flatMapLatest({ isOn -> Observable<Void> in
                if isOn {
                    Notifications.shared.askForPermissionsIfNeeded()
                    return .empty()
                }
                
                if let device = User.current.currentDevice {
                    return Client.shared.rx.removeDevice(deviceId: device.id).void()
                }
                
                return .empty()
            })
            .subscribe()
            .disposed(by: disposeBag)
    }
}

extension UIImage {
    fileprivate func resized(targetSize: CGSize) -> UIImage? {
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize: CGSize
        
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
