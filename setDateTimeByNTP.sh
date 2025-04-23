#!/bin/bash
SerialNo=2023092501

<< 'COMMENTOUT'
----
Change tracking
2023052101 1st based setDateTimeByNTP.sh
----
- Description:
  This file is a template for creating a script.

- Sub process: 
  nothing
  or 
-- *************************

----
- Setup

target=$dCProgramsSh/setDateTimeByNTP.sh; vi $target

or 

target=$dCProgramsSh/setDateTimeByNTP.sh; echo -n > $target;vi $target

target=$dCProgramsSh/setDateTimeByNTP.sh;chmod 755 $target; shc -r -v -f $target; rm $target.x.c

target=$dCProgramsSh/setDateTimeByNTP.sh; $target version

crontab -e
---
*/1 * * * * $dCProgramsSh/setDateTimeByNTP.sh.x
---

- UsageA
-- Standard
$target.x 

-- version
$target.x version

-- show log
$target.x showlog

-- test
$target.x version
$target.x
$target.x test
$target.x showlog


- References


----
COMMENTOUT

source /zelowa/client/programs/sh/common1.sh $0  # クライアント用設定ファイルを読み取り

msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
echo -e $msg | tee -a ${logfile}
echo $0 $@ | tee -a ${logfile}

# 待機時間
waitsec=120
dotype=0 # 待機時間前の場合は終了
# dotype=1 # 待機時間前の場合は待機時間までの待機して実行する
waitNsecSpendFromBoot

arg1=$1
arg2=$2

#flgDoDualCheck=0 # 0: 多重起動OK
flgDoDualCheck=1 # 1: 二重起動不可、後のを起動させない。Set to 1 if double activation is not allowed.
#flgDoDualCheck=2 # 2: 二重起動不可、前のを強制終了して後のを起動させる。

difftask(){
   # プログラム更新に伴う臨時処理を記入
   :
}

main(){
	# --- main process ---
   # 単独実行: $dCProgramsSh/setDateTimeByNTP.sh main
   msg="Start the main of "${thisfile} 
   echo $msg | tee -a ${logfile}
   
   if [ $flgDoDualCheck -eq 1 ];then
      IsRunning
   elif [ $flgDoDualCheck -eq 2 ];then
      trap "pkill -P $$" EXIT # 終了時にサブプロセスも一緒に落とすおまじない
      stop # 古いプロセスを一旦終了
   fi

   cat /etc/systemd/timesyncd.conf | grep -e "^NTP=ntp.tohoku.ac.jp" > /dev/null
   if [ $? -ne 0 ];then
      echo "NTP=ntp.tohoku.ac.jp" >> /etc/systemd/timesyncd.conf
   fi
   timedatectl timesync-status
   if [ $? -ne 0 ];then
      systemctl enable systemd-timesyncd
      systemctl restart systemd-timesyncd
      timedatectl timesync-status
   fi
}



case $1 in
   sendValuableLog)
      sendValuableLog $@
         ;;
   test)
      test $@
         ;;
   showps)
      showps $@
         ;;
   version)
      version $@
         ;;
   stop)
      stop $@
         ;;
   *)
      main $@
         ;;
esac
shrinkfile $logfile 100000 50000
echo "Finished of " $0 >> ${logfile}

