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
import SQLite3

// MARK: View Controller
class ViewController: UIViewController, UITableViewDataSource, UIBarPositioningDelegate, UINavigationBarDelegate {

    var db: OpaquePointer?
    var fileManager = FileManager.default
    var documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    var fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("hope.sqlite")
    
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
    var history: [[String: String]] = [[:]]
    var chatHistoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("chat_history.txt")
    var selectedLanguage: String!
    var voiceName: String?
    var speechStyle: String?
    var speechPitch: String?
    var speechRate: String?
    var tokenCounts: Int?
    
    // UI connectivity
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var msgTable: UITableView!
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var recordingActivity: UIActivityIndicatorView!

    // MARK: viewDidLoad()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Inits connection to db
        if !fileManager.fileExists(atPath: fileURL.path) {
            if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
                let createTableQuery = """
                    CREATE TABLE IF NOT EXISTS chat_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        role TEXT,
                        message TEXT,
                        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                    );
                """
                print("Create table query created.")
                if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
                    print("Error creating table")
                } else {
                    print("Table creation/link successful.")
                }
                sqlite3_close(db)
                print("db connection closed")
            } else {
                print("Error opening database")
            }
        } else {
            if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
                let createTableQuery = """
                    CREATE TABLE IF NOT EXISTS chat_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        role TEXT,
                        message TEXT,
                        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                    );
                """
                print("Create table query created.")
                if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
                    print("Error creating table")
                } else {
                    print("Table creation/link successful.")
                }
                sqlite3_close(db)
                print("db connection closed")
            } else {
                print("Error opening database")
            }
        }
        
        // load subscription information
        sub = "289df82ad08e424cbd729c7dd332ddff"
        region = "canadacentral"
        
        // Load the selected language type
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en-US"
        print(selectedLanguage)
        if selectedLanguage == "en-US" {
            voiceName = "en-US-JennyNeural"
            chatPrompt = "Your name is Hope. You will be friendly, encourgaing, helpful. You will focus on the user's mental well-being. You will be used in an audio chatbot program, so please talk as if you are having a face-to-face conversation.\n"
        } else if selectedLanguage == "zh-CN" {
            voiceName = "zh-CN-XiaoxiaoNeural"
            chatPrompt = "你的名字是Hope。你会非常在意他人的心里感受，并且会站在别人的立场思考。你将会以最精辟的方式来回答。你将会被用于一个聊天机器人程序里，所以请用一种聊天的口吻与用户交流。"
        }
        let speechStyle = "chat"
        let speechPitch = "5%"
        let speechRate = "12%"
        print(selectedLanguage)
        print(String(voiceName ?? "en-US-JennyNeural"))
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
        
        // Recording Section Stuff
        recordingActivity.isHidden = true
        
        // Initiate token count
        tokenCounts = 0
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    // MARK: tableView()
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cell = msgTable.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        
        cell.messageLabel.text = message["content"] as? String
        cell.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Adjust color
        if message["role"] as? String == "user" {
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
//        let timestamp = Date().iso8601
        
        let message = [
            "role": sender,
            "content": contents
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
    func saveMessages() {
        do {
            // Save the `messages` into a file for session history - locally
            let data = try JSONSerialization.data(withJSONObject: messages)
            try data.write(to: chatHistoryURL)

            // Open database connection
            guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
                print("Error opening database connection, chat message won't be saved to db.")
                return
            }

            // Prepare the insert statement
            let insertQuery = "INSERT INTO chat_history (role, message) VALUES (?, ?);"
            var insertStatement: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Error preparing insert statement: \(errmsg)")
                sqlite3_close(db)
                return
            }

            // Bind parameters and execute the statement
            if let message = messages.last,
               let role = message["role"] as? NSString,
               let content = message["content"] as? NSString {
                sqlite3_bind_text(insertStatement, 1, role.utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 2, content.utf8String, -1, nil)
                if sqlite3_step(insertStatement) != SQLITE_DONE {
                    print("Error inserting row")
                }
                sqlite3_finalize(insertStatement)
                print("Most recent message inserted into chat_history table.")
            } else {
                print("Error: message array error.")
                sqlite3_finalize(insertStatement)
            }

            // Close database connection
            sqlite3_close(db)
            print("Messages saved to chatHistory.")
        } catch {
            print("Error while saving messages to chatHistory: \(error)")
        }
    }

    
    // MARK: Recording Button Clicked
        @IBAction func fromMicButtonClicked() {
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            feedbackGenerator.prepare()
            DispatchQueue.main.async {
                feedbackGenerator.impactOccurred(intensity: 1.0)
            }
           
            recordingActivity.isHidden = false
            recordingActivity.startAnimating()
            recordButton.isEnabled = false
            recordButton.isHidden = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.recognizeFromMic()
                DispatchQueue.main.async{
                    self.recordingActivity.stopAnimating()
                    self.recordingActivity.isHidden = true
//                    self.recordButton.isEnabled = true
//                    self.recordButton.isHidden = false
                }
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
        self.sendMessage(sender: "user", contents: result.text ?? "(no result)")
        print("User message sent.")

        // Call OpenAI API to generate Response
        self.getOpenAIResult(from: result.text ?? "") { response in
            if let response = response {
                print("OpenAI generated response: \(response)")
                self.sendMessage(sender: "assistant", contents: response)
                // Stop the recognizer after each recognition
                try? self.recognizer.stopContinuousRecognition()
            } else {
                print("Error generating response.")
                self.sendMessage(sender: "assistant", contents: "Error")
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
        let apiUrl = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        // Set the request headers
        var request = URLRequest(url: apiUrl)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Read the history and read {"User": "content", "Hope": "content"} into text files
        do {
            let historyData = try Data(contentsOf: chatHistoryURL)
            let history = try JSONSerialization.jsonObject(with: historyData, options: []) as! [[String: Any]]

            var historyArray: [[String: String]] = [[:]]
            for message in history {
                if let sender = message["role"] as? String, let content = message["content"] as? String {
                    historyArray.append(["role": sender, "content": content])
                }
            }
            self.history = historyArray.filter { !$0.isEmpty }
        } catch {
            print("Error loading chat history.")
        }
        
        // Set the request body - controll the length of historical input here
        if Int(self.tokenCounts ?? 1) > 3500 {
            self.history = Array(self.history.suffix(10))
            print("Current token count: \(Int(self.tokenCounts ?? 1))")
        } else {
            print("Current token count: \(Int(self.tokenCounts ?? 1))")
        }
        
        // Set the body for request
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo-0301",
            "messages": [
                ["role": "system", "content": self.chatPrompt],
            ] + self.history + [
                ["role": "user", "content": text]
            ],
            "temperature": 1,
            "max_tokens": 100,
            "user": "Jason Zhu"
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: requestBody, options: [])
        request.httpBody = jsonData
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        // Send the API request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                print(response ?? "meh")
                DispatchQueue.main.async() {
                    completion(nil)
                }
                return
            } else if let data = data {
                do {
                    print("Response received.")
                    print(response ?? "meh")
                    // Parse the response JSON
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    print(json)
                    if let usage = json?["usage"] as? [String: Int], let choices = json?["choices"] as? [[String: Any]], let message = choices[0]["message"] as? [String: Any], let text = message["content"] as? String {
                        response_text = text.replacingOccurrences(of: String("Hope: "), with: String(""))
//                        print(Int(usage["total_tokens"] ?? 0))
                        self.tokenCounts = Int(usage["total_tokens"] ?? 0)
                        // Pass the response to the completi0on handler
                        DispatchQueue.main.async() {
                            completion(response_text)
                        }
                        // Call textToSpeech
                        self.textToSpeech(inputText: response_text)
                    } else {
                        print("Error: response JSON did not contain expected data")
                        print("Response data: \(String(data: data, encoding: .utf8) ?? "")")
                        DispatchQueue.main.async() {
                            completion(nil)
                        }
                    }
                } catch let error {
                    print("Error parsing response JSON: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "")")
                    DispatchQueue.main.async() {
                        completion(nil)
                    }
                }
            }
        }
        print("Sending request to OpenAI API...")
        task.resume()
    }

    // Then, perform a text-to-speech
    func textToSpeech(inputText: String) {
//        DispatchQueue.main.async {
//            self.recordButton.isEnabled = false
//            self.recordButton.isHidden = true
//        }
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
        let inputSSML = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='https://www.w3.org/2001/mstts' xml:lang='\(self.selectedLanguage ?? "en-US")'> <voice name='\(self.voiceName ?? "en-US-JennyNeural")'> <mstts:express-as style='\(self.speechStyle ?? "affectionate")'> <prosody pitch='\(self.speechPitch ?? "5%")' rate='\(self.speechRate ?? "10%")'> \(inputText) </prosody> </mstts:express-as> </voice></speak>"
        print(inputSSML)
        let result = try! synthesizer.speakSsml(inputSSML)
        if result.reason == SPXResultReason.canceled
        {
            let cancellationDetails = try! SPXSpeechSynthesisCancellationDetails(fromCanceledSynthesisResult: result)
            print("Canceleled, error code: \(cancellationDetails.errorCode) detail: \(cancellationDetails.errorDetails!) ")
            return
        }
        DispatchQueue.main.async {
            self.recordButton.isEnabled = true
            self.recordButton.isHidden = false
        }
        // Shut down db connection after speech
        sqlite3_close(db)
        print("Database connection closed.")
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
