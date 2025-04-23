#!/bin/bash
SerialNo=20250309

<<"COMMENTOUT"
----
Change tracking
20250309 1st

----
- Setup

----
COMMENTOUT
source /zelowa/client/programs/sh/common1.sh $0  # クライアント用設定ファイルを読み取り

msg="\n========================================================\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
echo -e $msg | tee -a ${logfile}
echo $0 $@ | tee -a ${logfile}

# 待機時間
waitsec=240
#dotype=0 # 待機時間前の場合は終了
dotype=1 # 待機時間前の場合は待機時間までの待機して実行する
waitNsecSpendFromBoot

arg1=$1
arg2=$2


# stateOfStageの状態を確認
cat /boot/zelowa/custom | egrep "^stateOfStage" &> /dev/null  # そもそもstateOfStage設定が存在しない場合
if [ $? -ne 0 ];then
   echo -e "\n# 動作状態\nstateOfStage test # disable / enable / test " >> /boot/zelowa/custom
   stateOfStage=test
else
   stateOfStage=$(cat /boot/zelowa/custom | egrep "^stateOfStage" | tail -n 1 | awk '{print $2}')
fi

echo -e "\n---------------------------------\n"$msg | tee -a ${logfile}

trap "pkill -P $$" EXIT # 終了時にサブプロセスも一緒に落とすおまじない

# merge と restartがぶつかるので多重起動OKにする
#flgDoDualCheck=0 # 0: 多重起動OK
flgDoDualCheck=1 # 1: 二重起動不可、後のを起動させない。Set to 1 if double activation is not allowed.
#flgDoDualCheck=2 # 2: 二重起動不可、前のを強制終了して後のを起動させる。

if [ "${arg2}" != "all" ];then
   # 第2引数に"all"がない場合は追記のみ
   echo "start in only new mode!" | tee -a $logfile
else
   # 第2引数に"all"がある場合は全て再計算
   echo "start in all mode!" | tee -a $logfile
fi

prefixFilename=ble.$(hostname)
ramdisk=/var/ramdisk 

bledumpdir=/tmp/ble.dump.0
mkdir -p ${bledumpdir}
[ -d ${dLcData}/$(basename ${bledumpdir}) ] && rm -rf ${dLcData}/$(basename ${bledumpdir})
ln -sf ${bledumpdir} ${dLcData}/$(basename ${bledumpdir})

currentArchive=${bledumpdir}/currentArchive.csv1

mkdir -p ${dLcData}/ble.c1.db.data
c1DBfilePerDay=${dLcData}/ble.c1.db.data/ble.c1.db_${currentDateymd}
c1DBfile=${dLcData}/ble.c1.db

csv14tdagentOld=${bledumpdir}/ble.c1.csv.last10000
csv14tdagent=${ramdisk}/ble.c1.csv.last10000
if [ -f $csv14tdagentOld ];then
   mv $csv14tdagentOld $csv14tdagent
   ln -s ${ramdisk}/ble.c1.csv.last10000 ${bledumpdir}/
   ln -s ${ramdisk}/ble.c1.csv.last10000 ${dLcData}/
fi

shrinkfile $csv14tdagent 20000 10000

graphDBfile=${dLcData}/ble.graph.db
prefixGraphJsonfile=${dLcData}/ble.graph.json

# ログ/DBファイルの初期化と集約
bletransmitlogfile=${dLcData}/ble.transmit.log
co2jsonfile=${dLcData}/co2.json
deviceInfoDBfile=${dLcData}/$(hostname).deviceInfo.db

placeid=$(cat ${dLcConfig}/placeID )
if [ -z "${placeid}" ];then
   placeid="null";
fi
placeTag=$(cat ${dLcConfig}/placeTag )
if [ -z "${placeid}" ];then
   placeTag="null";
fi


