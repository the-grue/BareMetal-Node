# BareMetal Node

This project uses the BareMetal kernel to allow you to create a network of "nodes" for distributed processing tasks.


## Getting Started


### Prerequisites

[NASM](http://www.nasm.us) (Assembly compiler) is required to build the loader and kernel, as well as the apps written in Assembly. [GCC](https://gcc.gnu.org/) (C compiler) is required for building the MCP, as well as the C applications. [Git](https://git-scm.com/) is used for pulling the software from GitHub.

In Debian this can be completed with the following command:

	sudo apt install nasm gcc git


### Initial setup

	git clone https://github.com/ReturnInfinity/BareMetal-Node.git
	cd BareMetal-Node
	./setup.sh


### Configuring a PXE boot environment

Notes on configuring a PXE book environment can be found [here](https://github.com/ReturnInfinity/BareMetal-Node/wiki/Configuring-a-PXE-boot-environment). Once this is complete run the following script to copy the binary to the tftpboot folder:

	sudo ./install.sh


## Using BareMetal Node


### Running the Master Control Program

The [MCP](http://tron.wikia.com/wiki/Master_Control_Program) (Master Control Program) is responsible for working with the nodes. Elevated access is required for sending/receiving Ethernet packets. Provide the interface name as an argument.

	cd bin
	sudo ./mcp INTERFACE

The MCP has several commands that can be run.

- discover
- dispatch
- execute
- exit
- list
- parameters
- reboot
- reset
- stop


## Todo list

- Rewrite Node Handler in C instead of Assembly (eventually in will need to encrypt/decrypt packets)


// EOF
