module updb.command.deploy;

import std.stdio;
import std.string;
import std.path;
import std.file;

import dconfig.options;
import updb.config;
import updb.db;


class DeployCmd {

    struct Opts {
        string name;
        string tag;
        @option("in-txn") bool inTxn;
    }

    private string name;
    private string tag;
    Opts   opts;

    this() 
    {
        auto opts = Config.getCommandOpts!(DeployCmd.Opts);
        this(opts);
    }

    this(Opts opts) {
        this.name = name;
        this.tag  = tag;
        this.opts = opts;
    }


    void process()
    {
        auto cfg = Config.get;
        auto db  = cfg.getDB;

        Migration[] forCommit;

        if (!name.length)
        {
            forCommit = allUncommited();
        }

        if (!forCommit.length) {
            writeln("nothing to do");
            return;
        }

        applyMigrations(forCommit);
    }

    void applyMigrations(Migration[] migs)
    {
        auto db = Config.get.getDB;

        if (opts.inTxn)
        {
            db.applyInTxn(migs, MDirect.deploy);
        }
        else
        {
            db.apply(migs, MDirect.deploy);
        }
    }


    private Migration[] allUncommited()
    {
        import std.algorithm;
        import std.path;

        auto db = Config.get.getDB;

        Migration[string] migs;
        foreach (m; db.allMigrations)
        {
            migs[m.name] = m;
        }

        auto topdir = Config.get.getDir;

        Migration[] forCommit;
        foreach (dir; topdir.allMigrations)
        {
            string mname = baseName(dir);
            if (mname in migs)
            {
                auto m = migs[mname];
                if (m.status == MStatus.uncommited)
                {
                    m.dir = dir;
                    forCommit ~= m;
                }
            }
            else
            {
                forCommit ~= Migration(mname, mname, dir);
            }
        }

        return forCommit;
    }
}
