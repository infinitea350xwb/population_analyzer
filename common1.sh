####　システム関連の設定ファイル
SerialNo_clientcgf=2024041201
echo "SerialNo_clientcgf: "$SerialNo_clientcgf

<< "COMMENTOUT2"
2022120501 新サーバ・新方式への対応
2022120701 basehostでテスト済
2022120801 tgzservername変数に対応
2022122702 UrlOfDeviceInfoJsonHttpを追加
2022122801 UrlOfNgrokOrderの追加
2022122802 UrlOfsendImportantlogの追加とsendImportantlogの取り込み
2023010601 IsRunning waitforever showps stop を取り込み
2023020801 IsRunning を修正
2023052101 stopで落とすプロセスを修正
2023102201 isRunning での誤検知を注意喚起
2024021901 /zelowa/client/programs のリンク作成に関する間違いを修正
2024041201 shrinkfile によるファイル縮小時にtd-agent-bitでの送信に影響が無いように修正。本来は素直にローテーションすべき？

COMMENTOUT2

# vi $dCProgramsSh/common1.sh

# 旧設定：不要かもしれない
cserver=c001
groupname=g006

orign=c$(date "+%Y%m%d" -r "/zelowa")  # 端末の使用開始年月日。初期化などにより/zelow を再作成すると変更される。

## サーバ識別関連情報
flagUsingServer=1 # サーバ連携の有無（1:有, その他:無（スタンドアローンモード））
genid=g006


getLatestInfoservername=dpu.dais.cds.tohoku.ac.jp

#tgzservername=host131102.dais.cds.tohoku.ac.jp
tgzservername=dpu.dais.cds.tohoku.ac.jp

#backupservername=host131102.dais.cds.tohoku.ac.jp
backupservername=dpu.dais.cds.tohoku.ac.jp
#tdagentservername=host131102.dais.cds.tohoku.ac.jp
tdagentservername=dpu.dais.cds.tohoku.ac.jp
ntpserver=ntp.nict.jp

# td-agentサーバ
UrlOfLogServer="http://${tdagentservername}:8801/valuableLog/$(hostname)"
#UrlOfNgrokOrder='https://host131102.dais.cds.tohoku.ac.jp/common/sensors06_all.php?order=getngrokorder'
UrlOfDeviceInfoJsonHttp="http://${tdagentservername}:8801/deviceInfo/$(hostname)"

maxRetentionDayPeriodOfData=365 # 受信ログなどのデータをローカルに残す最低期間

THINGSBOARD_HOST_NAME=thingsboard2.dais.cds.tohoku.ac.jp



if [ -n "$1" ];then
   preprocess=$1 # 呼び出し元プロセス
else
   preprocess="null" # 呼び出し元プロセス
fi



#ローカルpath関連情報
dBz=/boot/zelowa # : client.cfgやWifi設定（wpa_supplicant.conf.hoge）等の起動時にアクセスしたい設定ファイルを置く。
dZc=/zelowa/client # 全クライアント（ラズパイ）が共用するファイル群を保存するフォルダ
dZcR=${dZc}/ramdisk # RAMディスク
dCConfig=${dZc}/config # 共通設定ファイルなど
dCPrograms=${dZc}/programs # bashスクリプト用保存フォルダ
dCProgramsSh=${dZc}/programs/sh # bashスクリプト用保存フォルダ
dCProgramsPy=${dZc}/programs/py # pythonスクリプト用保存フォルダ

dZcx=/zelowa/clientx # 個々のラズパイ端末毎の専用フォルダ「$(hostname)」が作成されるフォルダ
dLocalClient=${dZcx}/localhost # 自端末の専用フォルダ
dLcLog=${dLocalClient}/log # システムログファイルの保存フォルダ
dLcData=${dLocalClient}/data # 受信ログなどのデータの保存フォルダ
dLcConfig=${dLocalClient}/config # 各種設定ファイルや鍵ファイルの保存フォルダ

