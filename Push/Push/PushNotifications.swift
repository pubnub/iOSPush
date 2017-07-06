//
//  PushNotifications.swift
//  Push
//
//  Created by Jordan Zucker on 1/24/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import UIKit
import CoreData
import PushKit

class PushNotifications: NSObject, PKPushRegistryDelegate {
    
    static let sharedNotifications = PushNotifications()
    
    let pushContext: NSManagedObjectContext
    let pushRegistry: PKPushRegistry
    
    override init() {
        self.pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        self.pushContext = DataController.sharedController.newBackgroundContext()
        super.init()
        pushRegistry.delegate = self
        pushContext.automaticallyMergesChangesFromParent = true
    }
    
    func clearBadgeCount() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func appDidLaunchOperations(viewController: UIViewController? = nil) {
        print("\(#function) (pushTokenForType) before setting desired push types => \(String(describing: pushRegistry.pushToken(forType: .voIP)))")
        pushRegistry.desiredPushTypes = [.voIP]
        print("\(#function) (pushTokenForType) after setting desired push types => \(String(describing: pushRegistry.pushToken(forType: .voIP)))")
    }
    
    // MARK: - PKPushRegistryDelegate
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenForType type: PKPushType) {
        print("!!!!!!!!!!!! \(#function) registry: \(registry.debugDescription), for type: \(type.rawValue)")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, forType type: PKPushType) {
        print("\(#function) registry: \(registry.debugDescription), credentials: \(credentials.debugDescription), for type: \(type.rawValue)")
        print("\(#function) (pushTokenForType) after update credentials called => \(String(describing: pushRegistry.pushToken(forType: .voIP)))")
        DataController.sharedController.performBackgroundTask { (context) in
            let currentUser = DataController.sharedController.fetchCurrentUser(in: context)
            currentUser.pushToken = credentials.token
            do {
                try context.save()
            } catch {
                fatalError("What went wrong now??")
            }
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
        print("\(#function) registry: \(registry.debugDescription), with payload: \(payload.debugDescription), for type: \(type.rawValue)")
        pushContext.perform {
            _ = DataController.sharedController.createCoreDataEvent(in: self.pushContext, for: payload, with: DataController.sharedController.fetchCurrentUser(in: self.pushContext))
            do {
                try self.pushContext.save()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

}
