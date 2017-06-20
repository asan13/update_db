module updb.util;

import std.stdio;

import std.conv : to;
import std.meta;
import std.traits;

void openVim(T...)(string[] files, T extraArgs)
{
    import std.process;


    string[] args = ["vim"];

    if (files.length > 1) 
        args ~= "-O" ~ files.length.to!string;

    foreach (arg; extraArgs)
        args ~= arg.to!string;

    args ~= files;

    execvp(args[0], args);

    writeln("error: cant open ", args);
}
