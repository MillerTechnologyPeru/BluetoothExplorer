//
//  DecodedFieldsView.swift
//  BluetoothExplorerUI
//
//  Renders a plugin's decoded fields as label/value rows. Stays within the Skip-supported SwiftUI
//  subset (no ByteCountFormatter; Text(verbatim:) throughout).
//

#if canImport(SwiftUI)
import SwiftUI
#else
import AndroidSwiftUI
#endif
import BluetoothExplorerModel
import BluetoothExplorerPluginEngine

struct DecodedFieldsView: View {

    let result: DecodedResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = result.title {
                Text(verbatim: title)
                    .font(.headline)
            }
            ForEach(result.fields) { field in
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: field.label)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer(minLength: 8)
                    Text(verbatim: displayValue(field))
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func displayValue(_ field: DecodedField) -> String {
        if let unit = field.unit {
            return field.value.displayString + " " + unit
        }
        return field.value.displayString
    }
}
