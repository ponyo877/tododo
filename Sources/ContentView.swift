import SwiftUI

struct ContentView: View {
    let store: Store
    @State private var input = ""
    @State private var target = Bucket.today
    @FocusState private var adding: Bool

    var body: some View {
        List {
            ForEach(Bucket.allCases, id: \.self) { bucket in
                Section {
                    ForEach(store.items(in: bucket)) { todo in
                        TodoRow(store: store, todo: todo)
                    }
                    .dropDestination(for: String.self) { ids, offset in
                        withAnimation {
                            for (k, id) in ids.compactMap({ UUID(uuidString: $0) }).enumerated() {
                                store.drop(id, into: bucket, at: offset + k)
                            }
                        }
                    }
                } header: {
                    header(for: bucket)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) { addBar }
        .task { adding = true }  // 起動直後から入力できるようにする
        .onChange(of: adding) { _, focused in
            if !focused { target = .today }
        }
    }

    private func header(for bucket: Bucket) -> some View {
        HStack {
            Text(bucket.label)
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
            Spacer()
            Button {
                target = bucket
                adding = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundStyle(Color(.systemGray2))
            }
            .buttonStyle(.plain)
        }
        .textCase(nil)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { ids, _ in
            withAnimation {
                for id in ids.compactMap({ UUID(uuidString: $0) }) {
                    store.drop(id, into: bucket, at: store.items(in: bucket).count)
                }
            }
            return true
        }
    }

    private var addBar: some View {
        TextField(target == .today ? "やること..." : "\(target.label)に追加...", text: $input)
            .focused($adding)
            .submitLabel(.done)
            .onSubmit(submit)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(.systemGray6)))
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            adding = false
        } else {
            withAnimation { store.add(text, to: target) }
            input = ""
            adding = true  // 再フォーカスでキーボードを維持して連続入力
        }
    }
}

struct TodoRow: View {
    let store: Store
    let todo: Todo
    @State private var draft = ""
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { store.toggle(todo.id) }
            } label: {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.done ? Color(.systemGray3) : Color(.systemGray2))
            }
            .buttonStyle(.plain)

            if todo.done {
                HStack(spacing: 0) {
                    Text(todo.text)
                        .foregroundStyle(Color(.systemGray3))
                    Spacer(minLength: 0)
                }
                .overlay {
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(height: 1)
                }

                Button {
                    withAnimation { store.delete(todo.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color(.systemGray4))
                }
                .buttonStyle(.plain)
            } else if editing {
                TextField("", text: $draft)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { focused = false }
                    .onAppear { focused = true }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused {
                            editing = false
                            store.rename(todo.id, to: draft.trimmingCharacters(in: .whitespaces))
                        }
                    }
            } else {
                Text(todo.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draft = todo.text
                        editing = true
                    }
            }
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
        .draggable(todo.id.uuidString)
    }
}
