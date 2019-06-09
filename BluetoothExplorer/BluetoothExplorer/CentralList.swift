//
//  ContentView.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI

struct CentralList: View {
    
    @EnvironmentObject private var store: Store
    
    var body: some View {
        List {
            Text("Hey")
            Text("2")
        }.navigationBarTitle(Text("Central"), displayMode: .large)
    }
}

#if DEBUG
extension CentralList : PreviewProvider {
    static var previews: some View {
        CentralList()
    }
}
#endif
