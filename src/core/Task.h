#pragma once

#include <QDateTime>
#include <QString>

namespace dias {

struct Task {
    int id = 0;
    QString text;
    QDateTime due;   // invalid -> no due time
    bool done = false;
    QString source = "local";
    QString lastEditedBy = "local";
    int priority = 0;       // 0=none, 1=low, 2=med, 3=high
    QString status = "open"; // open | in_progress | blocked | done
    qint64 updatedAt = 0;
};

} // namespace dias
