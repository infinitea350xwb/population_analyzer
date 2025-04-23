#!/bin/bash
SerialNo=2024120301-2

<<"COMMENTOUT"
----
Change tracking
2023051901 tb-edgeとの連携を想定して再作成
2023052101 出力ファイル名にアクセスキー等を付ける
2023052102 jsonへの強制データ不要に対応
2023052103 mode情報を追加
2023052301 tb-edgeが未動作の場合、サーバに直接送信する
2023052302 modeの出力を修正
2023052501 pgrokstateを出力
2023060701 送信ログにアクセストークンを記載
2023060702 Mem_usedのチェック頻度を減らす
2023060801 cpu温度を測定する
2023062201 getnumOfFlowingBdaNMaxValues を追加
2023071001 MaxNumOfStayingBdaALLPer300 の取得方法を変更
2023081501 充電状態がpending-charge! でバッテリ残量が50%以下の場合は再起動
2023090101 充電状態がpending-charge! でバッテリ残量が10%以下で、起動後2時間以上経過の場合は再起動に変更。充電ゼロから再起動・給電中にrebootするのを回避するために。
2023090301 ReBoot.sh への対応: ex: $dCProgramsSh/ReBoot.sh $0 123 poweroff "hoge abc"
2023090501 LastBootInfo を取得 
2023090501-3 ReBoot.shで LastBootInfo を送信するので、ここでの処理をコメントアウトした
2023090601 ofono-sailfish のバージョンをホールドする
2023090602 SubscriberNumbersを取得
2023090701 tailscale_ipを取得
2023091501 末弟残量により再起動/停止のプロセスを単純化
2023092501 uptimesecとMaxNumOfFlowingBdaLastWeekNEARPer300を取得
2023110501 ThingsBoard Edgeのバージョン情報を取得する
2023111901 ofono-sailfish のバージョンをホールドをやめる。SI<が見えなくなる？
2023120401 getFiwareInfoを追加
2024031001 NumOfCPUOnline=$(cat /sys/devices/system/cpu/cpu*/online | grep "1" | wc -l)  の結果を確認
2024031501 tb-edgeを使用しない
2024032801 定期的にSIM情報を再取得する
2024040301 
2024042301 バッテリ状態charging_stateが「pending-charge」になり、起動後１時間以上経過の場合はreboot
2024052401 ibattleの契約情報を取得する
2024060301 fiwareの送信履歴を送信
2024072801 GhostnameDateなどを送信
2024080901 ble_majorを送信
2024090101 utTemperature の使用する温度を変更
2024120301 ibattleのAPI停止に伴う不具合を解消
----
- Description:
  Collect and show device information
  cronにより一定時間（１時間)毎に再起動。
  while true で繰り返し処理。

   ・毎回送信
      テレメトリ
     - 送信日時のunixtime: ts
     - 送信日時のラベル: currentDate

   ・値が変化した場合、または、*/Hour時に（直近に値の変化により送信済であっても）送信。
     [チェック頻度：*/Minute分、毎回チェックの場合は*]
      テレメトリ
     - uptimeDate: 起動日時
     - hostName
     - hostnametag
     - group
     - deviceid
     - placeID *
     - placeTag *
     - BdAddress
     - wlan0MacAddress
     - wlan1MacAddress
     - wlan0ip *
     - wlan1ip *
     - rmnet_data0ip
     - globalIP
     - essid *
     - defaultRoute *
     - priorityComChannel: 優先経路

     - imsi
     - apn

      # 通信量
     - txMB_celler_today
     - rxMB_celler_today
     - txMB_wlan0_today
     - rxMB_wlan0_today

     - txMB_celler_yesterday
     - rxMB_celler_yesterday
     - txMB_wlan0_yesterday
     - rxMB_wlan0_yesterday

     - pgrok_state *
     - pgrok_ports_ssh *
     - pgrok_ports_http *

     - customSetting
     - latitute
     - longitude
     - hardInfo
     - isServer
     - firmver
     - osInfo
     - TgzInfo *

     - battery_percentage  *
     - charging_state  *

     - Mem_total
     - Swap_total
     - Mem_used
     - Swap_used
     - useRateOfStorageBoot
     - useRateOfStorageRoot
     - useRateOfStorageZelowa
     - useRateOfStorageRoot
     - nGBSizOfStorageRoot
     - useRateOfStorageUserdata
     - nGBSizOfStorageUserdata
     - useRateOfStorageTmp
     - nGBSizOfStorageTmp

     - flow600_numOfFlowingBda_[3]  *
     - flow600_numOfStayingBda_[3] *
     - flow3600_numOfData  *
     - flow3600_numOfFlowingBda_[3]  *
     - flow3600_numOfStayingBda_[3] *

   ・*/Min分に送信
     - spendTime: 起動時間ラベル
     - NumOfBleRecievedLast10Mins: 過去10分間のビーコン観測量
     - LoadAverage[0-3]


   実現方法：
   ・あとで再現（再登録）できるように、tbに送信する全てのjsonデータにはタイムスタンプtsを付ける。
     また、アクセスキー、送信理由reason（changed, *時, *分など）と、成否resultの結果付けて、全てログ(Txt)に残す。
     また、td-agentでサーバにも送信してバックアップする。
     本番モード以外のデータは、別のデバイス（アクセスキー）で登録する。
   
   注意点：
   ・負荷低減の目的でEdgeの使用をやめる可能性がある。そのことに対応できること。
     => jsonデータをtxt形式でサーバにバックアップしておけば、サーバに処理を代行できる？
   ・flow**などのビーコンに関する情報は、ここでは発信しない。
----
- Setup

target=$dCProgramsSh/getDeviceInfo2_u.sh; vi $target

or 

target=$dCProgramsSh/getDeviceInfo2_u.sh; echo -n > $target;vi $target

target=$dCProgramsSh/getDeviceInfo2_u.sh;chmod 755 $target; shc -r -v -f $target; rm $target.x.c

crontab -e
---
# 1分毎にデバイス情報を確認
@reboot  sleep 1m && nice $dCProgramsSh/getDeviceInfo2_u.sh
*/5 * * * * nice $dCProgramsSh/getDeviceInfo2_u.sh
1-4,6-9,11-14,16-19,21-24,26-29,31-34,36-39,41-44,46-49,51-54,56-59 * * * * nice $dCProgramsSh/getDeviceInfo2_u.sh lite
---

- Usage
-- Standard
$target.x 

