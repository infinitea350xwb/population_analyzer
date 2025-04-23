#!/bin/bash
SerialNo=2025030901

<<"COMMENTOUT"
----
Change tracking
2025030901 first: x86対応 
----
- Setup

---

----
COMMENTOUT
source /zelowa/client/programs/sh/common1.sh $0  # クライアント用設定ファイルを読み取り

msg="\n========================================================\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
echo -e $msg | tee -a ${logfile}
echo $0 $@ | tee -a ${logfile}

echo "logfile=$logfile" | tee -a ${logfile}
ln -sf $logfile $dCProgramsSh/
ls -sl $dCProgramsSh/$(basename $logfile) | tee -a ${logfile}


# 待機時間
waitsec=240
#dotype=0 # 待機時間前の場合は終了
dotype=1 # 待機時間前の場合は待機時間までの待機して実行する
waitNsecSpendFromBoot

arg1=$1
arg2=$2

echo -e "\n---------------------------------\n"$msg | tee -a ${logfile}

trap "pkill -P $$" EXIT # 終了時にサブプロセスも一緒に落とすおまじない
#flgDoDualCheck=0 # 0: 多重起動OK
flgDoDualCheck=1 # 1: 二重起動不可、後のを起動させない。Set to 1 if double activation is not allowed.
#flgDoDualCheck=2 # 2: 二重起動不可、前のを強制終了して後のを起動させる。


arg2=$2
if [ "${arg2}" != "all" ];then
   # 第2引数に"all"がない場合は追記のみ
   echo "start in only new mode!" | tee -a $logfile
else
   # 第2引数に"all"がある場合は全て再計算
   echo "start in all mode!" | tee -a $logfile
fi


urlbase=smartcity-sendai.jp
url_orion_v20_entities=https://${urlbase}/orion/v2.0/entities
url_oauth2_token=https://${urlbase}/oauth2/token
url_orion_v20_entities=https://${urlbase}/orion/v2.0/entities
url_orion_v20_subscriptions=https://${urlbase}/orion/v2.0/subscriptions
url_comet_v10_contextEntities_type=https://${urlbase}/comet/v1.0/contextEntities/type


prefixFilename=ble.$(hostname)

bledumpdir=/tmp/ble.dump.0
mkdir -p ${bledumpdir}
[ -d ${dLcData}/$(basename ${bledumpdir}) ] && rm -rf ${dLcData}/$(basename ${bledumpdir})
ln -sf ${bledumpdir} ${dLcData}/$(basename ${bledumpdir})


c1DBfile=${dLcData}/ble.c1.db
graphDBfile=${dLcData}/ble.graph.db
prefixGraphJsonfile=${dLcData}/ble.graph.json

custom_addinfo1_mode=$(cat /boot/zelowa/custom | grep -e "^stateOfStage" | awk '{print $2}')
if [ -z "$custom_addinfo1_mode" ];then
   custom_addinfo1_mode="null"
fi

intervalseclist="300 3600"
echo "intervalseclist="$intervalseclist  | tee -a ${logfile}
#intervalseclist="300 3600"
#intervalseclist="3600"

recordedDateUt=$(date +%s)
recordedDate=$(date "+%Y/%m/%d %H:%M" --date @${recordedDateUt})

range_1st=20230123 # 処理対象年月日の最小値
range_end=21251231 # 処理対象年月日の最大値

findMtimeForNotAll=14400

echo "range_1st: "$range_1st  | tee -a ${logfile}
echo "range_end: "$range_end  | tee -a ${logfile}

numOfCpuCore=$(cat /proc/cpuinfo  | grep -e "^processor" | wc | awk '{print $1}')

if [ -n "$numOfCpuCore" ] && [ $numOfCpuCore -gt 1 ];then
   numOfParallel="-j"${numOfCpuCore}
else
   numOfParallel=""
fi
echo "numOfParallel: "$numOfParallel >> ${logfile}
#numOfParallel="-j4" # 最大コア数 時間: case1:26sec

sendTdAgentViaHttps=0 # 1: https経由でtd-agentサーバに送信

thresholdRssiNEAR=-60
thresholdRssi=-75

lastRecordDir=/tmp/$(basename $0)
echo "lastRecordDir: "$lastRecordDir
mkdir -p $lastRecordDir
isChangeOrPerNHour=1 # jsonデータに全項目を含める


# For MQTT
if [ ! -f /usr/bin/mosquitto_pub ];then
   echo "start to install mosquitto-clients" | tee -a ${logfile}
   apt-get update -y
   apt-get install -y mosquitto-clients
   echo "do: which mosquitto_pub"  | tee -a ${logfile}
      which mosquitto_pub | tee -a ${logfile}
fi

ACCESS_TOKEN=$(hostname | sed -e "s/focal-//")
jsonfile2tb=${dLcData}/ble.graph.tb.json
jsonfile2tbOld=${dLcData}/ble.graph.${ACCESS_TOKEN}.json

shrinkfile $jsonfile2tb 100000 50000

THINGSBOARD_HOST_NAME=thingsboard2.dais.cds.tohoku.ac.jp
THINGSBOARD_PORT=1883  # MQTT

group=$(cat ${dLcConfig}/group 2> /dev/null  | tail -n 1 )
[ -z "$group" ] && group="Null"

placeID=$(cat ${dLcConfig}/placeID 2> /dev/null  | tail -n 1 )
[ -z "$placeID" ] && placeID="Null"

stateOfStage=$(cat /boot/zelowa/custom | grep -e "^stateOfStage" | awk '{print $2}')
[ -z "$stateOfStage" ] && stateOfStage="Null"


start(){
   # 実行：$dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u_x86.sh start
   # --- start process ---
   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the start process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

   # 実行前に既存プロセスや既存ファイルを処理する
   if [ $flgDoDualCheck -eq 1 ];then
      IsRunning
   elif [ $flgDoDualCheck -eq 2 ];then
      stop # 古いプロセスを一旦終了
   fi

   # 過去のバグ対策
   # sed -i -e "s/:\./:0\./g" ${dLcData}/ble.graph.json.300;sed -i -e "s/:\./:0\./g" ${dLcData}/ble.graph.json.600;sed -i -e "s/:\./:0\./g" ${dLcData}/ble.graph.json.3600

   # csv1DBファイルからグラフ用のjsonファイルとDBファイルを作成
   echo "do in 224: csv1DB2graphJsonDB" >> ${logfile} && csv1DB2graphJsonDB

   flow2hourly

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished the start process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}
}

changeOldFiware2023log2New(){
     # 単独実行: $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u-sp.sh changeOldFiware2023log2New

      prefix_file=${dLcData}/fiwareUploadSendai2023

      echo -n > ${prefix_file}.${intervalsec}.failed

      intervalsec=300
      if [ -f ${prefix_file}_${intervalsec}.log ];then
         echo -n > ${prefix_file}.${intervalsec}.log

         cat ${prefix_file}_${intervalsec}.log  | grep -e "identifcation" -e "result: "> /tmp/changeOldFiware2023log2New.tmp
         prelogtype="";

         while read LINE
         do
            echo $LINE | grep "identifcation"  &> /dev/null
            if [ $? -eq 0 ];then
               jsondata=$LINE
               prelogtype=identifcation
               continue
            fi
            echo $LINE | grep "result:" &> /dev/null
            if [ $? -eq 0 ];then
               if [ "${prelogtype}" == "identifcation" ];then
                  senddate=$(echo $LINE | awk -F"," '{print $1}')
                  result=$(echo $LINE | sed -e "s/^.*result: //")
               
                  echo -e "${senddate}\t${result}\t${jsondata}" >> ${prefix_file}.${intervalsec}.log
                  if [ "$result" != "0" ];then
                     echo -e "${senddate}\t${result}\t${jsondata}" >> ${prefix_file}.log.failed
                  fi
                  prelogtype=result
               fi
            fi
         done < /tmp/changeOldFiware2023log2New.tmp
      fi

      intervalsec=3600
      if [ -f ${prefix_file}_${intervalsec}.log ];then
         echo -n > ${prefix_file}.${intervalsec}.log

         cat ${prefix_file}_${intervalsec}.log  | grep -e "identifcation" -e "result: "> /tmp/changeOldFiware2023log2New.tmp
         prelogtype="";

         while read LINE
         do
            echo $LINE | grep "identifcation"  &> /dev/null
            if [ $? -eq 0 ];then
               jsondata=$LINE
               prelogtype=identifcation
               continue
            fi
            echo $LINE | grep "result:" &> /dev/null
            if [ $? -eq 0 ];then
               if [ "${prelogtype}" == "identifcation" ];then
                  senddate=$(echo $LINE | awk -F"," '{print $1}')
                  result=$(echo $LINE | sed -e "s/^.*result: //")
               
                  echo -e "${senddate}\t${result}\t${jsondata}" >> ${prefix_file}.${intervalsec}.log
                  if [ "$result" != "0" ];then
                     echo -e "${senddate}\t${result}\t${jsondata}" >> ${prefix_file}.log.failed
                  fi
                  prelogtype=result
               fi
            fi
         done < /tmp/changeOldFiware2023log2New.tmp
         wc -l ${prefix_file}.log.failed
      fi
   
}