if [ -f /zelowa/boot/zelowa/custom_addinfo1 ];then
   custom_addinfo1=$(tail -n 1 /zelowa/boot/zelowa/custom_addinfo1)
   custom_addinfo1_tag_1=$(echo $custom_addinfo1 | jq -r .tag_1)
   custom_addinfo1_tag_2=$(echo $custom_addinfo1 | jq -r .tag_2)
   custom_addinfo1_mode=$(echo $custom_addinfo1 | jq -r .mode)
   #echo $custom_addinfo1_tag_1", "$custom_addinfo1_tag_2", "$custom_addinfo1_mode
else
   custom_addinfo1=""
   custom_addinfo1_tag_1="uk"
   custom_addinfo1_tag_2="uk"
   custom_addinfo1_mode="uk"
fi

isthresholdRssiset=0
thresholdRssi=""
   
cat /boot/zelowa/custom | egrep "^thresholdRssi"
if [ $? -eq 0  ];then
   thresholdRssicandi=$(cat /boot/zelowa/custom | egrep "^thresholdRssi" | tail -n 1 | awk {'print $2'})
   if [ $thresholdRssicandi -lt 0 ] && [ $thresholdRssicandi -gt -120 ];then
      thresholdRssi=$thresholdRssicandi
      isthresholdRssiset=1
   fi
fi

if [ $isthresholdRssiset -eq 0  ];then
   if [ -f /zelowa/boot/zelowa/thresholdRssi ];then
      thresholdRssicandi=$(cat /zelowa/boot/zelowa/thresholdRssi)
   fi
   if [ -n "$thresholdRssicandi" ] && [ $thresholdRssicandi -lt 0 ] && [ $thresholdRssicandi -gt -120 ];then
      thresholdRssi=$thresholdRssicandi
      isthresholdRssiset=1
   fi
fi

if [ $isthresholdRssiset -eq 0  ];then   
   thresholdRssi=-120
   isthresholdRssiset=1
fi
echo "thresholdRssi: "$thresholdRssi | tee -a ${logfile}

recordedDateUt=$(/usr/bin/date +%s)
recordedDate=$(date "+%Y/%m/%d %H:%M" --date @${recordedDateUt})

numOfCpuCore=$(cat /proc/cpuinfo  | grep -e "^processor" | wc | awk '{print $1}')

if [ -n "$numOfCpuCore" ] && [ $numOfCpuCore -gt 1 ];then
   numOfParallel="-j"${numOfCpuCore}
else
   numOfParallel=""
fi
echo "numOfParallel: "$numOfParallel >> ${logfile}
#numOfParallel="-j4" # 最大コア数 時間: case1:26sec


echo "SerialNo: "$SerialNo | tee -a ${logfile}



