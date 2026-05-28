#pragma once

#include <QString>

namespace dias {

struct Calendar {
    int     id = 0;
    QString name;
    QString color = "#cba6f7";
    bool    visible = true;
    qint64  createdAt = 0;
};

} // namespace dias
