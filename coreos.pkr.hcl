packer {
  required_plugins {
    external = {
      version = ">= 0.0.2"
      source  = "github.com/joomcode/external"
    }
    hcloud = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/hcloud"
    }
  }
}

variable "hcloud_token" {
  type      = string
  default   = env("HCLOUD_TOKEN")
  sensitive = true
}

variable "coreos_stream" {
  type    = string
  default = "stable"
}
variable "coreos_release" {
  type    = string
  default = "38.20230806.3.0"
}

data "external-raw" "ignition_config" {
  program = ["butane", "-d", "${path.cwd}/files", "--strict", "${path.cwd}/files/chain.bu"]
}

locals {
  image        = "coreos-${split(".", var.coreos_release)[0]}"
  coreos_image = "https://builds.coreos.fedoraproject.org/prod/streams/${var.coreos_stream}/builds/${var.coreos_release}/x86_64/fedora-coreos-${var.coreos_release}-metal.x86_64.raw.xz"
  build_id     = "${uuidv4()}"
  build_labels = {
    "image"                = "${local.image}",
    "os-flavor"            = "coreos"
    "coreos/stream"        = "${var.coreos_stream}"
    "coreos/release"       = "${var.coreos_release}"
    "packer.io/build.id"   = "${local.build_id}"
    "packer.io/build.time" = "{{timestamp}}"
    "packer.io/version"    = "{{packer_version}}"
  }
}

source "hcloud" "coreos" {
  image           = "fedora-38"
  location        = "fsn1"
  server_type     = "cx11"
  snapshot_labels = local.build_labels
  snapshot_name   = "coreos-{{ timestamp }}"
  ssh_username    = "root"
  token           = var.hcloud_token
  rescue          = "linux64"
}

build {
  sources = ["source.hcloud.coreos"]

  provisioner "shell" {
    inline = [
      "set -x",
      "curl -sL '${local.coreos_image}' | xz -d | dd of=/dev/sda",
      "mount /dev/sda3 /mnt",
      "mkdir -p /mnt/ignition"
    ]
  }
  provisioner "file" {
    content     = data.external-raw.ignition_config.result
    destination = "/mnt/ignition/config.ign"
  }
  provisioner "shell" {
    inline = [
      "set -x",
      "umount /mnt",
      "sync",
      "echo Installation complete",
    ]
  }

  post-processor "manifest" {
    custom_data = local.build_labels
  }
}
