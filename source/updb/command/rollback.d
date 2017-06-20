module updb.command.rollback;

import std.stdio;
import std.exception;
import std.string;
import std.path;
import std.file;
import std.typecons : Nullable;


import updb.config;
import updb.db;
import dconfig.options;

class RollbackCmd {

    struct Opts {
        string name;
        string tag;
        @option("force-next") bool forceNext;
        @option("force-all")  bool forceAll;
        @option("in-txn")     bool inTxn;
    }

    private string name;
    private string tag;
    private Opts   opts;

    this() 
    {
        auto o = Config.getCommandOpts!(RollbackCmd.Opts);
        this(o);
    }

    this(Opts opts)
    {
        enforce(!(opts.forceNext && opts.forceAll),
                new Exception(
                    "only one --force-next and --force-all allowed"
                    ) 
        );

        this.name = opts.name;
        this.tag  = opts.tag;
        this.opts = opts;
    }

    void process()
    {
        import std.algorithm;
        import std.array;

        auto cfg = Config.get;
        auto db  = cfg.getDB;

        Migration[] forCommit;

        if (name.length)
        {
        }
        else if (tag.length)
        {
        }
        else
        {
            if (opts.forceNext)
            {
                auto mig = lastCommited();
                if (!mig.isNull)
                {
                    forCommit ~= mig.get;
                }
            }
            else if (opts.forceAll)
            {
                forCommit = allCommited();
            }
            else
            {
                auto mig = lastMigration();

                if (!mig.isNull)
                {

                    if (mig.status == MStatus.commited)
                    {
                        forCommit ~= mig.get;
                    }
                    else
                    {
                        writeln("last migration undone already");
                        writeln("use --force-next key for undoned previous");
                    }

                }
            }
        }

        applyMigrations(forCommit);
    }

    void applyMigrations(Migration[] migs)
    {
        auto db = Config.get.getDB;

        if (opts.inTxn)
        {
            db.applyInTxn(migs, MDirect.back);
        }
        else
        {
            db.apply(migs, MDirect.back);
        }
    }

    Migration[] allCommited()
    {
        auto db  = Config.get.getDB;
        auto dir = Config.get.getDir;

        Migration[] migs = db.allByStatus(MStatus.commited);
        
        foreach (mig; migs)
        {
            string subDir = dir.migrationDir(mig.name);

            if (!(subDir.exists && subDir.isDir))
            {
                writeln("directory not exists: ", subDir);
                continue;
            }

            mig.dir = subDir;
            migs ~= mig;
        }

        return migs;

    }

    alias CanM = Nullable!Migration;

    CanM lastMigration(bool commited = false)
    {
        auto db = Config.get.getDB;

        auto mig = commited ? db.last(MStatus.commited) : db.last;

        if (mig.isNull) 
            return mig;

        auto dir = Config.get.getDir;
        string subDir = dir.migrationDir(mig.name);

        if (!(subDir.exists && subDir.isDir))
        {
            writeln("directory not exists: ", subDir);
            return CanM();
        }

        mig.dir = subDir;

        return mig;
    }

    CanM lastCommited()
    {
        return lastMigration(true);
    }

}

