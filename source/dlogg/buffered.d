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
        this.delayLogger = delayLogger;
        minOutputLevel = StyleEnum.max;
    }
    
    override void rawInput(string message) @trusted
    {
        buffer ~= message;
    }
    
    override void finalize() @trusted
    {
        if(finalized) return;
        scope(exit) finalized = true;
        
        foreach(msg; buffer)
        {
            try
            {
	            if(minOutputLevel != StyleEnum.max)
	                writeln(msg);
	                
	            delayLogger.rawInput(msg);
            } catch(Exception e)
            {
            	
            }
        }
    }
    
    private
    {
        shared IStyledLogger!StyleEnum delayLogger;
        string[] buffer;
        bool finalized;
    }
}

version(unittest)
{
    enum CustomBufferedLevel
    {
        Trace,
        Muted
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
