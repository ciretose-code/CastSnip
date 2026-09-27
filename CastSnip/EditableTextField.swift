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
    @FocusState private var focused: Bool
    
    var body: some View {
        TextField(placeholderText, text: $text)
            .focused($focused)
            .onTapGesture {
                focused = true
            }
            .onExitCommand {
                focused = false
            }
    }
}