csv1DB2graphJsonDB(){
   # --- csv1DB2graphJsonDB process ---
   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the csv1DB2graphJsonDB process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

   echo "intervalseclist: "$intervalseclist | tee -a ${logfile}

   for intervalsec in ${intervalseclist};do 
      echo -e "\nstart $0: " ${intervalsec} " of " ${intervalseclist} | tee -a ${logfile}

      echo -e '\ndo in 412: '"csv1DB2graphJsonDBPerInterval ${intervalsec}"  | tee -a ${logfile}
      csv1DB2graphJsonDBPerInterval

      ## /zelowa/clientx/localhost/data/ble.graph.json.${intervalsec}.last のデータをfiware2023に送信
      fiwareUploadSendai2023 fiwareUploadSendai2023 ${intervalsec}
   done

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished the csv1DB2graphJsonDB process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}
}


getAccessTokenForFiware2023(){
   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the getAccessTokenForFiware2023 process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}


   # 実行： $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u.sh getAccessTokenForFiware2023

   # 主要なURL
   urlbase=smartcity-sendai.jp
   url_oauth2_token=https://${urlbase}/oauth2/token
   url_orion_v20_entities=https://${urlbase}/orion/v2.0/entities
   url_orion_v20_subscriptions=https://${urlbase}/orion/v2.0/subscriptions
   url_comet_v10_contextEntities_type=https://${urlbase}/comet/v1.0/contextEntities/type

   FService=sendai
   FServicePath=/

   # ファイル情報
   accessTokenFile=$dLcConfig/accessToken2023

   # アカウント情報
   cid=4mEHiJDSs1CHdojGooSEu9jGZu8a
   csecret=8jW09d1pXYRra39BfzYcZS7ZCPoa

   # アクセストークンの更新
   # アクセストークンは時間経過で失効する。
   # 別のアクセストークンを再取得しても過去のトークンは執行しない。
   # 時間内は利用可能。
   ### 更新の必要性判定
   isGetNewAccessToken=false # 初期状態では不要
   if [ ! -f ${accessTokenFile} ] || [ ! -s ${accessTokenFile} ];then
      # 存在しない場合はダウンロード
      isGetNewAccessToken=true
   else
      # 取得後の経過秒数を取得
      spentsec=$(( $(date +%s) - $(date -r ${accessTokenFile} +%s)  ))
      # echo "spentsec: "$spentsec
      if [ ${spentsec} -gt 3300 ];then
         isGetNewAccessToken=true
      fi
   fi

   if "${isGetNewAccessToken}";then
      echo "更新する" | tee -a ${logfile}
      [ -f ${accessTokenFile} ] && sudo mv -f ${accessTokenFile} ${accessTokenFile}.bak
      sudo touch ${accessTokenFile}
      sudo chmod 777 ${accessTokenFile}
      sudo curl -X POST "${url_oauth2_token}" \
   -d scope=default \
   -d grant_type=client_credentials \
   -d client_id=${cid} \
   -d client_secret=${csecret} > ${accessTokenFile}
      echo "resut=$?" | tee -a ${logfile}
   else
      echo "更新不要"| tee -a ${logfile}
   fi
   accessToken=$(head -n 1 ${accessTokenFile} | jq -r .access_token)

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] finished the getAccessTokenForFiware2023 process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

}

fiwareUploadrecordDB(){
   echo "start: fiwareUploadrecordDB prcess" | tee -a ${logfile}
   echo "\$1=$1" | tee -a ${logfile}
   if [ "$1" == "all" ];then
      sourcejsonfile=${dLcData}/ble.graph.json.${intervalsec}
   else
      sourcejsonfile=${dLcData}/ble.graph.json.${intervalsec}.last
   fi
   if [ ! -f "$sourcejsonfile" ];then
      echo "return 0 since sourcejsonfile is not found" | tee -a ${logfile}
      return 0
   fi

   tac $sourcejsonfile | \
   while read line
   do
      echo "line="$line | tee -a ${logfile}
      echo "aa---------"
      unixtime=$(echo $line | jq -r .labeldateut)
      dateObservedFromUt=$unixtime
      dateObservedToUt=$((unixtime+intervalsec))
      dateObservedFrom=$(date --iso-8601="seconds" --date @${dateObservedFromUt})
      dateObservedTo=$(date --iso-8601="seconds" --date @${dateObservedToUt})
      #echo "dateObservedFrom="$dateObservedFrom
      #echo "dateObservedTo="$dateObservedTo
      dateRetrieved=$(date --iso-8601="seconds") # $unixtime から送信時刻に変更
      peopleCount_immedate=$(echo $line | jq -r .numOfFlowingBdaNEAR)
      peopleCount_near=$(echo $line | jq -r .numOfFlowingBda)
      peopleCount_far=$(echo $line | jq -r .numOfFlowingBdaALL)
      peopleOccupancy_immedate=$(echo $line | jq -r .numOfStayingBdaNEAR)
      peopleOccupancy_near=$(echo $line | jq -r .numOfStayingBda)
      peopleOccupancy_far=$(echo $line | jq -r .numOfStayingBdaALL)
      # echo $unixtime
      # echo $dateRetrieved

      jsondata=" \
{
   \"identifcation\":{
      \"value\":\"${myfiwareid2023}\",
      \"type\":\"Text\"
   },
   \"dateObservedFrom\":{
      \"value\":\"${dateObservedFrom}\",
      \"type\":\"DateTime\"
   },
   \"dateObservedTo\":{
      \"value\":\"${dateObservedTo}\",
      \"type\":\"DateTime\"
   },
   \"peopleCount_immedate\":{
      \"value\":${peopleCount_immedate},
      \"type\":\"number\"
   },
   \"peopleCount_near\":{
      \"value\":${peopleCount_near},
      \"type\":\"number\"
   },
   \"peopleCount_far\":{
      \"value\":${peopleCount_far},
      \"type\":\"number\"
   },
   \"peopleOccupancy_immedate\":{
      \"value\":${peopleOccupancy_immedate},
      \"type\":\"number\"
   },
   \"peopleOccupancy_near\":{
      \"value\":${peopleOccupancy_near},
      \"type\":\"number\"
   },
   \"peopleOccupancy_far\":{
      \"value\":${peopleOccupancy_far},
      \"type\":\"number\"
   },
   \"dateRetrieved\":{
      \"value\":\"${dateRetrieved}\",
      \"type\":\"DateTime\"
   }
}
   "
      sudo echo $jsondata > /tmp/sendDataPer${intervalsec}.json

      senddate=$(date "+%Y/%m/%d-%H:%M:%S")
      jsondatalile=$(echo ${jsondata} | jq -c .)

      targetyyyymmdd=$(date "+%Y%m%d" --date @${unixtime})
      dailyDBfile=${dLcData}/ble.c1.db.data/ble.c1.db_${targetyyyymmdd}
      jsondataline=$(echo "$jsondata" | jq -c .)
      echo "dailyDBfile="$dailyDBfile | tee -a ${logfile}
      echo "jsondata=${jsondata}" | tee -a ${logfile}
      echo "dateObservedFromUt="$dateObservedFromUt | tee -a ${logfile}
      echo "dateObservedFrom="$dateObservedFrom | tee -a ${logfile}
      sqlite3 ${dailyDBfile} ".schema" | grep fiware2023_${intervalsec} |grep json
      if [ $? -eq 0 ];then
         sqlite3 ${dailyDBfile} "drop table fiware2023_${intervalsec}"
      fi
      sqlite3 ${dailyDBfile} "create table if not exists fiware2023_${intervalsec}(unixtime integer primary key,dateObservedFrom text,dateObservedTo text,peopleCount_immedate integer,peopleCount_near,peopleCount_far,peopleOccupancy_immedate,peopleOccupancy_near,peopleOccupancy_far);"
      sqlite3 ${dailyDBfile} "INSERT INTO fiware2023_${intervalsec} values(${dateObservedFromUt},'${dateObservedFrom}','${dateObservedTo}',${peopleCount_immedate},${peopleCount_near},${peopleCount_far},${peopleOccupancy_immedate},${peopleOccupancy_immedate},${peopleOccupancy_far});" 
      sqlite3 ${dailyDBfile} "select * from fiware2023_${intervalsec} order by unixtime desc limit 1;" | tee -a ${logfile}
   done
   echo "Finished: fiwareUploadrecordDB prcess" | tee -a ${logfile}

}

