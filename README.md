# GFT - Cloud Practicum

The objective of this project is allow the evaluation of the cloud practicum

## Getting Started

### Prerequisites

Powershell to run the build-cloud.ps1, an Azure account and the Azure CLI 

```
PS C:\Path\To\The\Project> Install-Module AzureRM
PS C:\Path\To\The\Project> Install-AzureRM
PS C:\Path\To\The\Project> build-cloud.ps1
```

### Running the script

After the build process described before a microsoft window will pop up asking for credentials.
The script will:
* Create a resource group
* Create a Azure WebApp
* Create a RmSqlServer DB
* Set up the WebApp with the connection string
* Set up the DB firewall rules to accept the WebApp and the current machine running the script
* Run the application scripts to build and run migrations
* Run the application scripts to build and publish to the WebApp FTP

## Running the tests

Open the browser, navigate to the WebApp host and a message will show the DB connection result. 
```xml
<string xmlns="http://schemas.microsoft.com/2003/10/Serialization/">
  connected successfully
</string>
```
