terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.7"
    }
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Вміст публічного SSH ключа"
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Базовий образ Ubuntu
resource "libvirt_volume" "ubuntu" {
  name   = "ubuntu-22.04-base.qcow2"
  pool   = "default"
  target = {
    format = { type = "qcow2" }
  }
  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    }
  }
}

# Системні диски для двох машин
resource "libvirt_volume" "vm_disk" {
  count    = 2
  name     = "vm-disk-${count.index}.qcow2"
  pool     = "default"
  capacity = 10737418240 
  target   = { format = { type = "qcow2" } }
  backing_store = {
    path   = libvirt_volume.ubuntu.path
    format = { type = "qcow2" }
  }
}

# Cloud-Init диски для двох машин
resource "libvirt_cloudinit_disk" "commoninit" {
  count = 2
  name  = "commoninit-${count.index}.iso"

  user_data = <<-EOF
#cloud-config
users:
  - name: toros
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - "${var.ssh_public_key}"

chpasswd:
  list: |
    toros:1vlad1t2
  expire: false

ssh_pwauth: true

packages:
  - openssh-server

runcmd:
  - [ sed, -i, 's/PasswordAuthentication no/PasswordAuthentication yes/g', /etc/ssh/sshd_config ]
  - [ systemctl, restart, ssh ]
EOF

  meta_data = <<-EOF
instance-id: vm-00${count.index}
local-hostname: vm-${count.index}
EOF
}

resource "libvirt_volume" "commoninit_volume" {
  count = 2
  name  = "commoninit-vol-${count.index}.iso"
  pool  = "default"
  create = {
    content = {
      url = libvirt_cloudinit_disk.commoninit[count.index].path
    }
  }
}
# Створення двох віртуальних машин
resource "libvirt_domain" "app_server" {
  count       = 2
  name        = "vm-${count.index}"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"
  running     = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.vm_disk[count.index].pool
            volume = libvirt_volume.vm_disk[count.index].name
          }
        }
        driver = { type = "qcow2" }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.commoninit_volume[count.index].pool
            volume = libvirt_volume.commoninit_volume[count.index].name
          }
        }
        target = { dev = "sda", bus = "sata" }
      }
    ]

    interfaces = [
      {
        source = {
          network = { network = "default" }
        }
        model = { type = "virtio" }
        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]

    consoles = [
      {
        type = "pty"
        target = { type = "serial", port = "0" }
      }
    ]
  }
}

# Отримання адрес для автоматичного інвентарю
data "libvirt_domain_interface_addresses" "app_server_ip" {
  count  = 2
  domain = libvirt_domain.app_server[count.index].name
  source = "lease"
}

# Генерація файлу inventory.ini для Ansible
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [app_node]
    ${data.libvirt_domain_interface_addresses.app_server_ip[0].interfaces[0].addrs[0].addr} ansible_user=toros

    [monitor_node]
    ${data.libvirt_domain_interface_addresses.app_server_ip[1].interfaces[0].addrs[0].addr} ansible_user=toros

    [all:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
  filename = "../ansible/inventory.ini"
}

output "vm_ips" {
  value = data.libvirt_domain_interface_addresses.app_server_ip[*].interfaces[0].addrs[0].addr
}
