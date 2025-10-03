# my_utils/__init__.py
from .global_variables import *
from .helper_utilities import *
from .transmission import *
from .command_line_handling import *

import os
import pwd
import time
import datetime
import subprocess

# -------------------------------------------------------------------
# Compute startShlogfile's path and create 
# 2 linking directories, dest1 and dest2 (if missing)
# -------------------------------------------------------------------
startShlogfile = os.path.join(dLcLog, "startSh.log")
with open(startShlogfile, 'a'):
    os.utime(startShlogfile, None)

dest1 = os.path.join("/var/log", os.path.basename(startShlogfile))
remove_if_exists(dest1)
os.symlink(startShlogfile, dest1)

dest2 = os.path.join(dCProgramsSh, os.path.basename(startShlogfile))
remove_if_exists(dest2)
os.symlink(startShlogfile, dest2)

# -------------------------------------------------------------------
# Compute logfile's path and create the directory if missing
# -------------------------------------------------------------------
base_thisfile = os.path.basename(thisfile)
if base_thisfile.endswith(".x"):
    base_without_x = base_thisfile[:-2]  # remove the last 2 characters (".x")
else:
    base_without_x = base_thisfile
logfile = os.path.join(dLcLog, base_without_x + ".log")

with open(logfile, 'a'):
    os.utime(logfile, None)

# -------------------------------------------------------------------
# Compute the templogfile path:
#    templogfile = /tmp/<basename(thisfile)>/logfile
# -------------------------------------------------------------------
templogfile = os.path.join("/tmp", base_thisfile, "logfile")

# Create the directory for templogfile (like mkdir -p)
templogfile_dir = os.path.dirname(templogfile)
os.makedirs(templogfile_dir, exist_ok=True)

# Set full permissions
os.chmod(templogfile_dir, 0o777)

# -------------------------------------------------------------------
# Create a symlink from ${sourcedir}/programs to ${dZc}
# -------------------------------------------------------------------
remove_if_exists(dZc)
os.symlink(os.path.join(sourcedir, "programs"), dZc)

# -------------------------------------------------------------------
# Create a symlink for the logfile:
#    Link from ../log/<basename(thisfile without .x>.log to
#    ${dCProgramsSh}/<basename(thisfile without .x>.log
# -------------------------------------------------------------------
symlink_source = os.path.join("..", "log", base_without_x + ".log")
symlink_dest = os.path.join(dCProgramsSh, base_without_x + ".log")
remove_if_exists(symlink_dest)
os.symlink(symlink_source, symlink_dest)

# -------------------------------------------------------------------
# Change ownership of startShlogfile and logfile to masao:masao.
# -------------------------------------------------------------------
username = "masao"
user_info = pwd.getpwnam(username)
uid = user_info.pw_uid
gid = user_info.pw_gid
os.chown(startShlogfile, uid, gid)
os.chown(logfile, uid, gid)

# -------------------------------------------------------------------
# Rate-limiting to prevent excessively frequent operations by
# checking time elapsed since last OS modification time. Note: lastdatefile doestn exist yet
# -------------------------------------------------------------------
"""
if os.path.isfile(lastdatefile):
    # Read the date string from the file
    with open(lastdatefile, "r") as f:
        date_str = f.read().strip()

    # Convert the date string to a Unix timestamp using the "date" command
    try:
        output = subprocess.check_output(["date", "+%s", "--date", date_str])
        lastOsTermDateUt = int(output.strip())
    except Exception as e:
        print("Error parsing date from file:", e)
        # Set a default value or handle the error appropriately
        lastOsTermDateUt = 0

    waitSec = 120

    currentDateUt = int(time.time())
    diffUt = currentDateUt - lastOsTermDateUt
    print(f"{currentDateUt}-{lastOsTermDateUt}={diffUt}, waitSec: {waitSec}")

    # Loop until the difference reaches the waitSec threshold
    while diffUt < waitSec and diffUt > 0:
        time.sleep(5)
        currentDateUt = int(time.time())
        diffUt = currentDateUt - lastOsTermDateUt
        msg = f"Wait until diffsec: {diffUt} greater than {waitSec}"
        print(msg)
        with open(logfile, "a") as log:
            log.write(msg + "\n")
        # To send the message to /dev/tty1, uncomment the following line:
        # os.system(f'echo "{msg}" > /dev/tty1')

    print("do waitstart: OK!")
    with open(logfile, "a") as log:
        log.write("do waitstart: OK!\n")
"""
        
