import pandas as pd
import socket
import logging
import os
import re
import time
from pythonjsonlogger import jsonlogger

# ----------------------------------------
# Macros
# -----------------------------------------
interval = 300.0

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
sendImportantlog("data_analysis script running")

# ------------------------------------------------------------
# Function to find the earliest file in the ble dump csv directory
# ------------------------------------------------------------
def find_earliest_file():
    """
    Find the earliest file in the specified directory.
    Returns:
    - Path to the earliest file or None if no files match.
    """
    from pathlib import Path
    from datetime import datetime

    folder = Path("/tmp/ble.dump.0/raw_csv")          # directory to scan
    pattern = re.compile(r"_(\d{8}_\d{6})\.csv$")     # captures 20250412_214844

    earliest_file   = None
    earliest_dt     = None

    for f in folder.glob("*.csv"):                    # or **/*.csv for sub‑dirs
        m = pattern.search(f.name)
        if not m:
            continue                                  # skip non‑matching files

        ts = datetime.strptime(m.group(1), "%Y%m%d_%H%M%S")

        if earliest_dt is None or ts < earliest_dt:
            earliest_dt  = ts
            earliest_file = f

    return earliest_file

# ------------------------------------------------------------
# Function to calculate weighted population movement
# ------------------------------------------------------------
import numpy as np

def calculate_weighted_population_movement(df):
    """
    Calculate the weighted population movement based on RSSI values.
    
    Parameters:
    - df (pd.DataFrame): DataFrame containing BLE data with 'rssi' and 'bdaddr' columns, recorded over an interval of 5 mins
    """
    # Ensure that 'rssi' is numeric
    df['rssi'] = pd.to_numeric(df['rssi'], errors='coerce')
    
    # Convert 'timestamp' to numeric (if needed), then to datetime in UTC
    df['datetime'] = pd.to_datetime(pd.to_numeric(df['timestamp']), unit='s', utc=True)

    # Convert to GMT+9 (JST)
    df['datetime'] = df['datetime'].dt.tz_convert('Asia/Tokyo')
    
    df = (
        df
        .groupby('bdaddr', as_index=False)
        .agg(first_seen=('datetime', 'min'),
            last_seen =('datetime', 'max'),
            rssi_min  = ('rssi',  'min'))
        .reset_index()
    )
    
    # Calculate the duration divided by interval only once
    weight = (df['last_seen'] - df['first_seen']).dt.total_seconds() / interval
    
    # Assign weighted_value: if already larger than 1 (meaning that it has stayed longer than the interval period), assign 1, else assign duration_ratio
    df['weighted_value'] = np.where(weight > 1, 1, weight)
    
    # Convert interval to minutes for time windowing
    interval_minutes = int(interval / 60)
    #freq_str = f"{interval_minutes}min"
    
    # Floor the datetime to the nearest interval window using 'min'
    df['time_window'] = df['first_seen'].dt.floor("5min")
    
    print("length of master df after merging", len(df))
    return df

# ------------------------------------------------------------
# Function for displaying filtered data (based on rssi)
# ------------------------------------------------------------
def rssi_filter(df, rssi_threshold):
    """
    Show rows whose rssi_min is above the given threshold
    without modifying the original DataFrame.
    """
    # Build a filtered copy
    filtered_df = df.loc[df['rssi_min'] > rssi_threshold].copy()
    return filtered_df  

# ------------------------------------------------------------
# Driver program
# ------------------------------------------------------------
def data_analysis():
    """
    Main function to perform data analysis on BLE data.
    """
    # Find the earliest file
    earliest_file = find_earliest_file()
    if earliest_file is None:
        sendImportantlog("No matching files found, waiting for next round")
        exit(0)
    else:
        sendImportantlog(f"Earliest file found, processing: , {earliest_file}")
        
    # Get the timestamp from the filename
    filename = os.path.basename(earliest_file)
    pattern = re.compile(r"_(\d{8}_\d{6})\.csv$")
    m = pattern.search(filename)
    if m:
        timestamp = m.group(1)
    
    # read the csv format the df
    df = pd.read_csv(earliest_file)   
    print(len(df))

    # Calculate weighted population movement
    df = calculate_weighted_population_movement(df)
    
    # Calculate raw 'flowing' number of devices captured (no weighting), and staying devices using weighted value
    devices_info = df.groupby('time_window').agg(
        flowing_devices=('bdaddr', 'size'),
        staying_value=('weighted_value', 'sum'),
        rssi_above_minus50=('rssi_min', lambda x: (x > -50).sum()),
        rssi_above_minus75=('rssi_min', lambda x: (x > -75).sum()),
        rssi_above_minus100=('rssi_min', lambda x: (x > -100).sum())
    )
    print("Number of detected devices at the moment:", devices_info)
    
    # Output the filtered data to a new CSV file
    output_dir = "/tmp/ble.dump.0/processed_data"
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, f"ble_{hostname}_{timestamp}.csv") 
    
    # output data csv file
    df.to_csv(output_file, index=False)
    
    sendImportantlog(f"Filtered data saved to {output_file}")
    
    # remove processed .csv file
    # os.remove(earliest_file)
    
data_analysis()