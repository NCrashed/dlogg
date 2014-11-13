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
import dlogg.style;

import std.stream;
import std.path;
import std.stdio;
import std.file;
import std.conv;
import std.datetime;
import std.traits;

version(ColoredOutput)
{
    import colorize;
    
    version(Windows)
    {
        /**
        *   Standard implementation of IStyledLogger interface.
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
        alias StrictLogger = StyledStrictLogger!(LoggingLevel
                        , LoggingLevel.Debug,   "Debug:".color(fg.light_magenta) ~ " %1$s",   "[%2$s]: Debug: %1$s"
                        , LoggingLevel.Notice,  "Notice:".color(fg.light_green) ~ " %1$s",  "[%2$s]: Notice: %1$s"
                        , LoggingLevel.Warning, "Warning:".color(fg.light_yellow) ~ " %1$s", "[%2$s]: Warning: %1$s"
                        , LoggingLevel.Fatal,   "Fatal:".color(fg.light_red) ~ " %1$s",   "[%2$s]: Fatal: %1$s"
                        , LoggingLevel.Muted,   "",              ""
                        );
    } else
    {
        /**
        *   Standard implementation of IStyledLogger interface.
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
        alias StrictLogger = StyledStrictLogger!(LoggingLevel
                        , LoggingLevel.Debug,   "Debug:".color(fg.magenta) ~ " %1$s",   "[%2$s]: Debug: %1$s"
                        , LoggingLevel.Notice,  "Notice:".color(fg.green) ~ " %1$s",  "[%2$s]: Notice: %1$s"
                        , LoggingLevel.Warning, "Warning:".color(fg.light_yellow) ~ " %1$s", "[%2$s]: Warning: %1$s"
                        , LoggingLevel.Fatal,   "Fatal:".color(fg.light_red) ~ " %1$s",   "[%2$s]: Fatal: %1$s"
                        , LoggingLevel.Muted,   "",              ""
                        );
    
    }
} else
{
    /**
    *   Standard implementation of IStyledLogger interface.
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
    alias StrictLogger = StyledStrictLogger!(LoggingLevel
                    , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s]: Debug: %1$s"
                    , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s]: Notice: %1$s"
                    , LoggingLevel.Warning, "Warning: %1$s", "[%2$s]: Warning: %1$s"
                    , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s]: Fatal: %1$s"
                    , LoggingLevel.Muted,   "",              ""
                    );
}
/**
*   Implementation of $(B IStyledLogger) with custom style. Usually you want to use
*   $(B StrictLogger) alias, but there are cases where you want custom styles.
*
*   Example of custom styled logger:
*   --------------------------------
*   enum MyLevel
*   {
*       Error,
*       Debug
*   }
*   
*   alias MyLogger = StyledStrictLogger!(MyLevel
*               , MyLevel.Debug,   "Debug: %1$s",   "[%2$s] Debug: %1$s"
*               , MyLevel.Error,   "Fatal: %1$s",   "[%2$s] Fatal: %1$s");
*   --------------------------------
*
*   See_Also: dlogg.style
*/
synchronized class StyledStrictLogger(StyleEnum, US...) : IStyledLogger!StyleEnum
{
    mixin generateStyle!(StyleEnum, US);
    alias thistype = StyledStrictLogger!(StyleEnum, US);
    
    /// Option how to open logging file
    enum Mode
    {
        /// Don't override, append to end
        Append,
        /// Override, start new file
        Rewrite
    }
    
    /**
    *   Log file name.
    */
    string name() const nothrow @property @safe
    {
        return mName;
    }

    /**
    *   Setting new log file name. If the $(B value)
    *   differs from old one, logger should close
    *   old one and open new file.
    */
    void name(string value) @property @trusted
    {
        if(mName == value) return;
        
        close();
        mName = value;
        initialize(mSavedMode);
    }
    
    nothrow
    { 
        /**
        *   Prints message into log. Displaying in the console
        *   controlled by minOutputLevel property.
        */
        void log(lazy string message, StyleEnum level) @trusted
        {
            //scope(failure) {}
            try
            {
	            if(level >= mMinOutputLevel)
	            {
	                string msg = formatConsoleOutput(message, level);
	                version(ColoredOutput) cwriteln(msg);
	                else writeln(msg);
	            }
	            
	            if(level >= mMinLoggingLevel)
	            {
	                try
	                {
	                    rawInput(formatFileOutput(message, level));
	                }
	                catch(Exception e)
	                {
	                    if(minOutputLevel != LoggingLevel.Muted)
	                        writeln("Failed to write into log ", name);
	                }
	            }
            } catch(Throwable th)
            {
            	
            }
        }
        
        /**
        *   Returns: minimum log level,  will be printed in the console.
        */
        StyleEnum minOutputLevel() const @property @trusted
        {
            return mMinOutputLevel;
        }

        /**
        *   Setups minimum log level, 
        */
        void minOutputLevel(StyleEnum level) @property @trusted
        {
            mMinOutputLevel = level;
        }
        
        /**
        *   Setups minimum message level that goes to file.
        */
        StyleEnum minLoggingLevel() @property
        {
            return mMinLoggingLevel;
        }
        
        /**
        *   Setups minimum message level that goes to file.
        */
        void minLoggingLevel(StyleEnum level) @property
        {
            mMinLoggingLevel = level;
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
            initialize(mSavedMode);
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
        mSavedMode = mode;
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
        mMinOutputLevel = StyleEnum.min;
        mMinLoggingLevel = StyleEnum.min;
    }
    
    /**
    *   Unsafe write down the message without any meta information.
    */
    void rawInput(string message)  @trusted
    {
        if(this in mLogFiles)
            mLogFiles[this].writeLine(message);
    }
    
    /**
    *   Used to manual shutdown protocols.
    */
    void finalize() @trusted
    {
        if(finalized) return;
        
        //scope(failure) {}
        scope(exit) finalized = true;
        
        try close();
        catch(Throwable th) {}
    }
    
    ~this()
    {
        finalize();
    }

    private
    {
        string mName;
        __gshared std.stream.File[shared thistype] mLogFiles;
        StyleEnum mMinOutputLevel;
        StyleEnum mMinLoggingLevel;
        bool finalized = false;
        Mode mSavedMode;
        
        void close()
        {
            if(this in mLogFiles)
            {
                mLogFiles[this].close();
                mLogFiles.remove(this);
            }
        }
    }
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

    auto logger = new shared StrictLogger("TestLog");
    logger.minOutputLevel = LoggingLevel.Notice;
    logger.log("Notice msg!", LoggingLevel.Notice);
    logger.log("Warning msg!", LoggingLevel.Warning);
    logger.log("Debug msg!", LoggingLevel.Debug);
    logger.log("Fatal msg!", LoggingLevel.Fatal);
    logger.finalize();

    auto f = new std.stdio.File(logger.name, "r");
    auto r = regex(r"[\[][\p{InBasicLatin}]*[\]][:]");
    
    assert(f.readln()[0..$-1].replace(r, "") == logger.formatFileOutput("Notice msg!",  LoggingLevel.Notice).replace(r, ""),  "Log notice testing fail!");
    assert(f.readln()[0..$-1].replace(r, "") == logger.formatFileOutput("Warning msg!", LoggingLevel.Warning).replace(r, ""), "Log warning testing fail!");
    assert(f.readln()[0..$-1].replace(r, "") == logger.formatFileOutput("Debug msg!",   LoggingLevel.Debug).replace(r, ""),   "Log debug testing fail!");
    assert(f.readln()[0..$-1].replace(r, "") == logger.formatFileOutput("Fatal msg!",   LoggingLevel.Fatal).replace(r, ""),   "Log fatal testing fail!");
    f.close;

    logger = new shared StrictLogger("TestLog");
    scope(exit) logger.close();
    logger.minOutputLevel = LoggingLevel.Muted;
    
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
    
    // Testing overloading
    logger.logInfo("some string");
    logger.logInfo("first string", "second string");
    logger.logWarning("some string");
    logger.logWarning("first string", "second string");
    logger.logError("some string");
    logger.logError("first string", "second string");
    
    logger.close();
    remove(logger.name);
}
// issue #3 Testing custom time formatting
unittest
{
    import std.datetime;
    import std.file;
    
    string myTimeFormatting(DistType t, SysTime time)
    {
        final switch(t)
        {
            case(DistType.Console): return time.toSimpleString();
            case(DistType.File): return time.toISOExtString();
        }
    }
    
    alias MyLogger = StyledStrictLogger!(LoggingLevel, myTimeFormatting
                    , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s]: Debug: %1$s"
                    , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s]: Notice: %1$s"
                    , LoggingLevel.Warning, "Warning: %1$s", "[%2$s]: Warning: %1$s"
                    , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s]: Fatal: %1$s"
                    , LoggingLevel.Muted,   "",              ""
                    );
    
    auto logger = new shared MyLogger("TimeFormatTestLog");
    scope(exit)
    {
        logger.close();
        if(exists(logger.name)) remove(logger.name);
    }
    
    logger.logInfo("Msg1");
    logger.logWarning("Msg2");
    logger.logError("Msg2");
}
