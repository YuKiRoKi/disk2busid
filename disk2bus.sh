#!/usr/bin/env bash
set -euo pipefail

printf "%-12s %-10s %-10s %s\n" "DISK" "INTERFACE" "BUS" "MODEL"
printf "%-12s %-10s %-10s %s\n" "----" "---------" "---" "-----"

# 列出所有物理磁盘：SATA/SAS/USB(/dev/sdX) + NVMe(/dev/nvmeXn1)
mapfile -t DISKS < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}')

for dev in "${DISKS[@]}"; do
  name="${dev#/dev/}"

  # 1) BUS 类型
  # lsblk 的 TRAN 输出：sata / sas / usb / nvme / ...
  tran="$(lsblk -dn -o TRAN "$dev" 2>/dev/null | head -n1)"
  case "$tran" in
    sata|sas) bus="sata/sas" ;;
    usb)      bus="usb" ;;
    nvme)     bus="nvme" ;;
    *)        bus="${tran:-unknown}" ;;
  esac

  # 2) BUS_DIR（你的原逻辑大概率是从 sysfs 找父级；这里给一个通用写法）
  # /sys/block/<name>/device 可能在不同总线下层级不同，所以向上找一个像 ataX/usbX/nvmeX 的目录名
  sys_path="$(readlink -f "/sys/block/$name")"
  bus_dir="$(
    awk -v p="$sys_path" 'BEGIN{
      n=split(p, a, "/");
      for(i=n;i>0;i--){
        if(a[i] ~ /^(ata|usb|nvme)[0-9]+/){ print a[i]; exit }
      }
      print "-"
    }'
  )"

  # 3) MODEL
  model="$(lsblk -dn -o MODEL "$dev" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [[ -z "$model" || "$model" == "?" ]]; then
    # fallback: udevadm
    model="$(udevadm info --query=property --name="$dev" 2>/dev/null \
      | awk -F= '/^ID_MODEL=/{print $2; exit}' \
      | sed 's/_/ /g')"
  fi
  model="${model:-unknown}"

  printf "%-12s %-10s %-10s %s\n" "$dev" "$bus" "$bus_dir" "$model"
done

