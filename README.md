# CoreOS Packer template for Hetzner Cloud

This template builds a fully functioning Fedora CoreOS image on [Hetzner Cloud](https://hetzner.cloud/?ref=72AtIaBWO7Uw)[^1]

[^1]: Use this link to get €20 cloud balance for free. If you spend money with Hetzner Cloud, I get €10 as kickback.

## Features

- Support for Ignition configs provided via user data
- Automatic configuration of SSH public keys for `core` user
- Hostname configuration
- Support for both `x86 (Intel/AMD)` and `Arm64 (Ampere)`


## Usage

Prerequisites:
- [Packer](https://developer.hashicorp.com/packer/downloads?product_intent=packer)
- [Butane](https://coreos.github.io/butane/getting-started/)

(If you use Nix, just run `nix develop` to get a shell with those tools available)


```sh
export HCLOUD_TOKEN='helpiamtrappedinatokengenerator'
make build
```


## How it works

Image-building itself is straight forward:

1. provision any Linux server & boot in rescue mode
1. stream the CoreOS raw disk image onto `/dev/sda`
1. write a "chainloading" Ignition config (see below)

Now, the biggest challenge is configuring CoreOS systems properly. For Hetzner-provided images, `cloud-init` takes care of those things:

- set the hostname
- configure SSH public keys for `root`
- apply configuration provided as "user data"

CoreOS however only supports Ignition (a `cloud-init` alternative developed by CoreOS), which does not yet know how to talk to the Hetzner metadata/userdata service (PRs are open since 2018 ...).
We work around this by applying a few hacks (see [`files/chain.bu`](./files/chain.bu)):

- Configure a remote Ignition config to be merged into the statically provisioned one. As the source we configure the Hetzner userdata endpoint (`http://169.254.169.254/hetzner/v1/userdata`). This allows us to just use Ignition configs as userdata.
- Write `/etc/hostname` based on data from the Hetzner metadata endpoint (`http://169.254.169.254/hetzner/v1/metadata/hostname`)
- Write a Systemd service that downloads & installs the SSH public keys as authorized keys for the preconfigured `core` user.


## Further Reading

- [Hetzner Cloud Builder for Packer](https://developer.hashicorp.com/packer/integrations/hetznercloud/hcloud)
