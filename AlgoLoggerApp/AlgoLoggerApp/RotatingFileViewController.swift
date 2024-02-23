//
//  ViewController.swift
//  AlgoLoggerApp
//
//  Created by Jaehong Yoo on 2023/02/23.
//

import UIKit
import RxSwift
import XCGLogger
import AlgoLogger

class RotatingFileViewController: UIViewController {

    @IBOutlet weak var logTableView: UITableView!
    
    private var logs = [URL]()
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        logTableView.estimatedRowHeight = 68.0
        logTableView.rowHeight = UITableView.automaticDimension
        
        logTableView.reloadData()
        
        if let rotatingFileDestination = LogManager.singleton.getLogger(TestTag).destination(withIdentifier: "RotatingFileDestination") as? RotatingFileDestination {
            rotatingFileDestination.getLogFileObservable()
                .debounce(RxTimeInterval.seconds(1), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                .map { url in
                    return rotatingFileDestination.archivedFileURLs()
                        .sorted { left, right in
                            left.absoluteString < right.absoluteString
                        }
                }
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] urls in
                    self?.logs = urls
                    self?.logTableView.reloadData()
                })
                .disposed(by: disposeBag)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        L.debug(TestTag, "destination:\(segue.destination), sender:\(String(describing: sender))")
        if let viewController = segue.destination as? LogViewController,
           let logURL = sender as? URL,
           let contents = try? String(contentsOf: logURL, encoding: .utf8) {
            viewController.setLog(log: contents)
        }
    }
    
    @IBAction func handleRotate(_ sender: Any) {
        if let rotatingFileDestination = LogManager.singleton.getLogger(TestTag).destination(withIdentifier: "RotatingFileDestination") as? RotatingFileDestination {
            rotatingFileDestination.rotateFile()
        }
    }
}

extension RotatingFileViewController : UITableViewDataSource, UITableViewDelegate {
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
