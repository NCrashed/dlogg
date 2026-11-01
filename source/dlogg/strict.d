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

        replaceFile(value, mSavedMode);
    }

    nothrow
    {
        /**
        *   Prints message into log. Displaying in the console
        *   controlled by minOutputLevel property.
        */
        void log(lazy string message, StyleEnum level) @trusted
        {
            const writeToConsole = level >= mMinOutputLevel;
            const writeToFile = level >= mMinLoggingLevel;
            if(!writeToConsole && !writeToFile) return;

            string evaluatedMessage;
            try
            {
                evaluatedMessage = message;
            }
            catch(Exception e)
            {
                return;
            }
            if(evaluatedMessage is null) return;

            if(writeToConsole)
            {
                try
                {
                    const output = formatConsoleOutput(evaluatedMessage, level);
                    version(ColoredOutput) cwriteln(output);
                    else writeln(output);
                }
                catch(Exception e) {}
            }

            if(writeToFile)
            {
                try rawInput(formatFileOutput(evaluatedMessage, level));
                catch(Exception e)
                {
                    if(minOutputLevel != StyleEnum.max)
                    {
                        try writeln("Failed to write into log ", name);
                        catch(Exception ignored) {}
                    }
                }
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
        StyleEnum minLoggingLevel() const @property
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
        // logrotate commonly creates the replacement before asking the
        // application to reload. Always reopen instead of relying on path
        // existence, and append so an existing replacement is not truncated.
        replaceFile(name, Mode.Append);
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
    final protected void initialize(Mode mode = Mode.Rewrite) @trusted
    {
        replaceFile(name, mode);
    }

    /// Opens a replacement before releasing the current file.
    private void replaceFile(string path, Mode mode) @trusted
    {
        const dir = path.dirName;
        try
        {
            if (!dir.exists)
            {
                dir.mkdirRecurse;
            }

            File replacement;
            replacement.open(path, mapMode(mode));
            close();
            localFile(mLogFile) = replacement;
            mLogFileOpen = true;
            mName = path;
            finalized = false;
        }
        catch(Exception e)
        {
            throw new Exception(text("Failed to create log at '", path, "'. Details: ", e.msg));
        }
    }

    /// Transforms custom mode to file open mode
    private static string mapMode(Mode mode)
    {
        final switch(mode)
        {
            case(Mode.Append): return "a";
            case(Mode.Rewrite): return "w";
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
        if(mLogFileOpen)
            localFile(mLogFile).writeln(message);
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
        catch(Exception e) {}
    }

    ~this()
    {
        finalize();
    }

    private
    {
        string mName;
        File mLogFile;
        bool mLogFileOpen = false;
        StyleEnum mMinOutputLevel;
        StyleEnum mMinLoggingLevel;
        bool finalized = false;
        Mode mSavedMode;

        static ref File localFile(ref shared File file) @trusted
        {
            return *(cast(File*) &file);
        }

        void close()
        {
            if(mLogFileOpen)
            {
                localFile(mLogFile).close();
                mLogFileOpen = false;
            }
        }
    }
}

version(unittest)
{
    import std.concurrency;

    enum CustomLoggingLevel
    {
        Trace,
        Muted
    }

    synchronized class FailingConsoleLogger : StrictLogger
    {
        this(string path)
        {
            super(path);
        }

        override string formatConsoleOutput(string, LoggingLevel)
        {
            throw new Exception("simulated console formatting failure");
        }
    }

    void testThread(shared ILogger logger, Tid owner, uint n)
    {
        foreach(j; 0 .. n)
        {
            logger.logInfo(to!string(j));
            logger.logError(to!string(j));
        }

        send(owner, true);
    }

    version(linux)
    {
        pragma(inline, false)
        void createForgottenLoggers(string prefix, size_t count)
        {
            import std.conv : text;

            foreach(i; 0 .. count)
            {
                auto logger = new shared StrictLogger(text(prefix, i));
                logger.minOutputLevel = LoggingLevel.Muted;
            }
        }
    }
}

// Regression test for pull requests #7 and #9: custom logging levels must not
// be compared with the built-in LoggingLevel enum.
unittest
{
    import std.file : exists, remove, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    alias CustomLogger = StyledStrictLogger!(CustomLoggingLevel
                    , CustomLoggingLevel.Trace, "Trace: %1$s", "[%2$s]: Trace: %1$s"
                    , CustomLoggingLevel.Muted, "", ""
                    );

    const path = buildPath(tempDir, "dlogg-custom-" ~ randomUUID.toString);
    auto logger = new shared CustomLogger(path);
    scope(exit)
    {
        logger.finalize();
        if (exists(logger.name)) remove(logger.name);
    }

    logger.minOutputLevel = CustomLoggingLevel.Muted;
    logger.log("custom level", CustomLoggingLevel.Trace);
}

unittest
{
    import std.regex;
    import std.path;
    import std.file;
    import std.range : walkLength;
    import std.stdio;
    import std.uuid : randomUUID;

    const path = buildPath(tempDir, "dlogg-concurrency-" ~ randomUUID.toString);
    auto logger = new shared StrictLogger(path);
    scope(exit)
    {
        logger.finalize();
        if(exists(path)) remove(path);
    }
    logger.minOutputLevel = LoggingLevel.Notice;
    logger.log("Notice msg!", LoggingLevel.Notice);
    logger.log("Warning msg!", LoggingLevel.Warning);
    logger.log("Debug msg!", LoggingLevel.Debug);
    logger.log("Fatal msg!", LoggingLevel.Fatal);
    logger.finalize();

    auto f = new std.stdio.File(logger.name, "r");
    auto r = regex(r"[\[][\p{InBasicLatin}]*[\]][:]");

    assert(f.readln()[0..$-1].replace(r, "")
        == logger.formatFileOutput("Notice msg!", LoggingLevel.Notice).replace(r, ""),
        "Log notice testing fail!");
    assert(f.readln()[0..$-1].replace(r, "")
        == logger.formatFileOutput("Warning msg!", LoggingLevel.Warning).replace(r, ""),
        "Log warning testing fail!");
    assert(f.readln()[0..$-1].replace(r, "")
        == logger.formatFileOutput("Debug msg!", LoggingLevel.Debug).replace(r, ""),
        "Log debug testing fail!");
    assert(f.readln()[0..$-1].replace(r, "")
        == logger.formatFileOutput("Fatal msg!", LoggingLevel.Fatal).replace(r, ""),
        "Log fatal testing fail!");
    f.close;

    logger = new shared StrictLogger(path);
    logger.minOutputLevel = LoggingLevel.Muted;

    immutable n = 10;
    foreach(_; 0 .. n)
    {
        spawn(&testThread, logger, thisTid, n);
    }

    foreach(_; 0 .. n)
    {
        const received = receiveTimeout(dur!"seconds"(2), (bool completed)
        {
            assert(completed);
        });
        assert(received, "Concurrent logging test timed out!");
    }

    // Testing overloading
    logger.logInfo("some string");
    logger.logInfo("first string", "second string");
    logger.logWarning("some string");
    logger.logWarning("first string", "second string");
    logger.logError("some string");
    logger.logError("first string", "second string");

    logger.finalize();
    auto concurrentFile = File(path, "r");
    const lineCount = concurrentFile.byLine.walkLength;
    concurrentFile.close();
    assert(lineCount == 2 * n * n + 6,
        "Concurrent logging lost or duplicated messages");
}
// issue #3 Testing custom time formatting
unittest
{
    import std.datetime;
    import std.file;
    import std.path : buildPath;
    import std.uuid : randomUUID;

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

    const path = buildPath(tempDir, "dlogg-time-" ~ randomUUID.toString);
    auto logger = new shared MyLogger(path);
    scope(exit)
    {
        logger.finalize();
        if(exists(logger.name)) remove(logger.name);
    }

    logger.logInfo("Msg1");
    logger.logWarning("Msg2");
    logger.logError("Msg2");
}

// A replacement file created by logrotate must receive subsequent messages.
unittest
{
    import std.file : exists, readText, remove, rename, tempDir, write;
    import std.path : buildPath;
    import std.string : indexOf;
    import std.uuid : randomUUID;

    const baseName = "dlogg-reload-" ~ randomUUID.toString;
    const activePath = buildPath(tempDir, baseName);
    const rotatedPath = activePath ~ ".1";
    auto logger = new shared StrictLogger(activePath, StrictLogger.Mode.Append);
    logger.minOutputLevel = LoggingLevel.Muted;
    scope(exit)
    {
        logger.finalize();
        if(exists(activePath)) remove(activePath);
        if(exists(rotatedPath)) remove(rotatedPath);
    }

    logger.log("before rotation", LoggingLevel.Notice);
    rename(activePath, rotatedPath);
    write(activePath, "");
    logger.reload();
    logger.log("after rotation", LoggingLevel.Notice);
    logger.finalize();

    assert(readText(activePath).indexOf("after rotation") >= 0,
        "reload must switch to the replacement file");
    assert(readText(rotatedPath).indexOf("after rotation") < 0,
        "reload must stop writing to the rotated file");
}

version(linux) unittest
{
    import core.memory : GC;
    import std.conv : text;
    import std.file : SpanMode, dirEntries, exists, remove, tempDir;
    import std.path : buildPath;
    import std.range : walkLength;
    import std.uuid : randomUUID;

    size_t openFileDescriptors()
    {
        return dirEntries("/proc/self/fd", SpanMode.shallow).walkLength;
    }

    const firstPath = buildPath(tempDir, "dlogg-finalize-" ~ randomUUID.toString);
    const secondPath = firstPath ~ ".second";
    immutable before = openFileDescriptors();
    auto logger = new shared StrictLogger(firstPath);
    logger.finalize();
    logger.name = secondPath;
    logger.finalize();
    immutable after = openFileDescriptors();

    if(exists(firstPath)) remove(firstPath);
    if(exists(secondPath)) remove(secondPath);
    assert(after == before,
        "a logger reopened after finalize must be closeable again");

    enum forgottenCount = 16;
    const prefix = buildPath(tempDir, "dlogg-forgotten-" ~ randomUUID.toString ~ "-");
    createForgottenLoggers(prefix, forgottenCount);
    GC.collect();
    GC.minimize();
    immutable afterCollection = openFileDescriptors();
    foreach(i; 0 .. forgottenCount)
    {
        const path = text(prefix, i);
        if(exists(path)) remove(path);
    }
    assert(afterCollection <= after + 1,
        "unreferenced loggers must not keep their files open");
}

// A lazy message is an event value, not a repeatedly evaluated expression.
unittest
{
    import std.file : exists, remove, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    const path = buildPath(tempDir, "dlogg-lazy-" ~ randomUUID.toString);
    auto logger = new shared StrictLogger(path);
    scope(exit)
    {
        logger.finalize();
        if(exists(path)) remove(path);
    }

    size_t evaluations;
    string message()
    {
        ++evaluations;
        return "evaluated once";
    }

    logger.log(message(), LoggingLevel.Notice);
    assert(evaluations == 1, "log evaluated its lazy message more than once");

    evaluations = 0;
    logger.logInfo(message());
    assert(evaluations == 1, "logInfo evaluated its lazy message more than once");
}

// A broken console sink must not prevent the independent file sink.
unittest
{
    import std.file : exists, readText, remove, tempDir;
    import std.path : buildPath;
    import std.string : indexOf;
    import std.uuid : randomUUID;

    const path = buildPath(tempDir, "dlogg-sink-isolation-" ~ randomUUID.toString);
    auto logger = new shared FailingConsoleLogger(path);
    scope(exit)
    {
        logger.finalize();
        if(exists(path)) remove(path);
    }

    logger.log("must reach the file", LoggingLevel.Notice);
    logger.finalize();
    assert(readText(path).indexOf("must reach the file") >= 0,
        "a console failure prevented file logging");
}
