<#
    
    Copyright (c) Virtual Engine Limited. All rights reserved. 
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    
#>

Import-LocalizedData -BindingVariable localized -FileName Resources.psd1;
$providerName = 'AppV';
$packageSourceRootName = 'AppvPackageSourceRoot';
$persistencePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath ('PackageManagement\{0}' -f $providerName);
$registeredPackageSourcesPath = Join-Path -Path $persistencePath -ChildPath 'PackageSources.json';
$registeredPackageSources = New-Object -TypeName System.Collections.ArrayList -ArgumentList @();

function Resolve-PackageSource { 
    <# 
        Returns all registered provider package sources. This is
        called by the Get-PackageSource cmdlet.
    #>
    param ()   
    Write-Debug ('In {0} Provider - ''Resolve-PackageSource''.' -f $providerName);
    Get-RegisteredPackageSources;

    # if that's null or empty, they're asking for the whole list.
	if (-not ($request.PackageSources)) {
		# if there is nothing passed in, just return all the known package sources
		foreach($registeredPackageSource in $registeredPackageSources) {
			Write-Debug ('In {0} Provider - ''Resolve-PackageSource'' - Returning package source ''{1}''.' -f $providerName, $registeredPackageSource.Name);
			Write-Output $registeredPackageSource;
		}
		return;
	}
    
    ##TODO: Support $request.Options['Location']
    # otherwise, they are requesing one or more sources back. 
	foreach ($source in ($request.PackageSources)) {
        Write-Debug ('In {0} Provider - ''Resolve-PackageSource'' - Requesting package source ''{1}''.' -f $providerName, $source);
		$isFound = $false;
		# otherwise, for each item, check if we have a source by that name and return it.
		foreach ($packageSource in $registeredPackageSources) {
            Write-Debug ('In {0} Provider - ''Resolve-PackageSource'' - Checking package source ''{1}''.' -f $providerName, $packageSource.Name);
			if ($packageSource.Name -eq $source) {
                Write-Debug ('In {0} Provider - ''Resolve-PackageSource'' - Returning package source ''{1}''.' -f $providerName, $packageSource.Name);
				Write-Output $packageSource;
				$isFound = $true;
				break;
			}
		}
		if ($isFound) {
			continue;
		}
		# if it's not a valid source location send a warning back.
		Write-Warning ($localized.InvalidSourcePathWarning -f $source);
	} #end foreach source
    Write-Debug ('Done In {0} Provider - ''Resolve-PackageSource''.' -f $providerName);
} #end function Resolve-PackageSources

function Dump-RequestObjectOptions {
    param ()
    if ($request.Options) {
        foreach ($optionKey in $request.Options.Keys) {
            Write-Debug ('In {0} Provider - Dynamic Option ''{1}'' => ''{2}''.' -f $providerName, $optionKey, $request.Options[$optionKey]);
        }
    }
}

function Set-RegisteredPackageSources {
    <#
        Persists registered package sources to disk.
    #>
    param ()
    Write-Debug ('In {0} Provider - ''Set-RegisteredPackageSources''.' -f $providerName);
    Write-Debug ('Current Package Source Count: ''{0}''.' -f $RegisteredPackageSources.Count);
    if (-not (Test-Path -Path $registeredPackageSourcesPath -PathType Leaf)) {
        [Ref] $null = New-Item -Path $registeredPackageSourcesPath -ItemType File -Force;
    }
    ## Cannot pipe $registeredPackageSources into ConvertTo-Json if the object is empty!
    ConvertTo-Json -InputObject $registeredPackageSources | Set-Content -Path $registeredPackageSourcesPath -Force;
} #end function Set-RegisteredPackageSources

