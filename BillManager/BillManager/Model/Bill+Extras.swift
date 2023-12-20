//
//  Bill+Extras.swift
//  BillManager
//

import Foundation
import UserNotifications

extension Bill {
    var hasReminder: Bool {
        return (remindDate != nil)
    }
    
    var isPaid: Bool {
        return (paidDate != nil)
    }
    
    var formattedDueDate: String {
        let dateString: String
        
        if let dueDate = self.dueDate {
            dateString = dueDate.formatted(date: .numeric, time: .omitted)
        } else {
            dateString = ""
        }
        
        return dateString
    }
    
    static let notificationCategoryID = "reminderCategory"
    static var paidActionID = "paid"
    static var remindLaterID = "remindLater"
    
    mutating func unschedule() {
        if let notificationID = notificationID {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
            self.notificationID = nil
            remindDate = nil
        }
    }

    mutating func scheduleReminder(date: Date, completion: @escaping(Bill) -> ()) {
        unschedule()
        var updated = self
        updated.remindDate = date
        updated.notificationID = UUID().uuidString
        authorize { granted in
            guard granted else {
                DispatchQueue.main.async {
                    completion(updated)
                }
                return
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Bill Reminder"
        content.body = "\(updated.amount!) due on \(updated.formattedDueDate)"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = Bill.notificationCategoryID
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: updated.notificationID!, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { (error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    print(error)
                    completion(updated)
                } else {
                    completion(updated)
                }
            }
        }
    }
    
    private func authorize(completion: @escaping (Bool) -> ()) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { (settings) in
            switch settings.authorizationStatus {
            case .authorized:
                completion(true)
            case .notDetermined:
                notificationCenter.requestAuthorization(options: [.sound, .badge, .alert], completionHandler: { (granted, _) in
                    completion(granted)
                })
            case .denied, .provisional, .ephemeral:
                completion(false)
                
            default:
                completion(false)
            }
        }
    }
    
}
