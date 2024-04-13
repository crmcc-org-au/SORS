//
//  StopWatchManager.swift
//  SORS
//
//  Created by Ian McVay on 12/10/20.
//

import Foundation
import SwiftUI
import AVFoundation

class StopWatchManager: ObservableObject {
    @Published var counter = 0.0
    @Published var seconds = 0.0
    @Published var minutes = 0.0
    @Published var hours = 0.0
    @Published var nextStart = ""
    @Published var nextRider = ""
    @Published var nextRiders = ""
    @Published var started = false
    @Published var stopped = false
    @State var locked = true
    var startDateTime: Date?  { // = 0.0 {
        didSet {
            UserDefaults.standard.set(startDateTime, forKey: "startDateTime")
        }
    }
    
    var sortedHandicaps = [Handicap]()
    var sortedRiders = [Rider]()
    var countDown = 5
    var starting = false
    let updateInterval = 0.1          // update the timer every .1 sec
    
    // create a sound ID for count down and start.
    // note - availability of sounds seems unreliable
    let beepSoundID: SystemSoundID = 1072
    let goSoundID: SystemSoundID = 1070
    
    func restart() {
        if !stopped {
            resume()
            startTimer()
        }
    }
    
    func reset() {
        counter = 0.0
        seconds = 0.0
        minutes = 0.0
        hours = 0.0
        countDown = 5
        nextStart = ""
        nextRider = ""
        nextRiders = ""
        started = false
        stopped = false
        locked = true
        timer?.invalidate()
        startDateTime = nil
    }
    
    func storeStartTime() {
        startDateTime = Date()   //.timeIntervalSinceReferenceDate
    }
    
    var timer : Timer?
    
    func UpdateTimer() {
        counter = counter + updateInterval
    }
    