dZs=/zelowa/server # 全サーバの共通ディレクトリ
dSConfig=${dZs}/config # 共通設定ファイルなど
dSPrograms=${dZs}/programs # 各種プログラムの保存フォルダ
dSProgramsSh=${dZs}/programs/sh #bashスクリプト用保存フォルダ
dSProgramsPy=${dZs}/programs/py #pythonスクリプト用保存フォルダ

dZsx=/zelowa/serverx # 個々のサーバ端末毎の専用フォルダ「$(hostnmae)」が作成されるフォルダ
dLocalServer=${dZsx}/localhost # 自端末の専用フォルダ
dLsLog=${dLocalServer}/log # システムログファイルの保存フォルダ
dLsData=${dLocalServer}/data # 受信ログなどのデータの保存フォルダ
dLsConfig=${dLocalServer}/config # 各種設定ファイルや鍵ファイルの保存フォルダ

# Intial Settings about this script.
dzg=/zelowa/git-repositories
sourcedir=${dzg}/client-current
gitConfigDir=${sourcedir}/config

customfile="/boot/zelowa/custom"
lastbeaconfile=/tmp/lastbeacon
datafile=${dLcData}/ble.transmit.log

# create soft links
[ ! -f /usr/bin/date ] && ln -s /bin/date /usr/bin/date # check if /usr/bin/date exists, if not create soft link
[ ! -f /usr/sbin/ifconfig ] && ln -s /sbin/ifconfig /usr/sbin/ifconfig
[ ! -f /usr/sbin/iwconfig ] && ln -s /sbin/iwconfig /usr/sbin/iwconfig

# パス
export PATH=$PATH:/usr/sbin/:${dCProgramsSh}:${dCProgramsPh} # add path of executable shell and python scripts to system directory

### BLEビーコン送受信とサーバ連携の設定ファイル


## 発信
# uuidの値
# uuid of mamorio     : b9 40 7f 30 f5 f8 46 6e af f9 25 55 6b 57 fe 6e
# uuid of zelowa_case1: 06 80 68 ff c9 2b 49 c2 a4 10 7f 19 47 e6 d4 9e
#アドバタイズ信号に付与するuuid
prefix_uuid0x='06 80 68 ff c9 2b 49 c2 a4 10 7f 19 47 e6 d4'

# アドバタイズ信号に付与するmajor とminorの値
flagSetMajorMinorByBdaddr=2 # 2: hostnameから設定
#flagSetMajorMinorByBdaddr=1 # 1: BDアドレスから設定
# flagSetMajorMinorByBdaddr=1 # 0: 以下の値で設定
#major=13; minor=46  # それぞれ10進数の値

# txpower c8
txpower='c8'  # FFFFFFc8(符号あり16進数)=-56 [mdb]



# 汎用関数
sendValuableLogviaWebOrder(){
	currentDateUt=$(/usr/bin/date +%s)
	currentDateymd=$(date "+%Y%m%d" --date @${currentDateUt})
	currentDatehms=$(date "+%H%M%S" --date @${currentDateUt})

   log=$@ # 第1引数以降を取り込む
	log2=$(echo $log | sed -e 's/"/ /g')

   if [ -n "$log" ]; then
      #$logが空でない場合
      sendlog=$(adddata2json adddata2json "unixtime" "${currentDateUt}" )
      sendlog=$(adddata2json adddata2json "hostname" "$(hostname)"  "${sendlog}")
      sendlog=$(adddata2json adddata2json "datelabel" "${currentDateymd}_${currentDatehms}"  "${sendlog}")
      sendlog=$(adddata2json adddata2json "log" "${log2}"  "${sendlog}")
   else
      echo "no log message!"
      exit 1
   fi

   echo "send log to logserver of "${UrlOfLogServer}
   echo "send log: "
	echo ${sendlog}
   echo ${sendlog} | jq .
 
   #http経由で送信 (即時反映されるが、サーバが停止していた場合、それで終了してしまう。)
   curl -X POST -d "json=${sendlog}" ${UrlOfLogServer}
   echo "result: "$?

   #ファイル出力+td-agent-bit経由で送信する場合
   #filenameOfsendValuableLog=${dLcLog}/sendValuableLog.log

   echo ${sendlog} >> ${filenameOfsendValuableLog}
   echo "result: "$?
}


