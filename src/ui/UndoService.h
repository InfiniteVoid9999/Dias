#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

namespace dias {

class EventListModel;
class TaskListModel;

// Simple linear undo/redo. Each operation records a {description, undoFn,
// redoFn} entry. Bounded stack (default 32). QML triggers via Ctrl+Z /
// Ctrl+Shift+Z which call undo() / redo() Q_INVOKABLE methods.
class UndoService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY canUndoChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY canRedoChanged)
    Q_PROPERTY(QString lastDescription READ lastDescription NOTIFY canUndoChanged)

public:
    using Action = std::function<void()>;

    explicit UndoService(QObject* parent = nullptr);

    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    QString lastDescription() const { return canUndo() ? m_undo.last().description : QString(); }

    // C++ side: record an operation. Caller has already applied it; we store
    // the inverse for undo and a redo to re-apply later.
    void push(const QString& description, Action undo, Action redo);

    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void clear();

signals:
    void canUndoChanged();
    void canRedoChanged();
    void didUndo(QString description);
    void didRedo(QString description);

private:
    struct Entry { QString description; Action undo; Action redo; };
    QList<Entry> m_undo;
    QList<Entry> m_redo;
    int m_max = 32;
};

} // namespace dias
