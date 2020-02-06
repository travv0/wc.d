import std.stdio;
import std.algorithm : map, fold;
import std.string : split;
import std.range : walkLength, drop;
import std.getopt : getopt, defaultGetoptPrinter, config;
import std.format : format;
import core.stdc.stdlib : exit;

auto lines = false;
auto words = false;
auto bytes = false;
auto chars = false;

struct Output {
  size_t lines;
  size_t words;
  size_t bytes;
  size_t chars;

  Output opBinary(string op)(Output rhs) if (op == "+") {
    return Output(lines + rhs.lines,
                  words + rhs.words,
                  bytes + rhs.bytes,
                  chars + rhs.chars);
  }

  unittest {
    assert(Output(6, 8, 10, 12)
           == Output(1, 2, 3, 4) + Output(5, 6, 7, 8));
  }

  void opOpAssign(string op)(Output rhs) if (op == "+") {
    lines += rhs.lines;
    words += rhs.words;
    bytes += rhs.bytes;
    chars += rhs.chars;
  }

  unittest {
    auto output = Output(1, 2, 3, 4);
    output += Output(5, 6, 7, 8);
    assert(Output(6, 8, 10, 12) == output);
  }
}

Output lineToOutput(T)(T line) pure {
  return Output(line.length != 0 && line[$ - 1] == '\n' ? 1 : 0,
                line.split.length,
                line.length,
                line.walkLength);
}

pure unittest {
  assert(Output(1, 5, 22, 20) == lineToOutput("this is あ test line\n"));
  assert(Output(0, 0, 0, 0) == lineToOutput(""));
}

Output wc(T)(T input) {
  return input
    .byLine(KeepTerminator.yes)
    .map!lineToOutput
    .fold!"a + b"(Output(0, 0, 0, 0));
}

unittest {
  assert(Output(75, 213, 1735, 1733) == wc(File("testfiles/test1.txt")));
}

uint fileBytesSumWidth(string[] fileNames) nothrow {
  ulong sum = 0;
  foreach (fileName; fileNames) {
    try {
      auto file = File(fileName);
      sum += file.size();
    }
    catch (Exception e) {}
  }

  try {
    return cast(uint) sum.format!"%u".walkLength;
  }
  catch (Exception e) {
    return 0;
  }
}

unittest {
  assert(7 == fileBytesSumWidth(["testfiles/test1.txt", "testfiles/big.txt"]));
}

void printLine(Output output, string fileName, uint columnWidth) {
  if (lines)
    writef("%*d ", columnWidth, output.lines);
  if (words)
    writef("%*d ", columnWidth, output.words);
  if (chars)
    writef("%*d ", columnWidth, output.chars);
  if (bytes)
    writef("%*d ", columnWidth, output.bytes);
  writeln(fileName);
}

Output processFile(string programName, string fileName, uint columnWidth) {
  Output output = Output(0, 0, 0, 0);
  try {
    output = wc(File(fileName));
  }
  catch (Exception e) {
    stderr.writefln("%s: %s: %s", programName, fileName, e.message);
  }
  printLine(output, fileName, columnWidth);
  return output;
}

unittest {
  assert(Output(75, 213, 1735, 1733) == processFile("", "testfiles/test1.txt", 5));
  assert(Output(0, 0, 0, 0) == processFile("", "testfiles/", 5));
}

string programInfo(string programName) {
  return format("Usage: %s [OPTION]... [FILE]...

Print newline, word, and byte counts for each FILE, and a total line if
more than one FILE is specified.  A word is a non-zero-length sequence of
characters delimited by white space.

With no FILE, or when FILE is -, read standard input.

The options below may be used to select which counts are printed, always in
the following order: newline, word, character, byte.
", programName);
}

void main(string[] args) {
  try {
    auto helpInfo = getopt(args,
                           config.bundling,
                           config.passThrough,
                           "bytes|c", "print the byte counts", &bytes,
                           "chars|m", "print the character counts", &chars,
                           "lines|l", "print the newline counts", &lines,
                           "words|w", "print the word counts", &words);

    auto programName = args[0];
    auto fileNames = args.drop(1);
    auto columnWidth = fileBytesSumWidth(fileNames);
    auto total = Output(0, 0, 0, 0);

    if (helpInfo.helpWanted) {
      defaultGetoptPrinter(programInfo(programName), helpInfo.options);
      exit(0);
    }

    if (!(bytes || chars || lines || words)) {
      bytes = words = lines = true;
    }

    if (fileNames.length == 0 || fileNames[0] == "-") {
      printLine(wc(stdin),
                fileNames.length == 0 ? "" : "-",
                7);
    }
    else {
      foreach (fileName; fileNames) {
        total += processFile(programName, fileName, columnWidth);
      }

      if (fileNames.length > 1) {
        printLine(total, "total", columnWidth);
      }
    }
  }
  catch (Exception e) {
    writefln("%s: %s", args[0], e.message);
  }
}