-- version
$target.x version

----
COMMENTOUT
source /zelowa/client/programs/sh/common1.sh $0  # クライアント用設定ファイルを読み取り

msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"

logfile=${0}.log
echo "logfile: "${logfile} | tee -a ${logfile}

echo -e $msg | tee -a ${logfile}
echo $0 $@ | tee -a ${logfile}

# 待機時間
waitsec=10
# dotype=0 # 待機時間前の場合は終了
dotype=1 # 待機時間前の場合は待機時間までの待機して実行する
waitNsecSpendFromBoot

numArgs=$#
arg1=$1
arg2=$2
arg3=$3


trap "pkill -P $$" EXIT # 終了時にサブプロセスも一緒に落とすおまじない
#flgDoDualCheck=0 # 0: 多重起動OK
flgDoDualCheck=1 # 1: 二重起動不可、後のを起動させない。Set to 1 if double activation is not allowed.
#flgDoDualCheck=2 # 2: 二重起動不可、前のを強制終了して後のを起動させる。

# For MQTT
if [ ! -f /usr/bin/mosquitto_pub ];then
   echo "start to install mosquitto-clients" | tee -a ${logfile}
   apt-get update -y
   apt-get install -y mosquitto-clients
   echo "do: which mosquitto_pub"  | tee -a ${logfile}
      which mosquitto_pub | tee -a ${logfile}
fi
ACCESS_TOKEN=$(hostname | sed -e "s/^.*-//")
THINGSBOARD_HOST_NAME=thingsboard2.dais.cds.tohoku.ac.jp
THINGSBOARD_PORT=1883  # MQTT

mypsid=$$ # 自身のプロセスID

jsonfile=${dLcData}/deviceInfo2.${ACCESS_TOKEN}.json
jsonfile2tb=${dLcData}/deviceInfo2.json

MinIntervarlSec=10 # while loop の最小インターバル

lastRecordDir=/tmp/$(basename $0)
echo "lastRecordDir="$lastRecordDir
mkdir -p $lastRecordDir


MinIntervalHour=1 # 必ず送信する時間間隔（*/MinIntervalHour）時
LastUtOfMinIntervalHour=$(cat ${lastRecordDir}/LastUtOfMinIntervalHour) # 最後に送信したHour
echo "LastUtOfMinIntervalHour=$LastUtOfMinIntervalHour"
#exit 0

MinIntervalMinute=5 # 必ず送信する時間間隔（*/MinIntervalMinute)分 
LastUtOfMinIntervalMinute=$(cat ${lastRecordDir}/LastUtOfMinIntervalMinute) # 最後に送信したMinute
echo "LastUtOfMinIntervalMinute=$LastUtOfMinIntervalMinute"

currentDateUt=$(date +%s)
isChangeOrPerNHour=0; # 1ならば、値の変化の有無に関わらず全て再登録（送信）する

echo "SerialNo: ${SerialNo}" | tee -a ${logfile}  
echo "mypsid: ${mypsid}" | tee -a ${logfile}  

chmod 777 /boot/zelowa/custom

# 臨時
#apt list ofono-sailfish -a  2> /dev/null | grep installed | grep 20230605130914 > /dev/null
#if [ $? -ne 0 ];then
#    apt update
#    yes | apt install ofono-ril-binder-plugin=1.2.6-0ubports4+0~20221207170500.2+ubports20.04~1.gbpa3c4bd ofono-ril-plugin=1.0.4-1+0~20220728170912.11~1.gbp868831 ofono-sailfish=1.29+git7-0ubports1~20230414181414.5~1ce165f+ubports20.04 ofono-sailfish-scripts=1.29+git7-0ubports1~20230414181414.5~1ce165f+ubports20.04
#    apt-mark hold ofono-sailfish
#fi


## jsonfile=${dLcData}/deviceInfo2.${ACCESS_TOKEN}.json
## jsonfile2tb=${dLcData}/deviceInfo2.json


shrinkfile ${jsonfile2tb} 100000 50000
shrinkfile ${jsonfile2tb}.failed.log 10000 5000

