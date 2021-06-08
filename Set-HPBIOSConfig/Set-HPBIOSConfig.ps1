<#.DESCRIPTION
    This will use the gathered BIOS config file from HP BiosConfigUtility and set your systems BIOS preferences.
    Make sure your settings file is named the same as your Win32_ComputerSystem property Model, eg "HP ZBook 15 G4.txt" as the script will call this WMI Class to match up with a settigsfile.
    
    Script expects these files to be in the same directory as BiosConfigUtility64.exe :
        Passwordfile.bin
        BiosConfigUtility64.exe
        BIOSSettings.REPSET
        BCU_ExitCodes.xml
        
    Can be made into a package and ran through TS or as application, or even better is to place it on a share accessible from clients, then you wont have to update the package/application-files when making changes in settingsfiles or adding new ones.
    When running this from a UNC-path, you have to do this post your Apply Networksettings -step, as the TS is run in SYSTEM context.
    For Offline-media or package, make sure to set the parameters accordingly.
    
    To Download HP BIOS Configuration Utility
    https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.html
    
    For more information on the BIOSConfigUtility:
    http://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/BIOS_Configuration_Utility_User_Guide.pdf

.PARAMETER PasswordFile
    Used to define the name of your Password.bin
    For local or package set:
    eg "password"

.PARAMETER BCUPath
    Used to define the path to your BiosConfigUtility.exe directory, which should also contain you password.bin and biossettings.txt -files.
    If you want to use an UNC path you need a "Connect to network Folder" -step ahead of the script step.
    Map the folder containing all your settingsfiles, BCU utility and PWD file to eg "O:" and then set the -BCUPath parameter to "O:"
    For local or package set:
    ".\BiosConfigUtility64.exe"

.EXAMPLE 1 When using UNC
    PS > .\Set-HPBiosConfig.ps1 -BCUPath "O:" -PasswordFile "Password" -DeploymentType "OS"
.EXAMPLE 2 Running local or package
    PS > .\Set-HPBiosConfig.ps1 -BCUPath ".\BiosConfigUtility64.exe" -PasswordFile "Password"
#>
param (
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$PasswordFile,

    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$BCUPath
)

# Gather System preferences
$ComputerSystemModel = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Model
    Write-OutPut "Determined system model is  $ComputerSystemModel. Trying to find matching settingsfile..."

# Set LogPath
    #Construct TSEnv
    $TSEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop

    #Get Logpath
    $LogPath = $TSEnvironment.Value("_SMSTSLogPath")

#Get ExitCode Info
[XML]$BCUExitCodes = Get-Content ".\BCU_ExitCodes.xml"

# Run BCU and set BIOS Settings
    
    #Set BIOS Variables
    $REPSETFile = "$BCUPath\$ComputerSystemModel.REPSET"
    $CurrentPassword = "$BCUPath\$PasswordFile.bin"
    $LogFile = "$LogPath\$ComputerSystemModel.REPSETLog.log"

        # Run HP BCU Utility and try to create a new REPSET file for device
        $HPBCU = @{
            FilePath = "$BCUPath\BiosConfigUtility64.exe"
            ArgumentList = @(
                "`"/Set:$REPSETFile`"", `
                "`"/cpwdfile:$CurrentPassword`"", `
                "`"/verbose`""
            )
            wait = $True
            PassThru = $True
            RedirectStandardOutput = $LogFile
            WindowStyle = "Hidden"
        }

        $BCUExitCode = (Start-Process @HPBCU).ExitCode

        #Exit and write exitmessage
        $ExitCode = "exit$BCUExitCode"
        $ExitCodeMessage = $BCUExitCodes.exitcodes.$ExitCode
        Write-OutPut $ExitCodeMessage