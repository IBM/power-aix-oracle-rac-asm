<!-- This should be the location of the title of the repository, normally the short name -->
# AIX Oracle RAC Collection - power_aix_oracle_rac_asm

This Ansible Collection automates the installation and configuration of Oracle RAC 19c on IBM AIX LPARs running on Power Systems. The collection automates implementation of Oracle RAC specific requirements from setting up kernel tunables, network attributes, shared disk attributes, passwordless ssh user equivalency etc and, automates the Oracle 19c Grid and RDBMS Installations using silent method. It significantly reduces manual effort and installation time—from multiple days to just a few hours—even for multi-node clusters.

The playbook is tested on clusters ranging from 1 to 8 nodes and supports Oracle RAC installation using standard zip binaries + RU apply or Gold Images, with flexible software staging options such as NFS, remote (Ansible controller), or local (managed host).

Note: To Create Gold Images, please refer to the section "Gold Image Creation" in the below Documentation
https://github.com/IBM/ansible-power-aix-oracle/blob/main/docs/README_ORA_SI_Play.pdf

It is compatible with both manual infrastructure provisioning (via HMC) and automated provisioning using PowerVC, and integrates smoothly with Ansible Automation Platform 2 (AAP2) via both CLI (ansible-navigator) and GUI (AWX/Tower).

# Description

This playbook assumes the following:

- The user is familiar with Ansible and has basic knowledge of YAML, as required to run this playbook.
- The user is familiar with Oracle RAC configuration.
- The user is familiar with the AIX operating system.
- The playbook uses modules from the **ibm.power_aix** collection.
- The playbook configures **passwordless SSH** between nodes using credentials provided in `vars.yml`.
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

## Resources
For detailed steps on Ansible controller requirements and Oracle RAC playbook execution, please refer to the README document or guide below.

For **guides** and **reference**, please visit the [Documentation](https://github.com/IBM/power-aix-oracle-rac-asm/tree/main/docs/) site.

## License

[Apache License 2.0] (http://www.apache.org/licenses/)
## Copyright

© Copyright IBM Corporation 2021

