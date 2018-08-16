function Gui
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $Options
    )

    # enable the gui
    $PodeSession.Gui.Enabled = $true
    $PodeSession.Gui.Name = $Name

    # if we have options, set them up
    if (!(Test-Empty $Options)) {
        if (!(Test-Empty $Options.Icon)) {
            $PodeSession.Gui['Icon'] = (Resolve-Path $Options.Icon).Path
        }

        if (!(Test-Empty $Options.State)) {
            $PodeSession.Gui['State'] = $Options.State
        }
    }

    # validate the settings
    $icon = $PodeSession.Gui.Icon
    if (!(Test-Empty $icon) -and !(Test-Path $icon)) {
        throw "Path to icon for GUI does not exist"
    }

    $state = $PodeSession.Gui.State
    $states = @('Normal', 'Maximized', 'Minimized')
    if (!(Test-Empty $state) -and $states -inotcontains $state) {
        throw "Invalid GUI window state supplied, should be blank or $($states -join ' / ')"
    }
}

function Start-GuiRunspace
{
    if (!$PodeSession.Gui.Enabled) {
        return
    }

    $script = {
        try
        {
            <#
            # Sourced and editted from http://tiberriver256.github.io/powershell/gui/html/PowerShell-HTML-GUI-Pt3/
            #>

            # get the endpoint to listen on
            $protocol = 'http'
            if ($PodeSession.IP.Ssl) {
                $protocol = 'https'
            }

            $port = $PodeSession.IP.Port
            if ($port -eq 0) {
                $port = 8080
                if ($PodeSession.IP.Ssl) {
                    $port = 8443
                }
            }

            $endpoint = "$($protocol)://$($PodeSession.IP.Name):$($port)"

            # poll the server for a response
            while ($true) {
                try {
                    Invoke-WebRequest -Method Get -Uri $endpoint -UseBasicParsing -ErrorAction Stop | Out-Null
                    if (!$?) {
                        throw
                    }

                    break
                }
                catch {
                    Start-Sleep -Seconds 1
                }
            }

            # import the WPF assembly
            [System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
            [System.Reflection.Assembly]::LoadWithPartialName('PresentationCore') | Out-Null

            # setup the WPF XAML
            $gui_browser = "
                <Window
                    xmlns=`"http://schemas.microsoft.com/winfx/2006/xaml/presentation`"
                    xmlns:x=`"http://schemas.microsoft.com/winfx/2006/xaml`"
                    Title=`"$($PodeSession.Gui.Name)`"
                    WindowStartupLocation=`"CenterScreen`">
                        <WebBrowser Name=`"WebBrowser`"></WebBrowser>
                </Window>"

            # read in the XAML
            $reader = [System.Xml.XmlNodeReader]::new([xml]$gui_browser)
            $form = [Windows.Markup.XamlReader]::Load($reader)

            # add other options if they're available
            if (!(Test-Empty $PodeSession.Gui.Icon)) {
                $icon = [Uri]::new($PodeSession.Gui.Icon)
                $form.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($icon)
            }

            if (!(Test-Empty $PodeSession.Gui.State)) {
                $form.WindowState = $PodeSession.Gui.State
            }

            # get the browser object from XAML and navigate to base page
            $form.FindName("WebBrowser").Navigate($endpoint)

            # display the form
            $form.ShowDialog() | Out-Null
            Start-Sleep -Seconds 1
        }
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
        finally
        {
            # invoke the cancellation token to close the server
            $PodeSession.Tokens.Cancellation.Cancel()
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $script
}