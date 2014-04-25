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
*   Default logger interface that uses $(B LoggingLevel) as
*   enum that describes ordering of logging levels.
*/
alias ILogger = IStyledLogger!(LoggingLevel);

// wrappers for easy logging
nothrow @trusted
{
    /**
    *   Wrapper for handy debug messages.
    *   Warning: main purpose for debug messages, thus it is not lazy.
    */
    void logDebug(E...)(shared ILogger logger, E args)
    {
        debug
        {
            scope(failure) {}
            string msg = text(args);
            logger.log(msg, LoggingLevel.Debug);
        }
    }
    
    /// Not lazy wrapper for multiple args messages
    void logInfo(E...)(shared ILogger logger, E args)
    {
        scope(failure) {}
        logger.log(text(args), LoggingLevel.Notice);
    }

    /// Lazy wrapper for one string message
    void logInfo()(shared ILogger logger, lazy string message)
    {
        logger.log(message, LoggingLevel.Notice);
    }
    
    /// Not lazy wrapper for multiple args messages
    void logWarning(E...)(shared ILogger logger, E args)
    {
        scope(failure) {}
        logger.log(text(args), LoggingLevel.Warning);
    }
    
    /// Lazy wrapper for one string message
    void logWarning()(shared ILogger logger, lazy string message)
    {
        logger.log(message, LoggingLevel.Warning);
    }
    
    /// Not lazy wrapper for multiple args messages
    void logError(E...)(shared ILogger logger, E args)
    {
        scope(failure) {}
        logger.log(text(args), LoggingLevel.Fatal);
    }
    
    /// Lazy wrapper for one string message
    void logError()(shared ILogger logger, lazy string message)
    {
        logger.log(message, LoggingLevel.Fatal);
    }
}
    
/**
*   Interface for lazy logging. Assumes to be nothrow.
*   Underlying realization should be concurrent safe.
*
*   $(B StyleEnum) is enum that used to distinct logging
*   levels and define ordering for verbosity muting.
*/
shared interface IStyledLogger(StyleEnum)
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
        void log(lazy string message, StyleEnum level);

        /**
        *   Returns: minimum log level,  will be printed in the console.
        */
        LoggingLevel minOutputLevel() const @property;

        /**
        *   Setups minimum message level that goes to console.
        */
        void minOutputLevel(StyleEnum level) @property;
        
        /**
        *   Setups minimum message level that goes to file.
        */
        LoggingLevel minLoggingLevel() @property;
        
        /**
        *   Setups minimum message level that goes to file.
        */
        void minLoggingLevel(StyleEnum level) @property;
        
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
    string formatConsoleOutput(string message, StyleEnum level);
    
    /**
    *   Format message with default logging style (etc. time and level string).
    */
    string formatFileOutput(string message, StyleEnum level);
    
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
}