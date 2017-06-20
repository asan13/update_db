module updb.db;

import std.stdio;
import std.string;
import std.conv;
import std.exception;
import std.datetime;
import std.typecons : Nullable;
import std.file;
import std.path;

import dpq.connection;
import dpq.query;
import dpq.result;
import dpq.value;

string maintable_sql(string table)
{
    return "
        CREATE TABLE " ~ table ~ "(
            id          SERIAL       PRIMARY KEY,
            name        text         NOT NULL UNIQUE,
            tag         text,         
            status      int          NOT NULL DEFAULT 0,
            created     timestamp(0) NOT NULL DEFAULT now()
        );"
    ;
}

class DB {
    alias CanM = Nullable!Migration;

    Connection _conn;
    string table;

    Connection conn() @property { return _conn; }

    Result exec(string sql)
    {
        return _conn.exec(sql);
    }

    this(Connection c, string table)
    {
        _conn = c;
        this.table = table;
    }

    bool tableExists()
    {
        Query q = Query(_conn, "SELECT 1 FROM pg_tables WHERE tablename = $1");

        q.addParam(table);
        Result r = q.run();

        return r.rows > 0;
    }

    bool createMainTable()
    {

        if (tableExists)
            return false;

        _conn.exec( maintable_sql(table) );

        return true;
    }


    CanM last()
    {
        Query q = Query(_conn);
        q = "SELECT * FROM migrations ORDER BY id DESC LIMIT 1";
        Result r = q.run;

        CanM res;
        if (r.rows == 0) return res;

        res = Migration(r[0]);
        return res;
    }

    CanM last(MStatus status)
    {
        Query q = Query(_conn);
        q = "SELECT * FROM migrations WHERE status = $1 " ~
            "ORDER BY id DESC LIMIT 1";
        q.addParam(status.to!int);

        Result r = q.run;

        CanM res;
        if (r.rows == 0) return res;

        res = Migration(r[0]);
        return res;
    }



    Migration[] allMigrations()
    {

        Query q = Query(_conn);
        q = "SELECT * FROM " ~ table ~ " ORDER BY id";

        Result res = q.run;

        if (res.rows == 0) return [];

        Migration[] migs;
        foreach (r; res)
        {
            migs ~= Migration(r);
        }

        return migs;
    }

    Migration[] allByStatus(MStatus status)
    {

        Query q = Query(_conn);
        q = "SELECT * FROM " ~ table ~ " WHERE status = $1 ORDER BY id";
        q.addParam(status.to!int);

        Result res = q.run;

        if (res.rows == 0) return [];

        Migration[] migs;
        foreach (r; res)
        {
            migs ~= Migration(r);
        }

        return migs;
    }

    Migration oneByName(string name)
    {

        Query q = Query(_conn);
        q = "SELECT * FROM " ~ table ~ " WHERE name = $1";
        q.addParam(name);

        Result res = q.run;

        if (res.rows == 0) return CanM();

        return CanM(Migration(res[0]));
    }


    bool saveMigration(ref Migration mig, MStatus status)
    {
        Query q = Query(_conn);

        if (mig.id)
        {

            mig.created = cast(DateTime)Clock.currTime;

            q = "UPDATE " ~ table ~ " SET " ~
                "status = $1, created = $2::timestamp(0) " ~
                "WHERE id = $3"
            ;

            q.addParam(status.to!int);
            q.addParam(mig.created.toISOExtString);
            q.addParam(mig.id);

            q.run();
        }
        else
        {
            q = "INSERT INTO " ~ table ~ " (name, tag, status) " ~
                "VALUES ($1, $2, $3) RETURNING id, created"
            ;

            q.addParam(mig.name);
            q.addParam(mig.tag);
            q.addParam(status.to!int);

            Result res = q.run();

            mig.id = res[0]["id"].as!int;
        }

        mig.status = status;

        return true;
    }

    void apply(Migration[] migs, MDirect direct)
    {

        Migration[] commited;

        MStatus status = direct == MDirect.deploy ? MStatus.commited
                                                  : MStatus.uncommited
        ;

        string pStr = direct == MDirect.deploy ? "apply" : "undo";
        pStr ~= ": ";

        if (direct == MDirect.back)
            migs.reverse;

        int done;
        try {

            foreach (mig; migs)
            {
                string sql = mig.getSQL(direct);
                if (sql is null)
                {
                    writeln("warn: file not exists or empty " ~
                            mig.getFile(direct)
                    );
                    continue;
                }

                writeln(pStr, mig.shortInfo);

                exec(sql);
                saveMigration(mig, status);

                commited ~= mig;

                done++;
            }
        }
        catch (Exception e)
        {
            writeln("error: ", e.msg);
            debug writeln(e);

            if (commited.length)
            {
                writeln("try rollback already commited");
                rollbackApplies(commited, direct);
            }

            return;
        }

        if (!done) writeln("nothing to do");
    }

