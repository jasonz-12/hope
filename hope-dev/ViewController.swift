//
//  ViewController.swift
//  hope-dev
//
//  Created by Jason Zhu on 2023-02-18.
//

import UIKit
import AVFoundation
import Speech
import MicrosoftCognitiveServicesSpeech
import MessageKit

class ViewController: UIViewController, UITableViewDataSource {

    var fromMicButton: UIButton!
    
    var sub: String!
    var region: String!
    var chatPrompt: String!
    
    var audioPlayer: AVAudioPlayer?
    var messages: [[String: Any]] = []
    

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var msgTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load subscription information
        sub = "289df82ad08e424cbd729c7dd332ddff"
        region = "canadacentral"
        chatPrompt = "Your name is Hope, you will talk and chat with the user, which is your friend. Whenever they ask a question, you will try my best to answer them kindly in English. You have an MBTI of INTJ."
        
        // UI Stuff
        msgTable.dataSource = self
        msgTable.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
 
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cell = msgTable.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        
        cell.messageLabel.text = message["text"] as? String
        cell.timestampLabel.text = message["timestamp"] as? String
        
        if message["sender"] as? String == "User" {
            cell.backgroundColor = UIColor.systemBlue
            cell.messageLabel.textColor =  UIColor.white
        } else {
            cell.backgroundColor = UIColor.systemGray5
            cell.messageLabel.textColor = UIColor.black
        }
        
        return cell
    }
    
    // MARK: send messages
    func sendMessage(sender: String, contents: String) {
        let timestamp = Date().iso8601
        
        let message = [
            "text": contents,
            "sender": sender,
            "timestamp": timestamp
        ]
        
        messages.append(message)
        DispatchQueue.main.async {
            self.msgTable.reloadData()
        }
    }
    
    // MARK: Actions
    @IBAction func fromMicButtonClicked() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.recognizeFromMic()
        }
    }
    
    // MARK: Recognition
    func recognizeFromMic() {
        var speechConfig: SPXSpeechConfiguration?
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: sub, region: region)
        } catch {
            print("error \(error) happened")
            speechConfig = nil
        }
        speechConfig?.speechRecognitionLanguage = "en-US"
        
        let audioConfig = SPXAudioConfiguration()
        
        let reco = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
        
        reco.addRecognizingEventHandler() {reco, evt in
            print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
        }
        print("Listening...")
        
        let result = try! reco.recognizeOnce()
        print("recognition result: \(result.text ?? "(no result)")")
//        self.updateLabel(text: result.text, color: .black)
        self.sendMessage(sender: "user", contents: result.text ?? "(no result)")
        
        // Call OpenAI API to generate Response
        self.getOpenAIResult(from: result.text ?? "") { response in
            if let response = response {
                print("OpenAI generated response: \(response)")
                    self.sendMessage(sender: "Hope", contents: response)
            } else {
                print("Error generating response.")
                self.sendMessage(sender: "Hope", contents: "Error")
            }
        }
    }
    
    
    // MARK: OpenAI API
    func getOpenAIResult(from text: String, completion: @escaping (String?) -> Void) {
        // Set your API key
        var response_text: String!
        print("Received input \(text).")
        let apiKey = "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"
        
        // Set the API endpoint URL
        let apiUrl = URL(string: "https://api.openai.com/v1/completions")!
        
        // Set the request headers
        var request = URLRequest(url: apiUrl)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the request body
        let requestBody: [String: Any] = [
            "model": "text-davinci-003",
            "prompt": chatPrompt+"Q:"+text+"A:",
            "temperature": 0.75,
            "max_tokens": 100,
            "n": 1,
            "stop": ["\n"]
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: requestBody, options: [])
        request.httpBody = jsonData
        request.httpMethod = "POST"
        
        // Send the API request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                completion(nil)
            } else if let data = data {
                do {
                    // Parse the response JSON
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let choices = json?["choices"] as? [[String: Any]], let text = choices[0]["text"] as? String {
                        response_text = text
                        // Pass the response to the completion handler
                        completion(response_text)
                        
                        // Call textToSpeech
                        self.textToSpeech(inputText: response_text)
                    } else {
                        print("Error: response JSON did not contain expected data")
                        print("Response data: \(String(data: data, encoding: .utf8) ?? "")")
                        completion(nil)
                    }
                } catch let error {
                    print("Error parsing response JSON: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "")")
                    completion(nil)
                }
            }
        }
        task.resume()
    }

    // Then, perform a text-to-speech
    func textToSpeech(inputText: String) {
        var speechConfig: SPXSpeechConfiguration?
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: sub, region: region)
        } catch {
            print("Error \(error) happened.")
            speechConfig = nil
        }
        speechConfig?.speechSynthesisVoiceName = "en-US-JennyNeural"
        let synthesizer = try! SPXSpeechSynthesizer(speechConfig!)
        let result = try! synthesizer.speakText(inputText)
        if result.reason == SPXResultReason.canceled
        {
            let cancellationDetails = try! SPXSpeechSynthesisCancellationDetails(fromCanceledSynthesisResult: result)
            print("Canceleled, error code: \(cancellationDetails.errorCode) detail: \(cancellationDetails.errorDetails!) ")
            return
        }
    }
}

// MARK: - Extensions

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

class MessageCell: UITableViewCell {
    
    let messageLabel = UILabel()
    let timestampLabel = UILabel()
    let bubbleImageView = UIImageView()
    
    var leadingConstraint: NSLayoutConstraint!
    var trailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(messageLabel)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(bubbleImageView)
        
        bubbleImageView.contentMode = .scaleToFill
        bubbleImageView.tintColor = UIColor.systemBlue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        messageLabel.frame = CGRect(x: 16, y: 0, width: contentView.frame.width - 32, height: contentView.frame.height - 16)
        timestampLabel.frame = CGRect(x: contentView.frame.width - 100, y: contentView.frame.height - 16, width: 84, height: 16)
        
        if leadingConstraint == nil {
            leadingConstraint = bubbleImageView.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor, constant: -8)
        }
        
        if trailingConstraint == nil {
            trailingConstraint = bubbleImageView.trailingAnchor.constraint(equalTo: messageLabel.trailingAnchor, constant: 8)
        }
        
        bubbleImageView.frame = CGRect(x: messageLabel.frame.minX - 12, y: messageLabel.frame.minY - 8, width: messageLabel.frame.width + 24, height: messageLabel.frame.height + 16)
    }
    
    func setAlignment(sender: String) {
        if sender == "User" {
            leadingConstraint.isActive = true
            trailingConstraint.isActive = false
            bubbleImageView.tintColor = UIColor.systemBlue
        } else {
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
            bubbleImageView.tintColor = UIColor.systemGray5
        }
    }
}


