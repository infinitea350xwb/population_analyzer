import json
import time
import requests
import logging
import sys
import socket
from global_variables import *
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
            print("result:", response.status_code)
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

# HTTP POST Handler for valuable logs.
http_handler = HTTPPostHandler(UrlOfLogServer)
http_handler.setFormatter(formatter)
logger.addHandler(http_handler)

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
    
    # Display log information.
    print(f"send log to logserver of {UrlOfLogServer}")
    print("send log: ")
    try:
        pretty_log = json.dumps(extra, indent=4)
        print(pretty_log)
    except Exception as e:
        print("Error pretty printing JSON:", e)
    
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
UrlOfsendImportantlog missing in the original code. Assuming it is the same as UrlOfLogServer
"""

UrlOfsendImportantlog = UrlOfLogServer

# HTTP POST Handler for important logs.
http_handler_imp = HTTPPostHandler(UrlOfsendImportantlog)
http_handler_imp.setFormatter(formatter_imp)
important_logger.addHandler(http_handler_imp)
 
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

    # Pretty print the JSON log.
    try:
        pretty_log = json.dumps(extra, indent=4)
        print(pretty_log)
    except Exception as e:
        print("Error pretty printing JSON:", e)

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