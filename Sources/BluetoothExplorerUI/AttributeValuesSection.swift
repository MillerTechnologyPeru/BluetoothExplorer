//
//  AttributeValuesSection.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation
import Bluetooth
import SwiftUI
import BluetoothExplorerModel

struct AttributeValuesSection: View {
    
    let uuid: BluetoothUUID
    
    let values: [AttributeValue]
    
    var body: some View {
        Section(content: {
            ForEach(values) {
                AttributeValueCell(
                    uuid: uuid,
                    attributeValue: $0
                )
            }
        }, header: {
            Text("Values")
        })
    }
}
/*
#if DEBUG
struct AttributeValuesSection_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            /*
            NavigationView {
                List {
                    AttributeValuesSection(
                        uuid: .batteryLevel,
                        values: [
                            AttributeValue(
                                date: Date(),
                                type: .notification,
                                data: Data([25])
                            ),
                            AttributeValue(
                                date: Date() - 80 * 60,
                                type: .notification,
                                data: Data([80])
                            ),
                            AttributeValue(
                                date: Date() - 118 * 60,
                                type: .notification,
                                data: Data([98])
                            ),
                            AttributeValue(
                                date: Date() - 119 * 60,
                                type: .notification,
                                data: Data([99])
                            ),
                            AttributeValue(
                                date: Date() - 120 * 60,
                                type: .read,
                                data: Data([100])
                            )
                        ]
                    )
                }
                .navigationTitle(BluetoothUUID.batteryLevel.name ?? "")
                .previewDisplayName(BluetoothUUID.batteryLevel.name ?? "")
            }
            .previewLayout(.device)
            .previewDevice("iPod touch (7th generation)")
            .preferredColorScheme(.dark)
            */
            NavigationView {
                List {
                    AttributeValuesSection(
                        uuid: .deviceName,
                        values: [
                            AttributeValue(
                                date: Date() + 5 * 60,
                                type: .notification,
                                data: Data("iPhone 2".utf8)
                            ),
                            AttributeValue(
                                date: Date(),
                                type: .read,
                                data: Data("iPhone".utf8)
                            )
                        ]
                    )
                }
                .navigationTitle(BluetoothUUID.deviceName.name ?? "")
                .previewDisplayName(BluetoothUUID.deviceName.name ?? "")
            }
        }
    }
}
#endif
*/
