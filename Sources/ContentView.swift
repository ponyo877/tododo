import SwiftUI

struct ContentView: View {
    let store: Store
    @State private var input = ""
    @State private var target = Bucket.today
    @State private var adding = false
    @State private var canSort = false
    @State private var sorting = false
    @State private var observing = false  // ✨後の手直しをお手本として観測中
    @State private var corrected = false
    @State private var editingID: UUID?   // 入力欄で文字を編集中のタスク

    var body: some View {
        List {
            ForEach(store.rows) { row in
                switch row {
                case .header(let bucket):
                    header(for: bucket)
                        .background(RowTuner(isHeader: true))
                        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                case .todo(let todo):
                    TodoRow(store: store, todo: todo, isEditing: editingID == todo.id) {
                        editingID = todo.id
                        input = todo.text
                        adding = true
                    }
                    .background(RowTuner(isHeader: false))
                }
            }
            .onMove { source, destination in
                store.move(from: source, to: destination)
                captureCorrection()
            }
        }
        .onTapGesture { adding = false }  // タスク行以外（空き領域・見出し）のタップでキーボードを閉じる
        .listStyle(.plain)
        .listRowSpacing(2)
        .environment(\.defaultMinListRowHeight, 44)
        .environment(\.editMode, .constant(.active))  // 常時グリップ表示＝長押し不要で即並べ替え
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if store.todos.isEmpty {  // 空のときだけ、線画のドードーが静かに待っている（テンプレート描画でダークモードは白線）
                Image("DodoOutline")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260)
                    .foregroundStyle(.primary)
                    .opacity(0.25)
                    .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom) { addBar }
        .task {
            canSort = Sorter.isAvailable  // 初回フレーム後に判定して起動パスを汚さない
            adding = true
        }
        .onChange(of: adding) { _, focused in
            if !focused {
                target = .today
                if editingID != nil {  // 確定せずに閉じたら編集キャンセル
                    editingID = nil
                    input = ""
                }
            }
        }
    }

    private func header(for bucket: Bucket) -> some View {
        HStack {
            Text(bucket.label)
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
            Spacer()
            if bucket == .today && canSort && pendingToday.count >= 2 {
                if sorting {
                    ProgressView()
                } else {
                    Button(action: runSort) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(Color(.systemGray2))
                    }
                    .buttonStyle(.plain)
                }
            }
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
    }

    private var pendingToday: [Todo] {
        store.items(in: .today).filter { !$0.done }
    }

    private func runSort() {
        let pending = pendingToday
        guard pending.count >= 2, !sorting else { return }
        sorting = true
        Task {
            if let ordered = await Sorter.sortedOrder(of: pending) {
                withAnimation { store.reorder(.today, to: ordered) }
                observing = true
                corrected = false
            }
            sorting = false
        }
    }

    private func captureCorrection() {
        guard observing else { return }
        Sorter.saveExemplar(pendingToday.map(\.text), replacingLast: corrected)
        corrected = true
    }

    private var addBar: some View {
        HStack(spacing: 12) {
            Image("Dodo")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
            InputField(
                text: $input,
                isFocused: $adding,
                placeholder: target == .today ? "やること..." : "\(target.label)に追加...",
                onSubmit: submit
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(.systemGray6)))
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespaces)
        if let id = editingID {
            if !text.isEmpty { store.rename(id, to: text) }
            editingID = nil
            input = ""
            adding = false
        } else if text.isEmpty {
            adding = false
        } else {
            withAnimation { store.add(text, to: target) }
            input = ""  // フォーカスは外れないのでそのまま連続入力できる
        }
    }
}

