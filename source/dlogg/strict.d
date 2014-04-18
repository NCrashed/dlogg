// This file is written in D programming language
/**
*   Default synchronized log realization. The logging process performs
*   instantly (if it can be processed properly). Logger puts message
*   style string and current timestamp before the message.
*
*   Tested to be able operate in daemon mode and under heavy concurrent
*   writing.
*
*   Copyright: © 2013-2014 Anton Gushcha
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module dlogg.strict;

public import dlogg.log;
import std.stream;
import std.path;
import std.stdio;
import std.file;
import std.conv;
import std.datetime;
import std.traits;

/**
*   Standard implementation of ILogger interface.
*
*   Example:
*   -----------
*   shared ILogger logger = new StrictLogger("my_awesome_log.log");
*   logger.minOutputLevel = LoggingLevel.Warning; // info msgs won't be printed in console 
*   logger.logInfo("Info message!");
*   logger.logError("Error message!");
*   logger.logDebug("Debug message!");
*
*   // received USR1 signal from logrotate
*   logger.reload;
*   -----------
*/
synchronized class StrictLogger : ILogger
{
    /// Option how to open logging file
    enum Mode
    {
        /// Don't override, append to end
        Append,
        /// Override, start new file
        Rewrite
    }
    
    nothrow
    {   
        /**
        *   Log file name.
        */
        string name() const @property @safe
        {
            return mName;
        }

        /**
        *   Prints message into log. Displaying in the console
        *   controlled by minOutputLevel property.
        */
        void log(lazy string message, LoggingLevel level) @trusted
        {
            scope(failure) {}

            if(level >= mMinOutputLevel)
                writeln(logsStyles[level]~message);

            try
            {
                rawInput(formatString(message, level));
            }
            catch(Exception e)
            {
                if(minOutputLevel != LoggingLevel.Muted)
                    writeln(logsStyles[LoggingLevel.Warning], "Failed to write into log ", name);
            }
        }
        
        /**
        *   Returns: minimum log level,  will be printed in the console.
        */
        LoggingLevel minOutputLevel() const @property @trusted
        {
            return mMinOutputLevel;
        }

        /**
        *   Setups minimum log level, 
        */
        void minOutputLevel(LoggingLevel level) @property @trusted
        {
            mMinOutputLevel = level;
        }
    }

    /**
    *   Checks if the log file is exists at specified $(B location) and
    *   if can't find it, recreates the file and continues write into it.
    *
    *   Useful for $(B logrotate) utility. GNU/Linux system checks file identity by
    *   inode, that doesn't change while renaming. Thus after renaming the file at 
    *   $(B location) log continues write into the renamed file. The call to the
    *   $(B reload) method force splitting log into two parts.
    */
    void reload()
    {
        if(!name.exists)
        {
            initialize();
        }
    }
    
    /**
    *   Creates log at $(B dir)/$(B name). Tries to create parent directory
    *   and all sub directories.
    *
    *   Note: Can throw if there is a problem with access permissions.
    */ 
    this(string name, Mode mode = Mode.Rewrite) @trusted
    {
        mName = name;
        initialize(mode);
    }
    
    /**
    *   Tries to create log file at $(B location).
    */
    protected void initialize(Mode mode = Mode.Rewrite) @trusted
    {
        auto dir = name.dirName;
        try
        {
            if (!dir.exists)
            {
                dir.mkdirRecurse;
            }
            mLogFiles[this] = new std.stream.File(name, mapMode(mode));
        } 
        catch(OpenException e)
        {
            throw new Exception(text("Failed to create log at '", name, "'. Details: ", e.msg));
        }
    }
    
    /// Transforms custom mode to file open mode
    private static FileMode mapMode(Mode mode)
    {
        final switch(mode)
        {
            case(Mode.Append): return FileMode.Append;
            case(Mode.Rewrite): return FileMode.OutNew;
        }
    } 
    
    protected this()
    {
        mName = "";
        mMinOutputLevel = LoggingLevel.Notice;
    }
    
    /**
    *   Format message with default logging style (etc. time and level string).
    */
    string formatString(lazy string message, LoggingLevel level) @trusted
    {
        auto timeString = Clock.currTime.toISOExtString();
        return text("[", timeString, "]:", logsStyles[level], message);
    }
    
    /**
    *   Unsafe write down the message without any meta information.
    */
    void rawInput(string message)  @trusted
    {
        mLogFiles[this].writeLine(message);
    }
    
    /**
    *   Used to manual shutdown protocols.
    */
    void finalize() @trusted
    {
        if(finalized) return;
        
        scope(failure) {}
        scope(exit) finalized = true;
        
        close();
    }
    
    ~this()
    {
        finalize();
    }

    private
    {
        immutable(string) mName;
        __gshared std.stream.File[shared StrictLogger] mLogFiles;
        shared LoggingLevel mMinOutputLevel;
        bool finalized = false;
        
        void close()
        {
            mLogFiles[this].close();
        }
    }
}

