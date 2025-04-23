import os
import socket
import subprocess
import threading
import datetime
import time
import psutil
import logging
from pythonjsonlogger import jsonlogger

# ----------------------------------------
# Macros
# ----------------------------------------
interval = 10.0 # 300 seconds

# ----------------------------------------
# Logger for Important Logs.
# Important logs sends JSON-formatted log to three places:
# Streamhandler (console), HTTP POST (UrlOfsendImportantlog), and a file(filenameOfsendImportantLog).
# ----------------------------------------
important_logger = logging.getLogger("important_logger")
important_logger.setLevel(logging.DEBUG)

# StreamHandler for console output with JSON formatting.
stream_handler_imp = logging.StreamHandler()
important_json_format = '%(asctime)s %(levelname)s %(name)s %(datatype)s %(hostname)s %(currentDateUt)s %(currentDate)s %(thisfile)s %(msg)s'
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
hostname = socket.gethostname()
filenameOfsendImportantLog = f"/zelowa/clientx/{hostname}/log/sendImportantLog.log"
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
    scriptfilename = __file__

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

# Send an important log indicating the script is running.
sendImportantlog("ble_capture_dump script running")

# --------------------------------------
# Kill all nrfutil processes
# --------------------------------------
def kill_nrfutil_processes():
    # Iterate through all running processes
    for proc in psutil.process_iter(['pid', 'name']):
        try:
            # Check if 'nrfutil' is part of the process name
            if proc.info['name'] and 'nrfutil' in proc.info['name']:
                print(f"Killing process: {proc.info['name']} (PID: {proc.info['pid']})")
                proc.kill()  # Forcefully terminate the process
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    
    # final, blanket SIGKILL for anything still alive ---
    subprocess.run(["pkill", "-9", "-f", "nrfutil"], check=False)

# --------------------------------------
# Check if nrfutil is running
# --------------------------------------
def is_nrfutil_running():
    """
    Check if any process with 'nrfutil' in its name or command line is running.
    Returns True if found, False otherwise.
    """
    for proc in psutil.process_iter(attrs=['name', 'cmdline']):
        try:
            # Check if 'nrfutil' is in the process name or its command line
            name = proc.info['name'] or ""
            cmdline = " ".join(proc.info.get('cmdline') or [])
            if 'nrfutil' in name or 'nrfutil' in cmdline:
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    return False

# -------------------------------------
# Directory handling
# -------------------------------------
# Create a prefix filename using the hostname
prefixFilename = f"ble.{socket.gethostname()}"

# Define the bledumpdir for raw tshark captures and ensure it exists
bledumpdir = "/tmp/ble.dump.0"
os.makedirs(bledumpdir, exist_ok=True)
pcap_dir = os.path.join(bledumpdir, "raw_pcap")
os.makedirs(pcap_dir, exist_ok=True)

# Define bledumpdir/raw_csv for converted csv files and ensure it exists
csv_dir = os.path.join(bledumpdir, "raw_csv")
os.makedirs(csv_dir, exist_ok=True)

# Define bledumpdir/done2merged for merged files and ensure it exists
merged_dir = os.path.join(bledumpdir, "done2merged")
os.makedirs(merged_dir, exist_ok=True)

# --------------------------------------
# Start ble capture
# --------------------------------------
def start_capture():
    """
    Usage:
    start_capture(bledumpdir)
    Set bledumpdir in global variables at the beginning of this script
    """
    # Send log to console, logfile, server that script is running
    sendImportantlog("start ble capture")
    
    # Create the target file path using the hostname and current date/time.
    hostname = socket.gethostname()
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    targetfile = os.path.join(pcap_dir, f"bledump_{hostname}_{timestamp}.pcap")

    # Run the nrfutil ble-sniffer command in the background.
    # This command is equivalent to:
    # nrfutil ble-sniffer sniff --port /dev/ttyACM0 --output-pcap-file ${targetfile} &
    process = subprocess.Popen([
        "nrfutil", "ble-sniffer", "sniff",
        "--port", "/dev/ttyACM0",
        "--output-pcap-file", targetfile
    ])
    
    # Schedule the process to be killed after interval - 5 seconds.
    timer = threading.Timer(interval - 5, kill_nrfutil_processes)
    timer.start()
    timer.join()
    
    return targetfile, timestamp

# ------------------------------------------------------------
# Convert .pcap file captured in 290 seconds to csv format
# ------------------------------------------------------------
import subprocess
import re
import pandas as pd
import io