fiwareUploadSendai2023(){
   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the fiwareUploadSendai2023 process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

   # 外部実行： $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u.sh fiwareUploadSendai2023 $intervalsec [all]
   # 内部実行： fiwareUploadSendai2023 fiwareUploadSendai2023 $intervalsec [all]

   ## /zelowa/clientx/localhost/data/ble.graph.json.${intervalsec}.last のデータをfiwareに送信
   ## 第３引数に「all」が付いた場合は、/zelowa/clientx/localhost/data/ble.graph.json.${intervalsec}の全データを送信する。

   if [ "$2" == "3600" ] || [ "$2" == "300" ];then
#   if [ "$2" == "300" ];then
      intervalsec=$2
   else
      echo "return 0 since 2nd argument is not 300" | tee -a ${logfile}
      return 0
   fi
#   echo "arg2="$2
#   echo "intervalsec="$intervalsec | tee -a ${logfile}

   # entitiyIDの取得（一次管理はthingsboardのFiwareID2023属性）
   if [ ! -f $dLcConfig/FiwareID2023 ];then  # getDeviceInfo2_u.sh で定期実行される　$dCProgramsSh/thingsboardset.sh getAttributeAll　により取得
      # 存在しない場合実行しない
      return 0
   fi

   selectedID=$(cat $dLcConfig/FiwareID2023)
   myfiwareid2023=jp.sendai.Blesensor.per${intervalsec}.${selectedID}
   locationName=$(cat $dLcConfig/FiwareName)

#      echo "myfiwareid2023="$myfiwareid2023 | tee -a ${logfile}
#      echo "locationName="$locationName | tee -a ${logfile}

   # トークン等を取得・登録
#      accessToken=$(curl -s https://dpu.dais.cds.tohoku.ac.jp/common/atoken2023) 
   # echo $accessToken
#      echo "on web, accessToken="$accessToken | tee -a ${logfile}

   getAccessTokenForFiware2023
   echo "on local, accessToken="$accessToken | tee -a ${logfile}
   FiwareService=sendai
   FiwareServicePath=/

   fiwareUploadrecordDB $3

   if [ "$3" == "all" ];then
      sourcejsonfile=${dLcData}/ble.graph.json.${intervalsec}
   else
      sourcejsonfile=${dLcData}/ble.graph.json.${intervalsec}.last
   fi
#   echo "arg3="$3
   echo "sourcejsonfile="$sourcejsonfile | tee -a ${logfile}

   tac $sourcejsonfile | \
   while read line
   do
      echo "line="$line | tee -a ${logfile}
      echo "aa---------"
      unixtime=$(echo $line | jq -r .labeldateut)
      dateObservedFromUt=$unixtime
      dateObservedToUt=$((unixtime+intervalsec))
      dateObservedFrom=$(date --iso-8601="seconds" --date @${dateObservedFromUt})
      dateObservedTo=$(date --iso-8601="seconds" --date @${dateObservedToUt})
      #echo "dateObservedFrom="$dateObservedFrom
      #echo "dateObservedTo="$dateObservedTo
      dateRetrieved=$(date --iso-8601="seconds") # $unixtime から送信時刻に変更
      peopleCount_immedate=$(echo $line | jq -r .numOfFlowingBdaNEAR)
      peopleCount_near=$(echo $line | jq -r .numOfFlowingBda)
      peopleCount_far=$(echo $line | jq -r .numOfFlowingBdaALL)
      peopleOccupancy_immedate=$(echo $line | jq -r .numOfStayingBdaNEAR)
      peopleOccupancy_near=$(echo $line | jq -r .numOfStayingBda)
      peopleOccupancy_far=$(echo $line | jq -r .numOfStayingBdaALL)
      # echo $unixtime
      # echo $dateRetrieved

      jsondata=" \
{
   \"identifcation\":{
      \"value\":\"${myfiwareid2023}\",
      \"type\":\"Text\"
   },
   \"dateObservedFrom\":{
      \"value\":\"${dateObservedFrom}\",
      \"type\":\"DateTime\"
   },
   \"dateObservedTo\":{
      \"value\":\"${dateObservedTo}\",
      \"type\":\"DateTime\"
   },
   \"peopleCount_immedate\":{
      \"value\":${peopleCount_immedate},
      \"type\":\"number\"
   },
   \"peopleCount_near\":{
      \"value\":${peopleCount_near},
      \"type\":\"number\"
   },
   \"peopleCount_far\":{
      \"value\":${peopleCount_far},
      \"type\":\"number\"
   },
   \"peopleOccupancy_immedate\":{
      \"value\":${peopleOccupancy_immedate},
      \"type\":\"number\"
   },
   \"peopleOccupancy_near\":{
      \"value\":${peopleOccupancy_near},
      \"type\":\"number\"
   },
   \"peopleOccupancy_far\":{
      \"value\":${peopleOccupancy_far},
      \"type\":\"number\"
   },
   \"dateRetrieved\":{
      \"value\":\"${dateRetrieved}\",
      \"type\":\"DateTime\"
   }
}
   "
      sudo echo $jsondata > /tmp/sendDataPer${intervalsec}.json
#      echo "---------"  | tee -a $dLcData/fiwareUploadSendai2023_${intervalsec}.log  
#      cat /tmp/sendDataPer${intervalsec}.json | tee -a $dLcData/fiwareUploadSendai2023_${intervalsec}.log  
#      echo "---------"  | tee -a $dLcData/fiwareUploadSendai2023_${intervalsec}.log  
#      cat /tmp/sendDataPer${intervalsec}.json | jq -c . | tee -a $dLcData/fiwareUploadSendai2023_${intervalsec}.log  | tee -a ${logfile}
#      echo "---------"  | tee -a $dLcData/fiwareUploadSendai2023_${intervalsec}.log  

      echo "bb------------------------" | tee -a ${logfile}
      echo "ID: ${selectedID} (${locationName})"  | tee -a ${logfile}
      echo "intervalsec="$intervalsec | tee -a ${logfile}
      echo "myfiwareid2023="$myfiwareid2023 | tee -a ${logfile}
      echo "locationName="$locationName | tee -a ${logfile}
#      echo "accessToken=$accessToken" | tee -a ${logfile}
      echo "FiwareService=$FiwareService" | tee -a ${logfile}
      echo "FiwareServicePath=$FiwareServicePath" | tee -a ${logfile}
      echo "cc------------------------"| tee -a ${logfile}

      curl -X POST "${url_orion_v20_entities}/${myfiwareid2023}/attrs?type=Blesensor.per${intervalsec}" \
   -H "Accept: application/json" \
   -H "Content-Type: application/json" \
   -H "Authorization:Bearer ${accessToken}" \
   -H "Fiware-Service:${FiwareService}" \
   -H "Fiware-ServicePath:${FiwareServicePath}" \
   -sS -k \
   --data @/tmp/sendDataPer${intervalsec}.json > /tmp/fiwareUploadSendai2023.log

      result0=$?
      cat /tmp/fiwareUploadSendai2023.log | grep "error"
      result1=$?

      if [ $result0 -ne 0 ] || [ $result1 -ne 1 ] ;then
            # 失敗
            echo "Failed"
            result=1
      else 
            # 成功
            echo "Success"
            result=0
      fi

      senddate=$(date "+%Y/%m/%d-%H:%M:%S")
      jsondatalile=$(echo ${jsondata} | jq -c .)

 #     echo ${senddate}", result: "$result | tee -a $dLcData/fiwareUploadSendai2023_${intervalsec}.log 
      if [ -f $dLcData/fiwareUploadSendai2023_${intervalsec}.log ];then
         rm $dLcData/fiwareUploadSendai2023_${intervalsec}.log
      fi

      echo -e "${senddate}\t${result}\t${jsondatalile}" >> $dLcData/fiwareUploadSendai2023.${intervalsec}.log
      if [ $result -ne 0 ];then
         echo -e "${senddate}\t${result}\t${jsondatalile}" >> $dLcData/fiwareUploadSendai2023.log.failed
      fi
      
      targetyyyymmdd=$(date "+%Y%m%d" --date @${unixtime})
      dailyDBfile=${dLcData}/ble.c1.db.data/ble.c1.db_${targetyyyymmdd}
      jsondataline=$(echo "$jsondata" | jq -c .)
      echo "dailyDBfile="$dailyDBfile | tee -a ${logfile}
      echo "jsondata=${jsondata}" | tee -a ${logfile}
      echo "dateObservedFromUt="$dateObservedFromUt | tee -a ${logfile}
      echo "dateObservedFrom="$dateObservedFrom | tee -a ${logfile}
      sqlite3 ${dailyDBfile} ".schema" | grep fiware2023_${intervalsec} |grep json
      if [ $? -eq 0 ];then
         sqlite3 ${dailyDBfile} "drop table fiware2023_${intervalsec}"
      fi
      sqlite3 ${dailyDBfile} "create table if not exists fiware2023_${intervalsec}(unixtime integer primary key,dateObservedFrom text,dateObservedTo text,peopleCount_immedate integer,peopleCount_near,peopleCount_far,peopleOccupancy_immedate,peopleOccupancy_near,peopleOccupancy_far);"
      sqlite3 ${dailyDBfile} "INSERT INTO fiware2023_${intervalsec} values(${dateObservedFromUt},'${dateObservedFrom}','${dateObservedTo}',${peopleCount_immedate},${peopleCount_near},${peopleCount_far},${peopleOccupancy_immedate},${peopleOccupancy_immedate},${peopleOccupancy_far});" 
      sqlite3 ${dailyDBfile} "select * from fiware2023_${intervalsec} order by unixtime desc limit 1;" | tee -a ${logfile}
   done
   echo "done!" | tee -a ${logfile}
   echo "ee------------------------"| tee -a ${logfile}

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] finished the fiwareUploadSendai2023 process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}
}

