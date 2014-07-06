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
    this(shared ILogger delayLogger)
    {
        this.delayLogger = delayLogger;
        minOutputLevel = LoggingLevel.Muted;
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
	            if(minOutputLevel != LoggingLevel.Muted)
	                writeln(msg);
	                
	            delayLogger.rawInput(msg);
            } catch(Throwable th)
            {
            	
            }
        }
    }
    
    private
    {
        shared ILogger delayLogger;
        string[] buffer;
        bool finalized;
    }
}