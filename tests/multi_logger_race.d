module tests.multi_logger_race;

import core.thread : Thread;
import dlogg.strict;
import std.conv : text;
import std.file : exists, remove, tempDir;
import std.path : buildPath;
import std.uuid : randomUUID;

/// Writes through one logger while other independent loggers are active.
private final class LoggerThread : Thread
{
    /// Creates a worker for logger.
    this(shared ILogger logger)
    {
        mLogger = logger;
        super(&run);
    }

private:
    shared ILogger mLogger;

    void run()
    {
        foreach(i; 0 .. 256)
            mLogger.log(text("message ", i), LoggingLevel.Notice);
        mLogger.finalize();
    }
}

void main()
{
    enum workerCount = 8;
    const prefix = "dlogg-tsan-" ~ randomUUID.toString;
    Thread[] workers;
    string[] paths;

    foreach(workerId; 0 .. workerCount)
    {
        const path = buildPath(tempDir, text(prefix, "-", workerId));
        paths ~= path;
        auto logger = new shared StrictLogger(path);
        logger.minOutputLevel = LoggingLevel.Muted;
        // Initialize Phobos' time-zone cache before concurrent formatting so
        // this test reports logger races rather than one-time runtime setup.
        logger.log("warmup", LoggingLevel.Notice);
        workers ~= new LoggerThread(logger);
    }

    foreach(worker; workers) worker.start();
    foreach(worker; workers) worker.join();
    foreach(path; paths) if(exists(path)) remove(path);
}
