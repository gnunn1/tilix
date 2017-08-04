/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.monitor;

import core.sys.posix.unistd;
import core.thread;

import std.concurrency;
import std.datetime;
import std.experimental.logger;
import std.parallelism;

import vtec.vtetypes;

import gx.gtk.threads;

import gx.tilix.common;

enum MonitorEventType {
    NONE,
    STARTED, 
    CHANGED, 
    FINISHED
};

/**
 * Class that monitors processes to see if new child process have been
 * create and raises an alert if so.
 */
class ProcessMonitor {
private:
    Tid tid;
    bool running = false;

    bool fireEvents() {
        synchronized {
            foreach(process; processes.values()) {
                if (process.eventType != MonitorEventType.NONE) {
                    onChildProcess.emit(process.eventType, process.gpid, process.fd);
                    process.eventType = MonitorEventType.NONE;
                }
            }
        }
        return running;
    }

    static ProcessMonitor _instance;

public:
    this() {

    }

    ~this() {
        stop();
    }

    void start() {
        running = true;
        tid = spawn(&monitorProcesses, SLEEP_CONSTANT_MS, thisTid);
        threadsAddTimeoutDelegate(SLEEP_CONSTANT_MS, &fireEvents);
        trace("Started process monitoring");
    }

    void stop() {
        if (running) tid.send(true);
        running = false;
        trace("Stopped process monitoring");
    }

    /**
     * Add a process for monitoring
     */
    void addProcess(GPid gpid, int fd) {
        synchronized {
            if (gpid !in processes) {
                shared ChildStatus status = new shared(ChildStatus)(gpid, fd);
                processes[gpid] = status;
            }
        }
        if (!running) start();
    }

    /**
     * Remove a process for monitoring
     */
    void removeProcess(GPid gpid) {
        synchronized {
            if (gpid in processes) {
                processes.remove(gpid);
                if (running && processes.length == 0) stop();
            }
        }
    }

    /**
     * When a process changes inform children
     */
    GenericEvent!(MonitorEventType, GPid, pid_t) onChildProcess;

    static @property ProcessMonitor instance() {
        if (_instance is null) {
            _instance = new ProcessMonitor();
        }

        return _instance;
    }
}

private:

enum SLEEP_CONSTANT_MS = 250;

shared ChildStatus[GPid] processes;

void monitorProcesses(int sleep, Tid tid) {
    bool abort = false;
    while (!abort) {
        synchronized {
            foreach(process; processes.values()) {
                pid_t childPid = tcgetpgrp(process.fd);
                if (childPid != process.childPid && (process.childPid == -1 || process.childPid == process.gpid)) {
                    process.childPid = childPid;
                    process.lastChanged = Clock.currStdTime();
                    process.eventType = MonitorEventType.STARTED;
                } else if (childPid != process.childPid) {
                    process.childPid = childPid;
                    if (childPid == -1 || process.childPid == process.gpid) {
                        process.eventType = MonitorEventType.FINISHED;
                    } else {
                        process.eventType = MonitorEventType.CHANGED;
                    }
                }
            }
        }
        receiveTimeout(dur!("msecs")( sleep ), 
                (bool msg) {
                    if (msg) abort = true;
                }
        );    
    }
}


shared class ChildStatus {
    GPid gpid;
    int fd;
    pid_t childPid = -1;
    long lastChanged;
    MonitorEventType eventType = MonitorEventType.NONE;

    this(GPid gpid, int fd) {
        this.gpid = gpid;
        this.fd = fd;
    }
}