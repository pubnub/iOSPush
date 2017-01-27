//
//  Network.swift
//  Push
//
//  Created by Jordan Zucker on 1/9/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import UIKit
import CoreData
import PubNub

fileprivate let publishKey = "pub-c-a9dc3f6b-98f7-4b44-97e6-4ea5a705ab2d"
fileprivate let subscribeKey = "sub-c-93f47f52-d6b4-11e6-9102-0619f8945a4f"

@objc
class Network: NSObject, PNObjectEventListener {
    
    private var networkKVOContext = 0
    
    private let networkQueue = DispatchQueue(label: "Network", qos: .utility, attributes: [.concurrent])
    
    func config(with identifier: String) -> PNConfiguration {
        let config = PNConfiguration(publishKey: publishKey, subscribeKey: subscribeKey)
        config.uuid = identifier
        return config
    }
    
    @objc
    dynamic var client: PubNub?
    
    public var currentConfiguration: PNConfiguration {
        guard let existingConfiguration = client?.currentConfiguration() else {
            return config(with: User.userID)
        }
        return existingConfiguration
    }
    
    private var _user: User?
    
    public var user: User? {
        set {
            var settingUser = newValue
            if let actualUser = settingUser, actualUser.managedObjectContext != networkContext {
                guard let contextualUser = networkContext.object(with: actualUser.objectID) as? User else {
                    fatalError()
                }
                settingUser = contextualUser
            }
            let setItem = DispatchWorkItem(qos: .utility, flags: [.barrier]) { 
                let oldValue: User? = self._user
                self._user = settingUser
                oldValue?.removeObserver(self, forKeyPath: #keyPath(User.pushToken), context: &self.networkKVOContext)
                oldValue?.removeObserver(self, forKeyPath: #keyPath(User.pushChannels), context: &self.networkKVOContext)
                oldValue?.removeObserver(self, forKeyPath: #keyPath(User.isSubscribingToDebug), context: &self.networkKVOContext)
                settingUser?.addObserver(self, forKeyPath: #keyPath(User.pushToken), options: [.new, .old, .initial], context: &self.networkKVOContext)
                settingUser?.addObserver(self, forKeyPath: #keyPath(User.pushChannels), options: [.new, .old, .initial], context: &self.networkKVOContext)
                settingUser?.addObserver(self, forKeyPath: #keyPath(User.isSubscribingToDebug), options: [.new, .old, .initial], context: &self.networkKVOContext)
                guard let existingUser = settingUser else {
                    return
                }
                var userID: String? = nil
                self.networkContext.performAndWait {
                    userID = existingUser.identifier!
                }
                guard let pubNubUUID = userID else {
                    fatalError("How did we not get an identifier from existingUser: \(existingUser)")
                }
                let configuration = self.config(with: pubNubUUID) // can forcibly unwrap, we
                self.client = PubNub.clientWithConfiguration(configuration, callbackQueue: self.networkQueue)
                self.client?.addListener(self)
            }
            networkQueue.async(execute: setItem)
        }
        
        get {
            var finalUser: User? = nil
            let getItem = DispatchWorkItem(qos: .utility, flags: []) { 
                finalUser = self._user
            }
            networkQueue.sync(execute: getItem)
            return finalUser
        }
    }
    
    deinit {
        user = nil
    }
    
    // MARK: - KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &networkKVOContext {
            guard let existingKeyPath = keyPath else {
                return
            }
            guard let currentUser = object as? User else {
                fatalError("How is it not a user: \(object.debugDescription)")
            }
            switch existingKeyPath {
            case #keyPath(User.pushToken):
                networkContext.perform {
                    let currentPushToken = currentUser.pushToken
                    self.pushToken = currentPushToken
                }
            case #keyPath(User.pushChannels):
                networkContext.perform {
                    let newChannels = currentUser.pushChannels?.map({ (channel) -> String in
                        return channel.name!
                    })
                    var finalResult: Set<String>? = nil
                    if let actualChannels = newChannels {
                        finalResult = Set(actualChannels)
                    }
                    self.pushChannels = finalResult
                }
            case #keyPath(User.isSubscribingToDebug):
                networkContext.perform {
                    let updatedIsSubscribingToDebugChannels = currentUser.isSubscribingToDebug
                    self.isSubscribingToDebugChannels = updatedIsSubscribingToDebugChannels
                }
            default:
                fatalError("what wrong in KVO?")
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    let networkContext: NSManagedObjectContext
    
    static let sharedNetwork = Network()
    
    
    override init() {
        let context = DataController.sharedController.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        self.networkContext = context
        super.init()
    }
    
    // MARK: - APNS
    
    func requestPushChannelsForCurrentPushToken() {
        guard let currentToken = self.pushToken else {
            return
        }
        requestPushChannels(for: currentToken)
    }
    
    func requestPushChannels(for token: Data) {
        client?.pushNotificationEnabledChannelsForDeviceWithPushToken(token) { (result, status) in
            self.networkContext.perform {
                _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: result, with: self.user)
                _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: status, with: self.user)
                do {
                    try self.networkContext.save()
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
    
    var _pushToken: Data?
    
    var pushToken: Data? {
        set {
            var oldValue: Data? = nil
            let setItem = DispatchWorkItem(qos: .utility, flags: [.barrier]) {
                oldValue = self._pushToken
                self._pushToken = newValue
                self.updatePush(tokens: (oldValue, newValue), current: self._pushChannels)
            }
            networkQueue.async(execute: setItem)
        }
        
        get {
            var finalToken: Data? = nil
            let getItem = DispatchWorkItem(qos: .utility, flags: []) {
                finalToken = self._pushToken
            }
            networkQueue.sync(execute: getItem)
            return finalToken
        }
    }
    
    var _isSubscribingToDebugChannels = false
    var isSubscribingToDebugChannels : Bool {
        set {
            let setItem = DispatchWorkItem(qos: .utility, flags: [.barrier]) {
                self._isSubscribingToDebugChannels = newValue
                if newValue {
                    self.updateDebugSubscription(for: self._pushChannels, with: .add)
                } else {
                    self.updateDebugSubscription(for: self._pushChannels, with: .remove)
                }
            }
            networkQueue.async(execute: setItem)
        }
        
        get {
            var finalIsSubscribingToDebugChannels = false
            let getItem = DispatchWorkItem(qos: .utility, flags: []) {
                finalIsSubscribingToDebugChannels = self._isSubscribingToDebugChannels
            }
            networkQueue.sync(execute: getItem)
            return finalIsSubscribingToDebugChannels
        }
    }
    
    var _pushChannels: Set<String>? = nil
    
    var pushChannels: Set<String>? {
        set {
            var oldValue: Set<String>? = nil
            let setItem = DispatchWorkItem(qos: .utility, flags: [.barrier]) {
                oldValue = self._pushChannels
                self._pushChannels = newValue
                self.updatePush(channels: (oldValue, newValue), current: self._pushToken)
            }
            networkQueue.async(execute: setItem)
        }
        
        get {
            var finalChannels: Set<String>? = nil
            let getItem = DispatchWorkItem(qos: .utility, flags: []) {
                finalChannels = self._pushChannels
            }
            networkQueue.sync(execute: getItem)
            return finalChannels
        }
    }
    
    typealias tokens = (oldToken: Data?, newToken: Data?)
    typealias channels = (oldChannels: Set<String>?, newChannels: Set<String>?)
    
    enum SubscribeDebugOption {
        case add
        case remove
    }
    
    func updateDebugSubscription(for pushChannels: Set<String>?, with subscribeDebugOption: SubscribeDebugOption) {
        guard let actualClient = client else {
            return
        }

        guard let actualPushChannelSet = pushChannels else {
            guard actualClient.isSubscribing else {
                return
            }
            actualClient.unsubscribeFromAll()
            return
        }
        let pushChannelsArray = actualPushChannelSet.map { (channel) -> String in
            return channel + "-pndebug"
        }
        if subscribeDebugOption == .add {
            actualClient.subscribeToChannels(pushChannelsArray, withPresence: false)
        } else {
            guard actualClient.isSubscribing else {
                return
            }
            actualClient.unsubscribeFromChannels(pushChannelsArray, withPresence: false)
        }
    }
    
    func updatePush(tokens: tokens, current channels: Set<String>?) {
        guard let actualChannels = channelsArray(for: channels) else {
            return
        }
        
        let pushCompletionBlock: PNPushNotificationsStateModificationCompletionBlock = { (status) in
            self.networkContext.perform {
                _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: status, with: self._user)
                do {
                    try self.networkContext.save()
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
        
        switch tokens {
        case (nil, nil):
            return
        case let (oldToken, nil) where oldToken != nil:
            // If we no longer have a token at all, remove all push registrations for old token
            client?.removeAllPushNotificationsFromDeviceWithPushToken(oldToken!, andCompletion: pushCompletionBlock)
        case let (oldToken, newToken):
            // Maybe skip this guard step?
            guard oldToken != newToken else {
                print("Token stayed the same, we don't need to adjust push registration")
                return
            }
            if let existingOldToken = oldToken, oldToken != newToken {
                // Only remove old token if it's different from the new token
                client?.removePushNotificationsFromChannels(actualChannels, withDevicePushToken: existingOldToken, andCompletion: pushCompletionBlock)
            }
            if let existingNewToken = newToken {
                // add new token if it exists (not bad idea to register aggressively just in case this step got missed)
                client?.addPushNotificationsOnChannels(actualChannels, withDevicePushToken: existingNewToken, andCompletion: pushCompletionBlock)
            }
        }
    }
    
    func updatePush(channels: channels, current token: Data?) {
        guard let actualToken = token else {
            return
        }
        let pushCompletionBlock: PNPushNotificationsStateModificationCompletionBlock = { (status) in
            self.networkContext.perform {
                _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: status, with: self._user)
                do {
                    try self.networkContext.save()
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
        
        switch channels {
        case (nil, nil):
            return
        case let (oldChannels, nil) where oldChannels != nil:
            guard let existingOldChannels = channelsArray(for: oldChannels) else {
                return
            }
            client?.removePushNotificationsFromChannels(existingOldChannels, withDevicePushToken: actualToken, andCompletion: pushCompletionBlock)
            if self._isSubscribingToDebugChannels {
                updateDebugSubscription(for: oldChannels, with: .remove)
            }
        case let (nil, newChannels) where newChannels != nil:
            guard let existingNewChannels = channelsArray(for: newChannels) else {
                return
            }
            client?.addPushNotificationsOnChannels(existingNewChannels, withDevicePushToken: actualToken, andCompletion: pushCompletionBlock)
            if self._isSubscribingToDebugChannels {
                updateDebugSubscription(for: newChannels, with: .add)
            }
        case let (oldChannels, newChannels):
            guard oldChannels != newChannels else {
                print("Don't need to do anything because the channels haven't changed")
                return
            }
            let addingChannels = newChannels!.subtracting(oldChannels!)
            let removingChannels = oldChannels!.subtracting(newChannels!)
            
            if let actualAddingChannels = channelsArray(for: addingChannels), !actualAddingChannels.isEmpty {
                client?.addPushNotificationsOnChannels(actualAddingChannels, withDevicePushToken: actualToken, andCompletion: pushCompletionBlock)
                if self._isSubscribingToDebugChannels {
                    updateDebugSubscription(for: addingChannels, with: .add)
                }
            }
            if let actualRemovingChannels = channelsArray(for: removingChannels), !actualRemovingChannels.isEmpty {
                client?.removePushNotificationsFromChannels(actualRemovingChannels, withDevicePushToken: actualToken, andCompletion: pushCompletionBlock)
                if self._isSubscribingToDebugChannels {
                    updateDebugSubscription(for: removingChannels, with: .remove)
                }
            }
        }
    }
    
    func channelsArray(for set: Set<String>?) -> [String]? {
        guard let actualSet = set, !actualSet.isEmpty else {
            return nil
        }
        return actualSet.map { (channelName) -> String in
            return channelName
        }
    }
    
    // MARK: - PNObjectEventListener
    
    func client(_ client: PubNub, didReceive status: PNStatus) {
        self.networkContext.perform {
            _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: status, with: self.user)
            do {
                try self.networkContext.save()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    func client(_ client: PubNub, didReceiveMessage message: PNMessageResult) {
        self.networkContext.perform {
            _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: message, with: self.user)
            do {
                try self.networkContext.save()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

}
