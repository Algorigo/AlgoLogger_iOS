//
//  LogTableViewCell.swift
//  AlgoLoggerApp
//
//  Created by Jaehong Yoo on 2023/03/06.
//

import UIKit

class LogTableViewCell: UITableViewCell {

    @IBOutlet weak var logFileLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setLogFile(file: URL) {
        logFileLabel.text = file.lastPathComponent
    }
    
}