    func startTimer() {
        // check what sounds are available in debug
//        for i in 1000...2000 {
//            AudioServicesPlaySystemSound (UInt32(i))
//        }
        
        if !self.started {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) {
            timer in self.counter += self.updateInterval
            //    let a = self.counter    // debugging
            self.hours = self.counter/3600
            self.hours.round(.towardZero)
            self.minutes = (self.counter-self.hours*3600)/60
            self.minutes.round(.towardZero)
            self.seconds = self.counter - self.hours * 3600 - self.minutes * 60
            self.started = true
            
            if self.counter == 0 {
                // TODO not sure if this is ever executed as counter is set above
                // 1st rider is started
                setStartTime(id: self.sortedRiders[0].id)
                self.sortedRiders.remove(at: 0)
                
                if raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "Wheel" {
                    self.sortedHandicaps.remove(at: 0)
                }
            }
            
            if raceTypes[myConfig.raceType] == "TT" || raceTypes[myConfig.raceType] == "Age Std" {
                // start at TTStartInterval sec intervals
                if self.sortedRiders.count > 0 {
                    let showsec = myConfig.TTStartInterval - (Int(self.counter) % myConfig.TTStartInterval + 1) + 1
                    if showsec == myConfig.TTStartInterval {
                        if !self.starting {    // only do the remove once per showsec being zero
                            setStartTime(id: self.sortedRiders[0].id)
                            self.sortedRiders.remove(at: 0)
                            self.nextRiders = ""
                            for rider in self.sortedRiders {
                                self.nextRiders = self.nextRiders + rider.racenumber + " - " + rider.name + "\n"
                            }
                            self.starting = true
                            AudioServicesPlaySystemSound (self.goSoundID)
                            self.countDown = 5
                        }
                    } else {
                        self.starting = false
                    }
                    if self.sortedRiders.count > 0 {
                        self.nextRider = self.sortedRiders[0].racenumber + " - " + self.sortedRiders[0].name + " in 0:" + String(format: "%02d", showsec)
                        self.nextRiders = ""
                        var skipFirst = true
                        for rider in self.sortedRiders {
                            if !skipFirst {
                                self.nextRiders = self.nextRiders + rider.racenumber + " - " + rider.name + "\n"
                            } else {
                                skipFirst = false
                            }
                        }
                        if showsec <= self.countDown && showsec > 0 {
                            AudioServicesPlaySystemSound (self.beepSoundID)
                            self.countDown = self.countDown - 1
                        }
                    }
                } else {
                    // no riders to start
                    self.nextRider = ""
                    self.stopTimer()
                }
                    
            } else if raceTypes[myConfig.raceType] == "Hcp" || raceTypes[myConfig.raceType] == "Wheel" {
                if self.sortedHandicaps.count > 0 {
                    // if time has passed for grade start, remove it from the list
                    if Int(self.counter) >= self.sortedHandicaps[0].time {
                        AudioServicesPlaySystemSound (self.goSoundID)
                        self.sortedHandicaps.remove(at: 0)
                        self.countDown = 5
                    }
                    
                    if self.sortedHandicaps.count > 0 {
                        let showtime = self.sortedHandicaps[0].time - Int(self.counter)
                        let showmin = showtime/60
                        let showsec = showtime - (showmin * 60)
                        self.nextStart = self.sortedHandicaps[0].racegrade + " in " + String(showmin) + ":" + String(format: "%02.0f", Double(showsec))  // String(showtime) + " " + String(self.countDown) + " " +
                        if showtime <= self.countDown {
                            AudioServicesPlaySystemSound (self.beepSoundID)
                            self.countDown = self.countDown - 1
                        }
                    } else {
                        self.nextStart = ""
                        self.stopTimer()
                    }
                } else {
                    // No sorted handicaps -  there was only one grade
                    for i in 0...(arrayStarters.count - 1) {
                        if arrayStarters[i].racegrade == self.nextStart {
                            arrayStarters[i].startTime = Date()
                        }
                    }
                    self.nextStart = ""
                    AudioServicesPlaySystemSound (self.goSoundID)
                    self.stopTimer()
                }
            }
        }
            
        }
    }
    
    func resume() {
        // set the counter (seconds) to be the time since the race start
        // get the stored startdate
        if UserDefaults.standard.object(forKey: "startDateTime") != nil {
            startDateTime = UserDefaults.standard.object(forKey: "startDateTime") as! Date?
            counter = Date().timeIntervalSince(startDateTime!)
        } else {
            counter = 0
        }
        if !started {
            startTimer()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        self.counter = 0
        self.nextStart = ""
        self.stopped = true
    }
    
    func loadStarts(handicaps: [Handicap]) {
        var trimTime = 0
        // trim the 1st start time back to start at time = 0
        sortedHandicaps = handicaps
        self.sortedHandicaps.sort {
            return $0.time < $1.time
        }
        if counter == 0 && sortedHandicaps.count > 0 {
            // set the 1st grade to start
            nextStart = sortedHandicaps[0].racegrade
            trimTime = sortedHandicaps[0].time
        }
        if sortedHandicaps.count > 0 {
            for i in 0...(sortedHandicaps.count - 1) {
                sortedHandicaps[i].time = sortedHandicaps[i].time - trimTime
            }
        }
    }
   
    func loadTT(_ riders: [Rider]) {
        // sort by grade and race number
        sortedRiders = riders.filter {$0.racegrade != directorGrade && $0.racegrade != marshalGrade}
        if sortedRiders.count == 0 { return }
        self.sortedRiders.sort {
            if $0.racegrade == $1.racegrade {
                return $0.racenumber < $1.racenumber
            } else {
                return $0.racegrade < $1.racegrade
            }
        }
        setFirstRider()
    }
    
    func loadAgeStd(_ riders: [Rider]) {
        // sort by age
        sortedRiders = riders.filter {$0.racegrade != directorGrade && $0.racegrade != marshalGrade}
        self.sortedRiders.sort {
            return $0.age < $1.age
        }
        setFirstRider()
    }
    
    func setFirstRider() {
        if counter == 0 && sortedRiders.count > 0 {
            // set the 1st rider to start
            nextRider = sortedRiders[0].racenumber + " - " + sortedRiders[0].name
            self.nextRiders = ""
            var first = true
            for rider in self.sortedRiders {
                if first {
                    // skip the 1st rider in the list of next riders
                    first = false
                } else {
                    self.nextRiders = self.nextRiders + rider.racenumber + " - " + rider.name + "\n"
                }
            }
        }
    }
}
