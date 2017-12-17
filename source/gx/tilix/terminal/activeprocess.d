module gx.tilix.terminal.activeprocess;

import core.sys.posix.unistd;
import core.thread;

import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.file;
import std.path;
import std.string;


/**
* A stripped-down (plus extended) version of psutil's Process class.
*/
class Process {

    pid_t pid;
    string[] processStat;
    static Process[pid_t] processMap;
    static Process[][pid_t] sessionMap;

    this(pid_t p)
    {
        pid = p;
        processStat = parseStatFile();
    }

    @property string name() {
        return processStat[0];
    }

    @property pid_t ppid() {
        return to!pid_t(processStat[2]);
    }

    string[] parseStatFile() {
        try {
            string data = to!string(cast(char[])read(format("/proc/%d/stat", pid)));
            size_t rpar = data.lastIndexOf(")");
            string name = data[data.indexOf("(") + 1..rpar];
            string[] other  = data[rpar + 2..data.length].split;
            return name ~ other;
        } catch (FileException fe) {
            warning(fe);
            }
        return [];
    }

    /**
    * Foreground process has a controlling terminal and
    * process group id == terminal process group id.
    */
    bool isForeground() {
        if (!Process.pidExists(pid)) {
            return false;
        }
        // Need updated version.
        string[] tempStat = parseStatFile();
        long pgrp = to!long(tempStat[3]);
        long tty = to!long(tempStat[5]);
        long tpgid = to!long(tempStat[6]);
        return tty > 0 && pgrp == tpgid;
    }

    bool hasTTY() {
        return to!long(processStat[5]) > 0;
    }

    /**
    * Shell PID == session ID
    */
    pid_t sessionID() {
        return to!pid_t(processStat[4]);
    }

    /**
    * Return true if this process has any foreground child process.
    * Note that `Process.sessionMap` contains foreground processes only.
    */
    bool HasForegroundChildren() {
        foreach (p; Process.sessionMap.get(sessionID(), [])) {
            if (p.ppid == pid) {
                return true;
            }
        }
        return false;
    }

    /**
    * Get all running PIDs.
    */
    static pid_t[] pids() {
        return std.file.dirEntries("/proc", SpanMode.shallow)
            .filter!(a => std.path.baseName(a.name).isNumeric)
            .map!(a => to!pid_t(std.path.baseName(a.name)))
            .array;
    }

    static bool pidExists(pid_t p) {
            return exists(format("/proc/%d", p));
    }

    /**
    * Create `Process` object of all PIDs and store them in
    * `Process.processMap` and store foreground processes
    * in `Process.sessionMap` using session id as their key.
    */
    static void updateMap() {

        Process add(pid_t p) {
            auto proc = new Process(p);
            Process.processMap[p] = proc;
            return proc;
        }

        void remove(pid_t p) {
            Process.processMap.remove(p);
        }

        auto pids = Process.pids().sort();
        auto pmapKeys = Process.processMap.keys.sort();
        auto gonePids = setDifference(pmapKeys, pids);

        foreach(p; gonePids) {
            remove(p);
        }

        Process.processMap.rehash;
        Process proc;
        Process.sessionMap.clear;

        foreach(p; pids) {
            if ((p in Process.processMap) !is null) {
                proc = Process.processMap[p]; // Cached process.
            } else if (Process.pidExists(p)) {
                proc = add(p); // New Process.
            }
            // Taking advantages of short-circuit operator `&&` using `proc.hasTTY()`
            // to reduce calling on `proc.isForeground()`.
            if (proc !is null && proc.hasTTY() && proc.isForeground()) {
                Process.sessionMap[proc.sessionID()] ~= proc;
            }
        }
    }
}


/**
 * Get active process list of all terminals.
 * `Process.sessionMap` contains foreground processes of all
 * open terminals using session id (shell PID) as their key. We are
 * iterating through all processes for each session id and trying
 * to find their active process and finally returning all active process.
 * Returning all active process is very efficient when there are too
 * many open terminals comparing to find the active process of several
 * terminals one by one.
 */
Process[pid_t] getActiveProcessList() {
    //  Update `Process.sessionMap` and `Process.processMap`.
    Process.updateMap();
    Process[pid_t] ret;
    foreach(shellChild; Process.sessionMap.byValue()) {
         // The shell process has only one foreground
         // process, so, it is an active process.
        if (shellChild.length == 1) {
            auto proc = shellChild[0];
            ret[proc.sessionID()] = proc;
        } else {
            // Probably, the last item is the active process.
            foreach_reverse(proc; shellChild) {
                // If a foreground process has no foreground
                // child process then it is an active process.
                if (!proc.HasForegroundChildren()) {
                    ret[proc.sessionID()] = proc;
                    break;
                }
            }
        }
    }
    return ret;
}
