import shutil
import os

def shrinkfile(filename, upper_num_lines, shrinked_num_lines):
    """
    Shrinks a file by deleting lines from the beginning if it exceeds upper_num_lines.
    
    Args:
        filename (str): The path to the file.
        upper_num_lines (int): The threshold beyond which the file will be shrunk.
        shrinked_num_lines (int): The number of lines to keep after shrinking.
    
    Returns:
        None
    """
    # Resolve symbolic links
    if os.path.islink(filename):
        filename = os.readlink(filename)

    # Check if the file exists
    if not os.path.isfile(filename):
        print(f"Error: File not found - {filename}")
        return
    
    # Count the number of lines in the file
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    num_lines = len(lines)
    
    # If file size is within the limit, no need to shrink
    if num_lines <= upper_num_lines:
        print(f"No need to shrink: {num_lines} lines (<= {upper_num_lines})")
        return

    # Calculate how many lines to delete
    num_of_delete_lines = num_lines - shrinked_num_lines

    print(f"Shrinking {filename}...")
    print(f"Original lines: {num_lines}")
    print(f"Deleting first {num_of_delete_lines} lines")

    # Backup the original file before modifying it
    backup_filename = filename + ".bak"
    shutil.copy(filename, backup_filename)

    # Write the remaining lines back to the file
    with open(filename, 'w', encoding='utf-8') as f:
        f.writelines(lines[num_of_delete_lines:])

    new_num_lines = sum(1 for _ in open(filename, 'r', encoding='utf-8'))
    print(f"Success! File reduced from {num_lines} to {new_num_lines} lines.")
    
def remove_if_exists(path):
    """
    Helper: Remove a file or symlink if it exists.
    """
    if os.path.lexists(path):
        # If it's a file or a symlink, remove it.
        if os.path.isfile(path) or os.path.islink(path):
            os.remove(path)
        # If it's a directory, remove it recursively.
        elif os.path.isdir(path):
            shutil.rmtree(path)
            
