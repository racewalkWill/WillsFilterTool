//
//  PGLCoreDataStack.swift
//  WillsFilterTool
//
//  Created by Will on 8/29/21.
//  Copyright © 2021 Will Loew-Blosser. All rights reserved.
//  based on Apple Sample app "Synchronizing a Local Store to the Cloud"
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class to set up the Core Data stack, observe Core Data notifications, process persistent history, and deduplicate tags.
*/

import Foundation
import CoreData

// MARK: - Core Data Stack

/**
 Core Data stack setup including history processing.
 */
class CoreDataStack {

    /**
     A persistent container that can load cloud-backed and non-cloud stores.
     */
    lazy var persistentContainer: NSPersistentContainer = {

        // Create a container that can load CloudKit-backed stores
        let container = NSPersistentCloudKitContainer(name: appStackName)

        // Enable history tracking and remote notifications
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("###\(#function): Failed to retrieve a persistent store description.")
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores(completionHandler: { (_, error) in
            guard let error = error as NSError? else { return }
            fatalError("###\(#function): Failed to load persistent stores:\(error)")
//            DispatchQueue.main.async {
//                // put back on the main UI loop for the user alert
//                let alert = UIAlertController(title: "Data Store Error", message: " \(error.localizedDescription)", preferredStyle: .alert)
//
//                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
//                    Logger(subsystem: LogSubsystem, category: LogCategory).notice("The userSaveErrorAlert \(error.localizedDescription)")
//                }))
//                let myAppDelegate =  UIApplication.shared.delegate as! AppDelegate
//                myAppDelegate.displayUser(alert: alert)
//            }
        })

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = appTransactionAuthorName
        container.viewContext.undoManager = nil // We don't need undo so set it to nil.
        container.viewContext.shouldDeleteInaccessibleFaults = true

        // Pin the viewContext to the current generation token and set it to keep itself up to date with local changes.
        container.viewContext.automaticallyMergesChangesFromParent = true
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("###\(#function): Failed to pin viewContext to the current generation:\(error)")
        }

        // Observe Core Data remote change notifications.
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of: self).storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange, object: container)

        return container
    }()

    /**
     Track the last history token processed for a store, and write its value to file.

     The historyQueue reads the token when executing operations, and updates it after processing is complete.
     */
    private var lastHistoryToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = lastHistoryToken,
                let data = try? NSKeyedArchiver.archivedData( withRootObject: token, requiringSecureCoding: true) else { return }

            do {
                try data.write(to: tokenFile)
            } catch {
                print("###\(#function): Failed to write token data. Error = \(error)")
            }
        }
    }

    /**
     The file URL for persisting the persistent history token.
    */
    private lazy var tokenFile: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(appStackName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("###\(#function): Failed to create persistent container URL. Error = \(error)")
            }
        }
        return url.appendingPathComponent("token.data", isDirectory: false)
    }()

    /**
     An operation queue for handling history processing tasks: watching changes, deduplicating tags, and triggering UI updates if needed.
     */
    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /**
     The URL of the thumbnail folder.
     */
    static var attachmentFolder: URL = {
        var url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(appStackName, isDirectory: true)
        url = url.appendingPathComponent("attachments", isDirectory: true)

        // Create it if it doesn’t exist.
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

            } catch {
                print("###\(#function): Failed to create thumbnail folder URL: \(error)")
            }
        }
        return url
    }()

    init() {
        // Load the last token from the token file.
        if let tokenData = try? Data(contentsOf: tokenFile) {
            do {
                lastHistoryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: tokenData)
            } catch {
                print("###\(#function): Failed to unarchive NSPersistentHistoryToken. Error = \(error)")
            }
        }
    }
}
// MARK: - Notifications

extension CoreDataStack {
    /**
     Handle remote store change notifications (.NSPersistentStoreRemoteChange).
     */
    @objc
    func storeRemoteChange(_ notification: Notification) {
        print("###\(#function): Merging changes from the other persistent store coordinator.")

        // Process persistent history to merge changes from other coordinators.
        historyQueue.addOperation {
            self.processPersistentHistory()
        }
    }
}

/**
 Custom notifications in this sample.
 */
extension Notification.Name {
    static let didFindRelevantTransactions = Notification.Name("didFindRelevantTransactions")
}

// MARK: - Persistent history processing

extension CoreDataStack {

