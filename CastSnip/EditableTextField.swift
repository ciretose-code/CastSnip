//
//  EditableTextField.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/7/24.
//

import SwiftUI

struct EditableTextField: View {
    @Binding var text: String
    var placeholderText: String = ""
    @State private var tempText: String
    @FocusState private var focused: Bool
    
    init(text: Binding<String>, placeholderText: String = "") {
        self._text = text
        self.tempText = text.wrappedValue
        self.placeholderText = placeholderText
    }
    
    var body: some View {
        TextField(placeholderText, text: $tempText, onCommit: { text = tempText })
            .focused($focused, equals: true)
            .onTapGesture {
                focused = true
            }
        #if os(macOS)
            .onExitCommand(perform: {
                tempText = text
                focused = false
            })
        #endif
    }
}