# --------------------------------------------------------------------
# Logging module setup
# --------------------------------------------------------------------
import time
import requests
import logging
import sys
import socket
from pythonjsonlogger import jsonlogger

# JSON formatter formats for different loggers.
valuable_json_format = '%(asctime)s %(levelname)s %(name)s %(unixtime)s %(hostname)s %(datelabel)s %(log)s'
important_json_format = '%(asctime)s %(levelname)s %(name)s %(datatype)s %(hostname)s %(currentDateUt)s %(currentDate)s %(thisfile)s %(msg)s'

class HTTPPostHandler(logging.Handler):
    """
    Sends JSON log via an HTTP POST to UrlOfLogServer. Standard HTTP post handler.
    """
    def __init__(self, url):
        super().__init__()
        self.url = url

    def emit(self, record):
        try:
            log_entry = self.format(record)
            response = requests.post(self.url, data={"json": log_entry})
            # print("result:", response.status_code)
        except Exception as e:
            print("HTTP POST failed:", e)

# ----------------------------------------
# Logger for Valuable Logs.
# Valuable logs sends JSON-formatted log to three places:
# Streamhandler (console), HTTP POST (UrlofLogServer), and a file(filenameOfsendValuableLog).
# ----------------------------------------
logger = logging.getLogger("valuable_logger")
logger.setLevel(logging.DEBUG)

# StreamHandler for outputting JSON-formatted logs to the console
stream_handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(valuable_json_format)

stream_handler.setFormatter(formatter)
logger.addHandler(stream_handler)

"""
# HTTP POST Handler for valuable logs.
http_handler = HTTPPostHandler(UrlOfLogServer)
http_handler.setFormatter(formatter)
logger.addHandler(http_handler)
"""

# FileHandler for appending the JSON log to the file specified by filenameOfsendValuableLog
file_handler = logging.FileHandler(filenameOfsendValuableLog)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

def sendValuableLogviaWebOrder(*log):
    """
    Build a JSON log,
    send it via HTTP POST, and append it to a file.
    """
    # Get current timestamp and formatted date/time strings.
    currentDateUt = int(time.time())
    currentDateymd = time.strftime("%Y%m%d", time.localtime(currentDateUt))
    currentDatehms = time.strftime("%H%M%S", time.localtime(currentDateUt))
    
    # Join all log arguments into a single string and replace double quotes.
    log_str = " ".join(log)
    log2 = log_str.replace('"', ' ')
    
    if not log_str:
        print("no log message!")
        sys.exit(1)
    
    # Define hostname.
    hostname = socket.gethostname()
    
    # Build the JSON log by collecting extra data into a dictionary.
    extra = {
        "unixtime": currentDateUt,
        "hostname": hostname,
        "datelabel": f"{currentDateymd}_{currentDatehms}",
        "log": log2
    }
    
    """
    # Display log information.
    print(f"send log to logserver of {UrlOfLogServer}")
    print("send log: ")
    try:
        pretty_log = json.dumps(extra, indent=4)
        print(pretty_log)
    except Exception as e:
        print("Error pretty printing JSON:", e)
    """
    
    # Log the message (triggers HTTP POST and file append via the attached handlers).
    logger.info("Valuable log", extra=extra)

# Store the script filename.
thisfile = __file__

# ----------------------------------------
# Logger for Important Logs.
# Important logs sends JSON-formatted log to three places:
# Streamhandler (console), HTTP POST (UrlOfsendImportantlog), and a file(filenameOfsendImportantLog).
# ----------------------------------------
important_logger = logging.getLogger("important_logger")
important_logger.setLevel(logging.DEBUG)

# StreamHandler for console output with JSON formatting.
stream_handler_imp = logging.StreamHandler()
formatter_imp = jsonlogger.JsonFormatter(important_json_format)
stream_handler_imp.setFormatter(formatter_imp)
important_logger.addHandler(stream_handler_imp)

