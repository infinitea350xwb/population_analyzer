# 発信 (Transmission configuration)

# uuidの値:
# uuid of mamorio     : "b9 40 7f 30 f5 f8 46 6e af f9 25 55 6b 57 fe 6e"
# uuid of zelowa_case1: "06 80 68 ff c9 2b 49 c2 a4 10 7f 19 47 e6 d4 9e"

# アドバタイズ信号に付与するuuid
prefix_uuid0x = '06 80 68 ff c9 2b 49 c2 a4 10 7f 19 47 e6 d4'

# アドバタイズ信号に付与するmajor と minor の値
flagSetMajorMinorByBdaddr = 2  # 2: hostnameから設定
# Alternatively, you might use:
# flagSetMajorMinorByBdaddr = 1  # 1: BDアドレスから設定
# Or use fixed values:
# flagSetMajorMinorByBdaddr = 0  # and then set major and minor explicitly:
# major = 13
# minor = 46

# txpower c8
txpower = 'c8'  # FFFFFFc8 (符号あり16進数) = -56 [mdb]