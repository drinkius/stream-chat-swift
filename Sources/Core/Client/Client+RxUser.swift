//
//  Client+RxUser.swift
//  StreamChatCore
//
//  Created by Alexey Bukhtin on 02/08/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChatClient
import RxSwift

// MARK: User Requests

public extension Reactive where Base == Client {
    
    /// Requests users with given parameters. Creates a `UsersQuery` and call the `queryUsers` with it.
    /// - Parameters:
    ///   - filter: a user filter.
    ///   - sort: a sorting.
    ///   - options: a query options.
    func queryUsers(filter: Filter,
                    sort: Sorting? = nil,
                    options: QueryOptions = []) -> Observable<[User]> {
        queryUsers(query: .init(filter: filter, sort: sort, options: options))
    }
    
    /// Requests users with a given query (see `UsersQuery`).
    /// - Parameter query: a users query (see `UsersQuery`).
    func queryUsers(query: UsersQuery) -> Observable<[User]> {
        connectedRequest(request({ [unowned base] completion in
            base.queryUsers(query: query, completion)
        }))
    }
    
    // MARK: Update User
    
    /// Update or create a user.
    @discardableResult
    func update(users: [User]) -> Observable<[User]> {
        connectedRequest(request({ [unowned base] completion in
            base.update(users: users, completion)
        }))
    }
    
    /// Update or create a user.
    /// - Parameters:
    ///   - user: a user.
    func update(user: User) -> Observable<User> {
        connectedRequest(request({ [unowned base] completion in
            base.update(user: user, completion)
        }))
    }
    
    // MARK: Mute User
    
    /// Mute a user.
    /// - Parameters:
    ///   - user: a user.
    func mute(user: User) -> Observable<MutedUsersResponse> {
        connectedRequest(request({ [unowned base] completion in
            base.mute(user: user, completion)
        }))
    }
    
    /// Unmute a user.
    /// - Parameters:
    ///   - user: a user.
    func unmute(user: User) -> Observable<EmptyData> {
        connectedRequest(request({ [unowned base] completion in
            base.unmute(user: user, completion)
        }))
    }
    
    // MARK: Flag User
    
    /// Flag a user.
    /// - Parameters:
    ///   - user: a user.
    func flag(user: User) -> Observable<FlagUserResponse> {
        connectedRequest(request({ [unowned base] completion in
            base.flag(user: user, completion)
        }))
    }
    
    /// Unflag a user.
    /// - Parameters:
    ///   - user: a user.
    func unflag(user: User) -> Observable<FlagUserResponse> {
        connectedRequest(request({ [unowned base] completion in
            base.unflag(user: user, completion)
        }))
    }
}