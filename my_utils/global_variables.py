import os
from datetime import datetime
import socket
import time
import subprocess
import sys

# Current version of this file
SerialNo_clientcgf = 2024041201
print("SerialNo_clientcgf:", SerialNo_clientcgf)

# Time information
"""
uptimeDate: OS起動時刻
uptimeDateUt: OS起動時刻のUnix時間
currentDateUt: 現在時刻のUnix時間
diffsec: OS起動からの経過時間 (elapsed seconds since OS startup)
"""
uptimeDate = subprocess.check_output(['/usr/bin/uptime', '-s']).decode().strip()
uptimeDateUt = int(datetime.strptime(uptimeDate, "%Y-%m-%d %H:%M:%S").timestamp())
currentDateUt = int(time.time())
diffsec = currentDateUt - uptimeDateUt

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

ble_database = "/tmp/ble.dump.0/ble_database.db"  # BLEデータベースの保存場所

filenameOfsendValuableLog=f"{dLcLog}/sendValuableLog.log"
filenameOfsendImportantLog=f"{dLcLog}/sendImportantLog.log"
lastdatefile = "/zelowa/lastOsTermDate" # lastOstermdate not created yet

"""
Note: not all directories are created on noble-quieter3c
"""

if len(sys.argv) > 1:
    preprocess = sys.argv[1]  # 呼び出し元プロセス
else:
    preprocess = "null"       # 呼び出し元プロセス

# name of process that called this script
thisfile = preprocess 

print(f"Preprocess: {preprocess}")

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