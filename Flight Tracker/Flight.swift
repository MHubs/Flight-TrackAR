import Foundation
import UIKit
import WebKit

class Flight: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(icao24)
    }
    
    static func == (lhs: Flight, rhs: Flight) -> Bool {
        return lhs.icao24 == rhs.icao24
    }
    
    var initialArray: [AnyObject?]!
    var icao24: String!
    var callsign: String!
    var airline: String!
    var flightNum: String!
    var origin: Airport!
    var destination: Airport!
    var timePosition: Int!
    var lastContact: Int!
    var lat: Double!
    var lon: Double!
    var altitude: Double? // meters
    var velocity: Double? // m/s
    
    
    init(data: [AnyObject?]) {
        
        if (data[1] != nil && (data[1] as! String).count > 3  && data[5] != nil && data[6] != nil) {
            
            
            
            initialArray = data
            icao24 = (data[0] as! String)
            callsign = (data[1] as! String).replacingOccurrences(of: " ", with: "")
            
            let start = String.Index(utf16Offset: 0, in: callsign)
            let end = String.Index(utf16Offset: 3, in: callsign)
            let substring = String(callsign[start..<end])
            airline = Files.airlines[substring]
            flightNum = String(callsign[end..<callsign!.endIndex])
            timePosition = (data[3] as! Int)
            lastContact = (data[4] as! Int)
            lon = (data[5] as! Double)
            lat = (data[6] as! Double)
            altitude = (data[13] as? Double)
            velocity = (data[9] as? Double)
            
            //loadAirports()
        }
    }
    
    
    
    
}
