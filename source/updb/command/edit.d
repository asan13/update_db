module updb.command.edit;

import std.stdio;
import std.string;
import std.conv : to;
import std.array;
import std.path;
import std.file;

import dconfig.options;
import updb.config;
import updb.db;
import updb.util : openVim;

class EditCmd {

    struct Opts {
        string name;
        @option("type", "t") string type;
    }

    Opts opts;

    this(Opts opts)
    {
        this.opts = opts;
    }

    void process()
    {
        auto dir = Config.get.getDir;

        string name = opts.name;

        if (name.length)
        {
            string[] names = dir.find(name);
            if (!names.length) 
            {
                writeln("not found for name " ~ name);
                return;
            }

            if (names.length > 1)
            {
                writeln("Several dirs found:\n", names.join("\n"));
                return;
            }

            name = names[0];

        }
        else
        {
            name = dir.findLast();
        }

        if (!name.length)
        {
            writeln("not found");
            return;
        }

        auto mig = Migration(name);

        MDirect[] types;
        if (opts.type) {

            MDirect type;

            try { type = opts.type.to!MDirect; }
            catch (Exception e) {
                writeln("unknown type ", opts.type);
                return;
            }

            types ~= type;
        }
        else
            types = [MDirect.deploy, MDirect.back];

        string[] files;
        foreach (direct; types)
        {
            auto file = mig.getFile(direct);
            if (file.exists && file.isFile)
                files ~= file;
            else
                writeln("file " ~ file ~ " not exists");
        }

        if (!files.length) return;

        openVim(files);
    }

}


