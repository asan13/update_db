module updb.config;

import std.stdio;
import std.datetime;

import dpq.connection;
import dconfig.config;

import updb.dir;
import updb.db;

struct Config {
    mixin MyConfig;

    struct DBOpts {
        string dbname;
        string user;
        string password;
        string host;
        int    port;
    }

    @name("db") DBOpts db;
    string dir;
    string table;
    int    prefWidth = 4;

    Dir getDir()
    {
        return new Dir(dir);
    }

    DB getDB()
    {
        static DB db_inst;

        if (db_inst is null)
        {
            db_inst = new DB( conn, table );
        }

        return db_inst;
    }

    Connection conn() 
    {
        static Connection _conn;
        static bool connected;

        if (!connected)
        {
            _conn = Connection( db.conninfo );
            connected = true;
        }

        return _conn;
    }

}

string conninfo(Config.DBOpts db)
{
    import std.array;
    import std.conv;

    string[] opts;
    
    if (db.dbname) opts     ~= "dbname="   ~ db.dbname;
    if (db.user) opts       ~= "user="     ~ db.user;
    if (db.password) opts   ~= "password=" ~ db.password;
    if (db.host) opts       ~= "host="     ~ db.host;
    if (db.port) opts       ~= "port="     ~ to!string(db.port);

    return opts.join(" ");
}