adddata2json(){
   #    adddata2json adddata2json "keyname" "4"
   keyname=$2
   input=$3
   #echo "input 0: "$input
   #[ -z "$input" ] && echo "null input" && input="null"
   #echo "input 1: "$input
   #echo "do: echo $input | jq ."
   if echo "$input" | grep -qE '^[0-9.-]+(\.[0-9]*)?$'; then
      # 数値
      input='"'$input'"'
   fi
   if [ "$input" == "false" ] || [ "$input" == "true" ] || [ "$input" == "False" ] || [ "$input" == "True" ] || [ "$input" == "FALSE" ] || [ "$input" == "TRUE" ]; then
      # true of false
      input='"'$input'"'
   fi

   if [ "$input" == "null" ]; then
      # null 
      input='"'$input'"'
   fi
   
   #echo "input2 :"$input
   echo $input | jq . &> /dev/null
   result=$?
   #echo "result: "$result
   if [ $result -ne 0 ] || [ -z "$input" ] ;then
      # nullまたはjson以外の場合
      value="\"$input\""
   else
      # jsonの場合
      value=$input
   fi
   #echo "value 3: "$value
   inputjsondata=$4

   #echo "keyname: " $keyname
   #echo "value: "$value
   #echo "inputjsondata: "$inputjsondata
   #echo "---------"
   if [ -z "${inputjsondata}" ];then
      outputjsondata=$(cat << EOS
   {"${keyname}":${value}}
EOS
)
   else 
      outputjsondata=$(echo ${inputjsondata} | sed -e "s/}$//")","$(cat << EOS
   "${keyname}":${value}}
EOS
)
   fi
   echo $outputjsondata
}

adddata2json2(){
   #    adddata2json adddata2json "keyname" "4"
   #echo "------------adddata2json2:start -------------"
   keyname=$2
   input=$3
   #echo "input 0: "$input
   #[ -z "$input" ] && echo "null input" && input="null"
   #echo "input 1: "$input
   #echo "do: echo $input | jq ."
   if echo "$input" | grep -qE '^[0-9.-]+(\.[0-9]*)?$'; then
      # 数値
      input='"'$input'"'
   fi
   if [ "$input" == "false" ] || [ "$input" == "true" ] || [ "$input" == "False" ] || [ "$input" == "True" ] || [ "$input" == "FALSE" ] || [ "$input" == "TRUE" ]; then
      # true of false
      input='"'$input'"'
   fi
   
   #echo "input2 :"$input
   echo $input | jq . # &> /dev/null
   result=$?
   #echo "result: "$result
   if [ $result -ne 0 ] || [ -z "$input" ] ;then
      # nullまたはjson以外の場合
      value="\"$input\""
   else
      # jsonの場合
      value=$input
   fi
   #echo "value 3: "$value
   inputjsondata=$4

   #echo "keyname: " $keyname
   #echo "value: "$value
   #echo "inputjsondata: "$inputjsondata
   #echo "---------"
   if [ -z "${inputjsondata}" ];then
      outputjsondata=$(cat << EOS
   {"${keyname}":${value}}
EOS
)
   else 
      outputjsondata=$(echo ${inputjsondata} | sed -e "s/}$//")","$(cat << EOS
   "${keyname}":${value}}
EOS
)
   fi
   echo $outputjsondata
   #echo "------------adddata2json2:end -------------"
}

