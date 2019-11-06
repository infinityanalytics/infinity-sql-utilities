
<#
MIT License, http://www.opensource.org/licenses/mit-license.php
Copyright (c) 2019 Infinity Analytics Inc.

Permission is hereby granted, free of charge, to any person 
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without 
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom 
the Software is furnished to do so, subject to the following 
conditions:
The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
OTHER DEALINGS IN THE SOFTWARE.
#>

$ErrorActionPreference = "Stop"
$CurrentFolder = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$SqlImageName = "mcr.microsoft.com/mssql/server:2019-RC1-ubuntu"
#$SqlImageName = "mcr.microsoft.com/mssql/server:2019-GA-ubuntu-16.04"
   #container_linux.go:346: starting container process caused "process_linux.go:101: executing setns process caused \"exit status 1\"": unknown
#$SqlImageName = "mcr.microsoft.com/mssql/server:2019-GDR1-ubuntu-16.04"
#$SqlImageName = "mcr.microsoft.com/mssql/server:2019-latest"
$MsftSamplesLocation = "https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0"
$ContainerName = "SQL2019Test"
$SaPassword = "Password123#"
$RebuildContainer = $True
$RestoreWWIBackups = $False

Clear-Host
Write-Host "======= Starting Docker SQL Script ========" -ForegroundColor Green
docker pull $SqlImageName

if ($RebuildContainer) {
   docker stop $ContainerName
   docker rm $ContainerName
   Write-Output "Existing container removed."
}
#run the container.  Will warn 'is already in use' if this container name already exists
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=$saPassword" -p 1433:1433 -v sql1data:/var/opt/mssql --name $ContainerName -d $SqlImageName
docker start $ContainerName
write-output "***started docker image $SqlImageName***"

#Download WideWorldImporters sample databases
if (!(Test-Path "$($CurrentFolder)/backups")) { New-Item -ItemType Directory -Force -Path "$($CurrentFolder)/backups" }
docker exec -it $ContainerName mkdir -p "/var/opt/mssql/backup/"

#enable SQL Agent:
docker exec -it $ContainerName /opt/mssql/bin/mssql-conf set sqlagent.enabled true 

#enable 2019 enhancement: hekaton-enabled tempDb metadata:
docker exec -it $ContainerName /opt/mssql-tools/bin/sqlcmd -S localhost `
   -U SA -P "$SaPassword" -Q "ALTER SERVER CONFIGURATION SET MEMORY_OPTIMIZED TEMPDB_METADATA = ON;"

#the "systemctl restart mssql-server.service" command is failing -- restart container as a workaround
docker restart $ContainerName
write-output "***restarted docker image***"

foreach(
   $SampleDatabase in (
      "WideWorldImporters-Full.bak",
      "WideWorldImportersDW-Full.bak"
   )
) {
   if (!(Test-Path "$($CurrentFolder)/backups/$SampleDatabase")) {
      Write-Output "Downloading $SampleDatabase..."
      Invoke-Webrequest -OutFile "$($CurrentFolder)/backups/$SampleDatabase" "$MsftSamplesLocation/$SampleDatabase"
   }
   else {
      Write-Output "$($CurrentFolder)/backups/$SampleDatabase already downloaded."
   }
   
   #copy local file to docker container
   docker cp "$CurrentFolder/backups/$SampleDatabase" "$($ContainerName):/var/opt/mssql/backup/"
}

if ($RestoreWWIBackups) {
   Write-Output "Restoring WideWorldImporters databases..."

   docker exec -it $ContainerName /opt/mssql-tools/bin/sqlcmd -S localhost `
   -U SA -P "$SaPassword" `
   -Q """RESTORE DATABASE WideWorldImporters 
            FROM DISK = '/var/opt/mssql/backup/WideWorldImporters-Full.bak' 
            WITH MOVE 'WWI_Primary' TO '/var/opt/mssql/data/WideWorldImporters.mdf', 
            MOVE 'WWI_UserData' TO '/var/opt/mssql/data/WideWorldImporters_userdata.ndf', 
            MOVE 'WWI_Log' TO '/var/opt/mssql/data/WideWorldImporters.ldf', 
            MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImporters_InMemory_Data_1';
            ALTER DATABASE WideWorldImporters SET COMPATIBILITY_LEVEL=150;
         """

   docker exec -it $ContainerName /opt/mssql-tools/bin/sqlcmd -S localhost `
      -U SA -P "$SaPassword" `
      -Q """RESTORE DATABASE WideWorldImportersDW 
            FROM DISK = '/var/opt/mssql/backup/WideWorldImportersDW-Full.bak' 
            WITH MOVE 'WWI_Primary' TO '/var/opt/mssql/data/WideWorldImportersDW.mdf', 
            MOVE 'WWI_UserData' TO '/var/opt/mssql/data/WideWorldImportersDW_userdata.ndf', 
            MOVE 'WWI_Log' TO '/var/opt/mssql/data/WideWorldImportersDW.ldf', 
            MOVE 'WWIDW_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImportersDW_InMemory_Data_1';
            ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL=150;
         """

   Write-Output "WideWorldImporters databases restored."
}
else {
   Write-Output "WideWorldImporters databases skipped because `$RestoreWWIBackups is set to `$False."
}

Write-Output "IP address to access this container:"
ifconfig en0 inet

Write-Host "Script complete." -ForegroundColor Green