/// Display styles
private immutable(string[LoggingLevel]) logsStyles;

static this() 
{
    logsStyles = [
        LoggingLevel.Notice  :   "Notice: ",
        LoggingLevel.Warning :   "Warning: ",
        LoggingLevel.Debug   :   "Debug: ",
        LoggingLevel.Fatal   :   "Error: ",
        LoggingLevel.Muted   :   "",
    ];
}

version(unittest)
{
    import std.concurrency;
    
    void testThread(shared ILogger logger, Tid owner, int i, uint n)
    {
        foreach(j; 1 .. n)
        {
            logger.logInfo(to!string(j));
            logger.logError(to!string(j));
        }
        
        send(owner, true);
    }
}
unittest
{
    import std.regex;
    import std.path;
    import std.file;
    import std.stdio;

    write("Testing log system... ");
    scope(success) writeln("Finished!");
    scope(failure) writeln("Failed!");

    auto logger = new shared StrictLogger("TestLog");
    logger.minOutputLevel = LoggingLevel.Muted;
    logger.log("Notice msg!", LoggingLevel.Notice);
    logger.log("Warning msg!", LoggingLevel.Warning);
    logger.log("Debug msg!", LoggingLevel.Debug);
    logger.log("Fatal msg!", LoggingLevel.Fatal);
    logger.close();

    auto f = new std.stdio.File(logger.name, "r");
    // Delete date string before cheking string
    assert(replace(f.readln()[0..$-1], regex(r"[\[][\p{InBasicLatin}]*[\]][:]"), "") == logsStyles[LoggingLevel.Notice]~"Notice msg!", "Log notice testing fail!");
    assert(replace(f.readln()[0..$-1], regex(r"[\[][\p{InBasicLatin}]*[\]][:]"), "") == logsStyles[LoggingLevel.Warning]~"Warning msg!", "Log warning testing fail!");
    assert(replace(f.readln()[0..$-1], regex(r"[\[][\p{InBasicLatin}]*[\]][:]"), "") == logsStyles[LoggingLevel.Debug]~"Debug msg!", "Log debug testing fail!");
    assert(replace(f.readln()[0..$-1], regex(r"[\[][\p{InBasicLatin}]*[\]][:]"), "") == logsStyles[LoggingLevel.Fatal]~"Fatal msg!", "Log fatal testing fail!");
    f.close();

    immutable n = 10;
    foreach(i; 1 .. n)
    {
        spawn(&testThread, logger, thisTid, i, n);
    }
    
    auto t = TickDuration.currSystemTick + cast(TickDuration)dur!"seconds"(2);
    auto ni = 0;
    while(ni < n && t > TickDuration.currSystemTick) 
    {
        ni += 1;
    }
    assert(ni == n, "Concurrent logging test is failed!");
    
    remove(logger.name);
}