shrinkfile(){
   # ファイルのサイズを縮小するスクリプト
   # 使い方：   shrinkfile $logfile 10000 5000
   # $logfile ファイルの中身が10000行以上の場合、前半を削り5000行まで減らす。
   if [ -L $1 ];then
      filename=$(readlink $1)
   else
      filename=$1
   fi
#   echo 1=$1
#   echo filename=$filename
#   echo "do:    ls -i $filename"
#   ls -i $filename
#   echo "do: wc -l $filename"
#   wc -l $filename

   if [ -f $filename ];then
      upperNumLine=$2
      numline=$(wc ${filename}|awk '{print $1}' )
      if [ $numline -gt $upperNumLine ];then
         tmpfile=$(mktemp)
         shrinkedNumLine=$3
         echo filename: $filename
         echo "Num. of line: "${numline}
         numofdeleteline=$((numline-shrinkedNumLine)) #削除が必要な数
         echo "numofdeleteline=$numofdeleteline"
         sed '1,'${numofdeleteline}'d' ${filename} > ${filename}.bak && echo -n > ${filename} && echo "seccess to shrink: "$filename
         echo $numline " -> " $(wc ${filename} |awk '{print $1}' )
      else
         echo "no need to shrink since numoflines is "${numline}" <= upperNumLine "${upperNumLine}
      fi
   else
      echo "no file:" $filename
   fi
#   echo "do:    ls -i ${filename} ${filename}.bak"
#   ls -i ${filename} ${filename}.bak 2> /dev/null
}


waitNsecSpendFromBoot(){
   echo "now: "${currentDateUt} ", uptime :"${uptimeDateUt} ", diff: " ${diffsec}"[sec]"
   if [ ${diffsec} -lt ${waitsec} ];then
      if [ ${dotype} -eq 0 ]; then
         # 待機時間を経過していない場合は実行せずに終了
         msg="No excute the $0 because the passing time is ${diffsec} [sec] lower than  the waiting time (${waitsec} [sec])"
         echo $msg | tee -a ${logfile}
         exit 1
      else
         # 待機時間を経過していない場合は経過するまで待機して実行
         msg="Waiting to excute the $0 because the passing time is ${diffsec} [sec] lower than  the waiting time (${waitsec} [sec])"
         echo $msg | tee -a ${logfile}
         sleep $(( waitsec - diffsec ))s
      fi
   else
      msg="No need to wait the start because the passing time is ${diffsec} [sec] over than  the waiting time (${waitsec} [sec])"
      echo $msg | tee -a ${logfile}
   fi
}

readwait(){
   echo "this is "$1
   read -p "suru to continue? > " str	#標準入力（キーボード）から1行受け取って変数strにセット
   case "$str" in			#変数strの内容で分岐
   *)
      echo "ok!";;
   esac
}

version(){
   echo  $0", SerialNo: "$SerialNo
}


sendImportantlog(){
   # hostmane
   hostName=$(hostname)
   # 現在日時
   currentDateUt=$(/usr/bin/date +%s)
   currentDate=$(/usr/bin/date -d @${currentDateUt} "+%Y-%m-%d %H:%M:%S")
   # scriptfilename
   scriptfilename=$thisfile
   
   sendlog=$(adddata2json adddata2json "datatype" "aleartlog" )
   sendlog=$(adddata2json adddata2json "hostname" "${hostName}" "$sendlog")
   sendlog=$(adddata2json adddata2json "currentDateUt" "${currentDateUt}" "$sendlog")
   sendlog=$(adddata2json adddata2json "currentDate" "${currentDate}" "$sendlog")
   sendlog=$(adddata2json adddata2json "thisfile" "${thisfile}" "$sendlog")
   sendlog=$(adddata2json adddata2json "msg" "${msg}" "$sendlog" )
   curl -X POST -d "json=${sendlog}" ${UrlOfsendImportantlog}
   echo "done: send aleartlog: "$?
   echo ${sendlog} | jq .

}

waitforever(){
   while true;do
      sleep 600s
   done
}

IsRunning(){
   echo 'do: IsRunning'
   echo '$$: '$$
   echo 'pgrep: ' $(pgrep -fo "$0") 

   if [ $$ -ne $(pgrep -fo "$0") ]; then
      echo "以下のプロセスが起動済みです。" | tee -a ${logfile}
      ps -aux | grep $(pgrep -fo "$0")  | grep -v "grep " | tee -a ${logfile}
      echo "[注意] tail等でログファイルを開いていると「起動済み」と誤検知します。"
      ps -aux | grep $(pgrep -fo "$0")  | grep "tail -f" > /dev/null
      if [ $? -ne 0  ];then
         exit 1
      fi
   fi
}

