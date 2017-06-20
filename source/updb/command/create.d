module updb.command.create;

import std.stdio;
import std.path;
import std.exception;
import std.file;
import std.conv : to;

import dconfig.options;
import updb.config;
import updb.db;
import updb.dir;
import updb.util : openVim;

enum DeployFile = "deploy.sql";
enum BackFile   = "back.sql";

class CreateCmd {

    private string name;
    private string tag;
    private string migDir;

    private Opts opts;

    struct Opts {
        string name;
        string tag;
        @option("exact-name") bool exactName;
        @option("edit", "e") bool doEdit;
    }

    this()
    {
        opts = Config.getCommandOpts!(CreateCmd.Opts);
        this(opts);
    }

    this(Opts opts)
    {
        enforce(name.length, new Exception("name required"));

        this.opts = opts;

        this.name  = opts.name;
        this.tag   = opts.tag.length ? opts.tag : opts.name;
    }


    private string getDirName()
    {
        import std.algorithm;

        assert(name.length, "name must be given");

        auto cfg = Config.get;

        if (opts.exactName)
        {
            return buildPath(cfg.dir, name);
        }

        auto dir = cfg.getDir;
        string pref   = dir.getNextPref(cfg.prefWidth);
        string subDir = pref ~ "_" ~ name;

        return buildPath(cfg.dir, subDir);
    }


    void process()
    {

        auto dir = Config.get.getDir;

        string subDir = getDirName();
        enforce(!subDir.exists, "subdir " ~ subDir ~ " alredy exists");

        mkdir(subDir);
        scope(failure) rmdirRecurse(subDir);

        string[] files = [DeployFile, BackFile];
        foreach (ref fn; files)
        {
            fn = buildPath(subDir, fn);
            File(fn, "w");
        }

        migDir = subDir;

        if (opts.doEdit)
        {
            openVim(files);
        }
    }
}


