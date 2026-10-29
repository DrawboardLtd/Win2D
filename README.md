# Win2D

Win2D is an easy-to-use Windows Runtime API for immediate mode 2D graphics
rendering with GPU acceleration. It is available to C#, C++ and VB developers
writing apps for the Windows Universal Platform (UWP). It utilizes the power
of Direct2D, and integrates seamlessly with XAML and CoreWindow.

Visit the [DirectX Landing Page](https://devblogs.microsoft.com/directx/landing-page/) for more resources for DirectX developers.

##### Where to get it
- [NuGet package](http://www.nuget.org/packages/Win2D.uwp)
- [Source code](http://github.com/Microsoft/Win2D)

##### How to use it
- [Documentation](http://microsoft.github.io/Win2D)
- [Sample code](http://github.com/Microsoft/Win2D-samples) -
    *also available in the [Store](https://www.microsoft.com/store/apps/9NBLGGGXWT9F)*

##### More info
- [Report a bug or ask a question](http://github.com/Microsoft/Win2D/issues)
- [Changelog](http://github.com/Microsoft/Win2D/blob/master/CHANGELOG.md)
- [License](http://opensource.org/licenses/MIT)
- [Contributing](http://github.com/Microsoft/Win2D/blob/master/CONTRIBUTING.md)

## Code Example
To give you a flavor of what the code looks like, here is a snippet of XAML:
```xml
xmlns:canvas="using:Microsoft.Graphics.Canvas.UI.Xaml"

<Grid>
    <canvas:CanvasControl Draw="canvasControl_Draw" ClearColor="CornflowerBlue" />
</Grid>
```
and C#:
```cs
void canvasControl_Draw(CanvasControl sender, CanvasDrawEventArgs args)
{
    args.DrawingSession.DrawEllipse(155, 115, 80, 30, Colors.Black, 3);
    args.DrawingSession.DrawText("Hello, world!", 100, 100, Colors.Yellow);
}
```
or C++/CX:
```cpp
void MainPage::CanvasControl_Draw(CanvasControl^ sender, CanvasDrawEventArgs^ args)
{
    args->DrawingSession->DrawEllipse(155, 115, 80, 30, Colors::Black, 3);
    args->DrawingSession->DrawText("Hello, world!", 100, 100, Colors::Yellow);
}
```
or C++/WinRT:
```cpp
void MainPage::CanvasControl_Draw(CanvasControl const& sender, CanvasDrawEventArgs const& args)
{
    args.DrawingSession().DrawEllipse(155, 115, 80, 30, Colors::Black(), 3);
    args.DrawingSession().DrawText(L"Hello, world!", 100, 100, Colors::Yellow());
}
```
or VB:
```vb
Sub canvasControl_Draw(sender As CanvasControl, args As CanvasDrawEventArgs)
    args.DrawingSession.DrawEllipse(155, 115, 80, 30, Colors.Black, 3)
    args.DrawingSession.DrawText("Hello, world!", 100, 100, Colors.Yellow)
End Sub
```

## Using Win2D

The [documentation](http://microsoft.github.io/Win2D) explains how to install Visual 
Studio, add the Win2D NuGet package to your project, and get started using the API.

## Building Win2D from source

##### Requirements
- Visual Studio 2022 17.12.4 with Tools for Universal Windows Apps 15.0.27428.01 and Windows SDK 18362

##### Clone Repository
- Go to 'View' -> 'Team Explorer' -> 'Local Git Repositories' -> 'Clone'
- Add the Win2D repository URL (https://github.com/Microsoft/Win2D.git) and hit 'Clone'

##### Build NuGet Packages
- Launch 'Developer Command Prompt for VS 2022'
- Change directory to your cloned Win2D repository and run 'build'

##### Point Visual Studio at the resulting 'bin' directory
- In Visual Studio, go to 'Tools' -> 'NuGet Package Manager' -> 'Package Manager Settings'
- Choose 'Package Sources'
- Click the '+' button to add a new source
- Set 'Name' to 'Win2D' (or a name of your choosing)
- Set 'Source' to the full path to the 'bin' directory (inside your cloned Win2D repository)
- Click the 'Update' button
- Click 'OK'

Locally built versions of Win2D are marked as prerelease, so you must change the 'Stable 
Only' setting to 'Include Prerelease' when adding them to your project.

## Building Drawboard's Win2D.uwp package

This fork's `uwp/main` is Microsoft's `uwp/main` (merged in from https://github.com/microsoft/Win2D) plus the fix for [Win2D #954](https://github.com/microsoft/Win2D/issues/954), which Microsoft hasn't taken. To take a later Microsoft release, merge their `uwp/main` into a branch and PR it into ours; the build refuses to run if a merge loses the fix. It is published to Drawboard's private `Drawboard.Win2D` feed by the Azure DevOps pipeline [`.pipelines/Drawboard-Package.yml`](.pipelines/Drawboard-Package.yml). Its header says how to release a new version.

To build the same package locally, run `build\drawboard\Build-Win2DPackage.ps1` from any PowerShell. It needs Visual Studio 2022 (Build Tools will do) with the v143 C++ toolset and its Universal Windows Platform support, including ARM64 (`Microsoft.VisualStudio.Component.UWP.VC.ARM64`), a Windows 10/11 SDK and the .NET SDK. It builds x86, x64, ARM64 and the C#/WinRT projection, writes `bin\Win2D.uwp.<version>.nupkg`, and checks it with `build\drawboard\Test-Win2DPackage.ps1`. Without the .NET Framework 4.7.2 targeting pack, pass `-IntellisenseXml` (see the script's help).


## Legacy support for Windows 8.1
Win2D 1.21.0 was the last release to support the Windows 8.1 and Windows Phone 8.1 
platforms. From Win2D 1.22.0 onward, only the Windows Universal Platform (UWP) is 
supported.

Legacy Win2D support for Windows and Phone 8.1 is available as a
[NuGet package](http://www.nuget.org/packages/Win2D.win81) and from the
[win81 branch](https://github.com/Microsoft/Win2D/tree/win81) on github.

---
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
