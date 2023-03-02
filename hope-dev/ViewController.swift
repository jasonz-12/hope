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

// MARK: View Controller
class ViewController: UIViewController, UITableViewDataSource, UIBarPositioningDelegate, UINavigationBarDelegate {

    var recognizer: SPXSpeechRecognizer!
    var recognizerIsRunning = false
    
    var fromMicButton: UIButton!
    var sub: String!
    var region: String!
    var chatPrompt: String!
    var leadingConstraint: NSLayoutConstraint!
    var trailingConstraint: NSLayoutConstraint!
    var audioPlayer: AVAudioPlayer?
    var messages: [[String: Any]] = []
    var history = ""
    var chatHistoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("chat_history.txt")
    var selectedLanguage: String!
    var voiceName: String?
    var speechStyle: String?
    var speechPitch: String?
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var msgTable: UITableView!
    @IBOutlet weak var navBar: UINavigationBar!

    override func viewDidLoad() {
        super.viewDidLoad()
        // load subscription information
        sub = "289df82ad08e424cbd729c7dd332ddff"
        region = "canadacentral"
        
        // Load the selected language type
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en-US"
        print(selectedLanguage)
        if selectedLanguage == "en-US" {
            voiceName = "en-US-JennyNeural"
            chatPrompt = "Your name is Hope, your MBTI personality is ENTP. You will be friendly, encourgaing, helpful. You will focus on the user's mental well-being. You will respond in the most concise way possible.\n"
        } else if selectedLanguage == "zh-CN" {
            voiceName = "zh-CN-XiaomengNeural"
            chatPrompt = "你的名字是Hope，你的MBTI人格测试结果是ENTP，你是个北京人。你会非常在意他人的心里感受，并且会站在别人的立场思考。你将会以最精辟的方式来回答。"
        }
        let speechStyle = "affectionate"
        let speechPitch = "5%"
        print(selectedLanguage)
        print(voiceName)
        print(speechStyle)
        print(speechPitch)
        
        // Setup recognizer
        let speechConfig = try! SPXSpeechConfiguration(subscription: sub, region: region)
        speechConfig.speechRecognitionLanguage = selectedLanguage
        let audioConfig = SPXAudioConfiguration()
        recognizer = try! SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
        
        // UI Stuff
        // Message Table View
        msgTable.dataSource = self
        msgTable.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        msgTable.separatorStyle = .none // Remove the cell separator lines
        
        // Navigation Bar
        navBar.delegate = self
        
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cell = msgTable.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        
        cell.messageLabel.text = message["text"] as? String
        cell.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Adjust color
        if message["sender"] as? String == "User" {
            cell.messageLabel.textColor =  UIColor.white
            cell.messageBackground.backgroundColor = UIColor.systemBlue
            cell.left_ic_leadingConstraint.isActive = false
            cell.left_mb_trailingConstraint.isActive = false
            cell.right_ic_trailingConstraint.isActive = true
            cell.right_mb_trailingConstraint.isActive = true
        } else {
            cell.messageLabel.textColor = UIColor.black
            cell.messageBackground.backgroundColor = UIColor.systemGray5
            cell.right_ic_trailingConstraint.isActive = false
            cell.right_mb_trailingConstraint.isActive = false
            cell.left_ic_leadingConstraint.isActive = true
            cell.left_mb_trailingConstraint.isActive = true
        }
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // MARK: Send messages
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
            // Scroll to the last row of the table view
            let lastRowIndex = IndexPath(row: self.messages.count - 1, section: 0)
            self.msgTable.scrollToRow(at: lastRowIndex, at: .bottom, animated: true)
        }
        // Save them
        saveMessages()
    }
    
    // MARK: Save messages
    func saveMessages(){
        // Save the `messages` into a file for session history - locally
        do {
            let data = try JSONSerialization.data(withJSONObject: messages, options: [])
            try data.write(to: chatHistoryURL)
            print("Messages saved to chatHistory.")
        } catch {
            print("Error while saving messages to chatHistory: \(error)")
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
        // Clear the audio session before recognition starts
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default, options: [])
        } catch {
            print("Error setting audio session category: \(error)")
        }
        
        // Add event handler and start recognition
        recognizer.addRecognizingEventHandler() { [weak self] recognizer, evt in
            print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
        }
        print("Listening...")

        let result = try! recognizer.recognizeOnce()
        print("recognition result: \(result.text ?? "(no result)")")
        self.sendMessage(sender: "User", contents: result.text ?? "(no result)")
        print("User message sent.")

        // Call OpenAI API to generate Response
        self.getOpenAIResult(from: result.text ?? "") { response in
            if let response = response {
                print("OpenAI generated response: \(response)")
                self.sendMessage(sender: "Hope", contents: response)
                // Stop the recognizer after each recognition
                try? self.recognizer.stopContinuousRecognition()
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
        
        // Read the history and read {"User": "content", "Hope": "content"} into text files
        do {
            let historyData = try Data(contentsOf: chatHistoryURL)
            let history = try JSONSerialization.jsonObject(with: historyData, options: []) as! [[String: Any]]
            var historyString = ""
            for message in history {
                if let sender = message["sender"] as? String, let content = message["text"] as? String {
                    historyString += "\n\(sender): \(content)"
                }
            }
            self.history = historyString
            self.chatPrompt += historyString
            print("Chat history successfully loaded.")
        } catch {
            print("Error loading chat history.")
        }
        
        // Set the request body - controll the length of historical input here
        let chatPromptLines = self.chatPrompt.components(separatedBy: "\n")
        let hopeSettings = chatPromptLines[0]
        let recentLines = Array(chatPromptLines.suffix(5))
        let recentChatPrompt = ([hopeSettings] + recentLines).joined(separator: "\n")
        print(recentChatPrompt)
        
        // Set the body for request
        let requestBody: [String: Any] = [
            "model": "text-davinci-003",
            "prompt": recentChatPrompt+"\nUser:" + text + "\nHope:",
            "temperature": 0.9,
            "max_tokens": 150,
            "top_p": 1,
            "frequency_penalty": 0,
            "presence_penalty": 0.6,
            "stop": [" User:", " Hope:"]
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: requestBody, options: [])
        request.httpBody = jsonData
        request.httpMethod = "POST"
        
        // Send the API request
        print("Sending request to OpenAI API...")
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                completion(nil)
            } else if let data = data {
                do {
                    print("Response received.")
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
        speechConfig?.speechSynthesisVoiceName = self.voiceName
        
        // SpeechSession helps to play the audio via speaker
        let speechSession = AVAudioSession.sharedInstance()
        try? speechSession.setCategory(.playback, mode: .default, options: [])
        let synthesizer = try! SPXSpeechSynthesizer(speechConfig!)
        // Configure the pitch
        let inputSSML = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='https://www.w3.org/2001/mstts' xml:lang='\(self.selectedLanguage ?? "en-US")'> <voice name='\(self.voiceName ?? "en-US-JennyNeural")'> <mstts:express-as style='\(self.speechStyle ?? "chat")'> <prosody pitch='\(self.speechPitch ?? "5%")'> \(inputText) </prosody> </mstts:express-as> </voice></speak>"
        print(inputSSML)
        let result = try! synthesizer.speakSsml(inputSSML)
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
    
    var right_mb_trailingConstraint: NSLayoutConstraint!
    var right_ic_trailingConstraint: NSLayoutConstraint!
    var left_ic_leadingConstraint: NSLayoutConstraint!
    var left_mb_trailingConstraint: NSLayoutConstraint!
    var trailingConstraint: NSLayoutConstraint!
    var leadingConstraint: NSLayoutConstraint!
    
    lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        //        let icon = UIImage(named: "icons8-Sheep on Bike")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        imageView.layer.cornerRadius = 30 // 25
        imageView.contentMode = .scaleAspectFit
        //        imageView.image = icon
        
        return imageView
    }()
    
    lazy var messageBackground: UIView = {
        let backgroundView = UIView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor.systemBlue
        backgroundView.layer.cornerRadius = 10
        return backgroundView
    }()
    
    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.backgroundColor = .clear
        label.textColor = .white
        
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        layoutViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layoutViews()
    }
    
    func layoutViews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(messageBackground)
        messageBackground.addSubview(messageLabel)
        
        left_ic_leadingConstraint = iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -52)
        left_mb_trailingConstraint = messageBackground.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -70)
        right_ic_trailingConstraint = iconImageView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        right_mb_trailingConstraint = messageBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor),
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            iconImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: 40),
//            left_ic_leadingConstraint!, // left
//            right_ic_trailingConstraint!, // right
            
            messageBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            messageBackground.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            messageBackground.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            messageBackground.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
//            left_mb_trailingConstraint!, // left
//            right_mb_trailingConstraint!, // right
            
            messageLabel.topAnchor.constraint(equalTo: messageBackground.topAnchor, constant: 5),
            messageLabel.bottomAnchor.constraint(equalTo: messageBackground.bottomAnchor, constant: -5),
            messageLabel.leadingAnchor.constraint(equalTo: messageBackground.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: messageBackground.trailingAnchor, constant: -10),
            
            // set the preferred max
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 250), // or any preferred max width
            ])
    }
}