    void applyInTxn(Migration[] migs, MDirect direct)
    {
        MStatus status = direct == MDirect.deploy ? MStatus.commited
                                                  : MStatus.uncommited
        ;

        string pStr = direct == MDirect.deploy ? "apply" : "undo";
        pStr ~= ": ";

        if (direct == MDirect.back)
            migs.reverse;

        int done;
        try {

            exec("BEGIN");

            foreach (mig; migs)
            {

                string sql = mig.getSQL(direct, true);

                if (sql is null)
                {
                    writeln("warn: file not exists or empty " ~
                            mig.getFile(direct)
                    );
                    continue;
                }

                writeln(pStr, mig.shortInfo);

                exec(sql);
                saveMigration(mig, status);
            }

            exec("COMMIT");
        }
        catch (Exception e)
        {
            writeln("error: ", e.msg);
            debug writeln(e);

            try 
            {
                writeln("try rollback changes");
                exec("ROLLBACK");
            }
            catch (Exception e2)
            {
                e2.next = e;
                throw new Exception("rollback failed", e2); 
            }
        }

    }

    void rollbackApplies(Migration[] migs, MDirect undo)
    {

        int done;

        MDirect direct = undo == MDirect.deploy 
            ? MDirect.back 
            : MDirect.deploy;

        MStatus status = direct == MDirect.deploy 
            ? MStatus.commited
            : MStatus.uncommited;

        try {

            foreach_reverse (mig; migs)
            {
                string file = mig.getFile(direct);
                if (!file.exists) continue;

                string sql = file.readText.strip;
                if (!sql.length) continue;

                writeln("try rollback: ", mig.shortInfo);

                exec(sql);
                saveMigration(mig, status);

                done++;
            }
        }
        catch (Exception e)
        {
            import std.array;

            string[] errs = migs[0..$ - done]
                            .map!(m => m.shortInfo)
                            .array
            ;

            throw new Exception(
                    "fatal error in undo apllies: " ~ e.msg ~ "\n" ~
                    (errs.length ? "Not undoned:\n" ~ errs.join("\n") : ""),
                    e
            );
        }
    }
}

enum MDirect { deploy, back }
enum MStatus { commited, uncommited, disabled }

struct Migration {

    int         id;
    string      name;
    string      tag;
    MStatus     status;
    DateTime    created;
    string      dir;
    bool        back;

    this(Row row)
    {
        id     = row["id"].as!int;
        name   = row["name"].as!string;
        tag    = row["tag"].as!string;
        status = row["status"].as!MStatus;
    }

    this(string name, string tag, string dir)
    {
        this.name   = name;
        this.tag    = tag;
        this.status = MStatus.uncommited;
        this.dir    = dir;
    }

    this(string dir)
    {
        this.dir  = dir;
        this.name = baseName(dir);
    }

    string shortInfo()
    {
        import std.format;
        return format("migration %s, %s", name, dir);
    }

    string deployFile() { return "deploy.sql"; }
    string backFile()   { return "back.sql";   }

    string getFile(MDirect direct)
    {
        string file = direct == MDirect.deploy ? deployFile : backFile;
        return buildPath(dir, file);
    }

    string[] getFiles()
    {
        string[] files;
        foreach (direct; [MDirect.deploy, MDirect.back])
        {
            auto file = getFile(direct);
            if (file.exists && file.isFile)
                files ~= file;
        }
        return files;
    }

    string getSQL(MDirect direct, bool delTxnBlock = false)
    {
        string file = getFile(direct);

        if (!file.exists)
            return null;

        string sql = file.readText.strip;

        if (!sql.length)
            return null;

        if (!delTxnBlock)
            return sql;

        string res = deleteTxnBlocks(sql);
        if (res is null)
            return sql;

        return res;
    }

}

string deleteTxnBlocks(string sql)
{
    import std.regex;
    import std.string;
    import std.array : join;

    auto skip_re   = ctRegex!(r"^\s*(?:--|$)");
    auto begin_re  = ctRegex!(r"^\s*BEGIN\s*;", "i");
    auto commit_re = ctRegex!(r"^\s*COMMIT\s*;", "i");

    string[] res;

    int idx, commit_idx;
    bool beginFound;
    foreach (s; sql.lineSplitter)
    {

        if (!beginFound)
        {
            if (s.matchFirst(begin_re))
            {
                res ~= s.replaceFirst(begin_re, "-- " ~ s);
                beginFound = true;
            }
            else res ~= s;
        }
        else
        {
            if (s.matchFirst(commit_re))
                commit_idx = idx;
            res ~= s;
        }

        ++idx;
    }

    if (!beginFound)
        return sql;

    if (!commit_idx)
        return null;

    res[commit_idx] = "-- " ~ res[commit_idx]; 

    return res.join("\n");
}

unittest {

    string sql = "-- comment\nBEGIN;\nCREATE";
    assert(deleteTxnBlocks(sql) is null);

    sql = "CREATE\nTABLE";
    assert(deleteTxnBlocks(sql) == sql);

    sql = "-- comment\nBEGIN;\nCREATE\nCOMMIT;";
    string res = "-- comment\n-- BEGIN;\nCREATE\n-- COMMIT;";
    assert(deleteTxnBlocks(sql) == res);

}