changeOldlog2New(){
     # 単独実行:chmod 755 $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u-sp.sh; 
     # $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u-sp.sh changeOldlog2New [100]

      maxlines=$2
      [ -z "$maxlines" ] && maxlines=-1

      echo "maxlines=$maxlines"
      echo -n > ${jsonfile2tb}
      echo -n > ${jsonfile2tb}.failed
      echo -n > ${jsonfile2tb}.failed.log
      echo "jsonfile2tb="$jsonfile2tb
      echo "jsonfile2tbOld="$jsonfile2tbOld
      tmpfile=/tmp/recieveBleBeacon3csv1DB2grapheDB2_u_changeOldlog2New.tmp

      if [ ! -f $jsonfile2tbOld ];then
         echo "$jsonfile2tbOld is not exist!" 
         exit 0
      else
         echo "$jsonfile2tbOld is exist!" 
      
         if  [ $maxlines -gt 0 ];then
            cat ${jsonfile2tbOld}  | tail -n $maxlines > ${tmpfile}
         else
            cat ${jsonfile2tbOld}   > ${tmpfile}
         fi

         while read LINE
         do
#            echo $LINE
            result=$(echo $LINE | cut -c 1)
            if [ $result == "{" ];then
               echo $LINE | grep "fail"
               if [ $? -eq 0 ];then
                  result=1 # faiil
               else
                  result=0
               fi
            fi
            intervalsec=$(echo $LINE | awk -F"," '{print $2}')            
            if [ -z "$intervalsec" ];then
               intervalsec=0
               echo $LINE | grep "labeldate2Per300"
               if [ $? -eq 0 ];then
                  intervalsec=300
               fi
               echo $LINE | grep "labeldate2Per600"
               if [ $? -eq 0 ];then
                  intervalsec=600
               fi
               echo $LINE | grep "labeldate2Per3600"
               if [ $? -eq 0 ];then
                  intervalsec=3600
               fi
            fi
            if [ $intervalsec -eq 0 ];then
               continue
            fi
            jsondata=$(echo $LINE | sed -e "s@^.*{\"ts@{\"ts@")
            labeldate2Per=$(echo $jsondata | jq .values.labeldate2Per${intervalsec})

            #echo "result="$result
            #echo $jsondata
            #echo intervalsec=$intervalsec
            #echo labeldate2Per=$labeldate2Per
            #cat ${dLcData}/ble.graph.json.${intervalsec} | grep "$labeldate2Per"
            #cat ${dLcData}/ble.graph.json.${intervalsec} | grep "$labeldate2Per"  | grep "intervalsec\":${intervalsec}"
            cat ${dLcData}/ble.graph.json.${intervalsec} > /dev/null
            [ $? -ne 0 ] &&  echo "done:  $LINE"

            line0=$(cat ${dLcData}/ble.graph.json.${intervalsec} | grep "$labeldate2Per"  | grep "intervalsec\":${intervalsec}" | tail -n 1)
            #echo line0=$line0
            group0=$(echo $line0 | jq -r .group)            
            placeid0=$(echo $line0 | jq -r .placeid)            
            mode0=$(echo $line0 | jq -r .mode)
            hostname0=$(echo $line0 | jq -r .hostname)
            ##echo group0=${group0}
            #echo placeid0=${placeid0}
            #echo mode0=${mode0}
            #echo hostname0=${hostname0}
            echo -e "${group0}\t${placeid0}\t${hostname0}\t${mode0}\tble${intervalsec}\t${result}\t${jsondata}" >> ${jsonfile2tb}
            if [ ${result} -ne 0 ];then
               # fail
               echo -e "${group0}\t${placeid0}\t${hostname0}\t${mode0}\tble${intervalsec}\t${result}\t${jsondata}" >> ${jsonfile2tb}.failed
            fi
         done <  ${tmpfile}
      fi
      wc -l ${jsonfile2tb}.failed
      ls -al ${jsonfile2tb}.failed

      rm  ${tmpfile}
}


fiwareDownloadSendai2023(){
   # 外部実行： $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u.sh fiwareDownloadSendai2023 ${intervalsec}

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] start the fiwareDownloadSendai2023 process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}


   if [ "$2" = "3600" ] || [ "$2" = "300" ];then
      intervalsec=$2
   else
      echo "no 3600 or 300 in 2nd argument" | tee -a ${logfile}
      return 0
   fi

   echo "intervalsec="$intervalsec

   # entitiyIDの取得（一次管理はthingsboardのFiwareID2023属性）
   if [ ! -f $dLcConfig/FiwareID2023 ];then  # getDeviceInfo2_u.sh で定期実行される　$dCProgramsSh/thingsboardset.sh getAttributeAll　により取得
      # 存在しない場合実行しない
      exit 0
   else
      selectedID=$(cat $dLcConfig/FiwareID2023)
      myfiwareid2023=jp.sendai.Blesensor.per${intervalsec}.${selectedID}
      locationName=$(cat $dLcConfig/FiwareName)

      # トークン等を取得・登録

      url_orion_v20_entities=https://${urlbase}/orion/v2.0/entities
      accessToken=$(curl -s https://dpu.dais.cds.tohoku.ac.jp/common/atoken2023) 
      # echo $accessToken
      FiwareService=sendai
      FiwareServicePath=/
   fi
      
   dateTo=$(date --iso-8601="seconds")
   dateTo="2025-05-01T00:00:00Z"
   type=Blesensor.per${intervalsec}
   
   echo "------------------------"
   echo "url_comet_v10_contextEntities_type="$url_comet_v10_contextEntities_type
   echo "type="$type
   echo "myfiwareid2023="$myfiwareid2023
   echo "accessToken=$accessToken"
   echo "FiwareService=$FiwareService"
   echo "FiwareServicePath=$FiwareServicePath"
   echo "dateTo="$dateTo
   echo "------------------------"

   key=peopleCount_far
   # key=dateRetrieved

	curl "${url_comet_v10_contextEntities_type}/${type}/id/${myfiwareid2023}/attributes/${key}?lastN=0&dateFrom=2023-05-01T00:00:00Z&dateTo=${dateTo}" \
-H "Authorization:Bearer ${accessToken}" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Fiware-Service:${FiwareService}" \
-H "Fiware-ServicePath:${FiwareServicePath}" \
   | tee /tmp/result.json  | jq .
   echo "done!"
   ls -al tee /tmp/result.json

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] finished the fiwareDownloadSendai2023 process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

}



