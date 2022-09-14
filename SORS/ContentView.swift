//
//  ContentView.swift
//  SORS
//
//  Created by Ian McVay on 7/10/20.
//

import SwiftUI
import AVFoundation

// CLASSES

class RaceNumber: ObservableObject {
    let limit: Int
    @Published var value = ""
        
    init(limit: Int) {
        self.limit = limit
    }
}

class Time: ObservableObject {
    let limit: Int
    @Published var value = ""
        
    init(limit: Int) {
        self.limit = limit
    }
}

// STRUCTURES

struct Config: Codable  {
    // holds config data for exchange with other SORS instances
    var championship: Bool = false
    var raceType = 0
    var raceDate = ""
    var TTStartInterval = 30  // 30 sec start intervals
    var TTDist = 20.0  // Distance for Age Std TT
    var master: Bool = true
    var stage: Bool = false
    var numbStages = 2
    var stages:[Stage]  = [Stage(), Stage()]   // min of two stages
    var currentStage = 0   // 0 based array
    var hcpScratch: Bool = false   // true for fastest grade being set at 0:00 else slowest grade has 0:00
}

struct Rider: Codable {
    var id: String = ""
    var racenumber: String = ""
    var name: String = ""
    var givenName: String = ""
    var surname: String = ""
    var gender: String = ""
    var dateofbirth: String = ""
    var age = 0
//    var corider = ""  // racenumber of the co-rider on a tandem
    var racegrade: String = ""
    var subgrade: String = ""
    var place: String = ""
    var ttOffset: Double = 0.0 // offset from 1st start time for a TT start
    var startTime: Date? = nil //Double = 0.0  // start time for TTs and Graded
    var finishTime: Date? = nil // Double = 0.0   // time over the line in Hcp & TT races
    var raceTime: Double = 0.0     // time over the line adjusted by Secret Hcp or Start time
    var adjustedTime: Double = 0.0     // race time adjusted by age standard
    var displayTime = ""   // formated finishtime
    var overTheLine = ""   // place over the line in Hcp & TT races
    var stageResults: [StageResult] = [StageResult()]
}

struct StageResult: Codable  {
    var place: String = ""
    var startTime: Date? = nil //Double = 0.0  // start time for TTs and Graded
    var finishTime: Date? = nil //Double = 0.0   // time over the line in Hcp & TT races
    var raceTime: Double = 0.0     // time over the line adjusted by Secret Hcp or Start time
    var overTheLine = ""   // place over the line in Hcp & TT races
    var displayTime = ""   // formated finishtime
}

struct StageBonus: Codable  {
    var id: String = ""
    var racenumber: String = ""
    var raceGrade: Int = 0
    var stage: Int = 0
    var type: Int = 0  //  prime or sprint
    var bonus: Int = 0   // in sec
    var prime: Int = 0   //  prime number
}

struct Stage: Codable  {
    var numbPrimes: Int = 0
    var type: Int = 0
}

struct StartedGrade: Codable  {
    var racegrade: String = ""
    var startTime: Date? = nil   // set when the start button is pressed
}

struct FinishTime: Codable, Identifiable {
    var id: UUID = UUID()
    var time: Date? = nil //Double = 0.0
    var displayTime = ""   // formatted overtheline and time
    var overTheLine = 0
    var allocated = false  // has this finish time been allocated to a rider
}

struct Handicap: Codable  {
    var racegrade: String = ""
    var time: Int = 0  // seconds
}

// VARIABLES

let rms = "https://rms.actvets.cc"  // URL to make web service calls to
// These values are used by RMS
let directorGrade = "REFEREE"
let marshalGrade = "MARSHAL"
let genders = ["M","F"]
let grades = ["A","B","C","D","E","F","G"]
let subgrades = ["-","1","2"]  // set no subgrade to '-' so options are visible in the picker
let raceTypes = ["Graded", "TT", "Crit", "Hcp", "Secret", "Age", "Age Std", "Wheel"]  // code actions use these raceTypes values.  1st 2 used for stage races
let unknownGrade = 999
let buttonSound = 1057

let bonusTypes = ["Sprint","Prime"]    // bonus to be applied to a stage type

var myConfig: Config = Config() {      // config for system
    didSet {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(myConfig) {
                UserDefaults.standard.set(encoded, forKey: "myConfig")
            }
        }
    }

let fullListHeight = 465.0
let handicapsListHeight = 560.0
let keypadHeight = 240.0
let listPad = CGFloat(15.0)
var msg = "---"                    // displayed on the main navigation page

let dateformatter = DateFormatter()


var reset = false                  // reset for next race/stage
//var stopDisabled = true
var startDisabled = false          // start button on timing view status
var recordDisabled = false         // record button on timing view status
//var lockedState = true
var timingStopped = true
var raceStarted = false
var tandem = false
var handicapsOK = false
var running = false {
    didSet {
        UserDefaults.standard.set(running, forKey: "running")
    }
}

var arrayRiders = [[String: Any]]() // list of riders loaded from RMS
var arrayNames: [String] = []       // list of rider names
var arrayRaces = [[String: Any]]()  // list of race dates
var unplacedRiders: [String] = []   // list of race numbers of riders yet to be placed
//var unplacedSpots: [String] = []    // list of recorded finish times yet to be assigned against a rider
var startingGrades: [String] = []   // list of grades with riders in them
var missingHandicaps = ""           // used for error message
var bonuses: [StageBonus] = []

var peripheralName = "" {            // name that appears on list of SORS devices for pairing
    didSet {
        UserDefaults.standard.set(peripheralName, forKey: "peripheralName")
    }
}

var arrayStarters = [Rider]() {      // list of registered riders
didSet {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(arrayStarters) {
            UserDefaults.standard.set(encoded, forKey: "Starters")
        }
    }
}

var handicaps = [Handicap]() {      // list of configured handicaps
didSet {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(handicaps) {
            UserDefaults.standard.set(encoded, forKey: "handicaps")
        }
    }
}
var startingHandicaps: [Handicap] = []   // handicaps for grades that have starters
var orderedHandicaps: [Handicap] = []   // handicaps in starting order slowest grade first

var unstartedGrades = [String]() {  // list of grades yet to start
didSet {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(unstartedGrades) {
            UserDefaults.standard.set(encoded, forKey: "unstartedGrades")
        }
    }
}

var startedGrades = [StartedGrade]() {   // list of grades that have started
didSet {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(startedGrades) {
            UserDefaults.standard.set(encoded, forKey: "startedGrades")
        }
    }
}
let defaults = UserDefaults.standard

var finishTimes = [FinishTime]() {  // recorded finishing times
didSet {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(finishTimes) {
            UserDefaults.standard.set(encoded, forKey: "finishTimes")
        }
    }
}

// EXTENSIONS

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// FUNCTIONS

func unplacedTimes() -> Int {
    var count = 0
    for time in finishTimes {
        if !time.allocated {
            count = count + 1
        }
    }
    return count
}

func gradeIndex(grade: String) -> Int {
    // return the arrary index for a given grade
    for (index, item) in grades.enumerated() {
        if item == grade {
            return index
        }
        
    }
    return -1 // grade not found
}

func secAsTime(_ time: Int) -> String{
    // Show seconds as int as formatted string
    let min = time/60
    let sec = time - min * 60
    return String(min) + ":" + String(format: "%02u", sec)
}

func doubleAsTime(_ time: Double) -> String {
    var negative = false
    var newTime = time
    // Show seconds as double as formatted string
    if time < 0 {
        negative = true
        newTime = abs(time)
    }
    var hours = newTime/3600
    hours.round(.towardZero)
    var minutes = (newTime - hours*3600)/60
    minutes.round(.towardZero)
    let seconds = newTime - hours * 3600 - minutes * 60
    
    if negative {
        return "-" + String(format: "%02.0f", hours) + ":" +
        String(format: "%02.0f", minutes) + ":" +
        String(format: "%04.1f", seconds)
    } else {
        return String(format: "%02.0f", hours) + ":" +
        String(format: "%02.0f", minutes) + ":" +
        String(format: "%04.1f", seconds)
    }
}

func dateAsTime(_ date: Date) -> String{
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let min = calendar.component(.minute, from: date)
    let sec = calendar.component(.second, from: date)
    return String(hour) + ":" + String(min) + ":" + String(format: "%02u", sec)
}

func resetRiders() {
    // resets the riders list for a race reset
    for rider in arrayStarters.indices {
        arrayStarters[rider].place = ""
        arrayStarters[rider].ttOffset = 0.0
        arrayStarters[rider].startTime = nil
        arrayStarters[rider].finishTime = nil
        arrayStarters[rider].raceTime = 0.0
        arrayStarters[rider].adjustedTime = 0.0
        arrayStarters[rider].displayTime = ""
        arrayStarters[rider].overTheLine = ""
        arrayStarters[rider].stageResults = [StageResult()]
    }
}

func riderCount() -> Int {
    var count = 0
    for rider in arrayStarters.indices {
        if arrayStarters[rider].racegrade != marshalGrade && arrayStarters[rider].racegrade != directorGrade {
            count =  count + 1
        }
    }
    return count
}

func officalCount() -> Int {
    var count = 0
    for rider in arrayStarters.indices {
        if arrayStarters[rider].racegrade == marshalGrade || arrayStarters[rider].racegrade == directorGrade {
            count =  count + 1
        }
    }
    return count
}

func getUnplaced(grade: Int = -1)  {
    // gets the started riders who are yet to be placed in the results
    unplacedRiders = []
    for rider in arrayStarters.indices {
        if grade < 0 {
            // All grades
            if myConfig.stage {
                if arrayStarters[rider].stageResults[myConfig.currentStage].place == "" && arrayStarters[rider].stageResults[myConfig.currentStage].overTheLine == "" &&
                    arrayStarters[rider].racegrade != directorGrade &&
                    arrayStarters[rider].racegrade != marshalGrade {
                        // Check that the rider has a start time
                        if (raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std") {
                            if arrayStarters[rider].stageResults[myConfig.currentStage].startTime != nil {
                                unplacedRiders.append(arrayStarters[rider].racenumber)
                            }
                        } else {
                            unplacedRiders.append(arrayStarters[rider].racenumber)
                        }
                }
            } else {
                if arrayStarters[rider].place == "" &&
                    arrayStarters[rider].overTheLine == "" &&
                    arrayStarters[rider].racegrade != directorGrade &&
                    arrayStarters[rider].racegrade != marshalGrade {
                        // Check that the rider has a start time - not paired master
                        if !masterPaired && (raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std") {
                            if arrayStarters[rider].startTime != nil {
                                unplacedRiders.append(arrayStarters[rider].racenumber)
                            }
                        } else {
                            unplacedRiders.append(arrayStarters[rider].racenumber)
                        }
                }
            }
        } else if startingGrades.count > 0 {
            // selected Grade
            if myConfig.stage {
                if arrayStarters[rider].stageResults[myConfig.currentStage].place == "" &&
                    arrayStarters[rider].racegrade == startingGrades[grade] {
                        // Check that the rider has a start time
                        if (raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std") {
                            if arrayStarters[rider].stageResults[myConfig.currentStage].startTime != nil {
                                unplacedRiders.append(arrayStarters[rider].racenumber)
                            }
                        } else {
                            unplacedRiders.append(arrayStarters[rider].racenumber)
                        }
                }
            } else {
                // not a stage race
                if arrayStarters[rider].place == "" &&
                    arrayStarters[rider].racegrade == startingGrades[grade] {
                    // Check that the rider has a start time
                        if (raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std") {
                             if arrayStarters[rider].startTime != nil {
                                unplacedRiders.append(arrayStarters[rider].racenumber)
                             }
                        } else {
                            unplacedRiders.append(arrayStarters[rider].racenumber)
                        }
                }
            }
        }
    }
    unplacedRiders.sort {$0.localizedStandardCompare($1) == .orderedAscending}  //  sorts string numbers
}

func getRiders(grade: Int = 0) -> [String] {
    // gets the started riders in selected grade
    var riders:[String] = []
    for rider in arrayStarters.indices {
        if arrayStarters[rider].racegrade == startingGrades[grade] {
            riders.append(arrayStarters[rider].racenumber)
        }
    }
    riders.sort {$0.localizedStandardCompare($1) == .orderedAscending}  //  sorts string numbers
    return riders
}

func initStageResults() {
    // ensure the rider list has enought stageResults
    if arrayStarters.count > 0 {
        for i in 0...(arrayStarters.count - 1) {
            while arrayStarters[i].stageResults.count < myConfig.numbStages {
                arrayStarters[i].stageResults.append(StageResult())
            }
        }
    }
}

func gradeIndex(grd: String) -> Int {
    // gets the index in the array of grades for the specified grade
    for i in 0...(grades.count - 1) {
        if grades[i] == grd {
            return i
        }
    }
    return unknownGrade
}

func setStartTime(id: String) {
    if arrayStarters.count  > 0 {
        for i in 0...(arrayStarters.count - 1) {
            if arrayStarters[i].id == id {
                arrayStarters[i].startTime = Date()
            }
        }
    }
}

func getDocumentsDirectory() -> URL {
    // find all possible documents directories for this user
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

    // just send back the first one, which ought to be the only one
    return paths[0]
}

func loadRiders() {
    // load the riders from file
    let url = getDocumentsDirectory().appendingPathComponent("riders.txt")
    do {
        let riders = try Data(contentsOf: url)
        let JSON = try! JSONSerialization.jsonObject(with: riders, options: [])
        arrayRiders = JSON as! [[String: Any]]
        msg = String(arrayRiders.count) + " Riders loaded from RMS."
    } catch {
//        print(error.localizedDescription)
        msg = "No riders loaded from RMS."
    }
}

func loadNames() {
    // load riders names into a sorted array
    for item in arrayRiders {
        arrayNames.append(item["name"] as? String ?? "")
        arrayNames.sort()
    }
}

func loadRaces() {
    // load the recent and near future races from RMS - need past races in case we are doing results post race
    let url = URL(string: rms + "/?closeEvents")!

    let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
        guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                //result = response
                //self.handleServerError(response)
                return
            }
        guard let data = data else {
//            result = "no races"
            return
        }
//        writeRaces(races: data)
        let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
        arrayRaces = JSON as! [[String: Any]]
    }
    task.resume()
}

func setStartingGrades() {
    // Find the grades with registered riders
    startingGrades = []
    for starter in arrayStarters {
        if starter.racegrade != directorGrade && starter.racegrade != marshalGrade {
            if raceTypes[myConfig.raceType] == "Age" || (raceTypes[myConfig.raceType] == "Crit" && myConfig.championship) {
                var gradeFound = false
//                let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
//                let yob = Int((starter.dateofbirth).prefix(4)) ?? 0
//                let age = (now.year ?? 0) - yob
                // get the age class

                for startingGrade in startingGrades {
                    if startingGrade ==  starter.racegrade {
                        gradeFound = true
                        break
                    }
                }
                if !gradeFound {
                    startingGrades.append(starter.racegrade)
                }
            } else {
                var gradeFound = false
                for startingGrade in startingGrades {
                    if startingGrade ==  starter.racegrade {
                        gradeFound = true
                        break
                    }
                }
                if !gradeFound {
                    startingGrades.append(starter.racegrade)
                }
            }
        }
    }
    startingGrades.sort()
}

func writeRiders(riders: Data) {
    // write the riders to file
    let url = getDocumentsDirectory().appendingPathComponent("riders.txt")
    do {
        try riders.write(to: url) //, atomically: true, encoding: .utf8)
        msg = "Riders written to storage file"
    } catch {
        msg = "Riders not written to storage file: " + error.localizedDescription
    }
}

func handicapForGrade(grade: String) -> String {
    // get the handicap allocated to a specific grade
    for handicap in handicaps {
        if grade == handicap.racegrade {
            return secAsTime(handicap.time)
        }
    }
    return ""
}

func handicapSecForGrade(grade: String) -> Int {
    // get the handicap allocated to a specific grade
    for handicap in handicaps {
        if grade == handicap.racegrade {
            return handicap.time
        }
    }
    return 0
}

func adjustGrades() {
    // check the handicaps and if subgrades are use, split the grade, else recombine.
    for item in handicaps {
        if item.racegrade.count == 1 {
            // no subgrades
            for rider in arrayStarters.indices {
                if arrayStarters[rider].racegrade.prefix(1) == item.racegrade {
                    arrayStarters[rider].racegrade = item.racegrade
                }
            }
        } else {
            // grade uses subgrades
            for rider in arrayStarters.indices {
                if arrayStarters[rider].racegrade.prefix(1) == item.racegrade.prefix(1) {
                    arrayStarters[rider].racegrade = item.racegrade.prefix(1) + arrayStarters[rider].subgrade
                }
            }
            
        }
    }
    setStartingGrades()
}

func sortHandicapsByGrd(asc: Bool) -> [Handicap] {
    // sort the hcps based on grade, asc [A, B, C ...] or desc  [D2, D1, C ...]
    return handicaps.sorted {
        if asc {
            if $0.racegrade.prefix(1) == $1.racegrade.prefix(1) {
                if $0.racegrade.suffix(1) == "1" {
                    return true
                } else {
                    return false
                }
            }
            return gradeIndex(grade: String($0.racegrade.prefix(1))) < gradeIndex(grade: String($1.racegrade.prefix(1)))
        } else {
            if $0.racegrade.prefix(1) == $1.racegrade.prefix(1) {
                if $0.racegrade.suffix(1) == "2" {
                    return true
                } else {
                    return false
                }
            }
            return gradeIndex(grade: String($0.racegrade.prefix(1))) > gradeIndex(grade: String($1.racegrade.prefix(1)))
        }
    }
}

func switchHandicaps(order: Bool) -> [Handicap] {
    // change the handicaps
    var newHandicaps = sortHandicapsByGrd(asc: !order)  // make sure handicaps are in the 'correct' starting order
    let sortedHandicaps = newHandicaps
    var newHandicapsPtr = 0
    
    if sortedHandicaps.count > 1 {
        for item in sortedHandicaps {
            // fastest grade being set at lowest time
            if newHandicapsPtr == 0 {
                // set the first to be the last
                newHandicaps[newHandicapsPtr].time = sortedHandicaps[sortedHandicaps.count - 1].time
            } else {
                if newHandicapsPtr == sortedHandicaps.count - 1 {
                    // set the last to be the 1st
                    newHandicaps[newHandicapsPtr].time = sortedHandicaps[0].time
                } else {
                    newHandicaps[newHandicapsPtr].time = sortedHandicaps[sortedHandicaps.count - 1].time - (item.time - sortedHandicaps[0].time)
                }
            }
            newHandicapsPtr = newHandicapsPtr + 1
        }
    }
   
    return newHandicaps
}

func checkHandicaps() {
    // check that the configured handicaps are ok for race start
    handicapsOK = true
    var comma = ""
    var missing : [String] = []
    missingHandicaps = ""
    startingHandicaps = []
    orderedHandicaps = []
    
    adjustGrades()
    
    if myConfig.hcpScratch {
        // handicaps are set at fastest grade starting at lowest time
        // this needs to be reversed to start the slowest grades first
        orderedHandicaps = switchHandicaps(order: false)
    } else {
        orderedHandicaps = handicaps
    }
    for rider in arrayStarters {
        if rider.racegrade != directorGrade && rider.racegrade != marshalGrade {
            var handicapFound = false
            for handicap in orderedHandicaps {
                if rider.racegrade == handicap.racegrade {
                    var alreadyFound = false
                    for startHandicap in startingHandicaps {
                        if startHandicap.racegrade == handicap.racegrade {
                            alreadyFound = true
                            break
                        }
                    }
                    if !alreadyFound {
                        startingHandicaps.append(handicap)
                    }
                    handicapFound = true
                    break
                }
            }
            if !handicapFound {
                // a rider is missing a handicap
                if missing.count > 0 {
                    var alreadyFound = false
                    for i in 0...(missing.count - 1) {
                        if missing[i] == rider.racegrade {
                            alreadyFound = true
                            break
                        }
                    }
                    if !alreadyFound {
                        missing.append(rider.racegrade)
                    }
                } else {
                    missing.append(rider.racegrade)
                }
                handicapsOK = false
            }
        }
    }
    // configure the missing handicaps text
    if !handicapsOK {
        for i in 0...(missing.count - 1) {
            missingHandicaps = missing[i] + comma + missingHandicaps
            comma = ","
        }
    } else {
        startingHandicaps = startingHandicaps.sorted {
            return $0.time < $1.time
        }
    }
}

func setRaceDate() -> Int{
    // used to set the date picker to the current race date
    if arrayRaces.count == 0 {
        return 0
    }
    for i in 0...(arrayRaces.count - 1) {
        if myConfig.raceDate == arrayRaces[i]["displaydate"] as! String {
            return i
        }
    }
    return 0
}

func DNFcount() -> Int{
    var count = 0
    for rider in arrayStarters {
        if rider.place == "DNF" {
            count = count + 1
        }
    }
    return count
}

func setStageResults() -> [Rider] {
    var starters = arrayStarters
    if starters.count > 0 {
        // add up the times from the stages and bonuses
        for i in 0...(starters.count - 1) {
            for result in starters[i].stageResults {
                if result.place == "DNF" {
                    starters[i].place = "DNF"
                }
                starters[i].raceTime = starters[i].raceTime + result.raceTime
            }
            for bonus in bonuses {
                if bonus.racenumber == starters[i].racenumber {
                    starters[i].raceTime = starters[i].raceTime - Double(bonus.bonus)
                }
            }
        }
        // set the places
        for startingGrade in startingGrades {
            var place = 1
            for i in 0...(starters.count - 1) {
                if starters[i].raceTime > 0.0 && starters[i].racegrade == startingGrade && starters[i].place != "DNF" {
                    starters[i].place = String(place)
                    place = place + 1
                }
            }
        }
        
        starters.sort {
            if $0.racegrade == $1.racegrade {
                return $0.place < $1.place
            }
            return $0.racegrade < $1.racegrade
        }
    }
    return starters
}



struct ContentView: View {
    @State var showMenu = false
    @State var selectedView = "Main"
    @StateObject var stopWatchManager = StopWatchManager()
    @State var dragEnable = true
    
    struct Background<Content: View>: View {
        private var content: Content

        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content()
        }

