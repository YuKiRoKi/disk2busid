#!/usr/bin/env bash
set -euo pipefail

printf "%-12s %-10s %-10s %-8s %s\n" "DISK" "BUS" "BUS_DIR" "SIZE" "MODEL"
printf "%-12s %-10s %-10s %-8s %s\n" "----" "----" "-------" "----" "-----"

mapfile -t DISKS < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}')

for dev in "${DISKS[@]}"; do
  name="${dev#/dev/}"
  tran="$(lsblk -dn -o TRAN "$dev" 2>/dev/null | head -n1)"
  case "$tran" in
    sata|sas) bus="sata/sas" ;;
    usb)      bus="usb" ;;
    nvme)     bus="nvme" ;;
    *)        bus="${tran:-unknown}" ;;
  esac
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
  # use lsblk to get disk size
  size="$(lsblk -dn -o SIZE "$dev" 2>/dev/null | head -n1)"
  size="${size:-unknown}"
  # use lblk to get the model of harddisk
  model="$(lsblk -dn -o MODEL "$dev" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [[ -z "$model" || "$model" == "?" ]]; then
    model="$(udevadm info --query=property --name="$dev" 2>/dev/null \
      | awk -F= '/^ID_MODEL=/{print $2; exit}' \
      | sed 's/_/ /g')"
  fi
  model="${model:-unknown}"

  # outopt result
  printf "%-12s %-10s %-10s %-8s %s\n" "$dev" "$bus" "$bus_dir" "$size" "$model"
done
