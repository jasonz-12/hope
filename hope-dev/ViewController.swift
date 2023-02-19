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

class ViewController: UIViewController {
    var label: UILabel!
    var chatGPTResponse: UILabel!
    var fromMicButton: UIButton!
    
    var sub: String!
    var region: String!
    var chatPrompt: String!
    
    var audioPlayer: AVAudioPlayer?
    
    @IBOutlet weak var recordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load subscription information
        sub = "289df82ad08e424cbd729c7dd332ddff"
        region = "canadacentral"
        chatPrompt = "Your name is Hope, you will talk and chat with the user, which is your friend. Whenever they ask a question, you will try my best to answer them kindly in English. You have an MBTI of INTJ."
        
        label = UILabel(frame: CGRect(x: 100, y: 100, width: 200, height: 200))
        label.textColor = UIColor.black
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.text = "Recognition Result"
        
        chatGPTResponse = UILabel(frame: CGRect(x: 100, y: 10, width: 200, height: 200))
        chatGPTResponse.textColor = UIColor.black
        chatGPTResponse.lineBreakMode = .byWordWrapping
        chatGPTResponse.numberOfLines = 0
        chatGPTResponse.text = "Response Contents"
        
        self.view.addSubview(label)
        self.view.addSubview(chatGPTResponse)
    }
    
    
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
        
        self.updateLabel(text: "Listening ...", color: .gray)
        print("Listening...")
        
        let result = try! reco.recognizeOnce()
        print("recognition result: \(result.text ?? "(no result)")")
        self.updateLabel(text: result.text, color: .black)
        
        // Call OpenAI API to generate Response
        self.getOpenAIResult(from: result.text ?? "") { response in
            if let response = response {
                print("OpenAI generated response: \(response)")
                self.updateResponse(text: response, color: .black)
            } else {
                print("Error generating response.")
                self.updateResponse(text: "Error", color: .blue)
            }
        }
    }
    
    // MARK: Update labels
    func updateLabel(text: String?, color: UIColor) {
        DispatchQueue.main.async {
            self.label.text = text
            self.label.textColor = color
        }
    }
        
    func updateResponse(text: String?, color: UIColor) {
        DispatchQueue.main.async {
            self.chatGPTResponse.text = text
            self.chatGPTResponse.textColor = color
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
        updateResponse(text: response_text, color: .black)
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

