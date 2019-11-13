# infinity-sql-utilities
Collection of helpful scripts for SQL Server development

## run sql 2019.ps1
This powershell script automates the process of getting up and running with SQL Server 2019 on Docker.  It is cross-platform, and will run on any machine that has docker and powershell support.  It is tested on Windows 10 and Mac OS Mojave.

It performs the following tasks:
* Downloads the SQL Server 2019 (latest revision) docker image from the Azure repository
* Creates & starts a container with the default options
* Enables SQL Agent & Memory-optimized Tempdb metadata
* Downloads the 2 WideWorldImporters sample databases
* Copies the sample databases into the docker container
* Optionally restores the 2 sample databases

## run sql 2019 2 node.ps1
* Does the same thing as the standard script, but separates the single SQL instance into 2 separate instances.
