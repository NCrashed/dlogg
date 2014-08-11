// This file is written in D programming language
/**
*   Module defines facilities for custom styling of logger messages. Template mixin $(generateStyle)
*   generates code for your logging styles (represented by an enum) that can be mixed into logger
*   implementation.
*
*   See $(B generateStyle) for detailed description.
*
*   Example of default logger style:
*   -------------------------------
*   import dlogg.log, dlogg.style;
*
*   mixin generateStyle!(LoggingLevel
*               , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s] Debug: %1$s"
*               , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s] Notice: %1$s"
*               , LoggingLevel.Warning, "Warning: %1$s", "[%2$s] Warning: %1$s"
*               , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s] Fatal: %1$s"
*               , LoggingLevel.Muted,   "",              ""
*               );
*   -------------------------------
*
*   Copyright: © 2013-2014 Anton Gushcha
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module dlogg.style;

/**
*   Utility mixin template that generates facilities for output message formatting
*   for console output and file output.
*
*   $(B Style) parameter defines what type is used as logging level. It must be an enum.
*   Order of values defines behavior of muting (styles that less current low border aren't
*   printed to output).
*
*   $(TS) has format of list of triples ($(B Style) value, string, string). Style value
*   defines for which logging level following format strings are. First format string is used
*   for console output, the second one is for file output.
*
*   Format strings could use two arguments: '%1$s' is message that is passed to a logger and
*   '%2$s' is current time string. Formatting is handled by $(B std.format) module. 
*/
mixin template generateStyle(Style, TS...)
{
    import std.array;
    import std.traits;
    import std.datetime;
    import std.format;
    import std.conv;

    /// Could not see style symbol while using with external packages
    mixin("import "~moduleName!Style~" : "~Style.stringof~";");
    
    static assert(is(Style == enum), "First parameter '"~Style.stringof~"' is expected to be an enum type!");
    static assert(checkTypes!TS, "logStyle expected triples of ('"~Style.stringof~"', string, string)");
    static assert(checkCoverage!TS, "logStyle triples doesn't cover all '"~Style.stringof~"' cases!");
    
    /// Checks types of US to be Style, string, string triples
    private template checkTypes(US...)
    {
        static if(US.length == 0)
        {
            enum checkTypes = true;
        } else static if(US.length < 3)
        {
            enum checkTypes = false;
        } else
        {
            enum checkTypes = is(Unqual!(typeof(US[0])) == Style) && isSomeString!(typeof(US[1])) && isSomeString!(typeof(US[2]))
                && checkTypes!(US[3..$]);
        }
    }
    
    /// Checking that triples covers all Style members
    private template checkCoverage(US...)
    {
        /// To be able to pass two expression tuples in one template
        private template Wrapper(T...)
        {
            alias get = T;
        }
        
        /// Finding ZSS[0] in ZSS[1..$], false if not finded
        private template findMember(ZSS...)
        {
            enum member = ZSS[0];
            alias ZS = ZSS[1..$];
            
            static if(ZS.length == 0)
            {
                enum findMember = false;
            } else
            {
                static if(ZS[0] == member)
                {
                    enum findMember = true;
                } else
                {
                    enum findMember = findMember!(member, ZS[1..$]);
                }
            }
        }
        
        /// Iterating over USS[0] to find each in USS[1]
        /// Wrapper is used to wrap expression tuples in expression tuple
        private template iterate(USS...)
        {
            alias EMembers = USS[0];
            alias SMembers = USS[1];
            
            static if(EMembers.get.length == 0)
            {
                enum iterate = true;
            } else
            {
                enum iterate = findMember!(EMembers.get[0], SMembers.get) 
                    && iterate!(Wrapper!(EMembers.get[1..$]), SMembers);
            }
        }
        
        /// We interested in only each first value of each triple
        /// creates new expression tuple from only first triple values of Style
        private template filter(US...)
        {
            private template Tuple(E...)
            {
                alias Tuple = E;
            }
            
            static if(US.length == 0)
            {
                alias filter = Tuple!();
            } else static if(US.length < 3)
            {
                static assert(false, "US invalid size!");
            } else
            {
                alias filter = Tuple!(US[0], filter!(US[3..$]));
            }
        }
        
        enum checkCoverage = iterate!(Wrapper!(EnumMembers!Style), Wrapper!(filter!US));
    }
    
    private template genSwitch(USS...)
    {
        enum variable = USS[0];
        enum formatElemIndex = USS[1];
        enum messageVariable = USS[2];
        enum timeVariable = USS[3];
        alias US = USS[4..$];
        
        private template genCases(US...)
        {
            static if(US.length == 0)
            {
                enum genCases = "";
            } else static if(US.length < 3)
            {
                static assert(false, "US invalid size!");
            } else
            {
                enum genCases = "\tcase("~Style.stringof~"."~US[0].to!string~"):\n\t{\n\t\t"
                    ~ `writer.formattedWrite("`~US[formatElemIndex]~`", `~messageVariable~", "~timeVariable~");\n\t\t"
                    ~ "break;\n\t}\n"
                    ~ genCases!(US[3..$]);
            }
        }
        
        enum genSwitch = "final switch("~variable~")\n{\n" 
            ~ genCases!(US) ~ "}\n";
    }
    
    string formatConsoleOutput( string message, Style level) @trusted
    {
        auto timeString = Clock.currTime.toISOExtString();
        auto writer = appender!string();
        
        //pragma(msg, genSwitch!("level", 1, "message", "timeString", TS));
        mixin(genSwitch!("level", 1, "message", "timeString", TS));
        
        return writer.data;
    }
    
    string formatFileOutput( string message, Style level) @trusted
    {
        auto timeString = Clock.currTime.toISOExtString();
        auto writer = appender!string();
        
        //pragma(msg, genSwitch!("level", 2, "message", "timeString", TS));
        mixin(genSwitch!("level", 2, "message", "timeString", TS));
        
        return writer.data;
    }
}
/// Example of default style
unittest
{
    import dlogg.log;
    mixin generateStyle!(LoggingLevel
                , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s] Debug: %1$s"
                , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s] Notice: %1$s"
                , LoggingLevel.Warning, "Warning: %1$s", "[%2$s] Warning: %1$s"
                , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s] Fatal: %1$s"
                , LoggingLevel.Muted,   "",              ""
                );
}
version(unittest)
{
    enum MyLevel
    {
        Error,
        Debug
    }
}
/// Example of custom style
unittest
{    
    mixin generateStyle!(MyLevel
                , MyLevel.Debug,   "Debug: %1$s",   "[%2$s] Debug: %1$s"
                , MyLevel.Error,   "Fatal: %1$s",   "[%2$s] Fatal: %1$s"
                );
}
