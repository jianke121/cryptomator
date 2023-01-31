# This script migrates Cryptomator settings for all local users on Windows in case a custom directory is used
#Requires -RunAsAdministrator

#Get all active, local user profiles
$profileList = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$localUsers = Get-LocalUser | Where-Object {$_.Enabled} | ForEach-Object { $_.Name}

Get-ChildItem $profileList | ForEach-Object { $_.GetValue("ProfileImagePath") } | Where-Object {
    $matches = ($_ | Select-String -Pattern "\\([^\\]+)$").Matches
    if($matches.Count -eq 1) {
        return $localUsers.Contains($matches[0].Groups[1].Value)
    }
    return $false;
} | ForEach-Object {
    $settingsPath = "$_\AppData\Roaming\Cryptomator\settings.json"
    if(!(Test-Path -Path $settingsPath)) {
        #No settings file, nothing to do.
        return;
    }

    $settings = Get-Content -Path $settingsPath | ConvertFrom-Json
    if($settings.preferredVolumeImpl -eq "FUSE") {
        #Fuse not used, nothing to do
        return;
    }

    #check if customMountPoints are used
    $atLeastOneCustomPath = $false;
    foreach ($vault in $settings.directories){
        $atLeastOneCustomPath = $atLeastOneCustomPath -or ($vault.useCustomMountPath -eq "True")
    }

    #if so, use WinFsp Local Drive
    if( $atLeastOneCustomPath ) {
        Add-Member -Force -InputObject $settings -Name "mountService" -Value "org.cryptomator.frontend.fuse.mount.WinFspMountProvider" -MemberType NoteProperty
        $newSettings  = $settings | Select-Object * -ExcludeProperty "preferredVolumeImpl"
        ConvertTo-Json $newSettings | Set-Content -Path $settingsPath
    }
}