csv1DB2graphJsonDBPerInterval(){
   # --- csv1DB2graphJsonDBPerInterval process ---
   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Start the csv1DB2graphJsonDBPerInterval process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

   echo -e "\t intervalsec: "$intervalsec
   echo -e "\t graphDBfile: "$graphDBfile
   echo -e "\t prefixGraphJsonfile: "$prefixGraphJsonfile
   
   tablename=blecap
   tablenameinGraphDBfile=flow${intervalsec}

   sqlite3 ${graphDBfile}  "create table if not exists ${tablenameinGraphDBfile}(dateindex integer primary key, value json);"
   
   sqlite3 ${graphDBfile}  "create table if not exists table_list(tablename VARCHAR(255));
   INSERT INTO table_list (tablename) VALUES (\"${tablenameinGraphDBfile}\");"

   # "c1DBfile に登録済みの最小/最大unixtimeから、今回の解析範囲を決める
   if [ ! -f ${c1DBfile} ];then
      echo "no c1DBfile in 372: "${c1DBfile} | tee -a ${logfile}
      return 1
   else
      #echo "c1DBfile: "${c1DBfile} | tee -a ${logfile}
      mindateut=$(sqlite3 ${c1DBfile} "select min(dateut) from ${tablename} where dateut > 1500000000")
      maxdateut=$(sqlite3 ${c1DBfile} "select max(dateut) from ${tablename} where dateut < 2000000000")
      #echo "intervalsec: "${intervalsec}", mindateut: " ${mindateut}", maxdateut: "${maxdateut} | tee -a ${logfile}
      if [ -z $maxdateut ];then
         echo "no data in table"${tablename}"in db"${c1DBfile}" in 380" | tee -a ${logfile}
         return 1
      fi

#      c1DBfile に登録済みの最初と最後のデータ
#      echo " 1st data in DB: "$(date --date @${mindateut})
#      echo -e "last data in DB: "$(date --date @${maxdateut})"\n"

      if [ ${intervalsec} -ge 86400 ];then
         surplusSecFromMindateut=$(((mindateut+32400) %intervalsec))  # mindateut のinterval間隔区切りからのズレ
         if [ $surplusSecFromMindateut -gt 3600 ];then
            # 1日間隔の観測において、開始が0時より１時間異常経過している場合はその日を捨てる。
            mindateut=$((mindateut+86400))
         fi
         minyyyymmdd=$(date --date @${mindateut} "+%Y-%m-%d")
         lowerdateut=$(date -d "${minyyyymmdd} 00:00:00" +%s)
         #echo $minyyyymmdd $lowerdateut

         surplusSecFromMaxdateut=$(((maxdateut+32400) %intervalsec))  # maxdateut のinterval間隔区切りからのズレ
         if [ $surplusSecFromMaxdateut -lt 82800 ];then
            # 1日間隔の観測において、終了が23時（82800秒）以前の場合はその日を捨てる。
            # 23時以降までのデータがない場合
            maxdateut=$((maxdateut-86400))
         fi
         maxyyyymmdd=$(date --date @${maxdateut} "+%Y-%m-%d")
         upperdateut=$(date -d "${maxyyyymmdd} 23:59:59" +%s)
         #echo $maxyyyymmdd $upperdateut

         # unixtime=0で、index=0となるようにする。
         # initervalsec=86400[sec]の場合、unixtime=0, 54000, 54000+initervalsecでindex=0,1,2となるようにする。
         lowerdateindex=$(((lowerdateut+32400)/intervalsec))
         upperdateindex=$(((upperdateut+32400)/intervalsec))
      else
         lowerdateut=$(((mindateut/intervalsec)*intervalsec)) # intervalsecの倍数で、mindateutより小さい最大値
         upperdateut=$(((maxdateut/intervalsec)*intervalsec)) #intervalsecの倍数で、maxdateutより小さい最大値
         
         # unixtime=0で、index=0となるようにする。
         lowerdateindex=$((lowerdateut/intervalsec))
         upperdateindex=$((upperdateut/intervalsec))
      fi
      echo "lowerdateut: "$lowerdateut
      echo "upperdateut: "$upperdateut
      

      upperdateindex=$((upperdateindex-1)) # upperdateindexの計算には、そこからintervalsecの時間分の追加データが必要。上記では考慮していなかったため、ここで１を引く
      upperdateut=$((upperdateindex*intervalsec))
      
      echo ${prefixGraphJsonfile}.${intervalsec}: 

      if [ -f ${prefixGraphJsonfile}.${intervalsec} ];then
         # jsonデータファイルの最終行に登録されているデータ日時インデックス：dateindex
         lastdonedateindex=$(tail -n 1 ${prefixGraphJsonfile}.${intervalsec} | jq -r .dateindex 2> /dev/null ) 

         if [ -z $lastdonedateindex ];then
            # 最終行が異常（＝書き込みに失敗している）の場合
            sed -i -e '$d' ${prefixGraphJsonfile}.${intervalsec} #　最終行を削除
            lastdonedateindex=$(tail -n 1 ${prefixGraphJsonfile}.${intervalsec} | jq -r .dateindex  2> /dev/null )
         fi
         echo "lastdonedateindex: $lastdonedateindex"

         # jsonデータファイルの最終行から取得されたデータ日時インデックスが正常の場合、その次の日時インデックスから処理する
         if [ "${arg2}" != "all" ];then
            # 追記のみ
            if [ -n "$lastdonedateindex" ] && [ "$lastdonedateindex" -gt 1 ];then
               lowerdateindex=$((lastdonedateindex+0)) # 全データの解析をやり直したい場合はこの行をコメントする
            fi
         fi
         echo "lowerdateindex: $lowerdateindex"
      fi

      lowerdateut=$((lowerdateindex*intervalsec))

      # 最終記録日時lowerdateutから、実際にデータ収集再開までに長期に開いている場合があるので、そのデータ収集再開日時を確認する。
<<"COMMENTOUT"      
      c1DBfile=${dLcData}/ble.c1.db
      tablename=blecap
      intervalsec=300
      lowerdateut=1694228700
      sqlite3 ${c1DBfile} "select min(dateut) from ${tablename} where dateut > ${lowerdateut}"

      # 長期停止後に再開する場合、空白期間の処理も一つずつ行おうとしてすごく時間がかかり、処理が始まらない。
      # データ空白期間を効率的に飛ばす処理が必要であるが、すぐには対応困難のため、最長１日まで遡るようにする。
COMMENTOUT

      mindateut=$(sqlite3 ${c1DBfile} "select min(dateut) from ${tablename} where dateut > ${lowerdateut}")

      mindateut0=$(date -d  '1 day ago' +%s)
      echo "mindateut0=$mindateut0"
      date --date @$mindateut0

      if [ $mindateut -lt $mindateut0 ];then
         echo "canged mindateut (mindateut = $mindateut -> $mindateut0) in 959 since $mindateut < $mindateut0" | tee -a  ${logfile}
         mindateut=$mindateut0
      else
         echo "No canged mindateut (mindateut = $mindateut ) in 959 since $mindateut >= $mindateut0" | tee -a  ${logfile}
      fi

      lowerdateindex=$((mindateut/intervalsec))
      newlowerdateut=$((lowerdateindex*intervalsec))
      echo "-------------" | tee -a ${logfile}
      echo "intervalsec: "$intervalsec | tee -a  ${logfile}
      echo "lowerdateut: "$lowerdateut | tee -a  ${logfile}
      echo "mindateut: "$mindateut | tee -a  ${logfile}
      echo "newlowerdateut: "$newlowerdateut | tee -a  ${logfile}
      echo $(date --date @$newlowerdateut) | tee -a  ${logfile}
      echo "-------------" | tee -a  ${logfile}
      lowerdateut=${newlowerdateut}
 
      
#      echo "lowerdateut: $lowerdateut "$(date --date @${lowerdateut})
#      exit 1
#      echo "${lowerdateindex}, ${lowerdateut}, ${upperdateindex}, ${upperdateut}"
#      echo " 1st index in loop: "${lowerdateindex}", "$(date --date @${lowerdateut})| tee -a ${logfile}
#      echo "last index in loop: "${upperdateindex}", "$(date --date @${upperdateut}) | tee -a ${logfile}
      echo "Num of remaining index: "$((upperdateindex-lowerdateindex+1)) \
      " from ${lowerdateindex} ( at " $(date "+%Y/%m/%d %H:%M:%S" --date @${lowerdateut}) \
      ") to ${upperdateindex} ( at " $(date "+%Y/%m/%d %H:%M:%S" --date @${upperdateut})" )" | tee -a ${logfile}

      # データ追記前のレコード数
      #echo -e "do in 513: sqlite3 ${graphDBfile} \"select count(dateindex) from ${tablenameinGraphDBfile}\""
      NumGraphDBBefore=$(sqlite3 ${graphDBfile} "select count(dateindex) from ${tablenameinGraphDBfile}" 2> /dev/null)
      if [ -z $NumGraphDBBefore ];then
         NumGraphDBBefore=0
      fi
      echo "NumGraphDBBefore: "$NumGraphDBBefore 

      echo -n > ${prefixGraphJsonfile}.${intervalsec}.last

      # パラレルのインストール
      #which parallel &> /dev/null
      #[ $? -ne 0 ] && echo -e "do in 524: apt-get install -y parallel" >> ${logfile} && apt-get install -y parallel 

      echo -e "\t graphDBfile: "$graphDBfile
      echo -e "\t tabfile: "${prefixGraphJsonfile}.${intervalsec}.last
      echo -e "\t tablenameinGraphDBfile : " $tablenameinGraphDBfile

      for index in $(seq ${lowerdateindex} ${upperdateindex});do
         echo "index: "$index" / "$upperdateindex
         EachCsv1DB2graphJsonDBPerInterval
      done

      cat ${prefixGraphJsonfile}.${intervalsec}.last >> ${prefixGraphJsonfile}.${intervalsec}


      shrinkfile ${prefixGraphJsonfile}.${intervalsec} 1000000 500000

      # echo -e "do in 538: sqlite3 ${graphDBfile} \"select count(dateindex) from ${tablenameinGraphDBfile}\""
      NumGraphDBAfter=$(sqlite3 ${graphDBfile} "select count(dateindex) from ${tablenameinGraphDBfile}") #DB登録済みのレコード数
      numofAdd=$(wc ${prefixGraphJsonfile}.${intervalsec}.last | awk '{print $1}' )
      echo -e "\n imported in 366 as (${NumGraphDBBefore} + ${numofAdd} -> ${NumGraphDBAfter} ): ${prefixGraphJsonfile}.${intervalsec}.last" | tee -a ${logfile}
   fi

   stepDateUt=$(date +%s)
   msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished the csv1DB2graphJsonDBPerInterval process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}
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

setJsonToJsonAsTxt(){
   # 使い方：   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
   #echo "type: "$type
   #echo "result: "$result
   #echo "jsondata: "$jsondata
   lastResult=$(cat ${lastRecordDir}/${type} 2> /dev/null)
   if [ $isChangeOrPerNHour -eq 1 ] || [ "${lastResult}" != "$result" ] ;then
   #   echo "changed!" >> ${logfile}
      echo "${result}" > ${lastRecordDir}/${type}
      jsoncore="\"${type}\":\"${result}\""

      if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
         jsondata="{${jsoncore}}"
      else
         jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
      fi
   #else
   #   echo "No-changed!" >> ${logfile}
   fi
   echo ${jsondata}
}

setJsonToJsonAsNum(){
   # 使い方：   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")

   type=$1
   result=$2
   jsondata=$3
   #echo "type: "$type
   #echo "result: "$result
   #echo "jsondata: "$jsondata
   lastResult=$(cat ${lastRecordDir}/${type} 2> /dev/null)
   if [ $isChangeOrPerNHour -eq 1 ] || [ "${lastResult}" != "$result" ] ;then
   #   echo "changed!" >> ${logfile}
      echo "${result}" > ${lastRecordDir}/${type}
      jsoncore="\"${type}\":${result}"

      if [ -z "$jsondata" ] || [ "$jsondata" == "{}" ];then
         jsondata="{${jsoncore}}"
      else
         jsondata=$(echo $jsondata | sed -e "s/}$/,/")"${jsoncore}}"
      fi
   #else
   #   echo "No-changed!" >> ${logfile}
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
# ---


EachCsv1DB2graphJsonDBPerInterval(){
   # --- EachCsv1DB2graphJsonDBPerInterval process ---

   indexFrom0=$(( index- lowerdateindex + 1)) # このループの繰り返し回数
   numofIndexes=$((upperdateindex - lowerdateindex +1))  #　ループするindex数

   # 年月日を抽出
   #echo $((index * intervalsec))
   yyyymmdd=$(date "+%Y%m%d" --date @$((index * intervalsec)))
   #echo "yyyymmdd: "$yyyymmdd

   #echo -e $targetfile "\n" $yyyymmdd
   [ -z $yyyymmdd ] && yyyymmdd=0
   if [ "${yyyymmdd}" -lt "${range_1st}" ] || [ "${yyyymmdd}" -gt "${range_end}" ];then
      # データが解析対象期間外の場合はskip
      echo -e "\t index: ${index}/${upperdateindex} ( ${indexFrom0}/${numofIndexes} ) skip to make graph info. in 871: ${yyyymmdd} " && return
   fi
   yyyymmddHHMM=$(date "+%Y/%m/%d %H:%M" --date @$((index * intervalsec)))


   echo -n -e "\t index: ${index}/${upperdateindex} ( ${indexFrom0}/${numofIndexes} ) "
   [ $(( indexFrom0 % 10 )) -eq 0 ] || [ ${index} -eq ${upperdateindex} ] && echo -n -e "\t${indexFrom0}/${numofIndexes} " >> ${logfile}
   [ $(( indexFrom0 % 100 )) -eq 0 ] || [ ${index} -eq ${upperdateindex} ] && echo " " >> ${logfile}
   # DBに登録済みであるかを確認
 #  echo -e "do in 579: sqlite3 ${graphDBfile} \"select count(*) from ${tablenameinGraphDBfile} where dateindex=${index};\""
   sqlresult=$(sqlite3 ${graphDBfile} "select count(*) from ${tablenameinGraphDBfile} where dateindex=${index};")
   #echo "sqlresult: "$sqlresult


   [ "${sqlresult}" -eq 1 ] && [ "${arg2}" != "all" ] && echo -e "\t ${yyyymmddHHMM}\t already done to make graph info to graph Json/DB in 593 " && return 
   
   if [ ${intervalsec} -ge 86400 ];then
      # その index における unixtimeの最小値
      lowerdateut=$((index*intervalsec - 32400)) # 9時間の時差のために-32400[sec]する。
   else
      lowerdateut=$((index*intervalsec)) 
   fi
   lowerdateut0=$lowerdateut; # 以下で補正される前の値をラベル用に保持する
   lowerdateut=$((lowerdateut0 +5 )); # cocoa識別子の切り替えによる二重カウントを防ぐために+5[sec]する。

   
   # その index における unixtimeの最大値
   upperdateut=$((lowerdateut0 + intervalsec - 1)) # cocoa識別子の切り替えによる二重カウントを防ぐために-1[sec]する。
   labeldate=$(date "+%Y-%m-%d %H:%M" --date @${lowerdateut0})
   echo -n -e "\t labeldate: ${labeldate}, "

   # その区間のグラフ描画用ラベルを決定
   case $intervalsec in
      86400 )
         labeldate2=$(date "+%Y/%m/%d" --date @${lowerdateut0})
         ;;
      3600 )
         labeldate2=$(date "+%Y/%m/%d-%H" --date @${lowerdateut0})
         ;;
      * ) # その他
         labeldate2=$(date "+%Y/%m/%d %H:%M" --date @${lowerdateut0})
         ;;
   esac
   echo "labeldate2: "$labeldate2


   # そのindexにおけるデータ数をカウント
   tablename=blecap
   tablenameinGraphDBfile=flow${intervalsec}

   numOfBleRecieved=$(sqlite3 ${c1DBfile} "select count(*) from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut}")
   echo -e "\t numOfBleRecieved: "$numOfBleRecieved | tee -a ${logfile}

   if [ "${numOfBleRecieved}" -eq 0 ];then
      NumOfDistinctBleRecieved=0;
      numOfBleRecieved_enable=0
      numOfBleRecieved_disable=0
      numOfBleRecieved_test=0
      echo -e "\t NumOfDistinctBleRecieved: "$NumOfDistinctBleRecieved | tee -a ${logfile}
      firstut=""
      lastut=""
      rhostnamelist=""
      numOfRhostnamelist=0

      recievedsec=0
      numOfFlowingBdaNEAR=0
      numOfFlowingBda=0
      numOfFlowingBdaALL=0
      detectedsecBdaALL=0
      detectedsecBda=0
      detectedsecBdaNEAR=0
      numOfStayingBdaALL=0
      numOfStayingBdaNEAR=0
      numOfStayingBda=0

   else
      NumOfDistinctBleRecieved=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut}")
      numOfBleRecieved_enable=$(sqlite3 ${c1DBfile} "select count(*) from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut} and stateOfStage = 'enable'")
      numOfBleRecieved_disable=$(sqlite3 ${c1DBfile} "select count(*) from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut} and stateOfStage = 'disable'")
      numOfBleRecieved_test=$(sqlite3 ${c1DBfile} "select count(*) from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut} and stateOfStage = 'test'")
      echo -e "\t NumOfDistinctBleRecieved: "$NumOfDistinctBleRecieved | tee -a ${logfile}

      result=$(sqlite3 ${c1DBfile} "select min(dateut), max(dateut) from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut}")
      firstut=$(echo $result | awk -F"|" '{print $1}')
      lastut=$(echo $result | awk -F"|" '{print $2}')

      # 受信センサのホスト名リスト
      rhostnamelist=$(sqlite3 ${c1DBfile} "select DISTINCT hostname from ${tablename} where dateut > ${lowerdateut} and dateut < ${upperdateut}")
      #echo $rhostnamelist
      numOfRhostnamelist=$(echo ${rhostnamelist} | awk '{print NF}')


      recievedsec=$(sqlite3 ${c1DBfile} "select count(distinct dateut) from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut};")
      # recievedsec は、観測されたunixtimeの種類数。ただし、csv1ファイルはBLE識別子毎の10秒間隔で記録を取っている。
      # ただし、最終桁の[秒]の桁が0とは限らないので、観測数*10とするとintervalsecを超えてしまう。
      # そのため、これは参考情報にすぎない。
      numOfFlowingBdaNEAR=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssiNEAR};")
      numOfFlowingBda=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssi};")
      numOfFlowingBdaALL=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut};")
   #   numOfFlowingCocoaNEAR=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where type = 'cocoa' and dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssiNEAR};")
   #   numOfFlowingCocoa=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where type = 'cocoa' and dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssi};")
   #   numOfFlowingCocoaALL=$(sqlite3 ${c1DBfile} "select count(distinct bdaddr) from ${tablename} where type = 'cocoa' and dateut <= ${upperdateut} and dateut > ${lowerdateut};")
      #echo "numOfFlowingBda: "$numOfFlowingBdaALL
      #echo "numOfFlowingCocoa: "$numOfFlowingCocoaALL

      detectedsecBdaALL=$(sqlite3 ${c1DBfile} "select sum(table1.detectedsec)
      from (select bdaddr, max(dateut), min(dateut), max(dateut)-min(dateut) as detectedsec
      from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut}    
      group by bdaddr order by dateut) as table1 ")

      detectedsecBda=$(sqlite3 ${c1DBfile} "select sum(table1.detectedsec)
      from (select bdaddr, max(dateut), min(dateut), max(dateut)-min(dateut) as detectedsec
      from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssi} 
      group by bdaddr order by dateut) as table1 ")

      detectedsecBdaNEAR=$(sqlite3 ${c1DBfile} "select sum(table1.detectedsec)
      from (select bdaddr, max(dateut), min(dateut), max(dateut)-min(dateut) as detectedsec
      from ${tablename} where dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssiNEAR}   
      group by bdaddr order by dateut) as table1 ")

      if [ -z ${detectedsecBdaALL} ];then
         numOfStayingBdaALL=0
      else
         numOfStayingBdaALL=$(bc <<< "scale=2; $detectedsecBdaALL/$intervalsec" | bc | awk '{printf "%.2f\n", $0}' )
      fi
      if [ -z ${detectedsecBdaNEAR} ];then
         numOfStayingBdaNEAR=0
      else
         numOfStayingBdaNEAR=$(bc <<< "scale=2; $detectedsecBdaNEAR/$intervalsec" | bc | awk '{printf "%.2f\n", $0}' )
      fi
      if [ -z ${detectedsecBda} ];then
         numOfStayingBda=0
      else
         numOfStayingBda=$(bc <<< "scale=2; $detectedsecBda/$intervalsec" | bc | awk '{printf "%.2f\n", $0}')
      fi
      #echo "numOfStayingBdaALL: "$numOfStayingBdaALL
      #echo "numOfStayingBda: "$numOfStayingBda

   fi
   
   #echo "rhostnamelist: "$rhostnamelist
   #echo "numOfRhostnamelist: "$numOfRhostnamelist


