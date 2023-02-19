//
//  ChatViewController.swift
//  hope-dev
//
//  Created by Jason Zhu on 2023-02-19.
//

import UIKit
import MessageKit


struct Sender: SenderType {
    var senderId: String
    
    var displayName: String
}

struct Message: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
    
    
}

class ChatViewController: MessagesViewController, MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {

    let currentUser = Sender(senderId: "self", displayName: "User")

    let otherUser = Sender(senderId: "self", displayName: "Hope")
    
    var messages = [MessageType]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagesCollectionView.dataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        
        
        // Messages array
        messages.append(Message(sender: currentUser, messageId: "1", sentDate: Date().addingTimeInterval(-86400), kind: .text("Who are you?")))
        messages.append(Message(sender: otherUser, messageId: "2", sentDate: Date().addingTimeInterval(-70000), kind: .text("My name is Hope")))
        messages.append(Message(sender: currentUser, messageId: "3", sentDate: Date().addingTimeInterval(-60000), kind: .text("What is your MBTI?")))
        messages.append(Message(sender: otherUser, messageId: "4", sentDate: Date().addingTimeInterval(-50000), kind: .text("I have an MBTI of INTJ.")))
    }
    func currentSender() -> MessageKit.SenderType {
        return currentUser
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    
    
}