"""
# HTTP POST Handler for important logs.
'''
UrlOfsendImportantlog missing in the original code. Assuming it is the same as UrlOfLogServer
'''
UrlOfsendImportantlog = UrlOfLogServer
http_handler_imp = HTTPPostHandler(UrlOfsendImportantlog)
http_handler_imp.setFormatter(formatter_imp)
important_logger.addHandler(http_handler_imp)
"""

# FileHandler for important logs.
file_handler_imp = logging.FileHandler(filenameOfsendImportantLog)
file_handler_imp.setFormatter(formatter_imp)
important_logger.addHandler(file_handler_imp)

def sendImportantlog(msg):
    """
    Build a JSON log for an important alert,
    send it via HTTP POST, and append it to a file.
    """
    # Get hostname.
    hostName = socket.gethostname()
    # 現在日時: current Unix timestamp.
    currentDateUt = int(time.time())
    # Formatted current date/time.
    currentDate = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(currentDateUt))
    # script filename.
    scriptfilename = thisfile

    # Build the extra data dictionary.
    extra = {
        "datatype": "aleartlog",  # Notice: the spelling matches the shell code ("aleartlog")
        "hostname": hostName,
        "currentDateUt": currentDateUt,
        "currentDate": currentDate,
        "thisfile": scriptfilename,
        "alert_msg": msg
    }

    """
    # Pretty print the JSON log.
    try:
        pretty_log = json.dumps(extra, indent=4)
        print(pretty_log)
    except Exception as e:
        print("Error pretty printing JSON:", e)
    """
    
    # Log the message (this triggers all attached handlers).
    important_logger.info("Important alert log", extra=extra)
    print("done: send aleartlog: success")

# ----------------------------------------
# Basic JSON Logger. Only prints onto the console.
# ----------------------------------------
json_logger = logging.getLogger("json_logger")
json_logger.setLevel(logging.INFO)
if not json_logger.handlers:
    handler = logging.StreamHandler()
    simple_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(simple_formatter)
    json_logger.addHandler(handler)

def setJsonToJsonAsTxt(key, value, jsondata):
    """
    Register text data as a JSON key–value pair.
    Usage: setJsonToJsonAsTxt(key, value, jsondata)
    Appends the key with a quoted value into the jsondata string.
    """
    jsoncore = f'"{key}":"{value}"'
    if not jsondata or jsondata == "{}":
        jsondata = "{" + jsoncore + "}"
    else:
        jsondata = jsondata[:-1] + "," + jsoncore + "}"
    json_logger.info(jsondata)
    return jsondata

def setJsonToJsonAsNum(key, value, jsondata):
    """
    Register numeric data as a JSON key–value pair.
    Usage: setJsonToJsonAsNum(key, value, jsondata)
    Appends the key with the numeric value (without quotes) into the jsondata string.
    """
    jsoncore = f'"{key}":{value}'
    if not jsondata or jsondata == "{}":
        jsondata = "{" + jsoncore + "}"
    else:
        jsondata = jsondata[:-1] + "," + jsoncore + "}"
    json_logger.info(jsondata)
    return jsondata

def setJsonToJsonAsJsonOrNumOrNull(key, value, jsondata):
    """
    Register JSON, numeric, or null value as a JSON key–value pair.
    Usage: setJsonToJsonAsJsonOrNumOrNull(key, value, jsondata)
    Appends the key with a value (assumed to be valid JSON, a number, or null)
    without adding extra quotes.
    """
    jsoncore = f'"{key}":{value}'
    if not jsondata or jsondata == "{}":
        jsondata = "{" + jsoncore + "}"
    else:
        jsondata = jsondata[:-1] + "," + jsoncore + "}"
    json_logger.info(jsondata)
    return jsondata

import re
from datetime import datetime

currentDateUt = int(time.time())
currentDateymd = datetime.fromtimestamp(currentDateUt).strftime("%Y%m%d")
currentDatehms = datetime.fromtimestamp(currentDateUt).strftime("%H%M%S")

# Replace .sh.x at the end of thisfile with .sh
sourceSh = re.sub(r'\.sh\.x$', '.sh', thisfile)
sourceSh = re.sub(r'\.sh\.x$', '.sh', thisfile)

