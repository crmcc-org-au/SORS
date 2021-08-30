//
//  BLEPeripheral.swift
//  SORS
//
//  Created by Ian McVay on 17/1/21.
//

import Foundation
import CoreBluetooth

var peripheralPaired = false

class BLEPeripheral: NSObject, CBPeripheralManagerDelegate, ObservableObject {
    @Published var isSwitchedOn = false
    @Published var advertising = false
    @Published var status = ""
    var myPeripheral: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var amountToSend = 0
    var sendDataIndex: Int = 0
    var xferTxt = ""
    var riders : [Rider] = []
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            isSwitchedOn = true
            setupPeripheral()
        }
        else {
            isSwitchedOn = false
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
//        var dataToSend = Data()
//        var testData = "Test"
        
//        guard let transferCharacteristic = transferCharacteristic else {
//            return
//        }
        
        // Get the data
//        dataToSend = testData.data(using: .utf8)!
        
        // Reset the index
        sendDataIndex = 0
        
        // save central
        connectedCentral = central
        status = "Pairing..."
//        let mtu = connectedCentral?.maximumUpdateValueLength
        
        // Start sending
//        let sent = myPeripheral.updateValue(dataToSend, for: transferCharacteristic, onSubscribedCentrals: nil)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        status = "Unpairing..."
        peripheralPaired = false
    }
    
    // This callback comes in when the PeripheralManager received write to characteristics
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        status = "Incoming data..."
        for aRequest in requests {
            guard let requestValue = aRequest.value
//                  , let stringFromData = String(data: requestValue, encoding: .utf8)
            else {
                continue
            }
            
            // load data into SORS
            // raceType, raceDate, championship
            status = "Decoding data..."
            let decoder = JSONDecoder()
            
            // data is chunked - reassemble
            let stringFromData = String(data: requestValue, encoding: .utf8)
            if stringFromData == "SOM" {
                status = "Starting data receipt..."
                return
            }
            if stringFromData == "EOMRiders" {
                // TODO update arrayStarters with new data in myRiders
                status = "Loading riders..."
                let jsonData = Data(xferTxt.utf8)
                if let decoded = try? decoder.decode([Rider].self, from: jsonData) {
                    var updateCount = 0
                    for rider in decoded {
                        // check if the rider is already registered.  If not append to starters
                        var riderFound = false
                        if arrayStarters.count > 0 {
                            for i in 0...(arrayStarters.count - 1) {
                                if rider.racenumber == arrayStarters[i].racenumber {
                                    riderFound = true
                                    // check if start time needs to be set ie for TT
                                    if arrayStarters[i].startTime == nil  && rider.startTime != nil //0
                                    {
                                        arrayStarters[i].startTime = rider.startTime
                                    }
                                    break
                                }
                            }
                        }
                        if !riderFound {
                            arrayStarters.append(rider)
                            updateCount = updateCount + 1
                        }
                    }
                    getUnplaced()
                    status = String(updateCount) + " riders loaded."
                } else {
                    status = "No riders loaded."
                }
                // reset the buffer
                xferTxt = ""
                peripheralPaired = true
            } else if stringFromData == "EOMConfig" {
                status = "Loading config..."
                let jsonData = Data(xferTxt.utf8)
                if let decoded = try? decoder.decode(Config.self, from: jsonData) {
                    myConfig.championship = decoded.championship
                    myConfig.TTStartInterval = decoded.TTStartInterval
                    myConfig.raceType = decoded.raceType
                    myConfig.raceDate = decoded.raceDate
                    myConfig.stage = decoded.stage
                    myConfig.stages = decoded.stages
                    myConfig.numbStages = decoded.numbStages
                    status = "Config loaded."
                } else {
                    status = "Config not loaded."
                }
                // reset the buffer
                xferTxt = ""
            } else if stringFromData == "EOMStarts" {
                status = "Loading times..."
                var loadCount = 0
                let jsonData = Data(xferTxt.utf8)
                if let decoded = try? decoder.decode([Rider].self, from: jsonData) {
                    for rider in decoded {
                        if rider.racegrade != marshalGrade && rider.racegrade != directorGrade {
                        if arrayStarters.count > 0 {
                            for i in 0...(arrayStarters.count - 1) {
                                if rider.racenumber == arrayStarters[i].racenumber {
                                    arrayStarters[i].finishTime = rider.finishTime
                                    arrayStarters[i].overTheLine = rider.overTheLine
                                    if rider.finishTime != nil && arrayStarters[i].startTime != nil {
                                        arrayStarters[i].raceTime = rider.finishTime!.timeIntervalSince(arrayStarters[i].startTime!)
                                        loadCount = loadCount + 1
                                    }
                                    break
                                }
                            }
                        }
                        }
                    }
                }
                status = String(loadCount) + " finish times loaded."
                // reset the buffer
                xferTxt = ""
            } else {
                xferTxt = xferTxt + stringFromData!
            }
            // respond to the central - ignored if type is .withoutResponse
            myPeripheral.respond(to: aRequest, withResult: .success)
        }
    }
    
    func startAdvertising() {
        myPeripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID], CBAdvertisementDataLocalNameKey: peripheralName])
        advertising = true
    }
    
    func stopAdvertising() {
        myPeripheral.stopAdvertising()
        advertising = false
    }
    
    private func setupPeripheral() {
        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.characteristicUUID,
                 properties: [.notify, .writeWithoutResponse, .write],
             value: nil,
             permissions: [.readable, .writeable])
        
        // Create a service from the characteristic.
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        
        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]
        
        // And add it to the peripheral manager.
        myPeripheral.add(transferService)
        
        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic
    }
    
    override init() {
        super.init()
        myPeripheral = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
}
