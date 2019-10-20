import Foundation

class Files {
    
    static var airlines = [String:String]()
    
    static func loadAirlines() {
        
        // Determine the file name
        let filename = "airlines"
        
        if let filepath = Bundle.main.path(forResource: filename, ofType: "txt") {
            print("Loading from:", filepath)
            let contents = try! String(contentsOfFile: filepath)
            
            // Split the file into separate lines
            let lines = contents.components(separatedBy: "\n")
            
            // Iterate over each line and print the line
                        
            for line in lines {
                
                
                
                let splits = line.components(separatedBy: ",")
                
                if splits.count > 1 {
                    
                    let name = splits[0]
                    let id = splits[1].replacingOccurrences(of: " ", with: "")
                    
                                        
                    airlines[id] = name
                                    
                }
                
            }
        }
                
        // Read the contents of the specified file
        
    }
    
    static var airports = [String:Airport]()
    
    static func loadAirports() {
        
        
        // Determine the file name
        let filename = "airports"
        
        if let filepath = Bundle.main.path(forResource: filename, ofType: "txt") {
            print("Loading from:", filepath)
            let contents = try! String(contentsOfFile: filepath)
            
            // Split the file into separate lines
            let lines = contents.components(separatedBy: "\n")
            
            // Iterate over each line and print the line
            for line in lines {
                
                let splits = line.components(separatedBy: ",")
                
                if (splits.count > 6) {
                    
                    let id = splits[4]
                    
                    if (Float(splits[6]) != nil && Float(splits[7]) != nil) {
                                                
                        airports[id] = Airport(code: splits[4], name: splits[1], lat: Float(splits[6])!, lon: Float(splits[7])!)
                        
                    }
                }
            }
            
            print("Done!")
        }
    }
}
