import std.stdio;
import std.algorithm : map, fold;
import std.string : split;
import std.range : walkLength, drop;
import std.getopt : getopt, defaultGetoptPrinter, config;
import std.format : format;
import core.stdc.stdlib : exit;

struct Options
{
    bool lines;
    bool words;
    bool bytes;
    bool chars;
}

struct Output
{
    size_t lines;
    size_t words;
    size_t bytes;
    size_t chars;

    pure nothrow @nogc @safe
    Output opBinary(string op)(Output rhs)
    {
        return mixin("Output(lines " ~ op ~ " rhs.lines,
                             words " ~ op ~ " rhs.words,
                             bytes " ~ op ~ " rhs.bytes,
                             chars " ~ op ~ " rhs.chars)");
    }

    unittest
    {
        assert(Output(6, 8, 10, 12)
               == Output(1, 2, 3, 4) + Output(5, 6, 7, 8));
        assert(Output(-4, -4, -4, -4)
               == Output(1, 2, 3, 4) - Output(5, 6, 7, 8));
    }

    pure nothrow @safe @nogc
    void opOpAssign(string op)(Output rhs)
    {
        mixin("lines " ~ op ~ "= rhs.lines;
               words " ~ op ~ "= rhs.words;
               bytes " ~ op ~ "= rhs.bytes;
               chars " ~ op ~ "= rhs.chars;");
    }

    unittest {
        auto output = Output(1, 2, 3, 4);
        output += Output(5, 6, 7, 8);
        assert(Output(6, 8, 10, 12) == output);
        output -= Output(5, 6, 7, 8);
        assert(Output(1, 2, 3, 4) == output);
    }
}

pure @safe
Output lineToOutput(T)(T line, Options options)
{
    return Output(options.lines && line.length != 0 && line[$ - 1] == '\n' ? 1 : 0,
                  options.words ? line.split.length : 0,
                  options.bytes ? line.length : 0,
                  options.chars ? line.walkLength : 0);
}

unittest
{
    assert(Output(1, 5, 22, 20) == lineToOutput("this is あ test line\n", Options(true, true, true, true)));
    assert(Output(0, 0, 0, 0) == lineToOutput("", Options(true, true, true, true)));
}

Output wc(T)(T input, Options options)
{
    return input
        .byLine(KeepTerminator.yes)
        .map!(l => lineToOutput!(const char[])(l, options))
        .fold!"a + b"(Output(0, 0, 0, 0));
}

unittest
{
    assert(Output(75, 213, 1735, 1733)
           == wc(File("testfiles/test1.txt"), Options(true, true, true, true)));
}

nothrow @safe
uint fileBytesSumWidth(string[] fileNames)
{
    ulong sum = 0;
    foreach (fileName; fileNames)
    {
        try
        {
            auto file = File(fileName);
            sum += file.size();
        }
        catch (Exception e) {}
    }

    try
    {
        return cast(uint) sum.format!"%u".walkLength;
    }
    catch (Exception e)
    {
        return 0;
    }
}

unittest
{
    assert(7 == fileBytesSumWidth(["testfiles/test1.txt", "testfiles/big.txt"]));
}

@safe
void printLine(Output output, string fileName, uint columnWidth, Options options)
{
    void printSection(string name)() {
        mixin("if (options." ~ name ~ ")
                   writef(\"%*d \", columnWidth, output." ~ name ~ ");");

    }
    printSection!"lines";
    printSection!"words";
    printSection!"chars";
    printSection!"bytes";
    writeln(fileName);
}

Output processFile(string programName, string fileName, uint columnWidth, Options options)
{
    Output output = Output(0, 0, 0, 0);
    try
    {
        output = wc(File(fileName), options);
    }
    catch (Exception e)
    {
        stderr.writefln("%s: %s: %s", programName, fileName, e.message);
    }
    printLine(output, fileName, columnWidth, options);
    return output;
}

unittest
{
    assert(Output(75, 213, 1735, 1733) == processFile("", "testfiles/test1.txt", 5,
                                                      Options(true, true, true, true)));
    assert(Output(0, 0, 0, 0) == processFile("", "testfiles/", 5,
                                             Options(true, true, true, true)));
}

pure @safe
string programInfo(string programName)
{
    return format("Usage: %s [OPTION]... [FILE]...

Print newline, word, and byte counts for each FILE, and a total line if
more than one FILE is specified.  A word is a non-zero-length sequence of
characters delimited by white space.

With no FILE, or when FILE is -, read standard input.

The options below may be used to select which counts are printed, always in
the following order: newline, word, character, byte.
", programName);
}

void main(string[] args)
{
    try
    {
        auto options = Options();
        auto helpInfo = getopt(args,
                               config.bundling,
                               config.passThrough,
                               "bytes|c", "print the byte counts", &options.bytes,
                               "chars|m", "print the character counts", &options.chars,
                               "lines|l", "print the newline counts", &options.lines,
                               "words|w", "print the word counts", &options.words);

        auto programName = args[0];
        auto fileNames = args.drop(1);
        auto columnWidth = fileBytesSumWidth(fileNames);
        auto total = Output();

        if (helpInfo.helpWanted)
        {
            defaultGetoptPrinter(programInfo(programName), helpInfo.options);
            exit(0);
        }

        if (!(options.bytes || options.chars || options.lines || options.words))
        {
            options.bytes = options.words = options.lines = true;
        }

        if (fileNames.length == 0 || fileNames[0] == "-")
        {
            printLine(wc(stdin, options),
                      fileNames.length == 0 ? "" : "-",
                      7,
                      options);
        }
        else
        {
            foreach (fileName; fileNames)
            {
                total += processFile(programName, fileName, columnWidth, options);
            }

            if (fileNames.length > 1)
            {
                printLine(total, "total", columnWidth, options);
            }
        }
    }
    catch (Exception e)
    {
        writefln("%s: %s", args[0], e.message);
    }
}
