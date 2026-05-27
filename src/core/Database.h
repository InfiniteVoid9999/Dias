#pragma once

#include <QString>
#include <QtSql/QSqlDatabase>

namespace dias {

class Database {
public:
    explicit Database(QString path);
    ~Database();

    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;

    bool open();
    QSqlDatabase& handle() { return m_db; }

    static QString defaultPath();

private:
    void migrate();
    int userVersion() const;
    void setUserVersion(int v);

    QString m_path;
    QSqlDatabase m_db;
};

} // namespace dias
