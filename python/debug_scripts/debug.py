import pyshark
import pandas as pd
import os

def pcap_to_csv_and_analyze(input_file, output_file):
    """
    Converts a binary .pcap file to CSV and analyzes unique MAC addresses.
    
    Args:
        input_file (str): Path to the binary .pcap file
        output_file (str): Path to save the CSV output
    """
    print(f"Reading PCAP file: {input_file}")
    
    # Create directory for output file if it doesn't exist
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Initialize empty lists to store parsed data
    frame_numbers = []
    timestamps = []
    source_macs = []
    dest_macs = []
    protocols = []
    frame_lengths = []
    frame_types = []
    
    # Read the pcap file using pyshark
    try:
        cap = pyshark.FileCapture(input_file)
        
        # Process each packet
        for packet in cap:
            frame_num = packet.frame_info.number
            timestamp = packet.frame_info.time_relative
            
            # Extract MAC addresses - handles different formats based on available layers
            src_mac = 'Unknown'
            dst_mac = 'Unknown'
            protocol = 'Unknown'
            frame_type = 'Unknown'
            
            # Check for Bluetooth LE specific information
            if hasattr(packet, 'btle'):
                if hasattr(packet.btle, 'advertising_address'):
                    src_mac = packet.btle.advertising_address
                elif hasattr(packet.btle, 'master_address'):
                    src_mac = packet.btle.master_address
                    
                if hasattr(packet.btle, 'slave_address'):
                    dst_mac = packet.btle.slave_address
                else:
                    dst_mac = 'Broadcast'
                    
                protocol = 'BTLE'
                
                # Try to get PDU type
                if hasattr(packet.btle, 'advertising_header_pdu_type'):
                    frame_type = packet.btle.advertising_header_pdu_type
            
            # Fallback to other layers if Bluetooth LE info not found
            elif hasattr(packet, 'wlan'):
                src_mac = packet.wlan.sa
                dst_mac = packet.wlan.da
                protocol = 'WLAN'
            elif hasattr(packet, 'eth'):
                src_mac = packet.eth.src
                dst_mac = packet.eth.dst
                protocol = 'ETH'
                
            # Get frame length
            frame_length = packet.frame_info.len
            
            # Append data
            frame_numbers.append(frame_num)
            timestamps.append(timestamp)
            source_macs.append(src_mac)
            dest_macs.append(dst_mac)
            protocols.append(protocol)
            frame_lengths.append(frame_length)
            frame_types.append(frame_type)
            
        cap.close()
        
    except Exception as e:
        print(f"Error processing PCAP file: {e}")
        return None
    
    # Create a DataFrame
    df = pd.DataFrame({
        'Frame': frame_numbers,
        'Timestamp': timestamps,
        'Source_MAC': source_macs,
        'Dest_MAC': dest_macs,
        'Protocol': protocols,
        'Length': frame_lengths,
        'Frame_Type': frame_types
    })
    
    # Save to CSV
    df.to_csv(output_file, index=False)
    print(f"CSV file saved to {output_file}")
    
    # Count unique source MAC addresses
    unique_source_macs = df[df['Source_MAC'] != 'Unknown']['Source_MAC'].nunique()
    print(f"Number of unique source MAC addresses: {unique_source_macs}")
    
    # Count unique destination MAC addresses excluding 'Broadcast' and 'Unknown'
    unique_dest_macs = df[(df['Dest_MAC'] != 'Broadcast') & (df['Dest_MAC'] != 'Unknown')]['Dest_MAC'].nunique()
    print(f"Number of unique destination MAC addresses (excluding Broadcast and Unknown): {unique_dest_macs}")
    
    # Count all unique MAC addresses (source and destination combined)
    source_macs = df[df['Source_MAC'] != 'Unknown']['Source_MAC']
    dest_macs = df[(df['Dest_MAC'] != 'Broadcast') & (df['Dest_MAC'] != 'Unknown')]['Dest_MAC']
    all_macs = pd.concat([source_macs, dest_macs]).unique()
    print(f"Total number of unique MAC addresses: {len(all_macs)}")
    
    # Display the unique MAC addresses (limited to first 20 if there are many)
    print("\nList of unique MAC addresses (up to 20):")
    for mac in sorted(all_macs)[:20]:
        print(mac)
    
    if len(all_macs) > 20:
        print(f"...and {len(all_macs) - 20} more")
    
    return df

# Specified file paths
input_file = "/tmp/ble.dump.0/raw_pcap/bledump_noble-8038fb636550_20250409_140940.pcap"
output_file = "/tmp/ble.dump.0/raw_csv/bledump_noble-8038fb636550_20250409_140940.csv"

# Execute the function
if __name__ == "__main__":
    print("Starting PCAP to CSV conversion and MAC address analysis...")
    df = pcap_to_csv_and_analyze(input_file, output_file)
    if df is not None:
        print("Analysis complete!")
    else:
        print("Analysis failed. Please check the file paths and ensure pyshark is installed.")