def extract_ble_data(pcap_file, timestamp):
    if not os.path.exists(pcap_file):
        raise FileNotFoundError(f"PCAP file not found: {pcap_file}")
    
    # Define name of converted CSV file.
    hostname = socket.gethostname()
    csv_file = os.path.join(csv_dir, f"bledump_{hostname}_{timestamp}.csv")
    
    # Define the tshark command
    tshark_cmd = [
        "tshark",
        "-r", pcap_file,
        "-T", "fields",
        "-E", "separator=/t",
        "-e", "btle.advertising_address",
        "-e", "frame.time_epoch",
        "-e", "nordic_ble.rssi",
        "-e", "btcommon.eir_ad.entry.data",
        "-e", "btcommon.eir_ad.entry.service_data",
        "-e", "btcommon.eir_ad.entry.uuid_16"
    ]
    
    try:
        # Run the tshark command and capture output
        process = subprocess.Popen(tshark_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        
        if process.returncode != 0:
            error_msg = stderr.decode('utf-8')
            raise RuntimeError(f"tshark command failed with error: {error_msg}")
        
        # Let pandas parse
        df = pd.read_csv(io.StringIO(stdout.decode()),
                        sep="/t", header=None,
                        names=['bdaddr','timestamp','rssi','adv_data','service_data','uuid_16'])

        df['timestamp'] = pd.to_numeric(df['timestamp'], errors='coerce')
        df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s', utc=True)
        
        # debug
        valid = df['timestamp'].dropna()
        if not valid.empty:
            print(f"Min timestamp: {valid.min()}")
            print(f"Max timestamp: {valid.max()}")
        
        df.to_csv(csv_file, index=False)
        print(f"Data saved to {csv_file}")
            
        return
        
        
        
        """
        # Process the output
        lines = stdout.decode('utf-8').splitlines()
        
        # Filter out invalid lines
        valid_lines = []
        for line in lines:
            # Check for valid MAC address at the beginning
            if re.match(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}', line) and not line.startswith('00:00:00:00:00:00'):
                valid_lines.append(line)
        
        # Create a DataFrame
        if valid_lines:
            df = pd.DataFrame(
                [line.split(',', 5) for line in valid_lines],
                columns=[
                    'bdaddr',
                    'timestamp',
                    'rssi',
                    'adv_data',
                    'service_data',
                    'uuid_16'
                ]
            )
            
            # Clean up timestamp (remove fractional seconds if present)
            df['timestamp'] = df['timestamp'].str.split('.').str[0]
            
            # Remove colons from MAC addresses
            df['bdaddr'] = df['bdaddr'].str.replace(':', '', regex=False)
            
            # Save to CSV
            df.to_csv(csv_file, index=False)
            print(f"Data saved to {csv_file}")
            
            return
        else:
            print("No valid BLE advertisement packets found in the capture file")
    """
    except Exception as e:
        print(f"Error processing PCAP file: {str(e)}")
        raise

"""
def extract_ble_data(pcap_file, timestamp):
    if not os.path.exists(pcap_file):
        raise FileNotFoundError(f"PCAP file not found: {pcap_file}")
    
    # Define name of converted CSV file.
    hostname = socket.gethostname()
    csv_file = os.path.join(csv_dir, f"bledump_{hostname}_{timestamp}.csv")

    tshark_cmd = [
        "tshark",
        "-r", pcap_file,
        "-T", "fields",
        "-E", "separator=,",    # use comma as field separator
        "-E", "header=y",       # include a header row
        "-e", "btle.advertising_address",      # bdaddr
        "-e", "frame.time_epoch",              # timestamp
        "-e", "nordic_ble.rssi",               # rssi
        "-e", "btcommon.eir_ad.entry.data",    # adv_data
        "-e", "btcommon.eir_ad.entry.service_data",  # service_data
        "-e", "btcommon.eir_ad.entry.uuid_16"         # uuid_16
    ]

    # run tshark and write its CSV output directly to csv_file
    with open(csv_file, "w") as out:
        subprocess.run(tshark_cmd, stdout=out, check=True)
    
    df = pd.read_csv(csv_file)
    min_time = df['frame.time_epoch'].min()
    max_time = df['frame.time_epoch'].max()
    print(f"min_time: {min_time}, max_time: {max_time}")
"""

if __name__ == "__main__":
    # Check if the ble capture process is still running, force exit if still running
    MAX_ATTEMPTS = 3
    SLEEP_SECONDS = 0.5
    if is_nrfutil_running():
        sendImportantlog("nrf_util is running; attempting to terminate...")
        for attempt in range(1, MAX_ATTEMPTS + 1):
            kill_nrfutil_processes()
            time.sleep(SLEEP_SECONDS)

            if not is_nrfutil_running():
                sendImportantlog("nrf_util processes have been terminated.")
                break

            sendImportantlog(f"Attempt {attempt}/{MAX_ATTEMPTS} failed; nrf_util still running…")
        else:
            raise RuntimeError(
                f"Unable to terminate nrf_util after {MAX_ATTEMPTS} attempts. "
                "Check permissions or respawn settings."
            )
            # note: may be triggered sometimes, rewrite this code to avoid exiting script    
    
    # start ble capture and dump raw .pcap data
    pcap_file, timestamp = start_capture()
    
    # Convert the pcap file to CSV format
    extract_ble_data(pcap_file, timestamp)
        
    # Remove the pcap file after conversion
    os.remove(pcap_file)