## Welcome!
The AppVProvider project is an open-source implementation of a Micrsoft Application Virtualization (App-V) 5.x
provider for Microsoft's ~~OneGet~~ Package Management Powershell module. More information on the open-source
OneGet project can be found [here](https://github.com/oneget/oneget).

The App-V Provider can install and uninstall Microsoft App-V v5.x packages from local and/or remote directory
paths with a behaviour that is is consistent with all other OneGet/Microsoft Package Management providers.

## Prerequisites
To use the OneGet/Package Management App-V Provider you will need the following installed:
* The [Windows Management Framework (WMF) 5.0 preview](http://www.microsoft.com/en-us/download/details.aspx?id=46889) __or__
the [latest experimental OneGet](https://www.microsoft.com/en-us/download/details.aspx?id=46889) build.
* Microsoft's Application Virtualization (App-V) 5.x client.

## Getting Started
Once you have the prerequisites installed, you can install the OneGet App-V Provider via the Powershell Gallery by running the following Powershell command:

> `Install-Module AppvProvider`

You can also manually download and install the OneGet App-V Provider by performing the following:

* Download the [latest Appv Provider release](http://github.com/VirtualEngine/AppvProvider/releases/latest).
* Unblock the zip file __before extracting!__
 * PowerShell by default does not run files downloaded from the internet.
 * Right-click the zip file and click on "Properties" and click on the "Unblock" button.
* Extract the zip file to the %ProgramFiles%\WindowsPowershell\Modules directory.

More detailed information on the usage of the App-V Provider can be found [here](http://virtualengine.co.uk/) until it's moved to the Wiki.

## How Can I Contribute?
All contributions to the OneGet App-V Provider are always gratefully received.

If you have:

* found a bug, file an issue and we'll look into it
* a feature you would like to see implemented, file an issue and we'll add it to the backlog
* updates to the documentation, contribute directly to the Wiki

Please fork the project and send us a pull request if:

* you have implemented a new feature or something from the backlog
* there is a bug you have found and fixed it
* or you have any other updates

We're all really busy and can only make this what it needs to be with a community effort \o/. 

## The OneGet Community
There is an active community shaping the future of [Package Management on Windows](https://github.com/OneGet/oneget) -- your opinions, feedback and code can help everyone. 

### Weekly Online Meeeting 
There is an online weekly meeting Friday mornings @ 10:00 PDT [via Lync](http://oneget.org/weekly/meeting.html)* (everyone welcome!).
You can also see archives of the previous meetings available on [YouTube](https://www.youtube.com/playlist?list=PLeKWr5Ekac1SEEvHqIh3g051OyioFwOXN&feature=c4-feed-u).

## License
The AppvProvider is licensed under the [Apache License, Version 2](http://www.apache.org/licenses/).