main(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh [once]
	# --- main process ---
   msg="Start the main of "${thisfile} $@
   echo $msg | tee -a ${logfile}

   [ "$1" == "once" ] && isChangeOrPerNHour=1

   # 直近の送信タイミング
   preDateDay=0
   preDateHour=0
   preDateMinute=0

   # thingsboardサーバから最新の属性情報を取得
   $dCProgramsSh/thingsboardset_x86.sh getAttributeAll

   while true;do
      sleep ${MinIntervarlSec}

      currentDateUt=$(date +%s)
   	currentDateDay=$(date "+%-d" --date @${currentDateUt})
	   currentDateHour=$(date "+%-H" --date @${currentDateUt})
	   currentDateMinute=$(date "+%-M" --date @${currentDateUt})
	   currentDateSec=$(date "+%-S" --date @${currentDateUt})

      # - 送信日時のunixtime: ts[msec]
      ts=${currentDateUt}000 # 送信日時のunixtime[msec]
      #echo "ts: "${ts}

      # - 送信日時のラベル: currentDate
      currentDate=$(date -d @${currentDateUt} "+%Y-%m-%d %H:%M:%S")
      echo "currentDate: "${currentDate}

      diffMinIntervalMinute=$((currentDateMinute % MinIntervalMinute))
      if [ ${diffMinIntervalMinute} -eq 0 ] && [ "${currentDateMinute}" != "${LastUtOfMinIntervalMinute}" ];then
         LastUtOfMinIntervalMinute=${currentDateMinute}
         echo ${currentDateMinute} > ${lastRecordDir}/LastUtOfMinIntervalMinute # 最後に送信したMinute

         # thingsboardサーバから最新の属性情報を取得
         $dCProgramsSh/thingsboardset.sh getAttributeAll

         echo "send Per N Minute"
         sendtype=A
         jsondata=$(PerNMinute)
         if [ -n "$jsondata" ];then
            #echo "nomarl jsondata :"$jsondata | tee -a $logfile
            type=currentDate
            result=${currentDate}
            [ -z "$result" ] && result="-1"
            jsondata=$(setDataToJsonAsTxtForcely $type "$result" "$jsondata")
            #echo "add ${type}, ${result} :"$jsondata | tee -a $logfile

            jsondata2="{\"ts\":${ts},\"values\":${jsondata}}"
            #echo "jsondata2: "$jsondata2  | tee -a $logfile

            echo $jsondata2 | grep currentDate
            if [ $? -ne 0 ];then
               echo "Fail in 249" >> ${logfile} 
               echo "currentDate: "$currentDate >> ${logfile} 
               echo "jsondata2: "$jsondata2 >> ${logfile} 
               continue
            fi

            sendts=$(date +%s)000 # 送信日時のunixtime[msec]
            echo "do: mosquitto_pub -d -q 1 -h \"${THINGSBOARD_HOST_NAME}\" -p \"${THINGSBOARD_PORT}\" -t \"v1/devices/me/telemetry\" -u \"${ACCESS_TOKEN}\" -m \"${jsondata2}\"" | tee -a ${logfile}
            resultOfMqtt=$(mosquitto_pub -d -q 1 -h "${THINGSBOARD_HOST_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN}" -m "${jsondata2}"  2>&1 )
            #echo "resultOfMqtt: "${resultOfMqtt}
            result0=$?

            echo ${resultOfMqtt} | grep -e "Connection Refused" -e "Error"
            result1=$?

            if [ $result0 -ne 0 ] || [ $result1 -ne 1 ] ;then
                  # 失敗
                  echo "Failed"
                  result=1
                  echo -e "${result}\t${jsondata2}" >> ${jsonfile2tb}.failed
            else 
                  # 成功
                  echo "Success"
                  result=0
            fi

            echo -e "${result}\t${jsondata2}" >> ${jsonfile2tb}
            echo ${jsondata2} >> ${jsonfile}
         fi
      fi

#      MinIntervalHour=5

      diffMinIntervalHour=$((currentDateHour % MinIntervalHour))
      echo "currentDateHour=$currentDateHour"
      echo "MinIntervalHour=$MinIntervalHour"
      echo "diffMinIntervalHour=$diffMinIntervalHour"
      echo "LastUtOfMinIntervalHour=$LastUtOfMinIntervalHour"

      if [ ${diffMinIntervalHour} -eq 0 ] && [ "${currentDateHour}" != "${LastUtOfMinIntervalHour}" ];then
         LastUtOfMinIntervalHour=${currentDateHour}
         echo ${currentDateHour} > ${lastRecordDir}/LastUtOfMinIntervalHour # 最後に送信したHour

         echo "do: ifValuesChangeOrPerNHour as all"
         if [ "$1" == "once" ];then
            sendtype=b
         else
            sendtype=B
         fi
         isChangeOrPerNHour=1; # 1ならば、値の変化の有無に関わらず全て再登録（送信）する

         # N時間１回はSIM情報を再取得する
         #/usr/share/ofono/scripts/list-modems > /tmp/boot_u.sh/list-modems
      else
         if [ "$1" == "once" ];then
            sendtype=d
            isChangeOrPerNHour=1; # 1ならば、値の変化の有無に関わらず全て再登録（送信）する
         else
            sendtype=D
            isChangeOrPerNHour=0; # 1以外ならば、差分のみ再登録（送信）する
         fi
      fi
      echo "isChangeOrPerNHour=$isChangeOrPerNHour"

      ### 値が変化した場合、または、*/H時間毎に（直近に値の変化により送信済であっても）送信

      jsondata=$(ifValuesChangeOrPerNHour) #   値が変化した場合、または、*/6時間毎に送信。

      if [ -n "$jsondata" ];then
         #echo "nomarl jsondata :"$jsondata | tee -a $logfile
         type=currentDate
         result=${currentDate}
         [ -z "$result" ] && result="-1"
         jsondata=$(setDataToJsonAsTxtForcely $type "$result" "$jsondata")
         #echo "add ${type}, ${result} :"$jsondata | tee -a $logfile

         jsondata2="{\"ts\":${ts},\"values\":${jsondata}}"
         #echo "jsondata2: "$jsondata2  | tee -a $logfile

         echo $jsondata2 | grep currentDate
         if [ $? -ne 0 ];then
            echo "Fail in 295" >> ${logfile} 
            echo "currentDate: "$currentDate >> ${logfile} 
            echo "jsondata2: "$jsondata2 >> ${logfile} 
            continue
         fi
         echo "do: mosquitto_pub -d -q 1 -h \"${THINGSBOARD_HOST_NAME}\" -p \"${THINGSBOARD_PORT}\" -t \"v1/devices/me/telemetry\" -u \"${ACCESS_TOKEN}\" -m \"${jsondata2}\""
         resultOfMqtt=$(mosquitto_pub -d -q 1 -h "${THINGSBOARD_HOST_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN}" -m "${jsondata2}" 2>&1 )
         #echo "resultOfMqtt: "${resultOfMqtt}
         echo $resultOfMqtt | grep -e "Connection Refused" -e "Error"
         result=$?
         if [ "$result" -eq 0 ];then
            # 失敗
            sendts=$(date +%s)000 # 送信日時のunixtime[msec]
            echo -e "${sendts}\t${jsondata2}" >> ${jsonfile}.faile
            #exit 0
         fi
         echo ${jsondata2} >> ${jsonfile}
      fi

   done

   msg="End the main of "${thisfile}    
   echo $msg | tee -a ${logfile}
}


changeOldlog2New(){
     # 単独実行:chmod 755 $dCProgramsSh/getDeviceInfo2_u-sp.sh; 
     # $dCProgramsSh/getDeviceInfo2_u-sp.sh changeOldlog2New [100]

      maxlines=$2
      [ -z "$maxlines" ] && maxlines=-1

      echo "maxlines=$maxlines"

      jsonfile2tbOld=${jsonfile}
      echo -n > ${jsonfile2tb}
      echo -n > ${jsonfile2tb}.failed
      echo -n > ${jsonfile2tb}.failed.log

      if [ -f $jsonfile2tbOld ];then

         if  [ $maxlines -gt 0 ];then
            cat ${jsonfile2tbOld} | grep uptimeDate | tail -n $maxlines > /tmp/changeOldlog2New.tmp
         else
            cat ${jsonfile2tbOld} | grep uptimeDate > /tmp/changeOldlog2New.tmp         
         fi

         while read LINE
         do
#            echo $LINE
            result=$(echo $LINE | cut -c 1)
            if [ $result == "{" ];then
               echo $LINE | grep "fail"
               if [ $? -eq 0 ];then
                  result=1 # 失敗
               else
                  result=0
               fi
            fi
            jsondata=$(echo $LINE | sed -e "s@^.*{\"ts@{\"ts@")
            #echo "result="$result
            #echo $jsondata
#            echo "result="${result}
            echo -e "${result}\t${jsondata}" >> ${jsonfile2tb}
         done <  /tmp/changeOldlog2New.tmp         
      fi
      cat ${jsonfile2tb} | egrep -e "^1" -e "^3" >>  ${jsonfile2tb}.failed
      wc -l ${jsonfile2tb}.failed

      rm  /tmp/changeOldlog2New.tmp
}

