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

import vte.c.types;

import gx.i18n.l10n;
import gx.gtk.threads;

import gx.tilix.common;
import gx.tilix.constants;
import gx.tilix.terminal.activeprocess;

import gx.tilix.application;

enum MonitorEventType {
    None,
    STARTED,
    CHANGED,
    FINISHED
};

/**
 * Class that monitors processes to see if new child processes have been
 * started or finished and raises an event if detected. This class uses
 * a separate thread to monitor the processes and a timeoutDelegate to
 * trigger the actual events to the terminals.
 */
class ProcessMonitor {
private:
    Tid tid;
    bool running = false;

    bool fireEvents() {
        synchronized {
            foreach(process; processes) {
                if (process.eventType != MonitorEventType.None) {
                    onChildProcess.emit(process.eventType, process.gpid, process.activePid, process.activeName);
                    process.eventType = MonitorEventType.None;
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
    void addProcess(GPid gpid) {
        synchronized {
            if (gpid !in processes) {
                shared ProcessStatus status = new shared(ProcessStatus)(gpid);
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
                // `processes` is `shared`; accessing its length directly is rejected by newer DMD.
                // We already hold the global monitor here, so it is safe to view it as non-shared.
                auto localProcesses = cast(ProcessStatus[GPid]) processes;
                if (running && localProcesses.length == 0) stop();
            }
        }
    }

    /**
     * When a process changes inform children
     */
    GenericEvent!(MonitorEventType, GPid, pid_t, string) onChildProcess;

    static @property ProcessMonitor instance() {
        if (!tilix.processMonitor) {
            warningf(_("Process monitoring is not enabled, this should never be called"));
        }
        if (_instance is null) {
            _instance = new ProcessMonitor();
        }
        return _instance;
    }
}

private:

/**
 * Constant used for sleep time between checks.
 */
enum SLEEP_CONSTANT_MS = 300;

/**
 * List of processes being monitored.
 */
shared ProcessStatus[GPid] processes;

void monitorProcesses(int sleep, Tid tid) {
    bool abort = false;
    while (!abort) {
        synchronized {
            // At this point we have a list of active processes of
            // all open terminals. We need to get these using shell
            // PID and will store them to raise events for each terminal.
            auto activeProcesses = getActiveProcessList();
            foreach(process; processes) {
                auto activeProcess  = activeProcesses.get(process.gpid, null);
                // No need to raise event for same process.
                if (activeProcess !is null && activeProcess.pid != process.activePid) {
                    process.activeName = activeProcess.name;
                    process.activePid = activeProcess.pid;
                    process.eventType = MonitorEventType.STARTED;
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

/**
 * Status of a single process
 */
shared class ProcessStatus {
    GPid gpid;
    pid_t activePid = -1;
    string activeName = "";
    MonitorEventType eventType = MonitorEventType.None;

    this(GPid gpid) {
        this.gpid = gpid;
    }
}
