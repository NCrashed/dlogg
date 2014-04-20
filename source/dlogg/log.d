/**
*    Logging system designed to operate in concurrent application.
*
*    The system should be initialized with $(B initLoggingSystem) function.
*    There is no need to call shutdown function as it is happen in module
*    destructor.
*
*    Example:
*    ---------
*    void testThread()
*    {
*        foreach(j; 1 .. 50)
*        {
*            logInfo(to!string(j));
*            logError(to!string(j));
*        }
*    }    
*
*    foreach(i; 1 .. 50)
*    {
*        spawn(&testThread);
*    }
*    ---------
*
*   Copyright: © 2013-2014 Anton Gushcha
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*
*/
module dlogg.log;
@safe:

public import std.conv;

/**
*   Log levels defines style of the messages.
*   Printing in console can be controlled by
*   ILogger.minOutputLevel property.
*/
enum LoggingLevel
{
    Notice,
    Warning,
    Debug,
    Fatal,
    Muted // Used only to mute all writing to console
}

/**
*   Interface for lazy logging. Assumes to be nothrow.
*   Underlying realization should be concurrent safe.
*/
shared interface ILogger
{
    /**
    *   Setting new log file name. If the $(B value)
    *   differs from old one, logger should close
    *   old one and open new file.
    */
    void name(string value) @property;
    
    nothrow 
    {
        /**
        *   Log file name.
        */
        string name() @property const;
        
        /**
        *   Prints message into log. Displaying in the console
        *   controlled by minOutputLevel property.
        */
        void log(lazy string message, LoggingLevel level);

        /**
        *   Returns: minimum log level,  will be printed in the console.
        */
        LoggingLevel minOutputLevel() const @property;

        /**
        *   Setups minimum log level, 
        */
        void minOutputLevel(LoggingLevel level) @property;
        
        /**
        *   Used to manual shutdown protocols.
        */
        void finalize();
    }

    /**
    *   Unsafe write down the message without any meta information.
    */
    void rawInput(string message);
    
    /**
    *   Format message with default logging style (etc. time and level string).
    */
    string formatString(lazy string message, LoggingLevel level);
    
    /**
    *   Checks if the log file is exists at specified $(B location) and
    *   if can't find it, recreates the file and continues write into it.
    *
    *   Useful for $(B logrotate) utility. GNU/Linux system checks file identity by
    *   inode, that doesn't change while renaming. Thus after renaming the file at 
    *   $(B location) log continues write into the renamed file. The call to the
    *   $(B reload) method force splitting log into two parts.
    *
    *   Note: The method is not nothrow!
    */
    void reload();

    // wrappers for easy logging
    final nothrow @trusted
    {
        /**
        *   Wrapper for handy debug messages.
        *   Warning: main purpose for debug messages, thus it is not lazy.
        */
        void logDebug(E...)(E args) shared @trusted
        {
            scope(failure) {}
            debug
            {
                string str = text(args);
                log(str, LoggingLevel.Debug);
            }
        }
        
        void logInfo(lazy string message)
        {
            log(message, LoggingLevel.Notice);
        }

        void logWarning(lazy string message)
        {
            log(message, LoggingLevel.Warning);
        }

        void logError(lazy string message)
        {
            log(message, LoggingLevel.Fatal);
        }
    }
}