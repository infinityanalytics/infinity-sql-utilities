
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
$MsftSamplesLocation = "https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0"
$ContainerName = "SQL2019Test"
$RebuildContainer = $False
$SaPassword = "Password123#"

Clear-Host
Write-Host "======= Starting Docker SQL Script ========" -ForegroundColor Green
docker pull $SqlImageName

if ($RebuildContainer) {
   docker stop $ContainerName
   docker rm $ContainerName
   Write-Output "Existing container removed."
}
#run the container.  Will warn 'is already in use' if this container name already exists
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=$saPassword" --name $ContainerName -p 1433:1433 -v sql1data:/var/opt/mssql -d $SqlImageName
docker start $ContainerName
write-output "***started docker image $SqlImageName***"

#Download WideWorldImporters sample databases
if (!(Test-Path "$($CurrentFolder)/backups")) { New-Item -ItemType Directory -Force -Path "$($CurrentFolder)/backups" }
docker exec -it $ContainerName mkdir -p "/var/opt/mssql/backup/"

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

Write-Host "WideWorldImporters databases restored.  Script complete." -ForegroundColor Green
#docker inspect -f "{{ .NetworkSettings.IPAddress }}" $ContainerName

