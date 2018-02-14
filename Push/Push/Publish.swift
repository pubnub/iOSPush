//
//  Publish.swift
//  Push
//
//  Created by Jordan Zucker on 1/24/17.
//  Copyright © 2017 PubNub. All rights reserved.
//

import UIKit
import PubNub
import CoreData

extension Network {
    
    func publishAlertController(handler: ((UIAlertAction) -> Swift.Void)? = nil) -> UIAlertController {
        let alertController = UIAlertController(title: "Publish Message to PubNub", message: "Configure the message then click publish below", preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter one channel name ..."
        }
        
        let channelsTextField = alertController.textFields![0]
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter message payload ..."
            textField.text = "Hello, world!"
        }
        
        let payloadTextField = alertController.textFields![1]
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter mobile push dictionary"
            textField.text = "{\"pn_apns\":{\"aps\":{\"alert\": {\"title\" : \"🚨THE GREAT ONE ALERT at https://pubnub.com\",\"body\":\"Watch Budweiser's new anthem with Wayne Gretzky and more https://pubnub.com\"}},\"data\":{\"message\":\"🚨 Watch Budweiser's new anthem with Wayne Gretzky and more.\",\"url\":\"https://www.youtube.com/watch?v=YwLnw9It9d0\",\"type\":\"generic-notification\"}}}"
        }
        
        let pushPayloadTextField = alertController.textFields![2]
        
        
        
        let publishAction = UIAlertAction(title: "Publish", style: .destructive) { (action) in
            var finalPushPayload: [String:Any]? = nil
            if let pushPayloadData = pushPayloadTextField.text?.data(using: .utf16) {
                do {
                    finalPushPayload = try JSONSerialization.jsonObject(with: pushPayloadData, options: [.allowFragments]) as? [String: Any]
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
            self.client.publish(payloadTextField.text, toChannel: channelsTextField.text!, mobilePushPayload: finalPushPayload, withCompletion: { (status) in
                self.networkContext.perform {
                    _ = DataController.sharedController.createCoreDataEvent(in: self.networkContext, for: status, with: self.user)
                    do {
                        try self.networkContext.save()
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }
            })
            handler?(action)
        }
        alertController.addAction(publishAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            handler?(action)
        }
        alertController.addAction(cancelAction)
        
        return alertController
    }
    
}
