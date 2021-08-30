//
//  BLEManager.swift
//  SORS
//
//  Created by Ian McVay on 17/1/21.
//

import Foundation
import CoreBluetooth

var masterPaired = false

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    var connected: Bool
}
 
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isSwitchedOn = false
    @Published var scanning = false
    @Published var connected = false
    @Published var connectionError = false
//    @Published var paired = false
    @Published var connectionErrorTxt = ""
    @Published var status = ""
    @Published var peripherals = [Peripheral]()
    var transferCharacteristic: CBCharacteristic?
    var dataToSend = Data()
    var configSent = false  // has the configuration been sent to the peripheral
    var ridersSent = false  // has the rider list been sent to the peripheral
    var timesSent = false   // haves the finish times been sent to the peripheral
    var sync = false
    var sendDataIndex = 0
    var amountToSend = 0
    var xferTxt = ""
    
    // Change of state for Manager
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
        }
        else {
            isSwitchedOn = false
        }
    }
    
    // Discovered a peripheral
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!
           
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralName = name
            // check if already known
            for peripheral in peripherals {
                if peripheral.name == peripheralName {
                    return
                }
            }
        }
        else {
            peripheralName = "Unknown"
        }
       
        // add peripheral to the list of known peripherals
        let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, peripheral: peripheral, connected: false)
        peripherals.append(newPeripheral)
    }
    
    // Failed to connect to peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // If the connection fails for whatever reason, we need to deal with it.
        connected = false
        connectionError = true
        connectionErrorTxt = String(describing: error)
    }
    
    // This callback comes in when the CentralManager received write to characteristics
//    func centralManager(_ central: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
//        status = "Incoming data..."
//        for aRequest in requests {
//            guard let requestValue = aRequest.value
////                  , let stringFromData = String(data: requestValue, encoding: .utf8)
//            else {
//                continue
//            }
//
//            // load data into SORS
//            // raceType, raceDate, championship
//            status = "Decoding data..."
//            let decoder = JSONDecoder()
//
//            // data is chunked - reassemble
//            let stringFromData = String(data: requestValue, encoding: .utf8)
//            if stringFromData == "SOM" {
//                status = "Starting..."
//                return
//            }
//            if stringFromData == "EOMRiders" {
//                // TODO update arrayStarters with new data in myRiders
//                status = "Updating riders..."
//                let jsonData = Data(xferTxt.utf8)
//                if let decoded = try? decoder.decode([Rider].self, from: jsonData) {
//                    var updateCount = 0
//                    for rider in decoded {
////                        // check if the rider is already registered.  If not append to starters
////                        var riderFound = false
////                        if arrayStarters.count > 0 {
////                            for i in 0...(arrayStarters.count - 1) {
////                                if rider.racenumber == arrayStarters[i].racenumber {
////                                    riderFound = true
////                                    // check if start time needs to be set ie for TT
////                                    if arrayStarters[i].startTime == nil  && rider.startTime != nil //0
////                                    {
////                                        arrayStarters[i].startTime = rider.startTime
////                                    }
////                                    break
////                                }
////                            }
////                        }
////                        if !riderFound {
////                            arrayStarters.append(rider)
////                            updateCount = updateCount + 1
////                        }
//                    }
//                    status = String(updateCount) + " riders updated."
//                } else {
//                    status = "No riders updated."
//                }
//                // reset the buffer
//                xferTxt = ""
//            } else {
//                xferTxt = xferTxt + stringFromData!
//            }
//            // respond to the peripheral - ignored if type is .withoutResponse
////            myCentral.respond(to: aRequest, withResult: .success)
//        }
//    }
    
    // Connected to peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
        connected = true
        for i in 0...(peripherals.count - 1) {
            if peripheral == peripherals[i].peripheral {
                peripherals[i].connected = true
            }
        }
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self

        // Search only for services that match our UUID
        peripheral.discoverServices([TransferService.serviceUUID])
    }
    
    func startScanning() {
        myCentral.scanForPeripherals(withServices: [TransferService.serviceUUID], options: nil)
        scanning = true
    }
    
    func stopScanning() {
        myCentral.stopScan()
        scanning = false
    }
    
    func sync(target: String) {
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        sync = true
        for peripheral in peripherals {
            if target == peripheral.name {
                peripheral.peripheral.writeValue("SOM".data(using: .utf8)!, for: transferCharacteristic, type: .withoutResponse)
            }
        }
    }
    
    func clear() {
        if peripherals.count > 0 {
            for i in 0...(peripherals.count - 1) {
                if peripherals[i].connected {
                    myCentral.cancelPeripheralConnection(peripherals[i].peripheral)
                }
            }
            peripherals = []
        }
        connected = false
        status = ""
    }
    
    func connect(target: String) {
        for peripheral in peripherals {
            if target == peripheral.name {
                myCentral.connect(peripheral.peripheral, options: nil)
            }
        }
    }
    
    func disconnect(target: String) {
        for i in 0...(peripherals.count - 1) {
            if target == peripherals[i].name {
                myCentral.cancelPeripheralConnection(peripherals[i].peripheral)
                peripherals[i].connected = false
                masterPaired = false
            }
        }
        connected = false
        status = ""
    }
    
    override init() {
        super.init()
 
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
 
    var myCentral: CBCentralManager!
}

