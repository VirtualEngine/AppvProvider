@{
    ModuleVersion = '0.6.0';
    GUID = 'efea3f79-595c-4eda-82fa-7cf72a3d85ac';
    Author = 'Iain Brighton, Nathan Sperry';
    CompanyName = 'Virtual Engine';
    Description = 'Powershell OneGet/Package Management Provider for App-V 5.x'
    Copyright = 'Copyright (c) 2015 Virtual Engine Limited. All rights reserved.';
    PowerShellVersion = '3.0';
    RequiredModules = @('PackageManagement','AppvClient');
    PrivateData = @{
        PackageManagementProviders = 'AppvProvider.psm1';
        PSData = @{
            Tags = @('VirtualEngine','Powershell','OneGet','Appv','App-V');
            LicenseUri = 'https://raw.githubusercontent.com/VirtualEngine/AppvProvider/master/LICENSE';
            ProjectUri = 'https://github.com/VirtualEngine/AppvProvider';
            IconUri = 'https://raw.githubusercontent.com/VirtualEngine/AppvProvider/master/appv_oneget.png';
        } # End of PSData hashtable
    };
}