function Get-RegisteredPackageSources {
    <#
        Loads registered package sources from disk.
    #>
    param ()
    $script:registeredPackageSources = New-Object -TypeName System.Collections.ArrayList -ArgumentList @();
    if (Test-Path -Path $registeredPackageSourcesPath -PathType Leaf) {
        $packageSources = Get-Content -Path $registeredPackageSourcesPath -Raw | ConvertFrom-Json;
        foreach ($source in $packageSources) {
            Write-Debug ('In {0} Provider - ''Get-RegisteredPackageSources'' - Loading package source ''{1}''.' -f $providerName, $source.Name);
            $packageSourceParam = @{
                Name = $source.Name;
                Location = $source.Location;
                Trusted = $source.IsTrusted;
                Registered = $source.IsRegistered;
                Valid = $source.IsValidated;
            }
            $packageSource = New-PackageSource @packageSourceParam;
            $script:registeredPackageSources.Add($packageSource);
        }
    }
    [Ref] $null = Resolve-AppvPackageSourceRoot;
} #end function Get-RegisteredPackageSources

function Register-PackageSource { 
    <# 
        .SYNOPSIS
            Registers a new provider package source
    #>
    param (
        [Parameter(Mandatory)] [System.String] $Name, 
        [Parameter(Mandatory)] [System.String] $Location, 
        [Parameter()] [System.Boolean] $Trusted
    )
    Write-Debug ('In {0} Provider - ''Register-PackageSource'' - Name ''{1}''.' -f $providerName, $Name);
    if (-not (Test-Path -Path $Location -PathType Container)) {
        Write-Error -Message ($localized.InvalidDirectoryPathError -f $Location) -Category InvalidArgument;
        return;
    }
	# remove any existing object first.
	for ($i = $registeredPackageSources.Count; $i -gt 0; $i--) {
        $packageSource = $registeredPackageSources[$i -1];
        Write-Debug ('In {0} Provider - ''Register-PackageSource'' - Checking existing package source ''{1}''.' -f $providerName, $packageSource.Name);
        if ($packageSource.Name -eq $Name) {
            Write-Debug ('In {0} Provider - ''Register-PackageSource'' - Removing existing package source ''{1}''.' -f $providerName, $packageSource.Name);
            $script:registeredPackageSources.Remove($packageSource);
        }		
	}
    $location = Resolve-Path -Path $Location;
    $packageSource = New-PackageSource -Name $Name -Location $location -Trusted $trusted -Registered $true -Valid $true;
	$script:registeredPackageSources.Add($packageSource);
    Set-RegisteredPackageSources;
	Write-Output $packageSource; 
} #end function Register-PackageSource

function Unregister-PackageSource { 
    <# 
        .SYNOPSIS
            Removes the specified provider package source by name or location.
    #>
    param (
        [Parameter(Mandatory)] [System.String] $Name
    )
    Write-Debug ('In {0} Provider - ''Unregister-PackageSource''.' -f $providerName);
    for ($i = $registeredPackageSources.Count; $i -gt 0; $i--) {
		$packageSource = $registeredPackageSources[$i -1];
        Write-Debug ('In {0} Provider - ''Unregister-PackageSource'' - Checking existing package source ''{1}''.' -f $providerName, $packageSource.Name);
		if ($packageSource.Name -eq $name -or $packageSource.Location -eq $Name )  {
			Write-Debug ('In {0} Provider - ''Unregister-PackageSource'' - Removing source ''{1}'' location ''{2}''.' -f $providerName, $packageSource.Name, $packageSource.Location);
			Write-Output $packageSource;
			$script:registeredPackageSources.Remove($packageSource);
            Set-RegisteredPackageSources;
		}
	} #end foreach registeredPackageSources
} #end function Unregister-PackageSource