extension BLEManager: CBPeripheralDelegate {
    // implementations of the CBPeripheralDelegate methods

    // The peripheral letting us know when services have been invalidated.
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        for service in invalidatedServices where service.uuid == TransferService.serviceUUID {
            peripheral.discoverServices([TransferService.serviceUUID])
        }
    }

    // The Transfer Service was discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            connectionErrorTxt = error.localizedDescription
//            cleanup()
            return
        }
        
        // Discover the characteristic we want...
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([TransferService.characteristicUUID], for: service)
        }
    }
    
    // The Transfer characteristic was discovered.
    // Once this has been found, we want to subscribe to it and then pair the SORS data
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        // Deal with errors (if any).
        if let error = error {
            connectionErrorTxt = error.localizedDescription
//            cleanup()
            return
        }
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.characteristicUUID {
            // If it is, subscribe to it
            transferCharacteristic = characteristic
            
            // TODO Only subscribe once.
            peripheral.setNotifyValue(true, for: characteristic)
        }
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        configSent = false
        ridersSent = false
        timesSent = false
        peripheral.writeValue("SOM".data(using: .utf8)!, for: transferCharacteristic, type: .withoutResponse)
    }
    
    // This callback lets us know if data has been received by the peripheral
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            status = "Error sending data: " + error!.localizedDescription
            return
        }
        status = "Data sent"
    }
    
    // This callback lets us know more data has arrived via notification on the characteristic
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            status = error.localizedDescription
//            cleanup()
            return
        }
        
        guard let characteristicData = characteristic.value,
            let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        
        // Have we received the end-of-message token?
        if stringFromData == "EOM" {
            // End-of-message case: show the data.
            // Dispatch the text view update to the main queue for updating the UI, because
            // we don't know which thread this method will be called back on.
            DispatchQueue.main.async() {
//                self.textView.text = String(data: self.data, encoding: .utf8)
            }
            
            // Write test data
        } else {
            // Otherwise, just append the data to what we have previously received.
//            data.append(characteristicData)
        }
    }

    // The peripheral letting us know whether our subscribe/unsubscribe happened or not
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            status = "Error sending data: " + error.localizedDescription
            return
        }
        
        // Exit if it's not the transfer characteristic
        guard characteristic.uuid == TransferService.characteristicUUID else { return }
        
        if characteristic.isNotifying {
            // Notification has started
            status = "Notification started"
        } else {
            // Notification has stopped, so disconnect from the peripheral
            status = "Notification stopped"
//            cleanup()
        }
    }
    
    // This is called when peripheral is ready to accept more data when using write without response
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        
        status = "Peripheral ready to accept data"
        // Start sending data to the peripheral to sync app.
        if !configSent {
            if sendDataIndex == 0 {
                status = "Writing config..."
                dataToSend = try! JSONEncoder().encode(myConfig)
            }
            if sendDataIndex >= dataToSend.count {
                // Send an EOM
                peripheral.writeValue("EOMConfig".data(using: .utf8)!, for: transferCharacteristic!, type: .withoutResponse)
                configSent = true
                sendDataIndex = 0
                return
            } else {
                // Work out how big it should be
                amountToSend = dataToSend.count - sendDataIndex
                amountToSend = min(amountToSend, mtu)
                // Copy out the data we want
                let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
                // Send it
                sendDataIndex += amountToSend
                peripheral.writeValue(chunk, for: transferCharacteristic!, type: .withoutResponse)
                return
            }
        } else if !ridersSent {
            if sendDataIndex == 0 {
                status = "Writing starting riders..."
                dataToSend = try! JSONEncoder().encode(arrayStarters)
            }
            if sendDataIndex >= dataToSend.count {
                // Send an EOM
                peripheral.writeValue("EOMRiders".data(using: .utf8)!, for: transferCharacteristic!, type: .withoutResponse)
                ridersSent = true
                sendDataIndex = 0
                return
            } else {
                // Work out how big it should be
                amountToSend = dataToSend.count - sendDataIndex
                amountToSend = min(amountToSend, mtu)
                // Copy out the data we want
                let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
                // Send it
                sendDataIndex += amountToSend
                peripheral.writeValue(chunk, for: transferCharacteristic!, type: .withoutResponse)
                return
            }
            
        } else if sync && !timesSent {
            if sendDataIndex == 0 {
                status = "Writing riders' start times..."
                dataToSend = try! JSONEncoder().encode(arrayStarters)
            }
            if sendDataIndex >= dataToSend.count {
                // Send an EOM
                peripheral.writeValue("EOMStarts".data(using: .utf8)!, for: transferCharacteristic!, type: .withoutResponse)
                timesSent = true
                sendDataIndex = 0
                return
            } else {
                // Work out how big it should be
                amountToSend = dataToSend.count - sendDataIndex
                amountToSend = min(amountToSend, mtu)
                // Copy out the data we want
                let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
                // Send it
                sendDataIndex += amountToSend
                peripheral.writeValue(chunk, for: transferCharacteristic!, type: .withoutResponse)
                return
            }
            
        } else {
            masterPaired = true
            status = "Finished writing..."
        }
    }
    
}
