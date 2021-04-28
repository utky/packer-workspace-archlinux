variable ssh_username {
  type = string
}
variable ssh_password {
  type = string
}
variable ssh_public_key_file {
  type = string
}
variable ssh_private_key_file {
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

source "virtualbox-iso" "workspace" {
  vm_name = "workspace"
  output_directory = "output"
  guest_os_type = "ArchLinux_64"
  iso_url = var.iso_url
  iso_checksum = "file:${var.iso_checksum_url}"
  guest_additions_mode = "disable"
  firmware = "efi"
  nested_virt = true
  ssh_username = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  shutdown_command = "sudo systemctl poweroff"
  headless = true
  cpus = 2
  memory = 4096
  disk_size = 204800
  hard_drive_interface = "sata"
  #sata_port_count = 1
  http_directory = "boot_scripts"
  boot_wait = "5s"
  boot_command = [
      "<enter><wait10><wait10><wait10><wait10>",
      "/usr/bin/curl -O http://{{ .HTTPIP }}:{{ .HTTPPort }}/enable-ssh.sh<enter><wait5>",
      "/usr/bin/bash ./enable-ssh.sh  '${var.ssh_username}' '${var.ssh_password}' '${chomp(file(var.ssh_public_key_file))}'<enter>"
  ]
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--natpf1", "guestssh,tcp,127.0.0.1,2222,,22"],
    ["modifyvm", "{{.Name}}", "--natpf1", "http1,tcp,127.0.0.1,3000,,3000"],
    ["modifyvm", "{{.Name}}", "--natpf1", "http2,tcp,127.0.0.1,8080,,8080"],
    ["modifyvm", "{{.Name}}", "--natpf1", "http3,tcp,127.0.0.1,8081,,8081"],
    ["modifyvm", "{{.Name}}", "--natpf1", "http4,tcp,127.0.0.1,8082,,8082"]
  ]
}

build {
  sources = ["sources.virtualbox-iso.workspace"]
  provisioner "file" {
    source = var.ssh_private_key_file
    destination = "/home/${var.ssh_username}/.ssh/id_rsa"
  }
  provisioner "shell" {
    inline = ["chmod 600 /home/${var.ssh_username}/.ssh/id_rsa"]
  }
  provisioner "shell" {
    execute_command = "chmod +x {{.Path}}; sudo -S env {{ .Vars }} {{ .Path }}"
    environment_vars = ["MAIN_USER=${var.ssh_username}", "MAIN_PASSWORD=${var.ssh_password}", "SSH_PUBLIC_KEY=${chomp(file(var.ssh_public_key_file))}"]
    scripts = [
      "scripts/setup.sh"
    ]
  }
  post-processor "compress" {
    output = "{{.BuildName}}.zip"
  }
}

