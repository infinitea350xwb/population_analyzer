#!/bin/bash
SerialNo=2025030901

<<"COMMENTOUT"
----
Change tracking
2025030901: 1st
----
- Description:
  This file is a script file for receiving BLE packets using tshark

----
COMMENTOUT
source /zelowa/client/programs/sh/common1.sh $0  # クライアント用設定ファイルを読み取り

msg="\n[$(date "+%Y-%m-%d %H:%M:%S" --date @${currentDateUt})] start: $0 $@"
echo -e $msg | tee -a ${logfile}
echo $0 $@ | tee -a ${logfile}

# 待機時間
waitsec=30
#dotype=0 # 待機時間前の場合は終了
dotype=1 # 待機時間前の場合は待機時間までの待機して実行する
waitNsecSpendFromBoot

arg1=$1
arg2=$2


trap "pkill -P $$" EXIT # 終了時にサブプロセスも一緒に落とすおまじない
#flgDoDualCheck=0 # 0: 多重起動OK
flgDoDualCheck=1 # 1: 二重起動不可、後のを起動させない。Set to 1 if double activation is not allowed.
#flgDoDualCheck=2 # 2: 二重起動不可、前のを強制終了して後のを起動させる。


prefixFilename=ble.$(hostname)

intervalSec=60 # データをマージする時間間隔 [sec]

bledumpdir=/tmp/ble.dump.0
mkdir -p ${bledumpdir}
[ -d ${dLcData}/$(basename ${bledumpdir}) ] && rm -rf ${dLcData}/$(basename ${bledumpdir})
ln -sf ${bledumpdir} ${dLcData}/$(basename ${bledumpdir})


# stateOfStageの状態を確認
cat /boot/zelowa/custom | egrep "^stateOfStage" &> /dev/null  # そもそもstateOfStage設定が存在しない場合
if [ $? -ne 0 ];then
   echo -e "\n# 動作状態\nstateOfStage test # disable / enable / test " >> /boot/zelowa/custom
   stateOfStage=test
else
   stateOfStage=$(cat /boot/zelowa/custom | egrep "^stateOfStage" | tail -n 1 | awk '{print $2}')
fi

if [ $stateOfStage = "disable" ];then
   echo "stateOfStage is disable. stop and exit." | tee -a ${logfile}
   stop
   exit 0
fi

start(){
   # --- start process ---
   msg="Start the start process of "${thisfile}" "$@ 
   echo $msg | tee -a ${logfile}

   # 実行前に既存プロセスや既存ファイルを処理する
   # tshark（キャプチャ）を一旦終了。
   if [ $flgDoDualCheck -eq 1 ];then
      IsRunning #| tee -a ${logfile}
   elif [ $flgDoDualCheck -eq 2 ];then
      stop # | tee -a ${logfile} # 古いプロセスを一旦終了
   fi
#   sleep 120s
#   exit 0
   blecapwithRaw_without_mkfifo
#   blecapwithRaw # 注意：ここでバッググラウンドジョブにすると、親スクリプト終了時にも一緒に落ちずに生き残るので注意   
   waitforever
}

