//
//  LogViewController.swift
//  AlgoLoggerApp
//
//  Created by Jaehong Yoo on 2023/03/07.
//

import UIKit

class LogViewController: UIViewController {

    @IBOutlet weak var logTextView: UITextView!
    
    private var log: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        logTextView.text = log
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    func setLog(log: String) {
        self.log = log
    }
}