function Get-AppvAppxManifest {
   <#
    .SYNOPSIS
        Returns the contents of an App-V package AppxManifest file.
    #>
    param (
        [Parameter(Mandatory)] [System.String] $Path
    )
    try {
        Write-Debug ('In {0} Provider - ''Get-AppvAppxManifest'' - Loading .Net Framework assemblies.' -f $providerName);
        [Ref] $null = [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression');
        [Ref] $null = [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem');
        Write-Debug ('In {0} Provider - ''Get-AppvAppxManifest'' - Opening ''{1}'' .appv archive.' -f $providerName, $Path);
        $appvArchive = New-Object System.IO.Compression.ZipArchive(New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open));
        $appvArchiveEntry = $appvArchive.GetEntry('AppxManifest.xml');
        if ($appvArchiveEntry -ne $null) {
            $xmlDocument = New-Object System.Xml.XmlDocument;
            $xmlDocument.Load($appvArchiveEntry.Open());
            Write-Output $xmlDocument;
        }
    }
    catch {
        Write-Error -Message ($localized.ReadAppvManifestError -f $Path) -Exception $_.Exception -Category InvalidOperation;
    }
    finally {
        if ($xmlDocument -ne $null) { $xmlDocument = $null; }
        if ($appvArchiveEntry -ne $null) { $appvArchive.Dispose(); }
    }
} #end function Get-AppvAppxManifest

function Find-Package { 
    <# 
        .SYNOPSIS
            Searches a registered provider package sources for packages
    #>  
    param (
        [Parameter()] [System.String[]] $Names,
        [Parameter()] [System.String] $RequiredVersion,
        [Parameter()] [System.String] $MinimumVersion,
        [Parameter()] [System.String] $MaximumVersion
    )

    Write-Debug ('In {0} Provider - ''Find-Package''.' -f $providerName);
    $filterparam = $request.Options['filter']; ##TODO: What is the filter parameter?
    
    if ([System.String]::IsNullOrEmpty($RequiredVersion)) {
        if ([System.String]::IsNullOrEmpty($MinimumVersion)) { $minVersion = New-Object -TypeName System.Version -ArgumentList 0, 0, 0, 0; }
        else { $minVersion =  New-Object -TypeName System.Version -ArgumentList $MinimumVersion; }
        if ([System.String]::IsNullOrEmpty($MaximumVersion)) {$maxVersion = (New-Object -TypeName System.Version -ArgumentList ([int]::MaxValue),([int]::MaxValue)).ToString(); }
        else { $maxVersion = New-Object -TypeName System.Version -ArgumentList $MaximumVersion; }
    }
    else {
        $minVersion = New-Object -TypeName System.Version -ArgumentList $RequiredVersion;
        $maxVersion = $minVersion;
    }
    Write-Debug ('In {0} Provider - ''Find-Package'' - Checking minimum ''{1}'' and maximum ''{2}''.' -f $providerName, $minVersion.ToString(), $maxVersion.ToString());

    foreach ($registeredPackageSource in $registeredPackageSources) {
        Write-Debug ('In {0} Provider - ''Find-Package'' - Checking package source ''{1}''.' -f $providerName, $registeredPackageSource.Name);
        $shouldProcessPackageSource = $false;
        if ([System.String]::IsNullOrEmpty($request.Options['Source'])) {
            Write-Debug ('In {0} Provider - ''Find-Package'' - Source parameter not specified.' -f $providerName);
            $shouldProcessPackageSource = $true;
        }
        elseif ($registeredPackageSource.Name -eq $request.Options['Source']) {
            Write-Debug ('In {0} Provider - ''Find-Package'' - Source parameter ''{1}'' matches package source ''{2}''.' -f $providerName, $request.Options['Source'], $registeredPackageSource.Name);
            $shouldProcessPackageSource = $true;
        }
        else {
            Write-Debug ('In {0} Provider - ''Find-Package'' - Skipping package source ''{1}''.' -f $providerName, $registeredPackageSource);
        }

        if ($shouldProcessPackageSource) {
            Write-Debug ('In {0} Provider - ''Find-Package'' - Searching package source ''{1}''.' -f $providerName, $registeredPackageSource.Name);
            Get-ChildItem -Path $registeredPackageSource.Location -Include *.appv -Recurse | ForEach-Object {
                Write-Debug ('In {0} Provider - ''Find-Package'' - Reading package ''{1}''.' -f $providerName, $_.FullName);
                $appxManifest = Get-AppvAppxManifest -Path $_.FullName;
                $appxVersion = New-Object -TypeName System.Version -ArgumentList $appxManifest.Package.Identity.Version;
                Write-Debug ('In {0} Provider - ''Find-Package'' - Discovered Package Id ''{1}''.' -f $providerName, $appxManifest.Package.Identity.PackageId);
                foreach ($name in $Names) {
                    if (-not $name.Contains('*')) { $name = '*{0}*' -f $name; }
                    if ($appxManifest.Package.Properties.DisplayName -like $name) {
                        if ($appxVersion -lt $minVersion) {
                            Write-Debug ('In {0} Provider - ''Find-Package'' - Package version ''{1}'' is less than ''{2}''.' -f $providerName, $appxVersion, $minVersion);
                        }
                        elseif ($appxVersion -gt $maxVersion) {
                            Write-Debug ('In {0} Provider - ''Find-Package'' - Package version ''{1}'' is greater than ''{2}''.' -f $providerName, $appxVersion, $maxVersion);
                        }
                        else {
                            $softwareIdentityParam = @{
                                FastPackageReference = $_.FullName;
                                Name = $appxManifest.Package.Properties.DisplayName;
                                Version = $appxManifest.Package.Identity.Version;
                                VersionScheme = 'semver';
                                Source = $registeredPackageSource.Name;
                                Summary = $appxManifest.Package.Properties.AppVPackageDescription;
                                SearchKey = $appxManifest.Package.Identity.PackageId;
                                FullPath = $_.FullName;
                                FromTrustedSource = $registeredPackageSource.IsTrusted;
                            };
                            Write-Output (New-SoftwareIdentity @softwareIdentityParam);
                        }
                    } #end if DisplayName -like name
                } #end foreach name
            } #end foreach-object
        } #end if package source
    } #end foreach registeredPackageSource
} #end function Find-Package

function Get-InstalledPackage { 
    <# 
        .SYNOPSIS
            Returns all applications registered in the App-V client.
    #>
    param (
        [Parameter()] [System.String] $Name,
        [Parameter()] [System.String] $RequiredVersion,
        [Parameter()] [System.String] $MinimumVersion,
        [Parameter()] [System.String] $MaximumVersion
        ##TODO: Implement version semantics
    )
    Write-Debug ('In {0} Provider - ''Get-InstalledPackage'' {1} {2}.' -f $providerName, $InstalledPackages.Count, $Name);
	if ($Name -eq $null -or $Name -eq "") {
		foreach ($appvPackage in Get-AppvClientPackage -All) {
            $softwareIdentityParam = @{
                FastPackageReference = $appvPackage.Path;
                Name = $appvPackage.Name;
                Version = $appvPackage.Version;
                VersionScheme = 'semver';
                Source = $appvPackage.Path;
                SearchKey = $appvPackage.PackageId;
            };
            New-SoftwareIdentity @softwareIdentityParam;
		}
	}
	else {
		# We're after a specific package
        if (-not $Name.Contains('*')) { $Name = '*{0}*' -f $Name; }
		foreach ($appvPackage in Get-AppvClientPackage -All) {
    		if ($appvPackage.Name -like $Name) {
                $softwareIdentityParam = @{
                    FastPackageReference = $appvPackage.Path;
                    Name = $appvPackage.Name;
                    Version = $appvPackage.Version;
                    VersionScheme = 'semver';
                    Source = $appvPackage.Path;
                    SearchKey = $appvPackage.PackageId;
                };
			    New-SoftwareIdentity @softwareIdentityParam;
            }
		} #end foreach appvPackage
	} #end else
} #end function Get-InstalledPackage

function Get-PackageProviderName { 
    <# 
        .SYNOPSIS
            Returns the name of the PackageManagement provider.
    #>
    param ()
    return $providerName;
} #end function Get-PackageProviderName

function Initialize-Provider { 
    <# 
        .SYNOPSIS
            Initializes the provider upon startup. 
    #>
    param ()
    Write-Debug ('In {0} Provider - ''Initialize-Provider''.' -f $providerName);
    Get-RegisteredPackageSources;
} #end function Initialize-Provider

function Resolve-AppvPackageSourceRoot {
    <#
        .SYNOPSIS
            Resolves the AppV client package source root from the registry and
            if valid, automatically adds it as a trusted Appv provider package source.
    #>
    param ()
    Write-Debug ('In {0} Provider - ''Resolve-AppvPackageSourceRoot''.' -f $providerName);
    if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\AppV\Client\Streaming')) {
        $packageSourceRoot = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\AppV\Client\Streaming').PackageSourceRoot;
        if ([System.String]::IsNullOrEmpty($packageSourceRoot) -or (-not (Test-Path -Path $packageSourceRoot -PathType Container))) {
            Write-Debug ('In {0} Provider - ''Resolve-AppvPackageSourceRoot'' - Appv Package Source Root ''{1}'' is invalid. ' -f $providerName, $packageSourceRoot);
            Unregister-PackageSource -Name $packageSourceRootName;
        }
        else {
            Write-Debug ('In {0} Provider - ''Resolve-AppvPackageSourceRoot'' - Adding Package Source Root ''{1}''.' -f $providerName, $packageSourceRoot);
            Register-PackageSource -Name $packageSourceRootName -Location $packageSourceRoot -Trusted $true;
        }
    } #end if packageSourceRoot
    else {
        Unregister-PackageSource -Name $packageSourceRootName;
    }
} #end function Resolve-AppvPackageSourceRoot