if os.path.isfile(sourceSh):
    # Look for the first line containing 'SerialNo=' and extract the value
    processSerialNo = ""
    with open(sourceSh, "r") as f:
        for line in f:
            if "SerialNo=" in line:
                processSerialNo = line.split("SerialNo=", 1)[1].strip()
                break
else:
    processSerialNo = ""
    
jsondata = "{}"
jsondata = setJsonToJsonAsNum("unixtime", currentDateUt, jsondata)
jsondata = setJsonToJsonAsTxt("hostname", socket.gethostname(), jsondata)
jsondata = setJsonToJsonAsTxt("datelabel", f"{currentDateymd}_{currentDatehms}", jsondata)
jsondata = setJsonToJsonAsTxt("process", preprocess, jsondata)
jsondata = setJsonToJsonAsTxt("processSerialNo", processSerialNo, jsondata)

# -------------------------------------------------------------------
# Function definitions
# -------------------------------------------------------------------
import psutil

def version(script_name, serial_no):
    """
    Prints the script name and serial number.
    
    Args:
        script_name (str): The name of the script (equivalent to $0 in Bash).
        serial_no (str): The serial number.
    
    Returns:
        None
    """
    print(f"{script_name}, SerialNo: {serial_no}")

def waitNsecSpendFromBoot(waitsec, dotype):
    """
    Waits until a specified number of seconds have passed since system boot before executing.

    Args:
        waitsec (int): The minimum time (in seconds) that must have passed since boot.
        dotype (int): Determines behavior if time has not passed (0 = exit, 1 = wait).
        logfile (str): Path to the log file where messages will be logged.
    """
    # Get unix time
    currentDateUt = int(time.time())
    
    # Get system uptime (in seconds) from /proc/uptime
    with open('/proc/uptime', 'r') as f:
        uptimeDateUt = float(f.readline().split()[0])
    
    # Redundant method of getting boot time, reserved for future modifications
    diffsec = currentDateUt - (currentDateUt - uptimeDateUt)

    msg = f"now: {currentDateUt}, uptime: {uptimeDateUt}, diff: {diffsec} [sec]"
    sendImportantlog(msg)

    if diffsec < waitsec:
        if dotype == 0:
            # 待機時間を経過していない場合は実行せずに終了
            msg = (f"Impossible to execute {sys.argv[0]}. Passing time is {diffsec} [sec] lower than "
                   f"the waiting time ({waitsec} [sec])")
            sendImportantlog(msg)
            sys.exit(1)
        else:
            # 待機時間を経過していない場合は経過するまで待機して実行
            remaining_time = waitsec - diffsec
            msg = f"Waiting {remaining_time} [sec] to execute {sys.argv[0]}"
            sendImportantlog(msg)
            time.sleep(remaining_time)
    else:
        # No need to wait
        msg = (f"No need to wait. Passing time is {diffsec} [sec], which is over the inputed waiting "
               f"time ({waitsec} [sec])")
        sendImportantlog(msg)

def readwait(message):
    """
    Displays a message and asks the user if they want to continue.
    Only continues if the user types 'yes', otherwise it exits.
    
    Args:
        message (str): The message to display.
    """
    print(f"this is {message}")

    while True:
        user_input = input("Do you want to continue? (yes/no) > ").strip().lower()
        
        if user_input == "yes":
            print("Proceeding...")
            break  # Exit the loop and continue execution
        elif user_input == "no":
            print("Exiting...")
            exit(1)  # Exit the script
        else:
            print("Invalid input! Please type 'yes' or 'no'.")

def waitforever():
    while True:
        time.sleep(600)

def IsRunning():
    print("do: IsRunning")
    print("$$: ", os.getpid())
    
    # Use sys.argv[0] as equivalent of "$0"
    try:
        # pgrep -fo "$0" finds the oldest process running this script
        pgrep_output = subprocess.check_output(["pgrep", "-fo", sys.argv[0]]).decode().strip()
    except subprocess.CalledProcessError:
        # If pgrep fails, assume no other process is running
        pgrep_output = str(os.getpid())
    print("pgrep: ", pgrep_output)
    
    try:
        oldest_pid = int(pgrep_output)
    except ValueError:
        oldest_pid = os.getpid()
    
    if os.getpid() != oldest_pid:
        message = "以下のプロセスが起動済みです。"
        print(message)
        with open(logfile, "a") as f:
            f.write(message + "\n")
            
        # Get process list (similar to ps -aux)
        ps_output = subprocess.check_output(["ps", "aux"]).decode()
        for line in ps_output.splitlines():
            if pgrep_output in line and "grep " not in line:
                print(line)
                with open(logfile, "a") as f:
                    f.write(line + "\n")
        print("[注意] tail等でログファイルを開いていると「起動済み」と誤検知します。")
        
        # Check if any line contains "tail -f" and the script name
        tail_found = any("tail -f" in line and pgrep_output in line for line in ps_output.splitlines())
        if not tail_found:
            sys.exit(1)

