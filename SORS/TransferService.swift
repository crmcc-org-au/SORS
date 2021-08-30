//
//  TransferService.swift
//  SORS
//
//  Created by Kevin Woods on 17/1/21.
//

import Foundation
import CoreBluetooth

struct TransferService {
    static let serviceUUID = CBUUID(string: "c2be28b7-fd78-44f1-bdbc-e2830c6fe4b0")
    static let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB12D4")
}