function Install-Package { 
    <#
        .SYNOPSIS
            Registers the App-V application package located in
            the path specified.
    #>
    param (
        [Parameter(Mandatory)] [System.String] $FastPackageReference
    )
    Write-Debug ('In {0} Provider - ''Install-Package'' - Package reference ''{1}''.' -f $providerName, $FastPackageReference);
    if ($request.Options['Global'] -eq $true -and $request.Options['DynamicUserConfigurationPath'] -ne $null) {
        Write-Error -Message $localized.InvalidArgumentsError -Category InvalidArgument;
    }

    $publishAppvClientPackageParam = @{ };
    $addAppvClientPackageParam = @{
        Path = $FastPackageReference;
    };
    if ($request.Options['DynamicDeploymentConfiguration']) {
        $dynamicDeploymentConfiguration = $request.Options['DynamicDeploymentConfiguration'];
        Write-Debug ('In {0} Provider - ''Install-Package'' - Setting Dynamic Deployment Configuration ''{1}''.' -f $providerName, $dynamicDeploymentConfiguration);
        $addAppvClientPackageParam['DynamicDeploymentConfiguration'] = $dynamicDeploymentConfiguration;
    }

    if ($request.Options['Global'] -ne $null -and $request.Options['Global'] -eq $true) {
        $publishAppvClientPackageParam['Global'] = $true;
    }
    if ($request.Options['DynamicUserConfigurationPath']) {
        $dynamicUserConfigurationPath = $request.Options['DynamicUserConfigurationPath'];
        Write-Debug ('In {0} Provider - ''Install-Package'' - Setting Dynamic User Configuration Path ''{1}''.' -f $providerName, $dynamicUserConfigurationPath);
        $publishAppvClientPackageParam['DynamicUserConfigurationPath'] = $dynamicUserConfigurationPath;
    }
    if ($request.Options['DynamicUserConfigurationType']) {
        $dynamicUserConfigurationType = $request.Options['DynamicUserConfigurationType'];
        Write-Debug ('In {0} Provider - ''Install-Package'' - Setting Dynamic User Configuration Type ''{1}''.' -f $providerName, $dynamicUserConfigurationType);
        $publishAppvClientPackageParam['DynamicUserConfigurationType'] = $dynamicUserConfigurationType;
    }

    try {
        $appvPackage = Add-AppvClientPackage @addAppvClientPackageParam -ErrorAction Stop | Publish-AppvClientPackage @publishAppvClientPackageParam;
        if ($request.Options['Mount'] -ne $null -and $request.Options['Mount'] -eq $true) {
            Write-Debug ('In {0} Provider - ''Install-Package'' - Mounting package ''{1}''.' -f $providerName, $appvPackage.Name);
            $appvPackage | Mount-AppvClientPackage;
        }
        $softwareIdentityParam = @{
            FastPackageReference = $appvPackage.Path;
            Name = $appvPackage.Name;
            Version = $appvPackage.Version;
            VersionScheme = 'semver';
            Source = $appvPackage.Path;
            SearchKey = $appvPackage.PackageId;
        }
        Write-Output (New-SoftwareIdentity @softwareIdentityParam);
    }
    catch {
        Remove-AppvClientPackage -Package $appvPackage -ErrorAction SilentlyContinue;
        Write-Error -Message $localized.InstallAppvPackageError -Exception $_.Exception -Category NotInstalled;
    }    
} #end function Install-Package

