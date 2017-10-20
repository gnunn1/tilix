module gx.tilix.terminal.activeprocess;

import core.sys.posix.unistd;
import core.thread;

import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.stdio;
import std.string;
import std.file;
import std.path;


class Process {

    pid_t pid;
    string[] processStat;
    static Process[pid_t] PMap;

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

    string status() {
        return processStat[1];
    }

    string[] parseStatFile() {
        try {
            string data = to!string(cast(char[])read(format("/proc/%d/stat", pid)));
            long rpar = data.lastIndexOf(")");
            string name = data[data.indexOf("(") + 1..rpar];
            string[] other  = data[rpar + 2..data.length].split;
            return name ~ other;
        } catch (FileException fe) {
            warning(fe);
        }
        return [];
    }

    bool isRunning() {
        if (!Process.pidExists(pid)) {
            return false;
        }

        return createTime() == to!long(parseStatFile()[20]);
    }

    bool isForeground() {
        if (!Process.pidExists(pid)) {
            return false;
        }
        string[] tempStat = parseStatFile();
        long pgrp = to!long(tempStat[3]);
        long tty = to!long(tempStat[5]);
        long tpgid = to!long(tempStat[6]);
        return tty > 0 && pgrp == tpgid;
    }

    long createTime() {
        return to!long(processStat[20]);
    }

    bool hasTTY() {
        return to!long(processStat[5]) > 0;
    }

    Process[] children() {
        Process[] ret = [];
        foreach (p; Process.processIter()) {
            if (p.ppid == pid && createTime() <= p.createTime()) {
                ret ~= p;
            }
        }
        return ret;
    }

    Process[] children(bool recursive) {
        Process[] ret = []; 
        if (!recursive) {
            ret = children();
        } else {
            Process[][pid_t] table;
            foreach (p; Process.processIter()) {
                table[p.ppid] ~= p;
            }

            pid_t[] checkpids = [pid];

            for(int i=0; i < checkpids.length; i++) {
                pid_t checkpid = checkpids[i];
                if((checkpid in table) !is null){
                    foreach (child; table[checkpid]) {
                        if (createTime() <= child.createTime()) {
                            ret ~= child;
                            if (!checkpids.canFind(child.pid)) {
                                checkpids ~= child.pid;
                            }
                        }
                    }
                }
            }
        }
        return ret;
    }

    static pid_t[] pids() {
        return std.file.dirEntries("/proc", SpanMode.shallow)
            .filter!(a => std.path.baseName(a.name).isNumeric)
            .map!(a => to!pid_t(std.path.baseName(a.name)))
            .array;
    }

    static bool pidExists(pid_t p) {
            return exists(format("/proc/%d", p));
    }

    static Process[] processIter() {

        Process add(pid_t p) {
            auto proc = new Process(p);
            Process.PMap[p] = proc;
            return proc;
        }

        void remove(pid_t p) {
            Process.PMap.remove(p);
        }

        auto pids = Process.pids().sort;
        auto pmapKeys = Process.PMap.keys.sort;
        auto gonePids = setDifference(pmapKeys, pids);

        foreach(p; gonePids) {
            remove(p);
        }

        Process.PMap.rehash();
        Process proc;
        Process[] ret = [];

        foreach(p; pids) {
            if ((p in Process.PMap) !is null) {
                proc = Process.PMap[p];
            } else if (Process.pidExists(p)) {
                proc = add(p);
            }
            if (proc !is null && proc.hasTTY()) {
                ret ~= proc;
            }
        }
        return ret;
    }
}


class ForegroundProcess {

    Process[] parentProcess;
    bool[Process] foregroundProcesses;
    Process[] processArray;
    pid_t pid;

    this(pid_t p) {
        pid = p;
    }

    Process[] getArray() {
        update();
        return foregroundProcesses.keys;
    }

    void update() {
        updateProcess();
        updateForeground();
    }

    void updateProcess() {
        if (!Process.pidExists(pid)){
            processArray = [];
        } else {
            auto parentProcess = new Process(pid);
            processArray = parentProcess.children(true) ~ [parentProcess];
         }
    }

    void updateForeground() {
        foregroundProcesses.clear;
        foreach(process; processArray) {
            if (!process.isRunning()) {
                Process.PMap.remove(process.pid);
            }
            if (process.isForeground()) {
                foregroundProcesses[process] = true;
            }
        }
    }

    static bool anyForeground(Process[] processes) {
        foreach(proc; processes) {
            if (proc.isForeground()) {
                return true;
            }
        }
        return false;
    }
}


class GetActiveProcess: ForegroundProcess {

    this(pid_t p) {
        super(p);
    }

    Process process() {
        foreach (proc; getArray()) {
            if (!(proc.isRunning() && proc.isForeground())) {
                continue;
            } 
            if (ForegroundProcess.anyForeground(proc.children())) {
                continue;
            }
           return proc;
        }
        return null;
    }
}
