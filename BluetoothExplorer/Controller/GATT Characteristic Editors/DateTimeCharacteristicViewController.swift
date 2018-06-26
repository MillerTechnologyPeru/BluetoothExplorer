//
//  DateTimeCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Bluetooth
import GATT

final class DateTimeCharacteristicViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) weak var dateTimeLabel: UILabel!
    
    @IBOutlet private(set) weak var datePicker: UIDatePicker!
    
    // MARK: - Properties
    
    var value = GATTDateTime(date: Date())
    
    var valueDidChange: ((GATTDateTime) -> ())?
    
    var minimumDate: Date? {
        
        var dateComponents = DateComponents()
        dateComponents.year = Int(GATTDateTime.Year.min.rawValue)
        dateComponents.timeZone = TimeZone(identifier: "UTC")
        
        return Calendar.current.date(from: dateComponents)
    }
    
    var maximumDate: Date? {
        
        var dateComponents = DateComponents()
        dateComponents.year = Int(GATTDateTime.Year.max.rawValue)
        dateComponents.timeZone = TimeZone(identifier: "UTC")
        
        return Calendar.current.date(from: dateComponents)
    }
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let minimumDate = minimumDate
            else { assertionFailure("Couldn't create minimumDate"); return }
        
        guard let maximumDate = maximumDate
            else { assertionFailure("Couldn't create maximumDate"); return }
        
        datePicker.minimumDate = minimumDate
        datePicker.maximumDate = maximumDate
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func datePickerChanged(_ sender: Any) {
        
        let strDate = CustomDateFormatter.default.string(from: datePicker.date)
        dateTimeLabel.text = strDate
        
        let dateComponents = Calendar.current.dateComponents(in: TimeZone(identifier: "UTC")!, from: datePicker.date)
        
        let datetime = GATTDateTime(dateComponents: dateComponents)
        
        guard let value = datetime
            else { assertionFailure("Couldn't create GATTDateTime from components"); return }
        
        self.value = value
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateDatePicker()
    }
    
    func updateDatePicker() {
        
        if let date = value.dateComponents.date {
            dateTimeLabel.text = CustomDateFormatter.default.string(from: date)
            datePicker.date = date
        }
    }
    
}

// MARK: - CharacteristicViewController

extension DateTimeCharacteristicViewController: CharacteristicViewController {
    
    static func fromStoryboard() -> DateTimeCharacteristicViewController {
        
        let storyboard = UIStoryboard(name: "DateTimeCharacteristic", bundle: .main)
        
        let viewController = storyboard.instantiateInitialViewController() as! DateTimeCharacteristicViewController
        
        return viewController
    }
}

extension DateTimeCharacteristicViewController {
    
    struct CustomDateFormatter {
        
        static let `default`: DateFormatter = {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
            return formatter
        }()
    }
}
