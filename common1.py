# Print the current version of this file
SerialNo_clientcgf = 2024041201
print("SerialNo_clientcgf:", SerialNo_clientcgf)

import os
from datetime import datetime
import socket
import sys

# Old settings, might be unused
cserver = "c001"
groupname = "g006"
timestamp = os.path.getmtime("/zelowa") # Get the modification time of "/zelowa" and format it as YYYYMMDD.
formatted_date = datetime.fromtimestamp(timestamp).strftime("%Y%m%d")
orign = "c" + formatted_date

# Server integration flag and identifier
flagUsingServer = 1  # サーバ連携の有無（1:有, その他:無（スタンドアローンモード））
genid = "g006"  # サーバ連携時のグループ識別子
getLatestInfoservername = "dpu.dais.cds.tohoku.ac.jp"
tgzservername = "dpu.dais.cds.tohoku.ac.jp"
backupservername = "dpu.dais.cds.tohoku.ac.jp"
tdagentservername = "dpu.dais.cds.tohoku.ac.jp"
ntpserver = "ntp.nict.jp"

# td-agentサーバのURL設定
hostname = socket.gethostname()
UrlOfLogServer = f"http://{tdagentservername}:8801/valuableLog/{hostname}"
UrlOfDeviceInfoJsonHttp = f"http://{tdagentservername}:8801/deviceInfo/{hostname}"
THINGSBOARD_HOST_NAME = "thingsboard2.dais.cds.tohoku.ac.jp"

# 受信ログなどのデータをローカルに残す最低期間（単位: 日）
maxRetentionDayPeriodOfData = 365

# ローカルpath関連情報
dBz = "/boot/zelowa"  # client.cfg や Wifi設定（wpa_supplicant.conf.hoge）等の起動時にアクセスしたい設定ファイルを置く。
dZc = "/zelowa/client"  # 全クライアント（ラズパイ）が共用するファイル群を保存するフォルダ
dZcR = f"{dZc}/ramdisk"  # RAMディスク
dCConfig = f"{dZc}/config"  # 共通設定ファイルなど
dCPrograms = f"{dZc}/programs"  # bashスクリプト用保存フォルダ
dCProgramsSh = f"{dZc}/programs/sh"  # bashスクリプト用保存フォルダ
dCProgramsPy = f"{dZc}/programs/py"  # pythonスクリプト用保存フォルダ

dZcx = "/zelowa/clientx"  # 個々のラズパイ端末毎の専用フォルダが作成されるフォルダ
dLocalClient = f"{dZcx}/{hostname}"  # 自端末の専用フォルダ
dLcLog = f"{dLocalClient}/log"  # システムログファイルの保存フォルダ
dLcData = f"{dLocalClient}/data"  # 受信ログなどのデータの保存フォルダ
dLcConfig = f"{dLocalClient}/config"  # 各種設定ファイルや鍵ファイルの保存フォルダ

dZs = "/zelowa/server"  # 全サーバの共通ディレクトリ
dSConfig = f"{dZs}/config"  # 共通設定ファイルなど
dSPrograms = f"{dZs}/programs"  # 各種プログラムの保存フォルダ
dSProgramsSh = f"{dZs}/programs/sh"  # bashスクリプト用保存フォルダ
dSProgramsPy = f"{dZs}/programs/py"  # pythonスクリプト用保存フォルダ

dZsx = "/zelowa/serverx"  # 個々のサーバ端末毎の専用フォルダが作成されるフォルダ
dLocalServer = f"{dZsx}/{hostname}"  # 自端末の専用フォルダ
dLsLog = f"{dLocalServer}/log"  # システムログファイルの保存フォルダ
dLsData = f"{dLocalServer}/data"  # 受信ログなどのデータの保存フォルダ
dLsConfig = f"{dLocalServer}/config"  # 各種設定ファイルや鍵ファイルの保存フォルダ

dzg = "/zelowa/git-repositories"
sourcedir = f"{dzg}/client-current"
gitConfigDir = f"{sourcedir}/config"

customfile = "/boot/zelowa/custom"
lastbeaconfile = "/tmp/lastbeacon"
datafile = f"{dLcData}/ble.transmit.log"

filenameOfsendValuableLog=f"{dLcLog}/sendValuableLog.log"

# Create soft links for the programs directory
def ensure_symlink(target, link_name):
    """Ensure that link_name exists as a symlink to target."""
    if not os.path.exists(link_name):
        try:
            os.symlink(target, link_name)
            print(f"Created symlink: {link_name} -> {target}")
        except OSError as e:
            print(f"Error creating symlink for {link_name}: {e}")
    else:
        print(f"Symlink or file already exists: {link_name}")

ensure_symlink("/bin/date", "/usr/bin/date")
ensure_symlink("/sbin/ifconfig", "/usr/sbin/ifconfig")
ensure_symlink("/sbin/iwconfig", "/usr/sbin/iwconfig")

# Update the PATH environment variable to include the programs directory
os.environ["PATH"] = os.environ.get("PATH", "") + os.pathsep + "/usr/sbin" + os.pathsep + dCProgramsSh + os.pathsep + dCProgramsPy

print("Updated PATH:", os.environ["PATH"])

import json
import time
import requests
import logging
import sys
import socket
from pythonjsonlogger import jsonlogger

# JSON formatter formats for different loggers.
valuable_json_format = '%(asctime)s %(levelname)s %(name)s %(unixtime)s %(hostname)s %(datelabel)s %(log)s'
important_json_format = '%(asctime)s %(levelname)s %(name)s %(datatype)s %(hostname)s %(currentDateUt)s %(currentDate)s %(thisfile)s %(msg)s'

# Define a common HTTP POST Handler to send log messages via HTTP POST.
class HTTPPostHandler(logging.Handler):
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
# Logger for Valuable Logs
# ----------------------------------------
logger = logging.getLogger("valuable_logger")
logger.setLevel(logging.DEBUG)

# StreamHandler for console output with JSON formatting.
stream_handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter(valuable_json_format)
stream_handler.setFormatter(formatter)
logger.addHandler(stream_handler)

# HTTP POST Handler for valuable logs.
http_handler = HTTPPostHandler(UrlOfLogServer)
http_handler.setFormatter(formatter)
logger.addHandler(http_handler)

# FileHandler for valuable logs.
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
# Logger for Important Logs
# ----------------------------------------
important_logger = logging.getLogger("important_logger")
important_logger.setLevel(logging.DEBUG)

# StreamHandler for console output with JSON formatting.
stream_handler_imp = logging.StreamHandler()
formatter_imp = jsonlogger.JsonFormatter(important_json_format)
stream_handler_imp.setFormatter(formatter_imp)
important_logger.addHandler(stream_handler_imp)

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
        "msg": msg
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
# Basic JSON Logger for Console Output
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