IsRunning2(){
   echo 'do: IsRunning'
   echo '$$: '$$
   echo "----"
   echo 0=$0
   echo 1=$1
   echo "----"
   pgrep -fl "$1"
   echo "----"
   pgrep -fl "$1" | grep $(basename $0)
   echo "----"

   # 自プロセス以外の起動の有無を確認
   pgrep -fl "$1" | grep  -v $$ | grep $(basename $0)
   if [ $? -eq 0 ];then
      # 二重起動不可
      echo "[$(date "+%Y-%m-%d %H:%M:%S")] $$ Exit 0 since another process is doing now"  | tee -a ${logfile} | tee -a ${logfile}.2
      echo -n "num of doing $1 process: "  | tee -a ${logfile} | tee -a ${logfile}.2
      pgrep -fl "$1" | grep  -v $$ | grep $(basename $0)  | wc -l | tee -a ${logfile} | tee -a ${logfile}.2
      exit 0
   else
      echo "[$(date "+%Y-%m-%d %H:%M:%S")] $$ Start since another process is not doing." | tee -a ${logfile} | tee -a ${logfile}.2
   fi
}


sendValuableLog(){
   msg="Start the sendValuableLog process of "${thisfile} 
   echo $msg | tee -a ${logfile}
   # https://qiita.com/kentaro/items/db9944429ef160987b3a
   log=${@:2:($#-1)} # 第2引数以降を取り込む

   if [ -n "$log" ]; then
      #$logが空でない場合
      sendlog=$(adddata2json adddata2json "unixtime" "${currentDateUt}" )
      sendlog=$(adddata2json adddata2json "hostname" "$(hostname)"  "${sendlog}")
      sendlog=$(adddata2json adddata2json "datelabel" "${currentDateymd}_${currentDatehms}"  "${sendlog}")
      sendlog=$(adddata2json adddata2json "log" "${log}"  "${sendlog}")
   else
      echo "no log message!"
      exit 1
   fi

   echo "send log to logserver of "${UrlOfsendImportantlog}
   echo "send log: "
   echo ${sendlog} | jq .
 
   #http経由で送信 (即時反映されるが、サーバが停止していた場合、それで終了してしまう。)
#   curl -X POST -d "json=${sendlog}" ${UrlOfLogServer}
#   echo "result: "$?

   #ファイル出力+td-agent-bit経由で送信する場合
   filenameOfsendValuableLog=${dLcLog}/sendValuableLog.log

   echo ${sendlog} >> ${filenameOfsendValuableLog}
   echo "result: "$?

   # root@host0321-docker:/home/masao/clientx/td-agent/valuableLogに出力される。
   shrinkfile ${filenameOfsendValuableLog} 100000 50000
}


stop() {
   # 起動中の同名プログラムをすべて終了する
   showps
   psidlist=$(ps -aux | grep $(basename $0) | grep -v grep | grep -v "vi " | grep -v "tail -f "| awk {'print $2'}) # masaoユーザでsudo起動したものもと含める
   for psid in ${psidlist};do
      if [ ${psid} -ne $$ ];then
         command="kill ${psid}"
         ps -aux | grep ${psid}

         echo ${command} | tee -a ${logfile}
         eval ${command} &> /dev/null
         echo "result: "$? | tee -a ${logfile}
      else
         echo "this is myid" ${psid} | tee -a ${logfile}
      fi
   done
}

showps() {
   # 起動中の同名プログラムのプロセス情報を取得・表示する
   echo '$0: '$0
   mypsid=$$ # 自身のプロセスID
   echo "mypsid:" ${mypsid} | tee -a ${logfile}
   # psidlist=$(pgrep -f "$0")
   psidlist=$(ps -aux | grep $(basename $0) | grep -v grep | grep -v "vi " | grep -v "tail -f "| awk {'print $2'}) # masaoユーザでsudo起動したものもと含める
   echo "psidlist:" ${psidlist} | tee -a ${logfile}
   for psid in ${psidlist};do
      ps -aux | grep ${psid} | grep -v "grep"
   done
}

setJsonToJsonAsTxt(){
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

setJsonToJsonAsNum(){
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


# 実行ログ関連
startShlogfile=${dLcLog}/startSh.log
sudo touch ${startShlogfile}
sudo ln -sf ${startShlogfile} /var/log/
sudo ln -sf ${startShlogfile} ${dCProgramsSh}/

# 呼び出したshファイルのログファイル
thisfile=$preprocess

logfile=${dLcLog}/$(basename $thisfile | sed -e "s/.x$//").log
templogfile=/tmp/$(basename $thisfile)/logfile
sudo mkdir -p $(dirname $templogfile)
chmod 777 $(dirname $templogfile)
sudo touch ${logfile}
sudo ln -sf ${sourcedir}/programs ${dZc}
sudo ln -sf ../log/$(basename $thisfile | sed -e "s/.x$//").log ${dCProgramsSh}/$(basename $thisfile | sed -e "s/.x$//").log

sudo chown masao:masao ${startShlogfile} ${logfile}

# 最終OS終了日時（lastdatefile=/zelowa/lastOsTermDateに記載）から60秒以上経過するまで待機
lastdatefile=/zelowa/lastOsTermDate
if [ -f $lastdatefile ];then
   lastOsTermDateUt=$(date +%s --date "$(cat $lastdatefile)") 
   waitSec=120
   
   currentDateUt=$(/usr/bin/date +%s)
   diffUt=$((currentDateUt-lastOsTermDateUt))
   echo $currentDateUt"-"${lastOsTermDateUt}"="$diffUt ", waitSec: "$waitSec
   while [ ${diffUt} -lt $waitSec ] && [ ${diffUt} -gt 0 ];do
      sleep 5
      currentDateUt=$(/usr/bin/date +%s)
      diffUt=$((currentDateUt-lastOsTermDateUt))
      msg="Wait until diffsec: "${diffUt}" greater than "${waitSec}
      echo $msg | tee -a ${logfile}
      # echo $msg > /dev/tty1
   done
   echo "do waitstart: OK!" | tee -a ${logfile}
fi

# ログ削減
shrinkfile $startShlogfile 200000 100000 最後に実行
shrinkfile $logfile 100000 50000 最後に実行



# ログ記録
currentDateUt=$(/usr/bin/date +%s)
currentDateymd=$(date "+%Y%m%d" --date @${currentDateUt})
currentDatehms=$(date "+%H%M%S" --date @${currentDateUt})

sourceSh=$(echo $thisfile | sed -e "s/.sh.x$/.sh/")

sourceSh=$(echo $thisfile | sed -e "s/.sh.x$/.sh/")
if [ -f $sourceSh ];then 
   processSerialNo=$(cat $sourceSh | grep SerialNo= | sed -e "s/.*SerialNo=//" | head -n 1)
else
   processSerialNo=""
fi

sendlog=$(adddata2json adddata2json "unixtime" "${currentDateUt}" )
sendlog=$(adddata2json adddata2json "hostname" "$(hostname)"  "${sendlog}")
sendlog=$(adddata2json adddata2json "datelabel" "${currentDateymd}_${currentDatehms}"  "${sendlog}")
sendlog=$(adddata2json adddata2json "process" "$preprocess"  "${sendlog}")
sendlog=$(adddata2json adddata2json "processSerialNo" "$processSerialNo"  "${sendlog}")

echo -n "startShlog: "
echo $sendlog | sudo tee -a ${startShlogfile}

uptimeDate=$(/usr/bin/uptime -s)
uptimeDateUt=$(/usr/bin/date -d "${uptimeDate}" +%s)
# OS起動からの経過時間
diffsec=$(( currentDateUt - uptimeDateUt ))




