#include "UndoService.h"

namespace dias {

UndoService::UndoService(QObject* parent) : QObject(parent) {}

void UndoService::push(const QString& description, Action undo, Action redo) {
    m_undo.append({description, std::move(undo), std::move(redo)});
    while (m_undo.size() > m_max) m_undo.removeFirst();
    m_redo.clear();
    emit canUndoChanged();
    emit canRedoChanged();
}

void UndoService::undo() {
    if (m_undo.isEmpty()) return;
    Entry e = m_undo.takeLast();
    if (e.undo) e.undo();
    m_redo.append(e);
    emit canUndoChanged();
    emit canRedoChanged();
    emit didUndo(e.description);
}

void UndoService::redo() {
    if (m_redo.isEmpty()) return;
    Entry e = m_redo.takeLast();
    if (e.redo) e.redo();
    m_undo.append(e);
    emit canUndoChanged();
    emit canRedoChanged();
    emit didRedo(e.description);
}

void UndoService::clear() {
    m_undo.clear();
    m_redo.clear();
    emit canUndoChanged();
    emit canRedoChanged();
}

} // namespace dias