resendFailed2TB(){
     # 単独実行:  $dCProgramsSh/getDeviceInfo2_u-sp.sh resendFailed2TB
     logfile2=${jsonfile2tb}.failed.log
     
     msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
     echo -e $msg | tee -a ${logfile2}

     
     if [ ! -f ${jsonfile2tb}.failed ];then
          echo "no failed data: "$jsonfile2tb  | tee -a ${logfile2}
          return 0
     else
         echo "jsonfile2tb.failed="${jsonfile2tb}.failed
         while read LINE
         do
            echo $LINE | tee -a ${logfile2}
            # コマンド
            jsondata0=$(echo $LINE | sed -e "s@^.*{\"ts@{\"ts@")
               
            group0=$(echo $jsondata0 | jq .values.group)
            placeID0=$(echo $jsondata0 | jq .values.placeID)
            #echo group0=$group0
            #echo placeID0=$placeID0
            if [ "$group0" != "$group" ] || [ "$placeID0" != "$placeID" ];then
               echo "skip sicne group or placedID are changed!" | tee -a ${logfile2}
               sed -i "/$LINE/d" ${jsonfile2tb}.failed
               continue
            fi

            ACCESS_TOKEN0=$(hostname | sed -e "s/focal-//")
            #echo "ACCESS_TOKEN0="$ACCESS_TOKEN0
            #value=$(echo $LINE | awk '{print $6}')
            #echo $LINE | awk '{print $6}'
            #echo "jsondata0="$jsondata0

            #echo "THINGSBOARD_HOST_NAME="$THINGSBOARD_HOST_NAME
            #echo "ACCESS_TOKEN0="$ACCESS_TOKEN0
            #echo "THINGSBOARD_PORT="$THINGSBOARD_PORT
            #echo "jsondata0='"$jsondata0"'"
            echo 'do: mosquitto_pub -d -q 1 -h "${THINGSBOARD_HOST_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN0}" -m "${jsondata0}"'  | tee -a ${logfile2}
     
            resultOfMqtt=$(mosquitto_pub -d -q 1 -h "${THINGSBOARD_HOST_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN0}" -m "${jsondata0}" 2>&1 )

            result0=$?

            echo ${resultOfMqtt} | grep -e "Connection Refused" -e "Error"
            result1=$?

            if [ $result0 -ne 0 ] || [ $result1 -ne 1 ] ;then
                  # 失敗
                  result=1
                  echo -e "${resultOfMqtt}"  | tee -a ${logfile2}
                  echo "Failed"  | tee -a ${logfile2}
            else 
                  # 成功
                  echo "Success"
                  result=0
                  sed -i "/^$LINE/d" ${jsonfile2tb}.failed 
                  echo -e "0\t${jsondata0}" | tee -a ${jsonfile2tb}
            fi
         done <  ${jsonfile2tb}.failed 
     fi

     msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] finished: $0 $@"
     echo -e $msg | tee -a ${logfile2}

}



keepalive(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh keepalive
   # 直近動作から*秒以内の送信ログがある場合は、既存プロセスが動作中と考えて、以後の動作を中止
   echo "do: keepalive"
   thsec=240
   echo  jsonfile=${jsonfile}
   lastUt=$(tail -n 1 ${jsonfile} | sed -e "s/^.*,{/{/" | jq -c .ts | sed -e "s/000$//")
   spentSecFromLastUt=$((currentDateUt - lastUt))
   echo "spentSecFromLastUt: "${spentSecFromLastUt}
   if [ ${spentSecFromLastUt} -lt ${thsec} ];then
      echo "exit 0 since spentSecFromLastUt:$spentSecFromLastUt is less than ${thsec}" | tee -a ${logfile}
      exit 0   
   fi
}

setDataToJsonAsTxtForcely(){
   # 使い方：   jsondata=$(setDataToJsonAsTxtForcely $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
#   echo "changed!" >> ${logfile}
   echo "${result}" > ${lastRecordDir}/${type}
   jsoncore="\"${type}\":\"${result}\""

   if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
      jsondata="{${jsoncore}}"
   else
      jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
   fi
   echo ${jsondata}
}

setDataToJsonAsNumForcely(){
   # 使い方：   jsondata=$(setDataToJsonAsNumForcely $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
#   echo "changed!" >> ${logfile}
   echo "${result}" > ${lastRecordDir}/${type}
   jsoncore="\"${type}\":${result}"

   if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
      jsondata="{${jsoncore}}"
   else
      jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
   fi
   echo ${jsondata}
}


setJsonToJsonAsTxt2(){
   # txt形式のデータをjsonデータとして登録・作成する
   # 使い方：  setJsonToJsonAsTxt $key "$value" "$jsondata"
   # jsonデータを登録した「$jsondata」の変数に、テキスト形式のデータ「$value」を、key「$key」で追加登録して出力する。
   
   key=$1
   value=$2
   jsondata=$3
   #echo "key: "$key
   #echo "value: "$value
   #echo "jsondata: "$jsondata
   jsoncore="\"${key}\":\"${value}\""

   if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
      jsondata="{${jsoncore}}"
   else
      jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
   fi
   echo ${jsondata}
}

setJsonToJsonAsJsonOrNumOrNull(){
   # 数字形式のデータをjsonデータとして登録・作成する
   # 使い方：  setJsonToJsonAsTxt $key "$value" "$jsondata"
   # jsonデータを登録した「$jsondata」の変数に、数字形式のデータ「$value」を、key「$key」で追加登録して出力する。

   key=$1
   value=$2
   jsondata=$3
   #echo "key: "$key
   #echo "value: "$value
   #echo "jsondata: "$jsondata
   jsoncore="\"${key}\":${value}"

   if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
      jsondata="{${jsoncore}}"
   else
      jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
   fi

   echo ${jsondata}
}

