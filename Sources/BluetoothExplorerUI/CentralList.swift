//
//  CentralList.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI
import BluetoothExplorerModel

public struct CentralList: View {
    
    typealias ViewModel = CentralListViewModel
    
    @Environment(Store.self)
    var store: Store
    
    public init() { }
    
    public var body: some View {
        ContentView(store)
    }
    
    struct ContentView: View {
        
        @State
        var viewModel: ViewModel
        
        init(_ store: Store) {
            _viewModel = State(initialValue: CentralListViewModel(store: store))
        }
        
        var body: some View {
            ListView(scanResults: viewModel.scanResults)
                .navigationTitle(Text("Central"))
                .toolbar {
                    leftBarButtonItem
                }
        }
        
        var leftBarButtonItem: CentralList.LeftBarButtonItem {
            LeftBarButtonItem(
                isEnabled: viewModel.isEnabled,
                isScanning: viewModel.isScanning,
                canToggleScan: viewModel.canToggleScan,
                toggle: { viewModel.scanToggle() }
            )
        }
    }
    
    struct ListView: View {
        
        let scanResults: [CentralListViewModel.ScanResult]
        
        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(scanResults) { item in
                        NavigationLink(destination: {
                            EmptyView()
                        }, label: {
                            CentralCell(item)
                        })
                    }
                }
            }
        }
    }
    
    struct LeftBarButtonItem: View {
        
        let isEnabled: Bool
        
        let isScanning: Bool
        
        let canToggleScan: Bool
        
        let toggle: () -> ()
        
        var body: some View {
            switch isEnabled {
            case false:
                return AnyView(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                )
            case true:
                return AnyView(Button(action: toggle) {
                    isScanning ? Text("Stop") : Text("Scan")
                }.disabled(canToggleScan == false))
            }
        }
    }
}
