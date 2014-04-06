/**
<h1>Strict logger</h1>

Each logger in the package implements `dlogg.ILogger` interface and forced to be shared between threads. There are 5 different styles of logg messages:
-----
enum LoggingLevel
{
    Notice,
    Warning,
    Debug,
    Fatal,
    Muted // Used only to mute all writing to console
}
----
So, to put message in log you can use:
----
  void ILogger.log(lazy string message, LoggingLevel level) shared;
----
Or one of handy wrappers:
-------
  final nothrow shared
  {
    void logDebug(E...)(E args) shared @trusted; // not lazy
    void ILogger.logInfo(lazy string message);
    void ILogger.logWarning(lazy string message);
    void ILogger.logError(lazy string message);
  }
-------
Note that major logging funcs are lazy and we don't have overhead while logg call isn't needed but in strict version D performs string concatinations.

And finally full example:
-----------
   shared ILogger logger = new StrictLogger("my_awesome_log.log");
   logger.minOutputLevel = LoggingLevel.Warning; // info msgs won't be printed in console 
   logger.logInfo("Info message!");
   logger.logError("Error message!");
   logger.logDebug("Debug message!");
-----------
Output file:
-----------
[2014-04-06T19:50:22.8193333]:Notice: Notice msg!
[2014-04-06T19:50:22.819406]:Warning: Warning msg!
[2014-04-06T19:50:22.8194323]:Debug: Debug msg!
[2014-04-06T19:50:22.8194548]:Error: Fatal msg!
-----------

$(B minOutputLevel) property controls which message types should be printed in console. `LoggingLevel.Muted` is used to create daemon loggers that don't try to write into stdout.

<h1>Buffered logger</h1>
In many cases (for instance, unittesting) we don't want log output just in time. Buffered logger adds control when messages would be written into wrapped log. Example:
---------
   auto delayed = new shared BufferedLogger(logger); // wrapping a logger
   scope(exit) delayed.finalize(); // write down information in wrapped logger
   scope(failure) delayed.minOutputLevel = LoggingLevel.Notice; // if failed, spam in console
   delayed.logNotice("Hello!");

   // do something that can fail
---------

<h1>Log rotating</h1>
$(B StrictLogger.reload) function checks if the log file is exists at specified location and if can't find it, recreates the file and continues write into it. Useful for <a href=http://linuxcommand.org/man_pages/logrotate8.html>logrotate</a> utility. GNU/Linux system checks file identity by inode, that doesn't change while renaming. Thus after renaming the file at location log continues write into the renamed file. The call to the reload method force splitting log into two parts.
*/
module index.d;