setJsonToJsonAsTxt(){
   # 使い方：   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
#   echo "type="$type
#   echo "result="$result
#   echo "jsondata="$jsondata
#   echo "isChangeOrPerNHour: "$isChangeOrPerNHour
   lastResult=$(cat ${lastRecordDir}/${type} 2> /dev/null)
#   echo "lastResult=$lastResult"
   [ -z "$isChangeOrPerNHour" ] && isChangeOrPerNHour=1
#   echo "isChangeOrPerNHour=$isChangeOrPerNHour"

   if [ $isChangeOrPerNHour -eq 1 ] || [ "${lastResult}" != "$result" ] ;then
#   if [ "${lastResult}" != "$result" ] ;then
#      echo "changed!"
      echo "${result}" > ${lastRecordDir}/${type}
      jsoncore="\"${type}\":\"${result}\""

      if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
         jsondata="{${jsoncore}}"
      else
         jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
      fi
#   else
#      echo "No-changed!"
   fi
   echo ${jsondata}
}

setJsonToJsonAsNum(){
   # 使い方：   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
   #echo "type: "$type  > /tmp/setJsonToJsonAsNum
   #echo "result: "$result  > /tmp/setJsonToJsonAsNum
   #echo "jsondata: "$jsondata  > /tmp/setJsonToJsonAsNum
   lastResult=$(cat ${lastRecordDir}/${type} 2> /dev/null)
   if [ $isChangeOrPerNHour -eq 1 ] || [ "${lastResult}" != "$result" ] ;then
      echo "changed!" >> ${logfile}
      echo "${result}" > ${lastRecordDir}/${type}
      jsoncore="\"${type}\":${result}"

      if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
         jsondata="{${jsoncore}}"
      else
         jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
      fi
   else
      echo "No-changed!" > /tmp/setJsonToJsonAsNum
   fi
   echo ${jsondata}
}

setJsonToJsonAsTxtForce(){
   # 変化がなくてもjsondataに追加する
   # 使い方：   jsondata=$(setJsonToJsonAsTxtForce $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
   #echo "type: "$type
   #echo "result: "$result
   #echo "jsondata: "$jsondata
   lastResult=$(cat ${lastRecordDir}/${type} 2> /dev/null)
   echo "${result}" > ${lastRecordDir}/${type}
   jsoncore="\"${type}\":\"${result}\""

   if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
      jsondata="{${jsoncore}}"
   else
      jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
   fi
   echo ${jsondata}
}

setJsonToJsonAsNumForce(){
   # 変化がなくてもjsondataに追加する
   # 使い方：   jsondata=$(setJsonToJsonAsNumForce $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
   #echo "type: "$type  > /tmp/setJsonToJsonAsNum
   #echo "result: "$result  > /tmp/setJsonToJsonAsNum
   #echo "jsondata: "$jsondata  > /tmp/setJsonToJsonAsNum
   lastResult=$(cat ${lastRecordDir}/${type} 2> /dev/null)
   echo "${result}" > ${lastRecordDir}/${type}
   jsoncore="\"${type}\":${result}"

   if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
      jsondata="{${jsoncore}}"
   else
      jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
   fi
   echo ${jsondata}
}

