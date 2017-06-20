module updb.command.init;

import std.stdio;
import std.exception;
import std.file;
import std.path;

import updb.command.base;


class InitCmd {

    struct Opts {
        bool force;
    }

    Opts opts;

    this() 
    {
        auto opts = Config.getCommandOpts!(InitCmd.Opts);
        this(opts);
    }

    this(Opts opts)
    {
        this.opts = opts;
    }


    void process() {
        auto cfg = Config.get;

        string table = cfg.table;
        enforce(table.length, new Exception("table name not given"));

        string dir = cfg.dir;
        enforce(dir.length, new Exception("main directory not given"));
        
        bool dirCreated;
        if (dir.exists)
            writeln("directory ", dir, " already exists");
        else
        {
            mkdir(dir);
            dirCreated = true;
        }

        scope(failure) {
            if (dirCreated) rmdirRecurse(dir);
        }

        auto db = cfg.getDB;


        if (!db.createMainTable) {
            writeln("table " ~ cfg.table ~ " already exists");
            return;
        }

    }
}
