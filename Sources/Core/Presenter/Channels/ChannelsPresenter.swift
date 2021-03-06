//
//  ChannelsPresenter.swift
//  StreamChatCore
//
//  Created by Alexey Bukhtin on 14/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChatClient
import RxSwift
import RxCocoa

/// A channels presenter.
public final class ChannelsPresenter: Presenter {
    /// A callback type to provide an extra setup for a channel presenter.
    public typealias OnChannelPresenterSetup = (ChannelPresenter) -> Void
    
    /// Query options.
    public let queryOptions: QueryOptions
    
    /// Filter channels.
    ///
    /// For example, in your channels view controller:
    /// ```
    /// if let currentUser = User.current {
    ///     presenter = .init(channelType: .messaging, filter: "members".in([currentUser.id]))
    /// }
    /// ```
    public let filter: Filter
    
    /// Sort channels.
    ///
    /// By default channels will be sorted by the last message date.
    public let sorting: [Sorting]
    
    /// A callback to provide an extra setup for a channel presenter.
    public var onChannelPresenterSetup: OnChannelPresenterSetup?
    
    /// A filter for channels events.
    public var eventsFilter: StreamChatClient.Event.Filter?
    
    /// A filter for a selected channel events.
    /// When a user select a channel, then `ChannelsViewController` create a `ChatViewController`
    /// with a selected channel presenter and this channel events filter.
    public var channelEventsFilter: StreamChatClient.Event.Filter?
    
    let actions = PublishSubject<ViewChanges>()
    var disposeBagForInternalRequests = DisposeBag()
    
    /// Init a channels presenter.
    ///
    /// - Parameters:
    ///   - filter: a channel filter.
    ///   - sorting: a channel sorting. By default channels will be sorted by the last message date.
    ///   - queryOptions: query options (see `QueryOptions`).
    public init(filter: Filter = .none,
                sorting: [Sorting] = [],
                queryOptions: QueryOptions = .all) {
        self.queryOptions = queryOptions
        self.filter = filter
        self.sorting = sorting
        super.init(pageSize: .channelsPageSize)
    }
}

// MARK: - API

public extension ChannelsPresenter {
    
    /// View changes (see `ViewChanges`).
    func changes(_ onNext: @escaping Client.Completion<ViewChanges>) -> AutoCancellable {
        rx.changes.asObservable().bind(to: onNext)
    }
    
    /// Hide a channel and remove a channel presenter from items.
    ///
    /// - Parameters:
    ///   - channelPresenter: a channel presenter.
    ///   - clearHistory: checks if needs to remove a message history of the channel.
    ///   - completion: an empty completion block.
    func hide(_ channelPresenter: ChannelPresenter,
              clearHistory: Bool = false,
              _ completion: @escaping Client.Completion<EmptyData> = { _ in }) {
        rx.hide(channelPresenter, clearHistory: clearHistory).asObservable().bindOnce(to: completion)
    }
}

// MARK: - Response Parsing

extension ChannelsPresenter {
    func parseChannels(_ channels: [ChannelResponse]) -> ViewChanges {
        let isNextPage = next != pageSize
        var items = isNextPage ? self.items : [PresenterItem]()
        
        if let last = items.last, case .loading = last {
            items.removeLast()
        }
        
        let row = items.count
        
        items.append(contentsOf: channels.map {
            let channelPresenter = ChannelPresenter(response: $0, queryOptions: queryOptions)
            onChannelPresenterSetup?(channelPresenter)
            return .channelPresenter(channelPresenter)
        })
        
        if channels.count == next.limit {
            next = .channelsNextPageSize + .offset(next.offset + next.limit)
            items.append(.loading(false))
        } else {
            next = pageSize
        }
        
        self.items = items
        
        return isNextPage ? .reloaded(row, items) : .reloaded(0, items)
    }
}

// MARK: - WebSocket Events Parsing

extension ChannelsPresenter {
    func parse(event: StreamChatClient.Event) -> ViewChanges {
        if event.isNotification {
            return parseNotifications(event: event)
        }
        
        guard let cid = event.cid else {
            return .none
        }
        
        switch event {
        case .channelUpdated(let channelResponse, _, _):
            if let index = items.firstIndex(where: channelResponse.channel.cid),
                let channelPresenter = items[index].channelPresenter {
                channelPresenter.parse(event: event)
                return .itemsUpdated([index], [], items)
            }
            
        case .channelDeleted:
            if let index = items.firstIndex(where: cid) {
                items.remove(at: index)
                return .itemRemoved(index, items)
            }
            
        case .channelHidden:
            if let index = items.firstIndex(where: cid) {
                items.remove(at: index)
                return .itemRemoved(index, items)
            }
            
        case .messageNew:
            return parseNewMessage(event: event)
            
        case .messageDeleted(let message, _, _, _):
            if let index = items.firstIndex(where: cid),
                let channelPresenter = items[index].channelPresenter {
                channelPresenter.parse(event: event)
                return .itemsUpdated([index], [message], items)
            }
            
        case .messageRead:
            if let index = items.firstIndex(where: cid) {
                return .itemsUpdated([index], [], items)
            }
            
        default:
            break
        }
        
        return .none
    }
    
    private func parseNotifications(event: StreamChatClient.Event) -> ViewChanges {
        switch event {
        case .notificationAddedToChannel(let channel, _, _):
            return parseNewChannel(channel: channel)
        case .notificationMarkAllRead:
            return .reloaded(0, items)
        case .notificationMarkRead(_, let channel, _, _):
            if let index = items.firstIndex(where: channel.cid) {
                return .itemsUpdated([index], [], items)
            }
        default:
            break
        }
        
        return .none
    }
    
    private func parseNewMessage(event: StreamChatClient.Event) -> ViewChanges {
        guard let cid = event.cid,
            let index = items.firstIndex(where: cid),
            let channelPresenter = items.remove(at: index).channelPresenter else {
                return .none
        }
        
        channelPresenter.parse(event: event)
        items.insert(.channelPresenter(channelPresenter), at: 0)
        
        if index == 0 {
            return .itemsUpdated([0], [], items)
        }
        
        return .itemMoved(fromRow: index, toRow: 0, items)
    }
    
    private func parseNewChannel(channel: Channel) -> ViewChanges {
        guard items.firstIndex(where: channel.cid) == nil else {
            return .none
        }
        
        let channelPresenter = ChannelPresenter(channel: channel, queryOptions: queryOptions)
        onChannelPresenterSetup?(channelPresenter)
        // We need to load messages for new channel.
        loadChannelMessages(channelPresenter)
        items.insert(.channelPresenter(channelPresenter), at: 0)
        
        // Update pagination offset.
        if next != pageSize {
            next = .channelsNextPageSize + .offset(next.offset + 1)
        }
        
        return .itemsAdded([0], nil, false, items)
    }
    
    private func loadChannelMessages(_ channelPresenter: ChannelPresenter) {
        channelPresenter.rx.parsedMessagesRequest.asObservable()
            .take(1)
            .subscribe(onNext: { [weak self, weak channelPresenter] _ in
                guard let self = self,
                    let channelPresenter = channelPresenter,
                    let index = self.items.firstIndex(where: channelPresenter.channel.cid) else {
                        return
                }
                
                self.actions.onNext(.itemsUpdated([index], [], self.items))
            })
            .disposed(by: disposeBagForInternalRequests)
    }
}
