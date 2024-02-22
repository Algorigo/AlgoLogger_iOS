//
//  ViewController.swift
//  AlgoLoggerApp
//
//  Created by Jaehong Yoo on 2023/02/23.
//

import UIKit
import XCGLogger
import AlgoLogger

class ViewController: UIViewController {

    @IBOutlet weak var logTableView: UITableView!
    
    private var logs = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        logTableView.estimatedRowHeight = 68.0
//        logTableView.rowHeight = UITableView.automaticDimension
        
        L.verbose(TestTag, "verbose")
        L.debug(TestTag, "debug")
        L.info(TestTag, "info")
        L.notice(TestTag, "notice")
        L.warning(TestTag, "warning")
        L.error(TestTag, "error")
        L.assert(TestTag, "assert")
        L.warning(TestTag.TestTag2, "TestTag.TestTag2")
        L.warning(TestTag.TestTag2.TestTag3, "TestTag.TestTag2.TestTag3")
        L.warning(TestTag.TestTag4, "TestTag.TestTag4")
//        logTableView.reloadData()
        
        do {
            throw NSError(domain: "test", code: 0, userInfo: nil)
        } catch {
            L.error(TestTag, "error", error: error, callStackSymbols: Thread.callStackSymbols)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("sender:\(sender)")
        L.debug(TestTag, "sender:\(sender)")
        if let viewController = segue.destination as? LogViewController,
           let logPath = sender as? String,
           let contents = try? String.init(contentsOfFile: logPath) {
            viewController.setLog(log: contents)
        }
    }
}

extension ViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: LogTableViewCell
        if let _cell = tableView.dequeueReusableCell(withIdentifier: "log_cell") as? LogTableViewCell {
            cell = _cell
        } else {
            cell = LogTableViewCell()
        }
        cell.setLogFile(file: logs[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "log_text_segue", sender: logs[indexPath.row])
    }
}
