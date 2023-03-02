//
//  LaunchPage.swift
//  hope-dev
//
//  Created by Jason Zhu on 2023-02-23.
//

import Foundation
import UIKit

class LaunchViewController: UIViewController {
    
    @IBOutlet var languageSegmentedControl: UISegmentedControl!

    var selectedLanguage: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up segmented control
        languageSegmentedControl.addTarget(self, action: #selector(languageSelected), for: .valueChanged)
        view.addSubview(languageSegmentedControl)
        languageSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            languageSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            languageSegmentedControl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    @objc func languageSelected() {
        self.selectedLanguage = languageSegmentedControl.titleForSegment(at: languageSegmentedControl.selectedSegmentIndex)
        UserDefaults.standard.set(self.selectedLanguage, forKey: "selectedLanguage")
    }
}
