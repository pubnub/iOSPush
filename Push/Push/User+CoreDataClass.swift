//
//  User+CoreDataClass.swift
//  
//
//  Created by Jordan Zucker on 1/11/17.
//
//

import UIKit
import CoreData
import PubNub

let UserIdentifierKey = "UserIdentifierKey"


public class User: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        identifier = UUID().uuidString
    }
    
    public static func fetchUser(for userIdentifier: String, in context: NSManagedObjectContext? = nil) -> User? {
        var context = context
        if context == nil {
            context = DataController.sharedController.persistentContainer.viewContext
        }
        var finalUser: User? = nil
        context?.performAndWait {
            let userFetchRequest: NSFetchRequest<User> = User.fetchRequest()
            userFetchRequest.predicate = NSPredicate(format: "identifier == %@", userIdentifier)
            do {
                let results = try userFetchRequest.execute()
                finalUser = results.first
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        return finalUser
    }
    
//    private static var _userID: String? {
//        if let existingUserID = UserDefaults.standard.object(forKey: UserIdentifierKey) {
//            _userID = existingUserID as! String
//        } else {
//            let uuidString = UUID().uuidString
//            UserDefaults.standard.set(uuidString, forKey: UserIdentifierKey)
//            _userID = uuidString
//        }
//        return _userID
//    }
    
//    static var userID: String {
//        if _userID
//    }
    
    static var userID: String {
        if let existingUserID = UserDefaults.standard.object(forKey: UserIdentifierKey) {
            return existingUserID as! String
        } else {
            let uuidString = UUID().uuidString
            UserDefaults.standard.set(uuidString, forKey: UserIdentifierKey)
            return uuidString
        }
    }
    
    var pushChannelsArray: [Channel]? {
        return pushChannels?.map { $0 }
    }
    
    var pushChannelsString: String? {
        guard let actualChannels = pushChannels, !actualChannels.isEmpty else {
            return nil
        }
        return actualChannels.reduce("", { (result, channel) -> String in
            if result.isEmpty {
                return channel.name!
            }
            return result + "," + channel.name!
        })
    }
    
    func alertControllerForPushChannels(in context: NSManagedObjectContext) -> UIAlertController {
        let alertController = UIAlertController(title: "Update push channels", message: "Enter or edit the push channels for this client", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "Channels ..."
            context.perform {
                let currentUser = DataController.sharedController.fetchCurrentUser(in: context)
                guard let channelsString = currentUser.pushChannelsString else {
                    return
                }
                DispatchQueue.main.async {
                    textField.text = channelsString
                }
            }
        }
        
        let textField = alertController.textFields![0] // we just added only a single textField
        
        let updateAction = UIAlertAction(title: "Update", style: .default) { (action) in
            defer {
                context.perform {
                    do {
                        print("Save push channels change!")
                        try context.save()
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }
            }
            context.perform {
                let currentUser = DataController.sharedController.fetchCurrentUser(in: context)
                guard let entryText = textField.text, !entryText.isEmpty else {
                    context.perform {
                        currentUser.pushChannels?.removeAll()
                    }
                    return
                }
                var channelsArray: [String]? = nil
                do {
                    if let inputArray = try PubNub.stringToSubscribablesArray(channels: entryText) {
                        channelsArray = inputArray
                    }
                } catch {
                    fatalError(error.localizedDescription)
                }
                // check this forced unwrap
                let channelsObjectArray = channelsArray!.map({ (channelName) -> Channel in
                    let foundChannel = Channel.channel(in: context, with: channelName, shouldSave: false)
                    return foundChannel!
                })
                let channelsSet: Set<Channel> = Set(channelsObjectArray) // we can forcibly unwrap because we checked for channels above
                if !channelsSet.isEmpty {
                    print("user: \(currentUser.debugDescription)")
                    let pushChannelsKeyPath = #keyPath(User.pushChannels)
                    currentUser.mutableSetValue(forKeyPath: pushChannelsKeyPath).union(channelsSet)
                    currentUser.mutableSetValue(forKeyPath: pushChannelsKeyPath).intersect(channelsSet)
                }
                //                    currentUser.willChangeValue(forKey: keyPath, withSetMutation: .union, using: currentUser.pushChannels!)
                //                    currentUser.mutableSetValue(forKeyPath: keyPath).union(channelsSet)
                //                    currentUser.didChangeValue(forKey: keyPath, withSetMutation: .union, using: currentUser.pushChannels!)
                //currentUser.mutableSetValue(forKey: #keyPath(User.pushChannels)).intersect(channelsSet)
                //                    currentUser.pushChannels?.formUnion(channelsSet)
                //                    currentUser.pushChannels?.formIntersection(channelsSet)
                print("Done making push channel changes")
//                do {
//                    
//                    context.perform {
//                        let channelsArray = try PubNub.stringToSubscribablesArray(channels: entryText)
//                        let channelsObjectArray = channelsArray!.map({ (channelName) -> Channel in
//                            let foundChannel = Channel.channel(in: context, with: channelName, shouldSave: false)
//                            return foundChannel!
//                        })
//                        let channelsSet: Set<Channel> = Set(channelsObjectArray) // we can forcibly unwrap because we checked for channels above
//                        if !channelsSet.isEmpty {
//                            print("user: \(currentUser.debugDescription)")
//                            currentUser.mutableSetValue(forKey: #keyPath(User.pushChannels)).add(channelsSet)
//                        }
//                        //                    currentUser.willChangeValue(forKey: keyPath, withSetMutation: .union, using: currentUser.pushChannels!)
//                        //                    currentUser.mutableSetValue(forKeyPath: keyPath).union(channelsSet)
//                        //                    currentUser.didChangeValue(forKey: keyPath, withSetMutation: .union, using: currentUser.pushChannels!)
//                        //currentUser.mutableSetValue(forKey: #keyPath(User.pushChannels)).intersect(channelsSet)
//                        //                    currentUser.pushChannels?.formUnion(channelsSet)
//                        //                    currentUser.pushChannels?.formIntersection(channelsSet)
//                        print("Done making push channel changes")
//                    }
//                } catch {
//                    fatalError(error.localizedDescription)
//                }
            }
            
        }
        alertController.addAction(updateAction)
        
        let clearAction = UIAlertAction(title: "Clear", style: .destructive) { (action) in
            defer {
                context.perform {
                    do {
                        print("Save push channels change!")
                        try context.save()
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }
            }
            let currentUser = DataController.sharedController.fetchCurrentUser(in: context)
            guard let entryText = textField.text, !entryText.isEmpty else {
                context.perform {
                    currentUser.pushChannels?.removeAll()
                }
                return
            }
        }
        alertController.addAction(clearAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            
        }
        alertController.addAction(cancelAction)
        
        return alertController
    }

}