start(){
   # 実行：$dCProgramsSh/recieveBleBeacon3dump2csv1DBsh.sh start
   # --- start process ---
   stepDateUt=$(/usr/bin/date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the start process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}
   echo "in 200" | tee -a $logfile


   # 実行前に既存プロセスや既存ファイルを処理する
   # tshark（キャプチャ）を一旦終了。
   if [ $flgDoDualCheck -eq 1 ];then
      IsRunning
   elif [ $flgDoDualCheck -eq 2 ];then
      stop # 古いプロセスを一旦終了
   fi

   sleep 5s  # 最新ファイルの切り替わりがはじまるのを5秒間だけ待機 (待つ秒数はファイル名に含まれる作成日時から推測可能)
   echo "do in 170: dump2csv1DB" >> ${logfile} &&  dump2csv1DB # ble.dump.0 フォルダ内のデータを csv1DB に取り込み

   stepDateUt=$(/usr/bin/date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished the start process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

}



dump2csv1DB(){
   # 実行：$dCProgramsSh/recieveBleBeacon3dump2csv1DBsh_x86.sh dump2csv1DB
   # --- start process ---
   stepDateUt=$(/usr/bin/date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the merge process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

   # ble.dump.0 フォルダ内の1分毎ファイルからcsv1DBにデータ取り込み
   mkdir -p ${dLcData}/ble.dump ${bledumpdir}/done2merged

   # 最新の１個を除く作成済みdumpフアィルを処理対象とする。ただし、最大128個とする。
   listOfBleDumpFiles=$(ls -rt ${bledumpdir}/bledump_* | grep -v ".merged$" | grep -v ".csv1$" | grep -v ".zst$" | grep -v ".enc$" | sort | head -n -1 | head -n 128)

   echo "listOfBleDumpFiles: $listOfBleDumpFiles"

   wlan0mac=$(ifconfig | grep wlx | sed -e "s/:.*$//" | sed -e "s/wlx//")

   for targetfile in $(echo $listOfBleDumpFiles );do
      echo "targetfile: "${targetfile} | tee -a ${logfile}
      targetfile0=$(dirname ${targetfile})/temp0.$(basename ${targetfile})
      echo "targetfile0: "$targetfile0  | tee -a ${logfile}

      tshark -r ${targetfile} \
      -T fields -E separator=, -e btle.advertising_address -e frame.time_epoch -e nordic_ble.rssi -e btcommon.eir_ad.entry.data -e btcommon.eir_ad.entry.service_data -e btcommon.eir_ad.entry.uuid_16 2> /dev/null \
      | egrep "^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2},[0-9]{10}" \
      | grep -v "^00:00:00:00:00:00" \
      | cut -c 1-28,39- \
      | sort -t "," -k 1,1 \
      > ${targetfile0}.step0

      cat ${targetfile0}.step0 \
      | uniq -w 27 \
      | awk -F"," '
         {
            if(match($6, /64879/)){
               print $2","$1",cocoa,"$3","$4","$5","$6
            }else if(match($6, /0xfd6f/)){
               print $2","$1",cocoa,"$3","$4","$5","$6
            }else if(match($6, /65261/)){
               print $2","$1",tile,"$3","$4","$5","$6
            }else if(match($6, /0xfeed/)){
               print $2","$1",tile,"$3","$4","$5","$6
            }else if(match($6, /64897/)){
               print $2","$1",sesame,"$3","$4","$5","$6
            }else if(match($6, /0xfd81/)){
               print $2","$1",sesame,"$3","$4","$5","$6
            }else if(match($4, /0215068068ffc92b49c2a4107f1947e6d4/)){
               print $2","$1",zelowa,"$3","$4","$5","$6
            }else if(match($4, /02:15:06:80:68:ff:c9:2b:49:c2:a4:10:7f:19:47:e6:d4/)){
               print $2","$1",zelowa,"$3","$4","$5","$6
            }else if(match($4, /0215b9407f30f5f8466eaff925556b57fe6e/)){
               print $2","$1",mamorio,"$3","$4","$5","$6
            }else if(match($4, /02:15:b9:40:7f:30:f5:f8:46:6e:af:f9:25:55:6b:57:fe:6e/)){
               print $2","$1",mamorio,"$3","$4","$5","$6
            }else{
               print $2","$1",UK,"$3","$4","$5","$6
            }
         }' | egrep "^[0-9]{10},[0-9a-f]{2}" \
         | sed -e "s/://g" > $targetfile0
      result=$?
      echo "result: "$result | tee -a ${logfile}
      ls -al $targetfile0 | tee -a ${logfile}
      echo "placeid=${placeid} -v wlan0mac=${wlan0mac} -v stateOfStage=${stateOfStage}" | tee -a ${logfile}

      if [ $result -eq 0 ];then
         cat $targetfile0 \
         | sort \
         | awk -F"," -v placeid=${placeid} -v wlan0mac=${wlan0mac} -v stateOfStage=${stateOfStage} '{print $1","placeid","wlan0mac","$2","$4","$3","stateOfStage}' \
         | egrep "^1[0-9].*,.*,.*,.*,.*,.*,.*$" > ${targetfile}.csv1
         ls -al ${targetfile}.csv1 | tee -a ${logfile}

         firstut=$(head -n 1 ${targetfile}.csv1 | awk -F"," '{print $1}')
	      dataDateymd=$(date "+%Y%m%d" --date @${firstut})
         echo "firstut: "$firstut | tee -a ${logfile}
         echo "dataDateymd: "$dataDateymd | tee -a ${logfile}

         mv ${targetfile} ${bledumpdir}/done2merged/
         cat ${targetfile}.csv1 >> ${currentArchive}
         cat ${targetfile}.csv1 >> ${csv14tdagent}
         #cat ${targetfile}.csv1 | grep -v ",null," >> /tmp/ble.dump.0/ble.csv1.${dataDateymd}
         cat ${targetfile}.csv1 > /tmp/ble.c1.csv.last
         ls -al /tmp/ble.c1.csv.last  | tee -a ${logfile}

         # ${targetfile}.csv1からhourlyデータを作成
         blecsv1hourlydir=${dLcData}/ble.c1.db.data/hourly
         mkdir -p $blecsv1hourlydir

         # 誤って作製されたファイルの削除。後でこの行は除く
#         rm /ble.csv1.202*_* &> /dev/null

         # 先に過去ファイル分の処理
         for fname in $(ls /tmp/ble.dump.0/ble.csv1.20[0-9][0-9][0-9][0-9][0-9][0-9] 2> /dev/null);do
            echo fname=$fname
            cat ${fname} | awk -F',' -v OFS=',' '{print strftime("%Y%m%d_%H",substr($1,1,10)),$1,$2,$3,$4,$5,$6,$7}' > ${fname}.temp
            for yyyymmdd_hh in $(awk -F',' '{print $1}' ${fname}.temp | sort | uniq);do
               echo "yyyymmdd_hh=$yyyymmdd_hh"
               grep $yyyymmdd_hh ${fname}.temp >> ${blecsv1hourlydir}/ble.csv1.$yyyymmdd_hh
            done
            rm ${fname} ${fname}.temp
         done

         # 直近ファイル分の処理
         cat ${targetfile}.csv1 | grep -v ",null," | awk -F',' -v OFS=',' '{print strftime("%Y%m%d_%H",substr($1,1,10)),$1,$2,$3,$4,$5,$6,$7}' > ${targetfile}.csv1.temp
         for yyyymmdd_hh in $(awk -F',' '{print $1}' ${targetfile}.csv1.temp | sort | uniq);do
            echo "yyyymmdd_hh=$yyyymmdd_hh"
            grep $yyyymmdd_hh ${targetfile}.csv1.temp >> ${blecsv1hourlydir}/ble.csv1.$yyyymmdd_hh
         done
         rm ${targetfile}.csv1.temp

         numInputData=$(wc ${targetfile}.csv1 | awk '{print $1}') # 取り込み予定のレコード数を確認
         echo "Add "${targetfile}.csv1" (+"${numInputData}") to "${currentArchive} | tee -a ${logfile}
         ln -sf /tmp/ble.c1.csv.last ${dLcData}/

         # 追跡用データの抽出
         # 観測対象uuid 先頭の「0215」はibeaconを意味する
         target_uuid="0215"$(echo $prefix_uuid0x |sed -e "s/\s//g")
         catcherlog0=/tmp/ble.dump.0/ble.catcher.log.0
         catcherlog=${dLcData}/ble.catcher.log
         echo -n > ${catcherlog0}

         echo "target_uuid: "$target_uuid | tee -a $logfile
         cat $targetfile0 | grep -e ${target_uuid} > ${targetfile0}.work
         for line in $(cat ${targetfile0}.work | awk -F"," '{print $5","$1","$4}' | sort | uniq -w 45 );do # 最終行を書き込み途中の恐れがあるので除く
            echo "line: "${line} >> ${catcherlog0}

            ibeaconinfo=$(echo $line | awk -F"," {'print $1'})
            lastuuid=$(echo $ibeaconinfo | sed -e "s/^.*${target_uuid}//" | cut -c 1-2 )
            major_0x=$(echo $ibeaconinfo | sed -e "s/^.*${target_uuid}//" | cut -c 3-6 )
            minor_0x=$(echo $ibeaconinfo | sed -e "s/^.*${target_uuid}//" | cut -c 7-10 )
            major=$(echo $((16#${major_0x})))
            minor=$(echo $((16#${minor_0x})))
            ACCESS_TOKEN=T${lastuuid}MA$(printf '%05d' $major)MI$(printf '%05d' $minor)
            echo "ACCESS_TOKEN: "$ACCESS_TOKEN | tee -a ${catcherlog0}

            # latitude / longitude を受信
            #echo "-1---" | tee -a $logfile
            #echo "ls -al /tmp/$(basename $0)/latitude" | tee -a $logfile
            #ls -al /tmp/$(basename $0)/latitude | tee -a $logfile
            #echo "-1---" | tee -a $logfile
            #echo "ACCESS_TOKEN: $ACCESS_TOKEN" | tee -a $logfile

            cat ${dCProgramsSh}/recieveBleBeacon3dump2csv1DBsh.catchers | grep ${ACCESS_TOKEN}
            if [ $? -eq 0 ];then
               echo "This line is matched with ${ACCESS_TOKEN}"  >> ${catcherlog0}
               
               cUt=$(echo $line | awk -F"," {'print $2'} )  # 時間内において、最初に観測された時間
               rssi=$(echo $line | awk -F"," {'print $3'} )
               msg="${cUt},${lastuuid},${major},${minor},${rssi},${ACCESS_TOKEN}"
               echo $msg >> $logfile
               if [ $major -lt 65536 ] && [ $major -ge 0 ] && [ $rssi -lt 0 ] && [ $rssi -gt -140 ];then
                  THINGSBOARD_Server_NAME=thingsboard2.dais.cds.tohoku.ac.jp
                  THINGSBOARD_PORT=1883  # MQTT
                  ts=${cUt}000

                  # latitude / longitude を受信
                  if [ -f /tmp/$(basename $0)/latitude ];then
                     latitude=$(cat /tmp/$(basename $0)/latitude | sed "s/ //g")
                     longitude=$(cat /tmp/$(basename $0)/longitude | sed "s/ //g")
                     placeID=$(cat /tmp/$(basename $0)/placeID | sed "s/ //g")
                  else
                     STOKEN=${wlan0mac}
                     echo "-------"
                     echo "curl -X 'GET' \"https://${THINGSBOARD_Server_NAME}/api/v1/${STOKEN}/attributes\" -H 'accept: application/json' | jq .shared" | tee -a $logfile
                     echo "-------"
                     sharedattributes=$(curl -X 'GET' \
  "https://${THINGSBOARD_Server_NAME}/api/v1/${STOKEN}/attributes" \
  -H 'accept: application/json' | jq .shared)
                     echo "sharedattributes: "$sharedattributes | tee -a $logfile
                     group=$(echo $sharedattributes | jq -r .group)
                     placeID=$(echo $sharedattributes | jq -r .placeID)
                     latitude=$(echo $sharedattributes | jq -r .latitude)
                     longitude=$(echo $sharedattributes | jq -r .longitude)
                     echo "do: mkdir -p /tmp/$(basename $0)"
                     mkdir -p /tmp/$(basename $0)
                     echo $group > /tmp/$(basename $0)/group
                     echo $placeID > /tmp/$(basename $0)/placeID
                     echo $latitude > /tmp/$(basename $0)/latitude
                     echo $longitude > /tmp/$(basename $0)/longitude
                  fi

                  jsondata="{\"type\":\"${lastuuid}\",\"placeID\":\"${placeID}\",\"rssi\":${rssi},\"latitude\":${latitude},\"longitude\":${longitude}}"
                  jsondata2="{\"ts\":${ts},\"values\":${jsondata}}"


                  resultOfMqtt=$(mosquitto_pub -d -q 1 -h "${THINGSBOARD_Server_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN}" -m "${jsondata2}"  2>&1 )
                  echo "resultOfMqtt: "${resultOfMqtt} | tee -a $logfile
                  echo ${resultOfMqtt} | grep -e "Connection Refused" -e "Error"
                  result=$?
                  if [ "$result" -eq 0 ];then
                     # 失敗
                     echo "2-${ACCESS_TOKEN},"${jsondata2} >> ${catcherlog}
                     echo "2-${ACCESS_TOKEN},"${jsondata2} >> ${catcherlog0}
                     #echo $resultOfMqtt | tee -a $logfile
                     #echo "----"  | tee -a $logfile
                     #echo mosquitto_pub -d -q 1 -h "${THINGSBOARD_Server_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN}" -m "${jsondata2}"  | tee -a $logfile
                     #echo "----" | tee -a $logfile
                  else
                     # 成功
                     echo "0-${ACCESS_TOKEN},"${jsondata2} >> ${catcherlog}
                     echo "0-${ACCESS_TOKEN},"${jsondata2} >> ${catcherlog0}
                  fi
               else
                  # 失敗
                  echo "1-${ACCESS_TOKEN},"${jsondata2} >> ${catcherlog}
                  echo "1-${ACCESS_TOKEN},"${jsondata2} >> ${catcherlog0}
               fi
            else
               # 追跡対象外
               echo "This line is not matched with ${ACCESS_TOKEN}"  >> ${catcherlog0}
               echo "9-${ACCESS_TOKEN},{}"  >> ${catcherlog0}
            fi

         done
         cp ${catcherlog0} ${catcherlog0}.last
      fi
      rm ${targetfile}* ${targetfile0}*
   done

   numInputData=$(wc ${currentArchive} 2> /dev/null | awk '{print $1}') # DBに取り込み予定のレコード数を確認
   echo "-------------------" | tee -a ${logfile}
   if [ -n "$numInputData" ] && [ $numInputData -gt 0 ];then
      echo "Add "${currentArchive}" (+"${numInputData}") to "${c1DBfile} | tee -a ${logfile}
      NumDataBefore=$(sqlite3 ${c1DBfile} "select count(dateut) from blecap") #DB登録済みのレコード数
      [ -z "${NumDataBefore}" ] && NumDataBefore=0

      # 取り込み用DBファイルを準備
      touch ${c1DBfile}
      sqlite3 ${c1DBfile} "
      create table if not exists blecap(
         dateut INT UNSIGNED NOT NULL, 
         placeid varchar(50) NOT NULL, 
         hostname varchar(50) NOT NULL, 
         bdaddr varchar(12) NOT NULL, 
         rssi TINYINT NOT NULL, 
         type varchar(20) NOT NULL, 
         stateOfStage text, 
         PRIMARY KEY(dateut, bdaddr)
      );" "alter table blecap add column stateOfStage text;" &> /dev/null

      # 取り込み用DBファイルを準備
      touch ${c1DBfilePerDay}
      sqlite3 ${c1DBfilePerDay} "
      create table if not exists blecap(
         dateut INT UNSIGNED NOT NULL, 
         placeid varchar(50) NOT NULL, 
         hostname varchar(50) NOT NULL, 
         bdaddr varchar(12) NOT NULL, 
         rssi TINYINT NOT NULL, 
         type varchar(20) NOT NULL, 
         stateOfStage text, 
         PRIMARY KEY(dateut, bdaddr)
      );" "alter table blecap add column stateOfStage text;" &> /dev/null


      # sqlite3 -separator , ${c1DBfile} ".import ${currentArchive} blecap"  2>> /dev/null
      echo "Importing currentArchive to c1DBfile in 271" | tee -a ${logfile}

      sqlite3 -separator , ${c1DBfile} <<EOF 2> /dev/null
begin transaction;
.import ${currentArchive} blecap
commit;
EOF
      result=$?

      sqlite3 -separator , ${c1DBfilePerDay} <<EOF 2> /dev/null
begin transaction;
.import ${currentArchive} blecap
commit;
EOF

      tail -n 10 ${currentArchive} > ${currentArchive}.last
      rm ${currentArchive}
      
      # DBから異常値を削除：未来のデータ
      sqlite3 ${c1DBfile} "
      delete from blecap where dateut > ${currentDateUt};
      "
      sqlite3 ${c1DBfilePerDay} "
      delete from blecap where dateut > ${currentDateUt};
      "

      # DBから異常値を削除： 1500000000 =20170714114000より古いデータ
      sqlite3 ${c1DBfile} "
      delete from blecap where dateut < 1500000000;
      "
      sqlite3 ${c1DBfilePerDay} "
      delete from blecap where dateut < 1500000000;
      "

      # DBから異常値を削除： rssiが -120 < rssi < 0 の範囲外
      sqlite3 ${c1DBfile} "
      delete from blecap where not (rssi < 0 and rssi > -120);
      "
      sqlite3 ${c1DBfilePerDay} "
      delete from blecap where not (rssi < 0 and rssi > -120);
      "

      if [ $result -eq 0 ] || [ $result -eq 19 ] ;then
         # 取り込み後のレコード数を確認
         NumDataAfter=$(sqlite3 ${c1DBfile} "select count(dateut) from blecap") #DB登録済みのレコード数
         [ -z "${NumDataAfter}" ] && NumDataAfter=0

         echo "Succeed in importing csv1DB in 281 $result (${NumDataBefore} + ${numInputData} -> ${NumDataAfter} ): ${currentArchive}" | tee -a ${logfile}
      else
         echo "Fail to import csv1DB in 283  $result (${NumDataBefore} + ${numInputData} -> ${NumDataBefore} ): ${currentArchive}" | tee -a ${logfile}
      fi
   else
      echo "no input data to "${c1DBfile} | tee -a ${logfile}
   fi

   #analyzeMygration 回遊性解析用データを作成
#   echo "do: $dCProgramsSh/analyzeMygration_v1.sh analizeCurrentData " | tee -a ${logfile}
#   $dCProgramsSh/analyzeMygration_v1.sh analizeCurrentData  | tee ${templogfile}
#   cat ${templogfile} | grep "add" | head -n 3| tee -a ${logfile}
#   cat ${templogfile} | grep "add" | tail -n 3| tee -a ${logfile}
   echo "logfile=$templogfile" | tee -a ${logfile}


   stepDateUt=$(/usr/bin/date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished the dump2csv1DB process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}
}





test(){
   # --- test process ---
   # ログに記述しない
   # 既存プロセスや既存ファイルを確認する
   ps -ef | grep tshark | grep -v "grep tshark" > /dev/null 2>&1 
   if [ $? -eq 0 ]; then
      echo "doing tsarkprocess now: "
      ps -ef | grep tshark | grep -v "grep tshark"
   fi
   ps -ef | grep "hcitool lescan --duplicates" | grep -v "grep" > /dev/null 2>&1 
   if [ $? -eq 0 ]; then
      killall hcitool > /dev/null 2>&1   # tshark（キャプチャ）を一旦終了。
      echo "killed hcitool process now: "
      ps -ef | grep "hcitool lescan --duplicates"
   fi
}

echo "in 584" | tee -a ${logfile}

case $1 in
   dump2csv1DB)
      dump2csv1DB $@
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
   showlog)
      showlog $@
         ;;
   stop)
      stop $@
         ;;
   start)
      echo "in 606" | tee -a ${logfile}
      start $@
         ;;
   restart)
      stop $@
      start $@
         ;;
esac

stepDateUt=$(/usr/bin/date +%s)
msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished: "${thisfile}" "$@"\n-----------------------\n"
echo -e $msg | tee -a ${logfile}

