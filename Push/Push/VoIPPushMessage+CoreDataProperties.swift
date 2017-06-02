//
//  VoIPPushMessage+CoreDataProperties.swift
//  Push
//
//  Created by Jordan Zucker on 6/2/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import Foundation
import CoreData


extension VoIPPushMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VoIPPushMessage> {
        return NSFetchRequest<VoIPPushMessage>(entityName: "VoIPPushMessage")
    }

    @NSManaged public var type: String?
    @NSManaged public var dictionaryPayload: String?

}