def stop():
    """
    # 起動中の同名プログラムをすべて終了する
    """
    # Call showps to display current processes
    showps()
    
    script_name = os.path.basename(sys.argv[0])
    current_pid = os.getpid()
    
    # Build psidlist using the same filtering as in showps.
    psidlist = []
    for proc in psutil.process_iter(attrs=['pid', 'cmdline']):
        try:
            cmdline = proc.info['cmdline']
            if cmdline:
                cmdline_str = " ".join(cmdline)
                if (script_name in cmdline_str and 
                    "grep" not in cmdline_str and 
                    "vi " not in cmdline_str and 
                    "tail -f" not in cmdline_str):
                    psidlist.append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    # Iterate over each process ID in psidlist
    for psid in psidlist:
        if psid != current_pid:
            # Build the command string as in shell: "kill <psid>"
            command = f"kill {psid}"
            
            # Display process information for this psid (like ps -aux | grep psid)
            try:
                proc = psutil.Process(psid)
                info = proc.as_dict(attrs=['pid', 'name', 'cmdline'])
                print(info)
            except psutil.NoSuchProcess:
                print(f"Process {psid} not found.")
            
            # Log the kill command to both stdout and logfile
            print(command)
            with open(logfile, "a") as f:
                f.write(command + "\n")
            
            # Execute the kill command by terminating the process
            try:
                proc = psutil.Process(psid)
                proc.terminate()  # Send SIGTERM
                proc.wait(timeout=3)  # Wait for the process to exit
                result = 0
            except Exception:
                result = 1
            
            out = f"result: {result}"
            print(out)
            with open(logfile, "a") as f:
                f.write(out + "\n")
        else:
            # If the process ID is the current process ID, log it accordingly.
            out = f"this is myid {psid}"
            print(out)
            with open(logfile, "a") as f:
                f.write(out + "\n")
                
def showps():
    """
    # 起動中の同名プログラムのプロセス情報を取得・表示する
    """
    # Print the script name ($0 in shell)
    print("$0:", sys.argv[0])
    
    # Set mypsid to the current process ID (equivalent to $$)
    mypsid = os.getpid()
    out = f"mypsid: {mypsid}"
    print(out)
    with open(logfile, "a") as f:
        f.write(out + "\n")
    
    # Get the basename of the script (as in basename $0)
    script_name = os.path.basename(sys.argv[0])
    
    # Build psidlist by iterating over all processes and filtering out unwanted ones.
    psidlist = []
    for proc in psutil.process_iter(attrs=['pid', 'cmdline']):
        try:
            cmdline = proc.info['cmdline']
            if cmdline:
                # Join the command line into a single string.
                cmdline_str = " ".join(cmdline)
                # Filter: include if script_name is in the command line and exclude "grep", "vi ", and "tail -f"
                if (script_name in cmdline_str and 
                    "grep" not in cmdline_str and 
                    "vi " not in cmdline_str and 
                    "tail -f" not in cmdline_str):
                    psidlist.append(proc.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    out = f"psidlist: {psidlist}"
    print(out)
    with open(logfile, "a") as f:
        f.write(out + "\n")
    
    # For each psid in psidlist, display process info (similar to ps -aux | grep psid)
    for psid in psidlist:
        try:
            proc = psutil.Process(psid)
            info = proc.as_dict(attrs=['pid', 'name', 'cmdline'])
            print(info)
        except psutil.NoSuchProcess:
            continue
        
# -------------------------------------------------------------------
# Shrink log file sizes
# -------------------------------------------------------------------
shrinkfile(startShlogfile, 200000, 100000)
shrinkfile(logfile, 100000, 50000)


