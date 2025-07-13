//
//  AsyncButton.swift
//  
//
//  Created by Alsey Coleman Miller on 23/12/21.
//

import SwiftUI

enum ActionOption: CaseIterable {
    case disableButton
    case showProgressView
}

// https://www.swiftbysundell.com/articles/building-an-async-swiftui-button/
struct AsyncButton<Label: View>: View {
    
    var action: () async -> Void
    var actionOptions = Set(ActionOption.allCases)
    
    @ViewBuilder var label: () -> Label
    
    @State private var isDisabled = false
    @State private var showProgressView = false
    
    var body: some View {
        Button(
            action: {
                if actionOptions.contains(.disableButton) {
                    isDisabled = true
                }
            
                Task {
                    var progressViewTask: Task<Void, Error>?

                    if actionOptions.contains(.showProgressView) {
                        progressViewTask = Task {
                            try await Task.sleep(nanoseconds: 150_000_000)
                            showProgressView = true
                        }
                    }

                    await action()
                    progressViewTask?.cancel()

                    isDisabled = false
                    showProgressView = false
                }
            },
            label: {
                ZStack {
                    label().opacity(showProgressView ? 0 : 1)

                    if showProgressView {
                        ProgressView()
                    }
                }
            }
        )
        .disabled(isDisabled)
    }
}