        var body: some View {
            Color.white
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .overlay(content)
        }
    }
    
    func hideMenu() {
        showMenu = false
    }
    
    struct SettingsView: View {
        @State var result = ""
        @State var TTStartIntervalString = String(myConfig.TTStartInterval)
        @ObservedObject var bleManager = BLEManager()
        @ObservedObject var blePeripheral = BLEPeripheral()
        @State var scanText = ""
        @State var pName = ""
        
        @State private var master = true
//        let master = Binding<Bool>(
//            get:{myConfig.master},
//            set:{myConfig.master = $0}
//        )
        
        func checkNumb(_ value: String) {
            let filtered = TTStartIntervalString.filter { $0.isNumber}
            if TTStartIntervalString != filtered {
                TTStartIntervalString = filtered
            }
            myConfig.TTStartInterval = Int(TTStartIntervalString) ?? 30
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        var body: some View {
            Background {
            VStack {
                Toggle(isOn: $master) {
                    Text("Timer")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(width:130, alignment: .center)
                
                if master {
                if bleManager.isSwitchedOn {
                    Text("Bluetooth is switched on")
                    .foregroundColor(.green)
                }
                else {
                    Text("Bluetooth is NOT switched on")
                    .foregroundColor(.red)
                }
                List(bleManager.peripherals) { peripheral in
                    HStack {
                        Text(peripheral.name)
                        Spacer()
//                        Text(String(peripheral.rssi))
//                        Spacer()
                        
                        if self.bleManager.connected && peripheral.connected {
                            // Disconnect Button
                            Button(action: {
                                self.bleManager.disconnect(target: peripheral.name)
                            } ) {
                                Text("Disconnect")
                                .padding()
                                .foregroundColor(.black)
                            }
                            .frame(width: 110, height: 50, alignment: .leading)
                            .background(Color.yellow)
                            .cornerRadius(10)
                            .buttonStyle(PlainButtonStyle())
                            
                            // Sync Button
                            Button(action: {
                                scanText = "Syncing..."
                                self.bleManager.sync(target: peripheral.name)
                            } ) {
                                Text("Sync")
                                .padding()
                                .foregroundColor(.black)
                            }
                            .frame(width: 90, height: 50, alignment: .leading)
                            .background(Color.green)
                            .cornerRadius(10)
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // Connect Button
                            Button(action: {
                                self.bleManager.connect(target: peripheral.name)
                                if self.bleManager.connected {
                                    scanText = self.bleManager.status
                                } else {
                                    scanText = self.bleManager.connectionErrorTxt
                                }
                            } ) {
                                Text("Connect")
                                .padding()
                                .foregroundColor(.black)
                            }
                            .disabled(self.bleManager.connected)
                            .frame(width: 100, height: 50, alignment: .leading)
                            .background(self.bleManager.connected ? Color.gray : Color.green)
                            .cornerRadius(10)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(width:400, height: 200)
                
                HStack {
                    Button(action: {
                        self.bleManager.startScanning()
                        scanText = "Scanning..."
                    } ) {
                        Text("Start Scan")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .disabled(!bleManager.isSwitchedOn || self.bleManager.scanning)
                    .frame(width: 112, height: 50, alignment: .leading)
                    .background(!bleManager.isSwitchedOn || self.bleManager.scanning ? Color.gray : Color.green)
                    .cornerRadius(10)
                    Text("  ")  // spacer
                
                    Button(action: {
                        self.bleManager.stopScanning()
                        scanText = ""
                    } ) {
                        Text("Stop Scan")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .disabled(!self.bleManager.scanning)
                    .frame(width: 112, height: 50, alignment: .leading)
                    .background(self.bleManager.scanning ? Color.red : Color.gray)
                    .cornerRadius(10)
                    Text("  ")   // spacer
                    
                    Button(action: {
                        self.bleManager.clear()
                        scanText = ""
                    } ) {
                        Text("Clear")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .frame(width: 80, height: 50, alignment: .leading)
                    .background(Color.yellow)
                    .cornerRadius(10)
                }
                    Text(scanText + " " + self.bleManager.status)
                } else {
                    // is peripheral
                    HStack {
                        Text("Device Name: ")
                        // TODO update peripheralName on change
                        TextField("name", text: $pName, onEditingChanged: {
                            if $0 {peripheralName = pName}
                        })
                        .frame(width: 120.0)
                        .padding()
                    }
                    // slave - start stop advertising service
                    if blePeripheral.isSwitchedOn {
                        Text("Bluetooth is switched on")
                            .foregroundColor(.green)
                    }
                    else {
                        Text("Bluetooth is NOT switched on")
                            .foregroundColor(.red)
                    }
                    HStack {
                        Button(action: {
                            self.blePeripheral.startAdvertising()
                            scanText = "Advertising..."
                        } ) {
                            Text("Start Ad")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .disabled(!bleManager.isSwitchedOn || self.blePeripheral.advertising)
                        .frame(width:100, height: 50, alignment: .leading)
                        .background(!bleManager.isSwitchedOn || self.blePeripheral.advertising ? Color.gray : Color.green)
                        .cornerRadius(10)
                        Text("    ")
                    
                        Button(action: {
                            self.blePeripheral.stopAdvertising()
                            scanText = ""
                        } ) {
                            Text("Stop Ad")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .disabled(!self.blePeripheral.advertising)
                        .frame(width: 100, height: 50, alignment: .leading)
                        .background(self.blePeripheral.advertising ? Color.red : Color.gray)
                        .cornerRadius(10)
                    }
                    Text(self.blePeripheral.status)
                }
                HStack {
                    Text("TT Starts (sec): ")
                    TextField("000", text: $TTStartIntervalString)
                    //.font(Font.system(size: 60, design: .default))
                    .frame(width: 50.0)
                    .keyboardType(.numberPad)
                    .onChange(of: TTStartIntervalString, perform: checkNumb)
                    .padding()
                    .foregroundColor(Color.blue)
                }
                HStack {
                // Reset button
                Button(action: {
                    // Reset things required for a new race
                    unplacedRiders = []
                    startedGrades = []
                    finishTimes = []
                    reset = true
                    running = false
                    raceStarted = false
                    recordDisabled = true
                    resetRiders()
                    handicaps = []
                    
                    // Reset everything for testing
//                    myConfig.raceType = 0
//                    myConfig.championship = false
//                    myConfig.numbStages = 2
//                    myConfig.TTDist = 20.0
//                    myConfig.TTStartInterval = 30
//                    myConfig.currentStage = 0
//                    TTStartIntervalString = String(myConfig.TTStartInterval)
//                    myConfig.stage = false
//                    arrayStarters = []
//                    startingGrades = []
//                    handicaps = []
//                    peripheralPaired = false
//                    masterPaired = false
                    
//                    unplacedSpots = []
//                    lockedState = true
                    
                    // set up for test run - TODO disable this in production
//                    myConfig.raceType = 4 // 4 = Age
//                    handicaps = [Handicap(racegrade: "G", time: 0),Handicap(racegrade: "F", time: 10),Handicap(racegrade: "E", time: 20),Handicap(racegrade: "D", time: 30),Handicap(racegrade: "C", time: 40),Handicap(racegrade: "B", time: 50),Handicap(racegrade: "A", time: 60)]
//                    if raceTypes[myConfig.raceType] == "Age" {
//                        arrayStarters = [Rider(id: "1", racenumber: "4", name: "Fred", givenName: "", surname: "", gender: "M", dateofbirth: "", age: 33, racegrade: "M1", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: ""), Rider(id: "2", racenumber: "40", name: "Max", givenName: "", surname: "", gender: "M", dateofbirth: "", age: 43, racegrade: "M3", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: ""), Rider(id: "3", racenumber: "402", name: "June", givenName: "", surname: "", gender: "F", dateofbirth: "", age: 73, racegrade: "F9", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: "")
//                             , Rider(id: "4", racenumber: "567", name: "Geo", givenName: "", surname: "", gender: "F", dateofbirth: "", age: 34, racegrade: "REFEREE", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: "")
//                             , Rider(id: "5", racenumber: "568", name: "Xeo", givenName: "", surname: "", gender: "M", dateofbirth: "", age: 37, racegrade: "MARSHAL", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: "")
//                        ]
//                    } else {
//                    arrayStarters = [Rider(id: "1", racenumber: "4", name: "Fred", givenName: "", surname: "", gender: "M", dateofbirth: "", age: 33, racegrade: "A", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: ""), Rider(id: "2", racenumber: "40", name: "Max", givenName: "", surname: "", gender: "M", dateofbirth: "", age: 43, racegrade: "B", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: ""), Rider(id: "3", racenumber: "402", name: "June", givenName: "", surname: "", gender: "F", dateofbirth: "", age: 73, racegrade: "C", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: "")
//                         , Rider(id: "4", racenumber: "567", name: "Geo", givenName: "", surname: "", gender: "F", dateofbirth: "", age: 34, racegrade: "REFEREE", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: "")
//                         , Rider(id: "5", racenumber: "568", name: "Xeo", givenName: "", surname: "", gender: "M", dateofbirth: "", age: 37, racegrade: "MARSHAL", place: "", finishTime: 0.0, displayTime: "", overTheLine: "", corider: "")
//                    ]
//                    }
//                    unplacedRiders = ["4","40","402"]
                    
                    checkHandicaps()
                    setStartingGrades()
                    result = "Reset done"
                }) {
                    Text("Reset")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .frame(width: 100, height: 50, alignment: .leading)
                    .background(Color.red)
                    .cornerRadius(10)
                    
                    Text("    ")  // spacer
                    
                    // Restart button
                    Button(action: {
                        // Reset things required to restart the race
                        startedGrades = []
                        finishTimes = []
                        running = false
                        raceStarted = false
                        recordDisabled = true
                        resetRiders()
                        
                        setStartingGrades()
                        result = "Ready to restart"
                    }) {
                        Text("Restart")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .frame(width: 100, height: 50, alignment: .leading)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                    
                Text(result)
//                Spacer()
                .navigationBarTitle("Settings", displayMode: .inline)
            }
            .onAppear(perform: {
                master = myConfig.master
                pName = peripheralName
            })
            .onDisappear(perform: {
                myConfig.master = master
                peripheralName = pName
            })
            }.onTapGesture {
                self.endEditing()
            }
        }
    
    }
    
    struct LoadView: View {
        @State var result = ""
        @State private var selectedRace = 0
        @State var selectedRaceType = 0  // needs to be a state variable for the selector
        
        @State var TTDistString = String(myConfig.TTDist)
        
        @State var selectedStage = 0  // needs to be a state variable for the selector
        @State var stages: [Stage] = [Stage(), Stage()]  // min of two stages
        @State var numbStagesTxt = String(myConfig.numbStages)
        @State var numbStages = myConfig.numbStages
        @State var numbPrimesTxt = "0"
        @State var numbPrimes = 0
        @State var currentStageTxt = "1"
        @State var currentStage = 0
        @State var stage = false
        
        let bind = Binding<Bool>(
            get:{myConfig.championship},
            set:{myConfig.championship = $0}
        )
        
        func checkNumb(_ value: String) {
            let filtered = TTDistString.filter { $0.isNumber || $0 == "."}
            if TTDistString != filtered {
                TTDistString = filtered
            }
            myConfig.TTDist = Double(TTDistString) ?? 20.0
        }
        
        func checkNumbPrimes(_ value: String) {
            numbPrimesTxt = String(numbPrimesTxt.prefix(1))
            let filtered = numbPrimesTxt.filter { $0.isNumber }
            if numbPrimesTxt != filtered {
                numbPrimesTxt = filtered
            }
            numbPrimes = (Int(numbPrimesTxt) ?? 2)
            self.stages[selectedStage].numbPrimes = numbPrimes
            myConfig.stages = self.stages
        }
        
        
        func checkNumbStages(_ value: String) {
            numbStagesTxt = String(numbStagesTxt.prefix(1))
            let filtered = numbStagesTxt.filter { $0.isNumber }
            if numbStagesTxt != filtered {
                numbStagesTxt = filtered
            }
            numbStages = max((Int(numbStagesTxt) ?? 2), 2)
//            numbStagesTxt = String(numbStages)
            myConfig.numbStages = numbStages
            stages = Array(stages.prefix(numbStages))
            myConfig.stages = stages
            while self.stages.count < numbStages {
                // add more stages
                let newStage = Stage()
                self.stages.append(newStage)
            }
            self.selectedStage = 0
        }
        
        func checkCurrentStage(_ value: String) {
            currentStageTxt = String(currentStageTxt.prefix(1))
            let filtered = currentStageTxt.filter { $0.isNumber }
            if currentStageTxt != filtered {
                currentStageTxt = filtered
            }
            if currentStageTxt != "" {
                currentStage = (Int(currentStageTxt) ?? 1)
                if currentStage > numbStages {
                    currentStage = numbStages
                } else if currentStage == 0 {
                    currentStage = 1
                }
                currentStageTxt = String(currentStage)
                myConfig.currentStage = currentStage
            }
            
            // TODO need to ensure stage is completed prior to swapping?
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        private func getType() -> Int {
            var type = 0
            if self.stages.count >= selectedStage + 1 {
                type = self.stages[selectedStage].type
            }
            return type
        }
        
        private func raceGradeOK(raceGrade: String) -> Bool {
            // Check the race grade is valid.  ie could be TBA or suspended
            var gradeFound = false
            for grade in grades {
                for subgrade in subgrades {
                    if subgrade != "-" {
                        // subgrade '-' is nul subgrade
                        if raceGrade == grade + subgrade {
                            gradeFound = true
                            break
                        }
                    } else {
                        if raceGrade == grade {
                            gradeFound = true
                            break
                        }
                    }
                }
                if gradeFound { break }
            }
            return gradeFound
        }
        
        
        var body: some View {
            Background {
            VStack {
                HStack {
                    Text("Race")
                    Picker(selection: Binding(
                            get: {self.selectedRace},
                            set: {self.selectedRace = $0
                                if arrayRaces.count > 0 {
                                    myConfig.raceDate = arrayRaces[$0]["displaydate"] as! String
                                } else {
                                    myConfig.raceDate = "No race dates loaded"
                                }
                            }), label : Text("")){
                        ForEach(0 ..< arrayRaces.count, id:\.self) {
                            Text(arrayRaces[$0]["displaydate"] as! String)
                        }
                    }
                    .frame(width: 250)
                    .clipped()
//                    .scaledToFit()
//                    .scaleEffect(CGSize(width: 1.0, height: 0.8))
                }
                
                HStack {
                    Toggle(isOn: $stage) {
                        Text("Staged")
//                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(width:120) //, alignment: .center)
//                    .padding()
                    .onChange(of: stage) {
                        myConfig.stage = $0
                    }
                    if stage {
                        Text("No: ")
                        TextField(" ", text: $numbStagesTxt)
                        //.font(Font.system(size: 60, design: .default))
                        .frame(width: 60.0)
                        .keyboardType(.numberPad)
                        .onChange(of: numbStagesTxt, perform: checkNumbStages)
                        .disabled(!myConfig.stage)
                        .foregroundColor(Color.blue)
                    }
                    
//                    Text("Now: ")
//                    TextField(" ", text: $currentStageTxt)
//                    //.font(Font.system(size: 60, design: .default))
//                    .frame(width: 45.0)
//                    .keyboardType(.numberPad)
//                    .onChange(of: currentStageTxt, perform: checkCurrentStage)
//                    .disabled(!myConfig.stage)
                }
                
                HStack {
                    if stage {
                        Text("Stage:")
                        Picker(selection: Binding(
                                get: {self.selectedStage},
                                set: {self.selectedStage = $0
                                    // load the number of primes
                                    if self.stages.count == 0 {
                                        numbPrimesTxt = "0"
                                    } else {
                                        numbPrimesTxt = String(self.stages[$0].numbPrimes)
                                    }
                                }),
                                label : Text("")){
                            ForEach(0 ..< numbStages, id:\.self) {
                                Text(String($0 + 1))
                            }
                        }
                        .frame(width: 40)
                        .clipped()
                        .id(UUID())
                        
                        Text("Type:")
                        Picker(selection: Binding(
                            get: {getType()},
                            set: {self.stages[selectedStage].type = $0
                                // TODO check all stages have types set
                                myConfig.stages = self.stages
                            }),
                            label : Text("")){
                            ForEach(0 ..< raceTypes.count, id:\.self) {
                                // for stage races only have crit, graded and TT
                                if !myConfig.stage || $0 < 2 {
                                    Text(raceTypes[$0])
                                }
                            }
                        }
                        .frame(width: 80)
                        .clipped()
//                        .pickerStyle(SegmentedPickerStyle())
                        
                        if self.stages.count >= (selectedStage + 1) && self.stages[selectedStage].type == 0 {
                            // type 0 is graded scratch
                            Text("Primes:")
                            TextField(" ", text: $numbPrimesTxt)
                            //.font(Font.system(size: 60, design: .default))
                            .frame(width: 45.0)
                            .keyboardType(.numberPad)
                            .onChange(of: numbPrimesTxt, perform: checkNumbPrimes)
                            .foregroundColor(Color.blue)
                        }
                        
                        
                    } else {
                        Text("Race Type")
                        Picker(selection: Binding(
                                get: {self.selectedRaceType},
                                set: {self.selectedRaceType = $0
                                    myConfig.raceType = $0
                                }),
                                label : Text("")){
                            ForEach(0 ..< raceTypes.count, id:\.self) {
                                Text(raceTypes[$0])
                            }
                        }
                        .frame(width: 150)
                        .clipped()
    //                    .scaledToFit()
    //                    .scaleEffect(CGSize(width: 1.0, height: 0.8))
                    }
                }
                
                if raceTypes[self.selectedRaceType] == "Age Std" {
                    HStack {
                        Text("Age Std TT Dist (km): ")
                        TextField("000", text: $TTDistString)
                        //.font(Font.system(size: 60, design: .default))
                        .frame(width: 50.0)
                        .keyboardType(.decimalPad)
                        .onChange(of: TTDistString, perform: checkNumb)
    //                    .padding()
                    }
                }
                
                if !stage && raceTypes[self.selectedRaceType] != "Age Std"{
                    Toggle(isOn: bind) {
                        Text("Championship")
    //                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(width:200, alignment: .center)
                }
                HStack{
                // Update button
                Button(action: {
                    result = "Updating entries ..."
                    let url = URL(string: rms + "/?racingMembers")!

                    let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                        guard let httpResponse = response as? HTTPURLResponse,
                                (200...299).contains(httpResponse.statusCode) else {
                                //result = response
                                //self.handleServerError(response)
                                result = "Update entries failed."
                                return
                            }
                        guard let data = data else {
                            result = "No race entries received from RMS"
                            return
                        }
                        writeRiders(riders: data)
                        let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
                        arrayRiders = JSON as! [[String: Any]]
                        // clear persisted starters
                        defaults.set([], forKey: "Starters")
                        result = ""
                        
                        if arrayRaces.count > 0 {
                            let raceid = arrayRaces[selectedRace]["id"] as! String
                            
                            // load any new pre entries
                            let perentryURL = URL(string: rms + "/?eventEntries=" + raceid)!
                            let preTask = URLSession.shared.dataTask(with: perentryURL) {(data, response, error) in
                                guard let httpResponse = response as? HTTPURLResponse,
                                        (200...299).contains(httpResponse.statusCode) else {
                                        //result = response
                                        //self.handleServerError(response)
                                        return
                                    }
                                guard let data = data else {
                                    // no pre entries
                                    return
                                }
                                let perentryJSON = try! JSONSerialization.jsonObject(with: data, options: [])
                                let arrayPres = perentryJSON as! [[String: Any]]
                                var newPreentries = 0
                                for pre in arrayPres {
                                    var newRider = Rider()
                                    newRider.id = pre["id"] as? String ?? ""
                                    if newRider.id != "" {
                                        newRider.name = pre["name"] as! String
                                        newRider.racenumber = String(pre["racenumber"] as? Int ?? -1)
                                        if newRider.racenumber == "-1" {
                                            // don't enter riders without race numbers
                                            continue
                                        }
                                        newRider.gender = pre["gender"] as! String
                                        let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                        let yob = Int((pre["dateofbirth"]  as? String ?? " ").prefix(4)) ?? 0
                                        newRider.age = (now.year ?? 0) - yob
                                        
                                        // Check if the rider is already registered
                                        var alreadyRegistered = false
                                        for rider in arrayStarters {
                                            if rider.racenumber == newRider.racenumber {
                                                alreadyRegistered = true
                                                break
                                            }
                                        }
                                        if alreadyRegistered {
                                            continue
                                        }
                                        if raceTypes[myConfig.raceType] == "Age" ||
                                            (raceTypes[myConfig.raceType] == "Crit" && myConfig.championship) {
                                            var ageClass = 0
                                            if newRider.gender == "M" {
                                                ageClass = ((newRider.age - 30 ) / 5 ) + 1
                                            } else {
                                                ageClass = ((newRider.age - 30 ) / 10 ) + 1
                                            }
                                            newRider.racegrade = newRider.gender + "\(ageClass)"
                                        } else {
                                            // set the race grade
                                            if raceGradeOK(raceGrade: pre["grade"] as! String) {
                                                newRider.racegrade = pre["grade"] as! String
                                                newRider.subgrade = String(pre["subgrade"] as? Int ?? 1) 
                                            } else {
                                                result = "Rider " + newRider.racenumber + " not graded. "
                                            }
                                        }
                                        // register the rider
                                        arrayStarters.append(newRider)
                                        newPreentries = newPreentries + 1
                                    }
                                }
                                getUnplaced()
                                checkHandicaps()
                                setStartingGrades()
                                result = result + String(newPreentries) + " new entries."
                            }
                            preTask.resume()
                        }
                    }
                    task.resume()
                    
                }) {
                    Text( "Update\nentries")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .frame(width: 100, height: 80, alignment: .leading)
                    .background(Color.green)
                    .cornerRadius(10)
                
                // Load button
                Button(action: {
                    result = "Loading members ..."
                    let url = URL(string: rms + "/?racingMembers")!

                    let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                        guard let httpResponse = response as? HTTPURLResponse,
                                (200...299).contains(httpResponse.statusCode) else {
                                //result = response
                                //self.handleServerError(response)
                                result = "Load failed."
                                return
                            }
                        guard let data = data else {
                            result = "No members received from RMS"
                            return
                        }
                        writeRiders(riders: data)
                        let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
                        arrayRiders = JSON as! [[String: Any]]
                        result = String(arrayRiders.count) + " riders loaded. "
                        
                        arrayStarters = []
                        // clear persisted starters
                        defaults.set([], forKey: "Starters")
                        
                        if arrayRaces.count > 0 {
                            let raceid = arrayRaces[selectedRace]["id"] as! String
                            if arrayStarters.count == 0 {
                                // ie don't reload race officals
                                
                                // load marshals
                                let marshalURL = URL(string: rms + "/?marshals=" + raceid)!
                                let nextTask = URLSession.shared.dataTask(with: marshalURL) {(data, response, error) in
                                    guard let httpResponse = response as? HTTPURLResponse,
                                            (200...299).contains(httpResponse.statusCode) else {
                                            //result = response
                                            //self.handleServerError(response)
                                            return
                                        }
                                    guard let data = data else {
                                        // no pre entries
                                        return
                                    }
                                    let marshalsJSON = try! JSONSerialization.jsonObject(with: data, options: [])
                                    let arrayMarshals = marshalsJSON as! [[String: Any]]
                                    for marshal in arrayMarshals {
                                       var newRider = Rider()
                                        // set the race grade
                                        newRider.racegrade = marshalGrade
                                        newRider.id = marshal["marshal_id"]  as! String
                                        newRider.name = marshal["name"]  as! String
                                        newRider.racenumber = String(marshal["racenumber"] as? Int ?? 0)
                                        // register the rider
                                        arrayStarters.append(newRider)
                                    }
                                }
                                nextTask.resume()
                                // load director
                                let directorURL = URL(string: rms + "/?director=" + raceid)!
                                let directorTask = URLSession.shared.dataTask(with: directorURL) {(data, response, error) in
                                    guard let httpResponse = response as? HTTPURLResponse,
                                            (200...299).contains(httpResponse.statusCode) else {
                                            //result = response
                                            //self.handleServerError(response)
                                            return
                                        }
                                    guard let data = data else {
                                        // no pre entries
                                        return
                                    }
                                    let directorJSON = try! JSONSerialization.jsonObject(with: data, options: [])
                                    let director = directorJSON as! [[String: Any]]
                                    if director.count > 0 {
                                        var newRider = Rider()
                                        // set the race grade
                                        newRider.racegrade = directorGrade
                                        newRider.id = director[0]["director_id"]  as! String
                                        newRider.name = director[0]["name"]  as! String
                                        newRider.racenumber = String(director[0]["racenumber"] as! Int)
                                        // register the rider
                                        arrayStarters.append(newRider)
                                    }
                                }
                                directorTask.resume()
                            }

                            // load any new pre entries
                            let perentryURL = URL(string: rms + "/?eventEntries=" + raceid)!
                            let preTask = URLSession.shared.dataTask(with: perentryURL) {(data, response, error) in
                                guard let httpResponse = response as? HTTPURLResponse,
                                        (200...299).contains(httpResponse.statusCode) else {
                                        //result = response
                                        //self.handleServerError(response)
                                        return
                                    }
                                guard let data = data else {
                                    // no pre entries
                                    return
                                }
                                let perentryJSON = try! JSONSerialization.jsonObject(with: data, options: [])
                                let arrayPres = perentryJSON as! [[String: Any]]
                                var newPreentries = 0
                                for pre in arrayPres {
                                    var newRider = Rider()
                                    newRider.id = pre["id"] as? String ?? ""
                                    if newRider.id != "" {
                                        newRider.name = pre["name"] as! String
                                        newRider.racenumber = String(pre["racenumber"] as? Int ?? -1)
                                        if newRider.racenumber == "-1" {
                                            // don't enter riders without race numbers
                                            continue
                                        }
                                        newRider.gender = pre["gender"] as! String
                                        let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                        let yob = Int((pre["dateofbirth"]  as? String ?? " ").prefix(4)) ?? 0
                                        newRider.age = (now.year ?? 0) - yob
                                        
                                        // Check if the rider is already registered
                                        var alreadyRegistered = false
                                        for rider in arrayStarters {
                                            if rider.racenumber == newRider.racenumber {
                                                alreadyRegistered = true
                                                break
                                            }
                                        }
                                        if alreadyRegistered {
                                            continue
                                        }
                                        if raceTypes[myConfig.raceType] == "Age" ||
                                            (raceTypes[myConfig.raceType] == "Crit" && myConfig.championship) {
                                            var ageClass = 0
                                            if newRider.gender == "M" {
                                                ageClass = ((newRider.age - 30 ) / 5 ) + 1
                                            } else {
                                                ageClass = ((newRider.age - 30 ) / 10 ) + 1
                                            }
                                            newRider.racegrade = newRider.gender + "\(ageClass)"
                                        } else {
                                            // set the race grade
                                            if raceGradeOK(raceGrade: pre["grade"] as! String) {
                                                newRider.racegrade = pre["grade"] as! String
                                                if let sgrade = pre["subgrade"] as? Int  {
                                                    newRider.subgrade = String(sgrade)
                                                }
                                                else {
                                                    newRider.subgrade = "1"
                                                }
                                            } else {
                                                result = "Rider " + newRider.racenumber + " not graded. "
                                            }
                                        }
                                        // register the rider
                                        arrayStarters.append(newRider)
                                        newPreentries = newPreentries + 1
                                    }
                                }
                                getUnplaced()
                                checkHandicaps()
                                setStartingGrades()
                                result = result + String(newPreentries) + " new preentries."
                            }
                            preTask.resume()
                        }
                    }
                    task.resume()
                    
                }) {
                    Text("Load")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .frame(width: 100, height: 80, alignment: .leading)
                    .background(arrayStarters.count > 0 ? Color.orange : Color.green)
                    .cornerRadius(10)
                    
                }  // HStack
                    
                Text(result)
                    .padding(.bottom, 100)
//                Spacer()
                .navigationBarTitle("Load", displayMode: .inline)
            }
            .onAppear(perform: {
                self.TTDistString = String(myConfig.TTDist)
                self.selectedRaceType = myConfig.raceType
                self.numbStages = myConfig.numbStages
                self.numbStagesTxt = String(myConfig.numbStages)
                // set the picker to the currently selected race
                self.selectedRace = setRaceDate()
                // load the stages
                self.stage = myConfig.stage
                if self.stage {
                    self.stages = myConfig.stages
                    while self.stages.count < self.numbStages {
                        // add more stages
                        let newStage = Stage()
                        self.stages.append(newStage)
                    }
                    numbPrimesTxt = String(self.stages[0].numbPrimes)
                }
            })
            .onDisappear(perform: {
                if myConfig.stage {
                    // TODO set current stage
//                    myConfig.raceType = stageTypes[myConfig.currentStage]
                }
                
            })
                
            }.onTapGesture {
                self.endEditing()
            }
        }
    }
    
    struct DirectorView: View {
        @State var directorDetails = ""
        @State var registerDisabled = true
        @State var selectedRider = Rider()
        @State var director = [Rider()]
        @State var selectedDirector = 0
        @State var mode: EditMode = .inactive

        func setDirector() {
            director = arrayStarters.filter {$0.racegrade == directorGrade}
            if director.count == 0 {
                registerDisabled = false
            }
        }

        func deleteDirector(id: String) {
            var pointer = 0

            for item in arrayStarters {
                if item.id == id {
                    arrayStarters.remove(at: pointer)
                    director = arrayStarters.filter {$0.racegrade == directorGrade}
                    registerDisabled = false
                    return
                }
                pointer = pointer + 1
            }
            registerDisabled = false
        }

        var body: some View {
            VStack {
                Picker("Director", selection: $selectedDirector) {
                    ForEach(0 ..< arrayNames.count, id:\.self) {
                       Text(arrayNames[$0])
                    }
                }

                HStack {
                    Button(action: {
                        if arrayRiders.count == 0 {
                            directorDetails = "No riders loaded"
                            return
                        }
                        // get the rider's id
                        for rider in arrayRiders {
                            if arrayNames[selectedDirector] == rider["name"] as? String ?? "" {
                                selectedRider.id = rider["id"] as? String ?? " "
                                selectedRider.name = rider["name"] as? String ?? " "
                                selectedRider.racenumber = String(rider["racenumber"] as? Int ?? 0)
                                registerDisabled = false
                            }

                        }
                        // check if the rider is already registered
                        for starter in arrayStarters {
                            if selectedRider.id == starter.id {
                                directorDetails = starter.name + " is already entered"
                                return
                            }
                            if starter.racegrade == directorGrade {
                                directorDetails = "A director has already been registered"
                                return
                            }
                        }
                        // set the race grade
                        selectedRider.racegrade = directorGrade
                        // register the rider
                        arrayStarters.append(selectedRider)
                        setDirector()
                        registerDisabled = true
                    }) {
                        Text("Register")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .disabled(registerDisabled)
                        .frame(width: 100, height: 50, alignment: .leading)
                        .background(registerDisabled ? Color.gray : Color.green)
                        .cornerRadius(10)
                }
                .padding(5)
                if !director.isEmpty {
                    List {
                        HStack{
                            Text(director[0].name)
                            Spacer()
                            if mode == EditMode.active {
                            Button(action: {
                                deleteDirector(id: director[0].id)
                            }) {
                                Text("Remove")
                                    .padding()
                                    .foregroundColor(.black)
                                }
                                .frame(width: 100, height: 50, alignment: .leading)
                                .background(Color.yellow)
                                .cornerRadius(10)
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .toolbar {
                        EditButton()
                    }
                    .environment(\.editMode, $mode)
                }
                Text(directorDetails)
                    .padding(5)

                Spacer()
                }
                .onAppear {
                    self.setDirector()
                }
            .navigationBarTitle("Director", displayMode: .inline)
        }

    }
    
    struct MarshalsView: View {
        @State var marshalDetails = ""
        @State var registerDisabled = false
        @State var selectedRider = Rider()
        @State var marshals = [Rider()]
        @State var selectedMarshal = 0
        @State var mode: EditMode = .inactive
        
        func setMarshals() {
            marshals = arrayStarters.filter {$0.racegrade == marshalGrade}
        }
        
        func deleteMarshal(id: String) {
            var pointer = 0
            
            for item in arrayStarters {
                if item.id == id {
                    arrayStarters.remove(at: pointer)
                    marshals = arrayStarters.filter {$0.racegrade == marshalGrade}
                    return
                }
                pointer = pointer + 1
            }
        }
        
        var body: some View {
            VStack {
                Picker("Marshal", selection: $selectedMarshal) {
                    ForEach(0 ..< arrayNames.count, id:\.self) {
                       Text(arrayNames[$0])
                    }
                }
                HStack {
                    Button(action: {
                        if arrayRiders.count == 0 {
                            marshalDetails = "No riders loaded"
                            registerDisabled = true
                            return
                        }
                        if arrayNames.count == 0 {
                            marshalDetails = "Members not loaded"
                            registerDisabled = true
                            return
                        }
                        // get the rider's id
                        for rider in arrayRiders {
                            if arrayNames[selectedMarshal] == rider["name"] as? String ?? "" {
                                selectedRider.id = rider["id"] as? String ?? " "
                                selectedRider.name = rider["name"] as? String ?? " "
                                selectedRider.racenumber = String(rider["racenumber"] as? Int ?? 0)
                                registerDisabled = false
                                break
                            }
                        }
                        // check if the rider is already registered
                        for starter in arrayStarters {
                            if selectedRider.id == starter.id {
                                marshalDetails = selectedRider.name + " is already entered"
                                return
                            }
                        }
                        
                        // set the race grade
                        selectedRider.racegrade = marshalGrade
                        // register the rider
                        arrayStarters.append(selectedRider)
                        arrayNames.remove(at: selectedMarshal)
                        setMarshals()
                    }) {
                        Text("Register")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .disabled(registerDisabled)
                        .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                        .background(registerDisabled ? Color.gray : Color.green)
                        .cornerRadius(10)
                }
                .padding(5)

                List { ForEach(marshals, id: \.id) { rider in
                    HStack{
                        Text(rider.name)
                        Spacer()
                        if mode == EditMode.active {
                        Button(action: {
                            deleteMarshal(id: rider.id)
                            arrayNames.append(rider.name)
                            arrayNames.sort()
                        }) {
                            Text("Remove")
                                .padding()
                                .foregroundColor(.black)
                            }
                            .frame(width: 100, height: 50, alignment: .leading)
                            .background(Color.yellow)
                            .cornerRadius(10)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    }
                }
                .listStyle(PlainListStyle())
                .toolbar {
                    EditButton()
                }
                .environment(\.editMode, $mode)
                
                Text(marshalDetails)
                    .padding(5)
                
                Spacer()
                }
                .onAppear {
                    self.setMarshals()
                }
            .navigationBarTitle("Marshals", displayMode: .inline)
        }
    }
    
    struct HandicapView: View {
        @State private var selectedGrade = 0
        @State private var selectedSubGrade = 0
        @State var displayHandicaps = handicaps
        @ObservedObject var sec = Time(limit: 2)
        @ObservedObject var min = Time(limit: 2)
        @State var HCmsg = ""
        @State var HCmsgColor = Color.black
        @State var mode: EditMode = .inactive
        
        @State var listHeight: Double = handicapsListHeight
        @State var hcpScratch: Bool = myConfig.hcpScratch  // true for fastest grade being set at lowest time else slowest grade has lowest time

        func checkSec(_ value: String) {
            sec.value = String(value.prefix(sec.limit))
            let filtered = sec.value.filter { $0.isNumber }
            if sec.value != filtered {
                sec.value = filtered
            }
            // check sec is between 0 and 59
            let numb = Int(sec.value) ?? 0
            if numb > 59 {
                sec.value = "  "
            }
        }
        
        func checkMin(_ value: String) {
            min.value = String(value.prefix(min.limit))
            let filtered = min.value.filter { $0.isNumber }
            if min.value != filtered {
                min.value = filtered
            }
        }
        
        func delete(at offsets: IndexSet) {
            offsets.forEach { (i) in
                self.deleteHandicap(racegrade: displayHandicaps[i].racegrade)
                displayHandicaps.remove(at: i)
            }
        }

        func deleteHandicap(racegrade: String) {
            var pointer = 0
            
            for item in handicaps {
                if item.racegrade == racegrade {
                    handicaps.remove(at: pointer)
                    sortHandicaps()
                    return
                }
                pointer = pointer + 1
            }
        }
        
        func sortHandicaps() {
            // sort the hcps based on settings order
            if myConfig.hcpScratch {
                handicaps = handicaps.sorted {
                    return $0.time < $1.time
                }
            } else {
                handicaps = handicaps.sorted {
                    return $0.time > $1.time
                }
            }
            displayHandicaps = handicaps
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        var body: some View {
            Background {
            VStack {
                if raceTypes[myConfig.raceType] != "Hcp" && raceTypes[myConfig.raceType] != "Secret" && raceTypes[myConfig.raceType] != "Wheel" {
                    Text("Race type is not a Handicap")
                } else {
                    // list of handicaps
                    List { ForEach(displayHandicaps, id: \.racegrade) { handicap in
                        HStack{
                            Text(handicap.racegrade + " - " + secAsTime(handicap.time))
                            Spacer()
                            if mode == EditMode.active {
                                Button(action: {
                                    deleteHandicap(racegrade: handicap.racegrade)
                                    HCmsg = "Handicap deleted for " + handicap.racegrade
                                }) {
                                    Text("Remove")
                                        .padding()
                                        .foregroundColor(.black)
                                    }
                                    .frame(width: 100, height: 50, alignment: .leading)
                                    .background(Color.yellow)
                                    .cornerRadius(10)
                                    .buttonStyle(PlainButtonStyle())
                            }
                        }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .toolbar {
                        EditButton()
                    }
                    .environment(\.editMode, $mode)
                    
                    VStack {
                    HStack {
                        Text("Grade:")
                        Picker(selection: $selectedGrade, label : Text("")){
                            ForEach(0 ..< grades.count, id:\.self) {
                                //Spacer()
                                Text(grades[$0])
                                    //.font(Font.system(size: 60, design: .default))
                            }
                        }
                        .frame(width: 40)
                        .clipped()
                        // Add picker for subgrade 1,2
                        if raceTypes[myConfig.raceType] != "Crit" {
                            Text("Sub:")
                            Picker(selection: $selectedSubGrade, label : Text("-")){
                                ForEach(0 ..< subgrades.count, id:\.self) {
                                    //Spacer()
                                    Text(subgrades[$0])
                                    //.font(Font.system(size: 60, design: .default))
                                }
                            }
                            .frame(width: 40)
                            .clipped()
                        }
                        
                        TextField("00", text: $min.value, onEditingChanged: { if $0 {listHeight = handicapsListHeight - keypadHeight} })
                        //.font(Font.system(size: 60, design: .default))
                        .frame(width: 25.0)
                        .keyboardType(.numberPad)
                        .onChange(of: min.value, perform: checkMin)
//                        .padding()
                        Text(":").frame(width: 20.0)
                        TextField("00", text: $sec.value, onEditingChanged: { if $0 {listHeight = handicapsListHeight - keypadHeight} })
                        //.font(Font.system(size: 60, design: .default))
                        .frame(width: 25.0)
                        .keyboardType(.numberPad)
                        .onChange(of: sec.value, perform: checkSec)
//                        .padding()
                        
                        Button(action: {
                            // set handicap time for grade
                            // check the handicap hasn't already been set
                            var testgrade = ""
                            if subgrades[selectedSubGrade] == "-" {
                                testgrade = grades[selectedGrade]
                            } else {
                                testgrade = grades[selectedGrade] + subgrades[selectedSubGrade]
                            }
                            var newHandicap = Handicap()
                            if subgrades[selectedSubGrade] == "-" {
                                newHandicap.racegrade = grades[selectedGrade]
                            } else {
                                newHandicap.racegrade = grades[selectedGrade] + subgrades[selectedSubGrade]
                            }
                            newHandicap.time = (Int(min.value) ?? 0) * 60 + (Int(sec.value) ?? 0)
                            
                            // test the handicap is ok
                            for (index, item) in handicaps.enumerated() {
                                if item.racegrade == testgrade {
                                    HCmsg = "Handicap is already set for " + testgrade
                                    HCmsgColor = Color.red
                                    return
                                }
                                // check subgrades and grade are not being used at the same time
                                if item.racegrade.prefix(1) == grades[selectedGrade] {
                                    if item.racegrade.count == 1 || (item.racegrade.count == 2 && subgrades[selectedSubGrade] == "-") {
                                        // can't mix grade along with subgrades
                                        HCmsg = "Can't mix a grade and subgrades"
                                        HCmsgColor = Color.red
                                        return
                                    }
                                }
                                // check the handicaps not the same and are spaced out by min 10 sec
                                let minInterval = 10 // sec
                                let t = (Int(min.value) ?? 0) * 60 + (Int(sec.value) ?? 0)
                                if abs(item.time - t) < minInterval {
                                    HCmsg = "Grades need to be at least " + String(minInterval) + " seconds apart"
                                    HCmsgColor = Color.red
                                    return
                                }
                                // check the order of handicaps is correct
                                if hcpScratch {
                                    // fastest grade has handicap at lowest time
                                    if handicaps[index].racegrade.prefix(1) == grades[selectedGrade] {
                                        // base grades are the same - check the subgrade
                                        if (subgrades[selectedSubGrade] == "2" && item.time > newHandicap.time ) ||
                                            (subgrades[selectedSubGrade] == "1" && item.time < newHandicap.time ) {
                                            HCmsg = "Handicaps are out of order"
                                            HCmsgColor = Color.red
                                            return
                                        }
                                    } else {
                                        // base grades are different
                                        if (gradeIndex(grade: String(item.racegrade.prefix(1)) ) < gradeIndex(grade: String(grades[selectedGrade])) && item.time > newHandicap.time) ||
                                            (gradeIndex(grade: String(item.racegrade.prefix(1)) ) > gradeIndex(grade: String(grades[selectedGrade])) && item.time < newHandicap.time)
                                        {
                                            HCmsg = "Handicaps are out of order"
                                            HCmsgColor = Color.red
                                            return
                                        }
                                    }
                                    
                                } else {
                                    // slowest grade has handicap at lowest time
                                    if handicaps[index].racegrade.prefix(1) == grades[selectedGrade] {
                                        // base grades are the same - check the subgrade
                                        if (subgrades[selectedSubGrade] == "2" && item.time < newHandicap.time ) ||
                                            (subgrades[selectedSubGrade] == "1" && item.time > newHandicap.time ) {
                                            HCmsg = "Handicaps are out of order"
                                            HCmsgColor = Color.red
                                            return
                                        }
                                    } else {
                                        // base grades are different
                                        if (gradeIndex(grade: String(item.racegrade.prefix(1)) ) < gradeIndex(grade: String(grades[selectedGrade])) && item.time < newHandicap.time) ||
                                            (gradeIndex(grade: String(item.racegrade.prefix(1)) ) > gradeIndex(grade: String(grades[selectedGrade])) && item.time > newHandicap.time)
                                        
                                        {
                                            HCmsg = "Handicaps are out of order"
                                            HCmsgColor = Color.red
                                            return
                                        }
                                    }
                                }
                            }
                            // add the handicap to the list
                            handicaps.append(newHandicap)
                            HCmsg = "Handicap set for " + newHandicap.racegrade
                            HCmsgColor = Color.black
                            
                            sortHandicaps()
                            // check entered riders are in handicaped grade/subgrade
                            adjustGrades()
                        }) {
                            Text("Set")
                                .padding()
                                .foregroundColor(.black)
                            }
                            .frame(width: 60, height: 60, alignment: .leading)
                            .background(Color.green)
                            .cornerRadius(10)
                        
                    }  // end HStack
                    HStack {
                        Toggle(isOn: $hcpScratch) {
                            Text("Fastest Grade at lowest time")
        //                        .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(width:300, alignment: .center)
                        .onChange(of: hcpScratch) {
                            myConfig.hcpScratch = $0
                            handicaps = switchHandicaps(order: myConfig.hcpScratch)
                            sortHandicaps()
                            HCmsg = "Handicaps switched"
                            HCmsgColor = Color.black
                        }
                    }
                }
                    Text(HCmsg)
                    .foregroundColor(HCmsgColor)
                }
            }
            .onAppear {
                //self.switchHandicaps(order: myConfig.hcpScratch)
                self.sortHandicaps()
            }
            .onDisappear(perform: {
                // always set lowest grades to start 1st for handicaps
                //self.switchHandicaps(order: true)
            })
            .navigationBarTitle("Handicaps", displayMode: .inline)
            .frame(height: CGFloat(listHeight))
            
        }
        .onTapGesture {
            self.endEditing()
            listHeight = handicapsListHeight
        }
        }
    }
    
    struct RegoView: View {
        @State private var selectedGrade = 0
        @State private var selectedSubGrade = 0
        @State var raceNumb = RaceNumber(limit: 3)
        @State var riderDetails = ""
        @State var riderDetailsColor = Color.black
        @State var registerDisabled = true
        @State var regradeDisabled = true
        @State var selectedRider = Rider()
        @State var starterId = 0
//        @State var corider = 0
        
//        let bind = Binding<Bool>(
//            get:{tandem},
//            set:{tandem = $0}
//        )
        
        func checkNumb(_ value: String) {
            raceNumb.value = String(value.prefix(raceNumb.limit))
            let filtered = raceNumb.value.filter { $0.isNumber }
            if raceNumb.value != filtered {
                raceNumb.value = filtered
            }
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        var body: some View {
            Background {
            VStack(alignment: .leading) {
                VStack{
                    
                    HStack {
                        Text("Race No.")
                        TextField("000", text: $raceNumb.value)
//                        .font(Font.system(size: 45, design: .default))
                        .frame(width: 100.0)
                        .keyboardType(.numberPad)
                        .onChange(of: raceNumb.value, perform: checkNumb)
//                        .padding()
                        
//                        Toggle(isOn: bind) {
//                            Text("Tandem")
//                        }
//                        .frame(width:120, alignment: .center)
//
//                        if tandem {
//                            Picker("CoRider", selection: $corider) {
//                                ForEach(0 ..< unplacedRiders.count) {
//                                   Text(unplacedRiders[$0])
//                                }
//                            }
//                            .id(UUID())
//                            .frame(width: 50)
//                            .clipped()
//                        }
                    }
                    
                    // Confirm Btn
                    Button(action: {
                        regradeDisabled = true
                        // check if the rider is already registered
                        if arrayStarters.count > 0 {
                            for i in 0...(arrayStarters.count - 1) {
                                if raceNumb.value == arrayStarters[i].racenumber {
                                    riderDetails = raceNumb.value + " is already entered in " + arrayStarters[i].racegrade
                                    regradeDisabled = false
                                    registerDisabled = true
                                    // check if the rider has been placed
                                    if arrayStarters[i].place != "" || arrayStarters[i].overTheLine != ""  {
                                        riderDetails = riderDetails + "\nRider must be unplaced before regrading"
                                        regradeDisabled = true
                                    }
                                    starterId = i
                                    return
                                }
                            }
                        }
                        
                        // show the rider's name
                        if arrayRiders.count == 0 {
                            riderDetails = "No members loaded from RMS"
                            return
                        }
                        for item in arrayRiders {
                            let numb = item["racenumber"] as? Int ?? 0
                            
                            if String(numb) == raceNumb.value {
                                selectedRider.id = item["id"] as? String ?? " "
                                selectedRider.name = item["name"] as? String ?? " "
                                selectedRider.racenumber = String(numb)
                                let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                let yob = Int((item["dateofbirth"]  as? String ?? " ").prefix(4)) ?? 0
                                selectedRider.age = (now.year ?? 0) - yob
                                selectedRider.gender = item["gender"] as? String ?? " "
                                let grade = item["grade"] as? String ?? " "
                                let subgrade = item["subgrade"] as? Int ?? 0
                                let criteriumgrade = item["criteriumgrade"] as? String ?? " "
                                
                                switch raceTypes[myConfig.raceType] {
                                case "Age":
//                                    let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
//                                    let yob = Int((selectedRider.dateofbirth).prefix(4)) ?? 0
//                                    let age = (now.year ?? 0) - yob
                                    // get the age class
                                    var ageClass = 0
                                    if selectedRider.gender == "M" {
                                        ageClass = ((selectedRider.age - 30 ) / 5 ) + 1
                                    } else {
                                        ageClass = ((selectedRider.age - 30 ) / 10 ) + 1
                                    }
                                    riderDetails = String(numb) + " - " + selectedRider.name + "  Age Class: " + selectedRider.gender + String(ageClass)
                                case "Age Std":
                                    riderDetails = String(numb) + " - " + selectedRider.name + "  Age: " + String(selectedRider.age)
                                case "Graded", "Hcp", "TT", "Secret":
                                    riderDetails = String(numb) + " - " + selectedRider.name + "  Grade: " + grade + String(subgrade)
                                    selectedGrade = gradeIndex(grade: grade)
                                    if selectedGrade  == unknownGrade {
                                        // the rider's grade has not been set to one of the defined grades
                                        riderDetails = riderDetails + "\n Default grade C"
                                        selectedGrade = gradeIndex(grade: "C")
                                    }
                                    selectedSubGrade = subgrade
                                case "Crit", "Wheel":
                                    if myConfig.championship {
                                        var ageClass = 0
                                        if selectedRider.gender == "M" {
                                            ageClass = ((selectedRider.age - 30 ) / 5 ) + 1
                                        } else {
                                            ageClass = ((selectedRider.age - 30 ) / 10 ) + 1
                                        }
                                        riderDetails = String(numb) + " - " + selectedRider.name + "  Age Class: " + selectedRider.gender + String(ageClass)
                                    } else {
                                        riderDetails = String(numb) + " - " + selectedRider.name + " Crit: " + criteriumgrade
                                        selectedGrade = gradeIndex(grade: criteriumgrade)
                                        if selectedGrade  == unknownGrade {
                                            // the rider's grade has not been set to one of the defined grades
                                            riderDetails = riderDetails + "\n Default grade C"
                                            selectedGrade = gradeIndex(grade: "C")
                                        }
                                    }
                                default:
                                    riderDetails = "race type " + raceTypes[myConfig.raceType] + " not supported"
                                    return
                                }
                                riderDetailsColor = Color.black
                                if item["financial"]  as? Bool ?? false == false {
                                    riderDetails = "UNFINANCIAL - " + riderDetails
                                    riderDetailsColor = Color.red
                                }
                                registerDisabled = false
                                return  // exit from the for loop
                            }
                            // race number not found
                            riderDetails = raceNumb.value + " is invalid"
                            riderDetailsColor = Color.red
                        }  // for loop
                    }) {
                        Text("Confirm")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                        .background(Color.yellow)
                        .cornerRadius(10)
                    
                    Text(riderDetails)
                        .foregroundColor(riderDetailsColor)
                    
                    HStack {
                        // Hide grades if age based
                        if raceTypes[myConfig.raceType] == "Age" || raceTypes[myConfig.raceType] == "Age Std" ||
                            (raceTypes[myConfig.raceType] == "Crit" && myConfig.championship ) {
                            Text(" ") // force fields into view
                                .frame(height: 160)
                        } else {
                            Text("Grade")
                            Picker(selection: $selectedGrade, label : Text("")){
                                ForEach(0 ..< grades.count, id:\.self) {
                                    //Spacer()
                                    Text(grades[$0])
                                        //.font(Font.system(size: 60, design: .default))
                                }
                            }
                            .frame(width: 50)
                            .clipped()
                            if raceTypes[myConfig.raceType] != "Crit" {
                                Text("Sub")
                                // Add picker for subgrade 1,2
                                Picker(selection: $selectedSubGrade, label : Text("")){
                                    ForEach(0 ..< subgrades.count, id:\.self) {
                                        //Spacer()
                                        Text(subgrades[$0])
                                            //.font(Font.system(size: 60, design: .default))
                                    }
                                }
                                .frame(width: 50)
                                .clipped()
                            }
                        }
                    }
                    HStack {
                    // Register button
                    Button(action: {
                        switch raceTypes[myConfig.raceType] {
                        case "Age":
                            selectedRider.racegrade = selectedRider.gender+String(((selectedRider.age - 30 ) / 5 ) + 1)
                        case "Age Std":
                            // age Std TT used age, not racegrade
                            if selectedRider.gender == "M" {
                                selectedRider.racegrade = "Men"
                            } else {
                                selectedRider.racegrade = "Women"
                            }
                        case "Graded", "Hcp":
                            // set the race grade
                            if subgrades[selectedSubGrade] == "-" {
                                selectedRider.racegrade = grades[selectedGrade]
                            } else {
                                selectedRider.racegrade = grades[selectedGrade] + subgrades[selectedSubGrade]
                            }
                        case "Crit":
                            if myConfig.championship {
                                var ageClass = 0
                                if selectedRider.gender == "M" {
                                    ageClass = ((selectedRider.age - 30 ) / 5 ) + 1
                                } else {
                                    ageClass = ((selectedRider.age - 30 ) / 10 ) + 1
                                }
                                selectedRider.racegrade = selectedRider.gender + String(ageClass)
                            } else {
                                selectedRider.racegrade = grades[selectedGrade]
                            }
                        default:
                            selectedRider.racegrade = grades[selectedGrade]
                        }
                        
                        if tandem {
                            if unplacedRiders.count == 0 {
                                riderDetails = "No riders yet registered"
                                return
                            } else {
                                // check if the rider is already on a tandem
//                                for i in 0...(arrayStarters.count - 1) {
//                                    if arrayStarters[i].racenumber == unplacedRiders[corider] {
//                                        let x = arrayStarters[i].corider
//                                        if x == "" {
//                                            arrayStarters[i].corider = unplacedRiders[corider]
//                                        } else {
//                                            riderDetails = arrayStarters[i].racenumber + " is already a tandem"
//                                            return
//                                        }
//                                    }
//                                    break
//                                }
//                                selectedRider.corider = unplacedRiders[corider]
                            }
                        }
                        
                        // register the rider
                        arrayStarters.append(selectedRider)
                        setStartingGrades()
                        initStageResults()
                        getUnplaced()
                        checkHandicaps()
                        riderDetails = "Registered"
                        raceNumb.value = ""
                        registerDisabled = true
                    }) {
                        Text("Register")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .disabled(registerDisabled)
                        .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                        .background(registerDisabled ? Color.gray : Color.green)
                        .cornerRadius(10)
                    
                    if raceTypes[myConfig.raceType] != "Age" && raceTypes[myConfig.raceType] != "Age Std" && !myConfig.championship {
                    // Regrade button
                        Button(action: {
                            var subgrade = ""
                            if subgrades[selectedSubGrade] == "-" {
                                subgrade = ""
                            }
                            // check if the rider has been placed
                            if arrayStarters[starterId].place != "" || arrayStarters[starterId].overTheLine != ""  {
                                riderDetails = "Rider must be unplaced before regrading"
                                return
                            }
                            if arrayStarters[starterId].racegrade == grades[selectedGrade] + subgrade {
                                riderDetails = "Rider already in " + grades[selectedGrade]
                                return
                            }
                            // set the race grade
                            if raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "Graded" || raceTypes[myConfig.raceType] == "Wheel" {
                                arrayStarters[starterId].racegrade = grades[selectedGrade] + subgrade
                            } else {
                                arrayStarters[starterId].racegrade = grades[selectedGrade]
                            }
                            
                            setStartingGrades()
                            checkHandicaps()
                            riderDetails = "Regraded to " + grades[selectedGrade] + subgrade
                            regradeDisabled = true
                        }) {
                            Text("Regrade")
                                .padding()
                                .foregroundColor(.black)
                            }
                            .disabled(regradeDisabled)
                            .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                            .background(regradeDisabled ? Color.gray : Color.green)
                            .cornerRadius(10)
                    }
                    }
                }
//                Spacer()
            }
            .onAppear(perform: {
                raceNumb.value = ""
                tandem = false
            })
            }.onTapGesture {
                self.endEditing()
            }
            .navigationBarTitle("Registration", displayMode: .inline)
        }
    }
    
    struct TrialView: View {
        @State private var selectedGrade = 0
        @State private var selectedSubGrade = 0
        @State private var selectedGender = 0
        @State private var dob = Date()
        @State var visitNumb = RaceNumber(limit: 3)
        @State var givenName = ""
        @State var surname = ""
        @State var visitorDetails = ""
        @State var registerDisabled = true
        @State var visitor = Rider()
        @State var ageClass = 0
        @State var visitorDetailsColor = Color.black
        
        func checkNumb(_ value: String) {
            visitNumb.value = String(value.prefix(visitNumb.limit))
            let filtered = visitNumb.value.filter { $0.isNumber}
            if visitNumb.value != filtered {
                visitNumb.value = filtered
            }
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        var body: some View {
            Background {
            VStack {
                HStack {
                    // Hide grades if age based
                    if raceTypes[myConfig.raceType] == "Age" || raceTypes[myConfig.raceType] == "Age Std" {
                        Text(" ") // force fields into view
                            .frame(height: 150)
                    } else {
                        Text("Grade")
                            .padding(.top, 50)
                        Picker(selection: $selectedGrade, label : Text("")){
                            ForEach(0 ..< grades.count, id:\.self) {
                                //Spacer()
                                Text(grades[$0])
                                //.font(Font.system(size: 60, design: .default))
                            }
                        }
                        .frame(width: 50)
                        .clipped()
                        .padding(.top, 50)
                        if raceTypes[myConfig.raceType] != "Crit" {
                            // Add picker for subgrade 1,2
                            Picker(selection: $selectedSubGrade, label : Text("")){
                                ForEach(0 ..< subgrades.count, id:\.self) {
                                    //Spacer()
                                    Text(subgrades[$0])
                                        //.font(Font.system(size: 60, design: .default))
                                }
                            }
                            .frame(width: 50)
                            .clipped()
                            .padding(.top, 50)
                        }
                    }
                }
                HStack {
                    Text("Race No.")
                    TextField("700", text: $visitNumb.value)
                    //.font(Font.system(size: 60, design: .default))
                    .frame(width: 50.0)
                    .keyboardType(.numberPad)
                    .onChange(of: visitNumb.value, perform: checkNumb)
                }.padding(.top, 20)
                HStack {
                    Text("Given Name")
                    TextField("Given Name", text: $givenName)
                    .frame(width: 150.0)
                    .disableAutocorrection(true)
                }.padding(.top, 15)
                HStack {
                    Text("Surname")
                    TextField("Surname", text: $surname)
                    .frame(width: 150.0)
                    .disableAutocorrection(true)
                }.padding(.top, 15)
                if raceTypes[myConfig.raceType] == "Age" || raceTypes[myConfig.raceType] == "Age Std" {
                    HStack {
                        Text("Gender")
                        Picker(selection: $selectedGender, label : Text("")){
                            ForEach(0 ..< genders.count, id:\.self) {
                                Text(genders[$0])
                            }
                        }
//                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 50)
                        .clipped()
                        
                        Text("DOB")
                        DatePicker("DOB", selection: $dob, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                Button(action: {
                    // confirm details
                    if visitNumb.value == "" || surname == ""  || givenName == ""{
                        visitorDetails = "Enter race number and names"
                        visitorDetailsColor = Color.red
                    } else {
                        // check the race number is in 700s
                        if Int(visitNumb.value) ?? 0 < 700 {
                            visitorDetails = "Race number must be in the 700s"
                            visitorDetailsColor = Color.red
                            return
                        }
                        // check the race number hasn't been used.
                        for starter in arrayStarters {
                            if visitNumb.value == starter.racenumber {
                                visitorDetails = visitNumb.value + " is already entered"
                                visitorDetailsColor = Color.red
                                return
                            }
                        }
                        if raceTypes[myConfig.raceType] == "Age" || raceTypes[myConfig.raceType] == "Age Std" {
                            // check the rider is older than 29.
                            let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                            let yob = Calendar.current.dateComponents([.year, .month, .day], from: dob)
                            let years = (now.year ?? 0) - (yob.year ?? 0)
                            if years < 30 {
                                visitorDetails = "Rider must be at least 30"
                                visitorDetailsColor = Color.red
                                return
                            }
                            // get the age class
                            ageClass = ((years - 30 ) / 5 ) + 1
                            visitorDetails = genders[selectedGender] + String(ageClass) + " = " + String(visitNumb.value) + " - " + surname + " - VISITOR, " + givenName
                            visitorDetailsColor = Color.black
                        } else {
                            visitorDetails = String(visitNumb.value) + " - " + surname + " - VISITOR, " + givenName
                            visitorDetailsColor = Color.black
                        }
                        registerDisabled = false
                    }
                }) {
                    Text("Confirm")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                    .background(Color.yellow)
                    .cornerRadius(10)
                Text(visitorDetails)
                    .foregroundColor(visitorDetailsColor)
                    .padding()
                Button(action: {
                    // register the trial rider
                    // push the trial rider into the start list
                    if raceTypes[myConfig.raceType] == "Age" || raceTypes[myConfig.raceType] == "Age Std" {
                        // form the racegrade from gender and age
                        visitor.racegrade = genders[selectedGender] + String(ageClass)
                        visitor.gender = genders[selectedGender]
                        let formatter1 = DateFormatter()
                        formatter1.dateStyle = .short
                        visitor.dateofbirth = formatter1.string(from: dob)
                    } else {
                        visitor.racegrade = grades[selectedGrade]
                    }
                    visitor.racenumber = String(Int(visitNumb.value) ?? 700)
                    visitor.name = surname + " - VISITOR, " + givenName
                    visitor.surname = surname  // RMS adds in - VISITOR
                    visitor.givenName = givenName
                    arrayStarters.append(visitor)
                    setStartingGrades()
                    getUnplaced()
                    checkHandicaps()
                    visitorDetails = "Registered"
                    visitorDetailsColor = Color.black
                    visitNumb.value = ""
                    surname = ""
                    givenName = ""
                    registerDisabled = true
                }) {
                    Text("Register")
                        .padding()
                        .foregroundColor(.black)
                    }
                    .disabled(registerDisabled)
                    .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                    .background(registerDisabled ? Color.gray : Color.green)
                    .cornerRadius(10)
                    .padding(.bottom, 50)
//                 Spacer()
            }
            
            }.onTapGesture {
                self.endEditing()
                checkNumb(visitNumb.value)
                }
            .navigationBarTitle("Trial Rider", displayMode: .inline)
        }
    }
    
    struct StartView: View {
        @State var selectedGrade = 0
        @State private var selectedSubGrade = 0
        @State var starts: [Rider] = []
        @State var mode: EditMode = .inactive
        
        func setStarts() {
            // sert the starts array used for dynamic updating of the view
            if raceTypes[myConfig.raceType] == "Age Std" {
                starts = arrayStarters.filter {$0.racegrade != directorGrade && $0.racegrade != marshalGrade}
                starts.sort {$0.age < $1.age}
            }
            if raceTypes[myConfig.raceType] == "TT" {
                starts = arrayStarters.filter {$0.racegrade != "" && $0.racegrade != directorGrade && $0.racegrade != marshalGrade}
                starts.sort {
                    if $0.racegrade == $1.racegrade {
                        return $0.racenumber < $1.racenumber
                    } else {
                        return $0.racegrade < $1.racegrade
                    }
                }
            }
            if raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "TT" {
                // set the start time for each starting rider
                var ttStart = 0.0
                if starts.count > 0 {
                    for i in 0...(starts.count - 1) {
//                        for i in 0...(starts.count - 1) {
//                            if starts[i].corider != "" {
//                                // TODO allow for tandem
//                            }
//                        }
                        starts[i].ttOffset = ttStart
                        for j in 0...(arrayStarters.count - 1) {
                            if arrayStarters[j].racenumber == starts[i].racenumber {
                                arrayStarters[j].ttOffset = ttStart
                            }
                        }
                        ttStart = ttStart + Double(myConfig.TTStartInterval)
                    }
                }
            }
            if raceTypes[myConfig.raceType] != "Age Std" && raceTypes[myConfig.raceType] != "TT" && startingGrades.count > 0 {
                starts = arrayStarters.filter {$0.racegrade == startingGrades[selectedGrade]}
                // sort by name
                starts.sort {$0.name.localizedStandardCompare($1.name) == .orderedAscending}
            }
        }
        
        func delete(racenumber: String) {
            // deletes a rider from the start list
            var pointer = 0
            
            for item in arrayStarters {
                if item.racenumber == racenumber {
                    arrayStarters.remove(at: pointer)
                    setStartingGrades()
                    setStarts()
                    getUnplaced()
                    return
                }
                pointer = pointer + 1
            }
        }
        
        var body: some View {
            VStack{
            if raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "TT" {
                HStack {}
                    .onAppear {
                        self.setStarts()
                    }
            } else {
            HStack {
                if raceTypes[myConfig.raceType] == "Age" {
                    Text("Class")
                } else {
                    Text("Grade")
                }
                
                Picker(selection: Binding(
                        get: {self.selectedGrade},
                        set: {self.selectedGrade = $0
                            setStarts()
                        }), label : Text("")){
                    ForEach(0 ..< startingGrades.count, id:\.self) {
                        //Spacer()
                        Text(startingGrades[$0])
                            //.font(Font.system(size: 60, design: .default))
                    }
                }
                .id(UUID())
                .frame(width: 50)
                .clipped()
//                // Add picker for subgrade 1,2
//                if raceTypes[raceType] != "Crit" {
//                    Picker(selection: $selectedSubGrade, label : Text("")){
//                        ForEach(0 ..< subgrades.count) {
//                            //Spacer()
//                            Text(subgrades[$0])
//                                //.font(Font.system(size: 60, design: .default))
//                        }
//                    }
//                    .frame(width: 50)
//                    .clipped()
//                }
            }
            .onAppear {
                self.setStarts()
            }
            .onDisappear {
                setStartingGrades()
            }
            }
            
                
            List { ForEach(starts, id: \.racenumber) { rider in
                HStack{
                    if raceTypes[myConfig.raceType] == "Age Std" {
                        Text("\(rider.gender)\(rider.age) = \(rider.racenumber) - \(rider.name)")
                    } else if raceTypes[myConfig.raceType] == "TT" {
                        Text(doubleAsTime(rider.ttOffset) + " = \(rider.racenumber) - \(rider.name)")
                    } else {
                        Text("\(rider.racenumber) - \(rider.name)")
                    }
                    Spacer()
                    // Remove rider from start list
                    if mode == EditMode.active {
                    Button(action: {
                        delete(racenumber: rider.racenumber)
                    }) {
                        Text("Remove")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .frame(width: 100, height: 50, alignment: .leading)
                        .cornerRadius(10)
                        .buttonStyle(PlainButtonStyle())
                        // TODO check stage
                        .background(rider.place != "" || rider.overTheLine != "" ? Color.gray : Color.yellow)
                        .disabled(rider.place != "" || rider.overTheLine != "")  // don't allow placed riders to be removed
                    }
                }
                }
            }
            .listStyle(PlainListStyle())
            .toolbar {
                EditButton()
            }
            .environment(\.editMode, $mode)
            
            Spacer()
            if starts.count == 1 {
                Text(String(starts.count) + " rider")
            } else {
                Text(String(starts.count) + " riders")
            }
        }
            .navigationBarTitle("Start List", displayMode: .inline)
        }
        
    }
    
    struct TimingView: View {
        @State private var selectedStartGrade = 0
        let buttonHeight = CGFloat(80.0)
        @State var overTheLine = 0
        @State var newTime = FinishTime()
        @State var displayItem: Double = -1.0
        @State var startBtnTxt = "Start"
        @State var TimingMsg = ""
        @State var TimingMsgColor = Color.black
        @State var displayPlaces = finishTimes
        @State var mode: EditMode = .inactive
        
        @ObservedObject var stopWatchManager: StopWatchManager
        
        // TODO allow for grades to be started together in scratch?? - Or just press start quickly
        // TODO check there is a handicap for each rider -   if raceTypes[raceType] == "Hcp" {}
        // TODO what to do with TT riders who miss their start time
        
        func getUnstartedGrades() {
            unstartedGrades = []
            // find all the grades with starters
            for rider in arrayStarters.indices {
                var notfound = true
                for grade in unstartedGrades.indices {
                    if arrayStarters[rider].racegrade == unstartedGrades[grade] {
                        notfound = false
                        break
                    }
                }
                if notfound && arrayStarters[rider].racegrade != directorGrade && arrayStarters[rider].racegrade != marshalGrade {
                    // check the grade isn't already started
                    for startedGrade in startedGrades.indices {
                        if arrayStarters[rider].racegrade == startedGrades[startedGrade].racegrade {
                            notfound = false
                            break
                        }
                    }
                    if notfound {
                        unstartedGrades.append(arrayStarters[rider].racegrade)
                    }
                }
            }
        }
        
        func insertPlace(_ finishTime: FinishTime) {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            newTime.id = UUID()
            overTheLine =  overTheLine + 1
            newTime.overTheLine = finishTime.overTheLine + 1
            // move all the other down one place
            for i in 0...(finishTimes.count - 1) {
                if finishTimes[i].overTheLine >= newTime.overTheLine {
                    if finishTimes[i].allocated {
                        // update the riders details
                        for index in arrayStarters.indices {
                            if arrayStarters[index].overTheLine == String(finishTimes[i].overTheLine) {
                                arrayStarters[index].overTheLine = String(finishTimes[i].overTheLine + 1)
                            }
                        }
                    }
                    finishTimes[i].overTheLine = finishTimes[i].overTheLine + 1
                    finishTimes[i].displayTime = String(format: "%03d", finishTimes[i].overTheLine) + " - \n" +
                        formatter.string(from: finishTimes[i].time!)
                }
            }
            newTime.time = finishTime.time //set the same time
            newTime.displayTime = String(format: "%03d", newTime.overTheLine) + " - \n" +
                formatter.string(from: newTime.time!)
            finishTimes.append(newTime)
            finishTimes.sort {return $0.overTheLine < $1.overTheLine}
            displayPlaces = finishTimes
//            unplacedSpots.append(newTime.displayTime)
            TimingMsg = String(overTheLine) + " Recorded. " + String(max((unplacedRiders.count - overTheLine), 0)) + " to finish"
            TimingMsgColor = Color.black
        }

        func removePlace(_ finishTime: FinishTime) {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            if finishTimes.count > 0 {
                for i in 0...(finishTimes.count - 1) {
                    if finishTimes[i].displayTime == finishTime.displayTime {
                        
                        if i < finishTimes.count - 1 {
                            for j in i...(finishTimes.count - 1) {
                                // move up the other times
                                finishTimes[j].overTheLine = finishTimes[j].overTheLine - 1
                                finishTimes[j].displayTime = String(format: "%03d", finishTimes[j].overTheLine) + " - \n" +
                                    formatter.string(from: finishTimes[j].time!)
                            }
                        }
                        // TODO move up the other times and update any placed riders
                        finishTimes.remove(at: i)
                        break
                    }
                }
                displayPlaces = finishTimes
            }
            overTheLine =  overTheLine - 1
            TimingMsg = String(overTheLine) + " Recorded. " + String(max((unplacedRiders.count - overTheLine), 0)) + " to finish"
            TimingMsgColor = Color.black
        }
        
        func allowPlaceDelete(_ finishTime: FinishTime) -> Bool {
            var allocated = false
            if finishTime.allocated {
                return true
            }
            for i in stride(from: (finishTimes.count - 1), to: -1, by: -1) {
            
//            for i in ((finishTimes.count - 1)...0).reversed() {
                if finishTimes[i].allocated {
                    allocated = true
                }
                if finishTime.overTheLine == finishTimes[i].overTheLine {
                    return allocated
                }
            }
            return false
        }
        
        var body: some View {
            if raceTypes[myConfig.raceType] == "Crit" {
                Text("Race type " + raceTypes[myConfig.raceType] + " is not timed")
            } else {
                VStack(alignment: .leading) {
                    HStack {
                    VStack {
                    HStack {
                    
                    if !masterPaired {
                    switch raceTypes[myConfig.raceType] {
                    case "Graded", "Age":
                        if unstartedGrades.count > 0 {
                        // select grade to start
                        Picker(selection: $selectedStartGrade, label : Text("")){
                            ForEach(0 ..< unstartedGrades.count, id:\.self) {
                                Text(unstartedGrades[$0])
                            }
                        }
                        .id(unstartedGrades)
                        .frame(width: 50)
                        .clipped()
                        }
                    case "Hcp", "Wheel":
                        if handicaps.count == 0 {
                            Text("   No grades to start")
                                .frame(height: buttonHeight)
                        } else {
                            // show the grade that is about to start - grades should never start together
                            
                            Text("  " + stopWatchManager.nextStart)  // pad a bit to the right
                                .font(Font.body.monospacedDigit())
                                .frame(height: buttonHeight)
                                .padding()
                        }
                    case "TT", "Age Std" :
                        VStack {
                            // show a list of riders in start order
                            if overTheLine > 0 {     // if the race is started make the list narrower
                                Text(stopWatchManager.nextRider)
                                .font(Font.body.monospacedDigit())
                                .frame(width: 50, height: buttonHeight/1.7)
                                .padding()
                                Text(stopWatchManager.nextRiders)
                                .font(Font.body.monospacedDigit())
                                .frame(width: 50)
                                .padding()
                            } else {
                                Text(stopWatchManager.nextRider)
                                .font(Font.body.monospacedDigit())
                                .frame(width: 150, height: buttonHeight/1.7)
                                .padding()
                                Text(stopWatchManager.nextRiders)
                                .font(Font.body.monospacedDigit())
                                .frame(width: 150)
                                .padding()
                            }
                        }
                    default:
                        Text("") // fill in
                    }
                    
                    // hide start on master and when disabled
                    if ((raceTypes[myConfig.raceType] != "TT" && raceTypes[myConfig.raceType] != "Age Std") ||
                            !self.stopWatchManager.started )
                        && !startDisabled && !running || (running && !startDisabled) {
                        HStack {
                        Text(" ") // push button away from LHS of screen
                        // Start button
                        Button(action: {
                            let date = Date()
                            dateformatter.dateFormat = "HH:mm:ss"
                            AudioServicesPlaySystemSound(SystemSoundID(buttonSound))
                            if running {
                                TimingMsg = "Race is already running"
                                TimingMsgColor = Color.red
                            } else {
                                TimingMsg = "Race Started at " + dateformatter.string(from: date)
                                TimingMsgColor = Color.black
                                raceStarted = true
                                running = true
                                self.stopWatchManager.storeStartTime()
                                self.stopWatchManager.startTimer()
                            }
                            
                            switch raceTypes[myConfig.raceType] {
                            case "Graded", "Age":
                                TimingMsg = unstartedGrades[selectedStartGrade] + " Grade started at " + dateformatter.string(from: date)
                                // remove the started grade
                                for grade in unstartedGrades.indices {
                                    if unstartedGrades[grade] == unstartedGrades[selectedStartGrade] {
                                        // record the grade's start time
                                        var newStart = StartedGrade()
                                        newStart.racegrade = unstartedGrades[grade]
                                        newStart.startTime = Date()
                                        startedGrades.append(newStart)
                                        unstartedGrades.remove(at: grade)
                                        selectedStartGrade = 0
                                        break
                                    }
                                }
                                if unstartedGrades.count == 0 {
                                    startDisabled = true
        //                            stopDisabled = false
                                    recordDisabled = false
                                    self.stopWatchManager.stopTimer()
                                } else {
        //                            stopDisabled = true
                                }
                            case "Hcp":
                                // Just started the 1st grade
                                startDisabled = true
                                recordDisabled = false
        //                        stopDisabled = false
                            case "Secret":
                                // Just started everyone at once
                                startDisabled = true
                                recordDisabled = false
        //                        stopDisabled = false
                                for unstartedGrade in unstartedGrades {
                                    var newStartedGrade = StartedGrade()
                                    newStartedGrade.racegrade = unstartedGrade
                                    newStartedGrade.startTime = Date()
                                    startedGrades.append(newStartedGrade)
                                }
                                unstartedGrades = []
                                self.stopWatchManager.stopTimer()  // stop the timer.  Recording uses actual time of day
                                raceStarted = true
                            case "Wheel":
                                startDisabled = true
                                recordDisabled = true  // not timed
    //                            self.stopWatchManager.stopTimer()  // stop the timer.  Recording uses actual time of day
        //                        stopDisabled = false   // timer stops after all grades are started
                            case "Age Std", "TT":
                                startDisabled = true
                                recordDisabled = false
        //                        stopDisabled = false
                            default:
                                startDisabled = true
                            }
                        }) {
                            Text(startBtnTxt)
                                .padding()
                                .foregroundColor(.black)
                            }.disabled(startDisabled)
                            .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: buttonHeight, alignment: .leading)
                            .background(startDisabled ? Color.gray : Color.green)
                            .cornerRadius(10)
                        }
                    }
                    }
                    } // end HStack group
                    Text("") // spacer
                    // hide record and stop buttons on the paired slave
                    if !peripheralPaired {
                    if raceTypes[myConfig.raceType] != "Wheel" && raceStarted {
                        HStack {
                        Text(" ") // push button away from LHS of screen
                        // Record button
                        Button(action: {
                            AudioServicesPlaySystemSound(SystemSoundID(buttonSound))
                            overTheLine = finishTimes.count + 1
                            getUnplaced(grade: -1)
                            TimingMsg = String(overTheLine) + " Recorded. " + String(max((unplacedRiders.count - overTheLine), 0)) + " to finish"
                            TimingMsgColor = Color.black
                            // record a finish time
                            newTime.id = UUID()
                            newTime.overTheLine = overTheLine
                            newTime.time = Date() //stopWatchManager.counter
                            let formatter = DateFormatter()
                            formatter.timeStyle = .medium
                            newTime.displayTime = String(format: "%03d", overTheLine) + " - \n" +
                                formatter.string(from: newTime.time!)
                            finishTimes.append(newTime)
                            displayPlaces = finishTimes
    //                        unplacedSpots.append(newTime.displayTime)
                        }) {
                            Text("Record")
                                .padding()
                                .foregroundColor(.black)
                        }
                        .disabled(recordDisabled || (raceTypes[myConfig.raceType] == "Hcp" && stopWatchManager.nextStart != ""))
                        .frame(width: 90, height: buttonHeight, alignment: .leading)
                        .background(recordDisabled || (raceTypes[myConfig.raceType] == "Hcp" && stopWatchManager.nextStart != "") ? Color.gray : Color.yellow)
                        .cornerRadius(10)
                        .padding()
                        }
                    }
                    
    //                if raceTypes[myConfig.raceType] != "Wheel" {
    //                    // Stop button
    //                    Button(action: {
    //                        TimingMsg = "Stop"
    //                        self.stopWatchManager.stopTimer()
    //                        running = false
    //                        startDisabled = true
    //                        recordDisabled = true
    //                        stopDisabled = true
    //
    //                        // copy the finish time to the global array so they can be assigned in Places
    //                        for spot in finishTimes.indices {
    //                            unplacedSpots.append(finishTimes[spot].displayTime)
    //                        }
    //                        unplacedSpots.sort()
    //                    }) {
    //                        Text("Stop")
    //                            .padding()
    //                            .foregroundColor(.black)
    //
    //                    }
    //                    .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: buttonHeight, alignment: .leading)
    //                    .disabled(stopDisabled ||
    ////                                lockedState ||
    //                                (raceTypes[myConfig.raceType] == "Hcp" && self.stopWatchManager.nextStart != "") || self.stopWatchManager.stopped)
    //                    .background(stopDisabled ||
    ////                                lockedState  ||
    //                                (raceTypes[myConfig.raceType] == "Hcp" && self.stopWatchManager.nextStart != "" || self.stopWatchManager.stopped) ? Color.gray : Color.red)  //
    //                    .cornerRadius(10)
    //                }
                    }
                            
                    Spacer()
                    }  // end vstack
                    .padding(.top, 10)
                        
                        VStack() {
                        if !masterPaired &&
                            (raceTypes[myConfig.raceType] == "Graded" || raceTypes[myConfig.raceType] == "Age") && unstartedGrades.count > 0 {
                            // display the stopwatch run time
                            Text(String(format: "%02.0f", stopWatchManager.hours) + ":" +
                                String(format: "%02.0f", stopWatchManager.minutes) + ":" +
                                String(format: "%04.1f", stopWatchManager.seconds))
                                .font(Font.body.monospacedDigit())
                                .padding(.top, 40)
                        }

                        // List of finish times
                            List { ForEach(displayPlaces.reversed()) { finishTime in
    //                        Button(action: {
    //                            displayItem = finishTime.time
    //                        })
                                HStack {
                                Text(finishTime.displayTime).font(Font.body.monospacedDigit())
                                    
                                if mode == EditMode.active {
                                    // Insert button
                                    Button(action: {
                                        insertPlace(finishTime)
                                    }) {
                                        Text("+")
                                            .padding()
                                            .foregroundColor(.black)
                                        }
                                        .background(Color.green)
                                        .frame(width: 45, height: 50)
                                        .cornerRadius(10)
                                        .buttonStyle(PlainButtonStyle())
                                    
                                    // Remove button
                                    Button(action: {
                                        removePlace(finishTime)
                                    }) {
                                        Text("-")
                                            .padding()
                                            .foregroundColor(.black)
                                        }
                                        .disabled(allowPlaceDelete(finishTime))
                                        .background(allowPlaceDelete(finishTime) ? Color.gray : Color.red)
                                        .frame(width: 45, height: 50)
                                        .cornerRadius(10)
                                        .buttonStyle(PlainButtonStyle())
                                }
                                }
                                
        //                        {Text(finishTime.displayTime)}
                            }
                        }
                        .listStyle(PlainListStyle())
                        .toolbar {
                            EditButton()
                        }
                        .environment(\.editMode, $mode)
    //                    .frame(width: 180)
                         
                        Spacer()
                        }  // end Vstack
                }
                    //
                    Spacer()
                    HStack {
                    Text(TimingMsg)
                        .padding(.bottom, 5)
                        .foregroundColor(TimingMsgColor)
                        
                    }
                    .frame(width: 400, alignment: .center)
                    
                } // end VStack
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    stopWatchManager.resume()
                }
                
                .onAppear(perform: {  // of Timing
                    if reset {
                        stopWatchManager.reset()
                        reset = false  // reset done
                    }
                    if running {
                        dateformatter.dateFormat = "HH:mm:ss"
                        let date = UserDefaults.standard.object(forKey: "startDateTime") as! Date?
                        TimingMsg = "Race Started at " + dateformatter.string(from: date!)
                        TimingMsgColor = Color.black
                    }
                    checkHandicaps()
                    overTheLine = unplacedTimes()  //unplacedSpots.count
                    displayPlaces = finishTimes
                    // TODO change button to Restart and Yellow if restarting
                    switch raceTypes[myConfig.raceType] {
                    case "Graded", "Age":
                        getUnstartedGrades()
                        if unstartedGrades.count == 0 {
                            // also needs to be set before onAppear
                            startDisabled = true
    //                        stopDisabled = false
                            TimingMsg = String(max((unplacedRiders.count - unplacedTimes()), 0)) + " riders to finish"
                            TimingMsgColor = Color.black
                        } else {
                            unstartedGrades.sort()
                            startDisabled = false
                            if unstartedGrades.count == 1 {
                                TimingMsg = String(unstartedGrades.count) + " Grade to start"
                            } else {
                                TimingMsg = String(unstartedGrades.count) + " Grades to start"
                            }
                            TimingMsgColor = Color.black
                        }
                    case "Hcp", "Wheel":
                        if handicaps.count == 0 || !handicapsOK {
                            running = false
                            startDisabled = true
                            TimingMsg = "Missing handicaps - " + missingHandicaps
                            TimingMsgColor = Color.red
                        } else if startingHandicaps.count == 0 {
                            startDisabled = true
                            TimingMsg = "No riders to start"
                            TimingMsgColor = Color.black
                        } else if stopWatchManager.stopped {
                            // all grades started
                            running = false
                            startDisabled = true
                            TimingMsg = "All grades started"
                            TimingMsgColor = Color.black
                        } else {
                            // load the handicaps into the stopWatchManager
                            // only loads the handicaps that have riders in the handicapped grade
                            stopWatchManager.loadStarts(handicaps: startingHandicaps)
                            startDisabled = false
                            if running {
                                recordDisabled = false // checks are on button for handicaps still to start
                            }
                            TimingMsg = String(startingHandicaps.count) + " starting Grades"
                            TimingMsgColor = Color.black
                        }
                    case "Secret":
                        // everyone starts together
                        getUnstartedGrades()
                        if handicaps.count == 0 || !handicapsOK {
                            running = false
                            startDisabled = true
                            TimingMsg = "Missing handicaps - " + missingHandicaps
                            TimingMsgColor = Color.red
                        } else if startingHandicaps.count == 0 {
                            startDisabled = true
                            TimingMsg = "No riders to start"
                            TimingMsgColor = Color.black
                        } else if stopWatchManager.started || raceStarted {
                            startDisabled = true
    //                        stopDisabled = false
                            recordDisabled  = false
                        } else {
                            startDisabled = false
                        }
                    case "TT":
                        if peripheralPaired {
                            if stopWatchManager.started {
                                startDisabled = true
                            } else {
                                startDisabled = false
                            }
                            startDisabled = false
    //                        stopDisabled = true
                            recordDisabled  = true
                            stopWatchManager.loadTT(arrayStarters)
                            return
                        }
                        if masterPaired {
                            getUnplaced()
                            startDisabled = true
    //                        stopDisabled = false
                            recordDisabled  = false
                            TimingMsg = String(max((unplacedRiders.count - unplacedTimes()), 0)) + " riders to finish"
                            TimingMsgColor = Color.black
                            return
                        }
                        if running {    // stopWatchManager.started {
                            startDisabled = true
                        } else {
                            if arrayStarters.count == 0 {
                                startDisabled = true
                                TimingMsg = "No riders to start"
                                TimingMsgColor = Color.black
                            } else {
                                stopWatchManager.loadTT(arrayStarters)
                                startDisabled = false
                            }
                        }
                    case "Age Std":
                        TimingMsg = String(overTheLine) + " Recorded. " + String(max((unplacedRiders.count - overTheLine), 0)) + " to finish"
                        TimingMsgColor = Color.black
                        if peripheralPaired {
                            if stopWatchManager.started {
                                startDisabled = true
                            } else {
                                startDisabled = false
                            }
                            startDisabled = false
    //                        stopDisabled = true
                            recordDisabled  = true
                            stopWatchManager.loadAgeStd(arrayStarters)
                            return
                        }
                        if masterPaired {
                            getUnplaced()
                            startDisabled = true
    //                        stopDisabled = false
                            recordDisabled  = false
                            TimingMsg = String(max((unplacedRiders.count - unplacedTimes()), 0)) + " riders to finish"
                            TimingMsgColor = Color.black
                            return
                        }
                        if stopWatchManager.started || finishTimes.count > 0  {
                            startDisabled = true
                        } else {
                            if arrayStarters.count == 0 {
                                startDisabled = true
                                TimingMsg = "No riders to start"
                                TimingMsgColor = Color.black
                            } else {
                                stopWatchManager.loadAgeStd(arrayStarters)
                                startDisabled = false
                            }
                        }
                    default:
                        startDisabled = true
                    }

    //                if running && !stopWatchManager.stopped {
    //                    // TODO ???  not sure why this is here
    //                    self.stopWatchManager.restart()
    //                }
                })
                
    //            Toggle(isOn: bind) {
    //                Text("Lock")
    //                    .frame(maxWidth: .infinity, alignment: .trailing)
    //            }
    //            .frame(width:120, alignment: .center)
                    
                
                .navigationBarTitle("Timing", displayMode: .inline)
            }
            
        }
    }
    
    struct PlacesView: View {
        @State private var selectedGrade = -1
        @State var riderDetails = ""
        @State var selectedRider = Rider()
        @State var listHeight: Double = fullListHeight
        @State var displayStarters = arrayStarters
        @State var unplacedNumb = 0
        @State var unplacedSpot = 0
        @State var unplacedSpots: [FinishTime] = []
        @State var mode: EditMode = .inactive
        
        @Binding var dragEnable : Bool
        
        func move(from source: IndexSet, to destination: Int) {
            // this func is proving difficult to implement
        
            var promotion = true
            var targetGrade = ""
            var sourceGrade = ""
//            var targetPlace = -1
            var sourcePlace = -1
        
            // user drags a rider onto a target place in the list
            source.forEach { (i) in
                sourceGrade = displayStarters[i].racegrade
                sourcePlace = Int(displayStarters[i].place) ?? -1
                if i < destination {
                    promotion = false
                } else {
                    promotion = true
                }
            }
            // check if rider was DNF
            if sourcePlace == -1 {
                // don't move DNFed riders
                return
            }
            
            targetGrade = displayStarters[destination].racegrade
//            targetPlace = Int(displayStarters[destination].place) ?? -1
            
            // check if using grades
            // check if promoting or demoting
            if myConfig.stage {
                // TODO
            } else {
                // not stage race
                // is this a timed race
                if raceTypes[myConfig.raceType] == "Wheel" || raceTypes[myConfig.raceType] == "Hcp"  || raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "Secret" || raceTypes[myConfig.raceType] == "Graded" || raceTypes[myConfig.raceType] == "Age" {
                    // TODO
                } else {
                    // untimed race
                    if selectedGrade == 0 {
                        // all grades are displayed
                        if targetGrade == sourceGrade {
                            // set the place to the target and then shuffle the rest of the grade
                        } else {
                            if promotion {
                                // set the place to the 1st in grade and then shuffle the rest of the grade
                            } else {
                                // set the place to the last in grade and
                            }
                        }
                    } else {
                        // only one grade is displayed
//                        for updates in arrayStarters.indices {
//
//                        }
                    }
                }
            }
            
            displayStarters.move(fromOffsets: source, toOffset: destination)
        }
        
        func delete(at offsets: IndexSet) {
            offsets.forEach { (i) in
                self.remove(racenumber: displayStarters[i].racenumber)
                displayStarters.remove(at: i)
            }
            
        }
        
        func getUnplacedSpots()  {
            if finishTimes.count > 0 {
                unplacedSpots = []
                for i in 0...(finishTimes.count - 1) {
                    if !finishTimes[i].allocated {
                        unplacedSpots.append(finishTimes[i])
                    }
                }
            }
        }

        func nextPlace(grade: String = "") -> String {
            var place = 1
            // look through the starters to see what the next place is in that grade
            for starter in arrayStarters {
                if myConfig.stage {
                    if grade == starter.racegrade && starter.stageResults[myConfig.currentStage].place != "" {
                        // if place is DNF set to 0
                        if place <= Int(starter.stageResults[myConfig.currentStage].place) ?? 0 {
                            place = (Int(starter.stageResults[myConfig.currentStage].place) ?? 0) + 1
                        }
                    }
                } else {
                    if grade == starter.racegrade && starter.place != "" {
                        // if place is DNF set to 0
                        if place <= Int(starter.place) ?? 0 {
                            place = (Int(starter.place) ?? 0) + 1
                        }
                    }
                }
            }
            return String(place)
        }
        
        func nextPlaceByGender(gender: String = "") -> String {
            var place = 1
            // look through the starters to see what the next place is for that gender
            for starter in arrayStarters {
                if gender == starter.gender && starter.place != "" {
                    // if place is DNF set to 0
                    if place <= Int(starter.place) ?? 0 {
                        place = (Int(starter.place) ?? 0) + 1
                    }
                }
            }
            return String(place)
        }
        
        func hcpPlace() -> String {
            var place = 1
            // look through the starters to see what the next place is
            for starter in arrayStarters {
                // TODO check if used in stage - TT or Graded
                
                if starter.overTheLine != "" {
                    // if place is DNF set to 0
                    if place <= Int(starter.overTheLine) ?? 0 {
                        place = (Int(starter.overTheLine) ?? 0) + 1
                    }
                }
            }
            return String(place)
        }
        
        func remove(racenumber: String) {
            // removes a placed/ dnfed rider from the list
            var grade = ""
            var deletedPlace = 0
            for index in arrayStarters.indices {
                if racenumber == arrayStarters[index].racenumber {
                    grade = arrayStarters[index].racegrade
                    if myConfig.stage {
                        // TODO
                        if raceTypes[myConfig.raceType] == "TT" {
                            deletedPlace = Int(arrayStarters[index].stageResults[myConfig.currentStage].overTheLine) ?? 0
                        } else {
                            deletedPlace = Int(arrayStarters[index].stageResults[myConfig.currentStage].place) ?? 0
                        }
                        // return the unadjusted finishtime to the selection list
                        for i in 0...(finishTimes.count - 1) {
                            if finishTimes[i].overTheLine == Int(arrayStarters[index].stageResults[myConfig.currentStage].overTheLine) ?? 0 {
                                finishTimes[i].allocated = false
                            }
                        }
                        arrayStarters[index].stageResults[myConfig.currentStage].place = ""
                        arrayStarters[index].stageResults[myConfig.currentStage].overTheLine = ""
                        arrayStarters[index].stageResults[myConfig.currentStage].finishTime = nil //0
                        arrayStarters[index].stageResults[myConfig.currentStage].displayTime = ""
                        arrayStarters[index].stageResults[myConfig.currentStage].raceTime = 0.0
                        break
                    } else {
                        // not a stage race
                        if raceTypes[myConfig.raceType] == "Wheel" || raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "Secret" {
                            deletedPlace = Int(arrayStarters[index].overTheLine) ?? 0
                        } else {
                            deletedPlace = Int(arrayStarters[index].place) ?? 0
                        }
                        // return the unadjusted finishtime to the selection list
                        if finishTimes.count > 0 {
                            for i in 0...(finishTimes.count - 1) {
                                if finishTimes[i].overTheLine == Int(arrayStarters[index].overTheLine) ?? 0 {
                                    finishTimes[i].allocated = false
                                    break
                                }
                            }
                        }
                        arrayStarters[index].place = ""
                        arrayStarters[index].overTheLine = ""
                        arrayStarters[index].finishTime = nil
                        arrayStarters[index].displayTime = ""
                        arrayStarters[index].raceTime = 0.0
                        break
                    }
                }
            }
            // if the removed place wasn't a DNF, move up the lower places
            if deletedPlace > 0 {
                for index in arrayStarters.indices {
                    if myConfig.stage {
                        // TODO check this is OK?
                        if arrayStarters[index].racegrade == grade {
                            if Int(arrayStarters[index].stageResults[myConfig.currentStage].place) ?? 0 > deletedPlace {
                                arrayStarters[index].stageResults[myConfig.currentStage].place = String((Int(arrayStarters[index].stageResults[myConfig.currentStage].place) ?? 0) - 1)
                            }
                        }
                    } else {
                    if raceTypes[myConfig.raceType] == "Wheel" {
                        if Int(arrayStarters[index].overTheLine) ?? 0 > deletedPlace {
                            arrayStarters[index].overTheLine = String((Int(arrayStarters[index].overTheLine) ?? 0) - 1)
                        }
                    } else {
                        if arrayStarters[index].racegrade == grade {
                            if Int(arrayStarters[index].place) ?? 0 > deletedPlace {
                                arrayStarters[index].place = String((Int(arrayStarters[index].place) ?? 0) - 1)
                            }
                        }
                    }
                    }
                }
            }
            if raceTypes[myConfig.raceType] == "Crit" {
                getUnplaced(grade: self.selectedGrade)
            } else {
                getUnplaced()
            }
            getUnplacedSpots()
            riderDetails = racenumber + " unplaced"
        }
        
        func promote(racenumber: String) {
            for index in arrayStarters.indices {
                if racenumber == arrayStarters[index].racenumber {
                    if myConfig.stage {
                        if arrayStarters[index].stageResults[myConfig.currentStage].overTheLine == "DNF" {
                            arrayStarters[index].stageResults[myConfig.currentStage].overTheLine = hcpPlace()
                            return
                        }
                        // find prev place
                        arrayStarters.sort {
                            $0.stageResults[myConfig.currentStage].overTheLine < $1.stageResults[myConfig.currentStage].overTheLine
                        }
                        
                        for i in 0...(arrayStarters.count - 1) {
                            if arrayStarters[i].racenumber == racenumber {
                                let newPlace = arrayStarters[i-1].stageResults[myConfig.currentStage].overTheLine
                                let newDisplayTime = arrayStarters[i-1].stageResults[myConfig.currentStage].displayTime
                                let newFinishTime = arrayStarters[i-1].stageResults[myConfig.currentStage].finishTime
                                arrayStarters[i-1].stageResults[myConfig.currentStage].displayTime = arrayStarters[i].stageResults[myConfig.currentStage].displayTime
                                arrayStarters[i-1].stageResults[myConfig.currentStage].finishTime = arrayStarters[i].stageResults[myConfig.currentStage].finishTime
                                arrayStarters[i-1].stageResults[myConfig.currentStage].overTheLine = arrayStarters[i].stageResults[myConfig.currentStage].overTheLine
                                arrayStarters[i-1].stageResults[myConfig.currentStage].raceTime = arrayStarters[i-1].finishTime!.timeIntervalSince(arrayStarters[i-1].stageResults[myConfig.currentStage].startTime!)
                                arrayStarters[i].stageResults[myConfig.currentStage].overTheLine = newPlace
                                arrayStarters[i].stageResults[myConfig.currentStage].displayTime = newDisplayTime
                                arrayStarters[i].stageResults[myConfig.currentStage].finishTime = newFinishTime
                                arrayStarters[i].stageResults[myConfig.currentStage].raceTime = arrayStarters[i].finishTime!.timeIntervalSince(arrayStarters[i].stageResults[myConfig.currentStage].startTime!)
                                return
                            }
                        }
                            
                    } else {
                    // Non Stage race
                    // is this a timed race
                    if raceTypes[myConfig.raceType] == "Wheel" || raceTypes[myConfig.raceType] == "Hcp"  || raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "Secret" || raceTypes[myConfig.raceType] == "Graded" || raceTypes[myConfig.raceType] == "Age" {
                        if arrayStarters[index].overTheLine == "DNF" {
                            // set to the last place
                            arrayStarters[index].overTheLine = hcpPlace()
                            return
                        }
                        // find prev place
                        arrayStarters.sort {
                            Int($0.overTheLine) ?? 10000 < Int($1.overTheLine) ?? 10000
                        }
                        
                        for i in 0...(arrayStarters.count - 1) {
                            if arrayStarters[i].racenumber == racenumber {
                                let newPlace = arrayStarters[i-1].place
                                let newOverTheLine = arrayStarters[i-1].overTheLine
                                let newDisplayTime = arrayStarters[i-1].displayTime
                                let newFinishTime = arrayStarters[i-1].finishTime
                                arrayStarters[i-1].displayTime = arrayStarters[i].displayTime
                                arrayStarters[i-1].finishTime = arrayStarters[i].finishTime
                                arrayStarters[i-1].overTheLine = arrayStarters[i].overTheLine
                                arrayStarters[i-1].place = arrayStarters[i].place
                                if arrayStarters[i-1].finishTime != nil && arrayStarters[i-1].startTime != nil {
                                    arrayStarters[i-1].raceTime = arrayStarters[i-1].finishTime!.timeIntervalSince(arrayStarters[i-1].startTime!)
                                }
                                arrayStarters[i].place = newPlace
                                arrayStarters[i].overTheLine = newOverTheLine
                                arrayStarters[i].displayTime = newDisplayTime
                                arrayStarters[i].finishTime = newFinishTime
                                arrayStarters[i].raceTime = arrayStarters[i].finishTime!.timeIntervalSince(arrayStarters[i].startTime!)
                                return
                            }
                        }
                        
                    } else {
                        // untimed race
                        if arrayStarters[index].place == "DNF" {
                            arrayStarters[index].place = nextPlace(grade: arrayStarters[index].racegrade)
                            arrayStarters[index].overTheLine = ""
                            return
                        }
                        let newPlace = String((Int(arrayStarters[index].place) ?? 0) - 1)
                        // demote the rider in that place
                        for updates in arrayStarters.indices {
                            if arrayStarters[updates].racegrade == arrayStarters[index].racegrade && arrayStarters[updates].place == newPlace {
                                arrayStarters[updates].place = arrayStarters[index].place
                                arrayStarters[index].place = newPlace
                                return
                            }
                        }
                    }
                    }
                }
            }
        }
        
        func demote(racenumber: String) {
            // TODO swap finish times  ??
            for index in arrayStarters.indices {
                if racenumber == arrayStarters[index].racenumber {
                    if myConfig.stage {
                        // if the rider is last placed, set them to DNF
                        if arrayStarters[index].stageResults[myConfig.currentStage].overTheLine == lastPlace() {
                            // return the unadjusted finishtime to the selection list
                            for i in 0...(finishTimes.count - 1) {
                                if finishTimes[i].overTheLine == Int(arrayStarters[index].stageResults[myConfig.currentStage].overTheLine) ?? 0 {
                                    finishTimes[i].allocated = false
                                }
                            }
                            getUnplacedSpots()
                            arrayStarters[index].stageResults[myConfig.currentStage].place = "DNF"
                            arrayStarters[index].stageResults[myConfig.currentStage].overTheLine = "DNF"
                            arrayStarters[index].stageResults[myConfig.currentStage].finishTime = nil //0.0
                            arrayStarters[index].stageResults[myConfig.currentStage].displayTime = ""
                            sortPlaces()
                            return
                        }
                        arrayStarters.sort {
                            Int($0.stageResults[myConfig.currentStage].overTheLine) ?? 10000 < Int($1.stageResults[myConfig.currentStage].overTheLine) ?? 10000
                        }
                        
                        for i in 0...(arrayStarters.count - 1) {
                            if arrayStarters[i].racenumber == racenumber {
                                let newPlace = arrayStarters[i+1].stageResults[myConfig.currentStage].overTheLine
                                let newDisplayTime = arrayStarters[i+1].stageResults[myConfig.currentStage].displayTime
                                let newFinishTime = arrayStarters[i+1].stageResults[myConfig.currentStage].finishTime
                                arrayStarters[i+1].stageResults[myConfig.currentStage].displayTime = arrayStarters[i].stageResults[myConfig.currentStage].displayTime
                                arrayStarters[i+1].stageResults[myConfig.currentStage].finishTime = arrayStarters[i].stageResults[myConfig.currentStage].finishTime
                                arrayStarters[i+1].stageResults[myConfig.currentStage].overTheLine = arrayStarters[i].stageResults[myConfig.currentStage].overTheLine
                                arrayStarters[i+1].stageResults[myConfig.currentStage].raceTime = arrayStarters[i+1].finishTime!.timeIntervalSince(arrayStarters[i+1].stageResults[myConfig.currentStage].startTime!)
                                arrayStarters[i].stageResults[myConfig.currentStage].overTheLine = newPlace
                                arrayStarters[i].stageResults[myConfig.currentStage].displayTime = newDisplayTime
                                arrayStarters[i].stageResults[myConfig.currentStage].finishTime = newFinishTime
                                arrayStarters[i].stageResults[myConfig.currentStage].raceTime = arrayStarters[i].finishTime!.timeIntervalSince(arrayStarters[i].stageResults[myConfig.currentStage].startTime!)
                                return
                            }
                        }
                    } else {
                    // Non Stage race
                    // Is this a timed race?
                    if raceTypes[myConfig.raceType] == "Wheel"  || raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "Secret" || raceTypes[myConfig.raceType] == "Graded"  || raceTypes[myConfig.raceType] == "Age" {
                        // if the rider is last placed, set them to DNF
                        if arrayStarters[index].overTheLine == lastPlace() {
                            // return the unadjusted finishtime to the selection list
                            if finishTimes.count > 0 {
                                for i in 0...(finishTimes.count - 1) {
                                    if finishTimes[i].overTheLine == Int(arrayStarters[index].overTheLine) ?? 0 {
                                        finishTimes[i].allocated = false
                                    }
                                }
                            }
                            getUnplacedSpots()
                            sortPlaces()
                            arrayStarters[index].place = "DNF"
                            arrayStarters[index].overTheLine = "DNF"
                            arrayStarters[index].finishTime = nil //0.0
                            arrayStarters[index].displayTime = ""
                            return
                        }
                        // newPlace needs to be the next occupied place
                        arrayStarters.sort {
                            Int($0.overTheLine) ?? 10000 < Int($1.overTheLine) ?? 10000
                        }
                        
                        for i in 0...(arrayStarters.count - 1) {
                            if arrayStarters[i].racenumber == racenumber {
                                let newPlace = arrayStarters[i+1].place
                                let newOverTheLine = arrayStarters[i+1].overTheLine
                                let newDisplayTime = arrayStarters[i+1].displayTime
                                let newFinishTime = arrayStarters[i+1].finishTime
                                arrayStarters[i+1].displayTime = arrayStarters[i].displayTime
                                arrayStarters[i+1].finishTime = arrayStarters[i].finishTime
                                arrayStarters[i+1].overTheLine = arrayStarters[i].overTheLine
                                arrayStarters[i+1].place = arrayStarters[i].place
                                arrayStarters[i+1].raceTime = arrayStarters[i+1].finishTime!.timeIntervalSince(arrayStarters[i+1].startTime!)
                                arrayStarters[i].place = newPlace
                                arrayStarters[i].overTheLine = newOverTheLine
                                arrayStarters[i].displayTime = newDisplayTime
                                arrayStarters[i].finishTime = newFinishTime
                                arrayStarters[i].raceTime = arrayStarters[i].finishTime!.timeIntervalSince(arrayStarters[i].startTime!)
                                return
                            }
                        }
                    } else {
                        // Untimed race
                        // if the rider is last placed, set them to DNF
                        if arrayStarters[index].place == lastPlace(grade: arrayStarters[index].racegrade) {
                            arrayStarters[index].place = "DNF"
                            arrayStarters[index].overTheLine = "DNF"
                            arrayStarters[index].finishTime = nil //0.0
                            arrayStarters[index].displayTime = ""
                            // return the unadjusted finishtime to the selection list
                            if finishTimes.count > 0 {
                                for i in 0...(finishTimes.count - 1) {
                                    if finishTimes[i].overTheLine == Int(arrayStarters[index].overTheLine) ?? 0 {
                                        finishTimes[i].allocated = false
                                    }
                                }
                            }
                            sortPlaces()
                            return
                        }
                        let newPlace = String((Int(arrayStarters[index].place) ?? 0) + 1)
                        
                        // demote the rider in that place
                        for updates in arrayStarters.indices {
                            if arrayStarters[updates].racegrade == arrayStarters[index].racegrade && arrayStarters[updates].place == newPlace {
                                arrayStarters[updates].place = arrayStarters[index].place
                                arrayStarters[index].place = newPlace
                                return
                            }
                        }
                    }
                    }
                }
            }
        }
        
        func lastPlace(grade: String = "")  -> String {
            var count = 0
            for index in arrayStarters.indices {
                if grade == "" {
                    if arrayStarters[index].overTheLine != "DNF"  && arrayStarters[index].overTheLine != "" {
                        count = max(count, Int(arrayStarters[index].overTheLine) ?? 0)
                    }
                } else {
                    if (!myConfig.stage && (arrayStarters[index].racegrade == grade  && arrayStarters[index].place != "DNF"  && arrayStarters[index].place != "")) || (myConfig.stage && (arrayStarters[index].racegrade == grade  && arrayStarters[index].stageResults[myConfig.currentStage].place != "DNF"  && arrayStarters[index].stageResults[myConfig.currentStage].place != ""))  {
                        if raceTypes[myConfig.raceType] == "Crit" {
                            count = max(count, Int(arrayStarters[index].place) ?? 0)
                        } else {
                            count = max(count, Int(arrayStarters[index].overTheLine) ?? 0)
                        }
                    }
                }
            }
            return String(count)
        }
        
        func bestPlace(grade: String = "")  -> String {
            var count = 999  // large number to start from
            for index in arrayStarters.indices {
                if grade == "" {
                    if arrayStarters[index].overTheLine != "DNF"  && arrayStarters[index].overTheLine != "" {
                        count = min(count, Int(arrayStarters[index].overTheLine) ?? 0)
                    }
                } else {
                    if (!myConfig.stage && (arrayStarters[index].racegrade == grade  && arrayStarters[index].place != "DNF"  && arrayStarters[index].place != "")) || (myConfig.stage && (arrayStarters[index].racegrade == grade  && arrayStarters[index].stageResults[myConfig.currentStage].place != "DNF"  && arrayStarters[index].stageResults[myConfig.currentStage].place != ""))  {
                        if raceTypes[myConfig.raceType] == "Crit" {
                            count = min(count, Int(arrayStarters[index].place) ?? 0)
                        } else {
                            count = min(count, Int(arrayStarters[index].overTheLine) ?? 0)
                        }
                    }
                }
            }
            return String(count)
        }
        
        func sortPlaces() {
            if myConfig.stage {
                displayStarters = arrayStarters.sorted {
                    // stages is either TT or graded scratch
                    if $0.racegrade != $1.racegrade {
                        return $0.racegrade < $1.racegrade
                    } else {
                        // use the current stage place
                        if $0.stageResults[myConfig.currentStage].place != $1.stageResults[myConfig.currentStage].place {
                            return Int($0.stageResults[myConfig.currentStage].place) ?? 10000 < Int($1.stageResults[myConfig.currentStage].place) ?? 10000  // force DNF places to end of list
                        }
                        return $0.racenumber < $1.racenumber  // TODO not sure this should be reached
                    }
                }
                
            } else {
                displayStarters = arrayStarters.sorted {
                if raceTypes[myConfig.raceType] == "Wheel"  || raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "Secret" || raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std" || raceTypes[myConfig.raceType] == "Graded"  || raceTypes[myConfig.raceType] == "Age" {
                    return Int($0.overTheLine) ?? 10000 < Int($1.overTheLine) ?? 10000
                } else {
                    if $0.racegrade != $1.racegrade {
                        return $0.racegrade < $1.racegrade
                    }
                    else {
                        if $0.place != $1.place {
                            return Int($0.place) ?? 10000 < Int($1.place) ?? 10000  // force DNF places to end of list
                        }
                        return $0.racegrade < $1.racegrade
                    }
                }
            }
            }
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        private func displayName(rider: Rider) -> String {
            var timeTxt = ""
            if myConfig.stage {
                // only TT or Stage race
                if rider.stageResults[myConfig.currentStage].displayTime != "" {
                    timeTxt = " @ \(rider.stageResults[myConfig.currentStage].displayTime) "
                }
                return rider.racegrade + " " + rider.stageResults[myConfig.currentStage].place + timeTxt + " = " + rider.racenumber + " - " + rider.name
                
            } else {
                if raceTypes[myConfig.raceType] != "Crit" && raceTypes[myConfig.raceType] != "Wheel"{
                    if rider.displayTime != "" {
                        timeTxt = " @ \(rider.displayTime) "
                    }
                }
                // for wheel, Hcp, etc - no grade
                if raceTypes[myConfig.raceType] == "Crit" {
                    return rider.racegrade + " " + rider.place + timeTxt + " = " + rider.racenumber + " - " + rider.name
                } else {
                    return rider.overTheLine + timeTxt + " = " + rider.racenumber + " - " + rider.name
                }
            }
        }
        
        var body: some View {
            Background {
                VStack{
//                VStack{
                    List { ForEach(displayStarters , id: \.racenumber) { rider in   //
                        if (!myConfig.stage && (rider.place != "" || rider.overTheLine != "")  &&
                            // show all riders for non crits  or Either show all riders or restrict by grade
                            ((raceTypes[myConfig.raceType] != "Crit") || (self.selectedGrade == -1 || (self.selectedGrade != -1 && startingGrades[self.selectedGrade] == rider.racegrade)) )
                            ) ||
                            (myConfig.stage && (rider.stageResults[myConfig.currentStage].place != "" || rider.stageResults[myConfig.currentStage].overTheLine != ""))  {
                            HStack{
                                Text(displayName(rider: rider))
                                Spacer()
                                
                                if mode == EditMode.active {
                                // Promote button
                                Button(action: {
                                    promote(racenumber: rider.racenumber)
                                    riderDetails = rider.racenumber + " promoted"
                                    sortPlaces()
                                }) {
                                    Image(systemName: "arrow.up")
                                        .padding()
                                        .foregroundColor(.black)
                                    }
                                    // don't allow DNFed riders in timed events to be promoted
                                .disabled((!myConfig.stage && ((rider.place == bestPlace(grade: rider.racegrade) && raceTypes[myConfig.raceType] == "Crit") || rider.overTheLine == bestPlace() || (rider.place == "DNF" && raceTypes[myConfig.raceType] != "Crit"))) ||
                                        (myConfig.stage && (rider.stageResults[myConfig.currentStage].overTheLine == bestPlace()) || rider.stageResults[myConfig.currentStage].place == "DNF"))
                                .background((!myConfig.stage && ( (rider.place == bestPlace(grade: rider.racegrade) && raceTypes[myConfig.raceType] == "Crit") || rider.overTheLine == bestPlace() || (rider.place == "DNF" && raceTypes[myConfig.raceType] != "Crit"))) ||
                                        (myConfig.stage && (rider.stageResults[myConfig.currentStage].overTheLine == bestPlace()  || rider.stageResults[myConfig.currentStage].place == "DNF")) ? Color.gray : Color.green)
                                    .frame(width: 40, height: 50)
                                    .cornerRadius(10)
                                    .buttonStyle(PlainButtonStyle())
                                
                                // Demote button
                                Button(action: {
                                    demote(racenumber: rider.racenumber)
                                    riderDetails = rider.racenumber + " demoted"
                                    sortPlaces()
                                }) {
                                    Image(systemName: "arrow.down")
                                        .padding()
                                        .foregroundColor(.black)
                                    }
                                    .disabled((!myConfig.stage && (rider.place == "DNF" || rider.overTheLine == "DNF")) ||
                                        (myConfig.stage && (rider.stageResults[myConfig.currentStage].place == "DNF" || rider.stageResults[myConfig.currentStage].overTheLine == "DNF")))
                                    .frame(width: 40, height: 50)
                                    .background((!myConfig.stage && (rider.place == "DNF" || rider.overTheLine == "DNF")) ||
                                        (myConfig.stage && (rider.stageResults[myConfig.currentStage].place == "DNF" || rider.stageResults[myConfig.currentStage].overTheLine == "DNF")) ? Color.gray : Color.yellow)
                                    .cornerRadius(10)
                                    .buttonStyle(PlainButtonStyle())
                                
                                // Remove button - superceeded by edit - delete
//                                Button(action: {
//                                    remove(racenumber: rider.racenumber)
//                                    riderDetails = rider.racenumber + " removed from placings"
//                                    sortPlaces()
//                                }) {
//                                    Image(systemName: "bin.xmark") //Text("X")
//                                        .padding()
//                                        .foregroundColor(.black)
//                                    }
//                                    .frame(width: 40, height: 50)
//                                    .background(Color.red)
//                                    .cornerRadius(10)
//                                    .buttonStyle(PlainButtonStyle())
                                }
                            }  // end HStack
                    }
                }
                    //.onMove(perform: move)
                    .onDelete(perform: delete)
                }
                .listStyle(PlainListStyle())
                .toolbar {
                    EditButton()
                }
                .environment(\.editMode, $mode)
                .onChange(of: mode, perform: {value in
                    if value == .active {
                        // in edit mode
                        dragEnable = false
                    } else {
                        dragEnable = true
                    }
                })
//                }
                .onAppear(perform: {
                    initStageResults()
                    sortPlaces()
                })
                .frame(height: CGFloat(listHeight))
                
                HStack {
                    VStack {
                        Text(riderDetails)
                        HStack {  // for place and rider pickers
                            if raceTypes[myConfig.raceType] != "Crit" && raceTypes[myConfig.raceType] != "Wheel" {
                                // show the over the line places and times recorded in the Timer
                                Picker(selection: $unplacedSpot, label : Text("000")) {
                                    ForEach(0 ..< unplacedSpots.count, id:\.self) {
                                        Text(unplacedSpots[$0].displayTime)
                                    }
                                }
                                .id(UUID())
                                .frame(width: 190)
                                .clipped()
                            } else if raceTypes[myConfig.raceType] == "Crit" {
                                // show grades to select riders from plus one with all riders
                                Picker(selection: Binding(
                                        get: {self.selectedGrade},
                                        set: {self.selectedGrade = $0
                                            getUnplaced(grade: self.selectedGrade)
                                            unplacedNumb = 0
                                            // only display placed list for that grade
                                        }), label : Text("")){
                                    
                                    ForEach(-1 ..< startingGrades.count, id:\.self) {
                                        if $0 == -1 {
                                            Text("All")
                                        } else {
                                            Text(startingGrades[$0])
                                        }
                                    }
                                }
                                .id(UUID())
                                .frame(width: 50)
                                .clipped()
                            }
                            
                            Picker("Rider", selection: $unplacedNumb) {
                                ForEach(0 ..< unplacedRiders.count, id:\.self) {
                                   Text(unplacedRiders[$0])
                                }
                            }
                            .id(UUID())
                            .frame(width: 60)
                            .clipped()
                        }
                        .padding(.top, 10)
                    }
                    
                    VStack {  // Place and DNF buttons
                        
                    // Place Button
                    Button(action: {
                        
                        if myConfig.stage {
                            AudioServicesPlaySystemSound(SystemSoundID(buttonSound))
                            // get the finishTime
                            var t: FinishTime = FinishTime()
                            
                            let x = unplacedSpot
                            var pointer = 0
                            for finishTime in finishTimes {
                                if !finishTime.allocated {
                                    if pointer == x {
                                    t = finishTime
                                    } else {
                                        pointer = pointer + 1
                                    }
                                }
                            }
                            
                            // assign race no. and time
                            for index in arrayStarters.indices {
                                if unplacedRiders[unplacedNumb] == arrayStarters[index].racenumber {
                                    if raceTypes[myConfig.raceType] == "TT" {
                                        arrayStarters[index].stageResults[myConfig.currentStage].overTheLine = hcpPlace()
                                        riderDetails = arrayStarters[index].stageResults[myConfig.currentStage].overTheLine
                                        arrayStarters[index].stageResults[myConfig.currentStage].finishTime = t.time
                                        arrayStarters[index].stageResults[myConfig.currentStage].raceTime = t.time!.timeIntervalSince(arrayStarters[index].stageResults[myConfig.currentStage].startTime!)
                                    } else if raceTypes[myConfig.raceType] == "Graded" {
                                        arrayStarters[index].stageResults[myConfig.currentStage].place = nextPlace(grade: arrayStarters[index].racegrade)
                                        riderDetails = arrayStarters[index].stageResults[myConfig.currentStage].place
                                        for grade in startedGrades {
                                            if arrayStarters[index].racegrade == grade.racegrade {
                                                arrayStarters[index].stageResults[myConfig.currentStage].startTime = grade.startTime!
                                                arrayStarters[index].stageResults[myConfig.currentStage].raceTime =
                                                    t.time!.timeIntervalSince(grade.startTime!)
                                                arrayStarters[index].stageResults[myConfig.currentStage].finishTime = t.time
                                                arrayStarters[index].stageResults[myConfig.currentStage].overTheLine = String(t.overTheLine)
                                                break
                                            }
                                        }
                                        t.allocated = true
                                    }
                                    t.allocated = true
//                                    unplacedSpots.remove(at: unplacedSpot)
//                                    unplacedSpots.sort()
                                    unplacedSpot = 0  // need to reset picker index after updating array
                                    // check that there is a finish time
                                    if arrayStarters[index].stageResults[myConfig.currentStage].finishTime != nil {
                                        arrayStarters[index].stageResults[myConfig.currentStage].displayTime = dateAsTime(arrayStarters[index].stageResults[myConfig.currentStage].finishTime!)}
                                    riderDetails = arrayStarters[index].racenumber + " placed " + riderDetails
                                    getUnplaced()
                                    getUnplacedSpots()
                                    unplacedNumb = max(0, unplacedNumb - 1)  // need to reset picker index after updating array
                                    break
                                }
                            }
                            sortPlaces()
                            
                        } else {
                        // non-stage event
                        // find the rider in arrayStarters and set place to next place
                        if raceTypes[myConfig.raceType] == "Crit" {
                            // Crit race - no timings
                            for index in arrayStarters.indices {
                                // TODO next line is throwing index out of range errors
                                if unplacedRiders[unplacedNumb] == arrayStarters[index].racenumber {
                                    arrayStarters[index].place = nextPlace(grade: arrayStarters[index].racegrade)
                                    riderDetails = arrayStarters[index].racenumber + " placed " + arrayStarters[index].place
                                    getUnplaced(grade: self.selectedGrade)
                                    unplacedNumb = max(0, unplacedNumb - 1)
                                    break
                                }
                            }
                            sortPlaces()
                        } else if raceTypes[myConfig.raceType] == "Wheel" {
                            // Wheel race - no timings, no grades
                            for index in arrayStarters.indices {
                                if unplacedRiders[unplacedNumb] == arrayStarters[index].racenumber {
                                    arrayStarters[index].overTheLine = hcpPlace()
                                    // arrayStarters[index].place = nextPlace(grade: arrayStarters[index].racegrade)
                                    riderDetails = arrayStarters[index].racenumber + " placed " + arrayStarters[index].overTheLine
                                    getUnplaced()
                                    getUnplacedSpots()
                                    unplacedNumb = max(0, unplacedNumb - 1)
                                    break
                                }
                            }
                            sortPlaces()
                        } else {
                            // get the finishTime
                            var t: FinishTime = FinishTime()
                            for i in 0...(finishTimes.count - 1) {
                                if !finishTimes[i].allocated && unplacedSpots.count > 0 {
                                    if unplacedSpots[unplacedSpot].displayTime == finishTimes[i].displayTime {
                                        t = finishTimes[i]
                                        finishTimes[i].allocated = true
                                        unplacedSpots.remove(at: unplacedSpot)
                                        break
                                    }
                                }
                            }
                            
                            // assign race no. and time
                            for index in arrayStarters.indices {
                                if unplacedRiders[unplacedNumb] == arrayStarters[index].racenumber {
                                    if raceTypes[myConfig.raceType] == "Hcp" {
                                        arrayStarters[index].overTheLine = String(t.overTheLine)
                                        riderDetails = arrayStarters[index].overTheLine
                                        arrayStarters[index].finishTime = t.time
                                        arrayStarters[index].raceTime = t.time!.timeIntervalSince(arrayStarters[index].startTime!)
                                    } else if raceTypes[myConfig.raceType] == "TT" {
                                        arrayStarters[index].overTheLine = String(t.overTheLine)
                                        riderDetails = arrayStarters[index].overTheLine
                                        arrayStarters[index].finishTime = t.time
                                        // start times are not set on master of paired devices
                                        if !masterPaired {
                                            arrayStarters[index].raceTime = t.time!.timeIntervalSince(arrayStarters[index].startTime!)
                                        }
                                    } else if raceTypes[myConfig.raceType] == "Age Std" {
                                        arrayStarters[index].overTheLine = String(t.overTheLine)
                                        riderDetails = arrayStarters[index].overTheLine
                                        arrayStarters[index].finishTime = t.time
                                        // start times are not set on master of paired devices
                                        if !masterPaired {
                                            arrayStarters[index].raceTime = t.time!.timeIntervalSince(arrayStarters[index].startTime!)
                                        }
                                        arrayStarters[index].place = nextPlaceByGender(gender: arrayStarters[index].gender)
                                    } else if raceTypes[myConfig.raceType] == "Secret" {
                                        arrayStarters[index].overTheLine = String(t.overTheLine)
                                        riderDetails = arrayStarters[index].overTheLine
                                        arrayStarters[index].finishTime = t.time
                                        for grade in startedGrades {
                                            if arrayStarters[index].racegrade == grade.racegrade {
                                                var dateComponent = DateComponents()
                                                // TODO check if this needs to be split to minutes and seconds - seems OK
                                                dateComponent.second = handicapSecForGrade(grade: arrayStarters[index].racegrade)
                                                
                                                // need start time
                                                arrayStarters[index].startTime = Calendar.current.date(byAdding: dateComponent, to: grade.startTime!)
                                                
                                                arrayStarters[index].raceTime = t.time!.timeIntervalSince(arrayStarters[index].startTime!)
                                                break
                                            }
                                        }
                                    } else if raceTypes[myConfig.raceType] == "Graded" || raceTypes[myConfig.raceType] == "Age" {
                                        // set places in Results
                                        arrayStarters[index].place = nextPlace(grade: arrayStarters[index].racegrade)
                                        riderDetails = arrayStarters[index].racegrade + " " + arrayStarters[index].place
                                        for grade in startedGrades {
                                            if arrayStarters[index].racegrade == grade.racegrade {
                                                arrayStarters[index].startTime = grade.startTime!
                                                arrayStarters[index].raceTime =
                                                    t.time!.timeIntervalSince(grade.startTime!)
                                                arrayStarters[index].finishTime = t.time
                                                arrayStarters[index].overTheLine = String(t.overTheLine)
                                                break
                                            }
                                        }
                                        t.allocated = true
                                    }
                                    t.allocated = true
//                                    unplacedSpots.remove(at: unplacedSpot)
//                                    unplacedSpots.sort()
                                    unplacedSpot = 0  // need to reset picker index after updating array
                                    if arrayStarters[index].finishTime != nil {
                                        arrayStarters[index].displayTime = dateAsTime(arrayStarters[index].finishTime!)  // TODO Check for abort
                                    }
                                    riderDetails = arrayStarters[index].racenumber + " placed " + riderDetails
                                    getUnplaced()
                                    getUnplacedSpots()
                                    unplacedNumb = max(0, unplacedNumb - 1)  // need to reset picker index after updating array
                                    break
                                }
                            }
                            sortPlaces()
                        }
                        }
                     }) {
                        Text("Place")
                            .padding()
                            .foregroundColor(.black)
                        }
                        // TODO ????  For non Crits - don't allow placing until the timer is stopped
                    
                    .disabled(unplacedRiders.count == 0 || ((raceTypes[myConfig.raceType] != "Crit" && raceTypes[myConfig.raceType] != "Wheel") && unplacedTimes() == 0))
                        .frame(width: 80, height: 50, alignment: .leading)
                    .background(unplacedRiders.count == 0 || ((raceTypes[myConfig.raceType] != "Crit" && raceTypes[myConfig.raceType] != "Wheel") && unplacedTimes() == 0) ? Color.gray : Color.green)
                        .cornerRadius(10)
                        
                    // DNF button
                    Button(action: {
                        // find the rider in arrayStarters and set place to dnf
                        for index in arrayStarters.indices {
                            if unplacedRiders[unplacedNumb] == String(arrayStarters[index].racenumber) {
                                if myConfig.stage {
                                    arrayStarters[index].stageResults[myConfig.currentStage].place = "DNF"
                                    arrayStarters[index].stageResults[myConfig.currentStage].overTheLine = "DNF"
                                } else {
                                    arrayStarters[index].place = "DNF"
                                    arrayStarters[index].overTheLine = "DNF"
                                }
                                riderDetails = arrayStarters[index].racenumber + " DNFed"
                                unplacedRiders.remove(at: unplacedNumb)
                                unplacedNumb = max(0, unplacedNumb - 1)  // need to reset picker index after updating array
                                break
                            }
                        }
                        sortPlaces()
                    }) {
                        Text("DNF")
                            .padding()
                            .foregroundColor(.black)
                        }
                        .disabled(unplacedRiders.count == 0)
                        .frame(width: 80, height: 50, alignment: .leading)
                        .background(unplacedRiders.count == 0 ? Color.gray : Color.yellow)
                        .cornerRadius(10)
                    }  // end VStack of two buttons
                }
                .padding(.top, 5)
                } // end VStack
            }
            
//            .onTapGesture {  // closes the keyboard when user taps on background
//                self.endEditing()
//                listHeight = fullListHeight
//            }
            .onAppear(perform: {
                getUnplaced()
                getUnplacedSpots()
            })
            .navigationBarTitle("Places", displayMode: .inline)
        }
    }
    
    struct TestView: View  {
        @State var displayStarters = ["x","y","z"]
        
        func move(from source: IndexSet, to destination: Int) {
            // do stuff
            displayStarters.move(fromOffsets: source, toOffset: destination)
        }
        
        func delete(at offsets: IndexSet) {
            offsets.forEach { (i) in
               displayStarters.remove(at: i)
            }
        }
        
        var body: some View {
            NavigationView {
                List { ForEach(displayStarters , id: \.self) { rider in   //
                        Text(rider)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
                .listStyle(PlainListStyle())
                
                .frame(width: CGFloat(300), height: CGFloat(300)  )
            }
            .toolbar {
                EditButton()
            }
            .navigationBarTitle("Test", displayMode: .inline)
        }
    }

    
    struct StagesView: View {
        @State private var selectedGrade = 0
        @State var selectedStage = 0  // needs to be a state variable for the selector
        @State var selectedPrime = -1  // default for sprint
        @State var bonusType = 0
        @State var bonusRiderNumb = 0
        @State var bonusTxt = ""
        @State var bonus = 0
        @State var showBonuses = false
        @State var filteredBonuses: [StageBonus] = []
        @State var result = ""
        @State var points = ""
        @State var outputPlace = ""
        @State var displayTime = ""
        
        @State var riderList: [String] = []
        
        func checkBonus(_ value: String) {
            bonusTxt = String(bonusTxt.prefix(3))
            let filtered = bonusTxt.filter { $0.isNumber }
            if bonusTxt != filtered {
                bonusTxt = filtered
            }
            bonus = (Int(bonusTxt) ?? 0)
        }
        
        private func endEditing() {
            UIApplication.shared.endEditing()
        }
        
        private func filterBonuses() {
            filteredBonuses =  bonuses.filter {$0.stage == self.selectedStage && $0.prime == self.selectedPrime && $0.raceGrade == self.selectedGrade }
        }
        
        func deleteBonus(racenumber: String) {
            for index in bonuses.indices {
                if racenumber == bonuses[index].racenumber && bonuses[index].prime == self.selectedPrime && bonuses[index].stage == self.selectedStage {
                    bonuses.remove(at: index)
                    break
                }
            }
        }
        
        var body: some View {
            Background {
            VStack {
                if !myConfig.stage {
                    Text("Not a Stage race")
                } else {
                    HStack {
                        Text("Stage")
                        Picker(selection: Binding(
                                get: {self.selectedStage},
                                set: {self.selectedStage = $0
                                    myConfig.currentStage = $0
                                    myConfig.raceType = myConfig.stages[myConfig.currentStage].type
                                    reset = true
                                }),
                                label : Text("")){
                            ForEach(0 ..< myConfig.stages.count, id:\.self) {
                                Text(String($0 + 1))
                            }
                        }
                        .frame(width:30)
                        .clipped()
                        .id(UUID())
                        
                        Picker(selection: Binding(
                                get: {self.selectedGrade},
                                set: {self.selectedGrade = $0
                                    riderList = getRiders(grade: self.selectedGrade)
                                    bonusRiderNumb = 0
                                    filterBonuses()
                                }), label : Text("")){

                            ForEach(0 ..< startingGrades.count, id:\.self) {
                                Text(startingGrades[$0])
                            }
                        }
                        .id(UUID())
                        .frame(width: 30)
                        .clipped()

                        
                        if myConfig.stages[self.selectedStage].type == 0 {
                            Toggle(isOn: $showBonuses) {
                                Text("Bonus")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .frame(width:130, alignment: .center)
                        }
                    }

                    if myConfig.stages[self.selectedStage].type == 0 && showBonuses {
//                        HStack {
//                            Picker(selection: Binding(
//                                get: {self.bonusType},
//                                set: {self.bonusType = $0
//                                    filterBonuses()
//                                    if $0 == 0 {
//                                        self.selectedPrime = -1
//                                    }
//                                }), label : Text("")){
//                                    ForEach(0 ..< bonusTypes.count) {
//                                    Text(bonusTypes[$0])
//                                }
//                            }
//                            .frame(width: 110, height: 80)
//                            .clipped()
////                            .pickerStyle(RadioGroupPickerStyle())
//                        }

                        HStack {
                            Picker(selection: Binding(
                                get: {self.bonusType},
                                set: {self.bonusType = $0
                                    filterBonuses()
                                    if $0 == 0 {
                                        self.selectedPrime = -1
                                    }
                                }), label : Text("")){
                                    ForEach(0 ..< bonusTypes.count, id:\.self) {
                                    Text(bonusTypes[$0])
                                }
                            }
                            .frame(width: 110, height: 80)
                            .clipped()
                            
                            if bonusType == 1 && myConfig.stages[self.selectedStage].numbPrimes  > 0 {
                                Picker("Prime", selection: $selectedPrime) {
                                    ForEach(1 ..< myConfig.stages[self.selectedStage].numbPrimes + 1, id:\.self) {
                                        Text(String($0))
                                    }
                                }
                                .id(UUID())
                                .frame(width: 50)
                                .clipped()
                            }
                            
                            Picker("Rider", selection: $bonusRiderNumb) {
                                ForEach(0 ..< riderList.count, id:\.self) {
                                    Text(riderList[$0])
                                }
                            }
                            .id(UUID())
                            .frame(width: 50)
                            .clipped()

                            VStack {
                                Text("Sec:")
                                .frame(width: 45.0, alignment: .leading)
                                TextField("000", text: $bonusTxt)
                                //.font(Font.system(size: 60, design: .default))
                                .frame(width: 45.0)
                                .keyboardType(.numberPad)
                                .onChange(of: bonusTxt, perform: checkBonus)
                                Text(" ")  // force the time up in line
                            }

                            Button(action: {
                                // do some checks to see this isn't a duplicate
                                for existingBonus in bonuses {
                                    if existingBonus.racenumber == riderList[bonusRiderNumb] && existingBonus.stage == self.selectedStage
                                        && ((existingBonus.type == 1 && existingBonus.prime == selectedPrime) || (existingBonus.type == 0)){
                                        return
                                    }
                                }
                                
                                // store the bonus
                                var newBonus = StageBonus()
                                newBonus.stage = self.selectedStage
                                newBonus.racenumber = riderList[bonusRiderNumb]
                                newBonus.raceGrade = self.selectedGrade
                                newBonus.prime = selectedPrime
                                newBonus.bonus = bonus
                                newBonus.id = String(newBonus.stage) + newBonus.racenumber + String(newBonus.prime)
                                bonuses.append(newBonus)
                                filterBonuses()
                                bonusTxt = ""  // reset bonus
                            }) {
                                Text("Add")
                                    .padding()
                                    .foregroundColor(.black)
                                }
            //                .disabled( )
                                .background(Color.green)
                                .frame(width: 70, height: 40)
                                .cornerRadius(10)
                                .buttonStyle(PlainButtonStyle())

                        }  // end HStack
                    
                        List { ForEach(filteredBonuses, id: \.id) { listBonus in   //
                            // filter by Stage & Grade @ prime
                            if listBonus.stage == self.selectedStage && listBonus.prime == self.selectedPrime {
                                HStack {
                                    Text(listBonus.racenumber + " : " + String(listBonus.bonus))
                                    Spacer()
                                    Button(action: {
                                        deleteBonus(racenumber: listBonus.racenumber)
                                        filterBonuses()
                                    }) {
                                        Text("Remove")
                                            .padding()
                                            .foregroundColor(.black)
                                        }
                                        .frame(width: 100, height: 30, alignment: .leading)
                                        .background(Color.yellow)
                                        .cornerRadius(10)
                                        .buttonStyle(PlainButtonStyle())
                                }
                            } // end if
                            }
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        Text(result)
                        Button(action: {
                            // Export the stage results as file
                            var csvString = "\("Number")\t\("Surname")\t\("Firstname")\t\("Grade")\t\("Race Grade")\t\("Position")\t\("Time")"
                            for stage in myConfig.stages {
                                csvString = csvString.appending("\(raceTypes[stage.type])\t")
                                if stage.type == 0 {  // graded scratch
                                    for i in 1...stage.numbPrimes {
                                        csvString = csvString.appending("Prime \(i)\t")
                                    }
                                    csvString = csvString.appending("Sprint\t")
                                }
                            }
                                
                            csvString =  csvString + "\n"
                            
                            for starter in setStageResults() {
                                // reset values
                                displayTime = ""
                                
                                csvString = csvString.appending("\(starter.racenumber)\t\(starter.surname)\t\(starter.givenName)\t\("")\t\("")\t\("")\t\(starter.racegrade)\t\(outputPlace)\t\(displayTime)\t\(points)")
                                
                                for i in 0...starter.stageResults.count-1 {
                                    csvString = csvString.appending("\(starter.stageResults[i].raceTime)\t")
                                    let riderBonuses = bonuses.filter {$0.stage == i && $0.racenumber == starter.racenumber}
                                    if riderBonuses.count == 0 {
                                        if myConfig.stages[i].type == 0 {  // graded scratch
                                            for _ in 1...myConfig.stages[i].numbPrimes {
                                                csvString = csvString.appending("\t")  // prime
                                            }
                                            csvString = csvString.appending("\t")  // Sprint
                                        }
                                    } else {
                                        // primes
                                        for j in 0...myConfig.stages[i].numbPrimes-1 {
                                            var append = "\t"
                                            for riderBonus in riderBonuses {
                                                if riderBonus.type == 0 && riderBonus.prime == j {
                                                    append = "\(riderBonus.bonus)\t"
                                                    break
                                                }
                                            }
                                            csvString = csvString.appending(append)  // prime
                                        }
                                        // sprint
                                        var sprintAppend = "\t"
                                        for riderBonus in riderBonuses {
                                            if riderBonus.type == 1 {
                                                sprintAppend = "\(riderBonus.bonus)\t"
                                                break
                                            }
                                        }
                                        csvString = csvString.appending(sprintAppend)  // prime
                                    }
                                }
                                
                                csvString =  csvString + "\n"
                            }
                            
                            let fileManager = FileManager.default
                            var newName = myConfig.raceDate.replacingOccurrences(of: "/", with: " ")
                            newName = newName.replacingOccurrences(of: ":", with: " ")
                            do {
                                let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
                                // name file after race
                                let fileURL = path.appendingPathComponent("Stages " + newName + ".csv")
                                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                                result = "Result written: " + "Stages " + newName + ".csv"
                            } catch {
                                result = "Error creating file: " + "Stages " + newName + ".csv   Error: \(error)"
                            }
                        }) {
                            Text("Export")
                                .padding()
                                .foregroundColor(.black)
                        }
                        .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding(.bottom, 10)
                        
                    } // end if
                }  // end else
            }
            .onAppear(perform: {
                riderList = getRiders(grade: 0)
                selectedStage = myConfig.currentStage
                filterBonuses()
            })
            
            .navigationBarTitle("Stages", displayMode: .inline)
            }  // end background
            .onTapGesture {
                self.endEditing()
            }
        }  // end view
    }
    
    struct ResultsView: View {
        @State var displayStarters = arrayStarters
        @State var exportEnabled = true
        @State var result = ""
        @State var outputPlace = ""
        // @State var overTheLine = ""
        @State var displayTime = ""
        @State var time = ""
        @State var points = ""
        @State var surname = ""
        @State var givenName = ""
        var riderDetails = ""
        
        private func hcpDisplayTime(rider: Rider) -> String {
            return doubleAsTime(rider.raceTime) + " (" + handicapForGrade(grade: rider.racegrade) + ")"
        }
        
        private func formDetails(rider: Rider) -> String {
            // formats the results list based on race type
            if rider.racegrade == directorGrade || rider.racegrade == marshalGrade {
                return rider.racegrade + " = " + rider.racenumber + " - " + rider.name
            }
            if myConfig.stage {
                if rider.place == "DNF" {
                    return rider.racegrade + " " + rider.place  + " = " + rider.racenumber + " - " + rider.name
                }
                return rider.racegrade + " " + rider.place + " @ " + doubleAsTime(rider.raceTime)  + " = " + rider.racenumber + " - " + rider.name
            }
            switch raceTypes[myConfig.raceType] {
                case "Graded", "Age", "TT":
                    // display adjusted time
                    if rider.place == "DNF" {
                        return rider.racegrade + " " + rider.place  + " = " + rider.racenumber + " - " + rider.name
                    }
                    return rider.racegrade + " " + rider.place + " @ " + doubleAsTime(rider.raceTime)  + " = " + rider.racenumber + " - " + rider.name
                case "Hcp":
                    // adjust the display time with the handicap
                    if rider.place == "DNF" {
                        return rider.place + " = " + rider.racenumber + " - " + rider.name
                    }
                    return rider.overTheLine + " @ " + doubleAsTime(rider.raceTime) + " (" + handicapForGrade(grade: rider.racegrade) + ") " + " = " + rider.racenumber + " - " + rider.name
                case "Wheel":
                    if rider.overTheLine == "DNF" {
                        return rider.overTheLine + " = " + rider.racenumber + " - " + rider.name
                    }
                    return rider.overTheLine + " @ " + " (" + handicapForGrade(grade: rider.racegrade) + ") " + " = " + rider.racenumber + " - " + rider.name
                case "Secret":
                    if rider.place == "DNF" {
                        return rider.place  + " = " + rider.racenumber + " - " + rider.name
                    }
                    return rider.place + " @ " + doubleAsTime(rider.raceTime) + " (" + handicapForGrade(grade: rider.racegrade) + ") " + " = " + rider.racenumber + " - " + rider.name
                case "Age Std":
                    // work out race time (fin - start) and diff with std
                    // then set places smallest to biggest
                    if rider.place == "DNF" {
                        return rider.place + " = " + rider.racenumber + " - " + rider.name
                    }
                    return rider.gender + rider.place + " @ " + doubleAsTime(rider.raceTime)  + "(" + doubleAsTime(rider.raceTime - getStd(age: rider.age, dist: myConfig.TTDist, gender: rider.gender)) + ") = " + rider.racenumber + " - " + rider.name
                default:  // Crit
                    return rider.racegrade + " " + rider.place + " = " + rider.racenumber + " - " + rider.name
                }
        }
        
        struct DetailView: View {
            var body: some View {
                Text("Detail")
            }
        }
        
        var body: some View {
            VStack {
                // TODO check if there is a race director?
                
                // list of riders
                List { ForEach(displayStarters, id: \.id) { rider in
                    Text(formDetails(rider: rider))
                    .foregroundColor(rider.place == "" && rider.overTheLine == "" && (rider.racegrade != directorGrade && rider.racegrade != marshalGrade) ? Color.red : Color.black)
                    }
                }
                .listStyle(PlainListStyle())
                Text(result)
                Button(action: {
                    // Export the results for RMS as file
                    // Insert the race date.  This is checked by RMS
                    var csvString = "km) - " + myConfig.raceDate + "\n\n"  // RMS expects this format from SORS
                    // headers in 4th row
                    csvString = csvString + "\("ID")\t\("Number")\t\("Surname")\t\("Firstname")\t\("Grade")\t\("Subgrade")\t\("Criterium")\t\("Race Grade")\t\("Position")\t\("OverTheLine")\t\("Time")\t\("Points")\t\("AVCCNumber")\t\("DOB")\t\("Gender")\t\("Street")\t\("Suburb")\t\("State")\t\("Postcode")\t\("Home Phone")\t\("Work or Mobile")\t\("Email")\t\("First Aid")\t\("Emergency Contact")\t\("Emergency Contact No")\t\("Emergency Contact No2")\t\("Comment")\t\("Preentered")\n"
                    
                    // DNFs = place 10000 in RMS
                    for starter in displayStarters {
                        // reset values
                        surname = ""
                        givenName = ""
                        displayTime = ""
                        // allocate points
                        if starter.place == "" && starter.overTheLine == "" {
                            outputPlace = ""
                            points = ""
                            if starter.racegrade == directorGrade {
                                outputPlace = "10000"
                                points = "20"
                            } else if starter.racegrade == marshalGrade {
                                outputPlace = "10000"
                                points = "10"
                            }
                        } else if starter.place == "DNF" || starter.overTheLine == "DNF" {
                            outputPlace = "10000"
                            if !myConfig.championship {
                                points = "1"
                            } else {
                                points = "0"
                            }
                        } else if Int(starter.racenumber) ?? 700 > 699 {
                            // no points for visitors
                            outputPlace = starter.place
                            points = "0"
                            surname = starter.surname
                            givenName = starter.givenName
                            if raceTypes[myConfig.raceType] == "Wheel" {
                                displayTime = "(" + handicapForGrade(grade: starter.racegrade) + ")"
                            } else if raceTypes[myConfig.raceType] == "Hcp" {
                                displayTime = hcpDisplayTime(rider: starter)
                            } else if myConfig.stage || raceTypes[myConfig.raceType] == "Graded" {
                                displayTime = doubleAsTime(starter.raceTime)
                            } else {
                                displayTime = starter.displayTime
                            }
                        } else if myConfig.championship {
                            points = "0"
                            outputPlace = starter.place
                        } else {
                            // point allocation is based on number of riders in a grade
                            var raceType = raceTypes[myConfig.raceType]
                            if myConfig.stage {
                                // user graded style point allocations for stages
                                raceType = "Graded"
                            }
                            switch raceType {
                            case "Graded", "Crit":
                                // 6 or more starters 10, 8, 6, 4, 3, 2, 2 ...
                                // 5 starters 8, 6, 4, 3, 2
                                // 4 starters 6, 4, 3, 2
                                // 3 starters 4, 3, 2
                                // 2 starters 3, 2
                                // 1 starter 2
                                outputPlace = starter.place
                                if raceTypes[myConfig.raceType] == "Graded" {
                                    displayTime = doubleAsTime(starter.raceTime)
                                }
                                var cntr = 0
                                for countStarter in displayStarters {
                                    if countStarter.racegrade == starter.racegrade {
                                        cntr = cntr + 1
                                    }
                                }
                                switch cntr {
                                case 1:
                                    points = "2"
                                case 2:
                                    let arrayPoints = ["3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 3:
                                    let arrayPoints = ["4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 4:
                                    let arrayPoints = ["6","4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 5:
                                    let arrayPoints = ["8","6","4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                default:
                                    // 6 or more
                                    if (Int(starter.place) ?? 0) > 5 {
                                        points = "2"
                                    } else {
                                        let arrayPoints = ["10","8","6","4","3"]
                                        points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                    }
                                }
                            case "TT":
                                // 6 or more starters 10, 8, 6, 4, 3, 2, 2 ...
                                // 5 starters 8, 6, 4, 3, 2
                                // 4 starters 6, 4, 3, 2
                                // 3 starters 4, 3, 2
                                // 2 starters 3, 2
                                // 1 starter 2
                                outputPlace = starter.place
                                var cntr = 0
                                for countStarter in displayStarters {
                                    if countStarter.racegrade == starter.racegrade {
                                        cntr = cntr + 1
                                    }
                                }
                                switch cntr {
                                case 1:
                                    points = "2"
                                case 2:
                                    let arrayPoints = ["3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 3:
                                    let arrayPoints = ["4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 4:
                                    let arrayPoints = ["6","4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 5:
                                    let arrayPoints = ["8","6","4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                default:
                                    // 6 or more
                                    if (Int(starter.place) ?? 0) > 5 {
                                        points = "2"
                                    } else {
                                        let arrayPoints = ["10","8","6","4","3"]
                                        points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                    }
                                }
                                displayTime = doubleAsTime(starter.raceTime)
                            case "Age Std":
                                // 6 or more starters 10, 8, 6, 4, 3, 2, 2 ...
                                // 5 starters 8, 6, 4, 3, 2
                                // 4 starters 6, 4, 3, 2
                                // 3 starters 4, 3, 2
                                // 2 starters 3, 2
                                // 1 starter 2
                                outputPlace = starter.place
                                var cntr = 0
                                for countStarter in displayStarters {
                                    if countStarter.gender == starter.gender {
                                        cntr = cntr + 1
                                    }
                                }
                                switch cntr {
                                case 1:
                                    points = "2"
                                case 2:
                                    let arrayPoints = ["3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 3:
                                    let arrayPoints = ["4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 4:
                                    let arrayPoints = ["6","4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                case 5:
                                    let arrayPoints = ["8","6","4","3","2"]
                                    points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                default:
                                    // 6 or more
                                    if (Int(starter.place) ?? 0) > 5 {
                                        points = "2"
                                    } else {
                                        let arrayPoints = ["10","8","6","4","3"]
                                        points = arrayPoints[(Int(starter.place) ?? 0) - 1]
                                    }
                                }
                                displayTime = doubleAsTime(starter.raceTime) + "(" + doubleAsTime(starter.raceTime - getStd(age: starter.age, dist: myConfig.TTDist, gender: starter.gender)) + ")"
                            case "Wheel", "Hcp", "Secret":
                                // 20, 15, 12, 10, 8, 7, 6, 5, 4, 3, 2, 2 ...
                                var switcher = ""
                                outputPlace = starter.place
                                if raceTypes[myConfig.raceType]  == "Secret" {
                                    switcher = starter.place
                                } else {
                                    // "Wheel", "Hcp"
                                    switcher = starter.overTheLine
                                }
                                switch switcher {
                                case "1":
                                    points = "20"
                                case "2":
                                    points = "15"
                                case "3":
                                    points = "12"
                                case "4":
                                    points = "10"
                                case "5":
                                    points = "8"
                                case "6":
                                    points = "7"
                                case "7":
                                    points = "6"
                                case "8":
                                    points = "5"
                                case "9":
                                    points = "4"
                                case "10":
                                    points = "3"
                                default:
                                    points = "2"
                                }
                                // for handicaps, append the handicap time
                                if raceTypes[myConfig.raceType]  == "Wheel"  {
                                    displayTime = "(" + handicapForGrade(grade: starter.racegrade) + ")"
                                } else {
                                    displayTime = hcpDisplayTime(rider: starter)
                                }
                            default:  // Age
                                // no points as this is an age based race
                                displayTime = doubleAsTime(starter.raceTime)
                                points = "0"
                            }
                        }
                        // finish time format in RMS is text ie just displays what is given
                        if raceTypes[myConfig.raceType] == "Age Std" {
                            csvString = csvString.appending("\(starter.id)\t\(starter.racenumber)\t\(surname)\t\(givenName)\t\("")\t\("")\t\("")\t\(starter.gender)\t\(outputPlace)\t\(starter.overTheLine)\t\(displayTime)\t\(points)\n")
                        } else {
                            csvString = csvString.appending("\(starter.id)\t\(starter.racenumber)\t\(surname)\t\(givenName)\t\("")\t\("")\t\("")\t\(starter.racegrade)\t\(outputPlace)\t\(starter.overTheLine)\t\(displayTime)\t\(points)\n")
                        }
                        
                    }
                    
                    let fileManager = FileManager.default
                    var newName = myConfig.raceDate.replacingOccurrences(of: "/", with: " ")
                    newName = newName.replacingOccurrences(of: ":", with: " ")
                    do {
                        let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
                        // name file after race
                        let fileURL = path.appendingPathComponent("Results " + newName + ".csv")
                        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                        result = "Result written: " + "Results " + newName + ".csv"
                    } catch {
                        result = "Error creating file: " + "Results " + newName + ".csv   Error: \(error)"
                    }
                }) {
                    Text("Export")
                        .padding()
                        .foregroundColor(.black)
                }
//                .disabled(!exportEnabled)
                .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 50, alignment: .leading)
                .background(exportEnabled ? Color.green : Color.gray)
                .cornerRadius(10)
                .padding(.bottom, 10)
            }
            .onAppear(perform: {
                if myConfig.stage {
                    displayStarters = setStageResults()
                } else {
                    if raceTypes[myConfig.raceType] == "Secret" {
                        // set places based on raceTime
                        displayStarters = arrayStarters.sorted {
                            return $0.raceTime < $1.raceTime
                        }
                        var place = 1
                        for i in 0...(displayStarters.count - 1) {
                            if displayStarters[i].raceTime > 0.0 {
                                // excludes officals from getting places
                                displayStarters[i].place = String(place)
                                place = place + 1
                            }
                        }
                    } else if raceTypes[myConfig.raceType] == "Graded" || raceTypes[myConfig.raceType] == "Age" || raceTypes[myConfig.raceType] == "TT"  {
                        // set places per grade based on raceTime
                        displayStarters = arrayStarters.sorted {
                            if $0.racegrade != $1.racegrade {
                                return $0.racegrade < $1.racegrade
                            } else {
                                return $0.raceTime < $1.raceTime
                            }
                        }
                        if displayStarters.count > 0 {
                            for grade in startingGrades {
                                var place = 1
                                for i in 0...(displayStarters.count - 1) {
                                    if displayStarters[i].racegrade == grade && displayStarters[i].place != "DNF" && displayStarters[i].raceTime > 0.0 {
                                        displayStarters[i].place = String(place)
                                        place = place + 1
                                    }
                                }
                            }
                        }
                        displayStarters.sort {
                            if $0.racegrade != $1.racegrade {
                                return $0.racegrade < $1.racegrade
                            } else {
                                return $0.place.localizedStandardCompare($1.place) == .orderedAscending
                            }
                        }
                    } else if raceTypes[myConfig.raceType] == "Age Std" {
                        if arrayStarters.count > 0 {
                            displayStarters = arrayStarters
                            // adjust the finish time against the age std time
                            for i in 0...(displayStarters.count - 1) {
                                if displayStarters[i].place != "DNF" {
                                    displayStarters[i].adjustedTime = displayStarters[i].raceTime - getStd(age: displayStarters[i].age, dist: myConfig.TTDist, gender: displayStarters[i].gender)
                                }
                            }
                            displayStarters.sort {
                                return $0.adjustedTime < $1.adjustedTime
                            }
                            // set the places
                            for gender in genders {
                                var place = 1
                                for i in 0...(displayStarters.count - 1) {
                                    if displayStarters[i].racegrade != directorGrade && displayStarters[i].racegrade != marshalGrade && displayStarters[i].place != "DNF" && displayStarters[i].gender == gender {
                                        if displayStarters[i].raceTime == 0.0 {
                                            displayStarters[i].place = ""
                                            displayStarters[i].overTheLine = ""
                                        } else {
                                            displayStarters[i].place = String(place)
                                            place = place + 1
                                        }
                                    }
                                }
                            }
                            displayStarters.sort {
                                if $0.gender != $1.gender {
                                    return $0.gender < $1.gender
                                } else {
                                    return Int($0.place) ?? 10000 < Int($1.place) ?? 10000
                                }
                            }
                        }
                    } else {
                        // race type is not Secret or Age Std
                        displayStarters = arrayStarters.sorted {
                            if raceTypes[myConfig.raceType] == "Wheel" || raceTypes[myConfig.raceType] == "Hcp" {
                                return $0.overTheLine.localizedStandardCompare($1.overTheLine) == .orderedAscending
                            } else {
                                if $0.racegrade != $1.racegrade {
                                    return $0.racegrade < $1.racegrade
                                } else {
                                    return $0.place.localizedStandardCompare($1.place) == .orderedAscending
                                }
                            }
                        }
                    }
                }
                // check if the results are ok to export
                if displayStarters.count == 0 {
                    exportEnabled = false
                } else {
                    for item in displayStarters {
                        if item.overTheLine == "" && item.place == "" && (item.racegrade != directorGrade && item.racegrade != marshalGrade) {
                            exportEnabled = false
                            break
                        }
                    }
                }
            })
            .navigationBarTitle("Results", displayMode: .inline)
        }
    }
    
//    struczt RegistrationsView: View {
//
//        var body: some View {
//            VStack (alignment: .leading) {
//                Group{
//                    NavigationLink(
//                        destination: DirectorView())
//                        { Text("Director").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: MarshalsView())
//                        { Text("Marshals").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: TrialView())
//                        { Text("Trial Rider").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: RegoView())
//                        { Text("Rider").padding(.top, listPad)}
//                }
//                Spacer()
//            }
//
//            .navigationBarTitle("Registrations", displayMode: .inline)
//        }
//    }
    
    struct MenuView: View {
        @Binding var selectedView: String
        @Binding var showMenu: Bool
        
        var body: some View {
            ScrollView {
            VStack(alignment: .leading) {
                Group{
//                HStack {
//                    Button(action: {
//                        withAnimation {
//                            selectedView = "Test"
//                            showMenu = false
//                        }
//                    }) {
//
//                    Text("Test")
//                        .foregroundColor(.black)
//                        .font(.headline)
//                    }
//                }
//                .padding(.top, 20)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Main"
                            showMenu = false
                        }
                    }) {
                    Image(systemName: "house")
                        .foregroundColor(.black)
                        .imageScale(.large)
                    Text("Main")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 20)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Settings"
                            showMenu = false
                        }
                    }) {
                        Image(systemName: "gear")
                        .foregroundColor(.black)
                        .imageScale(.large)
                        Text("Settings")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Load"
                            showMenu = false
                        }
                    }) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.black)
                        .imageScale(.large)
                    Text("Load")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Director"
                            showMenu = false
                        }
                    }) {
                    Image(systemName: "person")
                        .foregroundColor(.red)
                        .imageScale(.large)
                    Text("Director")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Marshals"
                            showMenu = false
                        }
                    }) {
                    Image(systemName: "person")
                        .foregroundColor(.orange)
                        .imageScale(.large)
                    Text("Marshals")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Trial"
                            showMenu = false
                        }
                    }) {
                    Image(systemName: "person")
                        .foregroundColor(.purple)
                        .imageScale(.large)
                    Text("Trials rider")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Rider"
                            showMenu = false
                        }
                    }) {
                    Image(systemName: "person")
                        .foregroundColor(.green)
                        .imageScale(.large)
                    Text("Rider")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                if raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "Wheel" || raceTypes[myConfig.raceType] == "Secret"  {
                    HStack {
                        Button(action: {
                            withAnimation {
                                selectedView = "Handicaps"
                                showMenu = false
                            }
                        }) {
                            Image(systemName: "plusminus.circle")
                                .foregroundColor(.black)
                                .imageScale(.large)
                            Text("Handicaps")
                                .foregroundColor(.black)
                                .font(.headline)
                        }
                    }
                .padding(.top, 18)
                }
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Start"
                            showMenu = false
                        }
                    }) {
                        Image(systemName: "figure.stand.line.dotted.figure.stand")
                            .foregroundColor(.black)
                            .imageScale(.large)
                        Text("Start list")
                            .foregroundColor(.black)
                            .font(.headline)
                    }
                }
                .padding(.top, 18)
                }
                Group {
                if raceTypes[myConfig.raceType] != "Crit" {
                    HStack {
                        Button(action: {
                            withAnimation {
                                selectedView = "Timing"
                                showMenu = false
                            }
                        }) {
                        Image(systemName: "stopwatch")
                            .foregroundColor(.black)
                            .imageScale(.large)
                        Text("Timing")
                            .foregroundColor(.black)
                            .font(.headline)
                        }
                    }
                    .padding(.top, 18)
                }
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Places"
                            showMenu = false
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                        .foregroundColor(.black)
                        .imageScale(.large)
                        Text("Places")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
                if myConfig.stage {
                    HStack {
                        Button(action: {
                            withAnimation {
                                selectedView = "Stages"
                                showMenu = false
                            }
                        }) {
                            Image(systemName: "tray.2")
                            .foregroundColor(.black)
                            .imageScale(.large)
                            Text("Stages")
                            .foregroundColor(.black)
                            .font(.headline)
                        }
                    }
                    .padding(.top, 18)
                }
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedView = "Results"
                            showMenu = false
                        }
                    }) {
                        Image(systemName: "folder")
                        .foregroundColor(.black)
                        .imageScale(.large)
                        Text("Results")
                        .foregroundColor(.black)
                        .font(.headline)
                    }
                }
                .padding(.top, 18)
//                Spacer()
                .padding(.bottom, 500)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.0, green: 1.0 , blue: 1.0))
            .edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    struct MainView: View {
         
        var body: some View {
            let nsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
            let version = nsObject as! String
            
            VStack(alignment: .leading) {
                Text("Race date: " + myConfig.raceDate)
                Text("Race type: " + raceTypes[myConfig.raceType])
                Text("Officals: " + String(officalCount()))
                Text("Entries: " + String(riderCount()))
                Text(msg)
                .frame(width: 300, alignment: .center)
                .padding(.top, 100)
                Text("SORS Version: " + version)
                .frame(width: 300, alignment: .center)
                .padding(.top, 50)
            }
        }
    }
    
    // Main page
    var body: some View {
        
        let drag = DragGesture()
        .onEnded {
            if $0.translation.width < -100 {
                withAnimation {
                    self.showMenu = false
                }
            }
            if $0.translation.width > 100 {
                withAnimation {
                    self.showMenu = true
                }
            }
        }
        
        return NavigationView {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                switch selectedView {
                case "Test":
                    TestView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Settings":
                    SettingsView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Load":
                    LoadView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Director":
                    DirectorView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Marshals":
                    MarshalsView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Trial":
                    TrialView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Rider":
                    RegoView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Handicaps":
                    HandicapView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Start":
                    StartView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Timing":
                    TimingView(stopWatchManager: stopWatchManager)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Places":
                    PlacesView(dragEnable: $dragEnable)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
//                    .gesture(dragEnable ? drag : nil)
                case "Stages":
                    StagesView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                case "Results":
                    ResultsView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                default:
                    MainView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width/2 : 0)
                    .disabled(self.showMenu ? true : false)
                    .gesture(drag)
                }

                if self.showMenu {
                    MenuView(selectedView: $selectedView, showMenu: $showMenu)
                    .frame(width: geometry.size.width/2)
                    .transition(.move(edge: .leading))
                }
            }  // on zstack
            .gesture(dragEnable ? drag : nil)
        }
        .navigationBarTitle("SORS", displayMode: .inline)
        .navigationBarItems(leading: (
            Button(action: {
                withAnimation {
                    self.showMenu.toggle()
                }
            }) {
                Image(systemName: "line.horizontal.3")
                    .imageScale(.large)
            }
        ))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
//        NavigationView {
//            VStack(alignment: .leading) {
//                Group{
//                    NavigationLink(
//                        destination: SettingsView())
//                        { Text("Settings").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: LoadView())
//                        { Text("Load").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: RegistrationsView())
//                        { Text("Registration").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: HandicapView())
//                        { Text("Handicaps").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: StartView())
//                        { Text("Start List").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: TimingView())
//                        { Text("Timing").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: PlacesView())
//                        { Text("Places").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: StagesView())
//                        { Text("Stages").padding(.top, listPad)}
//                    NavigationLink(
//                        destination: ResultsView())
//                        { Text("Results").padding(.top, listPad)}
//                }
//                Spacer()
//                .padding()
//                Text(msg).frame(width: 100, alignment: .center)
//                .navigationBarTitle("SORS", displayMode: .inline)
//            }
//        }
    }
}
 
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
