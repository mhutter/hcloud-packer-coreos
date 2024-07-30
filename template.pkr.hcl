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
variable "hcloud_location" {
  type    = string
  default = "fsn1"
}

locals {
  ### Configuration
  coreos_stream = "stable"
  # https://fedoraproject.org/coreos/download/?stream=stable
  coreos_release = "40.20240709.3.1"
  ### /Configuration

  image    = "coreos-${split(".", local.coreos_release)[0]}"
  build_id = "${uuidv4()}"
  build_labels = {
    "image"                = "${local.image}",
    "os-flavor"            = "coreos"
    "coreos/stream"        = "${local.coreos_stream}"
    "coreos/release"       = "${local.coreos_release}"
    "packer.io/build.id"   = "${local.build_id}"
    "packer.io/build.time" = "{{timestamp}}"
    "packer.io/version"    = "{{packer_version}}"
  }
}

# Generate Ignition config from Butane file
data "external-raw" "ignition_config" {
  program = ["butane", "-d", "${path.root}/files", "--strict", "${path.root}/files/chain.bu"]
}

source "hcloud" "aarch64" {
  # We use a fedora image but it really doesn't matter since we're booting in
  # rescue mode anyway
  image        = "fedora-38"
  rescue       = "linux64"
  ssh_username = "root"

  snapshot_labels = local.build_labels
  snapshot_name   = "${local.image}-{{timestamp}}"

  token    = var.hcloud_token
  location = var.hcloud_location
  # The smallest one available so we can later provision any server type
  server_type = "cax11"

  temporary_key_pair_type = "ed25519"
}

source "hcloud" "x86_64" {
  # We use a fedora image but it really doesn't matter since we're booting in
  # rescue mode anyway
  image        = "fedora-38"
  rescue       = "linux64"
  ssh_username = "root"

  snapshot_labels = local.build_labels
  snapshot_name   = "${local.image}-{{timestamp}}"

  token    = var.hcloud_token
  location = var.hcloud_location
  # The smallest one available so we can later provision any server type
  server_type = "cx11"

  temporary_key_pair_type = "ed25519"
}

build {
  sources = ["source.hcloud.aarch64", "source.hcloud.x86_64"]

  provisioner "shell" {
    env = {
      "COREOS_IMAGE" = "https://builds.coreos.fedoraproject.org/prod/streams/${local.coreos_stream}/builds/${local.coreos_release}/${source.name}/fedora-coreos-${local.coreos_release}-metal.${source.name}.raw.xz"
    }
    inline = [
      "set -x",
      # Install CoreOS
      "curl -sL \"$COREOS_IMAGE\" | xz -d | dd of=/dev/sda",
      # Mount the /boot partition
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
}
