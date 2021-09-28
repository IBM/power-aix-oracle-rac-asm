# Ansible Role: bootstrap

## Requirements

None.

## Role Variables

Available variables are listed below, along with default values:

    pkgtype (True, str, yum)

Specifies the package service requiring bootstrap installation.

    download_dir (optional, str, ~)

Specifies the temporary download location for install scripts and packages. The location resides on the Ansbile control node.

    target_dir (optional, str, /tmp/.ansible.cpdir)

Specifies the target location (per inventory host) for copying and restoring package files and metadata. If the target location does not exist, then a temporary filesystem is created using the target_dir as the mount point.  Upon role completion, the target location is removed.

## Dependencies

None.

## Example Playbook

    - hosts: aix
      gather_facts: no
      include_role:
        name: bootstrap
      vars:
        pkgtype: yum

## Copyright
© Copyright IBM Corporation 2021