blecapwithRaw(){
   echo "start the blecapwithRaw processes"  | tee -a ${logfile}
   
<<COMMENT

targetfile=/tmp/blecapture
rm $targetfile
nrfutil ble-sniffer sniff --port /dev/ttyACM0 --output-pcap-file ${targetfile}
[ctrl]-c

ls -al ${targetfile}

# ・特定のフィールド名を探す
tshark -r ${targetfile} -T pdml | grep -i "rssi" | more

   Running as user "root" and group "root". This could be dangerous.
    <field name="nordic_ble.rssi" showname="RSSI: -66 dBm" size="1" pos="10" show="-66" value="42"/>
    <field name="nordic_ble.rssi" showname="RSSI: -46 dBm" size="1" pos="10" show="-46" value="2e"/>
    <field name="nordic_ble.rssi" showname="RSSI: -53 dBm" size="1" pos="10" show="-53" value="35"/>

tshark -r ${targetfile} -T pdml | grep -i "btcommon" | more
   Running as user "root" and group "root". This could be dangerous.
    <field name="frame.protocols" showname="Protocols in frame: nordic_ble:btle:btcommon" size="0" pos="0" show="nordic_ble:btle:btcommon"/>
    <field name="btcommon.eir_ad.advertising_data" showname="Advertising Data" size="31" pos="29" show="" value="">
      <field name="btcommon.eir_ad.entry" showname="Manufacturer Specific" size="31" pos="29" show="" value="">
        <field name="btcommon.eir_ad.entry.length" showname="Length: 30" size="1" pos="29" show="30" value="1e"/>
        <field name="btcommon.eir_ad.entry.type" showname="Type: Manufacturer Specific (0xff)" size="1" pos="30" show="0xff" value="ff"/>
        <field name="btcommon.eir_ad.entry.company_id" showname="Company ID: Microsoft (0x0006)" size="2" pos="31" show="0x0006" value="0600"/>


tshark -r ${targetfile} -T fields -E separator=, -e btle.advertising_address -e frame.time_epoch -e nordic_ble.rssi -e btcommon.eir_ad.entry.data -e btcommon.eir_ad.entry.service_data -e btcommon.eir_ad.entry.uuid_16 | head

   Running as user "root" and group "root". This could be dangerous.
   3e:ee:64:7e:06:24,1741497692.647456000,-66,0109202230bff0dc9ad0ed53279cb7f774b7a9d60d6a6f65674247,
   3e:ee:64:7e:06:24,1741497692.648035000,-46,0109202230bff0dc9ad0ed53279cb7f774b7a9d60d6a6f65674247,
   5d:c5:f9:28:85:dc,1741497692.661321000,-53,010920021ecc68e0c92a3fa142f50d24ddf65a8342799b0545c518,
   5d:c5:f9:28:85:dc,1741497692.661860000,-65,010920021ecc68e0c92a3fa142f50d24ddf65a8342799b0545c518,
   5d:c5:f9:28:85:dc,1741497692.662400000,-67,010920021ecc68e0c92a3fa142f50d24ddf65a8342799b0545c518,
   c7:88:61:c7:88:62,1741497692.668798000,-62,010001c78861c7886200,
   c7:88:61:c7:88:62,1741497692.669524000,-64,010001c78861c7886200,
   c7:88:61:c7:88:62,1741497692.670252000,-64,010001c78861c7886200,


# リアルタイム解析
capfile=/tmp/mkfifo
mkfifo ${capfile}
ACMdevice="/dev/ttyACM0"
sudo nrfutil ble-sniffer sniff --port ${ACMdevice} --output-pcap-file ${capfile} &

capfile=/tmp/mkfifo
ls -al $capfile

cat ${capfile} |  tshark -l -r - # 成功！
   4728   7.569817 c7:88:61:c7:88:62 → Broadcast    LE LL 61 ADV_IND
   4729   7.578457 75:e8:4a:48:fd:f8 → Broadcast    LE LL 63 ADV_NONCONN_IND
   4730   7.578996 75:e8:4a:48:fd:f8 → Broadcast    LE LL 63 ADV_NONCONN_IND
   4731   7.600792 69:2c:79:1d:88:d5 → Broadcast    LE LL 49 ADV_IND
   4732   7.601831 69:2c:79:1d:88:d5 → Broadcast    LE LL 49 ADV_IND

cat ${capfile} |  tshark -T fields -e btle.advertising_address -e frame.time_epoch -e nordic_ble.rssi -e btcommon.eir_ad.entry.data -e btcommon.eir_ad.entry.service_data -e btcommon.eir_ad.entry.uuid_16 
        1741499456.519530379
        1741499456.558384269
        1741499456.569060759
        1741499456.572025666
        1741499456.583581253
        1741499456.614135737

frame.time_epoc以外は表示されない？
mkfileを経由して保存したファイルからも、frame.time_epoc以外は取り出せない？ 取り出せる場合もある？リアルタイム処理の場合のみ失敗？


tshark -r ./ble* -T fields -E separator=, -e btle.advertising_address -e frame.time_epoch -e nordic_ble.rssi -e btcommon.eir_ad.entry.data -e btcommon.eir_ad.entry.service_data -e btcommon.eir_ad.entry.uuid_16
COMMENT

targetfile=/tmp/blecapture
ls -al ${targetfile} | grep prw &> /dev/null
if [ $? -ne 0 ];then
   rm ${targetfile}  &> /dev/null
   mkfifo ${targetfile}
fi
killall nrfutil
nrfutil ble-sniffer sniff --port /dev/ttyACM0 --output-pcap-file ${targetfile} &

cat ${targetfile} | tshark -w ${bledumpdir}/bledump_$(hostname)_$(date "+%Y%m%d_%H%M") -b duration:${intervalSec} -q &   # 1分ごとに書き出す

}

