//
//  Message+CoreDataClass.swift
//  Push
//
//  Created by Jordan Zucker on 1/26/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import Foundation
import CoreData
import PubNub

@objc(Message)
public class Message: Result {
    
    @objc
    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    public required init(object: NSObject, entity: NSEntityDescription, context: NSManagedObjectContext) {
        super.init(object: object, entity: entity, context: context)
        guard let messageResult = object as? PNMessageResult else {
            fatalError()
        }
        timetoken = messageResult.data.timetoken.int64Value
        channel = messageResult.data.channel
        subscription = messageResult.data.subscription
        publisher = messageResult.data.publisher
        guard let actualMessage = messageResult.data.message else {
            message = "There is not message"
            return
        }
        message = (actualMessage as AnyObject).debugDescription
    }
    
    public override var textViewDisplayText: String {
        let superText = super.textViewDisplayText
        return superText + "\nTimetoken: \(timetoken)\nChannel: \(String(describing: channel))\nSubscription: \(String(describing: subscription))\nPublisher: \(String(describing: publisher))\nMessage: \(String(describing: message))"
    }

}
