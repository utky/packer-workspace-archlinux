variable data_disk_uuid {
  type = string
}
variable iso_url {
  type = string
  default = "http://ftp.tsukuba.wide.ad.jp/Linux/archlinux/iso/2021.03.01/archlinux-2021.03.01-x86_64.iso"
}
variable iso_checksum_url {
  type = string
  default = "http://ftp.tsukuba.wide.ad.jp/Linux/archlinux/iso/2021.03.01/md5sums.txt"
}
variable ssh_username {
  type = string
  default = "packer"
}
variable ssh_password {
  type = string
}
source "virtualbox-iso" "workspace" {
  output_directory = "output"
  guest_os_type = "ArchLinux_64"
  iso_url = var.iso_url
  iso_checksum = "file:${var.iso_checksum_url}"
  guest_additions_mode = "disable"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  #shutdown_command = "sudo systemctl start poweroff.timer"
  shutdown_command = "sudo systemctl poweroff"
  headless = false
  cpus = 2
  memory = 4096
  disk_size = 7168
  hard_drive_interface = "sata"
  sata_port_count = 2
  http_directory = "boot_scripts"
  boot_wait = "5s"
  boot_command = [
      "<enter><wait10><wait10><wait10><wait10>",
      "/usr/bin/curl -O http://{{ .HTTPIP }}:{{ .HTTPPort }}/enable-ssh.sh<enter><wait5>",
      #"/usr/bin/curl -O http://{{ .HTTPIP }}:{{ .HTTPPort }}/poweroff.timer<enter><wait5>",
      "/usr/bin/bash ./enable-ssh.sh ${var.ssh_password}<enter>"
  ]
  vboxmanage = [
    ["storageattach", "{{.Name}}", "--storagectl", "SATA Controller", "--type", "hdd", "--port", "1", "--device", "0", "--medium", var.data_disk_uuid],
    ["modifyvm", "{{.Name}}", "--natpf1", "guestssh,tcp,127.0.0.1,2222,,22"]
  ]
}

build {
  sources = ["sources.virtualbox-iso.workspace"]
  provisioner "shell" {
    execute_command = "chmod +x {{.Path}}; sudo -S env {{ .Vars }} {{ .Path }}"
    environment_vars = ["DATA_DISK_UUID=${var.data_disk_uuid}"]
    scripts = [
      "scripts/setup.sh"
    ]
  }
}