<<"COMMENT"   
   detectedsecCocoaALL=$(sqlite3 ${c1DBfile} "select sum(table1.detectedsec)
   from (select bdaddr, max(dateut), min(dateut), max(dateut)-min(dateut) as detectedsec
   from ${tablename} where type = 'cocoa' and dateut <= ${upperdateut} and dateut > ${lowerdateut} 
   group by bdaddr order by dateut) as table1 ")

   detectedsecCocoa=$(sqlite3 ${c1DBfile} "select sum(table1.detectedsec)
   from (select bdaddr, max(dateut), min(dateut), max(dateut)-min(dateut) as detectedsec
   from ${tablename} where type = 'cocoa' and dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssi}   
   group by bdaddr order by dateut) as table1 ")

   detectedsecCocoaNEAR=$(sqlite3 ${c1DBfile} "select sum(table1.detectedsec)
   from (select bdaddr, max(dateut), min(dateut), max(dateut)-min(dateut) as detectedsec
   from ${tablename} where type = 'cocoa' and dateut <= ${upperdateut} and dateut > ${lowerdateut} and rssi > ${thresholdRssiNEAR} 
   group by bdaddr order by dateut) as table1 ")

   if [ -z ${detectedsecCocoaALL} ];then
      numOfStayingCocoaALL=0
   else
      numOfStayingCocoaALL=$(bc <<< "scale=2; $detectedsecCocoaALL/$intervalsec")
   fi
   if [ -z ${detectedsecCocoa} ];then
      numOfStayingCocoa=0
   else
      numOfStayingCocoa=$(bc <<< "scale=2; $detectedsecCocoa/$intervalsec")
   fi
   if [ -z ${detectedsecCocoaNEAR} ];then
      numOfStayingCocoaNEAR=0
   else
      numOfStayingCocoaNEAR=$(bc <<< "scale=2; $detectedsecCocoaNEAR/$intervalsec")
   fi
   #echo "numOfStayingCocoaALL: "$numOfStayingCocoaALL
   #echo "numOfStayingCocoa: "$numOfStayingCocoa
COMMENT

   # 追加情報を確認

   # deviceInfoDBから探す
   deviceInfo2jsonfile=${dLcData}/deviceInfo2.$(hostname | sed -e "s/^focal-//").json
   if [ -f $deviceInfo2jsonfile ];then
      uptimeDate=$(tail -n 1000 $deviceInfo2jsonfile | grep "uptime" | sed -e "s/^.*,{/{/" | jq -r .values.uptimeDate | tail -n 1) 
      uptimeDateUnixtime=$(date +%s --date "$uptimeDate")
      LoadAverage2=$(tail -n 1000 $deviceInfo2jsonfile | grep "LoadAverage2" | sed -e "s/^.*,{/{/" | jq -r .values.LoadAverage2 | tail -n 1)
      TgzInfo=$(tail -n 1000 $deviceInfo2jsonfile | grep "TgzInfo" | sed -e "s/^.*,{/{/" | jq -r .values.TgzInfo | tail -n 1)
#      placeID=$(tail -n 1000 $deviceInfo2jsonfile | grep "placeID" | sed -e "s/^.*,{/{/" | jq -r .values.placeID | tail -n 1)
#      placeTag=$(tail -n 1000 $deviceInfo2jsonfile | grep "placeTag" | sed -e "s/^.*,{/{/" | jq -r .values.placeTag | tail -n 1)
#      group=$(tail -n 1000 $deviceInfo2jsonfile | grep "group" | sed -e "s/^.*,{/{/" | jq -r .values.group | tail -n 1)
      hostname=$(tail -n 1000 $deviceInfo2jsonfile | grep "hostName" | sed -e "s/^.*,{/{/" | jq -r .values.hostName | tail -n 1)
      essid=$(tail -n 1000 $deviceInfo2jsonfile | grep "essid" | sed -e "s/^.*,{/{/" | jq -r .values.essid | tail -n 1)
   fi

   jsondata=""


   type=placeID
   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .


   type=placeTag
   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=essid
   result=${essid}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=group
   result=$(cat ${dLcConfig}/${type} 2> /dev/null  | tail -n 1 )
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=hostname
   result=$(hostname)
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=intervalsec
   result=${intervalsec}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=dateindex
   result=${index}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=labeldateut
   result=${lowerdateut0}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=labeldate2
   result=${labeldate2}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=mode
   result=${custom_addinfo1_mode}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=thresholdRssiNEAR
   result=${thresholdRssiNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=thresholdRssi
   result=${thresholdRssi}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfBleRecieved
   result=${numOfBleRecieved}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=NumOfDistinctBleRecieved
   result=${NumOfDistinctBleRecieved}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfBleRecieved_enable
   result=${numOfBleRecieved_enable}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfBleRecieved_disable
   result=${numOfBleRecieved_disable}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfBleRecieved_test
   result=${numOfBleRecieved_test}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=firstut
   result=${firstut}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=lastut
   result=${lastut}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=actualIntervalsec
   result=$((lastut-firstut))
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=recievedsec
   result=${recievedsec}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfFlowingBdaNEAR
   result=${numOfFlowingBdaNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfFlowingBda
   result=${numOfFlowingBda}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfFlowingBdaALL
   result=${numOfFlowingBdaALL}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   type=numOfStayingBdaNEAR
   result=${numOfStayingBdaNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfStayingBda
   result=${numOfStayingBda}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfStayingBdaALL
   result=${numOfStayingBdaALL}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

<<"COMMENT"
   type=numOfFlowingCocoaNEAR
   result=${numOfFlowingCocoaNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   type=numOfFlowingCocoa
   result=${numOfFlowingCocoa}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   type=numOfFlowingCocoaALL
   result=${numOfFlowingCocoaALL}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 
COMMENT

   type=recordedDate
   result=${recordedDate}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   type=SerialNo
   result=${SerialNo}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   echo $jsondata | jq .

   # DBを書き換える
   echo -e "\ndo in 879: sqlite3 ${graphDBfile} \"REPLACE INTO ${tablenameinGraphDBfile} values(${index}, '${jsondata}');\""
   sqlite3 ${graphDBfile} "REPLACE INTO ${tablenameinGraphDBfile} values(${index}, '${jsondata}');"
   result=$? && echo -e "result: "$result

   echo -e "${jsondata}" >> ${prefixGraphJsonfile}.${intervalsec}.last
   #echo -e "${yyyymmddHHMM},\t${jsondata}\n"


   # mqtt 送信
   jsondata=""

   type=labeldate2Per${intervalsec}
   result=${labeldate2}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=thresholdRssiNEAR
   result=${thresholdRssiNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=thresholdRssi
   result=${thresholdRssi}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfBleRecievedPer${intervalsec}
   result=${numOfBleRecieved}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=NumOfDistinctBleRecievedPer${intervalsec}
   result=${NumOfDistinctBleRecieved}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=actualIntervalsecPer${intervalsec}
   result=$((lastut-firstut))
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .


   type=recievedsecPer${intervalsec}
   result=${recievedsec}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfFlowingBdaNEARPer${intervalsec}
   result=${numOfFlowingBdaNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfFlowingBdaPer${intervalsec}
   result=${numOfFlowingBda}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfFlowingBdaALLPer${intervalsec}
   result=${numOfFlowingBdaALL}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   type=numOfStayingBdaNEARPer${intervalsec}
   result=${numOfStayingBdaNEAR}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfStayingBdaPer${intervalsec}
   result=${numOfStayingBda}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c .

   type=numOfStayingBdaALLPer${intervalsec}
   result=${numOfStayingBdaALL}
   [ -z "$result" ] && result="-1"
   #[ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsNum $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   type=SerialNo
   result=${SerialNo}
   #[ -z "$result" ] && result="-1"
   [ -z "$result" ] && result="Null"
   [ "$2" == "debug" ] && echo "result: "$result
   jsondata=$(setJsonToJsonAsTxt $type "$result" "$jsondata")
   [ "$2" == "debug" ] && [ -n "$jsondata" ] && echo $jsondata | jq -c 

   echo $jsondata | jq .
   if [ -n "$jsondata" ];then

      jsondata2="{\"ts\":${lowerdateut0}000,\"values\":${jsondata}}"
      echo $jsondata2 | jq -c .
      resultOfMqtt=$(mosquitto_pub -d -q 1 -h "${THINGSBOARD_HOST_NAME}" -p "${THINGSBOARD_PORT}" -t "v1/devices/me/telemetry" -u "${ACCESS_TOKEN}" -m "${jsondata2}" 2>&1)
      echo $resultOfMqtt | grep -e "Connection Refused" -e "Error"
      if [ $? -eq 0 ];then
         # 失敗
         echo "Failed!"
         echo "1-${mypsid}-${SerialNo}-${ACCESS_TOKEN},${sendtype},"${jsondata2} >> ${jsonfile2tbOld}

         echo -e "${group}\t${placeID}\t$(hostname)\t${stateOfStage}\tble${intervalsec}\t1\t${jsondata2}" >> ${jsonfile2tb}
         echo -e "${group}\t${placeID}\t$(hostname)\t${stateOfStage}\tble${intervalsec}\t1\t${jsondata2}" >> ${jsonfile2tb}.failed
      else 
         # 成功
         echo "Succeed!"
         echo "0-${mypsid}-${SerialNo}-${ACCESS_TOKEN},${intervalsec},"${jsondata2}  >> ${jsonfile2tbOld}
         echo -e "${group}\t${placeID}\t$(hostname)\t${stateOfStage}\tble${intervalsec}\t0\t${jsondata2}" >> ${jsonfile2tb}
      fi
   fi
}


resendFailed2Fiware2023(){
   # 単独実行:  $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u.sh resendFailed2Fiware2023
   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
   echo -e $msg | tee -a ${logfile2}

   prefix_file=${dLcData}/fiwareUploadSendai2023
   failedfile=${prefix_file}.log.failed
   logfile2=${failedfile}.log
   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
   echo -e $msg | tee -a ${logfile2}

   echo "failedfile="$failedfile
   ls -al $failedfile
   
   if [ ! -f ${failedfile} ];then
      echo "no failed data"  | tee -a ${logfile2}
      return 0
   else
      getAccessTokenForFiware2023
      echo "on local, accessToken="$accessToken | tee -a ${logfile2}
      FiwareService=sendai
      FiwareServicePath=/
      while read LINE
      do
         #echo $LINE # | tee -a ${logfile2}
         jsondata=$(echo $LINE | awk '{print $3}')
         # コマンド
         #jsondata='{"identifcation":{"value":"jp.sendai.Blesensor.per300.1000","type":"Text"},"dateObservedFrom":{"value":"2024-04-04T11:40:00+09:00","type":"DateTime"},"dateObservedTo":{"value":"2024-04-04T11:45:00+09:00","type":"DateTime"},"peopleCount_immedate":{"value":21,"type":"number"},"peopleCount_near":{"value":49,"type":"number"},"peopleCount_far":{"value":130,"type":"number"},"peopleOccupancy_immedate":{"value":12.58,"type":"number"},"peopleOccupancy_near":{"value":31.9,"type":"number"},"peopleOccupancy_far":{"value":57.65,"type":"number"},"dateRetrieved":{"value":"2024-04-04T11:47:09+09:00","type":"DateTime"}}'

         myfiwareid2023=$(echo $jsondata | jq -r .identifcation.value)
         intervalsec=$(echo $myfiwareid2023  | sed -e "s/^.*per//" | sed -e "s/\..*$//")
         echo $jsondata > /tmp/sendDataPer${intervalsec}.json
         cat /tmp/sendDataPer${intervalsec}.json | jq -c . #  | tee -a ${logfile2}
#            echo "url_orion_v20_entities="$url_orion_v20_entities | tee -a ${logfile2}
#            echo "myfiwareid2023="$myfiwareid2023 | tee -a ${logfile2}
#            echo "intervalsec="$intervalsec | tee -a ${logfile2}
#            echo "accessToken=$accessToken" | tee -a ${logfile2}
#            echo "FiwareService=$FiwareService" | tee -a ${logfile2}
#            echo "FiwareServicePath=$FiwareServicePath" | tee -a ${logfile2}
            echo "do: curl -X POST \"${url_orion_v20_entities}/${myfiwareid2023}/attrs?type=Blesensor.per${intervalsec}\" \
      -H \"Accept: application/json\" 
      -H \"Content-Type: application/json\" 
      -H \"Authorization:Bearer ${accessToken}\" 
      -H \"Fiware-Service:${FiwareService}\" 
      -H \"Fiware-ServicePath:${FiwareServicePath}\" 
      -sS -k 
      --data @/tmp/sendDataPer${intervalsec}.json > /tmp/resendFailed2Fiware.log
         "


         curl -X POST "${url_orion_v20_entities}/${myfiwareid2023}/attrs?type=Blesensor.per${intervalsec}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -H "Authorization:Bearer ${accessToken}" \
      -H "Fiware-Service:${FiwareService}" \
      -H "Fiware-ServicePath:${FiwareServicePath}" \
      -sS -k \
      --data @/tmp/sendDataPer${intervalsec}.json > /tmp/resendFailed2Fiware.log

         result0=$?
         cat /tmp/resendFailed2Fiware.log | grep "error"
         result1=$?

         if [ $result0 -ne 0 ] || [ $result1 -ne 1 ] ;then
               # 失敗
               echo "Failed"  | tee -a ${logfile2}
               echo "result0="$result0 | tee -a ${logfile2}
               echo "result1="$result1 | tee -a ${logfile2}
               result=1
               cat /tmp/resendFailed2Fiware.log | tee -a ${logfile2}

         else 
               # 成功
               echo "Success"  | tee -a ${logfile2}
               result=0
               # 行削除
               senddate=$(date "+%Y/%m/%d-%H:%M:%S")
#                  echo "do: sed -i \"/$jsondata/d\" ${failedfile}"
               sed -i "/$jsondata/d" ${failedfile}
               jsondatalile=$(echo ${jsondata} | jq -c .)
               echo -e "${senddate}\t${result}\t${jsondatalile}" >> $dLcData/fiwareUploadSendai2023.${intervalsec}.log
               echo -e "${senddate}\t${result}\t${jsondatalile}" >> $dLcData/fiwareUploadSendai2023.${intervalsec}.resend.log
         fi
      done <  ${failedfile}
   fi

   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] finished: $0 $@"
   echo -e $msg | tee -a ${logfile2}

}
resendFailed2TB(){
   # 単独実行:  $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u-sp.sh resendFailed2TB
   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
   echo -e $msg | tee -a ${logfile2}

   logfile2=${jsonfile2tb}.failed.log
   echo "logfile2="$logfile2
   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
   echo -e $msg | tee -a ${logfile2}

   
   if [ ! -f ${jsonfile2tb}.failed ];then
      echo "no failed data"  | tee -a ${logfile2}
      return 0
   else
      ls -al ${jsonfile2tb}.failed
      while read LINE
      do
         echo $LINE #| tee -a ${logfile2}
         # コマンド
         group0=$(echo $LINE | awk '{print $1}')
         placeID0=$(echo $LINE | awk '{print $2}')
         echo group0=$group0
         echo placeID0=$placeID0
         ts=$(echo $jsondata0 | jq -r .ts)
         stateOfStage0=$(echo $LINE | awk '{print $4}')
         hogely0=$(echo $LINE | awk '{print $5}')

         if [ "$group0" != "$group" ] || [ "$placeID0" != "$placeID" ];then
            echo "skip sicne group or placedID are changed!" | tee -a ${logfile2}
            echo $LINE | tee -a ${logfile2}
            targetkeywords="${group0}.*${placeID0}.*$(hostname).*${hogely0}.*${ts}"
            sed -i "/$targetkeywords/d" ${jsonfile2tb}.failed 
            continue
         fi

         ACCESS_TOKEN0=$(echo $LINE | awk '{print $3}' | sed -e "s/focal-//")
         echo "ACCESS_TOKEN0="$ACCESS_TOKEN0
         value=$(echo $LINE | awk '{print $6}')
         jsondata0=$(echo $LINE | sed -e "s@^.*{\"ts@{\"ts@")
         #echo $jsondata0 | jq -c .

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
               echo -e "${resultOfMqtt}"  | tee -a ${logfile2}
               echo "Failed"  | tee -a ${logfile2}
         else 
               # 成功
               echo "Success"
               targetkeywords="${group0}.*${placeID0}.*$(hostname).*${hogely0}.*${ts}"
               beforeWc=$(cat ${jsonfile2tb}.failed | wc -l)               
               sed -i "/$targetkeywords/d" ${jsonfile2tb}.failed 
               afterWc=$(cat ${jsonfile2tb}.failed | wc -l)
#               echo "$beforeWc -> $afterWc"

               echo -e "${group0}\t${placeID0}\t$(hostname)\t${stateOfStage0}\t${hogely0}\t0\t${jsondata0}" >> ${jsonfile2tb}
               result=0
         fi
      done <  ${jsonfile2tb}.failed 
   fi

   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] finished: $0 $@"
   echo -e $msg | tee -a ${logfile2}
}


flow2hourly(){
<<"COM"
   単独実行: $dCProgramsSh/recieveBleBeacon3csv1DB2grapheDB2_u.sh flow2hourly
   ・$dLcData/flowフォルダを作成する
   ・flowデータを
   $dLcData/flow/flow.${yyyymmdd}.${intervalsec}.json
   に追記する。

COM
   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
   echo -e $msg | tee -a ${logfile}



   outdir=${dLcData}/flow
   mkdir -p $outdir

   intervalsecs="300 600 3600"
   for intervalsec in $intervalsecs;do
      #echo "intervalsec=$intervalsec"
      orgfile=${dLcData}/ble.graph.json.${intervalsec}
      echo "orgfile=$orgfile"

      cat $orgfile | jq -r .labeldate2 | cut -c 1-13  | sort | uniq | while read yyyymmddhh 
      do
         yyyymmddhh2=$(echo $yyyymmddhh | sed -e 's/[^0-9]//g')

         echo "yyyymmddhh2="$yyyymmddhh2
         
         outfile=${outdir}/flow${intervalsec}.${yyyymmddhh2}.json
         #echo "outfile=$outfile"
         grep ",\"labeldate2\":\"$yyyymmddhh" $orgfile > $outfile
      done
      # 最後のyyyymmddhh以降を残す
      cp  $orgfile  ${orgfile}.bak
      lastyyyymmddhh=$(cat $orgfile | jq -r .labeldate2 | cut -c 1-13  | sort | tail -n 1)
      echo "lastyyyymmddhh=$lastyyyymmddhh"
      lastyyyymmddhh2=$(echo $lastyyyymmddhh | sed -e 's/[^0-9]//g')
      echo "lastyyyymmddhh2=$lastyyyymmddhh2"
      currentyyyymmddhh=$(date "+%Y%m%d%H")
      echo "currentyyyymmddhh=$currentyyyymmddhh"
      diffh=$(expr $currentyyyymmddhh - $lastyyyymmddhh2)
      echo "diffh=$diffh"
      if [ $diffh -gt 72 ];then
         echo -n >  ${orgfile}
      else
         grep -A 10000 ",\"labeldate2\":\"$lastyyyymmddhh" ${orgfile} > ${orgfile}.new
         mv ${orgfile}.new ${orgfile}
      fi
   done

   msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] finished: $0 $@"
   echo -e $msg | tee -a ${logfile}
}

case $1 in
   resendFailed2Fiware2023)
      resendFailed2Fiware2023 $@
         ;;
   resendFailed2TB)
      resendFailed2TB $@
         ;;
   changeOldFiware2023log2New)
      changeOldFiware2023log2New $@
         ;;
   changeOldlog2New)
      changeOldlog2New $@
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
      start $@
         ;;
   restart)
      stop $@
      start $@
         ;;
   fiwareDownloadSendai2023)
      fiwareDownloadSendai2023 $@
         ;;
   fiwareUploadSendai2023)
      fiwareUploadSendai2023 $@
         ;;
   getAccessTokenForFiware2023)
      getAccessTokenForFiware2023 $@
         ;;         
   flow2hourly)
      flow2hourly $@
         ;;
esac


stepDateUt=$(date +%s)
msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished: "${thisfile}" "$@"\n-----------------------\n"
echo -e $msg | tee -a ${logfile}

