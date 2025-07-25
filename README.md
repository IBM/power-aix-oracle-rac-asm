<!-- This should be the location of the title of the repository, normally the short name -->
# AIX Oracle RAC Collection - power_aix_oracle_rac_asm

This repository contains ansible **power_aix_oracle_rac_asm** collection which is used for installing Oracle 19c RAC on new AIX operating system.

The collection automates implementation of Oracle RAC specific requirements from setting up kernel tunables, network attributes, shared disk attributes, passwordless ssh user equivalency etc and, automates the Oracle 19c Grid and RDBMS Installations using silent method.

-- check below, can we add this 
This Ansible playbook automates the installation and configuration of Oracle RAC 19c on IBM AIX LPARs running on Power Systems. It significantly reduces manual effort and installation time—from multiple days to just a few hours—even for multi-node clusters.

The playbook is tested on clusters ranging from 1 to 8 nodes and supports Oracle RAC installation using standard zip binaries or Gold Images, with flexible software staging options such as NFS, remote (Ansible controller), or local (managed host).

It is compatible with both manual infrastructure provisioning (via HMC) and automated provisioning using PowerVC, and integrates smoothly with Ansible Automation Platform 2 (AAP2) via both CLI (ansible-navigator) and GUI (AWX/Tower).

# Description

This playbook assumes the following:

- The user is familiar with Ansible and has basic knowledge of YAML, as required to run this playbook.
- The user is familiar with Oracle RAC configuration.
- The user is familiar with the AIX operating system.
- The AIX version is 7.2 TL4 or later or AIX 7.3 TL0 SP1 or later.  
- The playbook is intended for use on a **new AIX LPAR**.
- The Oracle RAC Database version is 19.3.0.0 + RU.
- The user has downloaded:
  - Grid and Database 19.3 binaries
  - RU 19.x patch binaries
  - OPatch binaries
  - Oracle Gold Image (optional)  
  to either **NFS**, **local disk**, or a **remote Ansible Controller** location.
- The playbook uses modules from the **ibm.power_aix** collection.
- The user has **root access** on RAC nodes and **sudo/root access** on the Ansible controller.
- The playbook configures **passwordless SSH** between nodes using root credentials provided in `vars.yml`.
- Network interface names and shared disks are **consistent across all RAC nodes**.

To get started with Ansible refer

https://docs.ansible.com/ansible/latest/user_guide/intro_getting_started.html

To get started with Oracle Database on AIX refer

https://docs.oracle.com/en/database/oracle/oracle-database/19/axdbi/index.html

https://www.ibm.com/support/pages/oracle-db-rac-19c-ibm-aix-tips-and-considerations

To get started with AIX refer

https://www.ibm.com/support/knowledgecenter/ssw_aix_72/navigation/welcome.html



# System Configuration

![System Topology](https://github.com/sudhisk/power-aix-oracle-rac-asm/blob/development/pics/System_Configuration.png)

# Key Capabilities

-  Idempotent Task Execution
   - Tasks are designed to execute only once, even if the playbook is run multiple times.
-  Disk Renaming Support
   - Allows optional renaming of AIX hdiskX to <prefix>X, for better disk-role clarity in large setups.
-  Oracle-Recommended AIX Tunables
   - Applies Oracle-documented settings for kernel, disk, and networking attributes automatically via Ansible tasks.
-  Supports Oracle RAC 19c
   - Installs all supported 19c RU versions including:
     19.8, 19.11, 19.12, 19.14, 19.17, 19.18, 19.24, 19.26, 19.27.
   - Supports patching with -applyRU and opatchauto.
-  Oracle Home Filesystem Flexibility
   - Option to install Oracle DB Home on:
       JFS2 (local filesystem)
       ACFS (shared Oracle Cluster Filesystem)
   - Controlled via acfs_flag variable.
-  Gold Image Support for Grid and DB
   - Supports use of Oracle Gold Images for both Grid and DB installations.
   - Can source from:
	nfs
	remote (Ansible controller)
	local (managed host)
-  Flexible Oracle Binary Staging
   - Supports various staging options:
	oracle_binary_location: nfs, remote, local
	Define subdirectories: base_subdir, opatch_subdir, cluvfy_subdir, ru_subdir
-  CLUVFY Utility Subdirectory Support
   - Allows specifying the path for latest CLUVFY version using cluvfy_subdir.
-  Optional Precheck Override
   - Skip Oracle installer prechecks using:
  	 use_ignore_prechecks: true
-  Automated Passwordless SSH Setup
   - SSH configuration for grid and oracle users using bootstrap role.
-  Prechecks for Node VIPs and SCAN VIPs
   - Verifies VIPs are free before Grid installation.
-  Optional IBM XL C Compiler Installation
   - XL C v13 compiler installed via NFS if defined in vars.yml.
-  Optional VNC Server Setup
   - Installs and configures VNC server for non-root users defined in vars.yml.
-  PowerVS Standard Image Support
   - No NFS required if PowerVS images already contain needed filesets:
   - use_powervs_std_nim: true
   - powervs_loc: '/usr/sys/inst.images/installp/ppc'
-  PowerVC Support for Infrastructure Provisioning
   - Full automation for 2-node RAC setup using:
	 powervc_create_nodes_without_rac_volumes
	 powervc_create_and_multiattach_asm_volumes
	 powervc_add_nodes_to_inventory
-  Validated with PowerVS and Manual LPAR Builds
   - Works on PowerVS, HMC-provisioned LPARs, or via PowerVC.
-  Tested Configurations
   - Validated with:
	 1, 2, 3, 4, 5, 7, 8-node RAC clusters
	 AIX 7.2 TL4 SP1 and later
	 AIX 7.3 TL0 SP1, TL1 SP1, TL2
-  DNS, NTP, SAN, and Multi-Network Support
   - Ensures RAC-ready networking and storage, with validation for:
	 3 network types (public, private1, private2)
	 Node-vip and SCAN-vip mappings
	 NTP and DNS integration
-  Support for Ansible Automation Platform 2 (AAP2)
   - Full execution via:
	 CLI (ansible-navigator)
	 GUI (AWX/Tower interface)
   - Uses custom containerized execution environments via ansible-builder.
-  Built-in Role Structure
   - Modular role-based architecture:
	 bootstrap: ssh setup, DNS, binding
	 preconfig: filesets, internet access
	 config: prepares AIX for RAC
	 install: ASM disk groups, Grid + DB install
-  Support for Running in Tags or Background
   - Run roles selectively with --tags
   - Supports long-running background execution with nohup
-  Robust Logging
   - Logs each playbook step and provides example paths for failures:
     /tmp/ansible/done/

## Resources
For detailed steps on Ansible controller requirements and Oracle RAC playbook execution, please refer to the README document or guide below.

For **guides** and **reference**, please visit the [Documentation](https://github.com/IBM/power-aix-oracle-rac-asm/tree/main/docs/) site.

## License

[Apache License 2.0] (http://www.apache.org/licenses/)
## Copyright

© Copyright IBM Corporation 2021

