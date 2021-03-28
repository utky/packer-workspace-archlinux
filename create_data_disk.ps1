if ($args.Length -ne 1)
{
  echo "Please specify data disk path"
  exit
}

$data_disk_path=$args[0]

if (Test-Path -Path "$data_disk_path" -PathType Leaf) {
  echo "Output file already exists: $data_disk_path"
  exit
}

$disk_space="204800"
$disk_type="VMDK"

$createmediumOutput = & "${env:vbox_msi_install_path}VBoxManage.exe" "createmedium" "disk" "--filename" "$data_disk_path" "--size" $disk_space "--format" $disk_type
echo $createmediumOutput | Select-String -Pattern "UUID" -outvariable uuidLine
$uuid = $uuidLine.Line.Split(":")[1].Trim()
echo $uuid
Set-Content -Path "vbox.pkrvars.hcl" -Value "data_disk_uuid = ""${uuid}"""