function Uninstall-Package { 
    <# 
        .SYNOPSIS
            Registers the App-V application package located in
            the path specified.
    #>
    param (
        [Parameter(Mandatory)] [System.String] $FastPackageReference
    )
    Write-Debug ('In {0} Provider - ''Uninstall-Package'' - Reference ''{1}''.' -f $providerName, $FastPackageReference);
    foreach ($appvPackage in (Get-AppvClientPackage -All | Where-Object { $_.Path -eq $FastPackageReference })) {
        if ($appvPackage.InUse) {
            Write-Error -Message ($localized.AppvPackageIsInUseError -f $appvPackage.Name) -Category InvalidOperation;
        }
        else {
            Write-Debug ('Removing package ''{0}''.' -f $appvPackage.Name);
            $softwareIdentityParam = @{
                FastPackageReference = $appvPackage.Path;
                Name = $appvPackage.Name;
                Version = $appvPackage.Version;
                VersionScheme = 'semver';
                Source = $appvPackage.Path;
                SearchKey = $appvPackage.PackageId;
            }
            $package = New-SoftwareIdentity @softwareIdentityParam;
            Remove-AppvClientPackage -PackageId $appvPackage.PackageId -VersionId $appvPackage.VersionId;
            Write-Output $package;
		} #end if
	} #end foreach appvPackage
} #end function Uninstall-Package

