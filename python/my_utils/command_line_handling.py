import sys

# If an argument is provided, use it as the value for 'preprocess';
# otherwise, default to "null" (indicating no calling process).
if len(sys.argv) > 1:
    preprocess = sys.argv[1]  # calling process
else:
    preprocess = "null"       # calling process
    
