/**
*   Sometimes logging is needed only if something goes wrong. This module
*   describes a class-wrapper to handle delayed logging. 
*
*   Example:
*   ----------
*   auto delayed = new shared BufferedLogger(logger); // wrapping a logger
*	scope(exit) delayed.finalize(); // write down information in wrapped logger
*   scope(failure) delayed.minOutputLevel = LoggingLevel.Notice; // if failed, spam in console
*   delayed.logNotice("Hello!");
*
*   // do something that can fail
*
*   ----------
*
*   Copyright: © 2013-2014 Anton Gushcha
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module dlogg.buffered;

import std.array;
import std.stdio;
import dlogg.strict;

/**
*   Alias for $(B StyledBufferedLogger) for default logging style.
*/
alias BufferedLogger = StyledBufferedLogger!(LoggingLevel
                , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s]: Debug: %1$s"
                , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s]: Notice: %1$s"
                , LoggingLevel.Warning, "Warning: %1$s", "[%2$s]: Warning: %1$s"
                , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s]: Fatal: %1$s"
                , LoggingLevel.Muted,   "",              ""
                );

/**
*   Class-wrapper around strict logger. All strings are written down
*   only after finalizing the wrapper. Usually you want to use alias
*   for standart style $(B BufferedLogger).
*/
synchronized class StyledBufferedLogger(StyleEnum, US...) : StyledStrictLogger!(StyleEnum, US)
{
    /// Creates a buffered logger that flushes into delayLogger on finalization.
    this(shared IStyledLogger!StyleEnum delayLogger)
    {
        if(delayLogger is null)
            throw new Exception("Buffered logger requires a non-null sink");

        this.delayLogger = delayLogger;
        super.minOutputLevel(StyleEnum.max);
    }

    override void log(lazy string message, StyleEnum level) nothrow @trusted
    {
        if(finalized || level < minLoggingLevel) return;

        string evaluatedMessage;
        try evaluatedMessage = message;
        catch(Exception e) { return; }
        if(evaluatedMessage is null) return;

        BufferedEntry entry;
        entry.message = evaluatedMessage;
        entry.level = level;
        entry.styled = true;
        try
        {
            entry.fileOutput = formatFileOutput(evaluatedMessage, level);
            entry.hasFileOutput = true;
        }
        catch(Exception e) {}
        buffer ~= entry;
    }

    override StyleEnum minOutputLevel() const nothrow @property @trusted
    {
        return super.minOutputLevel;
    }

    override void minOutputLevel(StyleEnum level) nothrow @property @trusted
    {
        super.minOutputLevel(level);
        replayToConsole = true;
    }
    
    override void rawInput(string message) @trusted
    {
        if(finalized) return;

        BufferedEntry entry;
        entry.message = message;
        entry.fileOutput = message;
        entry.hasFileOutput = true;
        buffer ~= entry;
    }
    
    override void finalize() @trusted
    {
        if(finalized) return;
        scope(exit)
        {
            buffer.length = 0;
            finalized = true;
        }

        foreach(entry; buffer)
        {
            if(replayToConsole && (!entry.styled || entry.level >= minOutputLevel))
            {
                try
                {
                    const output = entry.styled
                        ? formatConsoleOutput(entry.message, entry.level)
                        : entry.message;
                    writeln(output);
                }
                catch(Exception e) {}
            }

            if(!entry.hasFileOutput) continue;
            try
            {
                delayLogger.rawInput(entry.fileOutput);
            } catch(Exception e)
            {
            }
        }
    }
    
    private
    {
        shared IStyledLogger!StyleEnum delayLogger;
        BufferedEntry[] buffer;
        bool finalized;
        bool replayToConsole;

        struct BufferedEntry
        {
            string message;
            string fileOutput;
            StyleEnum level;
            bool styled;
            bool hasFileOutput;
        }
    }
}

version(unittest)
{
    enum CustomBufferedLevel
    {
        Trace,
        Muted
    }

    enum BufferedLevelWithoutSentinel
    {
        Info,
        Error
    }
}

// Custom levels must work through both the buffered logger and its sink.
unittest
{
    import std.file : exists, remove;

    alias CustomSink = StyledStrictLogger!(CustomBufferedLevel
                    , CustomBufferedLevel.Trace, "Trace: %1$s", "[%2$s]: Trace: %1$s"
                    , CustomBufferedLevel.Muted, "", ""
                    );
    alias CustomBuffer = StyledBufferedLogger!(CustomBufferedLevel
                    , CustomBufferedLevel.Trace, "Trace: %1$s", "[%2$s]: Trace: %1$s"
                    , CustomBufferedLevel.Muted, "", ""
                    );

    auto sink = new shared CustomSink("CustomBufferedLevelTestLog");
    scope(exit)
    {
        sink.finalize();
        if (exists(sink.name)) remove(sink.name);
    }

    auto logger = new shared CustomBuffer(sink);
    logger.log("custom buffered level", CustomBufferedLevel.Trace);
    logger.finalize();
}

// Buffering must not rely on a synthetic enum value above every real level.
unittest
{
    import std.file : exists, getSize, readText, remove, tempDir;
    import std.path : buildPath;
    import std.stdio : File, stdout;
    import std.string : indexOf;
    import std.uuid : randomUUID;

    alias Sink = StyledStrictLogger!(BufferedLevelWithoutSentinel
                    , BufferedLevelWithoutSentinel.Info, "Info: %1$s", "Info: %1$s"
                    , BufferedLevelWithoutSentinel.Error, "Error: %1$s", "Error: %1$s"
                    );
    alias Buffer = StyledBufferedLogger!(BufferedLevelWithoutSentinel
                    , BufferedLevelWithoutSentinel.Info, "Info: %1$s", "Info: %1$s"
                    , BufferedLevelWithoutSentinel.Error, "Error: %1$s", "Error: %1$s"
                    );

    const prefix = buildPath(tempDir, "dlogg-buffer-" ~ randomUUID.toString);
    const sinkPath = prefix ~ ".sink";
    const consolePath = prefix ~ ".console";
    auto sink = new shared Sink(sinkPath);
    auto logger = new shared Buffer(sink);
    auto originalStdout = stdout;
    originalStdout.flush();
    scope(exit)
    {
        stdout = originalStdout;
        logger.finalize();
        sink.finalize();
        if(exists(sinkPath)) remove(sinkPath);
        if(exists(consolePath)) remove(consolePath);
    }

    stdout = File(consolePath, "w");
    logger.log("buffered info", BufferedLevelWithoutSentinel.Info);
    logger.log("buffered error", BufferedLevelWithoutSentinel.Error);
    stdout.flush();
    assert(getSize(consolePath) == 0,
        "the maximum real level bypassed buffering");

    logger.minOutputLevel = BufferedLevelWithoutSentinel.Error;
    logger.finalize();
    stdout.flush();
    sink.finalize();

    const consoleOutput = readText(consolePath);
    const fileOutput = readText(sinkPath);
    assert(consoleOutput.indexOf("buffered info") < 0);
    assert(consoleOutput.indexOf("buffered error") >= 0);
    assert(fileOutput.indexOf("buffered info") >= 0);
    assert(fileOutput.indexOf("buffered error") >= 0);

    logger.log("too late", BufferedLevelWithoutSentinel.Error);
    logger.finalize();
    assert(readText(sinkPath).indexOf("too late") < 0,
        "a finalized buffer accepted another message");
}

unittest
{
    import std.exception : assertThrown;

    shared IStyledLogger!LoggingLevel sink;
    assertThrown!Exception(new shared BufferedLogger(sink));
}