PerNMinute(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh PerNMinute [debug]
   debug=$2

   # 値が変化した場合、または、MinIntervalMinute(=5)分毎に送信。
   
   jsondata=""

   type=LoadAverage0
   result=$(uptime | sed 's/^.*average: //' | awk -F", " '{ print $1 }');
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=LoadAverage1
   result=$(uptime | sed 's/^.*average: //' | awk -F", " '{ print $2 }');
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=LoadAverage2
   result=$(uptime | sed 's/^.*average: //' | awk -F", " '{ print $3 }');
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   # Memory
   memorystate=$(free -m | grep Mem) 
   
   type=Mem_total
   result=$(echo $memorystate | awk -F" "  '{ print $2 }' | sed 's/^ *\| *$//')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=Mem_used
   result=$(echo $memorystate | awk -F" "  '{ print $3 }' | sed 's/^ *\| *$//')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=Mem_free
   result=$(echo $memorystate | awk -F" "  '{ print $4 }' | sed 's/^ *\| *$//')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi


   swapstate=$(free -m | grep Swap) 

   type=Swap_total
   result=$(echo $swapstate | awk -F" "  '{ print $2 }' | sed 's/^ *\| *$//')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi


   type=Swap_used
   result=$(echo $swapstate | awk -F" "  '{ print $3 }' | sed 's/^ *\| *$//')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi


   type=Swap_free
   result=$(echo $swapstate | awk -F" "  '{ print $4 }' | sed 's/^ *\| *$//')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi


   type=NumOfBleRecievedLast10Mins
   result=$(sqlite3 ${dLcData}/ble.c1.db "select count(*) from blecap where dateut > (${currentDateUt} - 600);")
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=NumOfDistinctBleRecievedLast10Mins
   result=$(sqlite3 ${dLcData}/ble.c1.db "select count(distinct bdaddr) from blecap where dateut > (${currentDateUt} - 600);")
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=utTemperature 
#   result=$(cat /sys/class/hwmon/hwmon0/temp?_input)
   result=$(cat /sys/class/thermal/thermal_zone34/temp)
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=uptimeSec 
   result=$(cat /proc/uptime | awk '{print $1}' | sed s/\.[0-9,]*$//)
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi


   #echo "-----"
   #echo $jsondata | jq -c .
   #echo "-----"

   [ -n "$jsondata" ] && echo $jsondata | jq -c . | tee -a /tmp/$(basename $0)/lastjson.PerNMinute
   shrinkfile /tmp/$(basename $0)/lastjson.PerNMinute 100 50 > /dev/null
   #echo "-----"
}

ifValuesChangeOrPerNHour(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh ifValuesChangeOrPerNHour debug

   # 値が変化した場合、または、*/6時間毎に送信。
   
   [ "$2" == "debug" ] && isChangeOrPerNHour=1

   jsondata=""

   #  - uptimeDate: 起動日時
   type=uptimeDate
   result=$(uptime -s)
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
#   echo "jsondata=$jsondata"
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c . 
   
   type=hostName
   result=$(hostname)
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
#   echo "jsondata=$jsondata"
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

#   isChangeOrPerNHour=1
#   echo jsondata=$jsondata 

#   type=LastBootInfo
#   result=$(getLastBootInfo)
#   [ -z "$result" ] && result="Null"
#   [ "$2" == "debug" ] && echo "${type}: "$result
#   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
#   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

#   type=hostnametag
#   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
#   [ -z "$result" ] && result="Null"
#   [ "$2" == "debug" ] && echo "${type}: "$result
#   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
#   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=group
   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=deviceid
#   wlan0MacAddress=$(ifconfig | grep wlx | sed -e "s/:.*$//" | sed -e "s/wlx//")
   lastwlx=$(ifconfig | grep "wl"  | tail -n 1)
   wlan0MacAddress=$(ifconfig | grep "$lastwlx" -A10 | grep "ether " | sed -e "s/^.*ether //" | sed -e "s/txqueuelen.*$//" | sed -e "s/ //g" | sed -e "s/://g")

   # echo $wlan0MacAddress
   result=${wlan0MacAddress}
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .| tee /tmp/$(basename $0)/lastjson.$1.$type


   type=placeID
   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .


   type=placeTag
   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=mode
   result=$(cat /boot/zelowa/custom | grep -e "^stateOfStage" | awk '{print $2}')
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=BdAddress
   result=$(hciconfig -a | grep "BD Address" | sed "s/  ACL.*$//g"| sed "s/^.*BD Address: //g" | sed "s/://g"| tr '[A-Z]' '[a-z]')
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=wlan0MacAddress
#   result=$(ifconfig | grep wlx | sed -e "s/:.*$//" | sed -e "s/wlx//")
   lastwlx=$(ifconfig | grep "wl"  | tail -n 1)
   result=$(ifconfig | grep "$lastwlx" -A10 | grep "ether " | sed -e "s/^.*ether //" | sed -e "s/txqueuelen.*$//" | sed -e "s/ //g" | sed -e "s/://g")

   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=wlan0ip
   result=$(ifconfig | grep wlx  -A 100 | grep inet | grep -v "inet6" | sed -e "s/netmask.*$//"| sed -e "s/^.*inet //")
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=globalIP
   result=$(curl -s inet-ip.info 2> /dev/null)
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=essid
   wlxid=$(ifconfig | grep wlx | sed -e "s/:.*$//" | sed -e "s/wlx//")
   result=$(iwconfig wlx${wlxid} | grep ESSID  | sed -e "s/^.*ESSID:\"//g" | sed -e 's/".*$//g')
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=defaultRoute
   result=$(/sbin/route | grep default  | head -n 3 | awk '{print $8"_"$2}')
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=tailscale_ip
   result=$(ifconfig tailscale0 | grep -v "inet6" | grep "inet" | awk {'print $2'})
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=customSetting
   result=$(cat /boot/zelowa/custom | sed -e "s/#.*$//g" | grep -v ^$ | sed -z 's/\n/<br>/g; s/$/\n/'  | sed -e "s/\s*<br>$//" | sed -e "s/\s*<br>/<br>/g")
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   # position
   posInfo=$(curl -s http://ip-api.com/csv/$globalIP?fields=status,zip,lat,lon 2> /dev/null | sed "s/fail/0000000,0.0,0.0/g" | sed "s/success,//g"| sed "s/-//g");
   zip=$(echo $posInfo | cut -d "," -f 1)
   latitute=$(echo $posInfo | cut -d "," -f 2)
   longitude=$(echo $posInfo | cut -d "," -f 3)

   type=latitute
   result=${latitute}
   [ -z "$result" ] && result="0"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=longitude
   result=${longitude}
   [ -z "$result" ] && result="0"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=isServer
   cat /boot/zelowa/custom | egrep -e "^server" &> /dev/null
   if [ $? -eq 0 ];then
      isServer="server"
   else
      isServer="client"
   fi
   result=${isServer}
   [ -z "$result" ] && result="null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=firmver
   result=$(uname -a | awk '{print $3}')
   [ -z "$result" ] && result="null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=osInfo
   result=$( cat /etc/os-release | strings |grep "PRETTY_NAME"| sed 's/^PRETTY_NAME="//g'| sed 's/"$//g'|sed 's/)"$/)/g' |sed 's@GNU/Linux @@g')
   [ -z "$result" ] && result="null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=TgzInfo
   result=$(basename $(ls /zelowa/git-repositories/client-current/tgz.version.*)| sed -e "s/tgz.version.//" )
   [ -z "$result" ] && result="null"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=FiwareID2023
   if [ -f /tmp/myfiwareid ];then
      result=$(cat /tmp/myfiwareid)
      jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   fi

   type=ble_major
   result=$($dCProgramsSh/transmitBleBeacon.sh getmajor | tail -n 1 | sed -e 's/[^0-9]//g')
   [ -z "$result" ] && result="-1"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .
   ble_major=${result}

   spendsec=$(cat /proc/uptime | awk '{printf("%d\n",$1)}')
   result=$(/usr/bin/upower -i /org/freedesktop/UPower/devices/battery_battery | grep state | grep charg | awk '{print $2}')

   if [ "$1" == "once" ];then
      echo "do: exit0 since \$1 is once" | tee -a ${logfile} 
      exit 0
   fi

   # ストレージ使用量
   type=useRateOfStorageRoot
   result=$(df -h / | tail -1 | awk '{print $5}' | sed -e 's/[^0-9.]//g')
   [ -z "$result" ] && result="-1"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=nGBSizOfStorageRoot
   result=$(df -h / | tail -1  | awk '{print $2}' | sed -e 's/[^0-9.]//g')
   [ -z "$result" ] && result="-1"
   [ "$2" == "debug" ] && echo "${type}: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   numOfCPUonlineBefore=$(cat /sys/devices/system/cpu/cpu*/online  | grep "^1" | wc -l)

   type=FiwareUploadDate300
   result0=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.300.log| awk '{print $1}' | sed -e "s/-/ /")
   #echo "result0="$result0
   result=$(date "+%Y%m%d%H%M" --date "$result0")
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadValueDateObservedFrom300
   result0=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.300.log| awk '{print $3}' | jq -r .dateObservedFrom.value)
   #echo "result0="$result0
   result=$(date "+%Y%m%d%H%M" --date $result0)
   #echo "result="$result
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadValueDateObservedFrom300ut
   result0=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.300.log| awk '{print $3}' | jq -r .dateObservedFrom.value)
   #echo "result0="$result0
   result=$(date "+%s" --date $result0)
   #echo "result="$result
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadValuepeopleCountFar300
   result=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.300.log| awk '{print $3}' | jq .peopleCount_far.value)
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadResult300
   result=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.300.log| awk '{print $2}')
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadDate3600
   result0=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.3600.log| awk '{print $1}' | sed -e "s/-/ /")
   #echo "result0="$result0
   result=$(date "+%Y%m%d%H%M" --date "$result0")
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadValueDateObservedFrom3600
   result0=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.3600.log| awk '{print $3}' | jq -r .dateObservedFrom.value)
   #echo "result0="$result0
   result=$(date "+%Y%m%d%H%M" --date $result0)
   #echo "result="$result
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi

   type=FiwareUploadValuepeopleCountFar3600
   result=$(tail -n 1 ${dLcData}/fiwareUploadSendai2023.3600.log| awk '{print $3}' | jq .peopleCount_far.value)
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   if [ "$2" == "debug" ];then
      echo "type: "$type
      echo "result: "$result
      echo "jsondata: "$jsondata
      echo $jsondata | jq -c .
   fi



   [ -n "$jsondata" ] && echo $jsondata | jq -c . | tee -a /tmp/$(basename $0)/lastjson.ifValuesChangeOrPerNHour
   shrinkfile /tmp/$(basename $0)/lastjson.ifValuesChangeOrPerNHour 100 50  > /dev/null



   #  - flow300_numOfData  *
   #tail -n 1 ble.graph.json.300 | jq -c .

   #  - flow300_numOfFlowingBda_[3]  *
   #  - flow3600_numOfData  *
   #  - flow600_numOfStayingBda_[3] *
   #  - flow3600_numOfFlowingBda_[3]  *
   #  - flow3600_numOfStayingBda_[3] *
}

