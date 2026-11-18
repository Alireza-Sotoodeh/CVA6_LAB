fine one file:
```bash
find "$PWD" -type f -name "*pkg_name.sv*"
```

find multiple files:
```bash
raw="xil_defaultlib.instr_queue, xil_defaultlib.instr_scan, xil_defaultlib.bht2lvl, xil_defaultlib.bht, xil_defaultlib.btb"

for item in $(echo "$raw" | tr ',' ' ' | sed 's/xil_defaultlib\.//g'); do
    echo "=== $item ==="
    find -L "$PWD" -iname "*${item}*"
done
```