    func build14DeleteOrphanStacks() {
        // prior builds did not have the delete rule to remove child stacks
        // at startup appDelegate checks db version, build and PGLVersion table
        // if buildLabel is not migrated run this func

    }
    /**
     Process persistent history, posting any relevant transactions to the current view.
     */
    func processPersistentHistory() {
        let taskContext = persistentContainer.newBackgroundContext()
        taskContext.performAndWait {

            // Fetch history received from outside the app since the last token
            let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest!
            historyFetchRequest.predicate = NSPredicate(format: "author != %@", appTransactionAuthorName)
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)
            request.fetchRequest = historyFetchRequest

            let result = (try? taskContext.execute(request)) as? NSPersistentHistoryResult
            guard let transactions = result?.result as? [NSPersistentHistoryTransaction],
                  !transactions.isEmpty
                else { return }

            // Post transactions relevant to the current view.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .didFindRelevantTransactions, object: self, userInfo: ["transactions": transactions])
            }

            // Deduplicate the new tags.
//            var newTagObjectIDs = [NSManagedObjectID]()
//            let tagEntityName = PGLTag.entity().name

//            for transaction in transactions where transaction.changes != nil {
//                for change in transaction.changes!
//                    where change.changedObjectID.entity.name == tagEntityName && change.changeType == .insert {
//                        newTagObjectIDs.append(change.changedObjectID)
//                }
//            }
//            if !newTagObjectIDs.isEmpty {
//                deduplicateAndWait(tagObjectIDs: newTagObjectIDs)
//            }

            // Update the history token using the last transaction.
            lastHistoryToken = transactions.last!.token
        }
    }
}

// MARK: - Deduplicate tags

extension CoreDataStack {
    /**
     Deduplicate tags with the same name by processing the persistent history, one tag at a time, on the historyQueue.

     All peers should eventually reach the same result with no coordination or communication.
     */
//    private func deduplicateAndWait(tagObjectIDs: [NSManagedObjectID]) {
//        // Make any store changes on a background context
//        let taskContext = persistentContainer.backgroundContext()
//
//        // Use performAndWait because each step relies on the sequence. Since historyQueue runs in the background, waiting won’t block the main queue.
//        taskContext.performAndWait {
//            tagObjectIDs.forEach { tagObjectID in
//                self.deduplicate(tagObjectID: tagObjectID, performingContext: taskContext)
//            }
//            // Save the background context to trigger a notification and merge the result into the viewContext.
//            taskContext.save(with: .deduplicate)
//        }
//    }

    /**
     Deduplicate a single tag.
     */
//    private func deduplicate(tagObjectID: NSManagedObjectID, performingContext: NSManagedObjectContext) {
//        guard let tag = performingContext.object(with: tagObjectID) as? PGLTag,
//            let tagName = tag.name else {
//            fatalError("###\(#function): Failed to retrieve a valid tag with ID: \(tagObjectID)")
//        }
//
//        // Fetch all tags with the same name, sorted by uuid
//        let fetchRequest: NSFetchRequest<PGLTag> = PGLTag.fetchRequest()
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Schema.PGLTag.uuid.rawValue, ascending: true)]
//        fetchRequest.predicate = NSPredicate(format: "\(Schema.PGLTag.name.rawValue) == %@", tagName)
//
//        // Return if there are no duplicates.
//        guard var duplicatedTags = try? performingContext.fetch(fetchRequest), duplicatedTags.count > 1 else {
//            return
//        }
//        print("###\(#function): Deduplicating tag with name: \(tagName), count: \(duplicatedTags.count)")
//
//        // Pick the first tag as the winner.
//        let winner = duplicatedTags.first!
//        duplicatedTags.removeFirst()
//        remove(duplicatedTags: duplicatedTags, winner: winner, performingContext: performingContext)
//    }

    /**
     Remove duplicate tags from their respective posts, replacing them with the winner.
     */
//    private func remove(duplicatedTags: [PGLTag], winner: PGLTag, performingContext: NSManagedObjectContext) {
//        duplicatedTags.forEach { tag in
//            defer { performingContext.delete(tag) }
//            guard let posts = tag.posts else { return }
//
//            for case let post as Post in posts {
//                if let mutableTags: NSMutableSet = post.tags?.mutableCopy() as? NSMutableSet {
//                    if mutableTags.contains(tag) {
//                        mutableTags.remove(tag)
//                        mutableTags.add(winner)
//                    }
//                }
//            }
//        }
//    }
}

