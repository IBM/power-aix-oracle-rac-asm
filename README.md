<!-- This should be the location of the title of the repository, normally the short name -->
# AIX Oracle RAC Collection - power_aix_oracle_rac_asm

This repository contains ansible **power_aix_oracle_rac_asm** collection which is used for installing Oracle 19c RAC on new AIX operating system.

The collection automates implementation of Oracle RAC specific requirements from setting up kernel tunables, network attributes, shared disk attributes, passwordless ssh user equivalency etc and, automates the Oracle 19c Grid and RDBMS Installations using silent method.

# Description

This playbook assumes the following:

     - The user is familiar with Ansible and has basic knowledge of YAML, as required to run this playbook.
     - The user is familiar with Oracle RAC configuration.
     - The user is familiar with the AIX operating system.
     - The AIX version is 7.2 TL4 or later or AIX 7.3 TL0 SP1 or later. (Tested on: AIX 7.2 TL4 SP1, AIX 7.2 TL5 SP2, AIX 7.3 TL0 SP1, AIX 7.3 TL1 SP1, AIX 7.3 TL2)
     - The playbook is intended for use on a new AIX LPAR.
     - The Oracle RAC Database version is 19.3.0.0 + RU (optional).
     - The user has downloaded the Grid and Database 19.3 binaries, RU 19.x binaries, OPatch binaries, and the Gold Image—either to NFS, local disk, or a remote (Ansible Controller) location.
     - The playbook uses modules from the ibm.power_aix collection.

To get started with Ansible refer

https://docs.ansible.com/ansible/latest/user_guide/intro_getting_started.html

To get started with Oracle Database on AIX refer

https://docs.oracle.com/en/database/oracle/oracle-database/19/axdbi/index.html

https://www.ibm.com/support/pages/oracle-db-rac-19c-ibm-aix-tips-and-considerations

To get started with AIX refer

https://www.ibm.com/support/knowledgecenter/ssw_aix_72/navigation/welcome.html



# System Configuration

![System Topology](https://github.com/IBM/power-aix-oracle-rac-asm/blob/main/pics/System_Configuration.png)

## Resources
The detail steps are mentioned in the readme document, Please go through it before you start using the collection

For **guides** and **reference**, please visit the [Documentation](https://github.com/IBM/power-aix-oracle-rac-asm/tree/main/docs/) site.

## License

[Apache License 2.0] (http://www.apache.org/licenses/)
## Copyright

© Copyright IBM Corporation 2021

