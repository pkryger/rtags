/* This file is part of RTags.

RTags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

RTags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with RTags.  If not, see <http://www.gnu.org/licenses/>. */

#include "CompilerManager.h"
#include <rct/Process.h>
#include <rct/Log.h>

static std::mutex sMutex;
struct Compiler {
    Compiler()
        : inited(false)
    {}
    bool inited;
    List<Path> includePaths;
    List<GccArguments::Define> defines;
};
static Hash<Path, Compiler> sCompilers;

namespace CompilerManager {
List<Path> compilers()
{
    std::lock_guard<std::mutex> lock(sMutex);
    return sCompilers.keys();
}

List<String> flags(const Path &compiler)
{
    List<GccArguments::Define> defines;
    List<Path> includePaths;
    data(compiler, defines, includePaths);
    List<String> flags;
    flags.reserve(defines.size() + includePaths.size());
    for (List<GccArguments::Define>::const_iterator it = defines.begin(); it != defines.end(); ++it) {
        if (it->value.isEmpty()) {
            flags.append("-D" + it->define);
        } else {
            flags.append("-D" + it->define + "=" + it->value);
        }
    }
    return flags;
}

void data(const Path &c, List<GccArguments::Define> &defines, List<Path> &includePaths)
{
    std::lock_guard<std::mutex> lock(sMutex);
    Compiler &compiler = sCompilers[c];
    if (!compiler.inited) {
        compiler.inited = true;

        List<String> out, err;
        for (int i=0; i<2; ++i) {
            Process proc;
            List<String> args;
            List<String> environ;
            environ << "RTAGS_DISABLED=1";
            if (i == 0) {
                args << "-v" << "-x" << "c++" << "-E" << "-dM" << "-";
            } else {
                if (i == 0)
                    args << "-v" << "-E" << "-dM" << "-";
            }
            proc.exec(c, args, environ);
            assert(proc.isFinished());
            if (!proc.returnCode()) {
                out = proc.readAllStdOut().split('\n');
                err = proc.readAllStdErr().split('\n');
                break;
            } else if (i == 1) {
                out = proc.readAllStdOut().split('\n');
                err = proc.readAllStdErr().split('\n');
            }
        }
        for (int i=0; i<out.size(); ++i) {
            const String &line = out.at(i);
            // error() << c << line;
            if (line.startsWith("#define ")) {
                compiler.defines.append(GccArguments::Define());
                GccArguments::Define &def = compiler.defines.last();
                const int space = line.indexOf(' ', 8);
                if (space == -1) {
                    def.define = line.mid(8);
                } else {
                    def.define = line.mid(8, space - 8);
                    def.value = line.mid(space + 1);
                }
            }
        }

        for (int i=0; i<err.size(); ++i) {
            const String &line = err.at(i);
            int j = 0;
            while (j < line.size() && isspace(line.at(j)))
                ++j;
            Path path = line.mid(j);
            if (path.isDir()
#ifdef OS_Darwin
                && !path.contains("/lib/clang/")
#endif
                )
            {
                path.resolve();
                compiler.includePaths.append(path);
            }
        }
        // warning() << compiler << "got\n" << String::join(flags, "\n");

    }
    defines = compiler.defines;
    includePaths = compiler.includePaths;
}
}
