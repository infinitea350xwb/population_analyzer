#!/usr/bin/env python3
import os
import sys
import socket
import datetime
import subprocess
import threading
import logging


def install_nrfutil():
    # Install the nrfutil package if it is not already installed
    result = subprocess.run(['nrfutil', 'install', 'ble-sniffer'], capture_output=True, text=True)
    
    if result.returncode != 0:
        print("Error: nrfutil install ble-sniffer failed.", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)
    else:
        print("Success: nrfutil install ble-sniffer succeeded.")
        print(result.stdout)


def setup_capture_directory(directory='ble_packets'):
    # create a directory that stores captured ble packets
    try:
        os.makedirs(directory, exist_ok=True)
        print(f"Directory '{directory}' is ready.")
        return directory
    except Exception as e:
        print(f"Failed to create directory '{directory}': {e}")
        return None
    

def start_ble_sniffer(target_file):
    """
    This function configures sys.argv as if the following command was run:
      nrfutil ble-sniffer sniff --port /dev/ttyACM0 --output-pcap-file <target_file>
    and then calls the main function of the BLE sniffer.
    """
    # Set up the arguments for the BLE sniffer command
    sys.argv = [
        'nrfutil',
        'ble-sniffer',
        'sniff',
        '--port', '/dev/ttyACM0',
        '--output-pcap-file', target_file
    ]
    # Execute the BLE sniffer command; this will block while sniffing.
    ble_sniffer.main()

def main():
    # Set your logfile and bledump directory paths here.
    logfile = "/path/to/your/logfile.log"
    bledumpdir = "/path/to/your/bledumpdir"
    
    # Append the log message.
    with open(logfile, "a") as f:
        f.write("Starting BLE capture (without mkfifo)\n")
    
    # Construct the target file path with a timestamp and the hostname.
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M")
    hostname = socket.gethostname()
    target_file = os.path.join(bledumpdir, f"bledump_{hostname}_{timestamp}.pcap")
    
    # Kill any previous instance of nrfutil.
    # (This uses the system's killall command, so ensure you have the right permissions.)
    subprocess.run(["killall", "nrfutil"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Start the BLE sniffer in a background thread.
    thread = threading.Thread(target=start_ble_sniffer, args=(target_file,), daemon=True)
    thread.start()
    
    print(f"BLE sniffer started. Output will be written to {target_file}")

if __name__ == '__main__':
    main()