// 入力欄。SwiftUIのTextFieldはReturnで必ず一度first responderを手放し、
// 再フォーカスまでの間にキーボードが下がって戻る（チカチカ）ため、
// UITextFieldを薄く包んでReturnでもフォーカスを保持する
struct InputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.returnKeyType = .done
        field.font = .preferredFont(forTextStyle: .body)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        if isFocused, !field.isFirstResponder {
            if field.window == nil {
                DispatchQueue.main.async { field.becomeFirstResponder() }
            } else {
                field.becomeFirstResponder()
            }
        } else if !isFocused, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    // 高さは文字の固有サイズ、幅は与えられた分（safeAreaInset内で縦に広がらないように）
    func sizeThatFits(_ proposal: ProposedViewSize, uiView field: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? field.intrinsicContentSize.width, height: field.intrinsicContentSize.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: InputField

        init(_ parent: InputField) {
            self.parent = parent
        }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return false  // キーボードを閉じない（閉じるかどうかはisFocusedで制御）
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            parent.isFocused = false
        }
    }
}

// UIKitのセルに手を入れて並べ替えの感触を調整する。
// 見出し行: グリップを隠し、行本体の長押しも無効化（moveDisabledは「壁」になるため使わない）
// タスク行: 行本体の長押し（標準0.5秒）を短縮して、どこを押してもすぐ持ち上がるようにする
struct RowTuner: UIViewRepresentable {
    let isHeader: Bool

    func makeUIView(context: Context) -> RowTunerView {
        RowTunerView()
    }

    func updateUIView(_ view: RowTunerView, context: Context) {
        view.isHeader = isHeader
        view.tune()
        DispatchQueue.main.async { view.tune() }
    }
}

final class RowTunerView: UIView {
    var isHeader = false {
        didSet { syncWatch() }
    }
    private var watch: Timer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        tune()
        DispatchQueue.main.async { self.tune() }
        syncWatch()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tune()
    }

    // UIKitはセル再構成のたびにグリップと長押しを作り直すため、見出し行は周期的に再適用する
    private func syncWatch() {
        watch?.invalidate()
        watch = nil
        guard isHeader, window != nil else { return }
        watch = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tune() }
        }
    }

    func tune() {
        var current: UIView? = self
        while let view = current, !(view is UICollectionViewCell) {
            current = view.superview
        }
        guard let cell = current else { return }
        for subview in cell.subviews {
            let name = String(describing: type(of: subview))
            if name.contains("ReorderControl") {
                subview.isHidden = isHeader
                subview.isUserInteractionEnabled = !isHeader
            }
            if name.contains("ContentView") {
                for press in subview.gestureRecognizers?.compactMap({ $0 as? UILongPressGestureRecognizer }) ?? [] {
                    press.isEnabled = !isHeader
                    press.minimumPressDuration = isHeader ? .greatestFiniteMagnitude : 0
                }
            }
        }
    }
}

struct TodoRow: View {
    let store: Store
    let todo: Todo
    let isEditing: Bool
    let onEdit: () -> Void
    @State private var dragX: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(todo.done ? Color(.systemGray3) : Color(.systemGray2))

            if todo.done {
                HStack(spacing: 0) {
                    Text(todo.text)
                        .lineLimit(1)
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
            } else {
                Text(todo.text)
                    .lineLimit(1)
                    .foregroundStyle(isEditing ? Color(.systemGray2) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onEdit)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}  // 行内のタップはListの「閉じる」に流さない
        .offset(x: dragX)
        .background(alignment: .leading) {
            Image(systemName: "checkmark")
                .foregroundStyle(Color(.systemGray2))
                .opacity(min(dragX / 50, 1))
        }
        // 編集モード中は標準のswipeActionsが効かないため、右スワイプ＝完了トグルを自前で判定する
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    let t = value.translation
                    guard t.width > 0, t.width > abs(t.height) else { return }
                    dragX = min(t.width, 80)
                }
                .onEnded { _ in
                    if dragX > 50 {
                        withAnimation { store.toggle(todo.id) }
                    }
                    withAnimation(.easeOut(duration: 0.15)) { dragX = 0 }
                }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
    }
}
