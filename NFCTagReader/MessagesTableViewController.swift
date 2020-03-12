//
//  MessagesTableViewController.swift
//  NFCTagReader
//
//  Created by Александр Борискин on 23.02.2019.
//  Copyright © 2020 Improve Digital. All rights reserved.
//

import UIKit
import CoreNFC

enum NFCMode {
    case reader
    case writer
}

class MessagesTableViewController: UITableViewController, NFCNDEFReaderSessionDelegate {

    // MARK: - Properties

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    var mode: NFCMode = .reader

    // MARK: - Actions

    // - Tag: beginScanning
    @IBAction func beginScanning(_ sender: Any) {
        mode = .reader
        startNFCSession()
    }

    @IBAction func beginWriting(_ sender: Any) {
        mode = .writer
        startNFCSession()
    }
    
    private func startNFCSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        let message = mode == .reader ? "Read tag" : "Write test tag"
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = message
        session?.begin()
    }
    // MARK: - NFCNDEFReaderSessionDelegate

    // - Tag: processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {

            self.detectedMessages.append(contentsOf: messages)
            self.tableView.reloadData()
        }
    }


    // - Tag: processingNDEFTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
        let message = NFCNDEFPayload.wellKnownTypeTextPayload(string: "Hello there, General Kenobi", locale: Locale.current)
        let new = NFCNDEFPayload(format: .media, type: "UIImage".data(using: .utf8)!, identifier: "SuperUniqueIdentifier".data(using: .utf8)!, payload: UIImage(named: "ic_location")!.jpegData(compressionQuality: 1.0)!)
        let nfcMessage = NFCNDEFMessage(records: [message!])
        if tags.count > 1 {

            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
                        
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }
                
                if self.mode == .reader {
                    tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                        var statusMessage: String
                        if nil != error || nil == message {
                            statusMessage = "Fail to read NDEF from tag"
                        } else {
                            statusMessage = "Found 1 NDEF message"
                            if let description = message?.records.first?.wellKnownTypeTextPayload().0 {
                                statusMessage = description
                            }
                            
                            let images = message?.records.filter({ (object) -> Bool in
                                let identifier = String(data: object.identifier, encoding: .utf8)
                                return identifier == "SuperUniqueIdentifier"
                            })
                            if let imagePayload = images?.first {
                                let image = UIImage(data: imagePayload.payload)
                                print(image?.configuration.hashValue as Any)
                            }
                            DispatchQueue.main.async {
                                
                                self.detectedMessages.append(message!)
                                self.tableView.reloadData()
                            }
                        }
                        
                        session.alertMessage = statusMessage
                        session.invalidate()
                    })
                } else {
                    
                    tag.writeNDEF(nfcMessage) { error in

                        if error != nil {
                            session.invalidate(errorMessage: "Failed to write message.")
                        } else {
                            session.alertMessage = "Successfully wrote data to tag!"
                            session.invalidate()
                        }
                    }
                }
            })
        })
    }
    
    // - Tag: sessionBecomeActive
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        
    }
    
    // - Tag: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {

            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(
                    title: "Session Invalidated",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }

        self.session = nil
    }


    // MARK: - addMessage(fromUserActivity:)
    func addMessage(fromUserActivity message: NFCNDEFMessage) {
        DispatchQueue.main.async {
            self.detectedMessages.append(message)
            self.tableView.reloadData()
        }
    }
}
