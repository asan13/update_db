module updb.dir;

import std.stdio;
import std.conv : to;
import std.string;
import std.file;
import std.path;
import std.regex;


class Dir {

    private string dir;
    string dirName() @property { return dir; }

    string migrationDir(string name, bool check = false)
    {
        string mdir = buildPath(dir, name);

        if (!check) return mdir;

        if (mdir.exists && mdir.isDir) return mdir;
        return null;
    }


    this(string dir)
    {
        this.dir = dir;
    }

    string[] allMigrations()
    {
        import std.algorithm;
        import std.array;

        return dirEntries(dir, SpanMode.shallow)
                .map!(a => a.name)
                .filter!(isDir)
                .array
                .sort;
    }

    string[] find(string name)
    {
        import std.algorithm;
        import std.regex;

        string[] res;

        bool isDigitStart = name.matchFirst(r"^\d+") && true;

        foreach (s; allMigrations)
        {
            string bname = s.baseName;
            if (isDigitStart)
            {
                if (bname.indexOf(name) == 0)
                    res ~= s;
            }
            else
            {
                string s2 = replaceFirst(bname, regex(r"^\d+[_-]"), "");
                if (s2.indexOf(name) >= 0)
                    res ~= s;
            }
        }

        return res;
    }

    string findOne(string name)
    {
        string[] res = find(name);
        return res.length == 1 ? res[0] : null;
    }

    string findFirst(string name = null)
    {
        string[] res;
        if (name.length)
            res = find(name);
        else
            res = allMigrations;

        return res.length > 0 ? res[0] : null;
    }

    string findLast(string name = null)
    {
        string[] res;
        if (name.length)
            res = find(name);
        else
            res = allMigrations;

        return res.length > 0 ? res[$ - 1] : null;
    }


    string getLastPref()
    {
        import std.algorithm;

        auto re = ctRegex!r"^(\d+)";

        int num;
        string pref;
        foreach (subdir; dirEntries(dir, SpanMode.shallow).map!baseName)
        {
            auto m = subdir.matchFirst(re);
            if (!m) continue;

            int n = m[1].to!int;
            if (n > num) 
            {
                num  = n;
                pref = m[1];
            }
        }

        return pref;
    }

    string getNextPref(int width = 0)
    {
        import std.format;

        string pref = getLastPref();
        int     num = pref.length ? pref.to!int + 1 : 1;

        if (!width) 
        {
            if (pref.length) 
                width = cast(int)pref.length;
            else
                width = 4;
        }

        return format("%*1$0d", width, num);
    }

    unittest {
        auto dir = new Dir("./");
        string pref = dir.getNextPref();
        assert(pref == "0001");
    }
}