function Get-Feature { 
    <# 
        .SYNOPSIS
            Returns metadata about what features are
            implemented by the Provider.
    #>
    param ()
    Write-Debug ('In {0} Provider - ''Get-Feature''.' -f $providerName);
	Write-Output (New-feature 'extensions' @('appv'));
} #end function Get-Feature

function Get-DynamicOptions {
    <#
        .SYNOPSIS
            Provides dynamic parameters for Package, Source and/or
            Install operations.            
    #>
    param (
        [Microsoft.PackageManagement.MetaProvider.PowerShell.OptionCategory] $category
    )
    Write-Debug ('In {0} Provider - ''Get-DynamicOption'' for category ''{1}''.' -f $providerName, $category);
	switch ($category) {
        Provider {
            # options when the user is trying to specify a provider
        }
	    Package {
			# options when the user is trying to specify a package 
		}
		Source {
			#options when the user is trying to specify a source
		}    
		Install {
			#options for installation/uninstallation
            Write-Output (New-DynamicOption -Category $category -Name Global -ExpectedType ([Microsoft.PackageManagement.MetaProvider.PowerShell.OptionType]::Switch) -IsRequired $false);
            Write-Output (New-DynamicOption -Category $category -Name Mount -ExpectedType ([Microsoft.PackageManagement.MetaProvider.PowerShell.OptionType]::Switch) -IsRequired $false);
            Write-Output (New-DynamicOption -Category $category -Name DynamicDeploymentConfiguration -ExpectedType ([Microsoft.PackageManagement.MetaProvider.PowerShell.OptionType]::String) -IsRequired $false);
            Write-Output (New-DynamicOption -Category $category -Name DynamicUserConfigurationPath -ExpectedType ([Microsoft.PackageManagement.MetaProvider.PowerShell.OptionType]::String) -IsRequired $false);
            Write-Output (New-DynamicOption -Category $category -Name DynamicUserConfigurationType -ExpectedType ([Microsoft.PackageManagement.MetaProvider.PowerShell.OptionType]::String) -IsRequired $false -PermittedValues @('UseDeploymentConfiguration','UseExistingConfiguration','UseNoConfiguration'));
		}
	} #end switch category
} #end function Get-DynamicOptions