blecapwithRaw_without_mkfifo(){
   echo "start the blecapwithRaw_without_mkfifo processes"  | tee -a ${logfile}
   
<<COMMENT

targetfile=/tmp/blecapture
rm $targetfile
nrfutil ble-sniffer sniff --port /dev/ttyACM0 --output-pcap-file ${targetfile}
[ctrl]-c

ls -al ${targetfile}

# ・特定のフィールド名を探す
tshark -r ${targetfile} -T pdml | grep -i "rssi" | more

   Running as user "root" and group "root". This could be dangerous.
    <field name="nordic_ble.rssi" showname="RSSI: -66 dBm" size="1" pos="10" show="-66" value="42"/>
    <field name="nordic_ble.rssi" showname="RSSI: -46 dBm" size="1" pos="10" show="-46" value="2e"/>
    <field name="nordic_ble.rssi" showname="RSSI: -53 dBm" size="1" pos="10" show="-53" value="35"/>

tshark -r ${targetfile} -T pdml | grep -i "btcommon" | more
   Running as user "root" and group "root". This could be dangerous.
    <field name="frame.protocols" showname="Protocols in frame: nordic_ble:btle:btcommon" size="0" pos="0" show="nordic_ble:btle:btcommon"/>
    <field name="btcommon.eir_ad.advertising_data" showname="Advertising Data" size="31" pos="29" show="" value="">
      <field name="btcommon.eir_ad.entry" showname="Manufacturer Specific" size="31" pos="29" show="" value="">
        <field name="btcommon.eir_ad.entry.length" showname="Length: 30" size="1" pos="29" show="30" value="1e"/>
        <field name="btcommon.eir_ad.entry.type" showname="Type: Manufacturer Specific (0xff)" size="1" pos="30" show="0xff" value="ff"/>
        <field name="btcommon.eir_ad.entry.company_id" showname="Company ID: Microsoft (0x0006)" size="2" pos="31" show="0x0006" value="0600"/>


tshark -r ${targetfile} -T fields -E separator=, -e btle.advertising_address -e frame.time_epoch -e nordic_ble.rssi -e btcommon.eir_ad.entry.data -e btcommon.eir_ad.entry.service_data -e btcommon.eir_ad.entry.uuid_16 | head

   Running as user "root" and group "root". This could be dangerous.
   3e:ee:64:7e:06:24,1741497692.647456000,-66,0109202230bff0dc9ad0ed53279cb7f774b7a9d60d6a6f65674247,
   3e:ee:64:7e:06:24,1741497692.648035000,-46,0109202230bff0dc9ad0ed53279cb7f774b7a9d60d6a6f65674247,
   5d:c5:f9:28:85:dc,1741497692.661321000,-53,010920021ecc68e0c92a3fa142f50d24ddf65a8342799b0545c518,
   5d:c5:f9:28:85:dc,1741497692.661860000,-65,010920021ecc68e0c92a3fa142f50d24ddf65a8342799b0545c518,
   5d:c5:f9:28:85:dc,1741497692.662400000,-67,010920021ecc68e0c92a3fa142f50d24ddf65a8342799b0545c518,
   c7:88:61:c7:88:62,1741497692.668798000,-62,010001c78861c7886200,
   c7:88:61:c7:88:62,1741497692.669524000,-64,010001c78861c7886200,
   c7:88:61:c7:88:62,1741497692.670252000,-64,010001c78861c7886200,

tshark -r ${targetfile} -T fields -E separator=,  -e frame.time_epoch | sed -e "s/\..*//" | uniq | sort


COMMENT

targetfile=${bledumpdir}/bledump_$(hostname)_$(date "+%Y%m%d_%H%M").pcap
killall nrfutil
nrfutil ble-sniffer sniff --port /dev/ttyACM0 --output-pcap-file ${targetfile} &

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

case $1 in
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
      # $dCProgramsSh/recieveBleBeacon3dump_x86.sh restart
      # * * * * * $dCProgramsSh/recieveBleBeacon3dump_x86.sh restart # 受信ログを1分毎に分割
      stop $@
      start $@
         ;;
esac

stepDateUt=$(/usr/bin/date +%s)
msg="[$(date "+%Y-%m-%d %H:%M:%S" --date @${stepDateUt})] Finished: "${thisfile}" "$@"\n-----------------------\n"
echo -e $msg | tee -a ${logfile}


