module updb.command.base;

public import updb.config;
public import updb.db;


class Command {
    abstract void process();
    void rollback() { }
}
