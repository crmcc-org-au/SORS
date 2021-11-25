//
//  SORSApp.swift
//  SORS
//
//  Created by Ian McVay on 7/10/20.
//

import SwiftUI

@main
struct SORSApp: App {
    init () {
        // Do things to start up the app
        UIApplication.shared.isIdleTimerDisabled = true  // stop the screen locking
        running = UserDefaults.standard.bool(forKey: "running")

        loadRiders()
        loadNames()
        loadRaces()
        
        // load the stored config
        if let items = UserDefaults.standard.data(forKey: "myConfig") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(Config.self, from: items) {
                myConfig = decoded
            }
        }
        
        peripheralName = String(UserDefaults.standard.string(forKey: "peripheralName") ?? "")

        // load stored starters
        if let items = UserDefaults.standard.data(forKey: "Starters") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([Rider].self, from: items) {
                arrayStarters = decoded
                if myConfig.stage {
                    if arrayStarters.count > 0 {
                        for i in 0...(arrayStarters.count - 1) {
                            while arrayStarters[i].stageResults.count < myConfig.numbStages {
                                arrayStarters[i].stageResults.append(StageResult())
                            }
                        }
                    }
                }
                getUnplaced()
            }
        }
        
        if let items = UserDefaults.standard.data(forKey: "finishTimes") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([FinishTime].self, from: items) {
                finishTimes = decoded
            }
        }

        if let items = UserDefaults.standard.data(forKey: "handicaps") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([Handicap].self, from: items) {
                handicaps = decoded
            }
        }
        checkHandicaps()
        // set up timer start state
        if let items = UserDefaults.standard.data(forKey: "unstartedGrades") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([String].self, from: items) {
                unstartedGrades = decoded
            }
        }
        if let items = UserDefaults.standard.data(forKey: "startedGrades") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([StartedGrade].self, from: items) {
                startedGrades = decoded
            }
        }
        
        if myConfig.stage {
            if myConfig.stages.count == 0 {
                myConfig.raceType = 0
            } else {
                myConfig.raceType = myConfig.stages[myConfig.currentStage].type
            }

        }
        // ensure selection is withing bounds
        if myConfig.raceType < 0 {
            myConfig.raceType = 0
        }
        if raceTypes[myConfig.raceType] == "Graded" && unstartedGrades.count == 0 {
            startDisabled = true
//                stopDisabled = false
        }
        setStartingGrades()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

