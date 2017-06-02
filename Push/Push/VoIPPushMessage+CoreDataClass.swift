//
//  VoIPPushMessage+CoreDataClass.swift
//  Push
//
//  Created by Jordan Zucker on 6/2/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import Foundation
import CoreData
import PushKit

@objc(VoIPPushMessage)
public class VoIPPushMessage: Event {
    
    @objc
    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    public required init(object: NSObject, entity: NSEntityDescription, context: NSManagedObjectContext) {
        super.init(entity: entity, insertInto: context)
        //        switch object {
        //        case let notification as UNNotification:
        //            creationDate = notification.date as NSDate?
        //            trigger = Trigger.trigger(for: notification.request.trigger)
        //            let content = notification.request.content
        //            body = content.body
        //            categoryIdentifier = content.categoryIdentifier
        //            subtitle = content.subtitle
        //            title = content.title
        //            userInfo = content.userInfo.debugDescription
        //            badge = content.badge?.int16Value ?? Int16.max
        //        case let userInfo as [AnyHashable : Any]:
        //            creationDate = NSDate()
        //            trigger = .none
        //
        //        default:
        //            fatalError("Can't handle object: \(object.debugDescription)")
        //        }
        guard let notification = object as? PKPushPayload else {
            fatalError("Can't handle object: \(object.debugDescription)")
        }
        creationDate = NSDate()
        self.type = notification.type.rawValue
        self.dictionaryPayload = notification.dictionaryPayload.debugDescription
    }
    
    public override var textViewDisplayText: String {
        //return "Type: PNResult\nOperation: \(stringifiedOperation)\nStatus Code: \(statusCode)\nLocal Time: \(creationDate)"
        return "Type: Push\nType: \(String(describing: type))\nDate: \(String(describing: creationDate))\nPayload: \(String(describing: dictionaryPayload))"
    }

}
