import std.stdio;
import std.exception;
import std.string;
import std.conv;
import std.range;
import std.algorithm;

import updb.config;
import updb.command;

import dpq.connection;
import dpq.query;
import dpq.result;

enum Command {
    init,
    status,
    create,
    deploy,
    rollback,
    back = rollback,
    disable,
    edit,
    help
}

import std.meta;

auto ref T makeCommand(T)()
    if (is(T == class) || is(T == struct))
{
    auto opts = Config.getCommandOpts!(mixin("T.Opts"));
    static if (is(T == class))
        return new T(opts);
    else
        return T(opts);
}

void processCommand(string commandName)
{
    Command command;
    try {
        command = commandName.to!Command;
    }
    catch (Exception e) {
        throw new Exception("Unknown command " ~ commandName, e);
    }

    switch (command) {
        case Command.init:
            processCommand!(Command.init);
            break;

        case Command.create:
            processCommand!(Command.create);
            break;

        case Command.deploy:
            processCommand!(Command.deploy);
            break;

        case Command.rollback:
            processCommand!(Command.rollback);
            break;

        case Command.edit:
            processCommand!(Command.edit);
            break;

        default:
            throw new Exception(commandName ~ " not implemented");
    }
}

void processCommand(Command command)() 
{

    static if (command == Command.init)
    {
        //auto cmd = new InitCmd;
        auto cmd = makeCommand!InitCmd;
    }
    else static if (command == Command.create)
    {
        //auto cmd = new CreateCmd;
        auto cmd = makeCommand!CreateCmd;
    }
    else static if (command == Command.deploy)
    {
        //auto cmd = new DeployCmd();
        auto cmd = makeCommand!DeployCmd;
    }
    else static if (command == Command.rollback)
    {
        //auto cmd = new RollbackCmd();
        auto cmd = makeCommand!RollbackCmd;
    }
    else static if (command == Command.edit)
        auto cmd = makeCommand!EditCmd;
    else
        static assert(0, command.to!string ~ " not implemented");

    cmd.process();
}

int main(string[] args)
{

    try {

        auto cfg = Config.init();

        if (cfg.needHelp || args.length < 2)
        {
            writeln("usage: ....");
            return 0;
        }
        
        processCommand(args[1]);

    }
    catch (Exception e) {
        writeln(e.msg);

        writeln("=".cycle.take(42));
        writeln(e);
        writeln("=".cycle.take(42));
    }
    



    return 0;
}