getPgorokStatus(){
   pgrok_ports=$(curl -m 2  127.0.0.1:14040/http/in 2> /dev/null| grep -e "relay[0-9][0-9].dais.cds.tohoku.ac.jp" |  sed -e "s@^.*JSON.parse(\"@@" | sed -e "s/\");$//" | sed -e 's/\\\"/\"/g' | jq -r -c ' .UiState.Tunnels[] | .result = .LocalAddr + " > " +  .PublicUrl | .result ' | sed -e "s/^127.0.0.1://g" | sed -e "s@tcp://@@g" |  tr '\n' ',' |  sed -e 's/,$/ \n/g')
   for portinfo in $( echo "$pgrok_ports" | sed -e "s/,/\n/g" | awk '{print $1","$3}' );do
      destination_port=$(echo $portinfo | awk -F"," '{print $1}')
      deperture_port=$(echo $portinfo | awk -F"," '{print $2}')
      echo $destination_port" > "$deperture_port
      #pgrok_info=$(adddata2json adddata2json "${destination_port}" "${deperture_port}" "$pgrok_info")
   done
}


getFiwareInfo(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh getFiwareInfo
   if [ -f /tmp/myfiwareid ];then
      cat /tmp/myfiwareid
   else
      urlbase=smartcity-sendai.jp
      url_orion_v20_entities=https://${urlbase}/orion/v2.0/entities
      FService=sendai
      FServicePath=/Test

      accessToken=$(curl https://dpu.dais.cds.tohoku.ac.jp/common/atoken) && echo $accessToken
      echo "accessToken: "$accessToken

      curl -i "${url_orion_v20_entities}?idPattern=.*" \
      -H "Accept: application/json" \
      -H "Authorization:Bearer ${accessToken}" \
      -H "Fiware-Service:${FService}" \
      -H "Fiware-ServicePath:${FServicePath}" \
      | egrep  -A 100000  "^\[" | jq -c . > /tmp/entities.json

      # cat /tmp/entities.json | jq . 
      hostname_mac=$(hostname | sed 's/^.*-//')
      myfiwareid=$(cat /tmp/entities.json | jq ".[] | select(.hostname.value == \"${hostname_mac}\")" | jq -r .id)
      if [ -n "$myfiwareid" ];then
         echo "myfiwareid: "$myfiwareid
         echo $myfiwareid > /tmp/myfiwareid
      else
         echo "myfiwareid: null"
         rm /tmp/myfiwareid &> /dev/null
      fi
   fi
}


getnumOfFlowingBdaNMaxValues(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh getnumOfFlowingBdaNMaxValues
   # --- getnumOfFlowingBdaNMaxValues process ---
   # 前処理
   sqfilename=${dLcData}/ble.graph.db
   targetTable=flow300

   # 問題のあるjsonをカウント
   #sqlite3 ${sqfilename} "SELECT count(*) from ${targetTable} where json_valid(value) = 0;"

   # 問題のあるレコードを削除
   #sqlite3 ${sqfilename} "delete from ${targetTable} where json_valid(value) = 0;"

   #### 前日の最大値を取得
   # N日前の0時のunixtimeを取得
   Ndays=1
   startut=$(date '+%s' --date $(date '+%Y-%m-%d' --date "${Ndays} days ago"))
   startdateindex=$((startut/300))
   # 本日0時のunixtimeを取得
   endut=$(date '+%s' --date $(date '+%Y-%m-%d' --date "today"))
   enddateindex=$((endut/300))

   #echo $((endut - startut))
   #echo $(( enddateindex - startdateindex))
   
   # startut から endut の区間のデータのうち、最大値を取得
   type=dateMaxNumOfhoge
   result=$(date '+%Y-%m-%d' --date @${startut})
   jsondata=$(setJsonToJsonAsTxt $type "$result") #  注意：変更がない場合は応答なし

   #echo "${type}=${result}"
   #echo "jsondata="$jsondata

   type=MaxNumOfFlowingBdaNEARPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfFlowingBdaNEAR')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfFlowingBdaNEAR | jq -s max )

   #echo "${type}=${result}"
   #echo "jsondata="$jsondata

   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   #echo $jsondata
   #exit 0

   type=MaxNumOfFlowingBdaPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfFlowingBda')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfFlowingBda | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfFlowingBdaALLPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfFlowingBdaALL')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfFlowingBdaALL | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfStayingBdaNEARPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfStayingBdaNEAR')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfStayingBdaNEAR | jq -s max )
   [ -z "$result" ] && result="Null"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfStayingBdaPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfStayingBda')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfStayingBda | jq -s max )

   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfStayingBdaALLPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfStayingBdaALL')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfStayingBdaALL | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")




   #### 先週の同曜日の最大値を取得
   # N日前の0時のunixtimeを取得
   Ndays=7
   startut=$(date '+%s' --date $(date '+%Y-%m-%d' --date "${Ndays} days ago"))
   startdateindex=$((startut/300))
   Ndays=6
   endut=$(date '+%s' --date $(date '+%Y-%m-%d' --date "${Ndays} days ago"))
   enddateindex=$((endut/300))

   #echo $((endut - startut))
   #echo $(( enddateindex - startdateindex))
   
   # startut から endut の区間のデータのうち、最大値を取得

   type=dateMaxNumOfhoge
   result=$(date '+%Y-%m-%d' --date @${startut})
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")


   type=MaxNumOfFlowingBdaLastWeekNEARPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfFlowingBdaNEAR')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfFlowingBdaNEAR | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   
   type=MaxNumOfFlowingLastWeekBdaPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfFlowingBda')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfFlowingBda | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfFlowingLastWeekBdaALLPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfFlowingBdaALL')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfFlowingBdaALL | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfStayingLastWeekBdaNEARPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfStayingBdaNEAR')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfStayingBdaNEAR | jq -s max )
   [ -z "$result" ] && result="Null"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfStayingLastWeekBdaPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfStayingBda')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfStayingBda | jq -s max )

   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=MaxNumOfStayingLastWeekBdaALLPer300
