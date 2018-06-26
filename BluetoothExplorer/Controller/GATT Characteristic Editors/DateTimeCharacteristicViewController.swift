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

final class DateTimeCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) weak var dateTimeLabel: UILabel!
    
    @IBOutlet private(set) weak var datePicker: UIDatePicker!
    
    // MARK: - Properties
    
    var value = GATTDateTime(date: Date())
    
    var valueDidChange: ((GATTDateTime) -> ())?
    
    private lazy var minimumDate: Date = {
        
        var dateComponents = DateComponents()
        dateComponents.year = Int(GATTDateTime.Year.min.rawValue)
        dateComponents.timeZone = TimeZone(identifier: "UTC")
        
        guard let minimumDate = calendar.date(from: dateComponents)
            else { fatalError("Couldn't create minimumDate") }
        
        return minimumDate
    }()
    
    private lazy var maximumDate: Date = {
        
        var dateComponents = DateComponents()
        dateComponents.year = Int(GATTDateTime.Year.max.rawValue)
        dateComponents.timeZone = TimeZone(identifier: "UTC")
        
        guard let maximumDate = calendar.date(from: dateComponents)
            else { fatalError("Couldn't create maximumDate") }
        
        return maximumDate
    }()
    
    private lazy var calendar: Calendar = {
        
        return Calendar(identifier: .gregorian)
    }()
    
    private lazy var timeZone: TimeZone = {
        
        guard let timezone = TimeZone(identifier: "UTC")
            else { fatalError("Couldn't create timezone") }
        
        return timezone
    }()
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        datePicker.minimumDate = minimumDate
        datePicker.maximumDate = maximumDate
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func datePickerChanged(_ sender: Any) {
        
        let dateString = CustomDateFormatter.default.string(from: datePicker.date)
        dateTimeLabel.text = dateString
        
        self.value = GATTDateTime(date: datePicker.date)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateDatePicker()
    }
    
    func updateDatePicker() {
        
        guard let date = value.dateComponents.date
            else { return }
        
        dateTimeLabel.text = CustomDateFormatter.default.string(from: date)
        datePicker.date = date
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
