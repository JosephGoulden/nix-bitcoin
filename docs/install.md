Preliminary steps
---
Get a machine to deploy nix-bitcoin on.
This could be a VirtualBox, a machine that is already running [NixOS](https://nixos.org/nixos/manual/index.html) or a cloud provider.
Have a look at the options in the [NixOps manual](https://nixos.org/nixops/manual/).

# Tutorials
1. [Install and configure NixOS for nix-bitcoin on VirtualBox](#tutorial-install-and-configure-nixos-for-nix-bitcoin-on-virtualbox)
2. [Install and configure NixOS for nix-bitcoin on your own hardware](#tutorial-install-and-configure-nixos-for-nix-bitcoin-on-your-own-hardware)

Tutorial: install and configure NixOS for nix-bitcoin on VirtualBox
---
Requires at least 250GB of free disk space.

## 1. VirtualBox installation
The following steps are meant to be run on the machine you deploy from, not the machine you deploy to.

1. Add virtualbox.list to /etc/apt/sources.list.d (Debian 9 stretch)

	```
	echo "deb http://download.virtualbox.org/virtualbox/debian stretch contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
	```

2. Add Oracle VirtualBox public key

	```
	wget https://www.virtualbox.org/download/oracle_vbox_2016.asc
	gpg2 oracle_vbox_2016.asc
	```
	Proceed _only_ if fingerprint reads B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF

	```
	sudo apt-key add oracle_vbox_2016.asc
	```

3. Install virtualbox-5.2

	```
	sudo apt-get update
	sudo apt-get install virtualbox-5.2
	```

3. Create Host Adapter in VirtualBox

	```
	Open VirtualBox
	File -> Host Network Manager -> Create
	```
	This should create a host adapter named vboxnet0

## 2. Nix installation
The following steps are meant to be run on the machine you deploy from, not the machine you deploy to.

1. Install Dependencies (Debian 9 stretch)

	```
	sudo apt-get install curl git gnupg2 dirmngr
	```

2. Install latest Nix in "multi-user mode" with GPG Verification

	```
	curl -o install-nix-2.2.1 https://nixos.org/nix/install
	curl -o install-nix-2.2.1.sig https://nixos.org/nix/install.sig
	gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
	gpg2 --verify ./install-nix-2.2.1.sig
	sh ./install-nix-2.2.1 --daemon
	```
	Then follow the instructions. Open a new terminal window when you're done.

	If you get an error similar to
	```
	error: cloning builder process: Operation not permitted
	error: unable to start build process
	/tmp/nix-binary-tarball-unpack.hqawN4uSPr/unpack/nix-2.2.1-x86_64-linux/install: unable to install Nix into your default profile
	```
	you're likely not installing as multi-user because you forgot to pass the `--daemon` flag to the install script.

## 3. Nixops deployment

1. Clone this project

	```
	cd
	git clone https://github.com/jonasnick/nix-bitcoin
	cd ~/nix-bitcoin
	```

2. Setup environment

	```
	nix-shell
	```
3. Create nixops deployment in nix-shell.

	```
	nixops create network/network.nix network/network-vbox.nix -d bitcoin-node
	```

4. Adjust configuration by opening `configuration.nix` and removing FIXMEs. Enable/disable the modules you want in `configuration.nix`.

5. Deploy Nixops in nix-shell

	```
	nixops deploy -d bitcoin-node
	```

	This will now create a nix-bitcoin node on the target machine.

6. Nixops automatically creates an ssh key for use with `nixops ssh`. Access `bitcoin-node` through ssh in nix-shell with

	```
	nixops ssh operator@bitcoin-node
	```

See [usage.md](usage.md) for usage instructions, such as how to update.

Tutorial: install and configure NixOS for nix-bitcoin on your own hardware
---
## 1. NixOS installation

This is borrowed from the [NixOS manual](https://nixos.org/nixos/manual/index.html#ch-installation). Look there for more information.

1. Obtain latest NixOS. For example:

	```
	wget https://releases.nixos.org/nixos/18.09/nixos-18.09.2257.235487585ed/nixos-graphical-18.09.2257.235487585ed-x86_64-linux.iso
	```

2. Write NixOS iso to install media (USB/CD). For example:

	```
	dd if=nixos-graphical-18.09.2257.235487585ed-x86_64-linux.iso of=/dev/sdX
	```
	Replace /dev/sdX with the correct device name. You can find this using `sudo fdisk -l`

3. Boot the system

	You will have to find out if your hardware uses UEFI or Legacy Boot for the next step.

4. Option 1: Partition and format for UEFI

	```
	parted /dev/sda -- mklabel gpt
	parted /dev/sda -- mkpart primary 512MiB -8GiB
	parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
	parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
	parted /dev/sda -- set 3 boot on
	mkfs.ext4 -L nixos /dev/sda1
	mkswap -L swap /dev/sda2
	mkfs.fat -F 32 -n boot /dev/sda3
	mount /dev/disk/by-label/nixos /mnt
	mkdir -p /mnt/boot
	mount /dev/disk/by-label/boot /mnt/boot
	swapon /dev/sda2
	```

4. Option 2: Partition and format for Legacy Boot (MBR)

	```
	parted /dev/sda -- mklabel msdos
	parted /dev/sda -- mkpart primary 1MiB -8GiB
	parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
	mkfs.ext4 -L nixos /dev/sda1
	mkswap -L swap /dev/sda2
	mount /dev/disk/by-label/nixos /mnt
	swapon /dev/sda2
	```

5. Generate NixOS config

	```
	nixos-generate-config --root /mnt
	nano /mnt/etc/nixos/configuration.nix
	```

	Option 1: Edit NixOS configuration for UEFI

	```
	{ config, pkgs, ... }: {
	  imports = [
	    # Include the results of the hardware scan.
	    ./hardware-configuration.nix
	  ];

	  boot.loader.systemd-boot.enable = true;

	  # Note: setting fileSystems is generally not
	  # necessary, since nixos-generate-config figures them out
	  # automatically in hardware-configuration.nix.
	  #fileSystems."/".device = "/dev/disk/by-label/nixos";
	
	  # Enable the OpenSSH server.
	  services.openssh = {
	    enable = true;
	    permitRootLogin = "yes";
	  };
	}
	```

	Option 2: Edit NixOS configuration for Legacy Boot (MBR)

	```
	{ config, pkgs, ... }: {
	  imports = [
	    # Include the results of the hardware scan.
	    ./hardware-configuration.nix
	  ];
	
	  boot.loader.grub.device = "/dev/sda"; 
	
	  # Note: setting fileSystems is generally not
	  # necessary, since nixos-generate-config figures them out
	  # automatically in hardware-configuration.nix.
	  #fileSystems."/".device = "/dev/disk/by-label/nixos";
	
	  # Enable the OpenSSH server.
	  services.openssh = {
	    enable = true;
	    permitRootLogin = "yes";
	  };
	}
	```

6. Do the installation

	```
	nixos-install
	```
	Set root password
	```
	setting root password...
	Enter new UNIX password: 
	Retype new UNIX password:
	```

7. If everything went well

	```
	reboot
	```

## 2. nix-bitcoin installation

On the machine you are deploying from:

1. Install Dependencies (Debian 9 stretch)

	```
	sudo apt-get install curl git gnupg2 dirmngr
	```

2. Install Latest Nix with GPG Verification

	```
	curl -o install-nix-2.2.1 https://nixos.org/nix/install
	curl -o install-nix-2.2.1.sig https://nixos.org/nix/install.sig
	gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
	gpg2 --verify ./install-nix-2.2.1.sig
	sh ./install-nix-2.2.1 --daemon
	. /home/user/.nix-profile/etc/profile.d/nix.sh
	```
	Then follow the instructions. Open a new terminal window when you're done.

	If you get an error similar to
	```
	error: cloning builder process: Operation not permitted
	error: unable to start build process
	/tmp/nix-binary-tarball-unpack.hqawN4uSPr/unpack/nix-2.2.1-x86_64-linux/install: unable to install Nix into your default profile
	```
	you're likely not installing as multi-user because you forgot to pass the `--daemon` flag to the install script.

3. Clone this project

	```
	cd
	git clone https://github.com/jonasnick/nix-bitcoin
	cd ~/nix-bitcoin
	```

4. Create network file

	```
	nano network/network-nixos.nix
	```

	```
	{
	  bitcoin-node =
	    { config, pkgs, ... }:
	    { deployment.targetHost = 1.2.3.4;
	    };
	}
	```

	Replace 1.2.3.4 with NixOS machine's IP address.

5. Edit `configuration.nix`

	```
	nano configuration.nix
	```

	Uncomment `./hardware-configuration.nix` line by removing #.
	
6. Create `hardware-configuration.nix`

	```
	nano hardware-configuration.nix
	```
	Copy contents of NixOS machine's `hardware-configuration.nix` to file.

7. Add boot option to `hardware-configuration.nix`

	Option 1: Enable systemd boot for UEFI
	```
	boot.loader.grub.device = "/dev/sda";
	```
	Option 2: Set grub device for Legacy Boot (MBR)
	```
	boot.loader.grub.device = "/dev/sda":
	``` 

8. Setup environment
	```
	nix-shell
	```

9. Create nixops deployment in nix-shell.
	```
	nixops create network/network.nix network/network-nixos.nix -d bitcoin-node
	```

10. Adjust configuration by opening `configuration.nix` and removing FIXMEs. Enable/disable the modules you want in `configuration.nix`.

11. Deploy Nixops in nix-shell
	
	```
	nixops deploy -d bitcoin-node
	```
	This will now create a nix-bitcoin node on the target machine.

12. Nixops automatically creates an ssh key for use with `nixops ssh`. Access `bitcoin-node` through ssh in nix-shell with

	```
	nixops ssh operator@bitcoin-node
	```

See [usage.md](usage.md) for usage instructions, such as how to update.