#   result=$(sqlite3 ${sqfilename} "select max(json_extract(value, '$.numOfStayingBdaALL')) from ${targetTable} where  json_valid(value) = 1 and cast ( json_extract(value, '$.labeldateut')  as integer ) >= ${startut} and cast (json_extract(value, '$.labeldateut') as integer )  <  ${endut};" )
   result=$(sqlite3 ${sqfilename} "select value from ${targetTable} where  dateindex >= ${startdateindex} and dateindex <  ${enddateindex};" | jq -c .numOfStayingBdaALL | jq -s max )
   [ -z "$result" ] && result="-1"
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
#   echo $jsondata
#   exit 0
   TOPIC=v1/devices/me/attributes
   ACCESS_TOKEN=$(hostname | sed -e "s/focal-//")
   JSONDATA=${jsondata}
   resultOfMqtt=$(mosquitto_pub -d -q 1 -h "${THINGSBOARD_HOST_NAME}" -p "${THINGSBOARD_PORT}" -t "${TOPIC}" -u "${ACCESS_TOKEN}" -m "${JSONDATA}")
   echo $resultOfMqtt | grep -e "Connection Refused" -e "Error"
   result=$?
   if [ "$result" -eq 0 ];then
      # 失敗
      sendts=$(date +%s)000 # 送信日時のunixtime[msec]
      echo -e "${sendts}\t${jsondata2}" >> ${jsonfile}.failed
   fi
   echo ${jsondata2} >> ${jsonfile}
#   echo $JSONDATA | jq -c . 
#   echo "do: mosquitto_pub -d -q 1 -h \"${THINGSBOARD_HOST_NAME}\" -p \"${THINGSBOARD_PORT}\" -t \"${TOPIC}\" -u \"${ACCESS_TOKEN}\" -m \"${JSONDATA}\""

}

getLastBootInfo(){
   # 単独実行： $dCProgramsSh/getDeviceInfo2_u.sh getLastBootInfo
   # --- getLastBootInfo process ---
   # 前処理
   if [ -f "${dCProgramsSh}/ReBoot.sh.log" ];then
      Date=$(cat ${dCProgramsSh}/ReBoot.sh.log | grep "Date: " | tail -n 1 | sed -e "s/^Date:\s*202[0-9]-//")
      Caller=$(cat ${dCProgramsSh}/ReBoot.sh.log | grep "Caller: " | tail -n 1 | sed -e "s/^Caller:\s*//")
      Caller2=$(basename ${Caller})
      Line=$(cat ${dCProgramsSh}/ReBoot.sh.log | grep "Line: " | tail -n 1  | sed -e "s/^Line:\s*//")
      MSG=$(cat ${dCProgramsSh}/ReBoot.sh.log | grep "MSG: " | tail -n 1 | sed -e "s/^MSG:\s*//")
      dotype=$(cat ${dCProgramsSh}/ReBoot.sh.log | grep "do: " | tail -n 1 | sed -e "s/^do:\s*//")
      #echo "Caller: "$Caller2
      #echo "Line: "$Line
      #echo "MSG: "$MSG
      #echo "dotype: "$dotype
      echo "${dotype} by ${Caller2}(${Line}) at ${Date}"
   else
      echo "null"
   fi
}

cpuOnlineCheck(){
   # 単独実行：
   # $dCProgramsSh/getDeviceInfo2_u.sh cpuOnlineCheck
   # cat /sys/devices/system/cpu/cpu*/online

   # cpuのオンラインチェック
   numOfCPUonlineBefore=$(cat /sys/devices/system/cpu/cpu*/online  | grep "^1" | wc -l)
   #echo "numOfCPUonlineBefore="$numOfCPUonlineBefore | tee -a  ${logfile}   
   if [ $numOfCPUonlineBefore -lt 8 ];then
      # cpuが一部オフライン（８コア未満）の場合
      for i in /sys/devices/system/cpu/cpu*/online; do
         isonline=$(cat $i)
         if [ $isonline -eq 0 ];then
            #echo "$i is offlie" | tee -a  ${logfile}   
            echo 1 > $i
         fi
      done
      numOfCPUonlineAfter=$(cat /sys/devices/system/cpu/cpu*/online  | grep "^1" | wc -l)
#      echo "numOfCPUonlineAfter="$numOfCPUonlineAfter | tee -a  ${logfile}   
   fi
}



case $1 in
   changeOldlog2New)
      changeOldlog2New $@
         ;;
   resendFailed2TB)
      resendFailed2TB $@
         ;;
   getFiwareInfo)
      getFiwareInfo $@
         ;;
   getLastBootInfo)
      getLastBootInfo $@
         ;;
   getnumOfFlowingBdaNMaxValues)
      getnumOfFlowingBdaNMaxValues $@
         ;;
   PerNMinute)
      PerNMinute $@
         ;;
   ifValuesChangeOrPerNHour)
      ifValuesChangeOrPerNHour $@
         ;;
   showps)
      showps $@
         ;;
   stop)
      stop $@
         ;;
   start)
      main $@
         ;;
   restart)
      stop $@
      main
         ;;
   once)
      main once
         ;;
   cpuOnlineCheck)
      cpuOnlineCheck $@
         ;;
   *)
      keepalive
      stop $@
      getnumOfFlowingBdaNMaxValues $@
      main $@
         ;;

esac


