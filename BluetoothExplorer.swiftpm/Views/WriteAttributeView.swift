//
//  WriteAttributeView.swift
//  
//
//  Created by Alsey Coleman Miller on 23/12/21.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import Bluetooth

struct WriteAttributeView: View {
    
    let uuid: BluetoothUUID
    
    @State
    var text: String
    
    var cancel: (() -> ())?
    
    var done: ((Data) -> ())?
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("0x00", text: $text, prompt: nil)
            }
            .navigationTitle("Write")
            #if os(iOS)
            .navigationBarItems(leading: leftBarButtonItem, trailing: rightBarButtonItem)
            #endif
        }
    }
}

internal extension WriteAttributeView {
    
    var leftBarButtonItem: some View {
        guard let cancel = self.cancel else {
            return AnyView(EmptyView())
        }
        return AnyView(
            Button(action: {
                cancel()
            }, label: {
                Text("Cancel")
            })
        )
    }
    
    var rightBarButtonItem: some View {
        guard let done = self.done,
            let data = generateData() else {
            return AnyView(EmptyView())
        }
        return AnyView(
            Button(action: {
                done(data)
            }, label: {
                Text("Done")
            })
        )
    }
    
    func generateData() -> Data? {
        return Data(hexadecimal: text)
    }
}
#endif
