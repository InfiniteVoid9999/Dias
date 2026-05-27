#pragma once

#include <QDateTime>
#include <QString>

namespace dias {

struct Task {
    int id = 0;
    QString text;
    QDateTime due;   // invalid -> no due time
    bool done = false;
};

} // namespace dias
